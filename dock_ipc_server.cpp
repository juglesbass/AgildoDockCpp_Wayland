#include "dock_ipc_server.h"

#include <QLocalServer>
#include <QLocalSocket>
#include <QDebug>

namespace {
    const char *kCmdOpenSettings = "open-settings";
    const char *kCmdToggleDock = "toggle-dock";
}

QString DockIpcServer::socketName()
{
    const QByteArray display = qgetenv("WAYLAND_DISPLAY");
    const QString suffix = display.isEmpty() ? QStringLiteral("default")
                                             : QString::fromLocal8Bit(display);
    return QStringLiteral("agildodock-") + suffix;
}

bool DockIpcServer::sendToRunningInstance(const QString &command, int timeoutMs)
{
    QLocalSocket socket;
    socket.connectToServer(socketName(), QIODevice::WriteOnly);
    if (!socket.waitForConnected(timeoutMs)) {
        return false;
    }

    socket.write(command.toUtf8() + '\n');
    if (!socket.waitForBytesWritten(timeoutMs)) {
        return false;
    }
    socket.disconnectFromServer();
    return true;
}

bool DockIpcServer::isAnotherInstanceRunning(int timeoutMs)
{
    QLocalSocket socket;
    socket.connectToServer(socketName(), QIODevice::ReadOnly);
    if (!socket.waitForConnected(timeoutMs)) {
        return false;
    }
    socket.disconnectFromServer();
    return true;
}

DockIpcServer::DockIpcServer(QObject *parent)
    : QObject(parent)
{
}

bool DockIpcServer::listen()
{
    if (m_server) {
        return m_server->isListening();
    }

    const QString name = socketName();

    // Limpa socket orfao deixado por um crash anterior. Sem isto o listen()
    // falha com AddressInUseError e a doca perde os atalhos globais para
    // sempre, ate' o utilizador apagar o ficheiro a' mao.
    //
    // Mas SO' se ninguem estiver do outro lado: antes esta linha corria sempre,
    // e por isso uma segunda doca roubava o socket a' primeira -- o canal de
    // instancia unica ficava a apontar para a instancia errada, e as duas docas
    // continuavam a correr sobrepostas.
    if (!isAnotherInstanceRunning(200)) {
        QLocalServer::removeServer(name);
    }

    m_server = new QLocalServer(this);
    connect(m_server, &QLocalServer::newConnection, this, &DockIpcServer::onNewConnection);

    if (!m_server->listen(name)) {
        qWarning() << "AgildoDock: nao foi possivel escutar no socket" << name
                   << "-" << m_server->errorString();
        delete m_server;
        m_server = nullptr;
        return false;
    }
    return true;
}

void DockIpcServer::onNewConnection()
{
    while (QLocalSocket *client = m_server->nextPendingConnection()) {
        connect(client, &QLocalSocket::disconnected, client, &QLocalSocket::deleteLater);
        connect(client, &QLocalSocket::readyRead, this, [this, client]() {
            while (client->canReadLine()) {
                const QByteArray line = client->readLine().trimmed();
                if (line == kCmdOpenSettings) {
                    Q_EMIT openSettingsRequested();
                } else if (line == kCmdToggleDock) {
                    Q_EMIT toggleDockRequested();
                }
            }
        });
    }
}
