import QtQuick
import QtQuick.Controls
import QtQuick.Window

// Menu flutuante em janela separada: cliques estáveis no Wayland (layer-shell da doca).
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
    property int ctxItemIndex: -1
    property var ctxDelegate: null
    property var ctxCustomCommands: []

    property Item _anchorItem: null

    readonly property bool ctxIsAppItem: !ctxIsLauncher && !ctxIsSystem && !ctxIsSeparator

    readonly property real menuPadW: 12
    readonly property real menuPadH: 12
    readonly property real menuGap: 18 * dock.liveScaleFactor
    readonly property real rowHeight: Math.round(34 * dock.liveScaleFactor)
    readonly property real rowSpacing: 2

    readonly property int visibleRows: (ctxIsAppItem ? 1 : 0) // Nova janela
                                     + ((ctxIsAppItem && !ctxIsRunning) ? 1 : 0) // Abrir
                                     + ((ctxIsAppItem && ctxIsRunning) ? 1 : 0) // Minimizar/Restaurar
                                     + (ctxIsAppItem ? 1 : 0) // Fixar/Desafixar
                                     + ((ctxIsAppItem && ctxIsRunning) ? 1 : 0) // Fechar
                                     + ((ctxIsAppItem && ctxCustomCommands.length > 0) ? 1 : 0) // Comando custom 1
                                     + ((ctxIsAppItem && ctxCustomCommands.length > 1) ? 1 : 0) // Comando custom 2
                                     + ((ctxIsSystem || ctxIsLauncher) ? 1 : 0) // Abrir (sistema/launcher)

    // Tamanho determinístico: evita loops de implicitHeight/polish em algumas versões de Qt.
    width: Math.round(228 * dock.liveScaleFactor) + (menuPadW * 2)
    height: Math.max(40, (menuPadH * 2)
                     + (visibleRows * rowHeight)
                     + (Math.max(0, visibleRows - 1) * rowSpacing))
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
        ctxItemIndex = data.itemIndex !== undefined ? data.itemIndex : -1
        ctxDelegate = data.delegate || null
        ctxLogicalCenter = data.logicalCenter !== undefined ? data.logicalCenter : -1
        ctxCustomCommands = dock.customCommandsFor(ctxCmd)

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
        // Usa tamanho já calculado da janela; evita ler implicitHeight durante polish().
        var menuW = menuWin.width
        var menuH = menuWin.height
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
            _anchorItem = null
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
        color: menuWin.dock.themeMenuBg
        border.color: menuWin.dock.themeMenuBorder
        border.width: 1
        clip: true

        Column {
            id: column
            width: Math.round(228 * menuWin.dock.liveScaleFactor)
            x: menuWin.menuPadW
            y: menuWin.menuPadH
            spacing: menuWin.rowSpacing

            ContextMenuRow {
                label: qsTr("Nova janela")
                labelColor: menuWin.dock.accentIdle
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
                label: menuWin.ctxIsFocused ? qsTr("Minimizar") : qsTr("Restaurar")
                rowVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                onRowClicked: {
                    if (menuWin.ctxIsFocused && menuWin._anchorItem) {
                        menuWin.dock.playMinimizeSuckAt(menuWin._anchorItem)
                    }
                    if (menuWin.ctxDelegate) {
                        menuWin.ctxDelegate.playFocusBounce()
                    }
                    taskBackend.launchApp(menuWin.ctxCmd)
                    menuWin.closeMenu()
                }
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
                label: qsTr("Fechar programa")
                labelColor: "#FF5555"
                labelBold: true
                rowVisible: menuWin.ctxIsAppItem && menuWin.ctxIsRunning
                onRowClicked: {
                    taskBackend.closeApp(menuWin.ctxCmd)
                    if (menuWin.ctxDelegate) {
                        menuWin.ctxDelegate.isRunning = false
                        menuWin.ctxDelegate.isFocused = false
                    }
                    menuWin.closeMenu()
                }
            }

            ContextMenuRow {
                label: menuWin.ctxCustomCommands.length > 0 ? String(menuWin.ctxCustomCommands[0].label || qsTr("Comando custom")) : ""
                labelColor: menuWin.dock.accentIdle
                rowVisible: menuWin.ctxIsAppItem && menuWin.ctxCustomCommands.length > 0
                onRowClicked: {
                    const customCmd = String(menuWin.ctxCustomCommands[0].command || "")
                    if (customCmd.length > 0) {
                        taskBackend.forceLaunchApp(customCmd)
                    }
                    menuWin.closeMenu()
                }
            }

            ContextMenuRow {
                label: menuWin.ctxCustomCommands.length > 1 ? String(menuWin.ctxCustomCommands[1].label || qsTr("Comando custom")) : ""
                labelColor: menuWin.dock.accentFocus
                rowVisible: menuWin.ctxIsAppItem && menuWin.ctxCustomCommands.length > 1
                onRowClicked: {
                    const customCmd = String(menuWin.ctxCustomCommands[1].command || "")
                    if (customCmd.length > 0) {
                        taskBackend.forceLaunchApp(customCmd)
                    }
                    menuWin.closeMenu()
                }
            }

            ContextMenuRow {
                label: qsTr("Abrir")
                rowVisible: menuWin.ctxIsSystem || menuWin.ctxIsLauncher
                onRowClicked: {
                    taskBackend.launchApp(menuWin.ctxCmd)
                    menuWin.closeMenu()
                }
            }
        }
    }

    component ContextMenuRow: Rectangle {
        id: row
        required property string label
        property color labelColor: menuWin.dock.themeTextPrimary
        property bool labelBold: false
        property bool rowVisible: true
        signal rowClicked()

        width: column.width
        height: rowVisible ? menuWin.rowHeight : 0
        visible: rowVisible
        opacity: rowVisible ? 1 : 0
        color: rowMouse.containsMouse ? menuWin.dock.themeMenuHover : "transparent"
        radius: 6

        Text {
            id: rowLabel
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            text: row.label
            color: row.labelColor
            font.pixelSize: 14 * menuWin.dock.liveScaleFactor
            font.bold: row.labelBold
            elide: Text.ElideRight
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            enabled: row.rowVisible
            hoverEnabled: true
            onClicked: row.rowClicked()
        }
    }
}
