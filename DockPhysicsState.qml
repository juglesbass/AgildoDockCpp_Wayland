import QtQuick

// Componente encarregado do estado de física da onda, rastreamento do ponteiro e auto-hide.
QtObject {
    id: physicsRoot

    required property var dockRoot
    required property var globalHover
    required property var mainRow
    required property var mainColumn

    property real dockMouseX: -1000
    property real dockMouseY: -1000
    property bool isDraggingOverDock: false
    property real logicalMouseX: -1000
    property real smoothedWaveRowWidth: dockRoot.baseRowWidth

    property bool dockRetracted: false
    property bool dockAutoHideLatched: false

    property real waveAmplitude: 0.0
    property bool waveCollapseArmed: false
    readonly property bool waveBlurAnimating: waveAmpAnim.running || waveCollapseTimer.running || waveCollapseArmed

    onWaveBlurAnimatingChanged: {
        if (typeof taskBackend !== "undefined" && taskBackend) {
            taskBackend.setDockWaveAnimating(waveBlurAnimating)
        }
    }

    Behavior on waveAmplitude {
        NumberAnimation {
            id: waveAmpAnim
            duration: dockRoot.liveWaveInertia === 0
                      ? DockConstants.waveAmpFastDurationMs
                      : (dockRoot.liveWaveInertia === 2
                         ? DockConstants.waveAmpButteryDurationMs
                         : DockConstants.waveAmpSmoothDurationMs)
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (running)
                    physicsRoot.waveCollapseArmed = false
                else if (!physicsRoot.dockHovered && physicsRoot.waveAmplitude < DockConstants.waveAmplitudeCutoff)
                    physicsRoot.waveCollapseArmed = false
            }
        }
    }

    property bool dockHovered: {
        if (!globalHover.hovered && !isDraggingOverDock) return false
        if (physicsRoot.dockRetracted) return false

        var maxIcon = Math.max(dockRoot.liveMinIconSize, dockRoot.liveMaxIconSize) * dockRoot.liveScaleFactor
        var waveExtra = dockRoot.wavePeakDeltaPx * DockConstants.waveHoverSpanFactor * dockRoot.liveScaleFactor * dockRoot.liveWaveIntensity
        var hoverSpan = dockRoot.baseRowWidth + (DockConstants.dockHoverPaddingPx * dockRoot.liveScaleFactor) + waveExtra

        if (dockRoot.dockLayoutVertical) {
            var safeHitX = dockRoot.liveDockEdge === 2
                ? (maxIcon + DockConstants.dockHoverMarginPx)
                : (dockRoot.width - (maxIcon + DockConstants.dockHoverMarginPx))
            var dockTop = (dockRoot.height / 2) - (hoverSpan / 2)
            var dockBottom = dockTop + hoverSpan
            if (dockRoot.liveDockEdge === 2) {
                return (dockMouseX < safeHitX) && (dockMouseY >= dockTop) && (dockMouseY <= dockBottom)
            }
            return (dockMouseX > safeHitX) && (dockMouseY >= dockTop) && (dockMouseY <= dockBottom)
        }

        var safeHitY = dockRoot.height - (maxIcon + DockConstants.dockHoverMarginPx)
        if (dockRoot.liveDockEdge === 1) {
            safeHitY = maxIcon + DockConstants.dockHoverMarginPx
        }
        var dockLeft = (dockRoot.width / 2) - (hoverSpan / 2)
        var dockRight = dockLeft + hoverSpan

        if (dockRoot.liveDockEdge === 1) {
            return (dockMouseY < safeHitY) && (dockMouseX >= dockLeft) && (dockMouseX <= dockRight)
        }
        return (dockMouseY > safeHitY) && (dockMouseX >= dockLeft) && (dockMouseX <= dockRight)
    }

    onDockHoveredChanged: {
        if (dockHovered) {
            waveCollapseArmed = false
            waveCollapseTimer.stop()
            waveAmplitude = 1.0
            smoothedWaveRowWidth = dockRoot.baseRowWidth
            logicalMouseX = -1000
            dockAutoHideLatched = false
            autoHideDockTimer.stop()
            dockRetracted = false
            dockRoot.updateZone()
        } else {
            waveCollapseArmed = true
            dockRoot.hideDockIconTip()
            waveCollapseTimer.restart()
            if (dockRoot.liveBehaviorAutoHide) {
                restartAutoHideTimer()
            }
        }
        applyDockRetractedState()
    }

    property var waveCollapseTimer: Timer {
        interval: DockConstants.waveCollapseIntervalMs
        repeat: false
        onTriggered: {
            if (!physicsRoot.dockHovered) {
                physicsRoot.waveAmplitude = 0.0
                physicsRoot.smoothedWaveRowWidth = dockRoot.baseRowWidth
            }
        }
    }

    property var autoHideDockTimer: Timer {
        repeat: false
        onTriggered: {
            if (!dockRoot.liveBehaviorAutoHide) return
            if (typeof settingsWin !== "undefined" && settingsWin && settingsWin.visible) return
            if (dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || (typeof taskBackend !== "undefined" && taskBackend && taskBackend.isPlasmaEditMode)) return
            if (physicsRoot.dockHovered) return

            physicsRoot.dockAutoHideLatched = true
            physicsRoot.applyDockRetractedState()
        }
    }

    function _processHoverPoint(px, py) {
        if (px === undefined || py === undefined) return;

        dockMouseX = px
        dockMouseY = py

        var tw = dockRoot.dockLayoutVertical ? mainColumn.height : mainRow.width
        if (tw <= 0) {
            tw = dockRoot.baseRowWidth
        }

        var waveOn = waveAmplitude > DockConstants.waveAmplitudeCutoff
        var alpha = 1.0
        if (dockRoot.liveWaveInertia === 2) {
            alpha = waveOn ? DockConstants.waveInertiaButteryActiveAlpha : DockConstants.waveInertiaButteryIdleAlpha
        } else if (dockRoot.liveWaveInertia === 1) {
            alpha = waveOn ? DockConstants.waveInertiaSmoothActiveAlpha : DockConstants.waveInertiaSmoothIdleAlpha
        } else {
            alpha = 1.0
        }

        smoothedWaveRowWidth = Math.max(
            dockRoot.baseRowWidth,
            (smoothedWaveRowWidth * (1.0 - alpha)) + (tw * alpha)
        )

        var lxRaw = 0
        if (dockRoot.dockLayoutVertical) {
            var colTop = (dockRoot.height * 0.5) - (dockRoot.baseRowWidth * 0.5)
            lxRaw = dockMouseY - colTop
        } else {
            var rowLeft = (dockRoot.width * 0.5) - (dockRoot.baseRowWidth * 0.5)
            lxRaw = dockMouseX - rowLeft
        }
        lxRaw = Math.max(0, Math.min(dockRoot.baseRowWidth, lxRaw))

        var beta = 1.0
        if (dockRoot.liveWaveInertia === 0) {
            beta = 1.0
        } else if (dockRoot.liveWaveInertia === 2) {
            beta = waveOn ? DockConstants.waveInertiaButteryActiveAlpha : DockConstants.waveInertiaButteryIdleAlpha
        } else {
            beta = waveOn ? DockConstants.waveInertiaSmoothActiveAlpha : DockConstants.waveInertiaSmoothIdleAlpha
        }
        var lxOut = lxRaw
        if (logicalMouseX > DockConstants.mouseInitializedThreshold) {
            lxOut = logicalMouseX + (lxRaw - logicalMouseX) * beta
        }
        logicalMouseX = lxOut

        if (dockRetracted && dockRevealEdgeHovered()) {
            dockAutoHideLatched = false
            dockRetracted = false
            dockRoot.updateZone()
        }
    }

    function restartAutoHideTimer() {
        if (!dockRoot.liveBehaviorAutoHide) {
            autoHideDockTimer.stop()
            dockAutoHideLatched = false
            return
        }
        if (typeof settingsWin !== "undefined" && settingsWin && settingsWin.visible) {
            autoHideDockTimer.stop()
            dockAutoHideLatched = false
            return
        }
        if (dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || (typeof taskBackend !== "undefined" && taskBackend && taskBackend.isPlasmaEditMode)) {
            autoHideDockTimer.stop()
            dockAutoHideLatched = false
            return
        }
        autoHideDockTimer.interval = Math.max(DockConstants.minAutoHideDelayMs, dockRoot.liveBehaviorAutoHideDelayMs)
        autoHideDockTimer.restart()
    }

    function dockRevealEdgeHovered() {
        if (!globalHover.hovered) return false
        var band = dockRoot.dockRevealBandPx
        switch (dockRoot.liveDockEdge) {
            case 1: return dockMouseY < band
            case 2: return dockMouseX < band
            case 3: return dockMouseX > dockRoot.width - band
            default: return dockMouseY > dockRoot.height - band
        }
    }

    function applyDockRetractedState() {
        if (typeof settingsWin !== "undefined" && settingsWin && settingsWin.visible) {
            dockRetracted = false
            dockAutoHideLatched = false
            dockRoot.updateZone()
            return
        }
        if (dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || (typeof taskBackend !== "undefined" && taskBackend && taskBackend.isPlasmaEditMode)) {
            dockRetracted = false
            dockAutoHideLatched = false
            dockRoot.updateZone()
            return
        }
        if (dockHovered) {
            dockRetracted = false
            dockRoot.updateZone()
            return
        }
        var edgePeek = dockRevealEdgeHovered()
        if (edgePeek) {
            dockRetracted = false
            dockAutoHideLatched = false
            dockRoot.updateZone()
            return
        }

        var dodgeHide = dockRoot.liveBehaviorDodgeWindows && (typeof taskBackend !== "undefined" && taskBackend && taskBackend.activeWindowCoversWorkArea)
        var autoHideHide = dockRoot.liveBehaviorAutoHide && dockAutoHideLatched

        var next = dodgeHide || autoHideHide
        if (next !== dockRetracted) {
            dockRetracted = next
        }
        dockRoot.updateZone()
    }
}
