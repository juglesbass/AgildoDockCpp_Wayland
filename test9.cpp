#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <iostream>

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    QDBusMessage msg = QDBusMessage::createMethodCall("org.kde.KWin", "/KWin", "org.kde.KWin", "queryWindowInfo");
    QDBusReply<QVariantMap> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 2000);
    if (reply.isValid()) {
        QVariantMap map = reply.value();
        for (auto it = map.constBegin(); it != map.constEnd(); ++it) {
            std::cout << it.key().toStdString() << ": " << it.value().toString().toStdString() << std::endl;
        }
    } else {
        std::cout << "Error: " << reply.error().name().toStdString() << " - " << reply.error().message().toStdString() << std::endl;
    }
    return 0;
}
