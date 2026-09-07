#ifndef DOCK_IPC_SERVER_H
#define DOCK_IPC_SERVER_H

#include <QObject>
#include <QString>

class QLocalServer;

/*!
 * Canal de instancia unica da doca.
 *
 * Existe por causa dos atalhos globais no Hyprland: como nao ha' KGlobalAccel,
 * os atalhos sao registados no compositor com `hyprctl keyword bind ... exec,
 * agildodock --toggle-dock`. Cada pressao arranca um processo novo, que precisa
 * de falar com a doca que JA' esta' a correr em vez de subir uma segunda doca.
 *
 * Protocolo: uma linha de texto por comando ("toggle-dock" ou "open-settings").
 */
class DockIpcServer : public QObject
{
    Q_OBJECT

public:
    // Nome do socket, derivado do WAYLAND_DISPLAY para nao colidir entre
    // sessoes simultaneas do mesmo utilizador.
    static QString socketName();

    /*!
     * Tenta entregar \a command a uma doca ja' em execucao.
     * Devolve true se houve uma doca do outro lado que aceitou o comando --
     * nesse caso quem chamou deve simplesmente sair.
     */
    static bool sendToRunningInstance(const QString &command, int timeoutMs = 400);

    /*!
     * Ha' outra doca viva nesta sessao?
     *
     * Limita-se a tentar ligar ao socket, sem escrever nada: se alguem atende,
     * ha' doca do outro lado. Serve para o arranque SEM argumentos, que ate'
     * agora nao verificava nada e subia uma segunda doca por cima da primeira.
     */
    static bool isAnotherInstanceRunning(int timeoutMs = 400);

    explicit DockIpcServer(QObject *parent = nullptr);

    // Comeca a escutar. Devolve false se nao conseguir (nesse caso os atalhos
    // globais via hyprctl nao funcionam, mas a doca corre normalmente).
    bool listen();

Q_SIGNALS:
    void openSettingsRequested();
    void toggleDockRequested();

private:
    void onNewConnection();

    QLocalServer *m_server = nullptr;
};

#endif // DOCK_IPC_SERVER_H
