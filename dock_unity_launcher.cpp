#include "dock_unity_launcher.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusReply>
#include <QXmlStreamReader>

DockUnityLauncherService::DockUnityLauncherService(QObject *parent)
    : QObject(parent)
{
    registerUnityService();
    connectUpdateSignal();

    if (QDBusConnectionInterface *bus = QDBusConnection::sessionBus().interface()) {
        connect(bus, &QDBusConnectionInterface::serviceRegistered, this, [this](const QString &service) {
            if (!service.startsWith(QLatin1Char(':'))) {
                scanServiceForLauncherEntries(service);
            }
        });
    }

    rescanExistingLauncherEntries();
}

void DockUnityLauncherService::setDesktopMaps(const QHash<QString, QString> *basenameToCmd,
                                              const QHash<QString, QString> *entryToCmd)
{
    m_basenameToCmd = basenameToCmd;
    m_entryToCmd = entryToCmd;
    Q_UNUSED(m_basenameToCmd)
    Q_UNUSED(m_entryToCmd)
}

void DockUnityLauncherService::registerUnityService()
{
    QDBusConnection session = QDBusConnection::sessionBus();
    const QString unityService = QStringLiteral("com.canonical.Unity");

    // Latte/outra dock pode já possuir o nome — só escutamos LauncherEntry nesse caso.
    if (QDBusConnectionInterface *bus = session.interface()) {
        if (bus->isServiceRegistered(unityService)) {
            m_unityServiceRegistered = false;
            return;
        }
    }

    session.registerObject(QStringLiteral("/Unity"), this);
    m_unityServiceRegistered = session.registerService(unityService);
}

void DockUnityLauncherService::connectUpdateSignal()
{
    m_updateSignalConnected = QDBusConnection::sessionBus().connect(QString(),
                                                                    QString(),
                                                                    QStringLiteral("com.canonical.Unity.LauncherEntry"),
                                                                    QStringLiteral("Update"),
                                                                    this,
                                                                    SLOT(onUnityLauncherUpdate(QString, QMap<QString, QVariant>)));
}

bool DockUnityLauncherService::introspectionContainsLauncherEntry(const QString &xml)
{
    return xml.contains(QStringLiteral("com.canonical.Unity.LauncherEntry"));
}

static void collectChildPaths(const QString &xml, const QString &parentPath, QStringList *paths)
{
    QXmlStreamReader reader(xml);
    QString current = parentPath;
    while (!reader.atEnd()) {
        reader.readNext();
        if (reader.tokenType() == QXmlStreamReader::StartElement && reader.name() == QLatin1String("node")) {
            const QString name = reader.attributes().value(QStringLiteral("name")).toString();
            if (name.isEmpty()) {
                continue;
            }
            current = parentPath.endsWith(QLatin1Char('/')) || parentPath.isEmpty()
                ? parentPath + name
                : parentPath + QLatin1Char('/') + name;
            if (name != QLatin1String("org") && name != QLatin1String("freedesktop")) {
                paths->append(current.startsWith(QLatin1Char('/')) ? current : QStringLiteral("/") + current);
            }
        }
    }
}

void DockUnityLauncherService::scanServiceForLauncherEntries(const QString &service)
{
    QStringList pending;
    pending.append(QStringLiteral("/"));

    while (!pending.isEmpty()) {
        const QString path = pending.takeFirst();
        QDBusInterface introspect(service,
                                  path,
                                  QStringLiteral("org.freedesktop.DBus.Introspectable"),
                                  QDBusConnection::sessionBus());
        if (!introspect.isValid()) {
            continue;
        }

        const QDBusReply<QString> xmlReply = introspect.call(QStringLiteral("Introspect"));
        if (!xmlReply.isValid()) {
            continue;
        }
        const QString xml = xmlReply.value();

        if (introspectionContainsLauncherEntry(xml)) {
            QDBusInterface queryIface(service,
                                      path,
                                      QStringLiteral("com.canonical.Unity.LauncherEntry"),
                                      QDBusConnection::sessionBus());
            if (queryIface.isValid()) {
                const QDBusMessage reply = queryIface.call(QStringLiteral("Query"));
                if (reply.type() == QDBusMessage::ReplyMessage && reply.arguments().size() >= 2) {
                    const QString appUri = reply.arguments().at(0).toString();
                    const QMap<QString, QVariant> props =
                        qdbus_cast<QMap<QString, QVariant>>(reply.arguments().at(1));
                    if (!appUri.isEmpty() && !props.isEmpty()) {
                        onUnityLauncherUpdate(appUri, props);
                    }
                }
            }
        }

        QStringList children;
        collectChildPaths(xml, path == QStringLiteral("/") ? QString() : path, &children);
        for (const QString &child : children) {
            pending.append(child);
        }
    }
}

void DockUnityLauncherService::rescanExistingLauncherEntries()
{
    QDBusConnectionInterface *iface = QDBusConnection::sessionBus().interface();
    if (!iface) {
        return;
    }
    const QStringList services = iface->registeredServiceNames();
    for (const QString &service : services) {
        if (service.startsWith(QLatin1Char(':'))) {
            continue;
        }
        scanServiceForLauncherEntries(service);
    }
}

void DockUnityLauncherService::onUnityLauncherUpdate(const QString &appUri,
                                                     const QMap<QString, QVariant> &properties)
{
    emit launcherUpdateReceived(appUri, properties);
}

bool DockUnityLauncherService::unityServiceRegistered() const
{
    return m_unityServiceRegistered;
}

bool DockUnityLauncherService::updateSignalConnected() const
{
    return m_updateSignalConnected;
}
