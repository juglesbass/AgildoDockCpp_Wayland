#ifndef DOCK_GLOBAL_SHORTCUTS_H
#define DOCK_GLOBAL_SHORTCUTS_H

#include <QObject>
#include <QString>

class QAction;

/*!
 * Atalhos globais via KGlobalAccel — funcionam mesmo quando a doca não tem foco.
 */
class DockGlobalShortcuts : public QObject
{
    Q_OBJECT

public:
    explicit DockGlobalShortcuts(QObject *targetRoot, QObject *parent = nullptr);

    Q_INVOKABLE void setOpenSettingsShortcut(const QString &sequence);
    Q_INVOKABLE void setToggleDockShortcut(const QString &sequence);

private:
    void ensureActions();

    QObject *m_targetRoot = nullptr;
    QAction *m_openSettings = nullptr;
    QAction *m_toggleDock = nullptr;
    QString m_openSettingsSeq = QStringLiteral("Meta+D");
    QString m_toggleDockSeq = QStringLiteral("Ctrl+Alt+D");
};

#endif
