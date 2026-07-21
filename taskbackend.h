#ifndef TASKBACKEND_H
#define TASKBACKEND_H

#include <QObject>
#include <QHash>
#include <QMap>
#include <QMultiHash>
#include <QProcess>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QWindow>


class DockUnityLauncherService;
class DockBrowserDownloadWatcher;
class PlasmaWaylandManager;

class TaskBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool activeWindowCoversWorkArea READ activeWindowCoversWorkArea NOTIFY activeWindowCoversWorkAreaChanged)
    Q_PROPERTY(bool kdotoolAvailable READ kdotoolAvailable CONSTANT)
    Q_PROPERTY(bool windowManagementAvailable READ windowManagementAvailable CONSTANT)
    Q_PROPERTY(bool windowOverviewOnRefocus READ windowOverviewOnRefocus WRITE setWindowOverviewOnRefocus NOTIFY windowOverviewOnRefocusChanged)
    Q_PROPERTY(QVariantMap notificationBadges READ notificationBadges NOTIFY notificationBadgesChanged)
    Q_PROPERTY(QVariantMap launcherProgress READ launcherProgress NOTIFY launcherProgressChanged)

public:
    explicit TaskBackend(QObject *parent = nullptr);

    void setMainWindow(QWindow *win);

    bool activeWindowCoversWorkArea() const { return m_activeWindowCoversWorkArea; }
    bool kdotoolAvailable() const { return m_kdotoolAvailable; }
    bool windowManagementAvailable() const;

    Q_INVOKABLE void updateExclusiveZone(int size);
    /// 0 = None, 1 = Exclusive, 2 = OnDemand (LayerShellQt::Window::KeyboardInteractivity).
    Q_INVOKABLE void applyLayerShellKeyboardMode(int keyboardMode);
    /// Se false, a doca não pede ativação ao aparecer (menos interferência nas outras janelas).
    Q_INVOKABLE void setLayerShellActivateOnShow(bool activate);
    /// Define a borda Layer Shell: 0 baixo, 1 topo, 2 esquerda, 3 direita.
    Q_INVOKABLE void applyLayerShellEdge(int edge);
    Q_INVOKABLE void setBlurRegion(int x, int y, int w, int h, int radius, bool immediate = false);
    /// Desliga blur KWin (estilo plano ou doca oculta).
    Q_INVOKABLE void clearBlurRegion();
    /// Wayland: remove a faixa superior (em px) da região que recebe ponteiro — cliques passam atrás.
    /// excludeTopPixels <= 0 repõe a superfície completa. Não altera o layout nem os tooltips.
    Q_INVOKABLE void setPointerInputExcludeTop(int excludeTopPixels);
    Q_INVOKABLE QVariantList getUnpinnedApps(const QVariantList &pinnedCmdsVar);
    Q_INVOKABLE void forceLaunchApp(const QString &command);
    Q_INVOKABLE void launchApp(const QString &command);
    Q_INVOKABLE void closeApp(const QString &command);
    Q_INVOKABLE bool isAppRunning(const QString &command);
    Q_INVOKABLE bool isAppFocused(const QString &command);
    Q_INVOKABLE int appWindowCount(const QString &command);
    Q_INVOKABLE void cycleAppWindows(const QString &command, int direction);
    Q_INVOKABLE void adjustVolume(int deltaSteps);
    Q_INVOKABLE void adjustBrightness(int deltaSteps);
    Q_INVOKABLE QVariantList recentItemsForCommand(const QString &command, int maxItems = 5);
    Q_INVOKABLE QVariantMap parseDropInfo(const QString &urlStr);
    
    /// Informa o Wayland sobre a posição de um ícone para animação de minimizar
    Q_INVOKABLE void reportIconGeometry(const QString &command, int x, int y, int w, int h);

    bool windowOverviewOnRefocus() const { return m_windowOverviewOnRefocus; }
    void setWindowOverviewOnRefocus(bool enabled);
    QVariantMap notificationBadges() const { return m_notificationBadges; }
    QVariantMap launcherProgress() const { return m_launcherProgress; }
    /// Centraliza filtro de apps que não devem aparecer na área dinâmica (ex.: Agildo Monitor).
    Q_INVOKABLE bool shouldHideFromDock(const QString &cmd, const QString &name) const;
    /// Persiste snapshot da lista de apps fixadas com escrita atômica.
    Q_INVOKABLE bool saveDockAppsSnapshot(const QString &dockAppsJson) const;
    /// Recupera snapshot salvo (fallback para .bak se necessário).
    Q_INVOKABLE QString loadDockAppsSnapshot() const;
    /// Persistência genérica para presets/perfis/widgets (JSON).
    Q_INVOKABLE bool writeUserJsonFile(const QString &relativeName, const QString &jsonText) const;
    Q_INVOKABLE QString readUserJsonFile(const QString &relativeName) const;
    /// Log de debug com categoria (respeita AGILDO_DOCK_DEBUG e AGILDO_DOCK_DEBUG_CATS).
    Q_INVOKABLE void debugLog(const QString &category, const QString &message) const;
    /// Pausa sinais de progresso durante a animação da onda (evita conflito com blur KWin).
    Q_INVOKABLE void setDockWaveAnimating(bool animating);
    /// 0 = ícone do navegador, 1 = pasta Transferências, 2 = Transferências com ícone do arquivo (macOS).
    Q_INVOKABLE void setDownloadProgressDisplayMode(int mode);

signals:
    void windowsUpdated();
    void activeWindowCoversWorkAreaChanged();
    void windowOverviewOnRefocusChanged();
    void notificationBadgesChanged();
    void launcherProgressChanged();
    /// Só o ícone com cmd correspondente deve reagir (evita repaint global na doca).
    void launcherProgressForCommandChanged(const QString &command);

private slots:
    void completeLaunchApp(const QString &command, const QString &winId);
    void completeCloseApp(const QString &command, const QString &winId);
    void flushBlurRegion();
    void mergeUnityLauncherUpdate(const QString &appUri, const QMap<QString, QVariant> &properties);
    void mergeBrowserDownloadProgress(const QString &command,
                                      double progress,
                                      bool visible,
                                      const QString &filePath,
                                      const QString &fileName);

private:
    void updateSystemState();
    void pollActiveForegroundHints();
    void loadKnownApps();
    void rebuildExecIndex();

    QString resolveWindowTokenForLaunch(const QString &command);
    bool tryShowAppWindowOverview(const QString &command);
    PlasmaWaylandManager *m_waylandManager = nullptr;
    QStringList windowHandlesForCommand(const QString &command);
    QVariantMap matchRunningLineToApp(const QString &cmdLineLower) const;
    static bool appMatchesRunningCmdLine(const QString &cmdLineLower, const QVariantMap &app);
    bool lactHasVisibleWindow(const QString &command) const;

    static QString readProcCmdlineFile(const QString &path);
    static QString execBasenameFromCommand(const QString &command);

    void updateActiveWindowCoversWorkAreaHint();
    void emitWindowsUpdatedCoalesced();
    void setupNotificationBadgeWatcher();
    void refreshNotificationBadgesFromSni();
    void setupUnityLauncherProgressWatcher();
    void setupBrowserDownloadWatcher();
    void updateBrowserDownloadCommand();
    QString commandForUnityAppUri(const QString &appUri) const;
    void applyLauncherProgressForCommand(const QString &cmd, QVariantMap entry, QVariantMap &next) const;
    void notifyLauncherProgressForCommand(const QString &command, bool urgent = false);
    /// Onde exibir progresso de download de navegador (ver setDownloadProgressDisplayMode).
    QString downloadProgressDockCommand(const QString &sourceCommand) const;
    bool publishLauncherProgressForSource(const QString &sourceCommand, QVariantMap entry);
    void enrichLauncherProgressEntry(QVariantMap &entry) const;
    void reapplyActiveDownloadMetadata();
    static QString iconThemeForDownloadFile(const QString &filePath);
    static QString dockAppsSnapshotPath();
    static QString dockAppsSnapshotBackupPath();
    static QString appDataPathForFile(const QString &relativeName);
    bool debugCategoryEnabled(const QString &category) const;

    QHash<QString, QVariantMap> knownApps;
    QMultiHash<QString, QVariantMap> m_appsByExec;
    QHash<QString, QString> m_desktopBasenameToCmd;
    QHash<QString, QString> m_desktopEntryToCmd;
    QHash<QString, QString> m_execBasenameToCmd;
    DockUnityLauncherService *m_unityLauncher = nullptr;
    DockBrowserDownloadWatcher *m_browserDownloadWatcher = nullptr;
    QWindow *m_mainWindow = nullptr;

    QSet<QString> m_runningCmdLines;
    QString m_activeAppClass;
    QString m_activeAppTitle;
    bool m_activeWindowCoversWorkArea = false;

    bool m_kdotoolAvailable = false;
    /// Evita filas de escaneamentos /proc sobrepostos em máquinas lentas.
    bool m_procScanRunning = false;
    /// Última região de blur aplicada — evita recomposição quando x/y/w/h não mudam.
    bool m_hasLastBlur = false;
    int m_lastBlurX = 0;
    int m_lastBlurY = 0;
    int m_lastBlurW = 0;
    int m_lastBlurH = 0;
    int m_lastBlurRadius = 0;
    /// Coalesce várias chamadas QML no mesmo ciclo de eventos antes de falar com o KWin.
    bool m_blurFlushPending = false;
    int m_pendingBlurX = 0;
    int m_pendingBlurY = 0;
    int m_pendingBlurW = 0;
    int m_pendingBlurH = 0;
    int m_pendingBlurRadius = 0;
    /// Descarta conclusões antigas quando há vários cliques rápidos no mesmo comando.
    QHash<QString, quint64> m_launchSeq;
    QHash<QString, quint64> m_closeSeq;
    bool m_debugLogsEnabled = false;
    bool m_windowsUpdatedPending = false;
    bool m_windowOverviewOnRefocus = true;
    QVariantMap m_notificationBadges;
    QVariantMap m_launcherProgress;
    QTimer *m_sniBadgeTimer = nullptr;
    QTimer *m_progressNotifyTimer = nullptr;
    QSet<QString> m_pendingProgressNotifyCmds;
    bool m_dockWaveAnimating = false;
    int m_downloadProgressDisplayMode = 2;
};

#endif // TASKBACKEND_H
