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

    // Margem inferior: só AnchorBottom (igual ao main.cpp no arranque).
    // Bottom|Left|Right no Plasma desloca a superfície para a esquerda — era o bug ao «Guardar».
    if (clamped == 0) {
        layer->setAnchors(W::AnchorBottom);
        m_dock->requestUpdate();
        emit dockAnchorChanged(0);
        return;
    }

    // Posições lateral/superior: layout QML ainda não adaptado — manter inferior.
    qWarning() << "AgildoDock: posição da doca" << clamped
               << "ainda não suportada; a manter margem inferior.";
    layer->setAnchors(W::AnchorBottom);
    m_dock->requestUpdate();
    emit dockAnchorChanged(clamped);
}
