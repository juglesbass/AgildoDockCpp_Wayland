#ifndef DOCK_UNITY_LAUNCHER_H
#define DOCK_UNITY_LAUNCHER_H

#include <QHash>
#include <QMap>
#include <QObject>
#include <QString>
#include <QVariant>

/// Escuta progresso/badges via com.canonical.Unity.LauncherEntry (mesmo protocolo do Plasma/Latte).
class DockUnityLauncherService : public QObject
{
    Q_OBJECT

public:
    explicit DockUnityLauncherService(QObject *parent = nullptr);

    void setDesktopMaps(const QHash<QString, QString> *basenameToCmd, const QHash<QString, QString> *entryToCmd);
    void rescanExistingLauncherEntries();

    bool unityServiceRegistered() const;
    bool updateSignalConnected() const;

signals:
    void launcherUpdateReceived(const QString &appUri, const QMap<QString, QVariant> &properties);

public slots:
    void onUnityLauncherUpdate(const QString &appUri, const QMap<QString, QVariant> &properties);

private:
    void registerUnityService();
    void connectUpdateSignal();
    void scanServiceForLauncherEntries(const QString &service);
    static bool introspectionContainsLauncherEntry(const QString &xml);

    const QHash<QString, QString> *m_basenameToCmd = nullptr;
    const QHash<QString, QString> *m_entryToCmd = nullptr;
    bool m_unityServiceRegistered = false;
    bool m_updateSignalConnected = false;
};

#endif // DOCK_UNITY_LAUNCHER_H
