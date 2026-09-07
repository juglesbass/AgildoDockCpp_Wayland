#include "dock_global_shortcuts.h"
#include "dock_hyprland_helper.h"

#include <KGlobalAccel>
#include <QAction>
#include <QKeySequence>
#include <QKeyCombination>
#include <QCoreApplication>
#include <QMetaObject>
#include <QStringList>

DockGlobalShortcuts::DockGlobalShortcuts(QObject *targetRoot, QObject *parent)
    : QObject(parent)
    , m_targetRoot(targetRoot)
{
    ensureActions();
}

QString DockGlobalShortcuts::hyprComboFromSequence(const QString &sequence)
{
    const QKeySequence seq(sequence);
    if (seq.isEmpty()) {
        return {};
    }

    const QKeyCombination combo = seq[0];
    const Qt::Key key = combo.key();
    if (key == Qt::Key_unknown || key == 0) {
        return {};
    }

    const Qt::KeyboardModifiers mods = combo.keyboardModifiers();
    QStringList modNames;
    if (mods & Qt::MetaModifier) {
        modNames << QStringLiteral("SUPER");
    }
    if (mods & Qt::ControlModifier) {
        modNames << QStringLiteral("CTRL");
    }
    if (mods & Qt::AltModifier) {
        modNames << QStringLiteral("ALT");
    }
    if (mods & Qt::ShiftModifier) {
        modNames << QStringLiteral("SHIFT");
    }

    // QKeySequence(Qt::Key_D).toString() == "D"; F8 -> "F8"; Space -> "Space".
    // O Hyprland resolve o nome do keysym sem distinguir maiúsculas, por isso
    // não é preciso normalizar.
    const QString keyName = QKeySequence(key).toString(QKeySequence::PortableText);
    if (keyName.isEmpty()) {
        return {};
    }

    return modNames.join(QLatin1Char(' ')) + QStringLiteral(", ") + keyName;
}

void DockGlobalShortcuts::applyHyprBind(const QString &combo, const QString &flag)
{
    if (combo.isEmpty()) {
        return;
    }
    // Caminho absoluto, não o nome no PATH: a unidade systemd arranca a doca por
    // caminho completo e o PATH do compositor pode não incluir ~/.local/bin.
    const QString exe = QCoreApplication::applicationFilePath();
    DockHyprlandHelper::applyKeyword({QStringLiteral("bind"),
                                      combo + QStringLiteral(", exec, ") + exe
                                          + QLatin1Char(' ') + flag});
}

void DockGlobalShortcuts::removeHyprBind(const QString &combo)
{
    if (combo.isEmpty()) {
        return;
    }
    DockHyprlandHelper::applyKeyword({QStringLiteral("unbind"), combo});
}

void DockGlobalShortcuts::reapplyHyprlandBinds()
{
    if (!DockHyprlandHelper::isHyprlandActive()) {
        return;
    }
    applyHyprBind(m_hyprOpenSettingsCombo, QStringLiteral("--open-settings"));
    applyHyprBind(m_hyprToggleDockCombo, QStringLiteral("--toggle-dock"));
}

void DockGlobalShortcuts::ensureActions()
{
    if (!m_targetRoot) {
        return;
    }

    const bool isHypr = DockHyprlandHelper::isHyprlandActive();

    if (!m_openSettings) {
        m_openSettings = new QAction(this);
        m_openSettings->setText(QCoreApplication::translate("DockGlobalShortcuts",
                                                             "AgildoDock — Preferências"));
        m_openSettings->setObjectName(QStringLiteral("AgildoDock_OpenSettings"));
        if (isHypr) {
            m_hyprOpenSettingsCombo = hyprComboFromSequence(m_openSettingsSeq);
            applyHyprBind(m_hyprOpenSettingsCombo, QStringLiteral("--open-settings"));
        } else {
            KGlobalAccel::setGlobalShortcut(m_openSettings, QKeySequence(m_openSettingsSeq));
        }
        connect(m_openSettings, &QAction::triggered, this, [this]() {
            if (m_targetRoot) {
                QMetaObject::invokeMethod(m_targetRoot, "openSettingsGlobal");
            }
        });
    }

    if (!m_toggleDock) {
        m_toggleDock = new QAction(this);
        m_toggleDock->setText(QCoreApplication::translate("DockGlobalShortcuts",
                                                          "AgildoDock — Mostrar/Ocultar"));
        m_toggleDock->setObjectName(QStringLiteral("AgildoDock_ToggleDock"));
        if (isHypr) {
            m_hyprToggleDockCombo = hyprComboFromSequence(m_toggleDockSeq);
            applyHyprBind(m_hyprToggleDockCombo, QStringLiteral("--toggle-dock"));
        } else {
            KGlobalAccel::setGlobalShortcut(m_toggleDock, QKeySequence(m_toggleDockSeq));
        }
        connect(m_toggleDock, &QAction::triggered, this, [this]() {
            if (m_targetRoot) {
                QMetaObject::invokeMethod(m_targetRoot, "toggleDockGlobal");
            }
        });
    }
}

void DockGlobalShortcuts::setOpenSettingsShortcut(const QString &sequence)
{
    if (sequence.trimmed().isEmpty() || !m_openSettings) {
        return;
    }
    m_openSettingsSeq = sequence.trimmed();

    if (DockHyprlandHelper::isHyprlandActive()) {
        const QString newCombo = hyprComboFromSequence(m_openSettingsSeq);
        if (newCombo == m_hyprOpenSettingsCombo) {
            return;
        }
        removeHyprBind(m_hyprOpenSettingsCombo);
        m_hyprOpenSettingsCombo = newCombo;
        applyHyprBind(m_hyprOpenSettingsCombo, QStringLiteral("--open-settings"));
        return;
    }

    KGlobalAccel::setGlobalShortcut(m_openSettings, QKeySequence(m_openSettingsSeq));
}

void DockGlobalShortcuts::setToggleDockShortcut(const QString &sequence)
{
    if (sequence.trimmed().isEmpty() || !m_toggleDock) {
        return;
    }
    m_toggleDockSeq = sequence.trimmed();

    if (DockHyprlandHelper::isHyprlandActive()) {
        const QString newCombo = hyprComboFromSequence(m_toggleDockSeq);
        if (newCombo == m_hyprToggleDockCombo) {
            return;
        }
        removeHyprBind(m_hyprToggleDockCombo);
        m_hyprToggleDockCombo = newCombo;
        applyHyprBind(m_hyprToggleDockCombo, QStringLiteral("--toggle-dock"));
        return;
    }

    KGlobalAccel::setGlobalShortcut(m_toggleDock, QKeySequence(m_toggleDockSeq));
}
