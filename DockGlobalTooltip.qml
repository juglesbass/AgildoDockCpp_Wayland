import QtQuick

// Tooltip global dos ícones (coordenadas relativas ao dockContainer).
Item {
    id: tipRoot

    required property var dock

    z: 200000
    visible: dock.dockTipVisible && !dock.dockContextMenuOpen
    x: Math.round(dock.dockTipAnchorX - (width * 0.5))
    y: Math.round(dock.dockTipAnchorY - height - (8 * dock.liveScaleFactor))
    width: globalTipBox.width
    height: globalTipBox.height

    Rectangle {
        id: globalTipBox
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
        color: dock.useLightChrome ? "#F0F0F4" : "#F0222222"
        border.color: dock.useLightChrome ? "#40000000" : "#70FFFFFF"
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
                text: dock.dockTipName
                font.bold: true
                font.pixelSize: 13
                color: dock.useLightChrome ? "#111111" : "#FFFFFF"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                maximumLineCount: 1
            }
            Text {
                id: globalTipStatus
                visible: text.length > 0
                width: globalTipBox.tipInnerWidth
                text: dock.dockTipStatus
                font.pixelSize: 12
                color: dock.dockTipStatusColor
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                id: globalTipHint
                visible: text.length > 0
                width: globalTipBox.tipInnerWidth
                text: dock.dockTipHint
                font.pixelSize: 12
                color: dock.useLightChrome ? "#444444" : "#CCCCCC"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
        }
    }
}
