#include "kwin_integration.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QVariant>

namespace {

bool s_checked = false;
bool s_available = false;

void ensureChecked()
{
    if (s_checked) {
        return;
    }
    s_checked = true;
    QDBusInterface iface(QStringLiteral("org.kde.KWin"),
                         QStringLiteral("/KWin"),
                         QStringLiteral("org.kde.KWin"),
                         QDBusConnection::sessionBus());
    s_available = iface.isValid();
}

quint32 activeWindowId()
{
    QDBusMessage msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                      QStringLiteral("/KWin"),
                                                      QStringLiteral("org.kde.KWin"),
                                                      QStringLiteral("activeWindow"));
    QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 500);
    if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
        return 0;
    }
    return reply.arguments().constFirst().toUInt();
}

QVariant readWindowProperty(quint32 wid, const char *prop)
{
    const QString path = QStringLiteral("/KWin/Window/") + QString::number(wid);
    QDBusInterface props(QStringLiteral("org.kde.KWin"),
                         path,
                         QStringLiteral("org.freedesktop.DBus.Properties"),
                         QDBusConnection::sessionBus());
    if (!props.isValid()) {
        return {};
    }
    QDBusReply<QVariant> reply = props.call(QStringLiteral("Get"),
                                            QStringLiteral("org.kde.KWin.Window"),
                                            QString::fromUtf8(prop));
    if (!reply.isValid()) {
        return {};
    }
    return reply.value();
}

} // namespace

namespace KwinIntegration {

bool isAvailable()
{
    ensureChecked();
    return s_available;
}

bool pollActiveWindow(QString *outClassLower, QString *outTitleLower, QSize *outInnerSizeOpt)
{
    if (!isAvailable()) {
        return false;
    }
    const quint32 wid = activeWindowId();
    if (wid == 0) {
        return false;
    }

    const QVariant capVar = readWindowProperty(wid, "caption");
    const QVariant clsVar = readWindowProperty(wid, "resourceClass");
    const QVariant nameVar = readWindowProperty(wid, "resourceName");

    QString cls = clsVar.toString().toLower();
    const QString name = nameVar.toString().toLower();
    if (!name.isEmpty()) {
        cls = cls + QLatin1Char(' ') + name;
    }
    if (cls.trimmed().isEmpty()) {
        return false;
    }

    if (outClassLower) {
        *outClassLower = cls.trimmed();
    }
    if (outTitleLower) {
        *outTitleLower = capVar.toString().toLower();
    }
    if (outInnerSizeOpt) {
        const QVariant wVar = readWindowProperty(wid, "width");
        const QVariant hVar = readWindowProperty(wid, "height");
        const int w = wVar.toInt();
        const int h = hVar.toInt();
        if (w > 0 && h > 0) {
            *outInnerSizeOpt = QSize(w, h);
        }
    }
    return true;
}

} // namespace KwinIntegration
