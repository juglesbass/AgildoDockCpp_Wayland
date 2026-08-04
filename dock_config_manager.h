#ifndef DOCK_CONFIG_MANAGER_H
#define DOCK_CONFIG_MANAGER_H

#include <QString>

class DockConfigManager {
public:
    static QString dockAppsSnapshotPath();
    static QString dockAppsSnapshotBackupPath();
    static bool saveDockAppsSnapshot(const QString &dockAppsJson);
    static QString loadDockAppsSnapshot();
    static QString appDataPathForFile(const QString &relativeName);
    static bool writeUserJsonFile(const QString &relativeName, const QString &jsonText);
    static QString readUserJsonFile(const QString &relativeName);
};

#endif // DOCK_CONFIG_MANAGER_H
