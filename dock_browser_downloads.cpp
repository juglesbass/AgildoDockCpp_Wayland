#include "dock_browser_downloads.h"
#include "dock_browser_utils.h"

#include <chrono>
#include <QtConcurrent>
#include <QFutureWatcher>
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
#include <QThread>
#include <QMutex>

namespace {

QString browserConfigDir(const QString &relativeRoot)
{
    return QStandardPaths::writableLocation(QStandardPaths::ConfigLocation) + QLatin1Char('/') + relativeRoot;
}

QString normalizedFinalPath(QString path)
{
    path = path.trimmed();
    if (path.endsWith(QStringLiteral(".crdownload"), Qt::CaseInsensitive)) {
        path.chop(11);
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

} // namespace

struct DownloadScanBest {
    bool active = false;
    double progress = 0.0;
    QString filePath;
    QString fileName;
    qint64 newHistoryScanMs = -1;
};

namespace {

bool pathHasActivePartial(const QString &finalPath)
{
    if (finalPath.isEmpty()) {
        return false;
    }
    if (QFile::exists(finalPath + QStringLiteral(".crdownload"))
        || QFile::exists(finalPath + QStringLiteral(".part"))) {
        return true;
    }

    const QFileInfo fi(finalPath);
    const QDir parentDir = fi.dir();
    if (parentDir.exists()) {
        const QString baseName = fi.completeBaseName();
        if (!baseName.isEmpty()) {
            const QStringList partials = parentDir.entryList(
                {baseName + QStringLiteral("*.part"), baseName + QStringLiteral("*.crdownload")},
                QDir::Files);
            if (!partials.isEmpty()) {
                return true;
            }
        }
    }
    return false;
}

/// Só metadados de caminho — não inventa progresso (ex.: .crdownload/.part antes do SQL/JSON).
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

    const double boundedProgress = qBound(0.0, progress, 0.999);
    const bool hasProgress = boundedProgress > 0.001;
    const bool bestHasProgress = best.active && best.progress > 0.001;

    // Se o candidato atual possui progresso real (> 0) e o anterior não tinha, ou se é maior:
    const bool betterProgress = !best.active
        || (hasProgress && !bestHasProgress)
        || (boundedProgress > best.progress + 0.0002)
        || (best.filePath.isEmpty() && !normalized.isEmpty());

    if (!best.active || betterProgress) {
        best.progress = boundedProgress;
        best.filePath = normalized;
        best.fileName = QFileInfo(normalized).fileName();
        best.active = true;
    }
}

void scanGeckoProfiles(const QString &relativeRoot, DownloadScanBest &best)
{
    const QDir profileRoot(browserConfigDir(relativeRoot));
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
            if (item.contains(QStringLiteral("endTime")) || item.contains(QStringLiteral("errorObj"))) {
                continue;
            }

            const qint64 totalBytes = item.value(QStringLiteral("totalBytes")).toVariant().toLongLong();
            if (totalBytes <= 0) {
                continue;
            }

            const QJsonObject target = item.value(QStringLiteral("target")).toObject();
            const QString partPath = target.value(QStringLiteral("partFilePath")).toString().trimmed();
            const QString finalTarget = downloadTargetPath(item);
            if (partPath.isEmpty()) {
                continue;
            }

            const QFileInfo partInfo(partPath);
            if (!partInfo.exists() && !pathHasActivePartial(finalTarget)) {
                continue;
            }

            const qint64 received = partInfo.exists() ? partInfo.size() : 0;
            const double progress = (received > 0 && totalBytes > 0)
                ? qBound(0.0, static_cast<double>(received) / static_cast<double>(totalBytes), 0.999)
                : 0.0;
            considerCandidate(best, progress, finalTarget);
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

// Cache e mutex compartilhados entre chromiumHistoryFailUntil / setChromiumHistoryFailUntil.
// Ambas as funções DEVEM usar o mesmo mutex e cache — declarar estáticos locais
// separados criava uma data race silenciosa (set escrevia num, get lia de outro).
static QMutex s_chromiumFailMutex;
static QHash<QString, qint64> s_chromiumFailCache;

qint64 chromiumHistoryFailUntil(const QString &historyPath)
{
    QMutexLocker locker(&s_chromiumFailMutex);
    return s_chromiumFailCache.value(historyPath, 0);
}

void setChromiumHistoryFailUntil(const QString &historyPath, qint64 value)
{
    QMutexLocker locker(&s_chromiumFailMutex);
    s_chromiumFailCache[historyPath] = value;
}

bool queryChromiumHistoryDirect(const QString &historyPath, DownloadScanBest &best)
{
    const QString connName = QStringLiteral("agildodock_cr_ro_") + QString::number(reinterpret_cast<quintptr>(QThread::currentThreadId()));
    bool opened = false;
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        // Open in read-only + immutable mode to avoid locks and WAL copies
        db.setDatabaseName(QStringLiteral("file:%1?immutable=1&mode=ro").arg(historyPath));
        db.setConnectOptions(QStringLiteral("QSQLITE_OPEN_READONLY;QSQLITE_OPEN_URI"));
        if (db.open()) {
            opened = true;
            ingestChromiumHistoryQuery(db, best);
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(connName);
    return opened;
}

bool queryChromiumHistorySnapshot(const QString &historyPath, DownloadScanBest &best)
{
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (chromiumHistoryFailUntil(historyPath) > nowMs) {
        return false;
    }

    // Try direct read-only open first (zero-copy, no disk I/O)
    if (queryChromiumHistoryDirect(historyPath, best)) {
        setChromiumHistoryFailUntil(historyPath, 0);
        return true;
    }

    // Fallback: snapshot copy (only if direct open fails due to WAL lock)
    QTemporaryFile tempHistory;
    tempHistory.setAutoRemove(true);
    if (!tempHistory.open()) {
        setChromiumHistoryFailUntil(historyPath, nowMs + 5000);
        return false;
    }
    const QString tempPath = tempHistory.fileName();
    tempHistory.close();

    if (!copySqliteHistorySnapshot(historyPath, tempPath)) {
        setChromiumHistoryFailUntil(historyPath, nowMs + 5000);
        return false;
    }

    bool opened = false;
    const QString connName = QStringLiteral("agildodock_chromium_downloads_") + QString::number(reinterpret_cast<quintptr>(QThread::currentThreadId()));
    {
        QSqlDatabase db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), connName);
        db.setDatabaseName(tempPath);
        if (db.open()) {
            opened = true;
            ingestChromiumHistoryQuery(db, best);
            db.close();
        }
    }
    QSqlDatabase::removeDatabase(connName);

    if (!opened) {
        setChromiumHistoryFailUntil(historyPath, nowMs + 5000);
        return false;
    }
    setChromiumHistoryFailUntil(historyPath, 0);
    return true;
}

void scanChromiumProfiles(const QString &relativeRoot, DownloadScanBest &best)
{
    const QDir browserRoot(browserConfigDir(relativeRoot));
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

void scanPartialsInDirectory(const QString &directoryPath, DownloadScanBest &best)
{
    const QDir dir(directoryPath);
    if (!dir.exists()) {
        return;
    }

    const QStringList partials = dir.entryList(
        {QStringLiteral("*.crdownload"), QStringLiteral("*.part")},
        QDir::Files);
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

} // namespace

DownloadScanBest scanAllActiveDownloads(qint64 lastChromiumHistoryScanMs)
{
    DownloadScanBest best;

    // 1. Gecko / Zen / Firefox (downloads.json com totalBytes e partFilePath em tempo real)
    for (const QString &root : DockBrowserUtils::geckoConfigRoots()) {
        scanGeckoProfiles(root, best);
    }

    // 2. Chromium History SQLite (se Gecko não encontrou progresso ativo)
    const bool needsHistoryScan = !best.active || best.progress <= 0.001;
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if (needsHistoryScan && (nowMs - lastChromiumHistoryScanMs) >= 400) {
        best.newHistoryScanMs = nowMs;
        for (const QString &root : DockBrowserUtils::chromiumConfigRoots()) {
            scanChromiumProfiles(root, best);
        }
    }

    // 3. Fallback: varredura de diretório caso nenhum perfil tenha reportado progresso
    if (!best.active || best.progress <= 0.001) {
        for (const QString &dirPath : downloadDirectoriesToScan()) {
            scanPartialsInDirectory(dirPath, best);
        }
    }

    return best;
}

DockBrowserDownloadWatcher::DockBrowserDownloadWatcher(QObject *parent)
    : QObject(parent)
{
    setupDownloadDirectoryWatcher();
    setupBrowserWatchers();

    m_scanWatcher = new QFutureWatcher<DownloadScanBest>(this);
    connect(m_scanWatcher, &QFutureWatcher<DownloadScanBest>::finished, this, [this]() {
        const DownloadScanBest best = m_scanWatcher->result();
        
        if (best.newHistoryScanMs > 0) {
            m_lastChromiumHistoryScanMs = best.newHistoryScanMs;
        }

        const QString previousPath = m_activeFilePath;
        const QString previousName = m_activeFileName;
        
        m_activeFilePath = best.active ? best.filePath : QString();
        m_activeFileName = best.active ? best.fileName : QString();
        m_activeProgress = best.active ? best.progress : 0.0;
        
        if (m_activeFilePath != previousPath || m_activeFileName != previousName) {
            emit activeDownloadMetadataChanged();
        }

        if (m_browserCommand.isEmpty()) {
            return;
        }

        const bool anyActive = !m_activeFilePath.isEmpty();

        // Controle adaptativo do temporizador: desativa polling agressivo quando ocioso
        if (anyActive) {
            if (!m_pollTimer->isActive()) {
                m_pollTimer->start(250);
            }
        } else {
            if (m_pollTimer->isActive()) {
                m_pollTimer->stop();
            }
        }

        if (!anyActive && !m_lastEmittedVisible) {
            return;
        }
        if (anyActive == m_lastEmittedVisible
            && qAbs(m_activeProgress - m_lastEmittedProgress) < 0.0002
            && m_activeFilePath == m_lastEmittedFilePath) {
            return;
        }

        m_lastEmittedProgress = m_activeProgress;
        m_lastEmittedVisible = anyActive;
        m_lastEmittedFilePath = m_activeFilePath;
        emit browserDownloadProgress(m_browserCommand, m_activeProgress, anyActive, m_activeFilePath, m_activeFileName);
    });

    m_pollTimer = new QTimer(this);
    m_pollTimer->setInterval(250);
    connect(m_pollTimer, &QTimer::timeout, this, &DockBrowserDownloadWatcher::pollActiveDownloads);
    pollActiveDownloads();

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

void DockBrowserDownloadWatcher::setupBrowserWatchers()
{
    if (!m_downloadFsWatcher) {
        return;
    }

    // 1. Chromium History
    for (const QString &relativeRoot : DockBrowserUtils::chromiumConfigRoots()) {
        const QDir browserRoot(browserConfigDir(relativeRoot));
        if (!browserRoot.exists()) {
            continue;
        }
        const QStringList profiles = browserRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &profileName : profiles) {
            const QString historyPath = browserRoot.filePath(profileName + QStringLiteral("/History"));
            if (QFile::exists(historyPath) && !m_watchedHistoryFiles.contains(historyPath)) {
                m_downloadFsWatcher->addPath(historyPath);
                m_watchedHistoryFiles.append(historyPath);
            }
        }
    }

    // 2. Gecko/Zen/Firefox downloads.json
    for (const QString &relativeRoot : DockBrowserUtils::geckoConfigRoots()) {
        const QDir browserRoot(browserConfigDir(relativeRoot));
        if (!browserRoot.exists()) {
            continue;
        }
        const QStringList profiles = browserRoot.entryList(QDir::Dirs | QDir::NoDotAndDotDot);
        for (const QString &profileName : profiles) {
            if (profileName == QLatin1String("NativeMessagingHosts")) {
                continue;
            }
            const QString downloadsPath = browserRoot.filePath(profileName + QStringLiteral("/downloads.json"));
            if (QFile::exists(downloadsPath) && !m_watchedHistoryFiles.contains(downloadsPath)) {
                m_downloadFsWatcher->addPath(downloadsPath);
                m_watchedHistoryFiles.append(downloadsPath);
            }
        }
    }
}

void DockBrowserDownloadWatcher::onDownloadSourcesChanged()
{
    if (!m_pollTimer->isActive()) {
        m_pollTimer->start(250);
    }
    if (!m_sourceChangeDebounce->isActive()) {
        m_sourceChangeDebounce->start();
    }
}

void DockBrowserDownloadWatcher::applyDownloadSourcesRefresh()
{
    m_lastChromiumHistoryScanMs = 0;
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
    if (m_scanWatcher->isRunning()) {
        return;
    }
    m_scanWatcher->setFuture(QtConcurrent::run(scanAllActiveDownloads, m_lastChromiumHistoryScanMs));
}

void DockBrowserDownloadWatcher::pollActiveDownloads()
{
    refreshActiveDownloadScan();
}
