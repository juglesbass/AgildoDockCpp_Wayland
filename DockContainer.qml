import QtQuick 2.15
import QtQuick.Layouts 1.15

Item {
    id: containerRoot

    required property var dockRoot

    readonly property alias mainRowRef: mainRow
    readonly property alias mainColumnRef: mainColumn
    readonly property alias dockBgRef: dockBg
    readonly property alias overlayLayerRef: overlayLayer

    function showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData) {
        overlayLayer.showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData)
    }

    function hideDockIconTip() {
        overlayLayer.hideDockIconTip()
    }

    function playMinimizeSuckAt(iconItem) {
        overlayLayer.playMinimizeSuckAt(iconItem)
    }

    function removeMinimizeSuck() {
        overlayLayer.removeMinimizeSuck()
    }

    function syncBlurAfterStyleChange() {
        dockBg.syncBlurAfterStyleChange()
    }

    anchors.fill: parent
    opacity: 0.0

    Accessible.role: Accessible.Pane
    Accessible.name: qsTr("AgildoDock")
    Accessible.description: {
        switch (dockRoot.liveDockEdge) {
            case 1: return qsTr("Dock de aplicações na margem superior do ecrã.")
            case 2: return qsTr("Dock de aplicações na margem esquerda do ecrã.")
            case 3: return qsTr("Dock de aplicações na margem direita do ecrã.")
            default: return qsTr("Dock de aplicações na margem inferior do ecrã.")
        }
    }

    MouseArea {
        anchors.fill: parent
        z: 300000
        enabled: dockRoot.dockContextMenuOpen
        hoverEnabled: false
        propagateComposedEvents: false
        acceptedButtons: Qt.AllButtons
        onPressed: (mouse) => {
            if (typeof iconContextMenu !== "undefined" && iconContextMenu) {
                iconContextMenu.closeMenu()
            } else if (dockRoot.iconContextMenu) {
                dockRoot.iconContextMenu.closeMenu()
            }
            mouse.accepted = true
        }
    }

    property real dockSlidePixels: dockRoot.dockRetracted ? dockRoot.dockRetractSlidePixels : 0
    Behavior on dockSlidePixels {
        enabled: typeof settingsWin !== "undefined" && settingsWin ? !settingsWin.visible : true
        NumberAnimation {
            duration: DockConstants.dockSlideAnimDurationMs
            easing.type: Easing.OutBack
            easing.overshoot: DockConstants.dockSlideEasingOvershoot
        }
    }
    transform: Translate {
        x: dockRoot.liveDockEdge === 2 ? -containerRoot.dockSlidePixels : (dockRoot.liveDockEdge === 3 ? containerRoot.dockSlidePixels : 0)
        y: dockRoot.liveDockEdge === 1 ? -containerRoot.dockSlidePixels : (dockRoot.liveDockEdge === 0 ? containerRoot.dockSlidePixels : 0)
    }

    onDockSlidePixelsChanged: dockBg.syncBlurAfterStyleChange()

    property real startupOffsetY: 0

    onStartupOffsetYChanged: {
        if (startupOffsetY < 0.5)
            dockBg.syncBlurAfterStyleChange()
    }

    Component.onCompleted: {
        startupOffsetY = DockConstants.startupOffsetYPx * dockRoot.liveScaleFactor
        startupAnim.start()
    }

    Timer {
        id: blurStartupSettleTimer
        interval: DockConstants.blurStartupSettleDelayMs
        repeat: false
        onTriggered: dockBg.syncBlurAfterStyleChange()
    }

    ParallelAnimation {
        id: startupAnim
        NumberAnimation {
            target: containerRoot
            property: "opacity"
            from: 0.0
            to: 1.0
            duration: DockConstants.startupFadeDurationMs
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: containerRoot
            property: "startupOffsetY"
            to: 0
            duration: DockConstants.startupSlideDurationMs
            easing.type: Easing.OutBack
        }
        onFinished: {
            dockBg.syncBlurAfterStyleChange()
            blurStartupSettleTimer.restart()
        }
    }

    DockBlurBackground {
        id: dockBg
        dockRoot: containerRoot.dockRoot
        dockContainer: containerRoot
        waveAmpAnim: containerRoot.dockRoot.waveAmpAnim
        onSurfaceContextMenuRequested: (surface, globalX, globalY) =>
            containerRoot.dockRoot.showDockSurfaceContextMenu(surface, globalX, globalY)
    }

    Row {
        id: mainRow
        visible: !containerRoot.dockRoot.dockLayoutVertical
        anchors.horizontalCenter: dockBg.horizontalCenter
        anchors.bottom: containerRoot.dockRoot.liveDockEdge === 0 ? dockBg.bottom : undefined
        anchors.top: containerRoot.dockRoot.liveDockEdge === 1 ? dockBg.top : undefined

        height: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
        spacing: containerRoot.dockRoot.baseSpacing

        add: Transition {
            NumberAnimation { property: "scale"; from: 0; to: 1; duration: DockConstants.iconAddScaleDurationMs; easing.type: Easing.OutBack }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: DockConstants.iconAddOpacityDurationMs }
        }

        Repeater {
            model: containerRoot.dockRoot.launcherModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }
        Repeater {
            model: containerRoot.dockRoot.appModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }

        Item {
            width: containerRoot.dockRoot.dividerWidth
            height: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
            visible: containerRoot.dockRoot.div1Count > 0

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                anchors.topMargin: -containerRoot.dockRoot.dividerExtraHitArea
                anchors.bottomMargin: -DockConstants.dividerHitBottomMarginPx

                function updateLogicalMouse(mx) {
                    if (mx === undefined || isNaN(mx) || width <= 0) return
                    if (containerRoot.dockRoot.dockHovered || containerRoot.dockRoot.waveAmplitude > 0.02) return
                    var logicalStart = ((containerRoot.dockRoot.launcherModel.count + containerRoot.dockRoot.appModel.count) * containerRoot.dockRoot.baseStride) - (containerRoot.dockRoot.baseSpacing / 2)
                    containerRoot.dockRoot.logicalMouseX = logicalStart + ((mx / width) * (containerRoot.dockRoot.dividerWidth + containerRoot.dockRoot.baseSpacing))
                }
                onPositionChanged: { updateLogicalMouse(mouseX) }
                onEntered: { updateLogicalMouse(mouseX) }
            }

            Rectangle {
                width: Math.max(2, Math.round(2 * containerRoot.dockRoot.liveScaleFactor))
                height: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor) * 0.45
                color: containerRoot.dockRoot.themeColors.divider
                anchors.centerIn: parent
                radius: 1
                antialiasing: true
            }
        }

        Repeater {
            model: containerRoot.dockRoot.dynamicModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }

        Item {
            width: containerRoot.dockRoot.dividerWidth
            height: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
            visible: containerRoot.dockRoot.div2Count > 0

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                anchors.topMargin: -containerRoot.dockRoot.dividerExtraHitArea
                anchors.bottomMargin: -40

                function updateLogicalMouse(mx) {
                    if (mx === undefined || isNaN(mx) || width <= 0) return
                    if (containerRoot.dockRoot.dockHovered || containerRoot.dockRoot.waveAmplitude > 0.02) return
                    var prevCount = containerRoot.dockRoot.launcherModel.count + containerRoot.dockRoot.appModel.count + containerRoot.dockRoot.dynamicModel.count
                    var logicalStart = (prevCount * containerRoot.dockRoot.baseStride) + (containerRoot.dockRoot.div1Count * containerRoot.dockRoot.dividerWidth) - (containerRoot.dockRoot.baseSpacing / 2)
                    containerRoot.dockRoot.logicalMouseX = logicalStart + ((mx / width) * (containerRoot.dockRoot.dividerWidth + containerRoot.dockRoot.baseSpacing))
                }
                onPositionChanged: { updateLogicalMouse(mouseX) }
                onEntered: { updateLogicalMouse(mouseX) }
            }

            Rectangle {
                width: Math.max(2, Math.round(2 * containerRoot.dockRoot.liveScaleFactor))
                height: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor) * 0.45
                color: containerRoot.dockRoot.themeColors.divider
                anchors.centerIn: parent
                radius: 1
                antialiasing: true
            }
        }

        Repeater {
            model: containerRoot.dockRoot.systemModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }
    }

    Column {
        id: mainColumn
        visible: containerRoot.dockRoot.dockLayoutVertical
        anchors.verticalCenter: dockBg.verticalCenter
        anchors.left: containerRoot.dockRoot.liveDockEdge === 2 ? dockBg.left : undefined
        anchors.right: containerRoot.dockRoot.liveDockEdge === 3 ? dockBg.right : undefined
        width: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
        spacing: containerRoot.dockRoot.baseSpacing

        add: Transition {
            NumberAnimation { property: "scale"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack }
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
        }

        Repeater {
            model: containerRoot.dockRoot.launcherModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }
        Repeater {
            model: containerRoot.dockRoot.appModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }

        Item {
            width: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
            height: containerRoot.dockRoot.dividerWidth
            visible: containerRoot.dockRoot.div1Count > 0
            Rectangle {
                width: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor) * 0.45
                height: Math.max(2, Math.round(2 * containerRoot.dockRoot.liveScaleFactor))
                color: containerRoot.dockRoot.themeColors.divider
                anchors.centerIn: parent
                radius: 1
            }
        }

        Repeater {
            model: containerRoot.dockRoot.dynamicModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }

        Item {
            width: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor)
            height: containerRoot.dockRoot.dividerWidth
            visible: containerRoot.dockRoot.div2Count > 0
            Rectangle {
                width: Math.round(containerRoot.dockRoot.dockBarHeightPx * containerRoot.dockRoot.liveScaleFactor) * 0.45
                height: Math.max(2, Math.round(2 * containerRoot.dockRoot.liveScaleFactor))
                color: containerRoot.dockRoot.themeColors.divider
                anchors.centerIn: parent
                radius: 1
            }
        }

        Repeater {
            model: containerRoot.dockRoot.systemModel
            delegate: DockIconDelegate { dock: containerRoot.dockRoot }
        }
    }

    DockOverlayLayer {
        id: overlayLayer
        anchors.fill: parent
        dock: containerRoot.dockRoot
        dockEdge: containerRoot.dockRoot.liveDockEdge
        scaleFactor: containerRoot.dockRoot.liveScaleFactor
        themeColors: containerRoot.dockRoot.themeColors
        accentFocus: containerRoot.dockRoot.accentFocus
        accentIdle: containerRoot.dockRoot.accentIdle
        contextMenuOpen: containerRoot.dockRoot.dockContextMenuOpen
        bgX: dockBg.x
        bgY: dockBg.y
        bgW: dockBg.width
        bgH: dockBg.height
    }
}
