import QtQuick
import QtQuick.Controls

// Aviso quando kdotool / gestão de janelas não está disponível.
Rectangle {
    id: banner

    required property var dock

    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 8 * dock.liveScaleFactor
    height: visible ? Math.max(28, label.implicitHeight + 12) : 0
    visible: !taskBackend.windowManagementAvailable
    z: 50000
    radius: 8
    color: Qt.rgba(0.55, 0.22, 0.12, 0.92)
    border.color: "#FFB090"
    border.width: 1

    Label {
        id: label
        anchors.fill: parent
        anchors.margins: 8
        text: qsTr("Instala «kdotool» para focar, minimizar e fechar janelas no Plasma/Wayland.")
        wrapMode: Text.WordWrap
        color: "#FFE8D8"
        font.pixelSize: 11 * dock.liveScaleFactor
        horizontalAlignment: Text.AlignHCenter
    }
}
