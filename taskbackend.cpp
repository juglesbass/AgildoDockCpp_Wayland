#include "taskbackend.h"
#include "dock_window_management.h"

#include <QDirIterator>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QMetaObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QPainterPath>
#include <QProcessEnvironment>
#include <QRegularExpression>
#include <QRegion>
#include <QStringList>
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
    constexpr int kSystemPollIntervalMs = 1400;
    constexpr int kWindowsUpdatedCoalesceMs = 45;

    static bool debugEnabledFromEnv()
    {
        const QByteArray v = qgetenv("AGILDO_DOCK_DEBUG").trimmed();
        if (v.isEmpty()) {
            return false;
        }
        return v != "0" && v.toLower() != "false" && v.toLower() != "off";
    }

    static QStringList debugCategoriesFromEnv()
    {
        const QString raw = QString::fromUtf8(qgetenv("AGILDO_DOCK_DEBUG_CATS")).trimmed().toLower();
        if (raw.isEmpty()) {
            return {};
        }
        QStringList out;
        const QStringList parts = raw.split(',', Qt::SkipEmptyParts);
        for (const QString &p : parts) {
            const QString cat = p.trimmed();
            if (!cat.isEmpty()) {
                out << cat;
            }
        }
        return out;
    }

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

    // Atalhos de sistema que usam Dolphin com localização específica.
    static bool isDolphinScopedCommand(const QString &commandLower)
    {
        if (!commandLower.startsWith(QStringLiteral("dolphin"))) {
            return false;
        }
        return commandLower.contains(QStringLiteral("trash:/"))
            || commandLower.contains(QStringLiteral("~/downloads"))
            || commandLower.contains(QStringLiteral("/downloads"));
    }

    static bool titleLooksLikeDownloads(QStringView titleLower)
    {
        const QString t = titleLower.toString();
        return t.contains(QStringLiteral("downloads"))
            || t.contains(QStringLiteral("transfer")) // "Transferências"
            || t.contains(QStringLiteral("download"));
    }

    static bool titleLooksLikeTrash(QStringView titleLower)
    {
        const QString t = titleLower.toString();
        return t.contains(QStringLiteral("trash"))
            || t.contains(QStringLiteral("lixeira"))
            || t.contains(QStringLiteral("reciclagem"));
    }

    static bool activeDolphinMatchesScopedTarget(const QString &commandLower,
                                                 QStringView activeClassLower,
                                                 QStringView activeTitleLower)
    {
        const QString cls = activeClassLower.toString();
        if (!cls.contains(QStringLiteral("dolphin"))) {
            return false;
        }
        if (commandLower.contains(QStringLiteral("trash:/"))) {
            return titleLooksLikeTrash(activeTitleLower);
        }
        return titleLooksLikeDownloads(activeTitleLower);
    }

    static bool anyDolphinWindowMatchesScopedTarget(const QString &commandLower,
                                                    bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return false;
        }

        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            return false;
        }

        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        if (out.isEmpty()) {
            return false;
        }

        const QStringList ids = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &idRaw : ids) {
            const QString id = idRaw.trimmed();
            QProcess nameP;
            nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
            if (!nameP.waitForFinished(120)) {
                nameP.kill();
                continue;
            }
            const QString title = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
            if (title.isEmpty()) {
                continue;
            }
            if (commandLower.contains(QStringLiteral("trash:/"))) {
                if (titleLooksLikeTrash(title)) {
                    return true;
                }
            } else {
                if (titleLooksLikeDownloads(title)) {
                    return true;
                }
            }
        }
        return false;
    }

    static QString firstScopedDolphinWindowId(const QString &commandLower,
                                              bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return {};
        }
        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            return {};
        }
        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        if (out.isEmpty()) {
            return {};
        }
        const QStringList ids = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
        for (const QString &idRaw : ids) {
            const QString id = idRaw.trimmed();
            QProcess nameP;
            nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
            if (!nameP.waitForFinished(120)) {
                nameP.kill();
                continue;
            }
            const QString title = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
            if (title.isEmpty()) {
                continue;
            }
            if (commandLower.contains(QStringLiteral("trash:/"))) {
                if (titleLooksLikeTrash(title)) {
                    return id;
                }
            } else {
                if (titleLooksLikeDownloads(title)) {
                    return id;
                }
            }
        }
        return {};
    }

    static bool anyDolphinWindowExists(bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return false;
        }

        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            return false;
        }
        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        return !out.isEmpty();
    }
} // namespace

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
    m_debugLogsEnabled = debugEnabledFromEnv();
    m_kdotoolAvailable = !QStandardPaths::findExecutable(QStringLiteral("kdotool")).isEmpty();
    if (!windowManagementAvailable()) {
        qWarning() << "AgildoDock: sem kdotool nem integração X11 (KF6/KX11Extras) disponível nesta sessão Qt — foco, minimizar,"
                      "fechar e o modo «desviar» dependem dessas vias.";
    }
    if (m_debugLogsEnabled) {
        qInfo() << "AgildoDock[debug]: logs de debug ativos (AGILDO_DOCK_DEBUG)";
    }

    loadKnownApps();

    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &TaskBackend::updateSystemState);
    timer->start(kSystemPollIntervalMs);
}

bool TaskBackend::windowManagementAvailable() const
{
    return DockWindowManagement::fullForeignWindowCtlAvailable(m_kdotoolAvailable);
}

void TaskBackend::setMainWindow(QWindow *win)
{
    m_mainWindow = win;
}

QString TaskBackend::dockAppsSnapshotPath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + QStringLiteral("/dock_apps_snapshot.json");
}

QString TaskBackend::dockAppsSnapshotBackupPath()
{
    return dockAppsSnapshotPath() + QStringLiteral(".bak");
}

bool TaskBackend::saveDockAppsSnapshot(const QString &dockAppsJson) const
{
    if (dockAppsJson.trimmed().isEmpty()) {
        return false;
    }

    QJsonParseError jerr;
    QJsonDocument::fromJson(dockAppsJson.toUtf8(), &jerr);
    if (jerr.error != QJsonParseError::NoError) {
        if (m_debugLogsEnabled) {
            qWarning() << "AgildoDock[debug]: snapshot dockApps inválido, ignorando:"
                       << jerr.errorString();
        }
        return false;
    }

    const QString targetPath = dockAppsSnapshotPath();
    const QString backupPath = dockAppsSnapshotBackupPath();
    const QString targetDir = QFileInfo(targetPath).absolutePath();
    QDir().mkpath(targetDir);

    if (QFile::exists(targetPath)) {
        QFile::remove(backupPath);
        QFile::copy(targetPath, backupPath);
    }

    QSaveFile out(targetPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "AgildoDock: falha ao abrir snapshot dockApps para escrita:" << targetPath;
        return false;
    }
    out.write(dockAppsJson.toUtf8());
    if (!out.commit()) {
        qWarning() << "AgildoDock: falha ao gravar snapshot dockApps:" << targetPath;
        return false;
    }

    if (m_debugLogsEnabled) {
        qInfo() << "AgildoDock[debug]: snapshot dockApps salvo em" << targetPath;
    }
    return true;
}

QString TaskBackend::loadDockAppsSnapshot() const
{
    const QStringList paths = {dockAppsSnapshotPath(), dockAppsSnapshotBackupPath()};
    for (const QString &p : paths) {
        QFile f(p);
        if (!f.exists() || !f.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray raw = f.readAll();
        f.close();
        if (raw.trimmed().isEmpty()) {
            continue;
        }
        QJsonParseError jerr;
        QJsonDocument::fromJson(raw, &jerr);
        if (jerr.error == QJsonParseError::NoError) {
            if (m_debugLogsEnabled) {
                qInfo() << "AgildoDock[debug]: snapshot dockApps carregado de" << p;
            }
            return QString::fromUtf8(raw);
        }
    }
    return {};
}

QString TaskBackend::appDataPathForFile(const QString &relativeName)
{
    QString safe = relativeName;
    safe.replace('\\', '/');
    safe.remove(QStringLiteral(".."));
    while (safe.startsWith('/')) {
        safe.remove(0, 1);
    }
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + QLatin1Char('/') + safe;
}

bool TaskBackend::debugCategoryEnabled(const QString &category) const
{
    if (!m_debugLogsEnabled) {
        return false;
    }
    const QStringList cats = debugCategoriesFromEnv();
    if (cats.isEmpty()) {
        return true;
    }
    return cats.contains(category.trimmed().toLower());
}

bool TaskBackend::writeUserJsonFile(const QString &relativeName, const QString &jsonText) const
{
    if (relativeName.trimmed().isEmpty() || jsonText.trimmed().isEmpty()) {
        return false;
    }
    QJsonParseError err;
    QJsonDocument::fromJson(jsonText.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) {
        if (debugCategoryEnabled(QStringLiteral("persist"))) {
            qWarning() << "AgildoDock[debug][persist]: JSON inválido para" << relativeName << err.errorString();
        }
        return false;
    }
    const QString outPath = appDataPathForFile(relativeName);
    const QString outDir = QFileInfo(outPath).absolutePath();
    QDir().mkpath(outDir);
    QSaveFile out(outPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        return false;
    }
    out.write(jsonText.toUtf8());
    const bool ok = out.commit();
    if (ok && debugCategoryEnabled(QStringLiteral("persist"))) {
        qInfo() << "AgildoDock[debug][persist]: arquivo salvo" << outPath;
    }
    return ok;
}

QString TaskBackend::readUserJsonFile(const QString &relativeName) const
{
    if (relativeName.trimmed().isEmpty()) {
        return {};
    }
    const QString inPath = appDataPathForFile(relativeName);
    QFile in(inPath);
    if (!in.exists() || !in.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QByteArray raw = in.readAll();
    in.close();
    if (raw.trimmed().isEmpty()) {
        return {};
    }
    QJsonParseError err;
    QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError) {
        if (debugCategoryEnabled(QStringLiteral("persist"))) {
            qWarning() << "AgildoDock[debug][persist]: JSON inválido em" << inPath << err.errorString();
        }
        return {};
    }
    return QString::fromUtf8(raw);
}

void TaskBackend::debugLog(const QString &category, const QString &message) const
{
    const QString cat = category.trimmed().toLower();
    if (!debugCategoryEnabled(cat)) {
        return;
    }
    qInfo() << "AgildoDock[debug][" + cat + "]:" << message;
}

void TaskBackend::emitWindowsUpdatedCoalesced()
{
    if (m_windowsUpdatedPending) {
        return;
    }
    m_windowsUpdatedPending = true;
    QTimer::singleShot(kWindowsUpdatedCoalesceMs, this, [this]() {
        m_windowsUpdatedPending = false;
        emit windowsUpdated();
    });
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
        emitWindowsUpdatedCoalesced();
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
                emitWindowsUpdatedCoalesced();
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
                emitWindowsUpdatedCoalesced();

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
                emitWindowsUpdatedCoalesced();
            }
            return;
        }

        if (dockItemMatchesForeground) {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowminimize"), winToken});
            m_activeAppClass.clear();
            m_activeAppTitle.clear();
            emitWindowsUpdatedCoalesced();
        } else {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), winToken});
            m_activeAppClass = execBasenameFromCommand(command);
            emitWindowsUpdatedCoalesced();
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
    // Downloads/Lixeira: comportamento de atalho de pasta.
    // - se já estiver em foco: minimiza (paridade com ícone normal do Dolphin)
    // - caso contrário: abre nova janela nessa localização
    if (isDolphinScopedCommand(command.toLower())) {
        const QString scopedLower = command.toLower();
        if (isAppFocused(command) && m_kdotoolAvailable) {
            QProcess::startDetached(QStringLiteral("kdotool"),
                                    {QStringLiteral("getactivewindow"), QStringLiteral("windowminimize")});
            m_activeAppClass.clear();
            m_activeAppTitle.clear();
            emitWindowsUpdatedCoalesced();
            return;
        }
        const QString existingWin = firstScopedDolphinWindowId(scopedLower, m_kdotoolAvailable);
        if (!existingWin.isEmpty() && m_kdotoolAvailable) {
            QProcess::startDetached(QStringLiteral("kdotool"),
                                    {QStringLiteral("windowactivate"), existingWin});
            return;
        }
        forceLaunchApp(command);
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

void TaskBackend::completeCloseApp(const QString &command, const QString &winToken)
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
    qWarning() << "AgildoDock: não foi possível fechar app (janela não encontrada):" << command;
}

void TaskBackend::closeApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }
    const QString cmdCopy = command;
    const quint64 seq = ++m_closeSeq[cmdCopy];
    (void)QtConcurrent::run([this, cmdCopy, seq]() {
        const QString winId = resolveWindowTokenForLaunch(cmdCopy);
        QMetaObject::invokeMethod(
            this,
            [this, cmdCopy, winId, seq]() {
                if (m_closeSeq.value(cmdCopy) != seq) {
                    return;
                }
                completeCloseApp(cmdCopy, winId);
            },
            Qt::QueuedConnection);
    });
}

bool TaskBackend::isAppRunning(const QString &command)
{
    if (command.isEmpty()) {
        return false;
    }

    const QString cmdLower = command.toLower();
    // Downloads/Lixeira não devem acender com "qualquer Dolphin" aberto.
    // Considera ativo quando existe janela do alvo específico (mesmo minimizada).
    if (isDolphinScopedCommand(cmdLower)) {
        return anyDolphinWindowMatchesScopedTarget(cmdLower, m_kdotoolAvailable);
    }

    QString execName = command.split(' ').first().split('/').last().toLower();
    execName.remove('"').remove('\'');

    // Evita falso positivo: o processo do Dolphin pode continuar vivo sem janela aberta.
    if (execName == QStringLiteral("dolphin")) {
        if (m_kdotoolAvailable) {
            return anyDolphinWindowExists(m_kdotoolAvailable);
        }
    }

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

    const QString cmdLower = command.toLower();
    if (isDolphinScopedCommand(cmdLower)) {
        return activeDolphinMatchesScopedTarget(cmdLower, m_activeAppClass, m_activeAppTitle);
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
    // CORREÇÃO: Impede a doca de aparecer nela mesma
    return c.contains(QStringLiteral("agildomonitor")) || n.contains(QStringLiteral("agildo monitor")) ||
    c.contains(QStringLiteral("agildodock")) || n.contains(QStringLiteral("agildo dock"));
}


