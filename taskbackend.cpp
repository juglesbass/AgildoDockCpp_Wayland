#include "taskbackend.h"
#include "dock_window_management.h"
#include "kwin_integration.h"

#include <QDBusInterface>
#include <QDBusReply>
#include <QDBusConnection>
#include <QDBusError>
#include <QFile>
#include <QStandardPaths>

#include <QDirIterator>
#include <QFile>
#include <QGuiApplication>
#include <QMetaObject>
#include <QStandardPaths>
#include <QPainterPath>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QRegion>
#include <QTextStream>
#include <QTimer>
#include <QUrl>
#include <QtConcurrent/QtConcurrentRun>

#include <LayerShellQt/Window>
#include <KWindowEffects>

#include <fcntl.h>
#include <unistd.h>

#include <dirent.h>

namespace {
    constexpr int kKdotoolTimeoutMs = 400;
    constexpr int kKdotoolGeometryKillMs = 800;
    constexpr int kKdotoolActiveWindowKillMs = 900;
    /// Intervalo do timer: escaneamento /proc é pesado em máquinas com muitos processos.
    constexpr int kSystemPollIntervalMs = 1200;
    constexpr int kSystemPollIntervalKwinMs = 750;
    constexpr int kForegroundPollKwinMs = 380;

    // Interpreta saída do kdotool getwindowgeometry (formato estilo xdotool / texto livre).
    static QSize parseWindowGeometryFromKdotool(const QString &text)
    {
        static const QRegularExpression reGeometry(QStringLiteral(R"(Geometry:\s*(\d+)\s*x\s*(\d+))"),
                                               QRegularExpression::CaseInsensitiveOption);
        const QRegularExpressionMatch m1 = reGeometry.match(text);
        if (m1.hasMatch()) {
            return QSize(m1.captured(1).toInt(), m1.captured(2).toInt());
        }
        static const QRegularExpression rePlain(QStringLiteral(R"((\d{2,5})\s*x\s*(\d{2,5}))"));
        int w = 0;
        int h = 0;
        QRegularExpressionMatchIterator it = rePlain.globalMatch(text);
        while (it.hasNext()) {
            const QRegularExpressionMatch m = it.next();
            w = m.captured(1).toInt();
            h = m.captured(2).toInt();
        }
        if (w > 0 && h > 0) {
            return QSize(w, h);
        }
        return QSize();
    }
} // namespace

static QString shQuote(const QString &s)
{
    // Aspas simples para bash/sh; escapa single-quote interno (fechando/abrindo).
    // Ex: abc'd -> 'abc'\''d'
    QString escaped = s;
    escaped.replace(QLatin1Char('\''), QStringLiteral("'\\''"));
    return QStringLiteral("'") + escaped + QStringLiteral("'");
}

static bool tryOpenDolphinLocation(const QString &command)
{
    const QString trimmed = command.trimmed();
    if (trimmed.isEmpty()) {
        return false;
    }

    const QStringList parts =
        trimmed.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    if (parts.isEmpty()) {
        return false;
    }

    const QString execName = parts.first().split(QLatin1Char('/')).last().toLower();
    if (execName != QLatin1String("dolphin")) {
        return false;
    }

    if (parts.size() < 2) {
        return false;
    }

    QString target = parts.mid(1).join(QLatin1Char(' ')).trimmed();
    if (target.isEmpty()) {
        return false;
    }
    target.remove(QStringLiteral("\"")).remove(QStringLiteral("'"));

    // Expande ~/ para caminho absoluto.
    if (target.startsWith(QStringLiteral("~/"))) {
        const QString home = QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
        if (!home.isEmpty()) {
            target = home + target.mid(1);
        }
    }

    QUrl url;
    // trash:/ é um esquema KIO.
    if (target.startsWith(QStringLiteral("trash:/")) || target.startsWith(QStringLiteral("trash:"))) {
        url = QUrl(target);
    } else if (target.contains(QLatin1String("://"))) {
        // Já é URL.
        url = QUrl(target);
    } else {
        // Considera caminho local.
        url = QUrl::fromLocalFile(target);
    }

    if (!url.isValid()) {
        return false;
    }

    const QString urlStr = url.toString(QUrl::FullyEncoded);

    // kfmclient costuma reutilizar a instância do Dolphin e abrir em tab.
    // Se falhar (ex.: não instalado/erro), tentamos xdg-open e só depois fallback pro comando original.
    const QString script = QStringLiteral("kfmclient openURL %1 >/dev/null 2>&1 || xdg-open %1 >/dev/null 2>&1 || sh -c %2")
                                .arg(shQuote(urlStr), shQuote(command));
    QProcess::startDetached(QStringLiteral("sh"), {QStringLiteral("-c"), script});
    return true;
}

QString TaskBackend::readProcCmdlineFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    QByteArray raw = f.readAll();
    for (int i = 0; i < raw.size(); ++i) {
        if (raw.at(i) == '\0') {
            raw[i] = ' ';
        }
    }
    return QString::fromUtf8(raw).toLower().trimmed();
}

QString TaskBackend::execBasenameFromCommand(const QString &command)
{
    QString exec = command.split(' ').first().split('/').last().toLower();
    exec.remove('"').remove('\'');
    return exec;
}

TaskBackend::TaskBackend(QObject *parent)
: QObject(parent)
{
    // D-Bus: usado pelo efeito do KWin para obter a geometria do ícone-alvo.
    {
        const QString service = QStringLiteral("org.agildosoft.AgildoDock");
        const QString path = QStringLiteral("/AgildoDock");
        auto bus = QDBusConnection::sessionBus();
        if (!bus.registerService(service)) {
            qWarning() << "AgildoDock: falha ao registrar serviço D-Bus:" << service << bus.lastError().message();
        }
        if (!bus.registerObject(path, this, QDBusConnection::ExportScriptableSlots)) {
            qWarning() << "AgildoDock: falha ao registrar object D-Bus:" << path << bus.lastError().message();
        }
    }

    m_kdotoolAvailable = !QStandardPaths::findExecutable(QStringLiteral("kdotool")).isEmpty();
    if (!windowManagementAvailable()) {
        qWarning() << "AgildoDock: sem kdotool nem integração X11 (KF6/KX11Extras) disponível nesta sessão Qt — foco, minimizar,"
                      "fechar e o modo «desviar» dependem dessas vias.";
    }

    loadKnownApps();

    m_pollTimer = new QTimer(this);
    connect(m_pollTimer, &QTimer::timeout, this, &TaskBackend::updateSystemState);
  m_pollTimer->start(KwinIntegration::isAvailable() ? kSystemPollIntervalKwinMs : kSystemPollIntervalMs);

    if (KwinIntegration::isAvailable()) {
        m_foregroundTimer = new QTimer(this);
        connect(m_foregroundTimer, &QTimer::timeout, this, [this]() {
            if (!m_procScanRunning) {
                pollActiveForegroundHints();
            }
        });
        m_foregroundTimer->start(kForegroundPollKwinMs);
    }
}

bool TaskBackend::kwinIntegrationAvailable() const
{
    return KwinIntegration::isAvailable();
}

bool TaskBackend::windowManagementAvailable() const
{
    return DockWindowManagement::fullForeignWindowCtlAvailable(m_kdotoolAvailable);
}

QStringList TaskBackend::appKeysForCommand(const QString &command) const
{
    QStringList keys;
    if (command.trimmed().isEmpty()) {
        return keys;
    }
    // Exec básico
    const QString exec = execBasenameFromCommand(command);
    if (!exec.isEmpty()) {
        keys << exec.toLower();
    }

    // Se o comando estiver no índice de apps conhecidas, adiciona wmclass e/ou appId quando existir.
    if (knownApps.contains(command)) {
        const QVariantMap row = knownApps.value(command);
        const QString wm = row.value(QStringLiteral("wmclass")).toString().trimmed().toLower();
        if (!wm.isEmpty() && !keys.contains(wm)) {
            keys << wm;
        }
        // Alguns .desktop podem guardar appId explicitamente (se existir no índice).
        const QString appId = row.value(QStringLiteral("appid")).toString().trimmed().toLower();
        if (!appId.isEmpty() && !keys.contains(appId)) {
            keys << appId;
        }
    }
    keys.removeAll(QString());
    keys.removeDuplicates();
    return keys;
}

void TaskBackend::setIconRectForKeys(const QStringList &keys, int x, int y, int w, int h, const QString &screenName)
{
    if (keys.isEmpty()) {
        return;
    }
    const bool valid = (w > 0 && h > 0);
    for (const QString &kRaw : keys) {
        const QString k = kRaw.trimmed().toLower();
        if (k.isEmpty()) {
            continue;
        }
        if (!valid) {
            m_iconRects.remove(k);
            continue;
        }
        QVariantMap row;
        row.insert(QStringLiteral("x"), x);
        row.insert(QStringLiteral("y"), y);
        row.insert(QStringLiteral("w"), w);
        row.insert(QStringLiteral("h"), h);
        row.insert(QStringLiteral("screen"), screenName);
        m_iconRects.insert(k, row);
    }
}

QVariantMap TaskBackend::GetIconRect(const QString &appKey) const
{
    const QString k = appKey.trimmed().toLower();
    if (k.isEmpty()) {
        return {};
    }
    if (m_iconRects.contains(k)) {
        return m_iconRects.value(k);
    }
    // WM_CLASS / windowClass do KWin (ex.: "dolphin dolphin").
    const QStringList tokens =
        k.split(QRegularExpression(QStringLiteral("\\s+")), Qt::SkipEmptyParts);
    for (const QString &token : tokens) {
        if (m_iconRects.contains(token)) {
            return m_iconRects.value(token);
        }
    }
    // Fallback: se vier algo como org.kde.dolphin, tenta o basename.
    const QString tail = k.split(QLatin1Char('.')).last();
    if (!tail.isEmpty() && m_iconRects.contains(tail)) {
        return m_iconRects.value(tail);
    }
    return {};
}

void TaskBackend::setMainWindow(QWindow *win)
{
    m_mainWindow = win;
}

void TaskBackend::applyLayerShellKeyboardMode(int keyboardMode)
{
    if (!m_mainWindow) {
        return;
    }
    LayerShellQt::Window *layerWindow = LayerShellQt::Window::get(m_mainWindow);
    if (!layerWindow) {
        return;
    }
    int clamped = qBound(0, keyboardMode, 2);
    layerWindow->setKeyboardInteractivity(static_cast<LayerShellQt::Window::KeyboardInteractivity>(clamped));
    m_mainWindow->requestUpdate();
}

void TaskBackend::setLayerShellActivateOnShow(bool activate)
{
    if (!m_mainWindow) {
        return;
    }
    LayerShellQt::Window *layerWindow = LayerShellQt::Window::get(m_mainWindow);
    if (!layerWindow) {
        return;
    }
    layerWindow->setActivateOnShow(activate);
    m_mainWindow->requestUpdate();
}

// CORREÇÃO: Função assíncrona para não travar a interface da doca
void TaskBackend::updateActiveWindowCoversWorkAreaHint()
{
    if (!m_kdotoolAvailable || !m_mainWindow || !m_mainWindow->screen()) {
        return;
    }

    auto *pg = new QProcess(this);
    connect(pg, &QProcess::finished, this, [this, pg]() {
        const QString geo = QString::fromUtf8(pg->readAllStandardOutput());
        pg->deleteLater();

        const QSize windowSize = parseWindowGeometryFromKdotool(geo);
        const QRect sg = m_mainWindow->screen()->geometry();

        bool covers = false;
        if (windowSize.isValid() && sg.width() > 0 && sg.height() > 0) {
            covers = (windowSize.width()  >= int(sg.width()  * 0.88) &&
            windowSize.height() >= int(sg.height() * 0.82));
        }

        if (covers != m_activeWindowCoversWorkArea) {
            m_activeWindowCoversWorkArea = covers;
            emit activeWindowCoversWorkAreaChanged();
        }
    });

    QTimer::singleShot(kKdotoolGeometryKillMs, pg, [pg]() {
        if (pg && pg->state() == QProcess::Running) {
            pg->kill();
        }
    });

    pg->start(QStringLiteral("kdotool"), {QStringLiteral("getactivewindow"), QStringLiteral("getwindowgeometry")});
}

void TaskBackend::pollActiveForegroundHints()
{
    QString clsNative;
    QString ttlNative;
    QSize innerGeom;

    if (KwinIntegration::pollActiveWindow(&clsNative, &ttlNative, &innerGeom)) {
        m_activeAppClass = clsNative;
        m_activeAppTitle = ttlNative;
        if (m_mainWindow && m_mainWindow->screen()) {
            const QRect sg = m_mainWindow->screen()->geometry();
            const bool covers = DockWindowManagement::activeWindowProbablyCoversWorkArea(
                innerGeom,
                QSize(sg.width(), sg.height()));
            if (covers != m_activeWindowCoversWorkArea) {
                m_activeWindowCoversWorkArea = covers;
                emit activeWindowCoversWorkAreaChanged();
            }
        }
        emit windowsUpdated();
        return;
    }

    if (DockWindowManagement::fillActiveHintsFromNativeStacking(clsNative, ttlNative, &innerGeom, nullptr)) {
        m_activeAppClass = clsNative;
        m_activeAppTitle = ttlNative;
        if (m_mainWindow && m_mainWindow->screen()) {
            const QRect sg = m_mainWindow->screen()->geometry();
            const bool covers = DockWindowManagement::activeWindowProbablyCoversWorkArea(
                innerGeom,
                QSize(sg.width(), sg.height()));
            if (covers != m_activeWindowCoversWorkArea) {
                m_activeWindowCoversWorkArea = covers;
                emit activeWindowCoversWorkAreaChanged();
            }
        }
        emit windowsUpdated();
        return;
    }

    if (!m_kdotoolAvailable) {
        return;
    }

    auto *p = new QProcess(this);
    connect(p, static_cast<void (QProcess::*)(int, QProcess::ExitStatus)>(&QProcess::finished), this,
            [this, p](int exitCode, QProcess::ExitStatus exitStatus) {
                QString out = QString::fromUtf8(p->readAllStandardOutput()).trimmed();
                if (exitStatus == QProcess::NormalExit && exitCode == 0 && !out.isEmpty()) {
                    QStringList lines = out.split(QLatin1Char('\n'));
                    if (lines.size() >= 2) {
                        m_activeAppClass = lines[0].toLower();
                        m_activeAppTitle = lines[1].toLower();
                    } else {
                        m_activeAppClass = out.toLower();
                        m_activeAppTitle.clear();
                    }
                }
                p->deleteLater();
                updateActiveWindowCoversWorkAreaHint();
                emit windowsUpdated();
            });

    QTimer::singleShot(kKdotoolActiveWindowKillMs, p, [p]() {
        if (p && p->state() == QProcess::Running) {
            p->kill();
        }
    });

    p->start(QStringLiteral("kdotool"),
             {QStringLiteral("getactivewindow"),
              QStringLiteral("getwindowclassname"),
              QStringLiteral("getwindowname")});
}

void TaskBackend::updateSystemState()
{
    if (m_procScanRunning) {
        return;
    }
    m_procScanRunning = true;
    (void)QtConcurrent::run([this]() {
        QSet<QString> next;
        DIR *dir = opendir("/proc");
        if (dir) {
            struct dirent *ent;
            while ((ent = readdir(dir)) != nullptr) {
                if (ent->d_name[0] >= '1' && ent->d_name[0] <= '9') {
                    const QString path = QStringLiteral("/proc/%1/cmdline").arg(QString::fromUtf8(ent->d_name));
                    const QString line = readProcCmdlineFile(path);
                    if (!line.isEmpty()) {
                        next.insert(line);
                    }
                }
            }
            closedir(dir);
        }
        QMetaObject::invokeMethod(
            this,
            [this, next]() {
                m_procScanRunning = false;
                m_runningCmdLines = next;
                // Indicadores “a correr” baseiam-se em /proc — não esperar pelo kdotool.
                emit windowsUpdated();

                if (DockWindowManagement::fullForeignWindowCtlAvailable(m_kdotoolAvailable)) {
                    pollActiveForegroundHints();
                }
            },
            Qt::QueuedConnection);
    });
}

QString TaskBackend::resolveWindowTokenForLaunch(const QString &command)
{
    return DockWindowManagement::resolveWindowHandleForLaunch(command,
                                                               knownApps,
                                                               m_kdotoolAvailable,
                                                               kKdotoolTimeoutMs);
}

void TaskBackend::updateExclusiveZone(int size)
{
    if (!m_mainWindow) {
        return;
    }

    LayerShellQt::Window *layerWindow = LayerShellQt::Window::get(m_mainWindow);
    if (layerWindow) {
        layerWindow->setExclusiveZone(size);
        m_mainWindow->requestUpdate();
    }
}

void TaskBackend::setPointerInputExcludeTop(int excludeTopPixels)
{
    if (!m_mainWindow) {
        return;
    }

    // No Wayland, QWindow::setMask alimenta wl_surface.set_input_region (ver QWaylandWindow::setMask).
    // No X11 o mesmo API pode recortar a janela visualmente — não tocar.
    if (!QGuiApplication::platformName().contains(QStringLiteral("wayland"), Qt::CaseInsensitive)) {
        return;
    }

    const int w = m_mainWindow->width();
    const int h = m_mainWindow->height();
    if (w <= 0 || h <= 0) {
        return;
    }

    if (excludeTopPixels <= 0 || excludeTopPixels >= h - 24) {
        m_mainWindow->setMask(QRegion());
    } else {
        m_mainWindow->setMask(QRegion(0, excludeTopPixels, w, h - excludeTopPixels));
    }
    m_mainWindow->requestUpdate();
}

void TaskBackend::setBlurRegion(int x, int y, int w, int h, int radius)
{
    m_pendingBlurX = x;
    m_pendingBlurY = y;
    m_pendingBlurW = w;
    m_pendingBlurH = h;
    m_pendingBlurRadius = radius;

    if (!m_blurFlushPending) {
        m_blurFlushPending = true;
        QMetaObject::invokeMethod(this, "flushBlurRegion", Qt::QueuedConnection);
    }
}

void TaskBackend::flushBlurRegion()
{
    m_blurFlushPending = false;

    if (!m_mainWindow) {
        return;
    }

    const int x = m_pendingBlurX;
    const int y = m_pendingBlurY;
    const int w = m_pendingBlurW;
    const int h = m_pendingBlurH;
    const int radius = m_pendingBlurRadius;

    int safeW = qMin(w, m_mainWindow->width() - x);
    int safeH = qMin(h, m_mainWindow->height() - y);

    // Geometria inválida por um frame (onda/arrasto): não desligar o blur — evita “piscar” um retângulo.
    if (safeW <= 0 || safeH <= 0) {
        return;
    }

    if (m_hasLastBlur && m_lastBlurX == x && m_lastBlurY == y && m_lastBlurW == safeW && m_lastBlurH == safeH
        && m_lastBlurRadius == radius) {
        return;
    }

    m_hasLastBlur = true;
    m_lastBlurX = x;
    m_lastBlurY = y;
    m_lastBlurW = safeW;
    m_lastBlurH = safeH;
    m_lastBlurRadius = radius;

    QPainterPath path;
    path.addRoundedRect(x, y, safeW, safeH, radius, radius);
    QRegion blurRegion(path.toFillPolygon().toPolygon());
    KWindowEffects::enableBlurBehind(m_mainWindow, true, blurRegion);
}

void TaskBackend::loadKnownApps()
{
    QStringList sysPaths = {QStringLiteral("/usr/share/applications"), QStringLiteral("/usr/local/share/applications")};
    const QString homePath = QProcessEnvironment::systemEnvironment().value(QStringLiteral("HOME"))
    + QStringLiteral("/.local/share/applications");
    sysPaths << homePath;

    const QStringList blacklist = {
        QStringLiteral("lact"),     QStringLiteral("steam"),     QStringLiteral("discord"), QStringLiteral("telegram-desktop"),
        QStringLiteral("obsidian"), QStringLiteral("kded5"),     QStringLiteral("kded6"), QStringLiteral("polkit"),
        QStringLiteral("kwallet"),  QStringLiteral("powerdevil"), QStringLiteral("ksmserver"), QStringLiteral("plasmashell"),
        QStringLiteral("kwin_wayland"), QStringLiteral("agent"), QStringLiteral("agildo thermo"), QStringLiteral("agildothermo"),
        QStringLiteral("agildodock"), QStringLiteral("agildocontrol")};

    for (const QString &path : std::as_const(sysPaths)) {
        QDirIterator it(path, QStringList() << QStringLiteral("*.desktop"), QDir::Files, QDirIterator::Subdirectories);
        while (it.hasNext()) {
            const QString filePath = it.next();
            QVariantMap app = parseDropInfo(QStringLiteral("file://") + filePath);

            if (app.contains(QStringLiteral("cmd")) && !app.contains(QStringLiteral("error")) && !app.contains(QStringLiteral("nodisplay"))) {
                const QString fullCmd = app[QStringLiteral("cmd")].toString().toLower();
                const QString appName = app[QStringLiteral("name")].toString().toLower();

                bool isBlacklisted = false;
                for (const QString &b : blacklist) {
                    if (fullCmd.contains(b) || appName.contains(b)) {
                        isBlacklisted = true;
                        break;
                    }
                }

                if (isBlacklisted) {
                    continue;
                }

                const QString cmdKey = app[QStringLiteral("cmd")].toString();
                if (!cmdKey.isEmpty() && !knownApps.contains(cmdKey)) {
                    knownApps[cmdKey] = app;
                }
            }
        }
    }

    rebuildExecIndex();
}

void TaskBackend::rebuildExecIndex()
{
    m_appsByExec.clear();
    for (auto it = knownApps.constBegin(); it != knownApps.constEnd(); ++it) {
        const QVariantMap &app = it.value();
        const QString appExec = execBasenameFromCommand(app[QStringLiteral("cmd")].toString());
        if (!appExec.isEmpty()) {
            m_appsByExec.insert(appExec, app);
        }
    }
}

bool TaskBackend::appMatchesRunningCmdLine(const QString &cmdLineLower, const QVariantMap &app)
{
    const QString appCmd = app[QStringLiteral("cmd")].toString();
    const QString appCmdLower = appCmd.toLower();
    QString appExec = appCmd.split(' ').first().split('/').last().toLower();
    appExec.remove('"').remove('\'');

    if (appCmdLower.contains(QStringLiteral("--app-id"))) {
        QString appId;
        const QStringList parts = appCmdLower.split(' ');
        for (const QString &p : parts) {
            if (p.startsWith(QStringLiteral("--app-id="))) {
                appId = p;
                appId.remove('"').remove('\'');
                break;
            }
        }
        if (!appId.isEmpty() && cmdLineLower.contains(appId)) {
            return true;
        }
        return false;
    }

    const bool browserish = appExec.contains(QStringLiteral("chromium")) || appExec.contains(QStringLiteral("chrome"))
        || appExec.contains(QStringLiteral("edge")) || appExec.contains(QStringLiteral("zen"));

    if (browserish) {
        if ((cmdLineLower.startsWith(appExec) || cmdLineLower.contains(QStringLiteral("/") + appExec))
            && !cmdLineLower.contains(QStringLiteral("--app-id")) && !cmdLineLower.contains(QStringLiteral("--type=renderer"))
            && !cmdLineLower.contains(QStringLiteral("--type=zygote"))) {
            return true;
        }
        return false;
    }

    if (cmdLineLower.startsWith(appExec) || cmdLineLower.contains(QStringLiteral("/") + appExec)) {
        return true;
    }
    return false;
}

QVariantMap TaskBackend::matchRunningLineToApp(const QString &cmdLineLower) const
{
    const QString execTok = cmdLineLower.split(' ').first().split('/').last().toLower();
    QString tok = execTok;
    tok.remove('"').remove('\'');

    const QList<QVariantMap> candidates = m_appsByExec.values(tok);
    for (const QVariantMap &app : candidates) {
        if (appMatchesRunningCmdLine(cmdLineLower, app)) {
            return app;
        }
    }

    const QList<QVariantMap> allApps = knownApps.values();
    for (const QVariantMap &app : allApps) {
        if (appMatchesRunningCmdLine(cmdLineLower, app)) {
            return app;
        }
    }
    return {};
}

QVariantList TaskBackend::getUnpinnedApps(const QVariantList &pinnedCmdsVar)
{
    QVariantList unpinned;
    QSet<QString> pinnedCmds;

    for (const QVariant &v : pinnedCmdsVar) {
        pinnedCmds.insert(v.toString());
    }

    QSet<QString> addedCmds;

    for (const QString &cmdLine : std::as_const(m_runningCmdLines)) {
        const QVariantMap bestMatch = matchRunningLineToApp(cmdLine);
        if (bestMatch.isEmpty()) {
            continue;
        }

        const QString matchCmd = bestMatch[QStringLiteral("cmd")].toString();
        if (!pinnedCmds.contains(matchCmd) && !addedCmds.contains(matchCmd)) {
            unpinned.append(bestMatch);
            addedCmds.insert(matchCmd);
        }
    }
    return unpinned;
}

void TaskBackend::forceLaunchApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }
    if (tryOpenDolphinLocation(command)) {
        return;
    }

    QString desktopPath;
    if (knownApps.contains(command) && knownApps[command].contains(QStringLiteral("desktopPath"))) {
        desktopPath = knownApps[command][QStringLiteral("desktopPath")].toString();
    }

    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.remove(QStringLiteral("QT_WAYLAND_SHELL_INTEGRATION"));
    process.setProcessEnvironment(env);

    if (!desktopPath.isEmpty()) {
        process.setProgram(QStringLiteral("kioclient"));
        process.setArguments({QStringLiteral("exec"), desktopPath});
    } else {
        process.setProgram(QStringLiteral("sh"));
        process.setArguments({QStringLiteral("-c"), command});
    }

    process.startDetached();
}

void TaskBackend::completeLaunchApp(const QString &command, const QString &winToken)
{
    if (command.isEmpty()) {
        return;
    }

    if (!winToken.isEmpty()) {
        const bool dockItemMatchesForeground = isAppFocused(command);

        if (winToken.startsWith(QLatin1String("x11:"))) {
            QString wmGuess;
            // KX11Extras concentra ativar/minimizar; kdotool fica apenas para Plasma/Wayland.
            if (DockWindowManagement::activatePackedOrMinimize(winToken,
                                                               dockItemMatchesForeground,
                                                               command,
                                                               wmGuess)) {
                if (dockItemMatchesForeground) {
                    m_activeAppClass.clear();
                    m_activeAppTitle.clear();
                } else if (!wmGuess.isEmpty()) {
                    m_activeAppClass = wmGuess;
                }
                emit windowsUpdated();
            }
            return;
        }

        if (dockItemMatchesForeground) {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowminimize"), winToken});
            m_activeAppClass.clear();
            m_activeAppTitle.clear();
            emit windowsUpdated();
        } else {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), winToken});
            m_activeAppClass = execBasenameFromCommand(command);
            emit windowsUpdated();
        }
    } else {
        forceLaunchApp(command);
    }
}

void TaskBackend::launchApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }
    if (tryOpenDolphinLocation(command)) {
        return;
    }
    const QString cmdCopy = command;
    const quint64 seq = ++m_launchSeq[cmdCopy];
    // Descobre janela em thread do pool — evita travar a UI durante vários kdotool/waitForFinished.
    (void)QtConcurrent::run([this, cmdCopy, seq]() {
        const QString winId = resolveWindowTokenForLaunch(cmdCopy);
        QMetaObject::invokeMethod(
            this,
            [this, cmdCopy, winId, seq]() {
                if (m_launchSeq.value(cmdCopy) != seq) {
                    return;
                }
                completeLaunchApp(cmdCopy, winId);
            },
            Qt::QueuedConnection);
    });
}

void TaskBackend::completeCloseApp(const QString &command, const QString &winToken, bool killIfNoWindow)
{
    if (!winToken.isEmpty()) {
        if (winToken.startsWith(QLatin1String("x11:"))) {
            DockWindowManagement::closePackedWindow(winToken, m_kdotoolAvailable);
            return;
        }
        QProcess::startDetached(QStringLiteral("kdotool"),
                                {QStringLiteral("windowclose"), winToken});
        return;
    }
    if (killIfNoWindow) {
        killProcessesForCommand(command);
        return;
    }
    qWarning() << "AgildoDock: não foi possível fechar app (janela não encontrada):" << command;
}

void TaskBackend::closeAllWindows(const QString &command, bool killProcessIfNoWindow)
{
    if (command.isEmpty()) {
        return;
    }
    const QStringList handles = resolveAllWindowTokens(command);
    for (const QString &tok : handles) {
        completeCloseApp(command, tok, false);
    }
    if (handles.isEmpty() && killProcessIfNoWindow) {
        killProcessesForCommand(command);
    }
}

void TaskBackend::closeApp(const QString &command, bool killProcessIfNoWindow)
{
    if (command.isEmpty()) {
        return;
    }
    const QString cmdCopy = command;
    const quint64 seq = ++m_closeSeq[cmdCopy];
    const bool killCopy = killProcessIfNoWindow;
    (void)QtConcurrent::run([this, cmdCopy, seq, killCopy]() {
        const QString winId = resolveWindowTokenForLaunch(cmdCopy);
        QMetaObject::invokeMethod(
            this,
            [this, cmdCopy, winId, seq, killCopy]() {
                if (m_closeSeq.value(cmdCopy) != seq) {
                    return;
                }
                completeCloseApp(cmdCopy, winId, killCopy);
            },
            Qt::QueuedConnection);
    });
}

QStringList TaskBackend::resolveAllWindowTokens(const QString &command) const
{
    return DockWindowManagement::resolveAllWindowHandlesForCommand(command,
                                                                   knownApps,
                                                                   m_kdotoolAvailable,
                                                                   kKdotoolTimeoutMs);
}

int TaskBackend::windowCountForCommand(const QString &command)
{
    if (command.isEmpty()) {
        return 0;
    }
    const QStringList handles = resolveAllWindowTokens(command);
    if (!handles.isEmpty()) {
        return handles.size();
    }
    return isAppRunning(command) ? 1 : 0;
}

void TaskBackend::focusWindowToken(const QString &token)
{
    if (token.isEmpty()) {
        return;
    }
    DockWindowManagement::activateWindowToken(token, m_kdotoolAvailable);
    emit windowsUpdated();
}

void TaskBackend::cycleAppWindows(const QString &command, bool forward)
{
    if (command.isEmpty()) {
        return;
    }
    QStringList handles = resolveAllWindowTokens(command);
    if (handles.isEmpty()) {
        if (isAppRunning(command)) {
            launchApp(command);
        }
        return;
    }
    int idx = m_cycleWindowIndex.value(command, -1);
    if (forward) {
        idx = (idx + 1) % handles.size();
    } else {
        idx = (idx <= 0) ? (handles.size() - 1) : (idx - 1);
    }
    m_cycleWindowIndex.insert(command, idx);
    DockWindowManagement::activateWindowToken(handles.at(idx), m_kdotoolAvailable);
    m_activeAppClass = execBasenameFromCommand(command);
    emit windowsUpdated();
}

void TaskBackend::killProcessesForCommand(const QString &command) const
{
    const QString exec = execBasenameFromCommand(command);
    if (exec.isEmpty() || exec.size() < 2) {
        return;
    }
    static const QSet<QString> bloqueados = {
        QStringLiteral("python"),
        QStringLiteral("python3"),
        QStringLiteral("sh"),
        QStringLiteral("bash"),
        QStringLiteral("zsh"),
    };
    if (bloqueados.contains(exec)) {
        qWarning() << "AgildoDock: encerramento por processo ignorado (interpretador genérico):" << command;
        return;
    }
    QProcess::execute(QStringLiteral("pkill"), {QStringLiteral("-x"), exec});
}

bool TaskBackend::isAppRunning(const QString &command)
{
    if (command.isEmpty()) {
        return false;
    }

    // Comando com pasta/URL (ex.: dolphin trash:/) — só conta se existir janela desse alvo.
    if (DockWindowManagement::commandHasStrictPathTarget(command)) {
        return !resolveAllWindowTokens(command).isEmpty();
    }

    const QString cmdLower = command.toLower();
    QString execName = command.split(' ').first().split('/').last().toLower();
    execName.remove('"').remove('\'');

    if (cmdLower.contains(QStringLiteral("--app-id"))) {
        QString appId;
        const QStringList parts = cmdLower.split(' ');
        for (const QString &p : parts) {
            if (p.startsWith(QStringLiteral("--app-id="))) {
                appId = p;
                appId.remove('"').remove('\'');
                break;
            }
        }

        if (!appId.isEmpty()) {
            for (const QString &r : std::as_const(m_runningCmdLines)) {
                if (r.contains(appId)) {
                    return true;
                }
            }
        }
        return false;
    }

    if (execName.contains(QStringLiteral("chromium")) || execName.contains(QStringLiteral("chrome")) || execName.contains(QStringLiteral("edge"))
        || execName.contains(QStringLiteral("zen"))) {
        for (const QString &r : std::as_const(m_runningCmdLines)) {
            if ((r.startsWith(execName) || r.contains(QStringLiteral("/") + execName)) && !r.contains(QStringLiteral("--app-id"))) {
                return true;
            }
        }
        return false;
    }

    for (const QString &r : std::as_const(m_runningCmdLines)) {
        if (execName.contains(QStringLiteral("agildomonitor"))) {
            if (r.contains(QStringLiteral("agildomonitor"))) {
                return true;
            }
            continue;
        }

        if (r.startsWith(execName) || r.contains(QStringLiteral("/") + execName)) {
            return true;
        }
        if (execName.contains(QStringLiteral("faugus")) && r.contains(QStringLiteral("faugus"))) {
            return true;
        }
    }

    return false;
}

bool TaskBackend::isAppFocused(const QString &command)
{
    if (command.isEmpty()) {
        return false;
    }
    if (m_activeAppClass.trimmed().isEmpty() && m_activeAppTitle.trimmed().isEmpty()) {
        return false;
    }

    return DockWindowManagement::commandMatchesForegroundHints(command,
                                                              m_activeAppClass,
                                                              m_activeAppTitle,
                                                              knownApps);
}

QVariantMap TaskBackend::parseDropInfo(const QString &urlStr)
{
    const QUrl url(urlStr);
    const QString path = url.toLocalFile();
    QVariantMap map;

    if (!path.endsWith(QStringLiteral(".desktop"))) {
        map[QStringLiteral("error")] = QStringLiteral("Não é .desktop");
        return map;
    }

    map[QStringLiteral("desktopPath")] = path;

    QFile file(path);
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        bool foundName = false;
        bool foundIcon = false;
        bool foundCmd = false;
        bool foundWmClass = false;
        while (!in.atEnd()) {
            const QString line = in.readLine().trimmed();
            if (line == QStringLiteral("NoDisplay=true")) {
                map[QStringLiteral("nodisplay")] = true;
            } else if (!foundName && line.startsWith(QStringLiteral("Name="))) {
                map[QStringLiteral("name")] = line.mid(5);
                foundName = true;
            } else if (!foundIcon && line.startsWith(QStringLiteral("Icon="))) {
                map[QStringLiteral("icon")] = line.mid(5);
                foundIcon = true;
            } else if (!foundCmd && line.startsWith(QStringLiteral("Exec="))) {
                map[QStringLiteral("cmd")] = line.mid(5).split(QStringLiteral(" %")).first();
                foundCmd = true;
            } else if (!foundWmClass && line.startsWith(QStringLiteral("StartupWMClass="))) {
                map[QStringLiteral("wmclass")] = line.mid(15);
                foundWmClass = true;
            }
        }
        file.close();
    }
    if (!map.contains(QStringLiteral("name"))) {
        map[QStringLiteral("name")] = QStringLiteral("App");
    }
    if (!map.contains(QStringLiteral("icon"))) {
        map[QStringLiteral("icon")] = QStringLiteral("application-x-executable");
    }
    return map;
}

bool TaskBackend::shouldHideFromDock(const QString &cmd, const QString &name) const
{
    const QString c = cmd.toLower();
    const QString n = name.toLower();
    for (const QString &frag : m_userHiddenCmdFragments) {
        const QString f = frag.trimmed().toLower();
        if (!f.isEmpty() && (c.contains(f) || n.contains(f))) {
            return true;
        }
    }
    return c.contains(QStringLiteral("agildomonitor")) || n.contains(QStringLiteral("agildo monitor"))
           || c.contains(QStringLiteral("agildodock")) || n.contains(QStringLiteral("agildo dock"));
}

void TaskBackend::setUserHiddenCommands(const QStringList &cmdFragments)
{
    m_userHiddenCmdFragments = cmdFragments;
}

QString TaskBackend::windowTitleForToken(const QString &token) const
{
    if (token.isEmpty() || !m_kdotoolAvailable) {
        return {};
    }
    QProcess p;
    QStringList args{QStringLiteral("getwindowname"), token};
    if (token.startsWith(QLatin1String("x11:"))) {
        bool ok = false;
        const quint64 wid = token.sliced(4).toULongLong(&ok, 16);
        if (ok) {
            args = {QStringLiteral("getwindowname"), QStringLiteral("0x") + QString::number(wid, 16)};
        }
    }
    p.start(QStringLiteral("kdotool"), args);
    p.waitForFinished(350);
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed();
}

QVariantList TaskBackend::windowEntriesForCommand(const QString &command) const
{
    QVariantList out;
    const QStringList handles = resolveAllWindowTokens(command);
    int idx = 1;
    for (const QString &tok : handles) {
        QVariantMap row;
        row.insert(QStringLiteral("token"), tok);
        QString title = windowTitleForToken(tok);
        if (title.isEmpty()) {
            title = QObject::tr("Janela %1").arg(idx);
        }
        row.insert(QStringLiteral("title"), title);
        out.append(row);
        ++idx;
    }
    return out;
}

QString TaskBackend::plasmaCurrentActivityLabel() const
{
    QDBusInterface iface(QStringLiteral("org.kde.ActivityManager"),
                         QStringLiteral("/ActivityManager/Activities"),
                         QStringLiteral("org.kde.ActivityManager.Activities"),
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        return {};
    }
    QDBusReply<QString> current = iface.call(QStringLiteral("currentActivity"));
    if (!current.isValid() || current.value().isEmpty()) {
        return {};
    }
    const QString actId = current.value();
    QDBusInterface actIface(QStringLiteral("org.kde.ActivityManager"),
                            QStringLiteral("/ActivityManager/Activities/") + actId,
                            QStringLiteral("org.kde.ActivityManager.Activity"),
                            QDBusConnection::sessionBus());
    if (!actIface.isValid()) {
        return actId;
    }
    QDBusReply<QString> name = actIface.call(QStringLiteral("name"));
    return name.isValid() ? name.value() : actId;
}

void TaskBackend::setProcPollIntervalMs(int intervalMs)
{
    const int ms = qBound(400, intervalMs, 5000);
    if (m_pollTimer) {
        m_pollTimer->setInterval(ms);
    }
}

bool TaskBackend::saveTextFile(const QString &path, const QString &utf8Text) const
{
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return false;
    }
    f.write(utf8Text.toUtf8());
    return true;
}

QString TaskBackend::loadTextFile(const QString &path) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(f.readAll());
}

QString TaskBackend::defaultDockAppsExportPath() const
{
    return QStandardPaths::writableLocation(QStandardPaths::HomeLocation)
           + QStringLiteral("/agildodock-apps.json");
}


