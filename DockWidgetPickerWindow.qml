import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

Window {
    id: widgetPickerWin

    required property var dock

    property string searchText: ""
    property var allAppsList: []
    property string statusMessage: ""
    property int maxDisplayApps: 40

    width: 820
    height: 640
    minimumWidth: 680
    minimumHeight: 480
    visible: false
    title: qsTr("Adicionar Widgets & Atalhos — AgildoDock")

    readonly property bool isDark: dock.liveThemeMode === 0 || dock.liveThemeMode === 2 || dock.liveThemeMode === 3
    readonly property color uiBgColor: isDark ? "#1A1D24" : "#F0F2F5"
    readonly property color uiCardBg: isDark ? "#212631" : "#FFFFFF"
    readonly property color uiCardBorder: isDark ? "#2D3444" : "#D0D5DD"
    readonly property color uiTextPrimary: isDark ? "#F3F4F6" : "#111827"
    readonly property color uiTextSecondary: isDark ? "#9CA3AF" : "#4B5563"
    readonly property color uiAccent: "#3B82F6"

    Component.onCompleted: {
        Qt.callLater(function() {
            loadApps()
        })
    }

    function loadApps() {
        var rawApps = taskBackend.getAllInstalledApps()
        var list = []
        if (rawApps) {
            for (var i = 0; i < rawApps.length; i++) {
                if (rawApps[i]) list.push(rawApps[i])
            }
        }
        allAppsList = list
    }

    function openPicker() {
        if (!allAppsList || allAppsList.length === 0) {
            loadApps()
        }
        searchText = ""
        statusMessage = ""
        maxDisplayApps = 40
        widgetPickerWin.show()
        widgetPickerWin.raise()
        widgetPickerWin.requestActivate()
        Qt.callLater(function() {
            if (typeof searchInput !== "undefined" && searchInput) {
                searchInput.forceActiveFocus()
            }
        })
    }

    function closePicker() {
        widgetPickerWin.hide()
    }

    function handleToggleWidget(modelItem) {
        if (!dock || !modelItem) return
        const inDock = dock.isItemInDock(modelItem)
        if (inDock) {
            const removed = dock.removeAppOrWidget(modelItem)
            if (removed) {
                statusMessage = qsTr("✓ '%1' removido da doca!").arg(modelItem.name || "Item")
            }
        } else {
            const added = dock.addPlasmoidFromDropInfo(modelItem)
            if (added) {
                statusMessage = qsTr("✓ '%1' adicionado à doca!").arg(modelItem.name || "Item")
            }
        }
        statusTimer.restart()
    }

    Timer {
        id: statusTimer
        interval: 2500
        onTriggered: widgetPickerWin.statusMessage = ""
    }

    readonly property var presetWidgetsList: [
        {
            name: qsTr("Lixeira"),
            icon: "user-trash",
            desc: qsTr("Gerenciador de lixeira nativo com indicador de cheia/vazia e esvaziamento"),
            widgetPreset: "trash"
        },
        {
            name: qsTr("Relógio Digital"),
            icon: "preferences-system-time",
            desc: qsTr("Exibe a hora e data atual ao vivo com estética minimalista"),
            widgetPreset: "clock"
        },
        {
            name: qsTr("Controle de Volume"),
            icon: "audio-volume-high",
            desc: qsTr("Acesso rápido às configurações e controle de volume de áudio"),
            widgetPreset: "volume"
        },
        {
            name: qsTr("Player de Mídia"),
            icon: "media-playback-start",
            desc: qsTr("Controle de reprodução de música/vídeo (MPRIS2) com capa do álbum"),
            widgetPreset: "media"
        },
        {
            name: qsTr("Menu Iniciar (Kickoff)"),
            icon: "start-here-kde",
            desc: qsTr("Lançador de aplicativos e busca rápida do KDE Plasma"),
            isSystemItem: true,
            cmd: "krunner"
        },
        {
            name: qsTr("Monitor do Sistema"),
            icon: "utilities-system-monitor",
            desc: qsTr("Atalho para o monitor de recursos de hardware (CPU/RAM)"),
            cmd: "plasma-systemmonitor"
        },
        {
            name: qsTr("Separador de Ícones"),
            icon: "draw-separator",
            desc: qsTr("Divisor transparente para organizar seus aplicativos na doca"),
            cmd: "separator",
            isSeparator: true
        }
    ]

    Rectangle {
        id: bgPanel
        anchors.fill: parent
        color: widgetPickerWin.uiBgColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "🧩"
                    font.pixelSize: 26
                }

                ColumnLayout {
                    spacing: 3
                    Layout.fillWidth: true

                    Text {
                        text: qsTr("Adicionar Widgets & Atalhos à Doca")
                        color: widgetPickerWin.uiTextPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Escolha um widget ou aplicativo abaixo para adicionar ou remover da doca")
                        color: widgetPickerWin.uiTextSecondary
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: widgetPickerWin.statusMessage.length > 0 ? 32 : 0
                visible: widgetPickerWin.statusMessage.length > 0
                radius: 6
                color: widgetPickerWin.statusMessage.includes("removido") ? "#EF4444" : "#10B981"
                clip: true

                Behavior on height { NumberAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: widgetPickerWin.statusMessage
                    color: "#FFFFFF"
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 8
                color: widgetPickerWin.uiCardBg
                border.color: searchInput.activeFocus ? widgetPickerWin.uiAccent : widgetPickerWin.uiCardBorder
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    spacing: 10

                    Text {
                        text: "🔍"
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        text: widgetPickerWin.searchText
                        color: widgetPickerWin.uiTextPrimary
                        font.pixelSize: 13
                        onTextChanged: widgetPickerWin.searchText = text

                        Text {
                            text: qsTr("Pesquisar widgets ou aplicativos por nome...")
                            color: widgetPickerWin.uiTextSecondary
                            font.pixelSize: 13
                            visible: parent.text.length === 0
                        }
                    }

                    Text {
                        text: "✕"
                        color: widgetPickerWin.uiTextSecondary
                        font.pixelSize: 13
                        visible: searchInput.text.length > 0
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: searchInput.text = ""
                        }
                    }
                }
            }

            ScrollView {
                id: mainScrollView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                ColumnLayout {
                    width: mainScrollView.availableWidth
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: searchInput.text.length === 0

                        Text {
                            text: qsTr("WIDGETS RECOMENDADOS")
                            color: widgetPickerWin.uiAccent
                            font.pixelSize: 11
                            font.bold: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Repeater {
                                model: widgetPickerWin.presetWidgetsList

                                delegate: Rectangle {
                                    id: cardDelegate
                                    Layout.fillWidth: true
                                    height: 58
                                    radius: 8
                                    color: cardHover.containsMouse ? (widgetPickerWin.isDark ? "#2A303D" : "#E5E7EB") : widgetPickerWin.uiCardBg
                                    border.color: cardHover.containsMouse ? widgetPickerWin.uiAccent : widgetPickerWin.uiCardBorder
                                    border.width: 1

                                    readonly property bool itemInDock: dock ? dock.isItemInDock(modelData) : false

                                    MouseArea {
                                        id: cardHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: widgetPickerWin.handleToggleWidget(modelData)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 14
                                        anchors.rightMargin: 14
                                        spacing: 14

                                        Kirigami.Icon {
                                            source: modelData.icon
                                            Layout.preferredWidth: 32
                                            Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 150
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2
                                            clip: true

                                            Text {
                                                text: modelData.name
                                                color: widgetPickerWin.uiTextPrimary
                                                font.pixelSize: 13
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.desc
                                                color: widgetPickerWin.uiTextSecondary
                                                font.pixelSize: 11
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 105
                                            Layout.preferredHeight: 32
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 6
                                            color: cardDelegate.itemInDock 
                                                ? (addBtnMouse.containsMouse ? "#DC2626" : "#EF4444")
                                                : (addBtnMouse.containsMouse ? "#2563EB" : widgetPickerWin.uiAccent)

                                            Text {
                                                anchors.centerIn: parent
                                                text: cardDelegate.itemInDock ? qsTr("🗑️ Remover") : qsTr("+ Adicionar")
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: addBtnMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: widgetPickerWin.handleToggleWidget(modelData)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: searchInput.text.length > 0 ? qsTr("RESULTADOS DA BUSCA (%1)").arg(appRepeater.count) : qsTr("TODOS OS APLICATIVOS DO SISTEMA (%1)").arg(widgetPickerWin.allAppsList ? widgetPickerWin.allAppsList.length : 0)
                            color: widgetPickerWin.uiAccent
                            font.pixelSize: 11
                            font.bold: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            Repeater {
                                id: appRepeater
                                model: {
                                    const filter = (searchInput.text || "").toLowerCase().trim()
                                    if (!widgetPickerWin.allAppsList) return []
                                    if (filter.length === 0) {
                                        return widgetPickerWin.allAppsList.slice(0, widgetPickerWin.maxDisplayApps)
                                    }
                                    const res = []
                                    for (let i = 0; i < widgetPickerWin.allAppsList.length; i++) {
                                        const app = widgetPickerWin.allAppsList[i]
                                        if (!app) continue
                                        const name = (app.name || "").toLowerCase()
                                        const cmd = (app.cmd || "").toLowerCase()
                                        if (name.includes(filter) || cmd.includes(filter)) {
                                            res.push(app)
                                        }
                                    }
                                    return res
                                }

                                delegate: Rectangle {
                                    id: appRowDelegate
                                    Layout.fillWidth: true
                                    height: 48
                                    radius: 6
                                    color: appRowHover.containsMouse ? (widgetPickerWin.isDark ? "#2A303D" : "#E5E7EB") : widgetPickerWin.uiCardBg
                                    border.color: widgetPickerWin.uiCardBorder
                                    border.width: 1

                                    readonly property bool itemInDock: dock ? dock.isItemInDock(modelData) : false

                                    MouseArea {
                                        id: appRowHover
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: widgetPickerWin.handleToggleWidget(modelData)
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 12

                                        Kirigami.Icon {
                                            source: modelData.icon || "application-x-executable"
                                            Layout.preferredWidth: 28
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            Layout.minimumWidth: 150
                                            Layout.alignment: Qt.AlignVCenter
                                            spacing: 2
                                            clip: true

                                            Text {
                                                text: modelData.name || "App"
                                                color: widgetPickerWin.uiTextPrimary
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }

                                            Text {
                                                text: modelData.cmd || ""
                                                color: widgetPickerWin.uiTextSecondary
                                                font.pixelSize: 10
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 100
                                            Layout.preferredHeight: 28
                                            Layout.alignment: Qt.AlignVCenter
                                            radius: 6
                                            color: appRowDelegate.itemInDock
                                                ? (appAddMouse.containsMouse ? "#DC2626" : "#EF4444")
                                                : (appAddMouse.containsMouse ? "#2563EB" : widgetPickerWin.uiAccent)

                                            Text {
                                                anchors.centerIn: parent
                                                text: appRowDelegate.itemInDock ? qsTr("🗑️ Remover") : qsTr("+ Adicionar")
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }

                                            MouseArea {
                                                id: appAddMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: widgetPickerWin.handleToggleWidget(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 36
                                radius: 6
                                visible: searchInput.text.length === 0 && widgetPickerWin.allAppsList && widgetPickerWin.allAppsList.length > widgetPickerWin.maxDisplayApps
                                color: moreBtnMouse.containsMouse ? (widgetPickerWin.isDark ? "#2A303D" : "#E5E7EB") : widgetPickerWin.uiCardBg
                                border.color: widgetPickerWin.uiCardBorder
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: qsTr("Mostrar mais aplicativos (%1 restantes)...").arg((widgetPickerWin.allAppsList ? widgetPickerWin.allAppsList.length : 0) - widgetPickerWin.maxDisplayApps)
                                    color: widgetPickerWin.uiAccent
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    id: moreBtnMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: widgetPickerWin.maxDisplayApps += 40
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
