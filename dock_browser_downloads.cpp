#include "dock_browser_downloads.h"
#include "dock_browser_utils.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QHash>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QTemporaryFile>
#include <QTimer>
#include <QDateTime>

namespace {

QString geckoConfigRoot(const QString &relativeRoot)
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QLatin1Char('/') + relativeRoot;
}

QString normalizedFinalPath(QString path)
{
    path = path.trimmed();
    if (path.endsWith(QStringLiteral(".crdownload"), Qt::CaseInsensitive)) {
        path.chop(12);
    }
    if (path.endsWith(QStringLiteral(".part"), Qt::CaseInsensitive)) {
        path.chop(5);
    }
    return path;
}

QString downloadTargetPath(const QJsonObject &item)
{
    const QJsonObject target = item.value(QStringLiteral("target")).toObject();
    const QString path = target.value(QStringLiteral("path")).toString().trimmed();
    if (!path.isEmpty()) {
        return normalizedFinalPath(path);
    }
    return normalizedFinalPath(target.value(QStringLiteral("partFilePath")).toString());
}

struct DownloadScanBest {
    bool active = false;
    double progress = 0.0;
    QString filePath;
    QString fileName;
};

bool pathHasActivePartial(const QString &finalPath)
{
    if (finalPath.isEmpty()) {
        return false;
    }
    return QFile::exists(finalPath + QStringLiteral(".crdownload"))
        || QFile::exists(finalPath + QStringLiteral(".part"));
}

/// Só metadados de caminho — não inventa progresso (ex.: .crdownload antes do SQL).
void considerPathOnly(DownloadScanBest &best, const QString &filePath)
{
    const QString normalized = normalizedFinalPath(filePath);
    if (normalized.isEmpty()) {
        return;
    }

    const bool newHasPartial = pathHasActivePartial(normalized);
    const bool bestHasPartial = pathHasActivePartial(best.filePath);
    const bool fillsMissingPath = best.active && best.filePath.isEmpty();

    if (!best.active || fillsMissingPath || (newHasPartial && !bestHasPartial)) {
        best.filePath = normalized;
        best.fileName = QFileInfo(normalized).fileName();
        best.active = true;
    }
}

void considerCandidate(DownloadScanBest &best, double progress, const QString &filePath)
{
    const QString normalized = normalizedFinalPath(filePath);
    if (normalized.isEmpty()) {
        return;
    }

    const bool newHasPartial = pathHasActivePartial(normalized);
    const bool bestHasPartial = pathHasActivePartial(best.filePath);
    const bool betterProgress = !best.active || progress > best.progress + 0.001;
    const bool preferNewPartial = newHasPartial && !bestHasPartial;
    const bool fillsMissingPath = best.active && best.filePath.isEmpty();

    if (!best.active || preferNewPartial || fillsMissingPath
        || (betterProgress && (newHasPartial || !bestHasPartial))) {
        if (!best.active || preferNewPartial || fillsMissingPath || betterProgress) {
            best.progress = qBound(0.0, progress, 0.999);
        }
        best.filePath = normalized;
        best.fileName = QFileInfo(normalized).fileName();
        best.active = true;
    }
}

void scanGeckoProfiles(const QString &relativeRoot, DownloadScanBest &best)
{
    const QDir profileRoot(geckoConfigRoot(relativeRoot));
    if (!profileRoot.exists()) {
        return;
    }

    const QStringList profiles = profileRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &profileName : profiles) {
        if (profileName == QLatin1String("NativeMessagingHosts")) {
            continue;
        }

        QFile downloadsFile(profileRoot.filePath(profileName + QStringLiteral("/downloads.json")));
        if (!downloadsFile.open(QIODevice::ReadOnly)) {
            continue;
        }

        QJsonParseError parseError;
        const QJsonDocument doc = QJsonDocument::fromJson(downloadsFile.readAll(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            continue;
        }

        const QJsonArray list = doc.object().value(QStringLiteral("list")).toArray();
        for (const QJsonValue &value : list) {
            const QJsonObject item = value.toObject();
            if (item.contains(QStringLiteral("endTime"))) {
                continue;
            }

            const qint64 totalBytes = item.value(QStringLiteral("totalBytes")).toVariant().toLongLong();
            if (totalBytes <= 0) {
                continue;
            }

            const QJsonObject target = item.value(QStringLiteral("target")).toObject();
            const QString partPath = target.value(QStringLiteral("partFilePath")).toString();
            if (partPath.isEmpty()) {
                continue;
            }

            const qint64 received = QFileInfo(partPath).size();
            const double progress = received > 0
                ? qBound(0.0, static_cast<double>(received) / static_cast<double>(totalBytes), 0.999)
                : 0.0;
            considerCandidate(best, progress, downloadTargetPath(item));
        }
    }
}

bool copySqliteHistorySnapshot(const QString &historyPath, const QString &tempPath)
{
    if (!QFile::exists(historyPath)) {
        return false;
    }
    if (QFile::exists(tempPath)) {
        QFile::remove(tempPath);
    }
    if (!QFile::copy(historyPath, tempPath)) {
        return false;
    }
    const QString walPath = historyPath + QStringLiteral("-wal");
    const QString shmPath = historyPath + QStringLiteral("-shm");
    if (QFile::exists(walPath)) {
        QFile::copy(walPath, tempPath + QStringLiteral("-wal"));
    }
    if (QFile::exists(shmPath)) {
        QFile::copy(shmPath, tempPath + QStringLiteral("-shm"));
    }
    return true;
}

QSqlDatabase chromiumDownloadsDatabase()
{
    static const QString connectionName = QStringLiteral("agildodock_chromium_downloads");
    if (!QSqlDatabase::contains(connectionName)) {
        QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connectionName);
    }
    return QSqlDatabase::database(connectionName);
}

void ingestChromiumHistoryQuery(QSqlDatabase &db, DownloadScanBest &best)
{
    QSqlQuery query(db);
    if (!query.exec(QStringLiteral(
            "SELECT target_path, current_path, total_bytes, received_bytes "
            "FROM downloads "
            "WHERE state = 0 AND total_bytes > 0 "
            "ORDER BY start_time DESC"))) {
        return;
    }
    while (query.next()) {
        const QString targetPath = query.value(0).toString();
        const QString currentPath = query.value(1).toString();
        const qint64 totalBytes = query.value(2).toLongLong();
        const qint64 receivedBytes = query.value(3).toLongLong();
        QString path = !currentPath.trimmed().isEmpty() ? currentPath : targetPath;
        path = normalizedFinalPath(path);
        if (path.isEmpty() || totalBytes <= 0) {
            continue;
        }

        qint64 received = receivedBytes;
        const QString crPath = path + QStringLiteral(".crdownload");
        if (QFile::exists(crPath)) {
            received = qMax(received, QFileInfo(crPath).size());
        }

        const double progress = received > 0
            ? qBound(0.0, static_cast<double>(received) / static_cast<double>(totalBytes), 0.999)
            : 0.0;
        considerCandidate(best, progress, path);
    }
    query.finish();
}

bool isChromiumProfileDirectory(const QDir &browserRoot, const QString &profileName)
{
    if (profileName.startsWith(QLatin1Char('.'))) {
        return false;
    }
    return QFile::exists(browserRoot.filePath(profileName + QStringLiteral("/History")))
        && QFile::exists(browserRoot.filePath(profileName + QStringLiteral("/Preferences")));
}

qint64 &chromiumHistoryFailUntil(const QString &historyPath)
{
    static QHash<QString, qint64> cache;
    return cache[historyPath];
}

bool queryChromiumHistorySnapshot(const QString &historyPath, DownloadScanBest &best)
{
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (chromiumHistoryFailUntil(historyPath) > nowMs) {
        return false;
    }

    QTemporaryFile tempHistory;
    tempHistory.setAutoRemove(true);
    if (!tempHistory.open()) {
        chromiumHistoryFailUntil(historyPath) = nowMs + 5000;
        return false;
    }
    const QString tempPath = tempHistory.fileName();
    tempHistory.close();

    if (!copySqliteHistorySnapshot(historyPath, tempPath)) {
        chromiumHistoryFailUntil(historyPath) = nowMs + 5000;
        return false;
    }

    bool opened = false;
    {
        QSqlDatabase db = chromiumDownloadsDatabase();
        if (db.isOpen()) {
            db.close();
        }
        db.setDatabaseName(tempPath);
        if (db.open()) {
            opened = true;
            ingestChromiumHistoryQuery(db, best);
            db.close();
        }
    }

    if (!opened) {
        chromiumHistoryFailUntil(historyPath) = nowMs + 5000;
        return false;
    }
    chromiumHistoryFailUntil(historyPath) = 0;
    return true;
}

void scanChromiumProfiles(const QString &relativeRoot, DownloadScanBest &best)
{
    const QDir browserRoot(geckoConfigRoot(relativeRoot));
    if (!browserRoot.exists()) {
        return;
    }

    const QStringList profiles = browserRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QString &profileName : profiles) {
        if (!isChromiumProfileDirectory(browserRoot, profileName)) {
            continue;
        }

        const QString historyPath = browserRoot.filePath(profileName + QStringLiteral("/History"));
        queryChromiumHistorySnapshot(historyPath, best);
    }
}

void scanCrdownloadInDirectory(const QString &directoryPath, DownloadScanBest &best)
{
    const QDir dir(directoryPath);
    if (!dir.exists()) {
        return;
    }

    const QStringList partials = dir.entryList({QStringLiteral("*.crdownload")}, QDir::Files);
    for (const QString &partialName : partials) {
        const QString partialPath = dir.filePath(partialName);
        // Progresso real vem do History SQLite ou downloads.json — aqui só o caminho.
        considerPathOnly(best, partialPath);
    }
}

QStringList downloadDirectoriesToScan()
{
    QStringList dirs;
    const QString xdgDownloads = QStandardPaths::writableLocation(QStandardPaths::DownloadLocation);
    if (!xdgDownloads.isEmpty()) {
        dirs << xdgDownloads;
    }
    const QString homeDownloads = QDir::homePath() + QStringLiteral("/Downloads");
    if (!dirs.contains(homeDownloads)) {
        dirs << homeDownloads;
    }
    return dirs;
}

DownloadScanBest scanAllActiveDownloads(qint64 &lastChromiumHistoryScanMs)
{
    DownloadScanBest best;

    for (const QString &dirPath : downloadDirectoriesToScan()) {
        scanCrdownloadInDirectory(dirPath, best);
    }
    for (const QString &root : DockBrowserUtils::geckoConfigRoots()) {
        scanGeckoProfiles(root, best);
    }

    // History SQLite quando ainda não há progresso confiável ou ficheiro parcial desconhecido
    const bool needsHistoryScan = !best.active || best.progress <= 0.001
        || !pathHasActivePartial(best.filePath);
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (needsHistoryScan && (nowMs - lastChromiumHistoryScanMs) >= 400) {
        lastChromiumHistoryScanMs = nowMs;
        for (const QString &root : DockBrowserUtils::chromiumConfigRoots()) {
            scanChromiumProfiles(root, best);
        }
    }

    return best;
}

} // namespace

DockBrowserDownloadWatcher::DockBrowserDownloadWatcher(QObject *parent)
    : QObject(parent)
{
    setupDownloadDirectoryWatcher();
    setupChromiumHistoryWatcher();

    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(250);
    connect(m_pollTimer, &QTimer::timeout, this, &DockBrowserDownloadWatcher::pollActiveDownloads);
    m_pollTimer->start();

    m_sourceChangeDebounce = new QTimer(this);
    m_sourceChangeDebounce->setSingleShot(true);
    m_sourceChangeDebounce->setInterval(100);
    connect(m_sourceChangeDebounce, &QTimer::timeout, this, &DockBrowserDownloadWatcher::applyDownloadSourcesRefresh);
}

void DockBrowserDownloadWatcher::setupDownloadDirectoryWatcher()
{
    m_downloadFsWatcher = new QFileSystemWatcher(this);
    connect(m_downloadFsWatcher, &QFileSystemWatcher::directoryChanged,
            this, &DockBrowserDownloadWatcher::onDownloadSourcesChanged);
    connect(m_downloadFsWatcher, &QFileSystemWatcher::fileChanged,
            this, &DockBrowserDownloadWatcher::onDownloadSourcesChanged);

    for (const QString &dirPath : downloadDirectoriesToScan()) {
        if (QDir(dirPath).exists() && !m_watchedDownloadDirs.contains(dirPath)) {
            m_downloadFsWatcher->addPath(dirPath);
            m_watchedDownloadDirs.append(dirPath);
        }
    }
}

void DockBrowserDownloadWatcher::setupChromiumHistoryWatcher()
{
    if (!m_downloadFsWatcher) {
        return;
    }

    QStringList browserRoots;
    for (const QString &relativeRoot : DockBrowserUtils::chromiumConfigRoots()) {
        browserRoots << geckoConfigRoot(relativeRoot);
    }

    for (const QString &browserRootPath : browserRoots) {
        const QDir browserRoot(browserRootPath);
        if (!browserRoot.exists()) {
            continue;
        }
        const QStringList profiles = browserRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &profileName : profiles) {
            const QString historyPath = browserRoot.filePath(profileName + QStringLiteral("/History"));
            if (!QFile::exists(historyPath) || m_watchedHistoryFiles.contains(historyPath)) {
                continue;
            }
            m_downloadFsWatcher->addPath(historyPath);
            m_watchedHistoryFiles.append(historyPath);
        }
    }
}

void DockBrowserDownloadWatcher::onDownloadSourcesChanged()
{
    if (!m_sourceChangeDebounce->isActive()) {
        m_sourceChangeDebounce->start();
    }
}

void DockBrowserDownloadWatcher::applyDownloadSourcesRefresh()
{
    m_lastChromiumHistoryScanMs = 0;
    const QString previousPath = m_activeFilePath;
    const QString previousName = m_activeFileName;
    refreshActiveDownloadScan();
    if (m_activeFilePath != previousPath || m_activeFileName != previousName) {
        emit activeDownloadMetadataChanged();
    }
    pollActiveDownloads();
}

void DockBrowserDownloadWatcher::setBrowserCommand(const QString &command)
{
    m_browserCommand = command.trimmed();
    resetLastEmittedState();
}

void DockBrowserDownloadWatcher::resetLastEmittedState()
{
    m_lastEmittedProgress = -1.0;
    m_lastEmittedVisible = false;
    m_lastEmittedFilePath.clear();
    m_activeFilePath.clear();
    m_activeFileName.clear();
    m_activeProgress = 0.0;
}

void DockBrowserDownloadWatcher::refreshActiveDownloadScan()
{
    const DownloadScanBest best = scanAllActiveDownloads(m_lastChromiumHistoryScanMs);
    m_activeFilePath = best.active ? best.filePath : QString();
    m_activeFileName = best.active ? best.fileName : QString();
    m_activeProgress = best.active ? best.progress : 0.0;
}

void DockBrowserDownloadWatcher::pollActiveDownloads()
{
    const QString previousPath = m_activeFilePath;
    const QString previousName = m_activeFileName;
    refreshActiveDownloadScan();
    if (m_activeFilePath != previousPath || m_activeFileName != previousName) {
        emit activeDownloadMetadataChanged();
    }

    if (m_browserCommand.isEmpty()) {
        return;
    }

    const bool anyActive = !m_activeFilePath.isEmpty();
    if (!anyActive && !m_lastEmittedVisible) {
        return;
    }
    if (anyActive == m_lastEmittedVisible
        && qAbs(m_activeProgress - m_lastEmittedProgress) < 0.002
        && m_activeFilePath == m_lastEmittedFilePath) {
        return;
    }

    m_lastEmittedVisible = anyActive;
    m_lastEmittedProgress = m_activeProgress;
    m_lastEmittedFilePath = m_activeFilePath;
    emit browserDownloadProgress(m_browserCommand,
                                 m_activeProgress,
                                 anyActive,
                                 m_activeFilePath,
                                 m_activeFileName);
}
