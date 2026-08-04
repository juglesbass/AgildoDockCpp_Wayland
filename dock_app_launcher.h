#ifndef DOCK_APP_LAUNCHER_H
#define DOCK_APP_LAUNCHER_H

#include <QString>

class TaskBackend;

class DockAppLauncher {
public:
    explicit DockAppLauncher(TaskBackend *backend);

    void forceLaunchApp(const QString &command);
    bool tryShowAppWindowOverview(const QString &command);
    void completeLaunchApp(const QString &command, const QString &winId);
    void launchApp(const QString &command);
    void completeCloseApp(const QString &command, const QString &winId);
    void closeApp(const QString &command);
    void cycleAppWindows(const QString &command, int direction);

private:
    TaskBackend *m_backend;
};

#endif // DOCK_APP_LAUNCHER_H
