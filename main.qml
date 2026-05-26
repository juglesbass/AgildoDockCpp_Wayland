import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window
import org.kde.kirigami as Kirigami
import QtCore

Window {
    id: root

    // Accessible: só em tipos derivados de Item — ver dockContainer.

    // Métricas nomeadas (geometria da onda e da barra)
    readonly property real dockWaveRadiusStrideFactor: 3.15
    readonly property real dockBarHeightPx: 68
    readonly property real dockRevealBandPx: 36

    property real liveScaleFactor: 1.0
    property real liveIconSpacing: 10.0
    property real liveDockMargin: 5.0
    property real liveBgOpacity: 0.66
    property real liveMinIconSize: 45.0
    property real liveMaxIconSize: 75.0

    // Cópias “live” só para a janela de configurações
    property bool liveBehaviorAutoHide: false
    property bool liveBehaviorDodgeWindows: false
    property bool liveBehaviorKeepAppsFocused: false
    property int liveBehaviorAutoHideDelayMs: 900
    property int liveThemeMode: 0
    property int liveDockPosition: 0
    property bool liveMiddleClickCloses: false
    property bool liveShowWindowBadge: true
    property string liveLauncherTitle: ""
    property string liveLauncherIcon: ""
    property string liveLauncherCommand: ""

    readonly property bool useLightChrome: {
        if (root.liveThemeMode === 1) {
            return true
        }
        if (root.liveThemeMode === 2 && Qt.styleHints && Qt.styleHints.colorScheme !== undefined) {
            return Qt.styleHints.colorScheme === Qt.ColorScheme.Light
        }
        return false
    }

    onLiveBehaviorKeepAppsFocusedChanged: applyLayerShellFromSettings()
    onLiveBehaviorDodgeWindowsChanged: applyDockRetractedState()
    onLiveBehaviorAutoHideChanged: {
        restartAutoHideTimer()
        applyDockRetractedState()
    }
    onLiveBehaviorAutoHideDelayMsChanged: restartAutoHideTimer()

    property bool dockRetracted: false
    property bool dockAutoHideLatched: false

    onLiveScaleFactorChanged: {
        if (settingsWin.visible) {
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
        }
        updateZone()
    }
    onLiveDockMarginChanged: updateZone()

    // --- MAPA MATEMÁTICO BÁSICO ---
    property real baseMinSize: root.liveMinIconSize * root.liveScaleFactor

    property real baseSpacing: root.liveIconSpacing * root.liveScaleFactor
    property real baseItemWidth: baseMinSize + (15 * root.liveScaleFactor)
    property real baseStride: baseItemWidth + baseSpacing

    property real dividerWidth: baseStride * 0.4
    property int div1Count: dynamicModel.count > 0 ? 1 : 0
    property int div2Count: systemModel.count > 0 ? 1 : 0
    property real dividersWidth: (div1Count + div2Count) * dividerWidth

    property int totalItemsCount: launcherModel.count + appModel.count + dynamicModel.count + systemModel.count
    property real baseRowWidth: (totalItemsCount * baseItemWidth) + (Math.max(0, totalItemsCount - 1) * baseSpacing) + dividersWidth

    property real smoothedWaveRowWidth: baseRowWidth
    onBaseRowWidthChanged: smoothedWaveRowWidth = baseRowWidth

    readonly property real wavePeakDeltaPx: Math.max(0, root.liveMaxIconSize - root.liveMinIconSize)
    property real maxIconsExpansion: root.wavePeakDeltaPx * 7.0 * root.liveScaleFactor

    readonly property real dockIconTopOverflowPx: Math.max(
        0,
        (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor)
        - (root.dockBarHeightPx * root.liveScaleFactor)
        + (10 * root.liveScaleFactor)
    )

    readonly property real dockVerticalMotionSlopPx: 65 * root.liveScaleFactor

    // Matemática global blindada contra retornos `undefined` durante animações
    property real dividerExtraHitArea: Math.max(0, (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor * root.waveAmplitude) - Math.round(root.dockBarHeightPx * root.liveScaleFactor) + (10 * root.liveScaleFactor))

    property real safePadding: Math.max(160, (root.baseStride * root.dockWaveRadiusStrideFactor) * 2.2)

    property real rawWinWidth: baseRowWidth + maxIconsExpansion + safePadding
    readonly property int maxWinWidth: root.screen ? root.screen.width : 16777215
    width: Math.min(maxWinWidth, Math.max(420, Math.round(rawWinWidth / 2) * 2))

    readonly property real dockExpandedHeight: Math.round(
        (root.liveDockMargin + root.dockBarHeightPx) * root.liveScaleFactor
        + root.dockIconTopOverflowPx
        + root.dockVerticalMotionSlopPx
    )

    readonly property real dockPeekHeight: Math.round(Math.max(root.dockRevealBandPx, 48) * root.liveScaleFactor)

    // Deslocamento visual ao recolher (Translate no dockContainer);
    readonly property real dockRetractSlidePixels: Math.max(0, root.dockExpandedHeight - root.dockPeekHeight)

    height: root.dockRetracted ? root.dockPeekHeight : root.dockExpandedHeight

    onHeightChanged: pointerMaskDebouncer.restart()
    onWidthChanged: pointerMaskDebouncer.restart()

    Behavior on height {
        enabled: !settingsWin.visible
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    Component.onDestruction: {
        console.log(qsTr("Doca a fechar; a gravar a lista de aplicações."))
        saveApps()
    }

    HoverHandler {
        id: globalHover
        onPointChanged: {
            var px = globalHover.point.position.x
            var py = globalHover.point.position.y
            if (px === undefined || py === undefined) return;

            root.dockMouseX = px
            root.dockMouseY = py

            var tw = mainRow.width
            if (tw <= 0) {
                tw = root.baseRowWidth
            }

            var waveOn = root.waveAmplitude > 0.02
            var alpha = waveOn ? 0.035 : 0.22
            root.smoothedWaveRowWidth = Math.max(
                root.baseRowWidth,
                (root.smoothedWaveRowWidth * (1.0 - alpha)) + (tw * alpha)
            )

            var rowLeft = (root.width * 0.5) - (root.smoothedWaveRowWidth * 0.5)
            var relX = root.dockMouseX - rowLeft
            var denom = root.smoothedWaveRowWidth
            var lxRaw = denom > 0 ? ((relX / denom) * root.baseRowWidth) : (root.baseRowWidth * 0.5)
            lxRaw = Math.max(0, Math.min(root.baseRowWidth, lxRaw))

            var beta = waveOn ? 0.075 : 0.42
            var lxOut = lxRaw
            if (root.logicalMouseX > -100) {
                lxOut = root.logicalMouseX + (lxRaw - root.logicalMouseX) * beta
            }
            if (waveOn) {
                lxOut = Math.round(lxOut)
            }
            root.logicalMouseX = lxOut

            if (root.dockRetracted && root.dockMouseY > root.height - root.dockRevealBandPx) {
                root.dockAutoHideLatched = false
                root.dockRetracted = false
                root.updateZone()
            }
        }
    }

    property real dockMouseX: -1000
    property real dockMouseY: -1000
    property real logicalMouseX: -1000

    property bool dockHovered: {
        if (!globalHover.hovered) return false

            // Se estiver oculta, desliga o radar dos ícones!
            if (root.dockRetracted) return false

                var maxIcon = Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor
                var safeHitY = root.height - (maxIcon + 25)
                var waveExtra = root.wavePeakDeltaPx * 3.15 * root.liveScaleFactor
                var hoverW = root.baseRowWidth + (30 * root.liveScaleFactor) + waveExtra
                var dockLeft = (root.width / 2) - (hoverW / 2)
                var dockRight = dockLeft + hoverW
                return (dockMouseY > safeHitY) && (dockMouseX >= dockLeft) && (dockMouseX <= dockRight)
    }

    property real waveAmplitude: 0.0

    Timer {
        id: waveCollapseTimer
        interval: 120
        repeat: false
        onTriggered: {
            if (!root.dockHovered) {
                root.waveAmplitude = 0.0
                root.smoothedWaveRowWidth = root.baseRowWidth
            }
        }
    }

    Timer {
        id: autoHideDockTimer
        repeat: false
        onTriggered: {
            if (!root.liveBehaviorAutoHide) return
                if (settingsWin.visible) return
                    if (root.dockHovered) return

                        root.dockAutoHideLatched = true
                        root.applyDockRetractedState()
        }
    }

    function restartAutoHideTimer() {
        if (!root.liveBehaviorAutoHide) {
            autoHideDockTimer.stop()
            root.dockAutoHideLatched = false
            return
        }
        autoHideDockTimer.interval = Math.max(200, root.liveBehaviorAutoHideDelayMs)
        autoHideDockTimer.restart()
    }

    function applyLayerShellFromSettings() {
        var mode = root.liveBehaviorKeepAppsFocused ? 0 : 2
        taskBackend.applyLayerShellKeyboardMode(mode)
        taskBackend.setLayerShellActivateOnShow(!root.liveBehaviorKeepAppsFocused)
    }

    function applyDockPositionFromSettings() {
        if (typeof dockBridge !== "undefined" && dockBridge) {
            dockBridge.applyDockAnchor(root.liveDockPosition)
        }
    }

    function abrirJanelaPreferencias() {
        settingsWin.show()
        settingsWin.raise()
        settingsWin.requestActivate()
    }

    function loadLauncherFromSettings() {
        launcherModel.clear()
        launcherModel.append({
            name: root.liveLauncherTitle.length > 0 ? root.liveLauncherTitle : qsTr("Menu de Aplicativos"),
            icon: root.liveLauncherIcon.length > 0 ? root.liveLauncherIcon : "start-here-kde",
            cmd: root.liveLauncherCommand.length > 0
                ? root.liveLauncherCommand
                : "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu",
            isLauncher: true
        })
    }

    function loadSystemItemsFromSettings() {
        systemModel.clear()
        var raw = dockSettings.systemItemsJson
        if (raw === "") {
            systemModel.append({ name: qsTr("Transferências"), icon: "folder-downloads", cmd: "dolphin ~/Downloads", isSystem: true })
            systemModel.append({ name: qsTr("Reciclagem"), icon: "user-trash", cmd: "dolphin trash:/", isSystem: true })
            saveSystemItems()
            return
        }
        try {
            var arr = JSON.parse(raw)
            if (!Array.isArray(arr)) {
                return
            }
            for (var i = 0; i < arr.length; i++) {
                if (arr[i] && arr[i].name && arr[i].cmd) {
                    systemModel.append({
                        name: arr[i].name,
                        icon: arr[i].icon || "folder",
                        cmd: arr[i].cmd,
                        isSystem: true
                    })
                }
            }
        } catch (e) {
            console.warn(qsTr("Itens de sistema inválidos; a repor padrão.") + " " + e)
            dockSettings.systemItemsJson = ""
            loadSystemItemsFromSettings()
        }
    }

    function saveSystemItems() {
        var arr = []
        for (var i = 0; i < systemModel.count; i++) {
            var item = systemModel.get(i)
            if (item) {
                arr.push({ name: item.name, icon: item.icon, cmd: item.cmd })
            }
        }
        dockSettings.systemItemsJson = JSON.stringify(arr)
        if (typeof dockSettings.sync === "function") {
            dockSettings.sync()
        }
    }

    function applyDockRetractedState() {
        if (settingsWin.visible) {
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            updateZone()
            return
        }
        if (root.dockHovered) {
            root.dockRetracted = false
            updateZone()
            return
        }
        var edgePeek = globalHover.hovered && (dockMouseY > root.height - root.dockRevealBandPx)
        if (edgePeek) {
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            updateZone()
            return
        }

        var dodgeHide = root.liveBehaviorDodgeWindows && taskBackend.activeWindowCoversWorkArea
        var autoHideHide = root.liveBehaviorAutoHide && root.dockAutoHideLatched

        var next = dodgeHide || autoHideHide
        if (next !== root.dockRetracted) {
            root.dockRetracted = next
        }
        updateZone()
    }

    Behavior on waveAmplitude {
        NumberAnimation {
            duration: 350
            easing.type: Easing.OutCubic
        }
    }

    onDockHoveredChanged: {
        if (dockHovered) {
            waveCollapseTimer.stop()
            waveAmplitude = 1.0
            root.smoothedWaveRowWidth = root.baseRowWidth
            root.logicalMouseX = -1000
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
            root.dockRetracted = false
            updateZone()
        } else {
            root.hideDockIconTip()
            waveCollapseTimer.restart()
            if (root.liveBehaviorAutoHide) {
                restartAutoHideTimer()
            }
        }
        applyDockRetractedState()
    }

    Settings {
        id: dockSettings
        category: "General"
        property real scaleFactor: 1.0
        property real iconSpacing: 10.0
        property real bgOpacity: 0.66
        property real dockMargin: 5.0
        property real minIconSize: 45.0
        property real maxIconSize: 75.0
        property string dockApps: ""
        property bool behaviorAutoHide: false
        property bool behaviorDodgeWindows: false
        property bool behaviorKeepAppsFocused: false
        property int behaviorAutoHideDelayMs: 900
        property int themeMode: 0
        property int dockPosition: 0
        property bool middleClickCloses: false
        property bool showWindowBadge: true
        property string launcherTitle: "Menu de Aplicativos"
        property string launcherIcon: "start-here-kde"
        property string launcherCommand: "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu"
        property string systemItemsJson: ""
    }

    property alias appSettings: dockSettings

    Timer {
        id: zoneDebouncer
        interval: 150
        repeat: false
        onTriggered: {
            var espacoTotal = 0
            if (!root.dockRetracted) {
                espacoTotal = ((root.dockBarHeightPx + root.liveDockMargin) * root.liveScaleFactor)
            }
            taskBackend.updateExclusiveZone(Math.round(espacoTotal))
        }
    }

    Timer {
        id: pointerMaskDebouncer
        interval: 48
        repeat: false
        onTriggered: {
            if (root.dockRetracted) {
                taskBackend.setPointerInputExcludeTop(0)
                return
            }
            var ex = Math.round(root.dockVerticalMotionSlopPx)
            if (ex <= 0 || root.height < ex + 32) {
                taskBackend.setPointerInputExcludeTop(0)
            } else {
                taskBackend.setPointerInputExcludeTop(ex)
            }
        }
    }

    function updateZone() {
        zoneDebouncer.restart()
        pointerMaskDebouncer.restart()
    }

    function refreshPointerInputMask() {
        pointerMaskDebouncer.restart()
    }

    property bool dockTipVisible: false
    property string dockTipName: ""
    property string dockTipStatus: ""
    property color dockTipStatusColor: "#00E5FF"
    property string dockTipHint: ""
    property real dockTipAnchorX: 0
    property real dockTipAnchorY: 0

    function showDockIconTip(iconItem, name, statusLine, statusColor, hintLine) {
        if (!iconItem) {
            return
        }
        var p = iconItem.mapToItem(dockContainer, iconItem.width * 0.5, 0)
        root.dockTipAnchorX = p.x
        root.dockTipAnchorY = p.y
        root.dockTipName = name !== undefined ? name : ""
        root.dockTipStatus = statusLine !== undefined ? statusLine : ""
        root.dockTipStatusColor = statusColor
        root.dockTipHint = hintLine !== undefined ? hintLine : ""
        root.dockTipVisible = root.dockTipName.length > 0
    }

    function hideDockIconTip() {
        root.dockTipVisible = false
    }

    Timer {
        id: startupZoneTimer
        interval: 1000
        running: true
        repeat: false
        onTriggered: updateZone()
    }

    ListModel { id: _launcherModel }

    ListModel { id: _appModel }
    ListModel { id: _dynamicModel }
    ListModel { id: _systemModel }

    readonly property alias launcherModel: _launcherModel
    readonly property alias appModel: _appModel
    readonly property alias dynamicModel: _dynamicModel
    readonly property alias systemModel: _systemModel

    function unpinApp(indexToRemove) {
        appModel.remove(indexToRemove)
        saveApps()
    }

    function finalizeDynamicRemove(cmd) {
        for (let i = dynamicModel.count - 1; i >= 0; i--) {
            let e = dynamicModel.get(i)
            if (e.cmd === cmd && e.removing === true) {
                dynamicModel.remove(i)
                return
            }
        }
    }

    function updateDynamicApps() {
        let pinned = []
        for (let i = 0; i < appModel.count; i++) {
            pinned.push(appModel.get(i).cmd)
        }

        let rawRunning = taskBackend.getUnpinnedApps(pinned)
        let running = []

        for (let k = 0; k < rawRunning.length; k++) {
            if (taskBackend.shouldHideFromDock(rawRunning[k].cmd, rawRunning[k].name)) continue
                running.push(rawRunning[k])
        }

        for (let i = dynamicModel.count - 1; i >= 0; i--) {
            let found = false
            for (let j = 0; j < running.length; j++) {
                if (dynamicModel.get(i).cmd === running[j].cmd) {
                    found = true
                    break
                }
            }
            if (!found) {
                let row = dynamicModel.get(i)
                if (row.removing === true) continue
                    dynamicModel.setProperty(i, "removing", true)
            }
        }

        for (let j = 0; j < running.length; j++) {
            let found = false
            for (let i = 0; i < dynamicModel.count; i++) {
                if (dynamicModel.get(i).cmd === running[j].cmd) {
                    found = true
                    if (dynamicModel.get(i).removing === true) {
                        dynamicModel.setProperty(i, "removing", false)
                    }
                    break
                }
            }
            if (!found) {
                dynamicModel.append({
                    name: running[j].name,
                    icon: running[j].icon,
                    cmd: running[j].cmd,
                    isDynamic: true,
                    removing: false
                })
            }
        }
    }

    Connections {
        target: taskBackend
        function onWindowsUpdated() {
            updateDynamicApps()
        }
        function onActiveWindowCoversWorkAreaChanged() {
            applyDockRetractedState()
        }
    }

    Component.onCompleted: {
        root.liveScaleFactor  = dockSettings.scaleFactor
        root.liveIconSpacing  = dockSettings.iconSpacing
        root.liveDockMargin   = dockSettings.dockMargin
        root.liveBgOpacity    = dockSettings.bgOpacity
        root.liveMinIconSize  = dockSettings.minIconSize
        root.liveMaxIconSize  = Math.max(dockSettings.minIconSize, dockSettings.maxIconSize)

        root.liveBehaviorAutoHide = dockSettings.behaviorAutoHide
        root.liveBehaviorDodgeWindows = dockSettings.behaviorDodgeWindows
        root.liveBehaviorKeepAppsFocused = dockSettings.behaviorKeepAppsFocused
        root.liveBehaviorAutoHideDelayMs = dockSettings.behaviorAutoHideDelayMs
        root.liveThemeMode = dockSettings.themeMode
        root.liveDockPosition = dockSettings.dockPosition
        root.liveMiddleClickCloses = dockSettings.middleClickCloses
        root.liveShowWindowBadge = dockSettings.showWindowBadge
        root.liveLauncherTitle = dockSettings.launcherTitle
        root.liveLauncherIcon = dockSettings.launcherIcon
        root.liveLauncherCommand = dockSettings.launcherCommand

        loadLauncherFromSettings()
        updateZone()
        let savedData = dockSettings.dockApps

        if (savedData === "") {
            appModel.append({name: qsTr("Terminal"), icon: "konsole", cmd: "konsole"})
            appModel.append({name: qsTr("Ficheiros"), icon: "system-file-manager", cmd: "dolphin"})
            appModel.append({name: qsTr("Steam"), icon: "steam", cmd: "steam"})
            saveApps()
        } else {
            try {
                let parsed = JSON.parse(savedData)
                let apps = []

                if (Array.isArray(parsed)) apps = parsed
                    else if (parsed && parsed.version === 2 && Array.isArray(parsed.apps)) apps = parsed.apps

                        for (let i = 0; i < apps.length; i++) {
                            if (apps[i] && apps[i].name && apps[i].cmd) {
                                appModel.append(apps[i])
                            }
                        }
            } catch (e) {
                console.warn(qsTr("Configuração de apps inválida; a usar lista vazia.") + " " + e)
                dockSettings.dockApps = JSON.stringify({ version: 2, savedAt: Date.now(), apps: [] })
                if (typeof dockSettings.sync === "function") dockSettings.sync()
            }
        }
        loadSystemItemsFromSettings()
        applyDockPositionFromSettings()
        updateDynamicApps()
    }

    function saveApps() {
        let arr = []
        for (let i = 0; i < appModel.count; i++) {
            let item = appModel.get(i)
            if (item) arr.push({ name: item.name, icon: item.icon, cmd: item.cmd })
        }
        dockSettings.dockApps = JSON.stringify({ version: 2, savedAt: Date.now(), apps: arr })
        if (typeof dockSettings.sync === "function") {
            dockSettings.sync()
        }
        saveFlushTimer.restart()
        updateDynamicApps()
    }

    Timer {
        id: saveFlushTimer
        interval: 300
        repeat: false
        onTriggered: {
            if (typeof dockSettings.sync === "function") dockSettings.sync()
        }
    }

    Item {
        id: dockContainer
        anchors.fill: parent
        opacity: 0.0

        Accessible.role: Accessible.Pane
        Accessible.name: qsTr("AgildoDock")
        Accessible.description: qsTr("Dock de aplicações na margem inferior do ecrã.")

        property real dockSlidePixels: root.dockRetracted ? root.dockRetractSlidePixels : 0
        Behavior on dockSlidePixels { enabled: !settingsWin.visible; NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
        transform: Translate { y: dockContainer.dockSlidePixels }

        onDockSlidePixelsChanged: dockBg.requestBlurUpdate()

        property real startupOffsetY: 0

        Component.onCompleted: {
            startupOffsetY = 200 * root.liveScaleFactor
            startupAnim.start()
        }

        ParallelAnimation {
            id: startupAnim
            NumberAnimation {
                target: dockContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 600
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: dockContainer
                property: "startupOffsetY"
                to: 0
                duration: 900
                easing.type: Easing.OutBack
            }
        }

        Rectangle {
            id: dockBg
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round((root.liveDockMargin * root.liveScaleFactor) - dockContainer.startupOffsetY)

            property real waveExtraWidth: root.wavePeakDeltaPx * 3.15 * root.liveScaleFactor
            property real rawBgWidth: root.baseRowWidth + (30 * root.liveScaleFactor) + (waveExtraWidth * root.waveAmplitude)

            width:  Math.round(rawBgWidth / 2) * 2
            height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)

            color: root.useLightChrome
                ? Qt.rgba(0.94, 0.94, 0.96, root.liveBgOpacity)
                : Qt.rgba(0.06, 0.06, 0.06, root.liveBgOpacity)
            radius: Math.round(22 * root.liveScaleFactor)
            border.color: root.useLightChrome
                ? Qt.rgba(0.0, 0.0, 0.0, 0.12)
                : Qt.rgba(1.0, 1.0, 1.0, 0.15)
            border.width: 1
            antialiasing: true

            // === MICRO-BATCHER DE BLUR ===
            // O timer de 8ms espera silenciosamente as âncoras (anchors) de largura e
            // eixo-X terminarem de calcular antes de enviar para o KWin.
            // Resultado: blur sempre centralizado, eliminando a piscada na borda arredondada.
            Timer {
                id: blurThrottleTimer
                interval: 8
                repeat: false
                onTriggered: dockBg.updateBlurNative()
            }

            function requestBlurUpdate() {
                if (!blurThrottleTimer.running) {
                    blurThrottleTimer.start()
                }
            }

            function updateBlurNative() {
                taskBackend.setBlurRegion(
                    Math.round(dockBg.x),
                                          Math.round(dockBg.y + dockContainer.dockSlidePixels),
                                          Math.round(dockBg.width),
                                          Math.round(dockBg.height),
                                          Math.round(dockBg.radius)
                )
            }

            onXChanged: requestBlurUpdate()
            onYChanged: requestBlurUpdate()
            onWidthChanged: requestBlurUpdate()
            onHeightChanged: requestBlurUpdate()
            onRadiusChanged: requestBlurUpdate()

            Component.onCompleted: requestBlurUpdate()
            // =============================

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                height: 1
                color: Qt.rgba(1.0, 1.0, 1.0, 0.12)
                radius: parent.radius
                antialiasing: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: {
                    root.abrirJanelaPreferencias()
                }
            }
        }

        Row {
            id: mainRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: dockBg.bottom

            height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
            spacing: root.baseSpacing

            Repeater {
                model: launcherModel
                delegate: DockIconDelegate { dock: root }
            }
            Repeater {
                model: appModel
                delegate: DockIconDelegate { dock: root }
            }

            Item {
                width: root.dividerWidth
                height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
                visible: root.div1Count > 0

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    anchors.topMargin: -root.dividerExtraHitArea
                    anchors.bottomMargin: -40

                    function updateLogicalMouse(mx) {
                        if (mx === undefined || isNaN(mx) || width <= 0) return
                            if (root.dockHovered || root.waveAmplitude > 0.02) return
                                var logicalStart = ((launcherModel.count + appModel.count) * root.baseStride) - (root.baseSpacing / 2)
                                root.logicalMouseX = logicalStart + ((mx / width) * (root.dividerWidth + root.baseSpacing))
                    }
                    onPositionChanged: { updateLogicalMouse(mouseX) }
                    onEntered: { updateLogicalMouse(mouseX) }
                }

                Rectangle {
                    width: Math.max(2, Math.round(2 * root.liveScaleFactor))
                    height: Math.round(root.dockBarHeightPx * root.liveScaleFactor) * 0.45
                    color: "#30FFFFFF"
                    anchors.centerIn: parent
                    radius: 1
                    antialiasing: true
                }
            }

            Repeater {
                model: dynamicModel
                delegate: DockIconDelegate { dock: root }
            }

            Item {
                width: root.dividerWidth
                height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
                visible: root.div2Count > 0

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true

                    anchors.topMargin: -root.dividerExtraHitArea
                    anchors.bottomMargin: -40

                    function updateLogicalMouse(mx) {
                        if (mx === undefined || isNaN(mx) || width <= 0) return
                            if (root.dockHovered || root.waveAmplitude > 0.02) return
                                var prevCount = launcherModel.count + appModel.count + dynamicModel.count
                                var logicalStart = (prevCount * root.baseStride) + (root.div1Count * root.dividerWidth) - (root.baseSpacing / 2)
                                root.logicalMouseX = logicalStart + ((mx / width) * (root.dividerWidth + root.baseSpacing))
                    }
                    onPositionChanged: { updateLogicalMouse(mouseX) }
                    onEntered: { updateLogicalMouse(mouseX) }
                }

                Rectangle {
                    width: Math.max(2, Math.round(2 * root.liveScaleFactor))
                    height: Math.round(root.dockBarHeightPx * root.liveScaleFactor) * 0.45
                    color: "#30FFFFFF"
                    anchors.centerIn: parent
                    radius: 1
                    antialiasing: true
                }
            }

            Repeater {
                model: systemModel
                delegate: DockIconDelegate { dock: root }
            }
        }

        // Tooltip global (coordenadas relativas ao dockContainer — mapToItem não aceita Window).
        Item {
            id: dockGlobalTip
            z: 200000
            visible: root.dockTipVisible
            x: Math.round(root.dockTipAnchorX - (width * 0.5))
            y: Math.round(root.dockTipAnchorY - height - (8 * root.liveScaleFactor))
            width: globalTipBox.width
            height: globalTipBox.height

            Rectangle {
                id: globalTipBox
                property real tipInnerWidth: Math.min(
                    320,
                    Math.max(
                        globalTipName.implicitWidth,
                        globalTipStatus.visible ? globalTipStatus.implicitWidth : 0,
                        globalTipHint.visible ? globalTipHint.implicitWidth : 0,
                        80
                    )
                )
                width: tipInnerWidth + 24
                height: globalTipColumn.implicitHeight + 12
                radius: 8
                color: "#F0222222"
                border.color: "#70FFFFFF"
                border.width: 1
                clip: true

                Column {
                    id: globalTipColumn
                    x: 12
                    y: 6
                    spacing: 4
                    width: globalTipBox.tipInnerWidth

                    Text {
                        id: globalTipName
                        width: globalTipBox.tipInnerWidth
                        text: root.dockTipName
                        font.bold: true
                        font.pixelSize: 13
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        id: globalTipStatus
                        visible: text.length > 0
                        width: globalTipBox.tipInnerWidth
                        text: root.dockTipStatus
                        font.pixelSize: 12
                        color: root.dockTipStatusColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.NoWrap
                    }
                    Text {
                        id: globalTipHint
                        visible: text.length > 0
                        width: globalTipBox.tipInnerWidth
                        text: root.dockTipHint
                        font.pixelSize: 12
                        color: "#CCCCCC"
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }

    DropArea {
        anchors.fill: dockContainer
        onDropped: function(drop) {
            if (drop.hasUrls) {
                let info = taskBackend.parseDropInfo(drop.urls[0].toString())
                if (info.cmd) {
                    appModel.append({name: info.name, icon: info.icon, cmd: info.cmd})
                    saveApps()
                }
            }
        }
    }

    DockSettingsWindow {
        id: settingsWin
        dock: root
    }

    Connections {
        target: settingsWin
        function onVisibleChanged() {
            if (settingsWin.visible) {
                root.dockAutoHideLatched = false
                autoHideDockTimer.stop()
                root.dockRetracted = false
                root.updateZone()
            } else {
                root.applyDockRetractedState()
            }
        }
    }

    Shortcut {
        sequences: [StandardKey.Preferences, "Ctrl+,"]
        onActivated: root.abrirJanelaPreferencias()
    }
}
