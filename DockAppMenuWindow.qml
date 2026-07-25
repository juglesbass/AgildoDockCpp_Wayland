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
    
    width: Math.round(userMenuWidth + (menuShadowPad * 2))
    height: Math.round(userMenuHeight + (menuShadowPad * 2))
    flags: Qt.Popup | Qt.FramelessWindowHint | Qt.NoDropShadowWindowHint
    color: "transparent"
    transientParent: dock

    Component.onCompleted: {
        loadUserSize()
        Qt.callLater(function() {
            if (allAppsList.length === 0) {
                allAppsList = taskBackend.getAllInstalledApps()
            }
        })
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
    onUserMenuWidthChanged: applyWindowBlur()
    onUserMenuHeightChanged: applyWindowBlur()

    function openMenu(anchor, xG, yG) {
        menuOpen = true
        anchorItem = anchor
        anchorGlobalX = xG
        anchorGlobalY = yG
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

        if (anchorItem) {
            var g = anchorItem.mapToGlobal(anchorItem.width / 2, anchorItem.height / 2)
            if (edge === 2) {
                targetX = Math.round(g.x + (anchorItem.width / 2) + gap)
                targetY = Math.round(g.y - (userMenuHeight / 2))
            } else if (edge === 3) {
                targetX = Math.round(g.x - (anchorItem.width / 2) - userMenuWidth - gap)
                targetY = Math.round(g.y - (userMenuHeight / 2))
            } else if (edge === 1) {
                targetX = Math.round(g.x - (userMenuWidth / 2))
                targetY = Math.round(g.y + (anchorItem.height / 2) + gap)
            } else {
                targetX = Math.round(g.x - (userMenuWidth / 2))
                targetY = Math.round(g.y - (anchorItem.height / 2) - userMenuHeight - gap)
            }
        } else {
            targetX = Math.round(anchorGlobalX - (userMenuWidth / 2))
            targetY = Math.round(anchorGlobalY - userMenuHeight - gap)
        }

        var sc = appMenuWin.screen || dock.screen
        if (sc) {
            targetX = Math.max(sc.virtualX + 12, Math.min(targetX, sc.virtualX + sc.width - userMenuWidth - 12))
            targetY = Math.max(sc.virtualY + 12, Math.min(targetY, sc.virtualY + sc.height - userMenuHeight - 12))
        }

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

    // Categorias em Português BR correspondentes ao macOS
    readonly property var categoriesList: [
        { id: "all", label: qsTr("Todos") },
        { id: "office", label: qsTr("Produtividade & Finanças") },
        { id: "utility", label: qsTr("Utilitários") },
        { id: "internet", label: qsTr("Redes Sociais & Internet") },
        { id: "graphics", label: qsTr("Criatividade & Design") },
        { id: "multimedia", label: qsTr("Entretenimento & Mídia") },
        { id: "development", label: qsTr("Desenvolvimento") },
        { id: "other", label: qsTr("Outros") }
    ]

    function appMatchesFilter(app) {
        if (!app) return false
        const name = String(app.name || "").toLowerCase()
        const comment = String(app.comment || "").toLowerCase()
        const categories = String(app.categories || "").toLowerCase()
        const query = searchText.trim().toLowerCase()

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
                    comment: app.comment || ""
                })
            }
        }
    }

    onSearchTextChanged: updateFilteredModel()
    onSelectedCategoryChanged: updateFilteredModel()
    onAllAppsListChanged: updateFilteredModel()

    Item {
        id: menuRoot
        anchors.fill: parent

        // Painel Principal Estilo macOS Applications (Vidro Escuro Azulado / Frosted Teal com Blur KWin)
        Rectangle {
            id: panel
            x: appMenuWin.menuShadowPad
            y: appMenuWin.menuShadowPad
            width: appMenuWin.userMenuWidth
            height: appMenuWin.userMenuHeight
            radius: 24 * dock.liveScaleFactor
            color: Qt.rgba(0.06, 0.12, 0.16, 0.58)
            border.color: Qt.rgba(1, 1, 1, 0.25)
            border.width: 1
            clip: true

            // Animação Ultra-Suave Estilo macOS (Scale + Opacity + Deslize sutil)
            scale: appMenuWin.menuOpen ? 1.0 : 0.92
            opacity: appMenuWin.menuOpen ? 1.0 : 0.0
            transformOrigin: dock.liveDockEdge === 1 ? Item.Top
                             : dock.liveDockEdge === 2 ? Item.Left
                             : dock.liveDockEdge === 3 ? Item.Right
                             : Item.Bottom

            transform: Translate {
                x: dock.liveDockEdge === 2 ? (appMenuWin.menuOpen ? 0 : Math.round(-14 * dock.liveScaleFactor))
                 : dock.liveDockEdge === 3 ? (appMenuWin.menuOpen ? 0 : Math.round(14 * dock.liveScaleFactor))
                 : 0
                y: dock.liveDockEdge === 0 ? (appMenuWin.menuOpen ? 0 : Math.round(14 * dock.liveScaleFactor))
                 : dock.liveDockEdge === 1 ? (appMenuWin.menuOpen ? 0 : Math.round(-14 * dock.liveScaleFactor))
                 : 0

                Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            }

            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

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

                // 3. GRELHA DE APLICATIVOS (Alta Performance com cacheBuffer e reuseItems)
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    clip: true

                    GridView {
                        id: macAppsGrid
                        anchors.fill: parent
                        anchors.margins: 4 * dock.liveScaleFactor
                        
                        readonly property int dynamicCols: Math.max(3, Math.min(8, Math.floor(width / Math.round(140 * dock.liveScaleFactor))))
                        cellWidth: Math.floor(width / dynamicCols)
                        cellHeight: Math.round(120 * dock.liveScaleFactor)
                        model: filteredAppsModel

                        // Otimizações de Rolagem Amanteigada Estilo macOS 60/120 FPS:
                        cacheBuffer: 1000
                        reuseItems: true
                        flickDeceleration: 500
                        maximumFlickVelocity: 5000
                        boundsBehavior: Flickable.DragAndOvershootBounds
                        highlightMoveDuration: 0

                        ScrollBar.vertical: ScrollBar {
                            policy: ScrollBar.AsNeeded
                            width: 6 * dock.liveScaleFactor
                        }

                        delegate: ItemDelegate {
                            id: appDelegate
                            width: macAppsGrid.cellWidth
                            height: macAppsGrid.cellHeight

                            readonly property bool itemHovered: hovered && !macAppsGrid.moving && !macAppsGrid.flicking

                            background: Rectangle {
                                anchors.fill: parent
                                anchors.margins: 4
                                radius: 14 * dock.liveScaleFactor
                                color: appDelegate.itemHovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                                border.color: appDelegate.itemHovered ? Qt.rgba(1, 1, 1, 0.25) : "transparent"
                                border.width: 1
                            }

                            contentItem: ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 6

                                Kirigami.Icon {
                                    source: model.icon
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 64 * dock.liveScaleFactor
                                    implicitHeight: 64 * dock.liveScaleFactor
                                    scale: appDelegate.itemHovered ? 1.08 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 120 } }
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
                                }
                            }

                            onClicked: {
                                taskBackend.launchApp(model.cmd)
                                appMenuWin.closeMenu()
                            }
                        }
                    }

                    Label {
                        anchors.centerIn: parent
                        text: qsTr("Nenhum aplicativo encontrado")
                        color: "#FFFFFF"
                        opacity: 0.55
                        font.pixelSize: 14 * dock.liveScaleFactor
                        visible: filteredAppsModel.count === 0
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
