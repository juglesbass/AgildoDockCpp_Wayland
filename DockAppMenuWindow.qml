import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import org.kde.kirigami as Kirigami

// Menu de Aplicativos Estilo macOS: Restaurado exatamente ao comportamento original amado pelo utilizador + Blur KWin.
Window {
    id: appMenuWin

    required property var dock

    property Item anchorItem: null
    property real anchorGlobalX: 0
    property real anchorGlobalY: 0
    property string searchText: ""
    property string selectedCategory: "all"
    property var allAppsList: []
    property bool menuOpen: false

    // Tamanho padrão base (em pixels)
    readonly property real defaultMenuWidth: 800 * dock.liveScaleFactor
    readonly property real defaultMenuHeight: 560 * dock.liveScaleFactor

    // Tamanho customizado pelo utilizador
    property real userMenuWidth: defaultMenuWidth
    property real userMenuHeight: defaultMenuHeight

    readonly property real menuPad: 20 * dock.liveScaleFactor
    readonly property real menuShadowPad: 24 * dock.liveScaleFactor
    
    title: "AgildoDock App Menu"
    objectName: "agildodock-appmenu"
    width: Math.round(userMenuWidth + (menuShadowPad * 2))
    height: Math.round(userMenuHeight + (menuShadowPad * 2))
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    transientParent: dock

    // Gerenciamento de Aplicativos Ocultos
    property var hiddenAppsMap: ({})
    property int hiddenAppsCount: 0

    Component.onCompleted: {
        taskBackend.initLayerShellPopup(appMenuWin, "agildodock-appmenu")
        loadUserSize()
        loadHiddenApps()
        Qt.callLater(function() {
            if (allAppsList.length === 0) {
                allAppsList = taskBackend.getAllInstalledApps()
            }
        })

        // Recarrega quando algo e' instalado ou removido enquanto a doca corre.
        // Sem isto, as duas chamadas a getAllInstalledApps() estavam guardadas
        // por "length === 0" e so' perguntavam UMA vez: um programa instalado
        // depois so' aparecia ao reiniciar o processo.
        taskBackend.installedAppsChanged.connect(function() {
            allAppsList = taskBackend.getAllInstalledApps()
        })
    }

    function getAppKey(app) {
        if (!app) return ""
        var cmd = String(app.cmd || "").trim().toLowerCase()
        var name = String(app.name || "").trim().toLowerCase()
        if (cmd.length > 0) return cmd
        return name
    }

    function loadHiddenApps() {
        try {
            var raw = taskBackend.readUserJsonFile("dock_hidden_apps.json")
            if (raw && raw.trim().length > 0) {
                var arr = JSON.parse(raw)
                if (Array.isArray(arr)) {
                    var map = {}
                    var count = 0
                    for (var i = 0; i < arr.length; i++) {
                        if (arr[i]) {
                            map[arr[i]] = true
                            count++
                        }
                    }
                    hiddenAppsMap = map
                    hiddenAppsCount = count
                    return
                }
            }
        } catch (e) {
            taskBackend.debugLog("appmenu", "Sem apps ocultos salvos.")
        }
        hiddenAppsMap = {}
        hiddenAppsCount = 0
    }

    function saveHiddenApps() {
        try {
            var arr = Object.keys(hiddenAppsMap).filter(function(k) { return hiddenAppsMap[k] === true })
            taskBackend.writeUserJsonFile("dock_hidden_apps.json", JSON.stringify(arr, null, 2))
            hiddenAppsCount = arr.length
        } catch (e) {
            taskBackend.debugLog("appmenu", "Falha ao salvar apps ocultos.")
        }
    }

    function isAppHidden(app) {
        var key = getAppKey(app)
        return !!hiddenAppsMap[key]
    }

    function hideApp(app) {
        var key = getAppKey(app)
        if (!key) return
        var newMap = Object.assign({}, hiddenAppsMap)
        newMap[key] = true
        hiddenAppsMap = newMap
        saveHiddenApps()
        updateFilteredModel()
    }

    function unhideApp(app) {
        var key = getAppKey(app)
        if (!key) return
        var newMap = Object.assign({}, hiddenAppsMap)
        delete newMap[key]
        hiddenAppsMap = newMap
        saveHiddenApps()
        updateFilteredModel()
    }

    function restoreAllHiddenApps() {
        hiddenAppsMap = {}
        saveHiddenApps()
        updateFilteredModel()
    }

    function loadUserSize() {
        try {
            var raw = taskBackend.readUserJsonFile("appmenu_size.json")
            if (raw && raw.length > 0) {
                var obj = JSON.parse(raw)
                if (obj && obj.width > 0 && obj.height > 0) {
                    userMenuWidth = obj.width
                    userMenuHeight = obj.height
                }
            }
        } catch (e) {
            taskBackend.debugLog("appmenu", "Sem tamanho salvo; usando padrão.")
        }
    }

    function saveUserSize() {
        try {
            var data = JSON.stringify({ width: userMenuWidth, height: userMenuHeight })
            taskBackend.writeUserJsonFile("appmenu_size.json", data)
        } catch (e) {
            taskBackend.debugLog("appmenu", "Falha ao salvar tamanho do menu.")
        }
    }

    function applyWindowBlur() {
        if (appMenuWin.visible && menuOpen) {
            var rx = Math.round(panel.x)
            var ry = Math.round(panel.y)
            var rw = Math.round(panel.width)
            var rh = Math.round(panel.height)
            var rRad = Math.round(panel.radius)
            taskBackend.enableWindowBlur(appMenuWin, true, rx, ry, rw, rh, rRad)
        }
    }

    onVisibleChanged: {
        if (visible) applyWindowBlur()
    }
    onActiveChanged: {
        if (!active && menuOpen) {
            closeMenu()
        }
    }
    onUserMenuWidthChanged: applyWindowBlur()
    onUserMenuHeightChanged: applyWindowBlur()

    function openMenu(anchor, xG, yG) {
        menuOpen = true
        anchorItem = anchor
        anchorGlobalX = xG
        anchorGlobalY = yG
        loadHiddenApps()
        if (!allAppsList || allAppsList.length === 0) {
            allAppsList = taskBackend.getAllInstalledApps()
        }
        searchText = ""
        selectedCategory = "all"
        repositionAboveIcon()
        appMenuWin.show()
        applyWindowBlur()
        Qt.callLater(function() { 
            applyWindowBlur()
            searchInput.forceActiveFocus() 
        })
    }

    function closeMenu() {
        menuOpen = false
        if (appContextMenu.opened) {
            appContextMenu.close()
        }
        taskBackend.enableWindowBlur(appMenuWin, false)
        closeAnimTimer.restart()
    }

    Timer {
        id: closeAnimTimer
        interval: 220
        repeat: false
        onTriggered: {
            appMenuWin.visible = false
            taskBackend.enableWindowBlur(appMenuWin, false)
        }
    }

    function scheduleReposition() {
        repositionTimer.restart()
    }

    function repositionAboveIcon() {
        var edge = dock.liveDockEdge
        var targetX = 0
        var targetY = 0
        var gap = Math.round(14 * dock.liveScaleFactor)
        var sc = appMenuWin.screen || dock.screen

        var screenVirtualX = sc ? sc.virtualX : 0
        var screenVirtualY = sc ? sc.virtualY : 0
        var screenWidth = sc ? sc.width : 1920
        var screenHeight = sc ? sc.height : 1080

        var anchorRelX = 0
        var anchorRelY = 0

        if (anchorItem) {
            var g = anchorItem.mapToItem(null, anchorItem.width / 2, anchorItem.height / 2)
            anchorRelX = g.x
            anchorRelY = g.y
        } else {
            anchorRelX = anchorGlobalX
            anchorRelY = anchorGlobalY
        }

        // Determina a posição global da doca na tela (Wayland LayerShell / X11)
        var dockGlobalX = (dock.x > 0) ? dock.x : (screenVirtualX + Math.max(0, (screenWidth - dock.width) / 2))
        var dockGlobalY = (dock.y > 0) ? dock.y : (screenVirtualY + Math.max(0, screenHeight - dock.height))

        // Alinhamento do lado esquerdo do menu com o final esquerdo da barra visual da dock
        var dockVisualLeftX = dockGlobalX
        if (dock.dockBg) {
            var bgPos = dock.dockBg.mapToItem(null, 0, 0)
            dockVisualLeftX = dockGlobalX + bgPos.x
        }

        if (edge === 2) {
            // Lateral esquerda
            targetX = Math.round(screenVirtualX + dock.width + gap)
            targetY = Math.round(dockGlobalY + (dock.dockBg ? dock.dockBg.mapToItem(null, 0, 0).y : 0))
        } else if (edge === 3) {
            // Lateral direita
            targetX = Math.round(screenVirtualX + screenWidth - dock.width - userMenuWidth - gap)
            targetY = Math.round(dockGlobalY + (dock.dockBg ? dock.dockBg.mapToItem(null, 0, 0).y : 0))
        } else if (edge === 1) {
            // Topo
            targetX = Math.round(dockVisualLeftX)
            targetY = Math.round(screenVirtualY + dock.height + gap)
        } else {
            // Base (Padrão): lado esquerdo do menu alinhado com o final esquerdo da doca
            targetX = Math.round(dockVisualLeftX)
            targetY = Math.round(screenVirtualY + screenHeight - dock.height - userMenuHeight - gap)
        }

        if (sc) {
            targetX = Math.max(screenVirtualX + 12, Math.min(targetX, screenVirtualX + screenWidth - userMenuWidth - 12))
            targetY = Math.max(screenVirtualY + 12, Math.min(targetY, screenVirtualY + screenHeight - userMenuHeight - 12))
        }

        var marginX = targetX
        var marginY = Math.round((dock.dockBarHeightPx * dock.liveScaleFactor) + gap)
        if (edge === 2 || edge === 3) {
            marginY = Math.round(targetY)
            marginX = Math.round((dock.dockBarHeightPx * dock.liveScaleFactor) + gap)
        }
        taskBackend.repositionLayerShellPopup(appMenuWin, edge, marginX, marginY)

        appMenuWin.x = targetX - menuShadowPad
        appMenuWin.y = targetY - menuShadowPad
        applyWindowBlur()
    }

    Timer {
        id: repositionTimer
        interval: 16
        repeat: false
        onTriggered: appMenuWin.repositionAboveIcon()
    }

    Shortcut {
        sequences: [StandardKey.Cancel]
        onActivated: appMenuWin.closeMenu()
    }

    // Ocultar automaticamente quando o mouse sai de cima do menu (exceto se menu de contexto estiver aberto)
    HoverHandler {
        id: menuHover
        target: appMenuWin.contentItem
        onHoveredChanged: {
            if (!hovered && menuOpen && !appContextMenu.opened) {
                mouseLeaveDismissTimer.restart()
            } else {
                mouseLeaveDismissTimer.stop()
            }
        }
    }

    Timer {
        id: mouseLeaveDismissTimer
        interval: 400
        repeat: false
        onTriggered: {
            if (menuOpen && !menuHover.hovered && !appContextMenu.opened) {
                appMenuWin.closeMenu()
            }
        }
    }

    // Categorias em Português BR
    readonly property var baseCategories: [
        { id: "all", label: qsTr("Todos") },
        { id: "office", label: qsTr("Produtividade & Finanças") },
        { id: "utility", label: qsTr("Utilitários") },
        { id: "internet", label: qsTr("Redes Sociais & Internet") },
        { id: "graphics", label: qsTr("Criatividade & Design") },
        { id: "multimedia", label: qsTr("Entretenimento & Mídia") },
        { id: "development", label: qsTr("Desenvolvimento") },
        { id: "other", label: qsTr("Outros") }
    ]

    readonly property var categoriesList: {
        var list = baseCategories.slice()
        list.push({
            id: "hidden",
            label: hiddenAppsCount > 0 ? qsTr("Ocultos (%1)").arg(hiddenAppsCount) : qsTr("Ocultos")
        })
        return list
    }

    function appMatchesFilter(app) {
        if (!app) return false
        const name = String(app.name || "").toLowerCase()
        const comment = String(app.comment || "").toLowerCase()
        const categories = String(app.categories || "").toLowerCase()
        const query = searchText.trim().toLowerCase()
        const hidden = isAppHidden(app)

        // Se estiver na aba de Ocultos
        if (selectedCategory === "hidden") {
            if (!hidden) return false
            if (query.length > 0) {
                return name.includes(query) || comment.includes(query)
            }
            return true
        }

        // Em todas as outras abas/geral: itens ocultos NÃO aparecem na tela principal
        if (hidden) return false

        if (query.length > 0) {
            return name.includes(query) || comment.includes(query)
        }

        if (selectedCategory === "all") return true
        if (selectedCategory === "office") return categories.includes("office") || categories.includes("finance") || categories.includes("document") || categories.includes("texteditor")
        if (selectedCategory === "utility") return categories.includes("utility") || categories.includes("system") || categories.includes("archiving") || categories.includes("filemanager") || categories.includes("terminal") || categories.includes("settings")
        if (selectedCategory === "internet") return categories.includes("network") || categories.includes("web") || categories.includes("chat") || categories.includes("social") || categories.includes("browser") || categories.includes("email")
        if (selectedCategory === "graphics") return categories.includes("graphics") || categories.includes("design") || categories.includes("photography") || categories.includes("2dgraphics") || categories.includes("rastergraphics")
        if (selectedCategory === "multimedia") return categories.includes("audio") || categories.includes("video") || categories.includes("audiovideo") || categories.includes("music") || categories.includes("player") || categories.includes("media")
        if (selectedCategory === "development") return categories.includes("development") || categories.includes("ide") || categories.includes("programming") || categories.includes("building")
        if (selectedCategory === "other") return true

        return true
    }

    ListModel {
        id: filteredAppsModel
    }

    function updateFilteredModel() {
        filteredAppsModel.clear()
        for (var i = 0; i < allAppsList.length; ++i) {
            var app = allAppsList[i]
            if (appMatchesFilter(app)) {
                filteredAppsModel.append({
                    name: app.name || "",
                    icon: app.icon || "application-x-executable",
                    cmd: app.cmd || "",
                    comment: app.comment || "",
                    categories: app.categories || ""
                })
            }
        }
    }

    Timer {
        id: filterDebounceTimer
        interval: 60
        repeat: false
        onTriggered: appMenuWin.updateFilteredModel()
    }

    onSearchTextChanged: filterDebounceTimer.restart()
    onSelectedCategoryChanged: updateFilteredModel()
    onAllAppsListChanged: updateFilteredModel()

    Item {
        id: menuRoot
        anchors.fill: parent

        // Painel Principal Estilo macOS Applications (Vidro Escuro Vidrado + Brilho Especular)
        Rectangle {
            id: panel
            x: appMenuWin.menuShadowPad
            y: appMenuWin.menuShadowPad
            width: appMenuWin.userMenuWidth
            height: appMenuWin.userMenuHeight
            radius: 24 * dock.liveScaleFactor
            color: Qt.rgba(0.08, 0.12, 0.16, 0.55)
            border.color: Qt.rgba(1, 1, 1, 0.22)
            border.width: 1
            clip: true
            z: 1

            // Animação Estilo Hyprland — Wind curve (Scale + Opacity + Translate suave)
            scale: appMenuWin.menuOpen ? 1.0 : 0.90
            opacity: appMenuWin.menuOpen ? 1.0 : 0.0
            transformOrigin: dock.liveDockEdge === 1 ? Item.Top
                             : dock.liveDockEdge === 2 ? Item.Left
                             : dock.liveDockEdge === 3 ? Item.Right
                             : Item.Bottom

            transform: Translate {
                x: dock.liveDockEdge === 2 ? (appMenuWin.menuOpen ? 0 : Math.round(-18 * dock.liveScaleFactor))
                 : dock.liveDockEdge === 3 ? (appMenuWin.menuOpen ? 0 : Math.round(18 * dock.liveScaleFactor))
                 : 0
                y: dock.liveDockEdge === 0 ? (appMenuWin.menuOpen ? 0 : Math.round(18 * dock.liveScaleFactor))
                 : dock.liveDockEdge === 1 ? (appMenuWin.menuOpen ? 0 : Math.round(-18 * dock.liveScaleFactor))
                 : 0

                Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            }

            Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack; easing.overshoot: 0.8 } }
            Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: appMenuWin.menuPad
                spacing: 12 * dock.liveScaleFactor

                // 1. TÍTULO SUPERIOR ESTILO MACOS: "Aplicativos" + Campo de Pesquisa Seguro
                RowLayout {
                    Layout.fillWidth: true
                    height: Math.round(38 * dock.liveScaleFactor)
                    spacing: 10

                    Kirigami.Icon {
                        source: "applications-other"
                        implicitWidth: 26 * dock.liveScaleFactor
                        implicitHeight: 26 * dock.liveScaleFactor
                        color: "#FFFFFF"
                    }

                    Text {
                        text: qsTr("Aplicativos")
                        color: "#FFFFFF"
                        font.pixelSize: 20 * dock.liveScaleFactor
                        font.bold: true
                    }

                    Item { Layout.fillWidth: true }

                    // Campo de Pesquisa Estilo Pílula
                    Rectangle {
                        Layout.preferredWidth: Math.round(220 * dock.liveScaleFactor)
                        height: Math.round(34 * dock.liveScaleFactor)
                        radius: height / 2
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.color: searchInput.activeFocus ? dock.accentFocus : Qt.rgba(1, 1, 1, 0.18)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 6

                            Kirigami.Icon {
                                source: "search"
                                implicitWidth: 16 * dock.liveScaleFactor
                                implicitHeight: 16 * dock.liveScaleFactor
                                color: "#FFFFFF"
                                opacity: 0.85
                            }

                            TextInput {
                                id: searchInput
                                Layout.fillWidth: true
                                text: appMenuWin.searchText
                                onTextChanged: appMenuWin.searchText = text
                                color: "#FFFFFF"
                                font.pixelSize: 13 * dock.liveScaleFactor
                                font.bold: true
                                selectByMouse: true
                                clip: true

                                Text {
                                    text: qsTr("Pesquisar…")
                                    color: "#FFFFFF"
                                    opacity: 0.45
                                    font: searchInput.font
                                    visible: searchInput.text.length === 0 && !searchInput.activeFocus
                                }
                            }

                            Kirigami.Icon {
                                source: "edit-clear"
                                implicitWidth: 14 * dock.liveScaleFactor
                                implicitHeight: 14 * dock.liveScaleFactor
                                color: "#FFFFFF"
                                visible: searchInput.text.length > 0
                                opacity: 0.85

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: searchInput.text = ""
                                }
                            }
                        }
                    }
                }

                // 2. SELETOR DE CATEGORIAS EM PÍLULAS TRANSLÚCIDAS
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.round(34 * dock.liveScaleFactor)
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff

                    Row {
                        spacing: 8 * dock.liveScaleFactor

                        Repeater {
                            model: appMenuWin.categoriesList

                            delegate: ItemDelegate {
                                height: Math.round(30 * dock.liveScaleFactor)
                                padding: 12 * dock.liveScaleFactor
                                highlighted: appMenuWin.selectedCategory === modelData.id

                                background: Rectangle {
                                    radius: height / 2
                                    color: highlighted ? Qt.rgba(1, 1, 1, 0.28) : (parent.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                                    border.color: highlighted ? Qt.rgba(1, 1, 1, 0.40) : Qt.rgba(1, 1, 1, 0.12)
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: modelData.label
                                    color: "#FFFFFF"
                                    font.pixelSize: 12 * dock.liveScaleFactor
                                    font.bold: highlighted
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    appMenuWin.selectedCategory = modelData.id
                                    searchInput.text = ""
                                }
                            }
                        }
                    }
                }

                // 2.5 BANNER INFORMATIVO NA ABA "OCULTOS"
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: Math.round(34 * dock.liveScaleFactor)
                    radius: 10 * dock.liveScaleFactor
                    color: Qt.rgba(1, 1, 1, 0.08)
                    border.color: Qt.rgba(1, 1, 1, 0.15)
                    border.width: 1
                    visible: appMenuWin.selectedCategory === "hidden"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12 * dock.liveScaleFactor
                        anchors.rightMargin: 12 * dock.liveScaleFactor
                        spacing: 8 * dock.liveScaleFactor

                        Kirigami.Icon {
                            source: "view-hidden"
                            implicitWidth: 16 * dock.liveScaleFactor
                            implicitHeight: 16 * dock.liveScaleFactor
                            color: "#FFAAAA"
                        }

                        Text {
                            text: qsTr("Estes aplicativos estão ocultos da tela inicial do menu.")
                            color: "#FFFFFF"
                            font.pixelSize: 12 * dock.liveScaleFactor
                            opacity: 0.85
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        Button {
                            text: qsTr("Restaurar Todos")
                            visible: appMenuWin.hiddenAppsCount > 0
                            onClicked: appMenuWin.restoreAllHiddenApps()

                            contentItem: Text {
                                text: parent.text
                                color: "#66FF88"
                                font.pixelSize: 11 * dock.liveScaleFactor
                                font.bold: true
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            background: Rectangle {
                                implicitHeight: 24 * dock.liveScaleFactor
                                radius: 6 * dock.liveScaleFactor
                                color: parent.hovered ? Qt.rgba(0.2, 0.7, 0.4, 0.35) : Qt.rgba(1, 1, 1, 0.10)
                                border.color: parent.hovered ? Qt.rgba(0.2, 0.7, 0.4, 0.7) : Qt.rgba(1, 1, 1, 0.20)
                                border.width: 1
                            }
                        }
                    }
                }

                // 3. GRELHA DE APLICATIVOS — Rolagem Suave Hyprland + Animações Escalonadas
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    // Contador de geração para animação de entrada ao trocar filtro/categoria
                    property int filterGeneration: 0

                    GridView {
                        id: macAppsGrid
                        anchors.fill: parent
                        anchors.margins: 4 * dock.liveScaleFactor

                        readonly property int dynamicCols: Math.max(3, Math.min(8, Math.floor(width / Math.round(140 * dock.liveScaleFactor))))
                        cellWidth: Math.floor(width / dynamicCols)
                        cellHeight: Math.round(120 * dock.liveScaleFactor)
                        model: filteredAppsModel

                        // --- Física de Rolagem Leve e Suave ---
                        cacheBuffer: 1200
                        reuseItems: true
                        flickDeceleration: 600
                        maximumFlickVelocity: 8000
                        boundsBehavior: Flickable.DragAndOvershootBounds
                        boundsMovement: Flickable.FollowBoundsBehavior
                        highlightMoveDuration: 0
                        pixelAligned: true

                        // Rolagem suave com roda do mouse
                        WheelHandler {
                            id: gridWheelHandler
                            target: macAppsGrid
                            property: "contentY"
                            rotationScale: -0.8
                        }

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 5 * dock.liveScaleFactor

                            contentItem: Rectangle {
                                implicitWidth: 5 * dock.liveScaleFactor
                                radius: width / 2
                                color: Qt.rgba(1, 1, 1, parent.parent.active ? 0.45 : 0.20)
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }

                        delegate: Item {
                            id: appDelegate
                            width: macAppsGrid.cellWidth
                            height: macAppsGrid.cellHeight

                            readonly property bool isHidden: appMenuWin.isAppHidden({ name: model.name, cmd: model.cmd })
                            readonly property bool itemHovered: (hoverHandler.hovered || actionHover.hovered) && !macAppsGrid.moving && !macAppsGrid.flicking

                            // --- Animação de entrada escalonada Hyprland ---
                            opacity: 1.0
                            scale: 1.0

                            GridView.onAdd: {
                                appDelegate.opacity = 0
                                appDelegate.scale = 0.88
                                entranceAnim.start()
                            }

                            GridView.onReused: {
                                entranceAnim.stop()
                                appDelegate.opacity = 1.0
                                appDelegate.scale = 1.0
                            }

                            ParallelAnimation {
                                id: entranceAnim
                                NumberAnimation {
                                    target: appDelegate; property: "opacity"
                                    from: 0; to: 1.0
                                    duration: 280
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: appDelegate; property: "scale"
                                    from: 0.88; to: 1.0
                                    duration: 320
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.1
                                }
                            }

                            Rectangle {
                                id: delegateBg
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 14 * dock.liveScaleFactor
                                color: appDelegate.itemHovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                                border.color: appDelegate.itemHovered ? Qt.rgba(1, 1, 1, 0.30) : "transparent"
                                border.width: 1

                                Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                Behavior on border.color { ColorAnimation { duration: 150; easing.type: Easing.OutCubic } }
                            }

                            HoverHandler {
                                id: hoverHandler
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor

                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        var globalPos = mapToItem(panel, mouse.x, mouse.y)
                                        appContextMenu.openAt(globalPos.x, globalPos.y, {
                                            name: model.name,
                                            icon: model.icon,
                                            cmd: model.cmd,
                                            comment: model.comment || "",
                                            isHidden: appDelegate.isHidden
                                        })
                                    } else if (mouse.button === Qt.LeftButton) {
                                        taskBackend.launchApp(model.cmd)
                                        appMenuWin.closeMenu()
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Item {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 64 * dock.liveScaleFactor
                                    implicitHeight: 64 * dock.liveScaleFactor

                                    Kirigami.Icon {
                                        id: appIcon
                                        source: model.icon
                                        anchors.centerIn: parent
                                        implicitWidth: 64 * dock.liveScaleFactor
                                        implicitHeight: 64 * dock.liveScaleFactor
                                        scale: appDelegate.itemHovered ? 1.12 : 1.0
                                        Behavior on scale {
                                            NumberAnimation {
                                                duration: 180
                                                easing.type: Easing.OutBack
                                                easing.overshoot: 1.4
                                            }
                                        }
                                    }

                                    // Brilho sutil ao hover
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: appIcon.width * 1.3
                                        height: appIcon.height * 1.3
                                        radius: width / 2
                                        color: Qt.rgba(1, 1, 1, 0.06)
                                        visible: appDelegate.itemHovered
                                        z: -1
                                        scale: appDelegate.itemHovered ? 1.0 : 0.6
                                        opacity: appDelegate.itemHovered ? 1.0 : 0.0
                                        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                                    }
                                }

                                Text {
                                    text: model.name
                                    color: "#FFFFFF"
                                    font.pixelSize: 13 * dock.liveScaleFactor
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignHCenter
                                    opacity: appDelegate.itemHovered ? 1.0 : 0.90
                                    Behavior on opacity { NumberAnimation { duration: 120 } }
                                }
                            }

                            // Botão Rápido de Ocultar / Restaurar no Canto Superior Direito
                            Rectangle {
                                id: quickActionButton
                                width: 22 * dock.liveScaleFactor
                                height: 22 * dock.liveScaleFactor
                                radius: width / 2
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.topMargin: 6 * dock.liveScaleFactor
                                anchors.rightMargin: 6 * dock.liveScaleFactor
                                z: 20
                                visible: appDelegate.itemHovered
                                scale: actionHover.hovered ? 1.15 : 1.0
                                opacity: appDelegate.itemHovered ? 1.0 : 0.0

                                color: appDelegate.isHidden ? (actionHover.hovered ? Qt.rgba(0.2, 0.8, 0.4, 0.9) : Qt.rgba(0.2, 0.7, 0.4, 0.6))
                                                            : (actionHover.hovered ? Qt.rgba(0.9, 0.25, 0.25, 0.9) : Qt.rgba(1, 1, 1, 0.25))
                                border.color: Qt.rgba(1, 1, 1, 0.4)
                                border.width: 1

                                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Kirigami.Icon {
                                    anchors.centerIn: parent
                                    implicitWidth: 12 * dock.liveScaleFactor
                                    implicitHeight: 12 * dock.liveScaleFactor
                                    source: appDelegate.isHidden ? "view-refresh" : "edit-delete"
                                    color: "#FFFFFF"
                                }

                                HoverHandler {
                                    id: actionHover
                                }

                                TapHandler {
                                    onTapped: {
                                        if (appDelegate.isHidden) {
                                            appMenuWin.unhideApp({ name: model.name, cmd: model.cmd })
                                        } else {
                                            appMenuWin.hideApp({ name: model.name, cmd: model.cmd })
                                        }
                                    }
                                }

                                ToolTip.visible: actionHover.hovered
                                ToolTip.delay: 300
                                ToolTip.text: appDelegate.isHidden ? qsTr("Restaurar para a tela inicial") : qsTr("Ocultar da tela inicial")
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: appMenuWin.selectedCategory === "hidden" ? qsTr("Nenhum aplicativo oculto") : qsTr("Nenhum aplicativo encontrado")
                        color: "#FFFFFF"
                        opacity: 0.55
                        font.pixelSize: 14 * dock.liveScaleFactor
                        visible: filteredAppsModel.count === 0
                    }
                }
            }

            // Backdrop para fechar o menu de contexto ao clicar fora dele
            MouseArea {
                anchors.fill: parent
                z: 299
                enabled: appContextMenu.opened
                visible: appContextMenu.opened
                acceptedButtons: Qt.AllButtons
                onClicked: appContextMenu.close()
            }

            // Menu de Contexto Flutuante para Aplicativos (Estilo Hyprland)
            Rectangle {
                id: appContextMenu
                z: 300
                width: Math.round(220 * dock.liveScaleFactor)
                implicitHeight: ctxMenuCol.implicitHeight + Math.round(16 * dock.liveScaleFactor)
                radius: 14 * dock.liveScaleFactor
                color: Qt.rgba(0.08, 0.12, 0.16, 0.96)
                border.color: Qt.rgba(1, 1, 1, 0.25)
                border.width: 1
                clip: true
                visible: opacity > 0.01
                opacity: opened ? 1.0 : 0.0
                scale: opened ? 1.0 : 0.88
                transformOrigin: Item.TopLeft

                Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }

                property bool opened: false
                property var targetApp: ({})

                function openAt(px, py, app) {
                    targetApp = app
                    var targetX = Math.min(px, panel.width - width - 12)
                    var targetY = Math.min(py, panel.height - implicitHeight - 12)
                    x = Math.max(12, targetX)
                    y = Math.max(12, targetY)
                    opened = true
                }

                function close() {
                    opened = false
                }

                ColumnLayout {
                    id: ctxMenuCol
                    anchors.fill: parent
                    anchors.margins: 8 * dock.liveScaleFactor
                    spacing: 4 * dock.liveScaleFactor

                    // Cabeçalho com Ícone e Nome do App
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8 * dock.liveScaleFactor

                        Kirigami.Icon {
                            source: appContextMenu.targetApp ? (appContextMenu.targetApp.icon || "application-x-executable") : ""
                            implicitWidth: 20 * dock.liveScaleFactor
                            implicitHeight: 20 * dock.liveScaleFactor
                        }

                        Text {
                            text: appContextMenu.targetApp ? (appContextMenu.targetApp.name || "") : ""
                            color: "#FFFFFF"
                            font.pixelSize: 13 * dock.liveScaleFactor
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Qt.rgba(1, 1, 1, 0.15)
                    }

                    // Opção 1: Executar / Abrir
                    ItemDelegate {
                        Layout.fillWidth: true
                        implicitHeight: 28 * dock.liveScaleFactor
                        padding: 6 * dock.liveScaleFactor

                        background: Rectangle {
                            radius: 8 * dock.liveScaleFactor
                            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                        }

                        contentItem: RowLayout {
                            spacing: 8 * dock.liveScaleFactor
                            Kirigami.Icon {
                                source: "media-playback-start"
                                implicitWidth: 14 * dock.liveScaleFactor
                                implicitHeight: 14 * dock.liveScaleFactor
                                color: dock.accentIdle
                            }
                            Text {
                                text: qsTr("Abrir aplicativo")
                                color: "#FFFFFF"
                                font.pixelSize: 12 * dock.liveScaleFactor
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            if (appContextMenu.targetApp && appContextMenu.targetApp.cmd) {
                                taskBackend.launchApp(appContextMenu.targetApp.cmd)
                                appMenuWin.closeMenu()
                            }
                            appContextMenu.close()
                        }
                    }

                    // Opção 2: Fixar / Desafixar da Dock
                    ItemDelegate {
                        id: pinItemDelegate
                        Layout.fillWidth: true
                        implicitHeight: 28 * dock.liveScaleFactor
                        padding: 6 * dock.liveScaleFactor

                        readonly property bool isPinned: Boolean(appContextMenu.targetApp && appContextMenu.targetApp.cmd && dock.isCommandPinned(appContextMenu.targetApp.cmd))

                        background: Rectangle {
                            radius: 8 * dock.liveScaleFactor
                            color: parent.hovered ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                        }

                        contentItem: RowLayout {
                            spacing: 8 * dock.liveScaleFactor
                            Kirigami.Icon {
                                source: pinItemDelegate.isPinned ? "bookmark-remove" : "bookmark-new"
                                implicitWidth: 14 * dock.liveScaleFactor
                                implicitHeight: 14 * dock.liveScaleFactor
                                color: "#FFFFFF"
                            }
                            Text {
                                text: pinItemDelegate.isPinned ? qsTr("Desafixar da dock") : qsTr("Fixar na dock")
                                color: "#FFFFFF"
                                font.pixelSize: 12 * dock.liveScaleFactor
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            if (appContextMenu.targetApp && appContextMenu.targetApp.cmd) {
                                var cmd = appContextMenu.targetApp.cmd
                                if (pinItemDelegate.isPinned) {
                                    for (var i = 0; i < dock.appModel.count; ++i) {
                                        if (dock.appModel.get(i).cmd === cmd) {
                                            dock.unpinApp(i)
                                            break
                                        }
                                    }
                                } else {
                                    dock.appModel.append({
                                        name: appContextMenu.targetApp.name || "",
                                        icon: appContextMenu.targetApp.icon || "application-x-executable",
                                        cmd: cmd
                                    })
                                    dock.saveApps()
                                }
                            }
                            appContextMenu.close()
                        }
                    }

                    // Opção 3: Ocultar ou Restaurar
                    ItemDelegate {
                        id: hideItemDelegate
                        Layout.fillWidth: true
                        implicitHeight: 28 * dock.liveScaleFactor
                        padding: 6 * dock.liveScaleFactor

                        readonly property bool isHidden: Boolean(appContextMenu.targetApp && appContextMenu.targetApp.isHidden)

                        background: Rectangle {
                            radius: 8 * dock.liveScaleFactor
                            color: parent.hovered ? (hideItemDelegate.isHidden ? Qt.rgba(0.2, 0.7, 0.4, 0.3) : Qt.rgba(1, 0.3, 0.3, 0.3)) : "transparent"
                        }

                        contentItem: RowLayout {
                            spacing: 8 * dock.liveScaleFactor
                            Kirigami.Icon {
                                source: hideItemDelegate.isHidden ? "view-refresh" : "view-hidden"
                                implicitWidth: 14 * dock.liveScaleFactor
                                implicitHeight: 14 * dock.liveScaleFactor
                                color: hideItemDelegate.isHidden ? "#66FF88" : "#FFAAAA"
                            }
                            Text {
                                text: hideItemDelegate.isHidden ? qsTr("Restaurar para a tela inicial") : qsTr("Ocultar da tela inicial")
                                color: hideItemDelegate.isHidden ? "#66FF88" : "#FFAAAA"
                                font.pixelSize: 12 * dock.liveScaleFactor
                                Layout.fillWidth: true
                            }
                        }

                        onClicked: {
                            if (appContextMenu.targetApp) {
                                if (hideItemDelegate.isHidden) {
                                    appMenuWin.unhideApp(appContextMenu.targetApp)
                                } else {
                                    appMenuWin.hideApp(appContextMenu.targetApp)
                                }
                            }
                            appContextMenu.close()
                        }
                    }
                }
            }

            // ================= INDICADOR E PEGA DE ARRASTO NO TOPO (Pílula Central Superior) =================
            Rectangle {
                width: 48 * dock.liveScaleFactor
                height: 5 * dock.liveScaleFactor
                radius: height / 2
                color: topResizeHandle.containsMouse ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.40)
                anchors.top: parent.top
                anchors.topMargin: 6 * dock.liveScaleFactor
                anchors.horizontalCenter: parent.horizontalCenter
                z: 100
                Behavior on color { ColorAnimation { duration: 120 } }
            }

            // ================= PEGA DE REDIMENSIONAMENTO: BORDA SUPERIOR =================
            MouseArea {
                id: topResizeHandle
                height: 16 * dock.liveScaleFactor
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 24 * dock.liveScaleFactor
                anchors.rightMargin: 24 * dock.liveScaleFactor
                cursorShape: Qt.SizeVerCursor
                z: 101

                property real dragStartY: 0
                property real startHeight: 0

                onPressed: (mouse) => {
                    dragStartY = mouse.y
                    startHeight = appMenuWin.userMenuHeight
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dy = dragStartY - mouse.y
                        var minH = Math.round(380 * dock.liveScaleFactor)
                        var maxH = Math.round((dock.screen ? dock.screen.height * 0.88 : 900))
                        appMenuWin.userMenuHeight = Math.max(minH, Math.min(maxH, startHeight + dy))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }

            // ================= PEGA DE REDIMENSIONAMENTO: CANTO SUPERIOR DIREITO =================
            MouseArea {
                width: 24 * dock.liveScaleFactor
                height: 24 * dock.liveScaleFactor
                anchors.top: parent.top
                anchors.right: parent.right
                cursorShape: Qt.SizeBDiagCursor
                z: 101

                property real dragStartX: 0
                property real dragStartY: 0
                property real startWidth: 0
                property real startHeight: 0

                onPressed: (mouse) => {
                    dragStartX = mouse.x
                    dragStartY = mouse.y
                    startWidth = appMenuWin.userMenuWidth
                    startHeight = appMenuWin.userMenuHeight
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dx = mouse.x - dragStartX
                        var dy = dragStartY - mouse.y
                        var minW = Math.round(520 * dock.liveScaleFactor)
                        var minH = Math.round(380 * dock.liveScaleFactor)
                        var maxW = Math.round((dock.screen ? dock.screen.width * 0.92 : 1200))
                        var maxH = Math.round((dock.screen ? dock.screen.height * 0.88 : 900))

                        appMenuWin.userMenuWidth = Math.max(minW, Math.min(maxW, startWidth + dx))
                        appMenuWin.userMenuHeight = Math.max(minH, Math.min(maxH, startHeight + dy))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }

            // ================= PEGA DE REDIMENSIONAMENTO: CANTO SUPERIOR ESQUERDO =================
            MouseArea {
                width: 24 * dock.liveScaleFactor
                height: 24 * dock.liveScaleFactor
                anchors.top: parent.top
                anchors.left: parent.left
                cursorShape: Qt.SizeFDiagCursor
                z: 101

                property real dragStartX: 0
                property real dragStartY: 0
                property real startWidth: 0
                property real startHeight: 0

                onPressed: (mouse) => {
                    dragStartX = mouse.x
                    dragStartY = mouse.y
                    startWidth = appMenuWin.userMenuWidth
                    startHeight = appMenuWin.userMenuHeight
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dx = dragStartX - mouse.x
                        var dy = dragStartY - mouse.y
                        var minW = Math.round(520 * dock.liveScaleFactor)
                        var minH = Math.round(380 * dock.liveScaleFactor)
                        var maxW = Math.round((dock.screen ? dock.screen.width * 0.92 : 1200))
                        var maxH = Math.round((dock.screen ? dock.screen.height * 0.88 : 900))

                        appMenuWin.userMenuWidth = Math.max(minW, Math.min(maxW, startWidth + dx))
                        appMenuWin.userMenuHeight = Math.max(minH, Math.min(maxH, startHeight + dy))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }

            // ================= PEGA DE REDIMENSIONAMENTO: BORDA DIREITA =================
            MouseArea {
                width: 12 * dock.liveScaleFactor
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.topMargin: 24 * dock.liveScaleFactor
                anchors.bottomMargin: 24 * dock.liveScaleFactor
                cursorShape: Qt.SizeHorCursor
                z: 101

                property real dragStartX: 0
                property real startWidth: 0

                onPressed: (mouse) => {
                    dragStartX = mouse.x
                    startWidth = appMenuWin.userMenuWidth
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dx = mouse.x - dragStartX
                        var minW = Math.round(520 * dock.liveScaleFactor)
                        var maxW = Math.round((dock.screen ? dock.screen.width * 0.92 : 1200))
                        appMenuWin.userMenuWidth = Math.max(minW, Math.min(maxW, startWidth + dx))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }

            // ================= PEGA DE REDIMENSIONAMENTO: BORDA ESQUERDA =================
            MouseArea {
                width: 12 * dock.liveScaleFactor
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.topMargin: 24 * dock.liveScaleFactor
                anchors.bottomMargin: 24 * dock.liveScaleFactor
                cursorShape: Qt.SizeHorCursor
                z: 101

                property real dragStartX: 0
                property real startWidth: 0

                onPressed: (mouse) => {
                    dragStartX = mouse.x
                    startWidth = appMenuWin.userMenuWidth
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dx = dragStartX - mouse.x
                        var minW = Math.round(520 * dock.liveScaleFactor)
                        var maxW = Math.round((dock.screen ? dock.screen.width * 0.92 : 1200))
                        appMenuWin.userMenuWidth = Math.max(minW, Math.min(maxW, startWidth + dx))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }

            // ================= PEGA DE REDIMENSIONAMENTO: CANTO INFERIOR DIREITO =================
            MouseArea {
                width: 24 * dock.liveScaleFactor
                height: 24 * dock.liveScaleFactor
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                cursorShape: Qt.SizeFDiagCursor
                z: 101

                property real dragStartX: 0
                property real dragStartY: 0
                property real startWidth: 0
                property real startHeight: 0

                onPressed: (mouse) => {
                    dragStartX = mouse.x
                    dragStartY = mouse.y
                    startWidth = appMenuWin.userMenuWidth
                    startHeight = appMenuWin.userMenuHeight
                }

                onPositionChanged: (mouse) => {
                    if (pressed) {
                        var dx = mouse.x - dragStartX
                        var dy = mouse.y - dragStartY
                        var minW = Math.round(520 * dock.liveScaleFactor)
                        var minH = Math.round(380 * dock.liveScaleFactor)
                        var maxW = Math.round((dock.screen ? dock.screen.width * 0.92 : 1200))
                        var maxH = Math.round((dock.screen ? dock.screen.height * 0.88 : 900))

                        appMenuWin.userMenuWidth = Math.max(minW, Math.min(maxW, startWidth + dx))
                        appMenuWin.userMenuHeight = Math.max(minH, Math.min(maxH, startHeight + dy))
                        appMenuWin.repositionAboveIcon()
                    }
                }

                onReleased: appMenuWin.saveUserSize()
            }
        }
    }
}
