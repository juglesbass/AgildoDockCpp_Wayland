import QtQuick

Item {
    id: autoHideCtrl

    required property var dockRoot

    property bool liveBehaviorAutoHide: false
    property bool liveBehaviorDodgeWindows: false
    property bool liveBehaviorKeepAppsFocused: false
    property int liveBehaviorAutoHideDelayMs: 900
    property bool dockRetracted: false
    property bool dockAutoHideLatched: false
    readonly property real dockRevealBandPx: 36

    onLiveBehaviorKeepAppsFocusedChanged: applyLayerShellFromSettings()
    onLiveBehaviorDodgeWindowsChanged: applyDockRetractedState()
    onLiveBehaviorAutoHideChanged: {
        restartAutoHideTimer()
        applyDockRetractedState()
    }
    onLiveBehaviorAutoHideDelayMsChanged: restartAutoHideTimer()

    onDockRetractedChanged: {
        dockRoot.updateZone()
    }

    Timer {
        id: autoHideDockTimer
        repeat: false
        onTriggered: {
            if (!liveBehaviorAutoHide) return
            if (dockRoot.settingsWinVisible || dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || taskBackend.isPlasmaEditMode || dockRoot.mainDropAreaContainsDrag) return
            if (dockRoot.wavePhysics.dockHovered) return

            dockAutoHideLatched = true
            applyDockRetractedState()
        }
    }

    function restartAutoHideTimer() {
        if (!liveBehaviorAutoHide) {
            autoHideDockTimer.stop()
            dockAutoHideLatched = false
            return
        }
        if (dockRoot.settingsWinVisible || dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || taskBackend.isPlasmaEditMode) {
            autoHideDockTimer.stop()
            dockAutoHideLatched = false
            return
        }
        autoHideDockTimer.interval = Math.max(DockConstants.minAutoHideDelayMs, liveBehaviorAutoHideDelayMs)
        autoHideDockTimer.restart()
    }

    function applyLayerShellFromSettings() {
        var mode = liveBehaviorKeepAppsFocused ? 0 : 2
        taskBackend.setLayerShellMode(mode)
        taskBackend.setLayerShellActivateOnShow(!liveBehaviorKeepAppsFocused)
    }

    function dockRevealEdgeHovered() {
        if (!dockRoot.dockLayoutVertical && dockRoot.liveDockEdge !== 0 && dockRoot.liveDockEdge !== 1) return false
        if (dockRoot.dockLayoutVertical && dockRoot.liveDockEdge !== 2 && dockRoot.liveDockEdge !== 3) return false

        var band = dockRevealBandPx
        switch (dockRoot.liveDockEdge) {
            case 1: return dockRoot.wavePhysics.dockMouseY < band
            case 2: return dockRoot.wavePhysics.dockMouseX < band
            case 3: return dockRoot.wavePhysics.dockMouseX > dockRoot.width - band
            default: return dockRoot.wavePhysics.dockMouseY > dockRoot.height - band
        }
    }

    function applyDockRetractedState() {
        if (dockRoot.settingsWinVisible || dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || taskBackend.isPlasmaEditMode || dockRoot.mainDropAreaContainsDrag) {
            dockRetracted = false
            dockAutoHideLatched = false
            return
        }
        if (dockRoot.wavePhysics.dockHovered) {
            dockRetracted = false
            return
        }
        var edgePeek = dockRevealEdgeHovered()
        if (edgePeek) {
            dockRetracted = false
            dockAutoHideLatched = false
            return
        }

        var dodgeHide = liveBehaviorDodgeWindows && taskBackend.activeWindowCoversWorkArea
        var autoHideHide = liveBehaviorAutoHide && dockAutoHideLatched
        var next = dodgeHide || autoHideHide

        if (next !== dockRetracted) {
            dockRetracted = next
        }
    }

    function toggleDockGlobal() {
        dockRoot.visible = !dockRoot.visible
        if (dockRoot.visible) {
            dockRoot.raise()
            dockRoot.requestActivate()
        }
    }
}
