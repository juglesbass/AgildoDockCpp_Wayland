#ifndef TASKBACKEND_H
#define TASKBACKEND_H

#include <QObject>
#include <QHash>
#include <QMultiHash>
#include <QProcess>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>
#include <QWindow>


class TaskBackend : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool activeWindowCoversWorkArea READ activeWindowCoversWorkArea NOTIFY activeWindowCoversWorkAreaChanged)
    Q_PROPERTY(bool kdotoolAvailable READ kdotoolAvailable CONSTANT)
    Q_PROPERTY(bool windowManagementAvailable READ windowManagementAvailable CONSTANT)
    Q_PROPERTY(bool kwinIntegrationAvailable READ kwinIntegrationAvailable CONSTANT)

public:
    explicit TaskBackend(QObject *parent = nullptr);

    void setMainWindow(QWindow *win);

    bool activeWindowCoversWorkArea() const { return m_activeWindowCoversWorkArea; }
    bool kdotoolAvailable() const { return m_kdotoolAvailable; }
    bool kwinIntegrationAvailable() const;
    bool windowManagementAvailable() const;

    Q_INVOKABLE void updateExclusiveZone(int size);
    /// 0 = None, 1 = Exclusive, 2 = OnDemand (LayerShellQt::Window::KeyboardInteractivity).
    Q_INVOKABLE void applyLayerShellKeyboardMode(int keyboardMode);
    /// Se false, a doca não pede ativação ao aparecer (menos interferência nas outras janelas).
    Q_INVOKABLE void setLayerShellActivateOnShow(bool activate);
    Q_INVOKABLE void setBlurRegion(int x, int y, int w, int h, int radius);
    /// Wayland: remove a faixa superior (em px) da região que recebe ponteiro — cliques passam atrás.
    /// excludeTopPixels <= 0 repõe a superfície completa. Não altera o layout nem os tooltips.
    Q_INVOKABLE void setPointerInputExcludeTop(int excludeTopPixels);
    Q_INVOKABLE QVariantList getUnpinnedApps(const QVariantList &pinnedCmdsVar);
    Q_INVOKABLE void forceLaunchApp(const QString &command);
    Q_INVOKABLE void launchApp(const QString &command);
    Q_INVOKABLE void closeApp(const QString &command, bool killProcessIfNoWindow = false);
    Q_INVOKABLE void closeAllWindows(const QString &command, bool killProcessIfNoWindow = false);
    Q_INVOKABLE int windowCountForCommand(const QString &command);
    Q_INVOKABLE void cycleAppWindows(const QString &command, bool forward);
    Q_INVOKABLE void focusWindowToken(const QString &token);
    Q_INVOKABLE bool isAppRunning(const QString &command);
    Q_INVOKABLE bool isAppFocused(const QString &command);
    Q_INVOKABLE QVariantMap parseDropInfo(const QString &urlStr);
    /// Centraliza filtro de apps que não devem aparecer na área dinâmica (ex.: Agildo Monitor).
      Q_INVOKABLE bool shouldHideFromDock(const QString &cmd, const QString &name) const;
    Q_INVOKABLE void setUserHiddenCommands(const QStringList &cmdFragments);
    Q_INVOKABLE QVariantList windowEntriesForCommand(const QString &command) const;
    Q_INVOKABLE QString plasmaCurrentActivityLabel() const;
    Q_INVOKABLE void setProcPollIntervalMs(int intervalMs);
    Q_INVOKABLE bool saveTextFile(const QString &path, const QString &utf8Text) const;
    Q_INVOKABLE QString loadTextFile(const QString &path) const;
    Q_INVOKABLE QString defaultDockAppsExportPath() const;

signals:
    void windowsUpdated();
    void activeWindowCoversWorkAreaChanged();

private slots:
    void completeLaunchApp(const QString &command, const QString &winId);
    void completeCloseApp(const QString &command, const QString &winId, bool killIfNoWindow = false);
    void flushBlurRegion();

private:
    void updateSystemState();
    void pollActiveForegroundHints();
    void loadKnownApps();
    void rebuildExecIndex();

    QString resolveWindowTokenForLaunch(const QString &command);
    QVariantMap matchRunningLineToApp(const QString &cmdLineLower) const;
    static bool appMatchesRunningCmdLine(const QString &cmdLineLower, const QVariantMap &app);

    static QString readProcCmdlineFile(const QString &path);
    static QString execBasenameFromCommand(const QString &command);

    void updateActiveWindowCoversWorkAreaHint();

    QHash<QString, QVariantMap> knownApps;
    QMultiHash<QString, QVariantMap> m_appsByExec;
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
    QHash<QString, int> m_cycleWindowIndex;
    QTimer *m_pollTimer = nullptr;
    QTimer *m_foregroundTimer = nullptr;
    QStringList m_userHiddenCmdFragments;

    QStringList resolveAllWindowTokens(const QString &command) const;
    QString windowTitleForToken(const QString &token) const;
    void killProcessesForCommand(const QString &command) const;
};

#endif // TASKBACKEND_H
