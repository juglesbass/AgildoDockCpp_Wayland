import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

// Menu flutuante em janela separada: cliques estáveis e estética moderna Latte/Breeze no Wayland.
Window {
    id: menuWin

    required property var dock

    property real ctxLogicalCenter: -1
    property string ctxCmd: ""
    property string ctxName: ""
    property string ctxIcon: ""
    property bool ctxIsSurfaceMenu: false
    property bool ctxIsLauncher: false
    property bool ctxIsSeparator: false
    property bool ctxIsSystem: false
    property real ctxSurfaceGlobalX: 0
    property real ctxSurfaceGlobalY: 0
    property bool ctxIsDynamic: false
    property bool ctxIsRunning: false
    property bool ctxIsFocused: false
    property int ctxItemIndex: -1
    property var ctxDelegate: null
    property var ctxCustomCommands: []
    property var ctxRecentItems: []

    readonly property int ctxRecentCount: {
        var n = 0
        for (var i = 0; i < ctxRecentItems.length; ++i) {
            var it = ctxRecentItems[i]
            if (!it) continue
            var u = String(it.url || "")
            var l = String(it.label || "").trim()
            if (u.length > 0 || l.length > 0) n++
        }
        return n
    }

    property Item _anchorItem: null

    readonly property bool ctxIsAppItem: !ctxIsSurfaceMenu && !ctxIsLauncher && !ctxIsSystem && !ctxIsSeparator

    readonly property real menuPadW: 10
    readonly property real menuPadH: 10
    readonly property real menuShadowPad: 16 * dock.liveScaleFactor
    readonly property real menuFloatGap: 12 * dock.liveScaleFactor
    readonly property real menuSideGap: 14 * dock.liveScaleFactor
    readonly property real rowHeight: Math.round(40 * dock.liveScaleFactor)
    readonly property real rowSpacing: 3

    readonly property int iconHeaderRows: ctxIsAppItem ? 1 : 0
    readonly property int iconVisibleRows: iconHeaderRows
                                     + (ctxIsAppItem ? 1 : 0) // Nova janela
                                     + ((ctxIsAppItem && ctxRecentCount > 0) ? 1 : 0) // Recentes
                                     + ((ctxIsAppItem && !ctxIsRunning) ? 1 : 0) // Abrir
                                     + ((ctxIsAppItem && ctxIsRunning) ? 1 : 0) // Minimizar/Restaurar
                                     + (ctxIsAppItem ? 1 : 0) // Fixar/Desafixar
                                     + ((ctxIsAppItem && ctxIsRunning) ? 1 : 0) // Fechar
                                     + (ctxIsAppItem ? 2 : 0) // Regras de clique
                                     + ((ctxIsAppItem && ctxCustomCommands.length > 0) ? 1 : 0)
                                     + ((ctxIsAppItem && ctxCustomCommands.length > 1) ? 1 : 0)
                                     + ((ctxIsSystem || ctxIsLauncher) ? 1 : 0)
                                     + (ctxIsAppItem ? 1 : 0) // Preferências da doca

    readonly property int surfaceVisibleRows: 7

    readonly property int visibleRows: ctxIsSurfaceMenu ? surfaceVisibleRows : iconVisibleRows

    readonly property real menuContentW: Math.round(270 * dock.liveScaleFactor)
    readonly property real menuContentH: Math.max(40, (menuPadH * 2)
                     + (visibleRows * rowHeight)
                     + (Math.max(0, visibleRows - 1) * rowSpacing))

    width: Math.round(menuContentW + (menuPadW * 2) + (menuShadowPad * 2))
    height: Math.round(menuContentH + (menuShadowPad * 2))
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    transientParent: dock

    function closeMenu() {
        recentSubmenuOpen = false
        recentSubmenuAllowed = false
        submenuHoverOpenTimer.stop()
        submenuCloseTimer.stop()
        menuOpenGraceTimer.stop()
        menuWin.visible = false
    }

    property bool recentSubmenuOpen: false
    property bool recentSubmenuAllowed: false
    property Item recentSubmenuAnchor: null
    property Item pendingSubmenuAnchor: null



    function openRecentSubmenu(anchorRow) {
        if (!recentSubmenuAllowed || !anchorRow || ctxRecentCount <= 0) {
            return
        }
        recentSubmenuAnchor = anchorRow
        recentSubmenuOpen = true
        submenuCloseTimer.stop()
        repositionRecentSubmenu()
    }

    function requestRecentSubmenu(anchorRow) {
        if (!recentSubmenuAllowed || !anchorRow || ctxRecentCount <= 0) {
            return
        }
        pendingSubmenuAnchor = anchorRow
        submenuHoverOpenTimer.restart()
    }

    function cancelRecentSubmenuHover() {
        submenuHoverOpenTimer.stop()
        pendingSubmenuAnchor = null
        scheduleRecentSubmenuClose()
    }

    function clampToScreen(sc, targetX, targetY, w, h) {
        if (!sc) return { x: targetX, y: targetY }
        var minX = sc.virtualX + 4
        var maxX = sc.virtualX + sc.width - w - 4
        var minY = sc.virtualY + 4
        var maxY = sc.virtualY + sc.height - h - 4
        return {
            x: Math.max(minX, Math.min(targetX, maxX)),
            y: Math.max(minY, Math.min(targetY, maxY))
        }
    }

    function repositionRecentSubmenu() {
        if (!recentSubmenuAnchor || !recentSubmenuOpen) {
            return
        }
        var subW = recentSubmenuWin.width
        var subH = recentSubmenuWin.height
        var gRow = recentSubmenuAnchor.mapToGlobal(0, 0)
        var gap = Math.round(6 * dock.liveScaleFactor)
        var targetX = Math.round(gRow.x + recentSubmenuAnchor.width + gap)
        var targetY = Math.round(gRow.y - menuShadowPad)

        var sc = recentSubmenuWin.screen || menuWin.screen
        if (sc && targetX + subW > sc.virtualX + sc.width - 4) {
            targetX = Math.round(menuWin.x - subW - gap)
        }
        var clamped = clampToScreen(sc, targetX, targetY, subW, subH)
        targetX = clamped.x
        targetY = clamped.y

        recentSubmenuWin.x = targetX
        recentSubmenuWin.y = targetY
    }

    function scheduleRecentSubmenuClose() {
        submenuCloseTimer.restart()
    }

    function cancelRecentSubmenuClose() {
        submenuCloseTimer.stop()
    }

    function openRecentItem(url) {
        const u = String(url || "")
        if (u.length > 0) {
            Qt.openUrlExternally(u)
        }
        closeMenu()
    }

    function openForSurface(anchorItem, globalX, globalY) {
        ctxIsSurfaceMenu = true
        _anchorItem = anchorItem
        ctxSurfaceGlobalX = globalX
        ctxSurfaceGlobalY = globalY
        ctxCmd = ""
        ctxName = ""
        ctxIcon = ""
        ctxIsLauncher = false
        ctxIsSeparator = false
        ctxIsSystem = false
        ctxIsDynamic = false
        ctxIsRunning = false
        ctxIsFocused = false
        ctxItemIndex = -1
        ctxDelegate = null
        ctxLogicalCenter = -1
        ctxCustomCommands = []
        ctxRecentItems = []

        repositionForSurface()
        menuWin.show()
        scheduleReposition()
    }

    function openForIcon(anchorItem, data) {
        if (!data) return
        ctxIsSurfaceMenu = false
        _anchorItem = anchorItem
        ctxCmd = String(data.cmd || "")
        ctxName = String(data.name || "")
        ctxIcon = String(data.icon || "")
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
        const rawRecent = taskBackend.recentItemsForCommand(ctxCmd, 5)
        const filteredRecent = []
        for (let i = 0; i < rawRecent.length; ++i) {
            const it = rawRecent[i]
            if (!it) continue
            const u = String(it.url || "")
            const l = String(it.label || "").trim()
            if (u.length === 0 && l.length === 0) continue
            filteredRecent.push(it)
        }
        ctxRecentItems = filteredRecent
        recentSubmenuOpen = false
        recentSubmenuAllowed = false
        recentSubmenuAnchor = null
        pendingSubmenuAnchor = null
        submenuHoverOpenTimer.stop()

        repositionAboveIcon()
        menuWin.show()
        scheduleReposition()
    }

    function scheduleReposition() {
        repositionTimer.restart()
    }

    function repositionForSurface() {
        var menuW = menuWin.width
        var menuH = menuWin.height
        var targetX = Math.round(ctxSurfaceGlobalX - menuW / 2)
        var targetY = Math.round(ctxSurfaceGlobalY - menuH / 2)
        if (_anchorItem) {
            var edge = menuWin.dock.liveDockEdge
            var localClick = _anchorItem.mapFromGlobal(ctxSurfaceGlobalX, ctxSurfaceGlobalY)
            if (edge === 2) {
                var gR = _anchorItem.mapToGlobal(_anchorItem.width, localClick.y)
                targetX = Math.round(gR.x + menuSideGap)
                targetY = Math.round(gR.y - menuH / 2)
            } else if (edge === 3) {
                var gL = _anchorItem.mapToGlobal(0, localClick.y)
                targetX = Math.round(gL.x - menuW - menuSideGap)
                targetY = Math.round(gL.y - menuH / 2)
            } else if (edge === 1) {
                var gB = _anchorItem.mapToGlobal(localClick.x, _anchorItem.height)
                targetX = Math.round(gB.x - menuW / 2)
                targetY = Math.round(gB.y + menuFloatGap)
            } else {
                var gT = _anchorItem.mapToGlobal(localClick.x, 0)
                targetX = Math.round(gT.x - menuW / 2)
                targetY = Math.round(gT.y - menuH - menuFloatGap)
            }
        }
        var clamped = clampToScreen(menuWin.screen, targetX, targetY, menuW, menuH)
        menuWin.x = clamped.x
        menuWin.y = clamped.y
    }

    function repositionAboveIcon() {
        if (!_anchorItem || ctxIsSurfaceMenu) {
            if (ctxIsSurfaceMenu) repositionForSurface()
            return
        }
        var menuW = menuWin.width
        var menuH = menuWin.height
        var localClick = _anchorItem.mapFromGlobal(ctxSurfaceGlobalX, ctxSurfaceGlobalY)
        var edge = menuWin.dock.liveDockEdge

        var targetX = 0
        var targetY = 0

        if (edge === 2) {
            var gR = _anchorItem.mapToGlobal(_anchorItem.width, _anchorItem.height / 2)
            targetX = Math.round(gR.x + menuSideGap)
            targetY = Math.round(gR.y - menuH / 2)
        } else if (edge === 3) {
            var gL = _anchorItem.mapToGlobal(0, _anchorItem.height / 2)
            targetX = Math.round(gL.x - menuW - menuSideGap)
            targetY = Math.round(gL.y - menuH / 2)
        } else if (edge === 1) {
            var gB = _anchorItem.mapToGlobal(_anchorItem.width / 2, _anchorItem.height)
            targetX = Math.round(gB.x - menuW / 2)
            targetY = Math.round(gB.y + menuFloatGap)
        } else {
            var gT = _anchorItem.mapToGlobal(_anchorItem.width / 2, 0)
            targetX = Math.round(gT.x - menuW / 2)
            targetY = Math.round(gT.y - menuH - menuFloatGap)
        }

        var clamped = clampToScreen(menuWin.screen, targetX, targetY, menuW, menuH)
        menuWin.x = clamped.x
        menuWin.y = clamped.y
    }

    Timer {
        id: repositionTimer
        interval: 16
        repeat: false
        onTriggered: menuWin.repositionAboveIcon()
    }

    onVisibleChanged: {
        if (visible) {
            recentSubmenuOpen = false
            recentSubmenuAllowed = false
            submenuHoverOpenTimer.stop()
            menuOpenGraceTimer.restart()
            dock.lockDockForContextMenu(true, ctxIsSurfaceMenu ? -1 : ctxLogicalCenter)
            taskBackend.applyLayerShellKeyboardMode(2)
            scheduleReposition()
        } else {
            dock.lockDockForContextMenu(false)
            dock.applyLayerShellFromSettings()
            recentSubmenuOpen = false
            recentSubmenuAllowed = false
            recentSubmenuAnchor = null
            pendingSubmenuAnchor = null
            submenuHoverOpenTimer.stop()
            menuOpenGraceTimer.stop()
            ctxDelegate = null
            _anchorItem = null
            ctxIsSurfaceMenu = false
        }
    }

    readonly property var desktopNameFilters: [
        qsTr("Atalhos de aplicação (*.desktop)"),
        qsTr("Todos os ficheiros (*)")
    ]



    Timer {
        id: menuOpenGraceTimer
        interval: 320
        repeat: false
        onTriggered: menuWin.recentSubmenuAllowed = true
    }

    Timer {
        id: submenuHoverOpenTimer
        interval: 140
        repeat: false
        onTriggered: {
            if (menuWin.pendingSubmenuAnchor) {
                menuWin.openRecentSubmenu(menuWin.pendingSubmenuAnchor)
            }
        }
    }

    Timer {
        id: submenuCloseTimer
        interval: 320
        repeat: false
        onTriggered: menuWin.recentSubmenuOpen = false
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

    Item {
        id: menuRoot
        anchors.fill: parent

        // Sombra de elevação elegante
        Rectangle {
            width: menuPanel.width
            height: menuPanel.height
            x: menuPanel.x
            y: menuPanel.y + Math.round(6 * menuWin.dock.liveScaleFactor)
            radius: menuPanel.radius
            color: Qt.rgba(0, 0, 0, 0.40)
            opacity: 0.70
            z: 0
        }

        // Painel Principal do Menu (Estilo Vidro/Latte)
        Rectangle {
            id: menuPanel
            x: menuWin.menuShadowPad
            y: menuWin.menuShadowPad
            width: Math.round(menuWin.menuContentW + (menuWin.menuPadW * 2))
            height: menuWin.menuContentH
            radius: 12 * menuWin.dock.liveScaleFactor
            color: menuWin.dock.themeMenuBg
            border.color: Qt.rgba(1, 1, 1, 0.18)
            border.width: 1
            clip: true
            z: 2

            scale: menuWin.visible ? 1.0 : 0.94
            opacity: menuWin.visible ? 1.0 : 0.0
            transformOrigin: menuWin.dock.liveDockEdge === 1 ? Item.Top
                             : menuWin.dock.liveDockEdge === 2 ? Item.Left
                             : menuWin.dock.liveDockEdge === 3 ? Item.Right
                             : Item.Bottom

            Behavior on scale {
                NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.06 }
            }
            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            Column {
                id: column
                width: menuWin.menuContentW
                x: menuWin.menuPadW
                y: menuWin.menuPadH
                spacing: menuWin.rowSpacing

                // Header com Nome da App
                Rectangle {
                    visible: menuWin.ctxIsAppItem
                    width: column.width
                    height: menuWin.ctxIsAppItem ? Math.round(32 * menuWin.dock.liveScaleFactor) : 0
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: menuWin.ctxName.length > 0 ? menuWin.ctxName : menuWin.ctxCmd
                            color: menuWin.dock.themeTextPrimary
                            font.pixelSize: 15 * menuWin.dock.liveScaleFactor
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Rectangle {
                            visible: menuWin.ctxIsRunning
                            radius: 4
                            color: menuWin.dock.accentFocus
                            implicitWidth: 58 * menuWin.dock.liveScaleFactor
                            implicitHeight: 20 * menuWin.dock.liveScaleFactor

                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Aberto")
                                color: "#FFFFFF"
                                font.pixelSize: 11 * menuWin.dock.liveScaleFactor
                                font.bold: true
                            }
                        }
                    }
                }

                ContextMenuSeparator {
                    rowVisible: menuWin.ctxIsAppItem
                }

                ContextMenuRow {
                    iconText: "✦"
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

                ContextMenuSubmenuRow {
                    id: recentMenuRow
                    label: qsTr("Ficheiros recentes")
                    rowVisible: menuWin.ctxIsAppItem && menuWin.ctxRecentCount > 0
                    subMenuOpen: menuWin.recentSubmenuOpen
                    onRowEntered: menuWin.requestRecentSubmenu(recentMenuRow)
                    onRowExited: menuWin.cancelRecentSubmenuHover()
                }

                ContextMenuRow {
                    iconText: "⚡"
                    label: {
                        const names = [qsTr("Padrão"), qsTr("Menu"), qsTr("Nova janela")]
                        const idx = menuWin.dock.effectiveLeftClickAction(menuWin.ctxCmd)
                        return qsTr("Clique esquerdo: %1").arg(names[idx] || names[0])
                    }
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        const cur = menuWin.dock.effectiveLeftClickAction(menuWin.ctxCmd)
                        menuWin.dock.setAppClickRule(menuWin.ctxCmd, "leftClickAction", (cur + 1) % 3)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: "⚙"
                    label: {
                        const names = [qsTr("Padrão"), qsTr("Fechar"), qsTr("Nova janela"), qsTr("Minimizar")]
                        const idx = menuWin.dock.effectiveMiddleClickAction(menuWin.ctxCmd)
                        return qsTr("Clique do meio: %1").arg(names[idx] || names[0])
                    }
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        const cur = menuWin.dock.effectiveMiddleClickAction(menuWin.ctxCmd)
                        menuWin.dock.setAppClickRule(menuWin.ctxCmd, "middleClickAction", (cur + 1) % 4)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: "▶"
                    label: qsTr("Abrir")
                    rowVisible: menuWin.ctxIsAppItem && !menuWin.ctxIsRunning
                    onRowClicked: {
                        taskBackend.launchApp(menuWin.ctxCmd)
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: menuWin.ctxIsFocused ? "🗕" : "🗖"
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
                    iconText: menuWin.ctxIsDynamic ? "📌" : "📍"
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
                    iconText: "✖"
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

                ContextMenuSeparator {
                    rowVisible: menuWin.ctxIsAppItem
                }

                ContextMenuRow {
                    iconText: "⚙"
                    label: qsTr("Preferências da doca…")
                    rowVisible: menuWin.ctxIsAppItem
                    onRowClicked: {
                        menuWin.dock.openSettingsGlobal()
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: "⚙"
                    label: qsTr("Preferências da doca…")
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.dock.openSettingsGlobal()
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: "➕"
                    label: qsTr("Adicionar aplicativo à doca…")
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.closeMenu()
                        menuWin.dock.openPinnedAppPicker()
                    }
                }

                ContextMenuRow {
                    iconText: "🧩"
                    label: qsTr("Adicionar atalho do sistema…")
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.closeMenu()
                        menuWin.dock.openSystemShortcutPicker()
                    }
                }

                ContextMenuRow {
                    iconText: "🔄"
                    label: qsTr("Atualizar lista de apps")
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.dock.updateDynamicApps()
                        menuWin.closeMenu()
                    }
                }

                ContextMenuRow {
                    iconText: menuWin.dock.visible ? "👁" : "🙈"
                    label: menuWin.dock.visible ? qsTr("Ocultar doca") : qsTr("Mostrar doca")
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.dock.toggleDockGlobal()
                        menuWin.closeMenu()
                    }
                }

                ContextMenuSeparator {
                    rowVisible: menuWin.ctxIsSurfaceMenu
                }

                ContextMenuRow {
                    iconText: "🚪"
                    label: qsTr("Sair da AgildoDock")
                    labelColor: "#FF5555"
                    labelBold: true
                    rowVisible: menuWin.ctxIsSurfaceMenu
                    onRowClicked: {
                        menuWin.closeMenu()
                        Qt.quit()
                    }
                }
            }
        }
    }

    // Submenu flutuante de recentes (estilo vidro)
    Window {
        id: recentSubmenuWin

        readonly property real subPadW: 10
        readonly property real subPadH: 10
        readonly property real subContentW: Math.round(260 * menuWin.dock.liveScaleFactor)
        readonly property real subContentH: Math.max(28, (subPadH * 2)
                         + (menuWin.ctxRecentCount * menuWin.rowHeight)
                         + (Math.max(0, menuWin.ctxRecentCount - 1) * menuWin.rowSpacing))

        width: Math.round(subContentW + (subPadW * 2) + (menuWin.menuShadowPad * 2))
        height: Math.round(subContentH + (menuWin.menuShadowPad * 2))
        visible: menuWin.recentSubmenuOpen
        flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
        color: "transparent"
        transientParent: menuWin

        onVisibleChanged: {
            if (visible) {
                menuWin.repositionRecentSubmenu()
            }
        }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) {
                    menuWin.cancelRecentSubmenuClose()
                } else {
                    menuWin.scheduleRecentSubmenuClose()
                }
            }
        }

        Item {
            anchors.fill: parent

            Rectangle {
                width: subPanel.width
                height: subPanel.height
                x: subPanel.x
                y: subPanel.y + Math.round(4 * menuWin.dock.liveScaleFactor)
                radius: subPanel.radius
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: 0.6
            }

            Rectangle {
                id: subPanel
                x: menuWin.menuShadowPad
                y: menuWin.menuShadowPad
                width: Math.round(recentSubmenuWin.subContentW + (recentSubmenuWin.subPadW * 2))
                height: recentSubmenuWin.subContentH
                radius: 12 * menuWin.dock.liveScaleFactor
                color: menuWin.dock.themeMenuBg
                border.color: Qt.rgba(1, 1, 1, 0.18)
                border.width: 1
                clip: true

                scale: menuWin.recentSubmenuOpen ? 1.0 : 0.96
                opacity: menuWin.recentSubmenuOpen ? 1.0 : 0.0
                transformOrigin: Item.Left

                Behavior on scale {
                    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }

                Column {
                    width: recentSubmenuWin.subContentW
                    anchors.centerIn: parent
                    spacing: menuWin.rowSpacing

                    Repeater {
                        model: menuWin.ctxRecentItems
                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: menuWin.rowHeight
                            radius: 6
                            color: itemMouse.containsMouse ? menuWin.dock.themeMenuHover : "transparent"

                            Behavior on color { ColorAnimation { duration: 100 } }

                            Text {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: Text.AlignVCenter
                                text: String(modelData.label || modelData.url || "")
                                color: menuWin.dock.themeTextPrimary
                                font.pixelSize: 14.5 * menuWin.dock.liveScaleFactor
                                elide: Text.ElideMiddle
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: menuWin.cancelRecentSubmenuClose()
                                onClicked: menuWin.openRecentItem(String(modelData.url || ""))
                            }
                        }
                    }
                }
            }
        }
    }

    component ContextMenuSubmenuRow: Rectangle {
        id: subRow
        required property string label
        property bool rowVisible: true
        property bool subMenuOpen: false
        signal rowEntered()
        signal rowExited()

        width: column.width
        height: rowVisible ? menuWin.rowHeight : 0
        visible: rowVisible
        opacity: rowVisible ? 1 : 0
        color: (subRowMouse.containsMouse || subMenuOpen) ? menuWin.dock.themeMenuHover : "transparent"
        radius: 6

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 10
            text: "📂 " + subRow.label
            color: menuWin.dock.themeTextPrimary
            font.pixelSize: 14.5 * menuWin.dock.liveScaleFactor
            elide: Text.ElideRight
            width: parent.width - 28
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 10
            text: "›"
            color: Qt.rgba(1, 1, 1, 0.5)
            font.pixelSize: 16 * menuWin.dock.liveScaleFactor
        }

        MouseArea {
            id: subRowMouse
            anchors.fill: parent
            enabled: subRow.rowVisible
            hoverEnabled: true
            onEntered: subRow.rowEntered()
            onExited: subRow.rowExited()
        }
    }

    component ContextMenuSeparator: Item {
        property bool rowVisible: true
        width: column.width
        height: rowVisible ? Math.round(8 * menuWin.dock.liveScaleFactor) : 0
        visible: rowVisible
        opacity: rowVisible ? 1 : 0

        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 12
            height: 1
            color: Qt.rgba(1, 1, 1, 0.14)
        }
    }

    component ContextMenuRow: Rectangle {
        id: row
        required property string label
        property string iconText: ""
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

        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
                visible: row.iconText.length > 0
                text: row.iconText
                color: row.labelColor
                font.pixelSize: 14 * menuWin.dock.liveScaleFactor
            }

            Text {
                id: rowLabel
                Layout.fillWidth: true
                text: row.label
                color: row.labelColor
                font.pixelSize: 14.5 * menuWin.dock.liveScaleFactor
                font.bold: row.labelBold
                elide: Text.ElideRight
            }
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
