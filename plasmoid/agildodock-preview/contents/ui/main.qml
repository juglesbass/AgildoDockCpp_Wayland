import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root
    implicitWidth: 420
    implicitHeight: 74
    property bool dockHovering: false
    property real hoverX: -1
    property int iconSlot: 42
    property int iconSpacing: 2
    property int dockHorizontalPadding: 12
    property int dockVerticalPadding: 8

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    ListModel {
        id: dockApps
        ListElement { iconName: "system-file-manager"; name: "Dolphin"; desktopId: "org.kde.dolphin.desktop" }
        ListElement { iconName: "utilities-terminal"; name: "Konsole"; desktopId: "org.kde.konsole.desktop" }
        ListElement { iconName: "systemsettings"; name: "Configuracoes"; desktopId: "systemsettings.desktop" }
        ListElement { iconName: "applications-internet"; name: "Navegador"; desktopId: "org.chromium.Chromium.desktop" }
    }

    // Executa comandos para abrir aplicativos pelo desktop file.
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
    }

    Item {
        id: dockContainer
        anchors.centerIn: parent
        width: Math.max(
                   180,
                   (dockApps.count * root.iconSlot)
                   + (Math.max(0, dockApps.count - 1) * root.iconSpacing)
                   + (root.dockHorizontalPadding * 2))
        height: root.iconSlot + (root.dockVerticalPadding * 2)

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0.08, 0.08, 0.09, 0.80)
            border.color: Qt.rgba(1, 1, 1, 0.14)
            border.width: 1
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.dockHorizontalPadding
            anchors.rightMargin: root.dockHorizontalPadding
            anchors.topMargin: root.dockVerticalPadding
            anchors.bottomMargin: root.dockVerticalPadding
            spacing: root.iconSpacing

            Repeater {
                model: dockApps

                delegate: Item {
                    id: iconHost
                    Layout.preferredWidth: root.iconSlot
                    Layout.preferredHeight: root.iconSlot

                    property bool hovering: mouseArea.containsMouse
                    property real iconCenterX: iconHost.mapToItem(dockContainer, width / 2, height / 2).x
                    property real pointerDistance: Math.abs(iconCenterX - root.hoverX)
                    // Onda suave e contínua com base na distância ao cursor.
                    property real waveScale: {
                        if (!root.dockHovering || root.hoverX < 0) {
                            return 1.0
                        }
                        const sigma = 44.0
                        const gauss = Math.exp(-(pointerDistance * pointerDistance) / (2.0 * sigma * sigma))
                        return 1.0 + (0.40 * gauss)
                    }
                    property bool launching: false

                    Rectangle {
                        anchors.centerIn: parent
                        width: 40
                        height: 40
                        radius: 10
                        color: hovering ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                        border.width: hovering ? 1 : 0
                        border.color: Qt.rgba(1, 1, 1, 0.25)
                    }

                    Kirigami.Icon {
                        id: iconItem
                        anchors.centerIn: parent
                        width: 30
                        height: 30
                        source: model.iconName
                        scale: iconHost.waveScale * (iconHost.launching ? 1.12 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 130
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        width: 5
                        height: 5
                        radius: 3
                        color: Qt.rgba(0.40, 0.78, 1.0, 0.95)
                        visible: iconHost.hovering
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            iconHost.launching = true
                            launchAnim.restart()
                            executable.connectSource("kioclient6 exec applications:" + model.desktopId)
                        }
                    }

                    PlasmaComponents3.ToolTip {
                        text: model.name
                        visible: mouseArea.containsMouse
                    }

                    SequentialAnimation {
                        id: launchAnim
                        running: false
                        NumberAnimation {
                            target: iconItem
                            property: "scale"
                            to: iconHost.waveScale * 1.16
                            duration: 90
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: iconItem
                            property: "scale"
                            to: iconHost.waveScale
                            duration: 130
                            easing.type: Easing.OutCubic
                        }
                        onFinished: iconHost.launching = false
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onEntered: root.dockHovering = true
            onExited: {
                root.dockHovering = false
                root.hoverX = -1
            }
            onPositionChanged: {
                root.dockHovering = true
                root.hoverX = mouse.x
            }
        }
    }
}
