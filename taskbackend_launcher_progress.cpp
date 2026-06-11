#include "taskbackend.h"
#include "dock_unity_launcher.h"
#include "dock_browser_integration.h"
#include "dock_browser_downloads.h"
#include "dock_browser_utils.h"

#include <QFileInfo>
#include <QMimeDatabase>
#include <QMimeType>
#include <algorithm>
#include <utility>

namespace {

QString downloadsDockCommand()
{
    return QStringLiteral("dolphin ~/Downloads");
}

} // namespace

QString TaskBackend::iconThemeForDownloadFile(const QString &filePath)
{
    if (filePath.isEmpty()) {
        return {};
    }

    const QString suffix = QFileInfo(filePath).suffix().toLower();
    static const QHash<QString, QString> suffixIcons = {
        {QStringLiteral("pdf"), QStringLiteral("application-pdf")},
        {QStringLiteral("zip"), QStringLiteral("application-zip")},
        {QStringLiteral("7z"), QStringLiteral("application-x-7z-compressed")},
        {QStringLiteral("rar"), QStringLiteral("application-vnd.rar")},
        {QStringLiteral("tar"), QStringLiteral("application-x-tar")},
        {QStringLiteral("gz"), QStringLiteral("application-gzip")},
        {QStringLiteral("xz"), QStringLiteral("application-x-xz")},
        {QStringLiteral("deb"), QStringLiteral("application-vnd.debian-package")},
        {QStringLiteral("rpm"), QStringLiteral("application-x-rpm")},
        {QStringLiteral("mp4"), QStringLiteral("video-mp4")},
        {QStringLiteral("mkv"), QStringLiteral("video-x-matroska")},
        {QStringLiteral("webm"), QStringLiteral("video-webm")},
        {QStringLiteral("mp3"), QStringLiteral("audio-mpeg")},
        {QStringLiteral("flac"), QStringLiteral("audio-x-flac")},
        {QStringLiteral("png"), QStringLiteral("image-png")},
        {QStringLiteral("jpg"), QStringLiteral("image-jpeg")},
        {QStringLiteral("jpeg"), QStringLiteral("image-jpeg")},
        {QStringLiteral("gif"), QStringLiteral("image-gif")},
        {QStringLiteral("webp"), QStringLiteral("image-webp")},
        {QStringLiteral("svg"), QStringLiteral("image-svg+xml")},
        {QStringLiteral("iso"), QStringLiteral("application-x-cd-image")},
        {QStringLiteral("appimage"), QStringLiteral("application-x-executable")},
        {QStringLiteral("exe"), QStringLiteral("application-x-ms-dos-executable")},
        {QStringLiteral("msi"), QStringLiteral("application-x-msi")},
        {QStringLiteral("torrent"), QStringLiteral("application-x-bittorrent")},
        {QStringLiteral("apk"), QStringLiteral("android-package-archive")},
    };
    const auto mapped = suffixIcons.constFind(suffix);
    if (mapped != suffixIcons.constEnd()) {
        return mapped.value();
    }

    QMimeDatabase db;
    const QMimeType mime = db.mimeTypeForFile(filePath, QMimeDatabase::MatchExtension);
    const QString mimeIcon = mime.iconName();
    if (!mimeIcon.isEmpty() && mimeIcon != QLatin1String("text-x-generic")
        && mimeIcon != QLatin1String("application-octet-stream")) {
        return mimeIcon;
    }

    // Genérico do KDE — melhor que "unknown" (ícone cinza com ?)
    return QStringLiteral("package-x-generic");
}

void TaskBackend::enrichLauncherProgressEntry(QVariantMap &entry) const
{
    entry.remove(QStringLiteral("progressFilePath"));
    entry.remove(QStringLiteral("progressFileName"));
    entry.remove(QStringLiteral("progressIcon"));

    if (m_downloadProgressDisplayMode != 2) {
        return;
    }
    if (!entry.value(QStringLiteral("progressVisible")).toBool()) {
        return;
    }

    if (m_browserDownloadWatcher) {
        m_browserDownloadWatcher->refreshActiveDownloadScan();
    }

    QString filePath = entry.value(QStringLiteral("progressFilePathHint")).toString().trimmed();
    QString fileName = entry.value(QStringLiteral("progressFileNameHint")).toString().trimmed();
    entry.remove(QStringLiteral("progressFilePathHint"));
    entry.remove(QStringLiteral("progressFileNameHint"));

    if (filePath.isEmpty() && m_browserDownloadWatcher) {
        filePath = m_browserDownloadWatcher->activeDownloadFilePath();
        fileName = m_browserDownloadWatcher->activeDownloadFileName();
    }

    if (!filePath.isEmpty()) {
        entry.insert(QStringLiteral("progressFilePath"), filePath);
        if (fileName.isEmpty()) {
            fileName = QFileInfo(filePath).fileName();
        }
        entry.insert(QStringLiteral("progressFileName"), fileName);
        const QString iconTheme = iconThemeForDownloadFile(filePath);
        if (!iconTheme.isEmpty()) {
            entry.insert(QStringLiteral("progressIcon"), iconTheme);
        }
    }
}

void TaskBackend::setDownloadProgressDisplayMode(int mode)
{
    const int clamped = qBound(0, mode, 2);
    if (m_downloadProgressDisplayMode == clamped) {
        return;
    }
    m_downloadProgressDisplayMode = clamped;

    const QStringList affected = m_launcherProgress.keys();
    m_launcherProgress.clear();
    for (const QString &cmd : affected) {
        emit launcherProgressForCommandChanged(cmd);
    }
    if (m_browserDownloadWatcher) {
        m_browserDownloadWatcher->resetLastEmittedState();
    }
}

void TaskBackend::setupUnityLauncherProgressWatcher()
{
    m_unityLauncher = new DockUnityLauncherService(this);
    m_unityLauncher->setDesktopMaps(&m_desktopBasenameToCmd, &m_desktopEntryToCmd);
    connect(m_unityLauncher,
            &DockUnityLauncherService::launcherUpdateReceived,
            this,
            &TaskBackend::mergeUnityLauncherUpdate);
    m_unityLauncher->rescanExistingLauncherEntries();

    if (m_debugLogsEnabled) {
        qInfo() << "AgildoDock[debug]: Unity com.canonical.Unity"
                << (m_unityLauncher->unityServiceRegistered() ? QStringLiteral("registrado")
                                                                : QStringLiteral("indisponível (plasmashell?)"))
                << "| LauncherEntry Update"
                << (m_unityLauncher->updateSignalConnected() ? QStringLiteral("conectado")
                                                             : QStringLiteral("falhou"));
    }
}

void TaskBackend::setupBrowserDownloadWatcher()
{
    m_browserDownloadWatcher = new DockBrowserDownloadWatcher(this);
    connect(m_browserDownloadWatcher,
            &DockBrowserDownloadWatcher::browserDownloadProgress,
            this,
            &TaskBackend::mergeBrowserDownloadProgress);
    connect(m_browserDownloadWatcher,
            &DockBrowserDownloadWatcher::activeDownloadMetadataChanged,
            this,
            &TaskBackend::reapplyActiveDownloadMetadata);
    updateBrowserDownloadCommand();
}

void TaskBackend::reapplyActiveDownloadMetadata()
{
    if (m_downloadProgressDisplayMode != 2 || !m_browserDownloadWatcher) {
        return;
    }

    m_browserDownloadWatcher->refreshActiveDownloadScan();

    const QString downloadsCmd = QStringLiteral("dolphin ~/Downloads");
    if (m_launcherProgress.contains(downloadsCmd)) {
        const QVariantMap entry = m_launcherProgress.value(downloadsCmd).toMap();
        if (entry.value(QStringLiteral("progressVisible")).toBool()) {
            const QString browserCmd = entry.value(QStringLiteral("progressBrowserCmd")).toString();
            if (!browserCmd.isEmpty()) {
                publishLauncherProgressForSource(browserCmd, entry);
                return;
            }
        }
    }

    for (auto it = m_launcherProgress.constBegin(); it != m_launcherProgress.constEnd(); ++it) {
        const QVariantMap entry = it.value().toMap();
        if (!entry.value(QStringLiteral("progressVisible")).toBool()) {
            continue;
        }
        const QString browserCmd = entry.value(QStringLiteral("progressBrowserCmd")).toString();
        if (!browserCmd.isEmpty() && DockBrowserUtils::commandLooksLikeBrowser(browserCmd)) {
            publishLauncherProgressForSource(browserCmd, entry);
        }
    }
}

void TaskBackend::updateBrowserDownloadCommand()
{
    if (!m_browserDownloadWatcher) {
        return;
    }

    QStringList browserCmds;
    browserCmds.reserve(m_execBasenameToCmd.size());
    for (auto it = m_execBasenameToCmd.constBegin(); it != m_execBasenameToCmd.constEnd(); ++it) {
        const QString &cmd = it.value();
        if (DockBrowserUtils::commandLooksLikeBrowser(cmd)) {
            browserCmds.append(cmd);
        }
    }

    if (browserCmds.isEmpty()) {
        m_browserDownloadWatcher->setBrowserCommand(QString());
        return;
    }

    std::sort(browserCmds.begin(), browserCmds.end());

    QString bestProgressCmd;
    double bestProgress = -1.0;
    for (const QString &cmd : std::as_const(browserCmds)) {
        const QString dockCmd = downloadProgressDockCommand(cmd);
        const QVariantMap entry = m_launcherProgress.value(dockCmd).toMap();
        const QString src = entry.value(QStringLiteral("progressBrowserCmd")).toString();
        if (!entry.value(QStringLiteral("progressVisible")).toBool()) {
            continue;
        }
        if (src != cmd && dockCmd != cmd) {
            continue;
        }
        const double progress = entry.value(QStringLiteral("progress"), -1.0).toDouble();
        if (progress >= 0.0 && progress < 1.0 && progress > bestProgress) {
            bestProgress = progress;
            bestProgressCmd = cmd;
        }
    }

    QString chosen = bestProgressCmd;
    if (chosen.isEmpty()) {
        for (const QString &cmd : std::as_const(browserCmds)) {
            if (DockBrowserUtils::commandMatchesWmClass(cmd, m_activeAppClass)) {
                chosen = cmd;
                break;
            }
        }
    }
    if (chosen.isEmpty()) {
        chosen = browserCmds.constFirst();
    }

    m_browserDownloadWatcher->setBrowserCommand(chosen);
}

void TaskBackend::applyLauncherProgressForCommand(const QString &cmd, QVariantMap entry, QVariantMap &next) const
{
    const bool visible = entry.value(QStringLiteral("progressVisible")).toBool();
    const double progress = entry.value(QStringLiteral("progress"), -1.0).toDouble();
    if (!visible || progress < 0.0 || progress >= 1.0) {
        next.remove(cmd);
    } else {
        next.insert(cmd, entry);
    }
}

QString TaskBackend::downloadProgressDockCommand(const QString &sourceCommand) const
{
    if (sourceCommand.isEmpty() || m_downloadProgressDisplayMode == 0) {
        return sourceCommand;
    }

    if (DockBrowserUtils::commandLooksLikeBrowser(sourceCommand)) {
        return downloadsDockCommand();
    }
    return sourceCommand;
}

bool TaskBackend::publishLauncherProgressForSource(const QString &sourceCommand, QVariantMap entry)
{
    if (sourceCommand.isEmpty()) {
        return false;
    }

    if (downloadProgressDockCommand(sourceCommand) != sourceCommand) {
        entry.insert(QStringLiteral("progressBrowserCmd"), sourceCommand);
    }

    enrichLauncherProgressEntry(entry);

    const QString targetCmd = downloadProgressDockCommand(sourceCommand);
    QVariantMap next = m_launcherProgress;
    applyLauncherProgressForCommand(targetCmd, entry, next);
    if (targetCmd != sourceCommand) {
        next.remove(sourceCommand);
    }

    const QVariantMap previousTarget = m_launcherProgress.value(targetCmd).toMap();
    const double previousProgress = previousTarget.value(QStringLiteral("progress"), -1.0).toDouble();
    const bool previousVisible = previousTarget.value(QStringLiteral("progressVisible")).toBool();
    const QString previousIcon = previousTarget.value(QStringLiteral("progressIcon")).toString();
    const QString previousFileName = previousTarget.value(QStringLiteral("progressFileName")).toString();
    const bool hadTarget = m_launcherProgress.contains(targetCmd);
    const bool hasTarget = next.contains(targetCmd);
    const QVariantMap nextTargetMap = hasTarget ? next.value(targetCmd).toMap() : QVariantMap();
    const double nextProgress = hasTarget ? nextTargetMap.value(QStringLiteral("progress"), -1.0).toDouble() : -1.0;
    const bool nextVisible = hasTarget && nextTargetMap.value(QStringLiteral("progressVisible")).toBool();
    const QString nextIcon = nextTargetMap.value(QStringLiteral("progressIcon")).toString();
    const QString nextFileName = nextTargetMap.value(QStringLiteral("progressFileName")).toString();

    const bool targetChanged = hadTarget != hasTarget || previousVisible != nextVisible
        || qAbs(previousProgress - nextProgress) >= 0.002
        || previousIcon != nextIcon
        || previousFileName != nextFileName;
    const bool sourceCleared = targetCmd != sourceCommand && m_launcherProgress.contains(sourceCommand);

    if (!targetChanged && !sourceCleared) {
        return false;
    }
    if (next == m_launcherProgress) {
        return false;
    }

    m_launcherProgress = next;
    if (targetChanged) {
        const bool urgent = previousVisible != nextVisible || hadTarget != hasTarget;
        notifyLauncherProgressForCommand(targetCmd, urgent);
    }
    if (sourceCleared) {
        notifyLauncherProgressForCommand(sourceCommand, true);
    }
    return true;
}

void TaskBackend::setDockWaveAnimating(bool animating)
{
    if (m_dockWaveAnimating == animating) {
        return;
    }
    m_dockWaveAnimating = animating;
    if (animating) {
        if (m_progressNotifyTimer) {
            m_progressNotifyTimer->stop();
        }
        return;
    }

    const QSet<QString> pending = std::exchange(m_pendingProgressNotifyCmds, {});
    for (const QString &cmd : pending) {
        emit launcherProgressForCommandChanged(cmd);
    }
    for (auto it = m_launcherProgress.constBegin(); it != m_launcherProgress.constEnd(); ++it) {
        emit launcherProgressForCommandChanged(it.key());
    }
}

void TaskBackend::notifyLauncherProgressForCommand(const QString &command, bool urgent)
{
    if (command.isEmpty()) {
        return;
    }
    if (m_dockWaveAnimating) {
        m_pendingProgressNotifyCmds.insert(command);
        return;
    }
    if (urgent) {
        m_pendingProgressNotifyCmds.remove(command);
        emit launcherProgressForCommandChanged(command);
        return;
    }
    m_pendingProgressNotifyCmds.insert(command);
    if (m_progressNotifyTimer && !m_progressNotifyTimer->isActive()) {
        m_progressNotifyTimer->start();
    }
}

void TaskBackend::mergeBrowserDownloadProgress(const QString &command,
                                               double progress,
                                               bool visible,
                                               const QString &filePath,
                                               const QString &fileName)
{
    if (command.isEmpty()) {
        return;
    }

    const QString targetCmd = downloadProgressDockCommand(command);
    const QVariantMap existing = m_launcherProgress.value(targetCmd).toMap();
    if (existing.value(QStringLiteral("progressSource")).toString() == QLatin1String("unity")) {
        return;
    }

    QVariantMap entry = m_launcherProgress.value(targetCmd).toMap();
    entry.insert(QStringLiteral("progressSource"), QStringLiteral("browser"));
    if (visible) {
        entry.insert(QStringLiteral("progress"), qBound(0.0, progress, 0.999));
        entry.insert(QStringLiteral("progressVisible"), true);
        entry.insert(QStringLiteral("progressFilePathHint"), filePath);
        entry.insert(QStringLiteral("progressFileNameHint"), fileName);
    } else {
        entry.insert(QStringLiteral("progressVisible"), false);
    }

    publishLauncherProgressForSource(command, entry);
}

QString TaskBackend::commandForUnityAppUri(const QString &appUri) const
{
    QString desktopRef = appUri.trimmed();
    if (desktopRef.startsWith(QLatin1String("application://"))) {
        desktopRef = desktopRef.mid(14);
    } else if (desktopRef.startsWith(QLatin1String("application:"))) {
        desktopRef = desktopRef.mid(12);
    }
    desktopRef = desktopRef.trimmed();
    if (desktopRef.isEmpty()) {
        return {};
    }

    const QString baseName = QFileInfo(desktopRef).fileName().toLower();
    const auto byBase = m_desktopBasenameToCmd.constFind(baseName);
    if (byBase != m_desktopBasenameToCmd.constEnd()) {
        return byBase.value();
    }

    QString entryId = baseName;
    if (entryId.endsWith(QStringLiteral(".desktop"))) {
        entryId.chop(8);
    }
    const auto byEntry = m_desktopEntryToCmd.constFind(entryId.toLower());
    if (byEntry != m_desktopEntryToCmd.constEnd()) {
        return byEntry.value();
    }

    const auto byExec = m_execBasenameToCmd.constFind(QFileInfo(desktopRef).fileName().toLower());
    if (byExec != m_execBasenameToCmd.constEnd()) {
        return byExec.value();
    }
    const auto byExecBase = m_execBasenameToCmd.constFind(entryId.toLower());
    if (byExecBase != m_execBasenameToCmd.constEnd()) {
        return byExecBase.value();
    }

    const QString refLower = desktopRef.toLower();
    if (refLower.contains(QLatin1String("zen")) || refLower.contains(QLatin1String("mozilla"))
        || refLower.contains(QLatin1String("firefox"))) {
        for (auto it = m_execBasenameToCmd.constBegin(); it != m_execBasenameToCmd.constEnd(); ++it) {
            if (it.key().contains(QLatin1String("zen")) || it.key().contains(QLatin1String("firefox"))) {
                return it.value();
            }
        }
    }

    return {};
}

void TaskBackend::mergeUnityLauncherUpdate(const QString &appUri, const QMap<QString, QVariant> &properties)
{
    const QString cmd = commandForUnityAppUri(appUri);
    if (cmd.isEmpty()) {
        if (m_debugLogsEnabled && debugCategoryEnabled(QStringLiteral("launcher"))) {
            qInfo() << "AgildoDock[debug][launcher]: URI sem ícone na doca:" << appUri;
        }
        return;
    }

    const QString targetCmd = downloadProgressDockCommand(cmd);
    QVariantMap entry = m_launcherProgress.value(targetCmd).toMap();

    for (auto it = properties.constBegin(); it != properties.constEnd(); ++it) {
        const QString key = it.key();
        if (key == QLatin1String("progress")) {
            entry.insert(QStringLiteral("progress"), qBound(0.0, it.value().toDouble(), 1.0));
        } else if (key == QLatin1String("progress-visible") || key == QLatin1String("progress_visible")) {
            entry.insert(QStringLiteral("progressVisible"), it.value().toBool());
        }
    }
    if (entry.value(QStringLiteral("progressVisible")).toBool()) {
        entry.insert(QStringLiteral("progressSource"), QStringLiteral("unity"));
        if (m_browserDownloadWatcher) {
            const QString filePath = m_browserDownloadWatcher->activeDownloadFilePath();
            if (!filePath.isEmpty()) {
                entry.insert(QStringLiteral("progressFilePathHint"), filePath);
                entry.insert(QStringLiteral("progressFileNameHint"), m_browserDownloadWatcher->activeDownloadFileName());
            }
        }
    }

    if (publishLauncherProgressForSource(cmd, entry)
        && m_debugLogsEnabled && debugCategoryEnabled(QStringLiteral("launcher"))) {
        qInfo() << "AgildoDock[debug][launcher]" << targetCmd << entry;
    }
}
