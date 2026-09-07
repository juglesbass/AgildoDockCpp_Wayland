#ifndef DOCK_GLOBAL_SHORTCUTS_H
#define DOCK_GLOBAL_SHORTCUTS_H

#include <QObject>
#include <QString>

class QAction;

/*!
 * Atalhos globais da doca — funcionam mesmo quando a doca não tem foco.
 *
 * Duas implementações, escolhidas em runtime:
 *
 *  - Plasma/KWin: KGlobalAccel, como sempre foi.
 *  - Hyprland: não existe KGlobalAccel (as chamadas falhavam com
 *    ServiceUnknown e os atalhos simplesmente não respondiam). Aqui os atalhos
 *    são registados no compositor com `hyprctl keyword bind`, apontando para o
 *    próprio executável com `--open-settings` / `--toggle-dock`; esse processo
 *    efémero fala com a doca em execução pelo DockIpcServer.
 *
 *    Os binds são de runtime: não escrevem no ~/.config/hypr/hyprland.conf.
 *    Como isso significa que se perdem num `hyprctl reload`,
 *    reapplyHyprlandBinds() existe para o listener de `configreloaded` chamar.
 */
class DockGlobalShortcuts : public QObject
{
    Q_OBJECT

public:
    explicit DockGlobalShortcuts(QObject *targetRoot, QObject *parent = nullptr);

    Q_INVOKABLE void setOpenSettingsShortcut(const QString &sequence);
    Q_INVOKABLE void setToggleDockShortcut(const QString &sequence);

    // Volta a registar os binds no compositor. No-op fora do Hyprland.
    void reapplyHyprlandBinds();

private:
    void ensureActions();

    // Converte "Meta+D" na sintaxe do Hyprland ("SUPER, D"). Devolve vazio se
    // a sequência não for representável.
    static QString hyprComboFromSequence(const QString &sequence);

    // Registam/removem um bind no compositor. `flag` é "--open-settings" ou
    // "--toggle-dock".
    void applyHyprBind(const QString &combo, const QString &flag);
    static void removeHyprBind(const QString &combo);

    QObject *m_targetRoot = nullptr;
    QAction *m_openSettings = nullptr;
    QAction *m_toggleDock = nullptr;
    QString m_openSettingsSeq = QStringLiteral("Meta+D");
    QString m_toggleDockSeq = QStringLiteral("Ctrl+Alt+D");

    // Combinações atualmente registadas no Hyprland, para as podermos remover
    // antes de registar outras. Sem isto, mudar o atalho nas Preferências
    // deixava o bind antigo pendurado no compositor.
    QString m_hyprOpenSettingsCombo;
    QString m_hyprToggleDockCombo;
};

#endif
