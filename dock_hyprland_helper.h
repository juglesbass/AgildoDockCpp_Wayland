#ifndef DOCK_HYPRLAND_HELPER_H
#define DOCK_HYPRLAND_HELPER_H

#include <QString>
#include <QStringList>
#include <QList>
#include <QHash>
#include <QVariantMap>
#include <QSet>
#include <QObject>
#include <QByteArray>

class QLocalSocket;

struct HyprClient {
    QString address;
    QString cls;
    QString initialClass;
    QString title;
    qint64 pid = 0;
    bool mapped = true;
    bool visible = true;
};

class DockHyprlandHelper {
public:
    static bool isHyprlandActive();

    static QList<HyprClient> getClients();
    static HyprClient getActiveWindow();

    static bool clientMatchesCommand(const HyprClient &client,
                                     const QString &command,
                                     const QHash<QString, QVariantMap> &knownApps);

    static bool isAppRunning(const QString &command,
                             const QHash<QString, QVariantMap> &knownApps,
                             const QSet<QString> &runningCmdLines);

    static bool isAppFocused(const QString &command,
                             const QHash<QString, QVariantMap> &knownApps);

    static int appWindowCount(const QString &command,
                              const QHash<QString, QVariantMap> &knownApps);

    static QStringList windowAddressesForCommand(const QString &command,
                                                 const QHash<QString, QVariantMap> &knownApps);

    static void focusWindow(const QString &address);
    static void minimizeWindow(const QString &address);
    static void closeWindow(const QString &address);

    // --- Configuracao em runtime do compositor -------------------------------
    //
    // Tudo o que segue usa `hyprctl keyword`, que aplica na hora e NAO escreve
    // no ~/.config/hypr/hyprland.conf. A contrapartida e' que se perde num
    // `hyprctl reload` -- por isso o DockHyprlandEventListener abaixo existe.

    // Executa `hyprctl keyword <args...>`. No-op fora do Hyprland.
    static void applyKeyword(const QStringList &keywordArgs);

    // Injeta as layerrule de blur para os tres escopos LayerShell da doca.
    // Idempotente: pode ser chamada quantas vezes for preciso.
    static void applyDockLayerRules();

    static bool anyDolphinWindowExists();
    static bool anyDolphinWindowMatchesScopedTarget(const QString &commandLower);
    static QString firstScopedDolphinWindowId(const QString &commandLower);
    static QStringList allScopedDolphinWindowIds(const QString &commandLower);
};

/*!
 * Ouve o socket de eventos do Hyprland (.socket2.sock) apenas para saber quando
 * a config foi recarregada.
 *
 * Motivo: layerrule e bind aplicados com `hyprctl keyword` sao de runtime e
 * desaparecem num `hyprctl reload`. Sem isto, o utilizador perdia o blur e os
 * atalhos globais da doca a cada reload, sem relacao obvia com a causa.
 *
 * Nao substitui o polling de `hyprctl clients` -- isto ouve UM evento, nada mais.
 */
class DockHyprlandEventListener : public QObject
{
    Q_OBJECT

public:
    explicit DockHyprlandEventListener(QObject *parent = nullptr);

    // Liga ao socket. No-op (e devolve false) fora do Hyprland ou se o socket
    // nao existir.
    bool start();

Q_SIGNALS:
    void configReloaded();

private:
    void onReadyRead();

    QLocalSocket *m_socket = nullptr;
    QByteArray m_buffer;
};

#endif // DOCK_HYPRLAND_HELPER_H
