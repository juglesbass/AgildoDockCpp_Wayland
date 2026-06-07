#ifndef DOCK_ZEN_DOWNLOADS_H
#define DOCK_ZEN_DOWNLOADS_H

#include <QObject>
#include <QString>

class QTimer;
class QFileSystemWatcher;

/*!
 * Metadados de download ativos: Gecko (downloads.json), Chromium (History SQLite)
 * e ficheiros .crdownload — para ícone do arquivo e fallback de progresso.
 */
class DockZenDownloadWatcher : public QObject
{
    Q_OBJECT

public:
    explicit DockZenDownloadWatcher(QObject *parent = nullptr);

    void setZenCommand(const QString &command);
    void resetLastEmittedState();
    /// Atualiza caminho/nome/progresso lendo fontes do sistema (sem esperar o timer).
    void refreshActiveDownloadScan();

    QString activeDownloadFilePath() const { return m_activeFilePath; }
    QString activeDownloadFileName() const { return m_activeFileName; }
    double activeDownloadProgress() const { return m_activeProgress; }

signals:
    void zenDownloadProgress(const QString &command,
                             double progress,
                             bool visible,
                             const QString &filePath,
                             const QString &fileName);
    /// Caminho/nome do arquivo mudou (ex.: .crdownload criado) — re-enriquecer ícone na doca.
    void activeDownloadMetadataChanged();

private:
    void pollZenDownloads();
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
    QString m_zenCommand;
    double m_lastEmittedProgress = -1.0;
    bool m_lastEmittedVisible = false;
    QString m_lastEmittedFilePath;
    QString m_activeFilePath;
    QString m_activeFileName;
    double m_activeProgress = 0.0;
};

#endif // DOCK_ZEN_DOWNLOADS_H
