import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Janela popup à parte da doca (estilo macOS): cliques não passam pela máscara Wayland da superfície layer-shell.
Window {
    id: menuWin

    required property var dock

    property real ctxLogicalCenter: -1
    property string ctxCmd: ""
    property string ctxName: ""
    property string ctxIcon: ""
    property bool ctxIsLauncher: false
    property bool ctxIsSeparator: false
    property bool ctxIsSystem: false
    property bool ctxIsDynamic: false
    property bool ctxIsRunning: false
    property bool ctxIsFocused: false
    property int ctxWindowCount: 0
    property int ctxItemIndex: -1
    property var ctxDelegate: null
    property var ctxWindowList: []

    property Item _anchorItem: null

    readonly property bool ctxIsAppItem: !ctxIsLauncher && !ctxIsSystem && !ctxIsSeparator
    readonly property bool ctxHasWindows: ctxWindowList.length > 0

    // Tamanho vem da coluna — evita usar height antigo de um menu anterior (saltava para o topo).
    readonly property real menuPadW: 16
    readonly property real menuPadH: 12
    readonly property real menuGap: 10 * dock.liveScaleFactor

    width: Math.max(column.implicitWidth + menuPadW, 80)
    height: Math.max(column.implicitHeight + menuPadH, 40)
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    transientParent: dock

    function closeMenu() {
        menuWin.visible = false
    }

    function openForIcon(anchorItem, data) {
        _anchorItem = anchorItem
        ctxCmd = data.cmd || ""
        ctxName = data.name || ""
        ctxIcon = data.icon || ""
        ctxIsLauncher = data.isLauncher === true
        ctxIsSeparator = data.isSeparator === true
        ctxIsSystem = data.isSystem === true
        ctxIsDynamic = data.isDynamic === true
        ctxIsRunning = data.isRunning === true
        ctxIsFocused = data.isFocused === true
        ctxWindowCount = data.windowCount !== undefined ? data.windowCount : 0
        ctxItemIndex = data.itemIndex !== undefined ? data.itemIndex : -1
        ctxDelegate = data.delegate || null
        ctxLogicalCenter = data.logicalCenter !== undefined ? data.logicalCenter : -1

        if (ctxIsRunning && menuWin.ctxIsAppItem) {
            ctxWindowList = taskBackend.windowEntriesForCommand(ctxCmd)
            if (ctxWindowCount < ctxWindowList.length) {
                ctxWindowCount = ctxWindowList.length
            }
        } else {
            ctxWindowList = []
        }

        // Posiciona antes de mostrar para evitar “saltos”/frames
        // sem superfície com tamanho correto.
        repositionAboveIcon()
        menuWin.show()
        scheduleReposition()
    }

    function scheduleReposition() {
        Qt.callLater(repositionAboveIcon)
        repositionTimer.restart()
    }

    function repositionAboveIcon() {
        if (!_anchorItem) {
            return
        }
        var menuW = Math.max(column.implicitWidth + menuPadW, 80)
        var menuH = Math.max(column.implicitHeight + menuPadH, 40)
        // Centro inferior do ícone (não o topo da MouseArea expandida para cima).
        var g = _anchorItem.mapToGlobal(_anchorItem.width / 2, _anchorItem.height)
        var targetX = Math.round(g.x - menuW / 2)
        var targetY = Math.round(g.y - menuH - menuGap)

        var sc = menuWin.screen
        if (sc) {
            var minX = sc.virtualX + 4
            var maxX = sc.virtualX + sc.width - menuW - 4
            var minY = sc.virtualY + 4
            targetX = Math.max(minX, Math.min(targetX, maxX))
            targetY = Math.max(minY, targetY)
        }

        menuWin.x = targetX
        menuWin.y = targetY
    }

    Timer {
        id: repositionTimer
        interval: 16
        repeat: false
        onTriggered: menuWin.repositionAboveIcon()
    }

    onVisibleChanged: {
        if (visible) {
            dock.lockDockForContextMenu(true, ctxLogicalCenter)
            taskBackend.applyLayerShellKeyboardMode(2)
            scheduleReposition()
        } else {
            dock.lockDockForContextMenu(false)
            dock.applyLayerShellFromSettings()
            ctxDelegate = null
            ctxWindowList = []
            _anchorItem = null
        }
    }

    Connections {
        target: column
        function onImplicitHeightChanged() {
            if (menuWin.visible) {
                menuWin.repositionAboveIcon()
            }
        }
    }

    Connections {
        target: menuWin.dock
        function onActiveChanged() {
            if (!menuWin.dock.active) {
                menuWin.closeMenu()
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: menuWin.closeMenu()
    }

    Rectangle {
        id: menuBody
        anchors.fill: parent
        radius: 10 * menuWin.dock.liveScaleFactor
        color: Qt.rgba(0.10, 0.11, 0.13, 0.98)
        border.color: Qt.rgba(1, 1, 1, 0.14)
        border.width: 1
        clip: true

        Flickable {
            id: menuScroll
            anchors.fill: parent
            anchors.margins: 6
            contentWidth: column.width
            contentHeight: column.height
            boundsBehavior: Flickable.StopAtBounds
            interactive: column.height > menuBody.height - 12

            Column {
                id: column
                width: Math.round(228 * menuWin.dock.liveScaleFactor)
                spacing: 2

                ContextMenuRow {
                    label: qsTr("Nova janela")
                    labelColor: "#00E5FF"
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        if (menuWin.ctxDelegate && !menuWin.ctxDelegate.isLaunching) {
                            taskBackend.forceLaunchApp(menuWin.ctxCmd)
                        }
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: qsTr("Abrir")
                    rowVisible: menuWin.ctxIsAppItem && !menuWin.ctxIsRunning
                    onRowClicked: {
                        taskBackend.launchApp(menuWin.ctxCmd)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: menuWin.ctxIsFocused ? qsTr("Minimizar") : qsTr("Mostrar janela")
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                    onRowClicked: {
                        taskBackend.launchApp(menuWin.ctxCmd)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: qsTr("Próxima janela")
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxWindowCount > 1
                    onRowClicked: {
                        taskBackend.cycleAppWindows(menuWin.ctxCmd, true)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuSeparator {
                    sepVisible: menuWin.ctxHasWindows
                }

                Repeater {
                    model: menuWin.ctxWindowList
                    delegate: ContextMenuRow {
                        label: {
                            var t = modelData.title
                            if (t === undefined || t === "") {
                                return qsTr("Janela %1").arg(index + 1)
                            }
                            return t
                        }
                        labelColor: "#BBBBBB"
                        rowVisible: true
                        onRowClicked: {
                            var tok = modelData.token
                            if (tok !== undefined && tok !== "") {
                                taskBackend.focusWindowToken(tok)
                            }
                            menuWin.closeMenu()
                        }
                    }
                }

                ContextMenuSeparator {
                    sepVisible: menuWin.ctxIsAppItem
                }

                ContextMenuRow {
                    label: menuWin.ctxIsDynamic ? qsTr("Fixar na doca") : qsTr("Desafixar da doca")
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        if (menuWin.ctxIsDynamic) {
                            menuWin.dock.appModel.append({
                                name: menuWin.ctxName,
                                icon: menuWin.ctxIcon,
                                cmd: menuWin.ctxCmd
                            })
                            menuWin.dock.saveApps()
                        } else if (menuWin.ctxItemIndex >= 0) {
                            menuWin.dock.unpinApp(menuWin.ctxItemIndex)
                        }
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: qsTr("Ocultar da área dinâmica")
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        menuWin.dock.hideAppFromDynamicArea(menuWin.ctxCmd)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuSeparator {
                    sepVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                }

                ContextMenuRow {
                    label: qsTr("Fechar todas as janelas")
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxWindowCount > 1
                    onRowClicked: {
                        taskBackend.closeAllWindows(menuWin.ctxCmd, false)
                        if (menuWin.ctxDelegate) {
                            menuWin.ctxDelegate.isRunning = false
                            menuWin.ctxDelegate.isFocused = false
                        }
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: qsTr("Fechar janela")
                    labelColor: "#FF8888"
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                    onRowClicked: {
                        taskBackend.closeApp(menuWin.ctxCmd, false)
                        if (menuWin.ctxDelegate) {
                            menuWin.ctxDelegate.isRunning = false
                            menuWin.ctxDelegate.isFocused = false
                        }
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    label: qsTr("Forçar encerrar")
                    labelColor: "#FF5555"
                    labelBold: true
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                    onRowClicked: {
                        taskBackend.closeApp(menuWin.ctxCmd, true)
                        if (menuWin.ctxDelegate) {
                            menuWin.ctxDelegate.isRunning = false
                            menuWin.ctxDelegate.isFocused = false
                        }
                        menuWin.closeMenu()
                    }
                }

                // Itens de sistema (Transferências, Lixeira): menu curto.
                ContextMenuRow {
                    label: qsTr("Abrir")
                    rowVisible: menuWin.ctxIsSystem
                    onRowClicked: {
                        taskBackend.launchApp(menuWin.ctxCmd)
                        menuWin.closeMenu()
                    }
                }
            }
        }
    }

    component ContextMenuRow: Rectangle {
        id: rowRoot

        property string label: ""
        property color labelColor: "#EEEEEE"
        property bool labelBold: false
        property bool rowVisible: true

        signal rowClicked()

        width: Math.round(228 * menuWin.dock.liveScaleFactor)
        height: rowVisible ? Math.round(34 * menuWin.dock.liveScaleFactor) : 0
        visible: rowVisible
        radius: 6 * menuWin.dock.liveScaleFactor
        color: rowMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : "transparent"

        Text {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            text: rowRoot.label
            color: rowRoot.labelColor
            font.bold: rowRoot.labelBold
            font.pixelSize: 13 * menuWin.dock.liveScaleFactor
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: rowRoot.rowClicked()
        }
    }

    component ContextMenuSeparator: Rectangle {
        property bool sepVisible: true

        width: Math.round(228 * menuWin.dock.liveScaleFactor)
        height: sepVisible ? 9 : 0
        visible: sepVisible && height > 0
        color: "transparent"

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 20
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }
    }
}
