import QtQuick

Item {
    id: wavePhysics

    anchors.fill: parent

    required property var dockRoot

    property real smoothedWaveRowWidth: dockRoot.baseRowWidth
    property real dockMouseX: -1000
    property real dockMouseY: -1000
    property real logicalMouseX: -1000

    property real waveAmplitude: 0.0
    property bool waveCollapseArmed: false

    readonly property bool waveBlurAnimating: dockRoot.waveAmpAnim.running || waveCollapseTimer.running || waveCollapseArmed

    onWaveBlurAnimatingChanged: taskBackend.setDockWaveAnimating(waveBlurAnimating)

    readonly property real wavePeakDeltaPx: Math.max(0, dockRoot.liveMaxIconSize - dockRoot.liveMinIconSize)
    property real maxIconsExpansion: wavePeakDeltaPx * DockConstants.waveExpansionMultiplier * dockRoot.liveScaleFactor * 1.0

    property real dividerExtraHitArea: Math.max(0, (Math.max(dockRoot.liveMinIconSize, dockRoot.liveMaxIconSize) * dockRoot.liveScaleFactor * waveAmplitude) - Math.round(dockRoot.dockBarHeightPx * dockRoot.liveScaleFactor) + (DockConstants.dockTopOverflowOffsetPx * dockRoot.liveScaleFactor))

    property bool dockHovered: {
        if (!globalHover.hovered && !dockRoot.isDraggingOverDock) return false
        if (dockRoot.dockRetracted) return false

        var maxIcon = Math.max(dockRoot.liveMinIconSize, dockRoot.liveMaxIconSize) * dockRoot.liveScaleFactor
        var waveExtra = wavePeakDeltaPx * DockConstants.waveHoverSpanFactor * dockRoot.liveScaleFactor * dockRoot.liveWaveIntensity
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
        var dockLeft = (dockRoot.width / 2) - (hoverSpan / 2)
        var dockRight = dockLeft + hoverSpan
        if (dockRoot.liveDockEdge === 1) { // Topo
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
        } else {
            if (dockRoot.dockContextMenuOpen || dockRoot.isAppMenuOpen || dockRoot.isWidgetPickerOpen || taskBackend.isPlasmaEditMode) {
                return
            }
            waveCollapseArmed = true
            waveCollapseTimer.restart()
        }
    }

    function clampMaxIconSizeForZoomCap() {
        var lo = dockRoot.liveMinIconSize
        var hi = lo * (1.0 + dockRoot.maxIconZoomPercentCap / 100.0)
        dockRoot.liveMaxIconSize = Math.max(lo, Math.min(dockRoot.liveMaxIconSize, hi))
    }

    function setLiveMaxIconZoomPercent(pct) {
        var p = Math.max(0, Math.min(dockRoot.maxIconZoomPercentCap, pct))
        dockRoot.liveMaxIconSize = dockRoot.liveMinIconSize * (1.0 + p / 100.0)
    }

    function _processHoverPoint(px, py) {
        if (px === undefined || py === undefined) return;

        dockMouseX = px
        dockMouseY = py

        var tw = dockRoot.dockLayoutVertical ? dockRoot.mainColumnRef.height : dockRoot.mainRowRef.width
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
            beta = waveOn ? 0.08 : 0.35
        } else {
            beta = waveOn ? 0.22 : 0.50
        }
        var lxOut = lxRaw
        if (logicalMouseX > DockConstants.mouseInitializedThreshold) {
            lxOut = logicalMouseX + (lxRaw - logicalMouseX) * beta
        }
        logicalMouseX = lxOut

        if (dockRoot.dockRetracted && dockRoot.autoHideCtrl.dockRevealEdgeHovered()) {
            dockRoot.autoHideCtrl.dockAutoHideLatched = false
            dockRoot.autoHideCtrl.dockRetracted = false
            dockRoot.updateZone()
        }
    }

    function lockDockForContextMenu(locked, anchorLogicalX) {
        dockRoot.dockContextMenuOpen = locked
        if (locked) {
            waveCollapseTimer.stop()
            waveAmplitude = 0
            smoothedWaveRowWidth = dockRoot.baseRowWidth
            if (anchorLogicalX !== undefined && !isNaN(anchorLogicalX) && anchorLogicalX >= 0) {
                logicalMouseX = anchorLogicalX
            }
            dockRoot.hideDockIconTip()
        } else {
            if (dockHovered) {
                waveAmplitude = 1.0
                smoothedWaveRowWidth = dockRoot.baseRowWidth
            } else {
                waveCollapseTimer.restart()
            }
        }
    }

    HoverHandler {
        id: globalHover
        property bool updatePending: false

        onPointChanged: {
            if (updatePending) return
            updatePending = true
            Qt.callLater(function() {
                updatePending = false
                _processHoverPoint(globalHover.point.position.x, globalHover.point.position.y)
            })
        }
    }

    Timer {
        id: waveCollapseTimer
        interval: DockConstants.waveCollapseIntervalMs
        repeat: false
        onTriggered: {
            if (!dockHovered) {
                waveAmplitude = 0.0
                smoothedWaveRowWidth = dockRoot.baseRowWidth
            }
        }
    }
}
