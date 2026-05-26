import QtQuick

// Gesto: arrastar para baixo na faixa da doca recolhe (auto-hide latch).
MouseArea {
    id: swipeArea

    required property var dock

    anchors.fill: parent
    z: 50
    propagateComposedEvents: true
    preventStealing: false
    enabled: dock.liveGestureSwipeHide && !dock.dockContextMenuOpen

    property real pressY: 0

    onPressed: (mouse) => {
        pressY = mouse.y
        mouse.accepted = false
    }
    onReleased: (mouse) => {
        if (!dock.liveGestureSwipeHide) {
            mouse.accepted = false
            return
        }
        var delta = mouse.y - pressY
        if (delta > 40 * dock.liveScaleFactor && dock.dockHovered) {
            dock.dockAutoHideLatched = true
            dock.applyDockRetractedState()
        }
        mouse.accepted = false
    }
}
