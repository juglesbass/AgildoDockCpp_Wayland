import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window

// Janela de configurações — referencia a janela principal da doca via `dock`.
Window {
    id: settingsWin

    required property var dock

    visible: false
    width: 410
    height: 920
    minimumWidth: 410
    maximumWidth: 410
    minimumHeight: 520
    maximumHeight: 1200
    title: qsTr("Configurações — AgildoDock")
    color: "#1A1A1A"
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    function carregarValores() {
        dock.liveScaleFactor = dock.appSettings.scaleFactor
        dock.liveIconSpacing = dock.appSettings.iconSpacing
        dock.liveDockMargin = dock.appSettings.dockMargin
        dock.liveBgOpacity = dock.appSettings.bgOpacity
        dock.liveMinIconSize = dock.appSettings.minIconSize
        dock.liveMaxIconSize = Math.max(dock.appSettings.minIconSize, dock.appSettings.maxIconSize)

        dock.liveBehaviorAutoHide = dock.appSettings.behaviorAutoHide
        dock.liveBehaviorDodgeWindows = dock.appSettings.behaviorDodgeWindows
        dock.liveBehaviorKeepAppsFocused = dock.appSettings.behaviorKeepAppsFocused
        dock.liveBehaviorAutoHideDelayMs = dock.appSettings.behaviorAutoHideDelayMs

        dock.liveThemeMode = dock.appSettings.themeMode
        dock.liveDockPosition = dock.appSettings.dockPosition
        dock.liveMiddleClickCloses = dock.appSettings.middleClickCloses
        dock.liveShowWindowBadge = dock.appSettings.showWindowBadge
        dock.liveLauncherTitle = dock.appSettings.launcherTitle
        dock.liveLauncherIcon = dock.appSettings.launcherIcon
        dock.liveLauncherCommand = dock.appSettings.launcherCommand
    }

    function cancelarValores() {
        carregarValores()
        settingsWin.close()
    }

    function aplicarValores() {
        var minSz = dock.liveMinIconSize
        var maxSz = Math.max(minSz, dock.liveMaxIconSize)
        dock.liveMaxIconSize = maxSz

        dock.appSettings.scaleFactor = dock.liveScaleFactor
        dock.appSettings.iconSpacing = dock.liveIconSpacing
        dock.appSettings.dockMargin = dock.liveDockMargin
        dock.appSettings.bgOpacity = dock.liveBgOpacity
        dock.appSettings.minIconSize = minSz
        dock.appSettings.maxIconSize = maxSz

        dock.appSettings.behaviorAutoHide = dock.liveBehaviorAutoHide
        dock.appSettings.behaviorDodgeWindows = dock.liveBehaviorDodgeWindows
        dock.appSettings.behaviorKeepAppsFocused = dock.liveBehaviorKeepAppsFocused
        dock.appSettings.behaviorAutoHideDelayMs = dock.liveBehaviorAutoHideDelayMs

        dock.appSettings.themeMode = dock.liveThemeMode
        dock.appSettings.dockPosition = dock.liveDockPosition
        dock.appSettings.middleClickCloses = dock.liveMiddleClickCloses
        dock.appSettings.showWindowBadge = dock.liveShowWindowBadge
        dock.appSettings.launcherTitle = dock.liveLauncherTitle
        dock.appSettings.launcherIcon = dock.liveLauncherIcon
        dock.appSettings.launcherCommand = dock.liveLauncherCommand

        if (typeof dock.appSettings.sync === "function") {
            dock.appSettings.sync()
        }
        dock.loadLauncherFromSettings()
        dock.saveApps()
        dock.saveSystemItems()
        dock.updateZone()
        dock.applyLayerShellFromSettings()
        dock.applyDockPositionFromSettings()
        dock.applyDockRetractedState()
        settingsWin.close()
    }

    onVisibleChanged: {
        if (visible) {
            carregarValores()
            var g = null
            if (dock && dock.screen)
                g = dock.screen.geometry
            if (g) {
                settingsWin.x = Math.round(g.x + (g.width - settingsWin.width) / 2)
                settingsWin.y = Math.round(g.y + (g.height - settingsWin.height) / 2)
            } else {
                settingsWin.x = Math.round((Screen.width - settingsWin.width) / 2)
                settingsWin.y = Math.round((Screen.height - settingsWin.height) / 2)
            }
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 12
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: settingsWin.width - 40
            spacing: 12

        Accessible.role: Accessible.Dialog
        Accessible.name: settingsWin.title

        Label {
            visible: !taskBackend.windowManagementAvailable
            text: qsTr("Gestão de janelas de outras aplicações indisponível: instala «kdotool» (recomendado no Plasma/Wayland) ou corre a própria AgildoDock numa sessão Qt X11 com KWinStack ativo.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: 12
            color: "#FFB090"
        }

        Label {
            text: qsTr("Ajustes da doca")
            font.bold: true
            font.family: "Noto Sans"
            font.pixelSize: 18
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
            Layout.bottomMargin: 8
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Escala geral: %1%").arg(Math.round(dock.liveScaleFactor * 100))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 0.5
                to: 1.8
                stepSize: 0.05
                value: dock.liveScaleFactor
                onMoved: {
                    dock.liveScaleFactor = value
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Espaçamento dos ícones: %1 px").arg(Math.round(dock.liveIconSpacing))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 0
                to: 40
                stepSize: 1
                value: dock.liveIconSpacing
                onMoved: {
                    dock.liveIconSpacing = value
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Distância ao rodapé: %1 px").arg(Math.round(dock.liveDockMargin))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 0
                to: 50
                stepSize: 1
                value: dock.liveDockMargin
                onMoved: {
                    dock.liveDockMargin = value
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Opacidade do fundo: %1%").arg(Math.round(dock.liveBgOpacity * 100))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 0.2
                to: 1.0
                stepSize: 0.05
                value: dock.liveBgOpacity
                onMoved: {
                    dock.liveBgOpacity = value
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: qsTr("Comportamento")
            font.bold: true
            font.family: "Noto Sans"
            font.pixelSize: 16
            color: "#FFFFFF"
        }

        CheckBox {
            text: qsTr("Ocultar automaticamente (após sair da doca)")
            checked: dock.liveBehaviorAutoHide
            onToggled: dock.liveBehaviorAutoHide = checked
            palette.text: "#DDDDDD"
            Layout.fillWidth: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: dock.liveBehaviorAutoHide
            Label {
                text: qsTr("Atraso para ocultar: %1 ms").arg(dock.liveBehaviorAutoHideDelayMs)
                color: "#AAAAAA"
                font.pixelSize: 12
            }
            Slider {
                Layout.fillWidth: true
                from: 300
                to: 4000
                stepSize: 50
                value: dock.liveBehaviorAutoHideDelayMs
                onMoved: dock.liveBehaviorAutoHideDelayMs = Math.round(value)
            }
        }

        CheckBox {
            text: qsTr("Desviar quando a janela ativa cobre quase o ecrã inteiro")
            checked: dock.liveBehaviorDodgeWindows
            onToggled: dock.liveBehaviorDodgeWindows = checked
            palette.text: "#DDDDDD"
            Layout.fillWidth: true
        }

        Label {
            visible: dock.liveBehaviorDodgeWindows
            text: qsTr("Usa o tamanho da janela ativa (heurística): «kdotool» no Plasma/Wayland ou só KWinStack quando a própria doca está numa sessão Qt X11.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: 11
            color: "#888888"
        }

        CheckBox {
            text: qsTr("Prioridade de teclado nas outras janelas (a doca não rouba o foco)")
            checked: dock.liveBehaviorKeepAppsFocused
            onToggled: dock.liveBehaviorKeepAppsFocused = checked
            palette.text: "#DDDDDD"
            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Efeito de onda")
            font.bold: true
            font.family: "Noto Sans"
            font.pixelSize: 16
            color: "#FFFFFF"
        }

        Label {
            text: qsTr("Para alvos de toque confortáveis, use pelo menos ~44 px de tamanho base (Material HIG).")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: 11
            color: "#888888"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Tamanho base do ícone: %1 px").arg(Math.round(dock.liveMinIconSize))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 30
                to: 80
                stepSize: 1
                value: dock.liveMinIconSize
                onMoved: {
                    dock.liveMinIconSize = value
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Label {
                text: qsTr("Tamanho máximo (zoom): %1 px").arg(Math.round(dock.liveMaxIconSize))
                color: "#CCCCCC"
            }
            Slider {
                Layout.fillWidth: true
                from: 30
                to: 140
                stepSize: 1
                value: dock.liveMaxIconSize
                onMoved: {
                    dock.liveMaxIconSize = value
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: qsTr("Aparência e atalhos")
            font.bold: true
            font.pixelSize: 16
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        Label {
            text: qsTr("Tema da barra")
            color: "#CCCCCC"
        }
        ComboBox {
            Layout.fillWidth: true
            model: [qsTr("Escuro"), qsTr("Claro"), qsTr("Seguir o sistema")]
            currentIndex: dock.liveThemeMode
            onActivated: dock.liveThemeMode = currentIndex
        }

        Label {
            text: qsTr("Posição (âncora Layer Shell)")
            color: "#CCCCCC"
        }
        ComboBox {
            Layout.fillWidth: true
            model: [qsTr("Inferior"), qsTr("Esquerda"), qsTr("Direita"), qsTr("Superior")]
            currentIndex: dock.liveDockPosition
            onActivated: dock.liveDockPosition = currentIndex
        }
        Label {
            text: qsTr("A disposição dos ícones continua optimizada para a margem inferior; outras posições podem exigir ajustes visuais.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            font.pixelSize: 11
            color: "#888888"
        }

        CheckBox {
            text: qsTr("Clique do meio fecha o programa")
            checked: dock.liveMiddleClickCloses
            onToggled: dock.liveMiddleClickCloses = checked
            palette.text: "#DDDDDD"
            Layout.fillWidth: true
        }

        CheckBox {
            text: qsTr("Mostrar contador de janelas nos ícones")
            checked: dock.liveShowWindowBadge
            onToggled: dock.liveShowWindowBadge = checked
            palette.text: "#DDDDDD"
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: qsTr("Lançador (menu Plasma)")
            font.bold: true
            font.pixelSize: 16
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Título")
            text: dock.liveLauncherTitle
            onTextEdited: dock.liveLauncherTitle = text
            color: "#EEEEEE"
        }
        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Ícone (nome do tema)")
            text: dock.liveLauncherIcon
            onTextEdited: dock.liveLauncherIcon = text
            color: "#EEEEEE"
        }
        TextField {
            Layout.fillWidth: true
            placeholderText: qsTr("Comando")
            text: dock.liveLauncherCommand
            onTextEdited: dock.liveLauncherCommand = text
            color: "#EEEEEE"
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#33FFFFFF"
            Layout.topMargin: 8
            Layout.bottomMargin: 8
        }

        Label {
            text: qsTr("Aplicações fixadas")
            font.bold: true
            font.pixelSize: 16
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        ListView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(180, Math.max(48, count * 52))
            clip: true
            model: dock.appModel
            delegate: RowLayout {
                width: ListView.view.width
                spacing: 6
                TextField {
                    Layout.fillWidth: true
                    text: model.name
                    onTextEdited: dock.appModel.setProperty(index, "name", text)
                    color: "#EEEEEE"
                }
                TextField {
                    Layout.fillWidth: true
                    text: model.cmd
                    onTextEdited: dock.appModel.setProperty(index, "cmd", text)
                    color: "#AAAAFF"
                    font.pixelSize: 11
                }
                Button {
                    text: "×"
                    onClicked: dock.unpinApp(index)
                }
            }
        }

        Button {
            text: qsTr("Adicionar linha vazia (editar depois)")
            Layout.fillWidth: true
            onClicked: dock.appModel.append({ name: qsTr("Nova app"), icon: "application-x-executable", cmd: "konsole" })
        }

        Label {
            text: qsTr("Itens de sistema (Transferências, Lixeira, …)")
            font.bold: true
            font.pixelSize: 16
            color: "#FFFFFF"
            Layout.fillWidth: true
        }

        ListView {
            id: systemItemsEditor
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(140, Math.max(48, count * 52))
            clip: true
            model: dock.systemModel
            delegate: RowLayout {
                width: systemItemsEditor.width
                spacing: 6
                TextField {
                    Layout.fillWidth: true
                    text: model.name
                    onTextEdited: dock.systemModel.setProperty(index, "name", text)
                    color: "#EEEEEE"
                }
                TextField {
                    Layout.fillWidth: true
                    text: model.cmd
                    onTextEdited: dock.systemModel.setProperty(index, "cmd", text)
                    color: "#AAAAFF"
                    font.pixelSize: 11
                }
                Button {
                    text: "×"
                    onClicked: dock.systemModel.remove(index)
                }
            }
        }

        Button {
            text: qsTr("Adicionar item de sistema")
            Layout.fillWidth: true
            onClicked: dock.systemModel.append({
                name: qsTr("Pasta"),
                icon: "folder",
                cmd: "dolphin",
                isSystem: true
            })
        }

        Item {
            Layout.fillHeight: true
            Layout.minimumHeight: 12
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: qsTr("Encerrar doca")
                icon.name: "application-exit"
                onClicked: {
                    Qt.quit()
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Cancelar")
                onClicked: {
                    settingsWin.cancelarValores()
                }
            }

            Button {
                text: qsTr("Guardar")
                highlighted: true
                onClicked: {
                    settingsWin.aplicarValores()
                }
            }
        }
        }
    }
}
