import QtQuick
import QtQuick.Controls

// Pequenos widgets opcionais à direita da barra (relógio, actividade Plasma).
Row {
    id: strip

    required property var dock

    spacing: dock.baseSpacing
    height: Math.round(dock.dockBarHeightPx * dock.liveScaleFactor)
    visible: dock.liveShowClockWidget || dock.liveShowActivityLabel

    Label {
        visible: dock.liveShowActivityLabel && activityText.length > 0
        text: activityText
        color: dock.useLightChrome ? "#333333" : "#AAAAAA"
        font.pixelSize: 10 * dock.liveScaleFactor
        elide: Text.ElideRight
        maximumLineCount: 1
        width: Math.min(120 * dock.liveScaleFactor, implicitWidth)

        property string activityText: taskBackend.plasmaCurrentActivityLabel()

        Timer {
            interval: 5000
            running: strip.visible && dock.liveShowActivityLabel
            repeat: true
            triggeredOnStart: true
            onTriggered: parent.activityText = taskBackend.plasmaCurrentActivityLabel()
        }
    }

    Label {
        visible: dock.liveShowClockWidget
        text: Qt.formatTime(new Date(), "HH:mm")
        color: dock.useLightChrome ? "#111111" : "#EEEEEE"
        font.pixelSize: 12 * dock.liveScaleFactor
        font.bold: true

        Timer {
            interval: 30000
            running: parent.visible
            repeat: true
            onTriggered: parent.text = Qt.formatTime(new Date(), "HH:mm")
        }
    }
}
