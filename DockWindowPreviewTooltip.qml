import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.pipewire as PipeWire

Item {
    id: previewRoot

    required property var dock
    property var windowData: null

    function parseWId(id) {
        if (!id) return 0;
        if (typeof id === "number") return Math.floor(id);
        let idStr = String(id).trim();
        if (idStr.length === 0) return 0;

        if (idStr.startsWith("x11:")) {
            let pHex = parseInt(idStr.substring(4), 16);
            return isNaN(pHex) ? 0 : pHex;
        }
        if (idStr.startsWith("0x") || idStr.startsWith("0X")) {
            let pHex = parseInt(idStr, 16);
            return isNaN(pHex) ? 0 : pHex;
        }
        if (/[a-fA-F]/.test(idStr)) {
            let pHex = parseInt(idStr, 16);
            return isNaN(pHex) ? 0 : pHex;
        }
        let decVal = parseInt(idStr, 10);
        return isNaN(decVal) ? 0 : decVal;
    }

    readonly property bool liveAvailable: (liveWindowImg.status === Image.Ready && liveWindowImg.progress === 1.0) || windowThumb.visible || (pipeWireItem && pipeWireItem.visible)

    implicitWidth: Math.round(240 * dock.liveScaleFactor)
    implicitHeight: Math.round(140 * dock.liveScaleFactor)

    Rectangle {
        id: cardBg
        anchors.fill: parent
        radius: Math.round(12 * dock.liveScaleFactor)
        color: Qt.rgba(0.08, 0.11, 0.16, 0.95)
        border.color: dock.accentFocus ? dock.accentFocus : Qt.rgba(0.4, 0.65, 1.0, 0.45)
        border.width: 1
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Math.round(8 * dock.liveScaleFactor)
            spacing: 6

            // Barra de título da pré-visualização (Estilo macOS / Windows)
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Kirigami.Icon {
                    source: (windowData && windowData.icon) ? windowData.icon : "window"
                    implicitWidth: Math.round(16 * dock.liveScaleFactor)
                    implicitHeight: Math.round(16 * dock.liveScaleFactor)
                }

                Text {
                    Layout.fillWidth: true
                    text: (windowData && windowData.title) ? windowData.title : qsTr("Janela Ativa")
                    color: "#F3F4F6"
                    font.pixelSize: Math.round(11 * dock.liveScaleFactor)
                    font.bold: true
                    elide: Text.ElideRight
                }

                // Botão de Fechar Janela ✕
                Rectangle {
                    implicitWidth: Math.round(18 * dock.liveScaleFactor)
                    implicitHeight: Math.round(18 * dock.liveScaleFactor)
                    radius: width / 2
                    color: closeBtnMouse.containsMouse ? "#EF4444" : Qt.rgba(1, 1, 1, 0.12)

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#FFFFFF"
                        font.pixelSize: Math.round(9 * dock.liveScaleFactor)
                        font.bold: true
                    }

                    MouseArea {
                        id: closeBtnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (windowData && windowData.cmd && taskBackend) {
                                taskBackend.closeApp(windowData.cmd)
                            }
                            dock.hideDockIconTip()
                        }
                    }
                }
            }

            // Quadro central: Live Window Preview Thumbnail em tempo real
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.round(8 * dock.liveScaleFactor)
                color: Qt.rgba(0.04, 0.06, 0.10, 0.8)
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1
                clip: true

                // Captura NATIVA da Janela em Tempo Real (C++ QQuickImageProvider)
                Image {
                    id: liveWindowImg
                    anchors.fill: parent
                    anchors.margins: 2
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                    source: (windowData && windowData.winId) ? ("image://windowpreview/" + windowData.winId) : ""
                    visible: status === Image.Ready && progress === 1.0
                }

                // Thumbnail nativo do KDE Plasma Core / KWin (fallback)
                PlasmaCore.WindowThumbnail {
                    id: windowThumb
                    anchors.fill: parent
                    anchors.margins: 2
                    winId: windowData && windowData.winId ? previewRoot.parseWId(windowData.winId) : 0
                    visible: !liveWindowImg.visible && thumbnailAvailable && winId > 0
                }

                // Stream PipeWire (Fallback)
                PipeWire.PipeWireSourceItem {
                    id: pipeWireItem
                    anchors.fill: parent
                    visible: !liveWindowImg.visible && !windowThumb.visible && windowData && windowData.nodeId !== undefined && windowData.nodeId > 0
                    nodeId: windowData ? (windowData.nodeId || 0) : 0
                }

                // Cartão Elegante de Janela (quando thumbnail live do compositor ainda não está pronto ou janela minimizada)
                Rectangle {
                    anchors.fill: parent
                    visible: !previewRoot.liveAvailable
                    color: "transparent"

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Qt.rgba(0.12, 0.18, 0.28, 0.6) }
                            GradientStop { position: 1.0; color: Qt.rgba(0.05, 0.08, 0.14, 0.9) }
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: Math.round(42 * dock.liveScaleFactor)
                            implicitHeight: Math.round(42 * dock.liveScaleFactor)
                            radius: Math.round(10 * dock.liveScaleFactor)
                            color: Qt.rgba(1, 1, 1, 0.08)
                            border.color: dock.accentFocus ? dock.accentFocus : Qt.rgba(0.4, 0.65, 1.0, 0.4)
                            border.width: 1

                            Kirigami.Icon {
                                anchors.centerIn: parent
                                source: (windowData && windowData.icon) ? windowData.icon : "preferences-system-windows"
                                implicitWidth: Math.round(28 * dock.liveScaleFactor)
                                implicitHeight: Math.round(28 * dock.liveScaleFactor)
                            }
                        }

                        Rectangle {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: statusText.implicitWidth + 16
                            implicitHeight: Math.round(20 * dock.liveScaleFactor)
                            radius: height / 2
                            color: (windowData && windowData.isFocused) ? Qt.rgba(0.0, 0.9, 0.6, 0.2) : Qt.rgba(1, 1, 1, 0.1)
                            border.color: (windowData && windowData.isFocused) ? "#00E5FF" : Qt.rgba(1, 1, 1, 0.2)
                            border.width: 1

                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: (windowData && windowData.isFocused) ? qsTr("● Janela em Foco") : (windowData && windowData.isMinimized ? qsTr("🗕 Janela Minimizada") : qsTr("Clique para Alternar"))
                                color: (windowData && windowData.isFocused) ? "#00E5FF" : "#E5E7EB"
                                font.pixelSize: Math.round(10 * dock.liveScaleFactor)
                                font.bold: true
                            }
                        }
                    }
                }

                // Clique na área central ativa/alterna a janela
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (windowData && windowData.cmd && taskBackend) {
                            taskBackend.launchApp(windowData.cmd)
                        }
                        dock.hideDockIconTip()
                    }
                }
            }
        }
    }
}
