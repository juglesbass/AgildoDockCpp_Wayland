import QtQuick

// Fundo da dock: blur KWin, estilos Padrão/Vidro e menu de contexto.
Rectangle {
    id: dockBg

    required property var dockRoot
    required property var dockContainer
    required property var waveAmpAnim

    signal surfaceContextMenuRequested(var surface, real globalX, real globalY)

    anchors.horizontalCenter: (dockRoot.liveDockEdge === 0 || dockRoot.liveDockEdge === 1) ? parent.horizontalCenter : undefined
    anchors.verticalCenter: (dockRoot.liveDockEdge === 2 || dockRoot.liveDockEdge === 3) ? parent.verticalCenter : undefined
    anchors.bottom: dockRoot.liveDockEdge === 0 ? parent.bottom : undefined
    anchors.top: dockRoot.liveDockEdge === 1 ? parent.top : undefined
    anchors.left: dockRoot.liveDockEdge === 2 ? parent.left : undefined
    anchors.right: dockRoot.liveDockEdge === 3 ? parent.right : undefined
    anchors.bottomMargin: dockRoot.liveDockEdge === 0
            ? Math.round((dockRoot.liveDockMargin * dockRoot.liveScaleFactor) - dockContainer.startupOffsetY + dockRoot.liveDockOffsetY)
            : 0
    anchors.topMargin: dockRoot.liveDockEdge === 1
            ? Math.round((dockRoot.liveDockMargin * dockRoot.liveScaleFactor) + dockContainer.startupOffsetY + dockRoot.liveDockOffsetY)
            : 0
    anchors.leftMargin: dockRoot.liveDockEdge === 2
            ? Math.round((dockRoot.liveDockMargin * dockRoot.liveScaleFactor) + dockRoot.liveDockOffsetX)
            : 0
    anchors.rightMargin: dockRoot.liveDockEdge === 3
            ? Math.round((dockRoot.liveDockMargin * dockRoot.liveScaleFactor) - dockRoot.liveDockOffsetX)
            : 0
    transform: Translate {
        x: (dockRoot.liveDockEdge === 0 || dockRoot.liveDockEdge === 1) ? Math.round(dockRoot.liveDockOffsetX) : 0
        y: (dockRoot.liveDockEdge === 2 || dockRoot.liveDockEdge === 3) ? Math.round(dockRoot.liveDockOffsetY) : 0
    }

    readonly property real sidePad: 30 * dockRoot.liveScaleFactor
    readonly property real expansionAmp: waveBlurAnimating
            ? Math.round(dockRoot.waveAmplitude * 80) / 80
            : dockRoot.waveAmplitude
    readonly property real waveExtraWidth: dockRoot.wavePeakDeltaPx * 3.15 * dockRoot.liveScaleFactor * dockRoot.liveWaveIntensity
    readonly property real rawBgSpan: dockRoot.baseRowWidth + sidePad + (waveExtraWidth * expansionAmp)
    readonly property int dockSpanEvenPx: {
        var w = Math.round(rawBgSpan)
        if ((w & 1) !== 0)
            w += 1
        return w
    }
    readonly property real barThickness: Math.round(dockRoot.dockBarHeightPx * dockRoot.liveScaleFactor)

    readonly property bool waveBlurAnimating: dockRoot.waveBlurAnimating

    property int blurLastSentW: -1
    property int blurLastSentH: -1
    property int blurLastSentX: -1
    property int blurLastSentY: -1
    property int blurStableCx: -1
    property int blurStableCy: -1
    property bool waveBlurLayerHold: false

    Timer {
        id: waveBlurLayerHoldTimer
        interval: 48
        repeat: false
        onTriggered: dockBg.waveBlurLayerHold = false
    }

    layer.enabled: false

    function resetBlurCache() {
        blurLastSentW = -1
        blurLastSentH = -1
        blurLastSentX = -1
        blurLastSentY = -1
    }

    function syncBlurAfterStyleChange() {
        resetBlurCache()
        updateBlurNative(true)
        Qt.callLater(function() { dockBg.updateBlurNative(true) })
    }

    function readBlurRectFromScene(bw, bh) {
        var p = dockBg.mapToItem(null, 0, 0)
        var radius = Math.min(
            Math.round(dockBg.radius),
            Math.floor(Math.min(bw, bh) / 2)
        )
        return {
            x: Math.round(p.x),
            y: Math.round(p.y),
            radius: radius
        }
    }

    function flushCollapseBlur() {
        syncBlurAfterStyleChange()
    }

    Connections {
        target: waveAmpAnim
        function onRunningChanged() {
            if (waveAmpAnim.running || dockRoot.dockHovered)
                return
            if (dockRoot.waveAmplitude < 0.05)
                dockBg.flushCollapseBlur()
        }
    }

    function invalidateBlurGeometry() {
        resetBlurCache()
        blurStableCx = -1
        blurStableCy = -1
        updateBlurNative(true)
    }

    Connections {
        target: dockRoot
        function onLiveDockEdgeChanged() {
            dockBg.invalidateBlurGeometry()
            Qt.callLater(function() { dockBg.syncBlurAfterStyleChange() })
        }
        function onWaveBlurAnimatingChanged() {
            blurThrottleTimer.stop()
            if (dockRoot.waveBlurAnimating) {
                if (dockRoot.dockHovered) {
                    waveBlurLayerHoldTimer.stop()
                    waveBlurLayerHold = false
                }
                blurLastSentW = -1
                blurLastSentH = -1
                blurStableCx = Math.round(dockRoot.width / 2) + Math.round(dockRoot.liveDockOffsetX)
                blurStableCy = Math.round(dockRoot.height / 2) + Math.round(dockRoot.liveDockOffsetY)
            } else {
                blurStableCx = -1
                blurStableCy = -1
                if (dockRoot.dockHovered) {
                    waveBlurLayerHold = true
                    waveBlurLayerHoldTimer.restart()
                } else {
                    waveBlurLayerHoldTimer.stop()
                    waveBlurLayerHold = false
                    blurLastSentW = -1
                    blurLastSentH = -1
                }
            }
            updateBlurNative(true)
            if (dockRoot.dockHovered)
                Qt.callLater(function() { dockBg.updateBlurNative(true) })
            else
                Qt.callLater(function() { dockBg.flushCollapseBlur() })
        }
    }

    readonly property bool bgIsFlat: dockRoot.liveBg3dStyle === 0
    readonly property bool bgIsGlass: dockRoot.liveBg3dStyle !== 0

    width: dockRoot.dockLayoutVertical ? barThickness : dockSpanEvenPx
    height: dockRoot.dockLayoutVertical ? dockSpanEvenPx : barThickness

    color: "transparent"
    radius: Math.round(dockRoot.liveDockRadius * dockRoot.liveScaleFactor)
    border.color: Qt.rgba(1, 1, 1, dockRoot.liveBorderGlow)
    border.width: Math.max(1, Math.round(dockRoot.liveBorderWidth))
    antialiasing: true
    clip: true

    Timer {
        id: blurThrottleTimer
        interval: 16
        repeat: false
        onTriggered: dockBg.updateBlurNative()
    }

    function requestBlurUpdate() {
        if (waveBlurAnimating)
            return
        if (!blurThrottleTimer.running)
            blurThrottleTimer.start()
    }

    function updateBlurNative(immediate) {
        if (immediate === undefined)
            immediate = false

        if (dockContainer.startupOffsetY > 0.5)
            return

        var bw = Math.round(dockBg.width)
        var bh = Math.round(dockBg.height)
        if (bw < 10 || bh < 10)
            return
        var rect = readBlurRectFromScene(bw, bh)
        var bx = rect.x
        var by = rect.y
        var radius = rect.radius

        if (bw === blurLastSentW && bh === blurLastSentH
                && bx === blurLastSentX && by === blurLastSentY)
            return

        blurLastSentW = bw
        blurLastSentH = bh
        blurLastSentX = bx
        blurLastSentY = by
        taskBackend.setBlurRegion(bx, by, bw, bh, radius, immediate || waveBlurAnimating)
    }

    onXChanged: requestBlurUpdate()
    onYChanged: requestBlurUpdate()
    onWidthChanged: {
        if (waveBlurAnimating)
            updateBlurNative(true)
        else
            requestBlurUpdate()
    }
    onHeightChanged: {
        if (waveBlurAnimating)
            updateBlurNative(true)
        else
            requestBlurUpdate()
    }
    onRadiusChanged: requestBlurUpdate()

    Component.onCompleted: syncBlurAfterStyleChange()

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, dockBg.radius - 1)
        visible: dockBg.bgIsFlat
        color: Qt.rgba(dockRoot.themeColors.dockR, dockRoot.themeColors.dockG, dockRoot.themeColors.dockB,
                        dockRoot.liveBgOpacity)
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: Math.max(0, dockBg.radius - 1)
        visible: dockBg.bgIsGlass
        antialiasing: true
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: Qt.tint(
                    dockRoot.liveGradientColorA,
                    Qt.rgba(1, 1, 1, Math.max(0.0, dockRoot.liveGradientMix * 0.26)))
            }
            GradientStop {
                position: 0.38
                color: Qt.tint(dockRoot.liveGradientColorB, Qt.rgba(1, 1, 1, 0.03))
            }
            GradientStop {
                position: 0.72
                color: Qt.tint(dockRoot.liveGradientColorB, Qt.rgba(0, 0, 0, 0.03))
            }
            GradientStop {
                position: 1.0
                color: Qt.tint(
                    dockRoot.liveGradientColorC,
                    Qt.rgba(0, 0, 0, Math.max(0.0, 0.16 - (dockRoot.liveGradientMix * 0.20))))
            }
        }
        opacity: dockRoot.liveBgOpacity
    }



    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                const g = dockBg.mapToGlobal(mouse.x, mouse.y)
                dockBg.surfaceContextMenuRequested(dockBg, g.x, g.y)
            }
        }
    }
}
