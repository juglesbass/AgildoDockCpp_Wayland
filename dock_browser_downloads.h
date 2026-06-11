#ifndef DOCK_BROWSER_DOWNLOADS_H
#define DOCK_BROWSER_DOWNLOADS_H

#include <QObject>
#include <QString>

class QTimer;
class QFileSystemWatcher;

/*!
 * Metadados de downloads ativos: Gecko (downloads.json), Chromium (History SQLite),
 * ficheiros .crdownload e pastas XDG — para ícone do arquivo e progresso real.
 */
class DockBrowserDownloadWatcher : public QObject
{
    Q_OBJECT

public:
    explicit DockBrowserDownloadWatcher(QObject *parent = nullptr);

    void setBrowserCommand(const QString &command);
    void resetLastEmittedState();
    /// Atualiza caminho/nome/progresso lendo fontes do sistema (sem esperar o timer).
    void refreshActiveDownloadScan();

    QString activeDownloadFilePath() const { return m_activeFilePath; }
    QString activeDownloadFileName() const { return m_activeFileName; }
    double activeDownloadProgress() const { return m_activeProgress; }

signals:
    void browserDownloadProgress(const QString &command,
                                 double progress,
                                 bool visible,
                                 const QString &filePath,
                                 const QString &fileName);
    /// Caminho/nome do arquivo mudou — re-enriquecer ícone na doca.
    void activeDownloadMetadataChanged();

private:
    void pollActiveDownloads();
    void setupDownloadDirectoryWatcher();
    void setupChromiumHistoryWatcher();
    void onDownloadSourcesChanged();
    void applyDownloadSourcesRefresh();

    QTimer *m_pollTimer = nullptr;
    QTimer *m_sourceChangeDebounce = nullptr;
    qint64 m_lastChromiumHistoryScanMs = 0;
    QFileSystemWatcher *m_downloadFsWatcher = nullptr;
    QStringList m_watchedDownloadDirs;
    QStringList m_watchedHistoryFiles;
    QString m_browserCommand;
    double m_lastEmittedProgress = -1.0;
    bool m_lastEmittedVisible = false;
    QString m_lastEmittedFilePath;
    QString m_activeFilePath;
    QString m_activeFileName;
    double m_activeProgress = 0.0;
};

#endif // DOCK_BROWSER_DOWNLOADS_H
