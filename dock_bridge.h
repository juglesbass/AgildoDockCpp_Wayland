#ifndef DOCK_BRIDGE_H
#define DOCK_BRIDGE_H

#include <QObject>

class QWindow;

/// Ponte QML ↔ C++ para atalhos globais e âncoras Layer Shell.
class DockBridge : public QObject
{
    Q_OBJECT

public:
    explicit DockBridge(QObject *parent = nullptr);

    void setDockWindow(QWindow *dock);
    void setSettingsWindow(QWindow *settings);

public slots:
    void abrirPreferencias();
    void alternarVisibilidadeDock();
    void applyDockAnchor(int anchorIndex);

signals:
    void pedirAbrirPreferencias();
    void pedirAlternarVisibilidade();
    void dockAnchorChanged(int anchorIndex);

private:
    QWindow *m_dock = nullptr;
    QWindow *m_settings = nullptr;
    bool m_dockOculta = false;
};

#endif
