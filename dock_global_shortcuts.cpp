#include "dock_global_shortcuts.h"

#include <KGlobalAccel>
#include <QAction>
#include <QKeySequence>
#include <QCoreApplication>
#include <QMetaObject>

DockGlobalShortcuts::DockGlobalShortcuts(QObject *targetRoot, QObject *parent)
    : QObject(parent)
    , m_targetRoot(targetRoot)
{
    ensureActions();
}

void DockGlobalShortcuts::ensureActions()
{
    if (!m_targetRoot) {
        return;
    }

    if (!m_openSettings) {
        m_openSettings = new QAction(this);
        m_openSettings->setText(QCoreApplication::translate("DockGlobalShortcuts",
                                                             "AgildoDock — Preferências"));
        m_openSettings->setObjectName(QStringLiteral("AgildoDock_OpenSettings"));
        KGlobalAccel::setGlobalShortcut(m_openSettings, QKeySequence(m_openSettingsSeq));
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
        KGlobalAccel::setGlobalShortcut(m_toggleDock, QKeySequence(m_toggleDockSeq));
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
    KGlobalAccel::setGlobalShortcut(m_openSettings, QKeySequence(m_openSettingsSeq));
}

void DockGlobalShortcuts::setToggleDockShortcut(const QString &sequence)
{
    if (sequence.trimmed().isEmpty() || !m_toggleDock) {
        return;
    }
    m_toggleDockSeq = sequence.trimmed();
    KGlobalAccel::setGlobalShortcut(m_toggleDock, QKeySequence(m_toggleDockSeq));
}
