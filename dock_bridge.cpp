#include "dock_bridge.h"

#include <LayerShellQt/Window>
#include <QtGlobal>
#include <QWindow>

DockBridge::DockBridge(QObject *parent)
    : QObject(parent)
{
}

void DockBridge::setDockWindow(QWindow *dock)
{
    m_dock = dock;
}

void DockBridge::setSettingsWindow(QWindow *settings)
{
    m_settings = settings;
}

void DockBridge::abrirPreferencias()
{
    Q_UNUSED(m_settings);
    emit pedirAbrirPreferencias();
}

void DockBridge::alternarVisibilidadeDock()
{
    if (!m_dock) {
        return;
    }
    m_dockOculta = !m_dockOculta;
    if (m_dockOculta) {
        m_dock->hide();
    } else {
        m_dock->show();
        m_dock->requestActivate();
    }
    emit pedirAlternarVisibilidade();
}

void DockBridge::applyDockAnchor(int anchorIndex)
{
    if (!m_dock) {
        return;
    }
    auto *layer = LayerShellQt::Window::get(m_dock);
    if (!layer) {
        return;
    }
    using W = LayerShellQt::Window;
    const int clamped = qBound(0, anchorIndex, 3);
    switch (clamped) {
    case 1:
        layer->setAnchors(W::Anchors(W::AnchorLeft | W::AnchorTop | W::AnchorBottom));
        break;
    case 2:
        layer->setAnchors(W::Anchors(W::AnchorRight | W::AnchorTop | W::AnchorBottom));
        break;
    case 3:
        layer->setAnchors(W::Anchors(W::AnchorTop | W::AnchorLeft | W::AnchorRight));
        break;
    case 0:
    default:
        layer->setAnchors(W::Anchors(W::AnchorBottom | W::AnchorLeft | W::AnchorRight));
        break;
    }
    m_dock->requestUpdate();
    emit dockAnchorChanged(clamped);
}
