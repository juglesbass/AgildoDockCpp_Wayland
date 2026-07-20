#include "taskbackend.h"
#include "dock_browser_utils.h"
#include "dock_window_management.h"
#include "dock_browser_integration.h"

#include <QDateTime>
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
#include <QXmlStreamReader>
#include <QtConcurrent/QtConcurrentRun>
#include <utility>

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>

#include <LayerShellQt/Window>
#include <KWindowEffects>

#include <QElapsedTimer>

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
    constexpr int kWindowCountCacheTtlMs = 2500;
    constexpr int kSniBadgePollMs = 6000;

    struct WindowCountCacheEntry {
        int count = 0;
        qint64 timestampMs = 0;
    };
    static QHash<QString, WindowCountCacheEntry> s_windowCountCache;

    static bool isLactCommand(const QString &cmd)
    {
        const QString c = cmd.trimmed().toLower();
        const QString exec = c.split(QLatin1Char(' ')).constFirst().section(QLatin1Char('/'), -1);
        return exec == QLatin1String("lact");
    }

    static bool debugEnabledFromEnv()
    {
        const QByteArray v = qgetenv("AGILDO_DOCK_DEBUG").trimmed();
        if (v.isEmpty()) {
            return false;
        }
        return v != "0" && v.toLower() != "false" && v.toLower() != "off";
    }

    /// Nome do executável (ex.: "/usr/bin/chromium" → "chromium").
    static QString execBasename(const QString &cmd)
    {
        QString token = cmd.trimmed().toLower();
        if (token.isEmpty()) {
            return token;
        }
        token = token.split(QLatin1Char(' ')).first();
        const int slash = token.lastIndexOf(QLatin1Char('/'));
        if (slash >= 0) {
            token = token.mid(slash + 1);
        }
        token.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
        return token;
    }

    static bool pinnedContainsCommand(const QSet<QString> &pinnedCmds, const QString &matchCmd)
    {
        if (pinnedCmds.contains(matchCmd)) {
            return true;
        }
        const QString matchExec = execBasename(matchCmd);
        if (matchExec.isEmpty()) {
            return false;
        }
        for (const QString &pinned : pinnedCmds) {
            if (execBasename(pinned) == matchExec) {
                return true;
            }
        }
        return false;
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
        return t.contains(QStringLiteral("download"))   // EN / PT / DE
            || t.contains(QStringLiteral("transfer"))   // PT "Transferências"
            || t.contains(QStringLiteral("télécharg"))  // FR "Téléchargements"
            || t.contains(QStringLiteral("descargas"))  // ES
            || t.contains(QStringLiteral("scaricati"))  // IT
            || t.contains(QStringLiteral("scarica"))    // IT alternativo
            || t.contains(QStringLiteral("herunterlad")); // DE "Herunterladen"
    }

    static bool titleLooksLikeTrash(QStringView titleLower)
    {
        const QString t = titleLower.toString();
        return t.contains(QStringLiteral("trash"))      // EN
            || t.contains(QStringLiteral("lixeira"))    // PT-BR
            || t.contains(QStringLiteral("reciclagem")) // PT-PT
            || t.contains(QStringLiteral("papierkorb")) // DE
            || t.contains(QStringLiteral("corbeille"))  // FR
            || t.contains(QStringLiteral("papelera"))   // ES
            || t.contains(QStringLiteral("cestino"));   // IT
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

    // Cache de janelas Dolphin por ciclo de poll: evita múltiplas chamadas kdotool bloqueantes
    // quando há vários ícones Dolphin scoped (Downloads + Lixeira) no mesmo ciclo de 1,4 s.
    struct DolphinWindowCache {
        QStringList ids;
        QStringList titlesLower;
        bool valid = false;
        qint64 timestampMs = 0;
    };
    static DolphinWindowCache s_dolphinCache;
    constexpr qint64 kDolphinWindowCacheTtlMs = 1800;

    // Preenche/renova o cache de IDs+títulos Dolphin se necessário.
    static DolphinWindowCache fetchDolphinWindowCache(bool kdotoolAvailable)
    {
        DolphinWindowCache cache;
        if (!kdotoolAvailable) {
            return cache;
        }

        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            return cache;
        }

        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList rawIds = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
            for (const QString &idRaw : rawIds) {
                const QString id = idRaw.trimmed();
                if (id.isEmpty()) {
                    continue;
                }
                QProcess nameP;
                nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
                if (!nameP.waitForFinished(120)) {
                    nameP.kill();
                    continue;
                }
                const QString title = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
                cache.ids << id;
                cache.titlesLower << title;
            }
        }
        return cache;
    }

    static bool anyDolphinWindowMatchesScopedTarget(const QString &commandLower,
                                                    bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return false;
        }
        

        const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
        for (const QString &title : std::as_const(s_dolphinCache.titlesLower)) {
            if (title.isEmpty()) {
                continue;
            }
            if (isTrash ? titleLooksLikeTrash(title) : titleLooksLikeDownloads(title)) {
                return true;
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
        // Ao lançar app, invalida o cache para obter IDs frescos.
        
        

        const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
        for (int i = 0; i < s_dolphinCache.ids.size(); ++i) {
            const QString &title = s_dolphinCache.titlesLower.value(i);
            if (title.isEmpty()) {
                continue;
            }
            if (isTrash ? titleLooksLikeTrash(title) : titleLooksLikeDownloads(title)) {
                return s_dolphinCache.ids.at(i);
            }
        }
        return {};
    }

    static QStringList allScopedDolphinWindowIds(const QString &commandLower,
                                                 bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return {};
        }
        
        

        QStringList ids;
        const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
        for (int i = 0; i < s_dolphinCache.ids.size(); ++i) {
            const QString &title = s_dolphinCache.titlesLower.value(i);
            if (title.isEmpty()) {
                continue;
            }
            if (isTrash ? titleLooksLikeTrash(title) : titleLooksLikeDownloads(title)) {
                ids << s_dolphinCache.ids.at(i);
            }
        }
        return ids;
    }

    static bool anyDolphinWindowExists(bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return false;
        }
        
        return !s_dolphinCache.ids.isEmpty();
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
    return DockBrowserUtils::execBasenameFromCommand(command);
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
    ensurePlasmaBrowserIntegrationHosts();

    setupNotificationBadgeWatcher();
    setupUnityLauncherProgressWatcher();
    setupBrowserDownloadWatcher();

    m_progressNotifyTimer = new QTimer(this);
    m_progressNotifyTimer->setSingleShot(true);
    m_progressNotifyTimer->setInterval(16);
    connect(m_progressNotifyTimer, &QTimer::timeout, this, [this]() {
        const QSet<QString> cmds = std::exchange(m_pendingProgressNotifyCmds, {});
        for (const QString &cmd : cmds) {
            emit launcherProgressForCommandChanged(cmd);
        }
    });

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
    if (win) {
        connect(win, &QWindow::widthChanged, this, [this] { m_hasLastBlur = false; });
        connect(win, &QWindow::heightChanged, this, [this] { m_hasLastBlur = false; });
    }
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

void TaskBackend::applyLayerShellEdge(int edge)
{
    if (!m_mainWindow) {
        return;
    }
    LayerShellQt::Window *layerWindow = LayerShellQt::Window::get(m_mainWindow);
    if (!layerWindow) {
        return;
    }
    LayerShellQt::Window::Anchors anchor;
    switch (edge) {
        case 1:  anchor = LayerShellQt::Window::AnchorTop;    break;
        case 2:  anchor = LayerShellQt::Window::AnchorLeft;   break;
        case 3:  anchor = LayerShellQt::Window::AnchorRight;  break;
        default: anchor = LayerShellQt::Window::AnchorBottom; break;
    }
    layerWindow->setAnchors(anchor);
    m_mainWindow->requestUpdate();
}

// CORREÇÃO: Função assíncrona para não travar a interface da doca
void TaskBackend::updateActiveWindowCoversWorkAreaHint()
{
    if (!m_kdotoolAvailable || !m_mainWindow || !m_mainWindow->screen()) {
        return;
    }

    auto *pg = new QProcess(this);
    connect(pg, &QProcess::errorOccurred, pg, &QProcess::deleteLater);
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
    connect(p, &QProcess::errorOccurred, p, &QProcess::deleteLater);
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
                    
                    const QSize windowSize = parseWindowGeometryFromKdotool(out);
                    if (m_mainWindow && m_mainWindow->screen()) {
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
                    }
                }
                p->deleteLater();
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
              QStringLiteral("getwindowname"),
              QStringLiteral("getwindowgeometry")});
}

void TaskBackend::updateSystemState()
{
    if (m_procScanRunning) {
        return;
    }
    m_procScanRunning = true;
    // Invalida o cache Dolphin no início de cada ciclo para que isAppRunning
    // popule dados frescos na primeira consulta do ciclo.
    
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
        
        bool hasDolphinProcess = false;
        for (const QString &cmd : std::as_const(next)) {
            if (cmd.startsWith(QStringLiteral("dolphin")) || cmd.contains(QStringLiteral("/dolphin"))) {
                hasDolphinProcess = true;
                break;
            }
        }
        
        DolphinWindowCache newDolphinWindowCache;
        if (hasDolphinProcess) {
            newDolphinWindowCache = fetchDolphinWindowCache(m_kdotoolAvailable);
        }
        
        QMetaObject::invokeMethod(
            this,
            [this, next, newDolphinWindowCache]() {
                s_dolphinCache = newDolphinWindowCache;
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

void TaskBackend::setBlurRegion(int x, int y, int w, int h, int radius, bool immediate)
{
    m_pendingBlurX = x;
    m_pendingBlurY = y;
    m_pendingBlurW = w;
    m_pendingBlurH = h;
    m_pendingBlurRadius = radius;

    if (immediate) {
        m_blurFlushPending = false;
        flushBlurRegion();
        return;
    }

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

    // Ignora frames fantasmas ou layout inválido vindo do QML
    if (m_pendingBlurW < 10 || m_pendingBlurH < 10) {
        return;
    }

    int safeX = qMax(0, m_pendingBlurX);
    int safeY = qMax(0, m_pendingBlurY);
    int adjW = m_pendingBlurW - (safeX - m_pendingBlurX);
    int adjH = m_pendingBlurH - (safeY - m_pendingBlurY);

    int safeW = qBound(0, adjW, m_mainWindow->width() - safeX);
    int safeH = qBound(0, adjH, m_mainWindow->height() - safeY);

    if (safeW < 10 || safeH < 10) {
        return;
    }

    const int winW = m_mainWindow->width();
    const int winH = m_mainWindow->height();
    if (safeW >= winW - 4 && safeH >= winH - 4) {
        return;
    }

    // Mesmo retângulo visual — sem expandir (expansão criava “fade”/halo em toda a borda).
    // +1 no raio cobre o AA dos cantos sem blur a extravasar nas arestas retas.
    const int radius = qBound(0, m_pendingBlurRadius + 1, qMin(safeW, safeH) / 2);

    if (m_hasLastBlur && m_lastBlurX == safeX && m_lastBlurY == safeY
        && m_lastBlurW == safeW && m_lastBlurH == safeH && m_lastBlurRadius == radius) {
        return;
    }

    m_hasLastBlur = true;
    m_lastBlurX = safeX;
    m_lastBlurY = safeY;
    m_lastBlurW = safeW;
    m_lastBlurH = safeH;
    m_lastBlurRadius = radius;

    // Polígono arredondado; dimensões inteiras evitam cantos “partidos” no KWin
    QPainterPath path;
    path.addRoundedRect(QRectF(safeX, safeY, safeW, safeH), radius, radius);
    QPolygon poly = path.toFillPolygon().toPolygon();
    if (poly.isEmpty()) {
        return;
    }
    KWindowEffects::enableBlurBehind(m_mainWindow, true, QRegion(poly));
}

void TaskBackend::clearBlurRegion()
{
    m_blurFlushPending = false;
    m_hasLastBlur = false;
    m_pendingBlurW = 0;
    m_pendingBlurH = 0;
    if (!m_mainWindow) {
        return;
    }
    KWindowEffects::enableBlurBehind(m_mainWindow, false);
}

void TaskBackend::loadKnownApps()
{
    QStringList sysPaths = {QStringLiteral("/usr/share/applications"), QStringLiteral("/usr/local/share/applications")};
    const QString homePath = QProcessEnvironment::systemEnvironment().value(QStringLiteral("HOME"))
    + QStringLiteral("/.local/share/applications");
    sysPaths << homePath;

    const QStringList blacklist = {
        QStringLiteral("discord"), QStringLiteral("telegram-desktop"),
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
    m_desktopBasenameToCmd.clear();
    m_desktopEntryToCmd.clear();
    m_execBasenameToCmd.clear();
    for (auto it = knownApps.constBegin(); it != knownApps.constEnd(); ++it) {
        const QString cmd = it.key();
        const QVariantMap &app = it.value();
        const QString appExec = execBasenameFromCommand(cmd);
        if (!appExec.isEmpty()) {
            m_appsByExec.insert(appExec, app);
            if (!m_execBasenameToCmd.contains(appExec)) {
                m_execBasenameToCmd.insert(appExec, cmd);
            }
        }
        const QString desktopPath = app.value(QStringLiteral("desktopPath")).toString();
        if (desktopPath.isEmpty()) {
            continue;
        }
        const QString baseName = QFileInfo(desktopPath).fileName().toLower();
        if (!m_desktopBasenameToCmd.contains(baseName)) {
            m_desktopBasenameToCmd.insert(baseName, cmd);
        }
        QString entryId = baseName;
        if (entryId.endsWith(QStringLiteral(".desktop"))) {
            entryId.chop(8);
        }
        if (!m_desktopEntryToCmd.contains(entryId.toLower())) {
            m_desktopEntryToCmd.insert(entryId.toLower(), cmd);
        }
    }
    updateBrowserDownloadCommand();
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

    if (DockBrowserUtils::commandLooksLikeBrowser(appExec)) {
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
        if (pinnedContainsCommand(pinnedCmds, matchCmd) || addedCmds.contains(matchCmd)) {
            continue;
        }
        if (isLactCommand(matchCmd) && m_kdotoolAvailable && !lactHasVisibleWindow(matchCmd)) {
            continue;
        }
        unpinned.append(bestMatch);
        addedCmds.insert(matchCmd);
    }
    return unpinned;
}

bool TaskBackend::lactHasVisibleWindow(const QString &command) const
{
    if (!m_kdotoolAvailable) {
        return true;
    }
    QString lactCmd = command;
    if (!knownApps.contains(lactCmd)) {
        for (auto it = knownApps.constBegin(); it != knownApps.constEnd(); ++it) {
            if (isLactCommand(it.key())) {
                lactCmd = it.key();
                break;
            }
        }
    }
    if (lactCmd.isEmpty()) {
        lactCmd = QStringLiteral("lact gui");
    }
    
    // Usa o const_cast para aproveitar a função assíncrona appWindowCount
    return const_cast<TaskBackend*>(this)->appWindowCount(lactCmd) > 0;
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

// Clique no ícone já focado: overview estilo macOS via Window View do KWin.
bool TaskBackend::tryShowAppWindowOverview(const QString &command)
{
    if (command.isEmpty() || !m_windowOverviewOnRefocus) {
        return false;
    }

    QStringList handles = windowHandlesForCommand(command);

    if (handles.isEmpty() || handles.size() < 2) {
        return false;
    }
    return DockWindowManagement::activateKWinWindowView(handles);
}

QStringList TaskBackend::windowHandlesForCommand(const QString &command)
{
    if (command.isEmpty()) {
        return {};
    }
    if (isDolphinScopedCommand(command.toLower())) {
        return allScopedDolphinWindowIds(command.toLower(), m_kdotoolAvailable);
    }
    return DockWindowManagement::resolveAllWindowHandlesForLaunch(command,
                                                                  knownApps,
                                                                  m_kdotoolAvailable,
                                                                  kKdotoolTimeoutMs);
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
            if (dockItemMatchesForeground) {
                if (tryShowAppWindowOverview(command)) {
                    emitWindowsUpdatedCoalesced();
                    return;
                }
            }
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
            if (tryShowAppWindowOverview(command)) {
                emitWindowsUpdatedCoalesced();
                return;
            }
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
            if (tryShowAppWindowOverview(command)) {
                emitWindowsUpdatedCoalesced();
                return;
            }
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

    if (isLactCommand(command)) {
        bool procRunning = false;
        for (const QString &r : std::as_const(m_runningCmdLines)) {
            if (r.startsWith(execName) || r.contains(QStringLiteral("/") + execName)) {
                procRunning = true;
                break;
            }
        }
        if (!procRunning) {
            return false;
        }
        return lactHasVisibleWindow(command);
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

void TaskBackend::setWindowOverviewOnRefocus(bool enabled)
{
    if (m_windowOverviewOnRefocus == enabled) {
        return;
    }
    m_windowOverviewOnRefocus = enabled;
    emit windowOverviewOnRefocusChanged();
}

int TaskBackend::appWindowCount(const QString &command)
{
    if (command.isEmpty()) {
        return 0;
    }
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const auto it = s_windowCountCache.constFind(command);
    if (it != s_windowCountCache.cend() && (nowMs - it->timestampMs) < kWindowCountCacheTtlMs) {
        return it->count;
    }
    
    // Atualiza o TTL temporariamente para evitar múltiplas chamadas simultâneas
    int lastCount = (it != s_windowCountCache.cend()) ? it->count : 0;
    s_windowCountCache.insert(command, WindowCountCacheEntry{lastCount, nowMs});
    
    (void)QtConcurrent::run([this, command]() {
        const QStringList handles = windowHandlesForCommand(command);
        const int count = handles.size();
        
        QMetaObject::invokeMethod(this, [this, command, count]() {
            s_windowCountCache.insert(command, WindowCountCacheEntry{count, QDateTime::currentMSecsSinceEpoch()});
            emitWindowsUpdatedCoalesced();
        });
    });
    
    return lastCount;
}

void TaskBackend::cycleAppWindows(const QString &command, int direction)
{
    if (command.isEmpty() || direction == 0 || !m_kdotoolAvailable) {
        return;
    }
    
    (void)QtConcurrent::run([this, command, direction]() {
        const QStringList handles = windowHandlesForCommand(command);
        if (handles.isEmpty()) {
            return;
        }
        if (handles.size() == 1) {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.first()});
            return;
        }

        QString activeHandle;
        QProcess activeP;
        activeP.start(QStringLiteral("kdotool"), {QStringLiteral("getactivewindow")});
        if (activeP.waitForFinished(kKdotoolTimeoutMs)) {
            activeHandle = QString::fromUtf8(activeP.readAllStandardOutput()).trimmed();
        }

        int idx = handles.indexOf(activeHandle);
        if (idx < 0) {
            idx = 0;
        } else {
            idx = (idx + (direction > 0 ? 1 : handles.size() - 1)) % handles.size();
        }
        QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.at(idx)});
    });
}

void TaskBackend::adjustVolume(int deltaSteps)
{
    if (deltaSteps == 0) {
        return;
    }
    const QString sign = deltaSteps > 0 ? QStringLiteral("+") : QStringLiteral("-");
    const QString step = QString::number(qAbs(deltaSteps) * 5) + sign + QStringLiteral("%");
    if (!QStandardPaths::findExecutable(QStringLiteral("wpctl")).isEmpty()) {
        QProcess::startDetached(QStringLiteral("wpctl"),
                                {QStringLiteral("set-volume"),
                                 QStringLiteral("@DEFAULT_AUDIO_SINK@"),
                                 step});
        return;
    }
    if (!QStandardPaths::findExecutable(QStringLiteral("pactl")).isEmpty()) {
        QProcess::startDetached(QStringLiteral("pactl"),
                                {QStringLiteral("set-sink-volume"),
                                 QStringLiteral("@DEFAULT_SINK@"),
                                 step});
    }
}

void TaskBackend::adjustBrightness(int deltaSteps)
{
    if (deltaSteps == 0) {
        return;
    }
    QDBusInterface iface(QStringLiteral("org.kde.Solid.PowerManagement"),
                         QStringLiteral("/org/kde/Solid/PowerManagement/Actions/BrightnessControl"),
                         QStringLiteral("org.kde.Solid.PowerManagement.Actions.BrightnessControl"),
                         QDBusConnection::sessionBus());
    if (!iface.isValid()) {
        return;
    }
    const int current = iface.property("brightness").toInt();
    const int step = qMax(1, iface.property("brightnessSteps").toInt() / 20);
    const int next = qBound(iface.property("brightnessMin").toInt(),
                            current + (deltaSteps * step),
                            iface.property("brightnessMax").toInt());
    iface.call(QStringLiteral("setBrightness"), next);
}

static bool recentMatchesCommand(const QString &command, const QString &href, const QString &title)
{
    const QString cmdLower = command.toLower();
    const QString hrefLower = href.toLower();
    const QString titleLower = title.toLower();

    if (cmdLower.contains(QStringLiteral("dolphin")) || cmdLower.contains(QStringLiteral("org.kde.dolphin"))) {
        return hrefLower.startsWith(QStringLiteral("file:"));
    }
    if (cmdLower.contains(QStringLiteral("firefox"))
        || cmdLower.contains(QStringLiteral("chrom"))
        || cmdLower.contains(QStringLiteral("zen"))
        || cmdLower.contains(QStringLiteral("brave"))) {
        return hrefLower.startsWith(QStringLiteral("http:")) || hrefLower.startsWith(QStringLiteral("https:"));
    }
    if (cmdLower.contains(QStringLiteral("kate")) || cmdLower.contains(QStringLiteral("kwrite"))) {
        return hrefLower.endsWith(QStringLiteral(".txt")) || hrefLower.endsWith(QStringLiteral(".md"))
               || titleLower.contains(QStringLiteral(".txt")) || titleLower.contains(QStringLiteral(".md"));
    }
    return false;
}

QVariantList TaskBackend::recentItemsForCommand(const QString &command, int maxItems)
{
    QVariantList out;
    if (command.isEmpty() || maxItems <= 0) {
        return out;
    }

    const QString xbelPath =
        QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + QStringLiteral("/recently-used.xbel");
    QFile file(xbelPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return out;
    }

    QXmlStreamReader xml(&file);
    QString currentHref;
    QString currentTitle;
    QVariantList allMatches;
    while (!xml.atEnd()) {
        xml.readNext();
        if (xml.isStartElement() && xml.name() == QLatin1String("bookmark")) {
            currentHref = xml.attributes().value(QStringLiteral("href")).toString();
            currentTitle.clear();
        } else if (xml.isStartElement() && xml.name() == QLatin1String("title")) {
            currentTitle = xml.readElementText(QXmlStreamReader::SkipChildElements).trimmed();
        } else if (xml.isEndElement() && xml.name() == QLatin1String("bookmark")) {
            if (!currentHref.isEmpty() && recentMatchesCommand(command, currentHref, currentTitle)) {
                QVariantMap item;
                // Se não houver título, extraímos apenas o nome do arquivo da URL para ficar mais limpo
                item.insert(QStringLiteral("label"), currentTitle.isEmpty() ? QUrl(currentHref).fileName() : currentTitle);
                item.insert(QStringLiteral("url"), currentHref);
                allMatches << item;
            }
            currentHref.clear();
            currentTitle.clear();
        }
    }
    
    // Os mais recentes ficam no final do arquivo XBEL, então pegamos do fim para o começo
    for (int i = allMatches.size() - 1; i >= qMax(0, allMatches.size() - maxItems); --i) {
        out << allMatches[i];
    }
    return out;
}

void TaskBackend::setupNotificationBadgeWatcher()
{
    QDBusMessage reg = QDBusMessage::createMethodCall(QStringLiteral("org.freedesktop.Notifications"),
                                                      QStringLiteral("/org/freedesktop/Notifications"),
                                                      QStringLiteral("org.kde.NotificationManager"),
                                                      QStringLiteral("RegisterWatcher"));
    QDBusConnection::sessionBus().call(reg, QDBus::NoBlock);

    m_sniBadgeTimer = new QTimer(this);
    m_sniBadgeTimer->setInterval(kSniBadgePollMs);
    connect(m_sniBadgeTimer, &QTimer::timeout, this, &TaskBackend::refreshNotificationBadgesFromSni);
    m_sniBadgeTimer->start();
    refreshNotificationBadgesFromSni();
}

void TaskBackend::refreshNotificationBadgesFromSni()
{
    // Cópia thread-safe dos apps conhecidos
    const QHash<QString, QVariantMap> currentKnownApps = knownApps;

    (void)QtConcurrent::run([this, currentKnownApps]() {
        QVariantMap nextBadges;
        const QStringList services = QDBusConnection::sessionBus().interface()->registeredServiceNames();

        for (const QString &service : services) {
            if (!service.startsWith(QLatin1String("org.kde.StatusNotifierItem-"))) {
                continue;
            }
            const QString path = QStringLiteral("/StatusNotifierItem");
            QDBusInterface item(service, path, QStringLiteral("org.kde.StatusNotifierItem"), QDBusConnection::sessionBus());
            if (!item.isValid()) {
                continue;
            }

            const QString desktopId = item.property("Id").toString().toLower();
            const QString category = item.property("Category").toString();
            if (category == QLatin1String("SystemServices")) {
                continue;
            }

            int badge = 0;
            if (item.property("NeedsAttention").toBool()) {
                badge = 1;
            }
            const QString overlay = item.property("OverlayIconName").toString();
            if (!overlay.isEmpty() && overlay.contains(QLatin1String("attention"), Qt::CaseInsensitive)) {
                badge = qMax(badge, 1);
            }
            const QString title = item.property("Title").toString();
            static const QRegularExpression countRe(QStringLiteral(R"((\d+))"));
            const QRegularExpressionMatch m = countRe.match(title);
            if (m.hasMatch()) {
                badge = qMax(badge, m.captured(1).toInt());
            }
            if (badge <= 0) {
                continue;
            }

            for (auto it = currentKnownApps.constBegin(); it != currentKnownApps.constEnd(); ++it) {
                const QString cmd = it.key();
                const QVariantMap app = it.value();
                const QString wm = app.value(QStringLiteral("wmclass")).toString().toLower();
                const QString name = app.value(QStringLiteral("name")).toString().toLower();
                if ((!desktopId.isEmpty() && (cmd.toLower().contains(desktopId) || wm.contains(desktopId)
                                              || desktopId.contains(execBasenameFromCommand(cmd))))
                    || (!name.isEmpty() && title.toLower().contains(name))) {
                    nextBadges.insert(cmd, badge);
                    break;
                }
            }
        }

        QMetaObject::invokeMethod(this, [this, nextBadges]() {
            if (nextBadges != m_notificationBadges) {
                m_notificationBadges = nextBadges;
                emit notificationBadgesChanged();
            }
        });
    });
}

