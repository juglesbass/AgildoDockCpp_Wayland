import QtQuick

// Camada de overlay para tooltip e efeito minimize-suck.
// Instanciado dentro de dockContainer em main.qml.
// Comunica com os delegates apenas por funções expostas — sem property bindings compartilhados.
Item {
    id: overlayRoot
    anchors.fill: parent

    // ── Required properties passadas pelo pai ──
    required property var dock          // root Window (para DockWindowPreviewTooltip)
    required property int dockEdge
    required property real scaleFactor
    required property var themeColors
    required property color accentFocus
    required property color accentIdle
    required property bool contextMenuOpen
    required property real bgX
    required property real bgY
    required property real bgW
    required property real bgH

    // ── Estado interno do tooltip ──
    property bool tipVisible: false
    property string tipName: ""
    property string tipStatus: ""
    property color tipStatusColor: "#00E5FF"
    property string tipHint: ""
    property real tipAnchorX: 0
    property real tipAnchorY: 0
    property var tipWindowData: null

    // ── Estado interno do minimize-suck ──
    property int _suckSerial: 0

    // ══════════════════════════════════════════════════════════════════
    //  API pública — chamada pelos delegates via dock forwarders
    // ══════════════════════════════════════════════════════════════════

    function showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData) {
        if (!iconItem) return
        var pTop = iconItem.mapToItem(overlayRoot, iconItem.width * 0.5, 0)
        var pCenter = iconItem.mapToItem(overlayRoot, iconItem.width * 0.5, iconItem.height * 0.5)
        tipAnchorX = pCenter.x
        tipAnchorY = pTop.y
        tipName = name !== undefined ? name : ""
        tipStatus = statusLine !== undefined ? statusLine : ""
        tipStatusColor = statusColor
        tipHint = hintLine !== undefined ? hintLine : ""
        tipWindowData = winData || null
        tipVisible = tipName.length > 0
    }

    function hideDockIconTip() {
        tipVisible = false
    }

    function playMinimizeSuckAt(iconItem) {
        if (!iconItem) return
        var center = iconItem.mapToItem(overlayRoot, iconItem.width * 0.5, iconItem.height * 0.5)
        var startY = Math.max(0, bgY - (DockConstants.minimizeSuckStartOffsetYPx * scaleFactor))
        var uid = ++_suckSerial
        minimizeSuckModel.append({
            uid: uid,
            startX: center.x,
            startY: startY,
            destX: center.x,
            destY: center.y,
            size: Math.max(DockConstants.minMinimizeSuckSizePx,
                           DockConstants.baseMinimizeSuckSizePx * scaleFactor),
            durationMs: DockConstants.minimizeSuckDurationMs
        })
    }

    function _removeSuck(uid) {
        for (let i = minimizeSuckModel.count - 1; i >= 0; i--) {
            if (minimizeSuckModel.get(i).uid === uid) {
                minimizeSuckModel.remove(i)
                return
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    //  Tooltip visual (z: 200000)
    // ══════════════════════════════════════════════════════════════════

    Item {
        id: dockGlobalTip
        z: 200000
        visible: overlayRoot.tipVisible && !overlayRoot.contextMenuOpen
        width: windowPreviewCard.visible ? windowPreviewCard.implicitWidth : globalTipBox.width
        height: windowPreviewCard.visible ? windowPreviewCard.implicitHeight : globalTipBox.height

        readonly property real marginGap: Math.round(10 * overlayRoot.scaleFactor)

        x: {
            var edge = overlayRoot.dockEdge
            if (edge === 2) {
                return Math.round(overlayRoot.bgX + overlayRoot.bgW + marginGap)
            } else if (edge === 3) {
                return Math.round(overlayRoot.bgX - width - marginGap)
            } else {
                var targetX = overlayRoot.tipAnchorX - (width * 0.5)
                return Math.round(Math.max(8, Math.min(targetX, overlayRoot.width - width - 8)))
            }
        }

        y: {
            var edge = overlayRoot.dockEdge
            if (edge === 1) {
                return Math.round(overlayRoot.bgY + overlayRoot.bgH + marginGap)
            } else if (edge === 2 || edge === 3) {
                var targetY = overlayRoot.tipAnchorY - (height * 0.5)
                return Math.round(Math.max(8, Math.min(targetY, overlayRoot.height - height - 8)))
            } else {
                var iconTop = Math.min(overlayRoot.bgY, overlayRoot.tipAnchorY)
                return Math.round(iconTop - height - marginGap)
            }
        }

        DockWindowPreviewTooltip {
            id: windowPreviewCard
            dock: overlayRoot.dock
            windowData: overlayRoot.tipWindowData
            visible: overlayRoot.tipWindowData && overlayRoot.tipWindowData.isRunning
        }

        Rectangle {
            id: globalTipBox
            visible: !windowPreviewCard.visible
            property real tipInnerWidth: Math.min(
                320,
                Math.max(
                    globalTipName.implicitWidth,
                    globalTipStatus.visible ? globalTipStatus.implicitWidth : 0,
                    globalTipHint.visible ? globalTipHint.implicitWidth : 0,
                    80
                )
            )
            width: tipInnerWidth + 24
            height: globalTipColumn.implicitHeight + 12
            radius: 8
            color: overlayRoot.themeColors.tipBg
            border.color: overlayRoot.themeColors.tipBorder
            border.width: 1
            clip: true

            Column {
                id: globalTipColumn
                x: 12
                y: 6
                spacing: 4
                width: globalTipBox.tipInnerWidth

                Text {
                    id: globalTipName
                    width: globalTipBox.tipInnerWidth
                    text: overlayRoot.tipName
                    font.bold: true
                    font.pixelSize: 13
                    color: overlayRoot.themeColors.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    maximumLineCount: 1
                }
                Text {
                    id: globalTipStatus
                    visible: text.length > 0
                    width: globalTipBox.tipInnerWidth
                    text: overlayRoot.tipStatus
                    font.pixelSize: 12
                    color: overlayRoot.tipStatusColor
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.NoWrap
                }
                Text {
                    id: globalTipHint
                    visible: text.length > 0
                    width: globalTipBox.tipInnerWidth
                    text: overlayRoot.tipHint
                    font.pixelSize: 12
                    color: overlayRoot.themeColors.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    //  Minimize-suck overlay (z: 210000)
    // ══════════════════════════════════════════════════════════════════

    Item {
        id: minimizeSuckOverlay
        anchors.fill: parent
        z: 210000

        ListModel {
            id: minimizeSuckModel
        }

        Repeater {
            model: minimizeSuckModel
            delegate: Item {
                required property int uid
                required property real startX
                required property real startY
                required property real destX
                required property real destY
                required property real size
                required property int durationMs

                x: startX - (size * 0.5)
                y: startY - (size * 0.5)
                width: size
                height: size
                opacity: 0.0
                scale: 1.0

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: width * 0.5
                    color: overlayRoot.accentFocus
                    opacity: 0.85
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.9
                    height: parent.height * 0.44
                    radius: height * 0.5
                    color: overlayRoot.accentIdle
                    opacity: 0.45
                    rotation: -90
                }

                ParallelAnimation {
                    running: true
                    NumberAnimation {
                        target: parent
                        property: "x"
                        to: destX - (size * 0.5)
                        duration: durationMs
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: parent
                        property: "y"
                        to: destY - (size * 0.5)
                        duration: durationMs
                        easing.type: Easing.InCubic
                    }
                    NumberAnimation {
                        target: parent
                        property: "scale"
                        to: 0.2
                        duration: durationMs
                        easing.type: Easing.InCubic
                    }
                    SequentialAnimation {
                        NumberAnimation {
                            target: parent
                            property: "opacity"
                            from: 0.0
                            to: 0.9
                            duration: Math.max(40, durationMs * 0.30)
                            easing.type: Easing.OutQuad
                        }
                        NumberAnimation {
                            target: parent
                            property: "opacity"
                            to: 0.0
                            duration: Math.max(90, durationMs * 0.70)
                            easing.type: Easing.InQuad
                        }
                    }
                    onFinished: overlayRoot._removeSuck(uid)
                }
            }
        }
    }
}
