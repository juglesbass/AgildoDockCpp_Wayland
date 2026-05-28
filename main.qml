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
    readonly property real dockWaveRadiusStrideFactor: liveWaveRadiusFactor
    readonly property real dockBarHeightPx: 68
    readonly property real dockRevealBandPx: 36

    property real liveScaleFactor: 1.0
    property real liveIconSpacing: 10.0
    property real liveDockMargin: 5.0
    property real liveBgOpacity: 0.66
    property real liveMinIconSize: 45.0
    property real liveMaxIconSize: 75.0
    property int liveThemeMode: 0 // 0 Escuro, 1 Claro, 2 Noite Azul, 3 Ametista
    property int liveAccentMode: 0 // 0 Ciano, 1 Roxo, 2 Verde, 3 Laranja, 4 Rosa
    property real liveWaveIntensity: 1.0 // 0.6..1.6
    property real liveDockRadius: 22.0 // px base antes da escala
    property bool liveMonochromeIcons: false
    property int liveIndicatorStyle: 0 // 0 ponto, 1 linha, 2 barra, 3 sublinhado, 4 pulso
    property real liveIndicatorScale: 1.0
    property int liveBg3dStyle: 1 // 0 flat, 1 glass3d suave, 2 glass premium
    property string liveGradientColorA: "#111111"
    property string liveGradientColorB: "#191D22"
    property string liveGradientColorC: "#1E1E1E"
    property real liveGradientMix: 0.65
    property real liveGradientAngle: 90
    property real liveBorderWidth: 1.0
    property real liveBorderGlow: 0.16
    property real liveShadowStrength: 0.30
    property int liveAnimationProfile: 0 // 0 suave, 1 rapido, 2 elastico, 3 sem animacao
    property real liveWaveRadiusFactor: 3.15
    property real liveWaveFalloff: 1.0
    property real liveLaunchBounceIntensity: 1.0
    property bool liveAutoThemeByActiveApp: false
    property bool liveDockEditMode: false
    property int liveDockEdge: 0 // 0 baixo, 1 topo, 2 esquerda, 3 direita
    property real liveDockOffsetX: 0
    property real liveDockOffsetY: 0
    property int liveLeftClickAction: 0 // 0 padrao, 1 menu, 2 nova janela
    property int liveMiddleClickAction: 2 // 0 padrao, 1 fechar, 2 nova janela, 3 minimizar
    property int liveRightClickAction: 1 // 0 padrao, 1 menu
    property string liveToggleDockShortcut: "Ctrl+Alt+D"
    property string liveOpenSettingsShortcut: "Ctrl+,"
    property bool liveScheduleThemeEnabled: false
    property int liveDayThemeMode: 1
    property int liveNightThemeMode: 0
    property int liveNightStartHour: 18
    property int liveDayStartHour: 7
    property string liveProfilesJson: "{}"
    property string liveAppRulesJson: "{}"
    property string liveCustomCommandsJson: "{}"
    property string liveWidgetsJson: "[]"
    property string livePresetName: "Dark Glass"
    property var customizationUndoStack: []
    property var customizationRedoStack: []

    function themePalette(mode) {
        if (mode === 1) { // Claro
            return {
                dockR: 0.95, dockG: 0.95, dockB: 0.97,
                dockBorder: Qt.rgba(0.0, 0.0, 0.0, 0.18),
                dockTopLine: Qt.rgba(0.0, 0.0, 0.0, 0.10),
                divider: "#30000000",
                tipBg: "#F0F6F6F8",
                tipBorder: "#70000000",
                textPrimary: "#202020",
                textSecondary: "#4A4A4A",
                menuBg: Qt.rgba(0.96, 0.96, 0.98, 0.99),
                menuBorder: Qt.rgba(0.0, 0.0, 0.0, 0.14),
                menuHover: Qt.rgba(0.0, 0.0, 0.0, 0.08)
            }
        }
        if (mode === 2) { // Noite Azul
            return {
                dockR: 0.05, dockG: 0.09, dockB: 0.14,
                dockBorder: Qt.rgba(0.35, 0.60, 1.0, 0.28),
                dockTopLine: Qt.rgba(0.55, 0.75, 1.0, 0.25),
                divider: "#5090B8FF",
                tipBg: "#F0121A28",
                tipBorder: "#7090B8FF",
                textPrimary: "#EAF2FF",
                textSecondary: "#BCD0EE",
                menuBg: Qt.rgba(0.06, 0.11, 0.19, 0.98),
                menuBorder: Qt.rgba(0.45, 0.68, 1.0, 0.24),
                menuHover: Qt.rgba(0.45, 0.68, 1.0, 0.16)
            }
        }
        if (mode === 3) { // Ametista
            return {
                dockR: 0.10, dockG: 0.06, dockB: 0.12,
                dockBorder: Qt.rgba(0.82, 0.62, 1.0, 0.26),
                dockTopLine: Qt.rgba(0.90, 0.74, 1.0, 0.20),
                divider: "#60D0A0FF",
                tipBg: "#F01A1022",
                tipBorder: "#70C894FF",
                textPrimary: "#F7EAFF",
                textSecondary: "#D8C0E8",
                menuBg: Qt.rgba(0.14, 0.08, 0.18, 0.98),
                menuBorder: Qt.rgba(0.82, 0.62, 1.0, 0.22),
                menuHover: Qt.rgba(0.82, 0.62, 1.0, 0.16)
            }
        }
        // Escuro (padrão atual)
        return {
            dockR: 0.06, dockG: 0.06, dockB: 0.06,
            dockBorder: Qt.rgba(1.0, 1.0, 1.0, 0.15),
            dockTopLine: Qt.rgba(1.0, 1.0, 1.0, 0.12),
            divider: "#30FFFFFF",
            tipBg: "#F0222222",
            tipBorder: "#70FFFFFF",
            textPrimary: "#FFFFFF",
            textSecondary: "#CCCCCC",
            menuBg: Qt.rgba(0.10, 0.11, 0.13, 0.98),
            menuBorder: Qt.rgba(1.0, 1.0, 1.0, 0.14),
            menuHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)
        }
    }

    readonly property var themeColors: themePalette(liveThemeMode)
    readonly property color themeMenuBg: themeColors.menuBg
    readonly property color themeMenuBorder: themeColors.menuBorder
    readonly property color themeMenuHover: themeColors.menuHover
    readonly property color themeTextPrimary: themeColors.textPrimary
    readonly property color themeTextSecondary: themeColors.textSecondary

    function accentPalette(mode) {
        if (mode === 1) return { idle: "#B77BFF", focus: "#D4ACFF" } // Roxo
        if (mode === 2) return { idle: "#39D98A", focus: "#7CF0B5" } // Verde
        if (mode === 3) return { idle: "#FFB347", focus: "#FFD18A" } // Laranja
        if (mode === 4) return { idle: "#FF6FB5", focus: "#FF9CCB" } // Rosa
        return { idle: "#00E5FF", focus: "#00FFCC" } // Ciano
    }
    readonly property var accentColors: accentPalette(liveAccentMode)
    readonly property color accentIdle: accentColors.idle
    readonly property color accentFocus: accentColors.focus

    QtObject {
        id: dockAppearanceModel
        property real scaleFactor: root.liveScaleFactor
        property real iconSpacing: root.liveIconSpacing
        property real dockMargin: root.liveDockMargin
        property real bgOpacity: root.liveBgOpacity
        property real minIconSize: root.liveMinIconSize
        property real maxIconSize: root.liveMaxIconSize
        property int themeMode: root.liveThemeMode
        property int accentMode: root.liveAccentMode
        property real waveIntensity: root.liveWaveIntensity
        property real dockRadius: root.liveDockRadius
        property int indicatorStyle: root.liveIndicatorStyle
        property bool monochromeIcons: root.liveMonochromeIcons
    }

    function animationDuration(baseMs) {
        if (liveAnimationProfile === 3) return 0
        if (liveAnimationProfile === 1) return Math.max(60, Math.round(baseMs * 0.65))
        if (liveAnimationProfile === 2) return Math.round(baseMs * 1.2)
        return baseMs
    }

    function applyThemeForCommand(cmd) {
        if (!liveAutoThemeByActiveApp || !cmd) return
        let c = String(cmd).toLowerCase()
        if (c.indexOf("dolphin") >= 0) liveAccentMode = 2
        else if (c.indexOf("firefox") >= 0 || c.indexOf("chrom") >= 0) liveAccentMode = 0
        else if (c.indexOf("steam") >= 0) liveAccentMode = 3
        else if (c.indexOf("code") >= 0 || c.indexOf("cursor") >= 0) liveAccentMode = 1
    }

    function customCommandsFor(cmd) {
        try {
            let parsed = JSON.parse(liveCustomCommandsJson || "{}")
            let arr = parsed[cmd]
            return Array.isArray(arr) ? arr : []
        } catch (e) {
            return []
        }
    }

    function appRuleForCommand(cmd) {
        try {
            let parsed = JSON.parse(liveAppRulesJson || "{}")
            let rule = parsed[cmd]
            return rule && typeof rule === "object" ? rule : {}
        } catch (e) {
            return {}
        }
    }

    function pushCustomizationHistory() {
        let snap = JSON.stringify({
            scale: liveScaleFactor, spacing: liveIconSpacing, margin: liveDockMargin, opacity: liveBgOpacity,
            min: liveMinIconSize, max: liveMaxIconSize, theme: liveThemeMode, accent: liveAccentMode,
            wave: liveWaveIntensity, radius: liveDockRadius, bgStyle: liveBg3dStyle, gradA: liveGradientColorA,
            gradB: liveGradientColorB, gradC: liveGradientColorC, gradMix: liveGradientMix, borderW: liveBorderWidth,
            borderGlow: liveBorderGlow, shadow: liveShadowStrength, indStyle: liveIndicatorStyle,
            mono: liveMonochromeIcons, edge: liveDockEdge, offX: liveDockOffsetX, offY: liveDockOffsetY
        })
        customizationUndoStack.push(snap)
        if (customizationUndoStack.length > 40) customizationUndoStack.shift()
        customizationRedoStack = []
    }

    function restoreCustomizationSnapshot(snap, fromUndo) {
        try {
            let s = JSON.parse(snap)
            if (fromUndo) {
                customizationRedoStack.push(JSON.stringify({
                    scale: liveScaleFactor, spacing: liveIconSpacing, margin: liveDockMargin, opacity: liveBgOpacity,
                    min: liveMinIconSize, max: liveMaxIconSize, theme: liveThemeMode, accent: liveAccentMode,
                    wave: liveWaveIntensity, radius: liveDockRadius, bgStyle: liveBg3dStyle, gradA: liveGradientColorA,
                    gradB: liveGradientColorB, gradC: liveGradientColorC, gradMix: liveGradientMix, borderW: liveBorderWidth,
                    borderGlow: liveBorderGlow, shadow: liveShadowStrength, indStyle: liveIndicatorStyle,
                    mono: liveMonochromeIcons, edge: liveDockEdge, offX: liveDockOffsetX, offY: liveDockOffsetY
                }))
            } else {
                customizationUndoStack.push(JSON.stringify({
                    scale: liveScaleFactor, spacing: liveIconSpacing, margin: liveDockMargin, opacity: liveBgOpacity,
                    min: liveMinIconSize, max: liveMaxIconSize, theme: liveThemeMode, accent: liveAccentMode,
                    wave: liveWaveIntensity, radius: liveDockRadius, bgStyle: liveBg3dStyle, gradA: liveGradientColorA,
                    gradB: liveGradientColorB, gradC: liveGradientColorC, gradMix: liveGradientMix, borderW: liveBorderWidth,
                    borderGlow: liveBorderGlow, shadow: liveShadowStrength, indStyle: liveIndicatorStyle,
                    mono: liveMonochromeIcons, edge: liveDockEdge, offX: liveDockOffsetX, offY: liveDockOffsetY
                }))
            }
            liveScaleFactor = s.scale; liveIconSpacing = s.spacing; liveDockMargin = s.margin; liveBgOpacity = s.opacity
            liveMinIconSize = s.min; liveMaxIconSize = s.max; liveThemeMode = s.theme; liveAccentMode = s.accent
            liveWaveIntensity = s.wave; liveDockRadius = s.radius; liveBg3dStyle = s.bgStyle
            liveGradientColorA = s.gradA; liveGradientColorB = s.gradB; liveGradientColorC = s.gradC
            liveGradientMix = s.gradMix; liveBorderWidth = s.borderW; liveBorderGlow = s.borderGlow
            liveShadowStrength = s.shadow; liveIndicatorStyle = s.indStyle; liveMonochromeIcons = s.mono
            liveDockEdge = s.edge; liveDockOffsetX = s.offX; liveDockOffsetY = s.offY
            updateZone()
        } catch (e) {
            taskBackend.debugLog("ui", "Falha ao restaurar snapshot de customização.")
        }
    }

    function undoCustomization() {
        if (customizationUndoStack.length === 0) return
        let snap = customizationUndoStack.pop()
        restoreCustomizationSnapshot(snap, true)
    }

    function redoCustomization() {
        if (customizationRedoStack.length === 0) return
        let snap = customizationRedoStack.pop()
        restoreCustomizationSnapshot(snap, false)
    }

    function applyAppearancePreset(presetName) {
        pushCustomizationHistory()
        livePresetName = presetName
        if (presetName === "Dark Glass") {
            liveThemeMode = 0; liveAccentMode = 0; liveBg3dStyle = 1
            liveGradientColorA = "#0C0C0F"; liveGradientColorB = "#171A1F"; liveGradientColorC = "#1E2228"
            liveBorderGlow = 0.20; liveShadowStrength = 0.34; liveMonochromeIcons = false; liveIndicatorStyle = 0
        } else if (presetName === "Light Glass") {
            liveThemeMode = 1; liveAccentMode = 2; liveBg3dStyle = 1
            liveGradientColorA = "#E7EBF1"; liveGradientColorB = "#DCE2EB"; liveGradientColorC = "#F6F8FB"
            liveBorderGlow = 0.12; liveShadowStrength = 0.18; liveMonochromeIcons = false; liveIndicatorStyle = 1
        } else if (presetName === "Neon") {
            liveThemeMode = 2; liveAccentMode = 0; liveBg3dStyle = 1
            liveGradientColorA = "#041022"; liveGradientColorB = "#0B1F3B"; liveGradientColorC = "#16386A"
            liveBorderGlow = 0.34; liveShadowStrength = 0.45; liveMonochromeIcons = true; liveIndicatorStyle = 4
        } else if (presetName === "Minimal") {
            liveThemeMode = 0; liveAccentMode = 1; liveBg3dStyle = 0
            liveGradientColorA = "#171717"; liveGradientColorB = "#171717"; liveGradientColorC = "#171717"
            liveBorderGlow = 0.07; liveShadowStrength = 0.18; liveMonochromeIcons = true; liveIndicatorStyle = 3
        }
        updateZone()
    }

    function applyScheduledThemeByClock() {
        if (!liveScheduleThemeEnabled) return
        const hour = (new Date()).getHours()
        const isNight = (hour >= liveNightStartHour || hour < liveDayStartHour)
        liveThemeMode = isNight ? liveNightThemeMode : liveDayThemeMode
    }

    // Cópias “live” só para a janela de configurações
    property bool liveBehaviorAutoHide: false
    property bool liveBehaviorDodgeWindows: false
    property bool liveBehaviorKeepAppsFocused: false
    property int liveBehaviorAutoHideDelayMs: 900

    onLiveBehaviorKeepAppsFocusedChanged: applyLayerShellFromSettings()
    onLiveBehaviorDodgeWindowsChanged: applyDockRetractedState()
    onLiveBehaviorAutoHideChanged: {
        restartAutoHideTimer()
        applyDockRetractedState()
    }
    onLiveBehaviorAutoHideDelayMsChanged: restartAutoHideTimer()

    property bool dockRetracted: false
    property bool dockAutoHideLatched: false
    property bool dockContextMenuOpen: false

    function showIconContextMenu(anchorItem, data) {
        iconContextMenu.openForIcon(anchorItem, data)
    }

    function lockDockForContextMenu(locked, anchorLogicalX) {
        dockContextMenuOpen = locked
        if (locked) {
            waveCollapseTimer.stop()
            waveAmplitude = 0
            smoothedWaveRowWidth = baseRowWidth
            if (anchorLogicalX !== undefined && !isNaN(anchorLogicalX) && anchorLogicalX >= 0) {
                logicalMouseX = anchorLogicalX
            }
            hideDockIconTip()
        } else {
            if (dockHovered) {
                waveAmplitude = 1.0
                smoothedWaveRowWidth = baseRowWidth
            } else {
                waveCollapseTimer.restart()
            }
        }
    }

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
    property real maxIconsExpansion: root.wavePeakDeltaPx * 7.0 * root.liveScaleFactor * root.liveWaveIntensity

    readonly property real dockIconTopOverflowPx: Math.max(
        0,
        (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor)
        - (root.dockBarHeightPx * root.liveScaleFactor)
        + (10 * root.liveScaleFactor)
    )

    readonly property real dockVerticalMotionSlopPx: 65 * root.liveScaleFactor

    // Matemática global blindada contra retornos `undefined` durante animações
    property real dividerExtraHitArea: Math.max(0, (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor * root.waveAmplitude) - Math.round(root.dockBarHeightPx * root.liveScaleFactor) + (10 * root.liveScaleFactor))

    property real safePadding: Math.max(160, (root.baseStride * root.dockWaveRadiusStrideFactor * root.liveWaveIntensity) * 2.2)

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
        property int themeMode: 0
        property int accentMode: 0
        property real waveIntensity: 1.0
        property real dockRadius: 22.0
        property bool monochromeIcons: false
        property int indicatorStyle: 0
        property real indicatorScale: 1.0
        property int bg3dStyle: 1
        property string gradientColorA: "#111111"
        property string gradientColorB: "#191D22"
        property string gradientColorC: "#1E1E1E"
        property real gradientMix: 0.65
        property real gradientAngle: 90
        property real borderWidth: 1.0
        property real borderGlow: 0.16
        property real shadowStrength: 0.30
        property int animationProfile: 0
        property real waveRadiusFactor: 3.15
        property real waveFalloff: 1.0
        property real launchBounceIntensity: 1.0
        property bool autoThemeByActiveApp: false
        property bool dockEditMode: false
        property int dockEdge: 0
        property real dockOffsetX: 0
        property real dockOffsetY: 0
        property int leftClickAction: 0
        property int middleClickAction: 2
        property int rightClickAction: 1
        property string toggleDockShortcut: "Ctrl+Alt+D"
        property string openSettingsShortcut: "Ctrl+,"
        property bool scheduleThemeEnabled: false
        property int dayThemeMode: 1
        property int nightThemeMode: 0
        property int nightStartHour: 18
        property int dayStartHour: 7
        property string profilesJson: "{}"
        property string appRulesJson: "{}"
        property string customCommandsJson: "{}"
        property string userWidgetsJson: "[]"
        property string presetName: "Dark Glass"
        property string dockApps: ""
        property bool behaviorAutoHide: false
        property bool behaviorDodgeWindows: false
        property bool behaviorKeepAppsFocused: false
        property int behaviorAutoHideDelayMs: 900
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
    property int minimizeSuckSerial: 0

    function removeMinimizeSuck(uid) {
        for (let i = minimizeSuckModel.count - 1; i >= 0; i--) {
            if (minimizeSuckModel.get(i).uid === uid) {
                minimizeSuckModel.remove(i)
                return
            }
        }
    }

    function playMinimizeSuckAt(iconItem) {
        if (!iconItem) {
            return
        }
        var center = iconItem.mapToItem(dockContainer, iconItem.width * 0.5, iconItem.height * 0.5)
        var startY = Math.max(0, dockBg.y - (120 * root.liveScaleFactor))
        var uid = ++root.minimizeSuckSerial
        // Rastro curto para simular "sugar/suck" ao minimizar.
        minimizeSuckModel.append({
            uid: uid,
            startX: center.x,
            startY: startY,
            destX: center.x,
            destY: center.y,
            size: Math.max(10, 14 * root.liveScaleFactor),
            durationMs: 210
        })
    }

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

    Timer {
        id: scheduledThemeTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.applyScheduledThemeByClock()
    }

    ListModel {
        id: _launcherModel
        ListElement {
            name: "Menu de Aplicativos"
            icon: "start-here-kde"
            cmd: "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu"
            isLauncher: true
        }
    }

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

    function populatePinnedAppsFromJson(rawJson) {
        appModel.clear()
        try {
            let parsed = JSON.parse(rawJson)
            let apps = []
            if (Array.isArray(parsed)) {
                apps = parsed
            } else if (parsed && parsed.version === 2 && Array.isArray(parsed.apps)) {
                apps = parsed.apps
            } else {
                return false
            }
            for (let i = 0; i < apps.length; i++) {
                if (apps[i] && apps[i].name && apps[i].cmd) {
                    appModel.append(apps[i])
                }
            }
            return true
        } catch (e) {
            return false
        }
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

    function reloadCustomWidgets() {
        for (let i = systemModel.count - 1; i >= 0; i--) {
            if (systemModel.get(i).isWidget === true) {
                systemModel.remove(i)
            }
        }
        try {
            let arr = JSON.parse(liveWidgetsJson || "[]")
            if (!Array.isArray(arr)) return
            for (let j = 0; j < arr.length; j++) {
                let w = arr[j]
                if (!w || !w.name || !w.cmd) continue
                systemModel.append({
                    name: w.name,
                    icon: w.icon || "applications-system",
                    cmd: w.cmd,
                    isSystem: true,
                    isWidget: true
                })
            }
        } catch (e) {
            taskBackend.debugLog("persist", "Falha ao carregar widgets customizados.")
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
                let rule = appRuleForCommand(rawRunning[k].cmd)
                if (rule.hideFromDock === true) continue
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
        root.liveThemeMode    = dockSettings.themeMode
        root.liveAccentMode   = dockSettings.accentMode
        root.liveWaveIntensity = Math.max(0.6, Math.min(1.6, dockSettings.waveIntensity))
        root.liveDockRadius   = Math.max(8, Math.min(40, dockSettings.dockRadius))
        root.liveMonochromeIcons = dockSettings.monochromeIcons
        root.liveIndicatorStyle = dockSettings.indicatorStyle
        root.liveIndicatorScale = dockSettings.indicatorScale
        root.liveBg3dStyle = dockSettings.bg3dStyle
        root.liveGradientColorA = dockSettings.gradientColorA
        root.liveGradientColorB = dockSettings.gradientColorB
        root.liveGradientColorC = dockSettings.gradientColorC
        root.liveGradientMix = dockSettings.gradientMix
        root.liveGradientAngle = dockSettings.gradientAngle
        root.liveBorderWidth = dockSettings.borderWidth
        root.liveBorderGlow = dockSettings.borderGlow
        root.liveShadowStrength = dockSettings.shadowStrength
        root.liveAnimationProfile = dockSettings.animationProfile
        root.liveWaveRadiusFactor = dockSettings.waveRadiusFactor
        root.liveWaveFalloff = dockSettings.waveFalloff
        root.liveLaunchBounceIntensity = dockSettings.launchBounceIntensity
        root.liveAutoThemeByActiveApp = dockSettings.autoThemeByActiveApp
        root.liveDockEditMode = dockSettings.dockEditMode
        root.liveDockEdge = dockSettings.dockEdge
        root.liveDockOffsetX = dockSettings.dockOffsetX
        root.liveDockOffsetY = dockSettings.dockOffsetY
        root.liveLeftClickAction = dockSettings.leftClickAction
        root.liveMiddleClickAction = dockSettings.middleClickAction
        root.liveRightClickAction = dockSettings.rightClickAction
        root.liveToggleDockShortcut = dockSettings.toggleDockShortcut
        root.liveOpenSettingsShortcut = dockSettings.openSettingsShortcut
        root.liveScheduleThemeEnabled = dockSettings.scheduleThemeEnabled
        root.liveDayThemeMode = dockSettings.dayThemeMode
        root.liveNightThemeMode = dockSettings.nightThemeMode
        root.liveNightStartHour = dockSettings.nightStartHour
        root.liveDayStartHour = dockSettings.dayStartHour
        root.liveProfilesJson = dockSettings.profilesJson
        root.liveAppRulesJson = dockSettings.appRulesJson
        root.liveCustomCommandsJson = dockSettings.customCommandsJson
        root.liveWidgetsJson = dockSettings.userWidgetsJson
        root.livePresetName = dockSettings.presetName
        if (root.liveProfilesJson === "{}") {
            const persistedProfiles = taskBackend.readUserJsonFile("profiles.json")
            if (persistedProfiles !== "") root.liveProfilesJson = persistedProfiles
        }
        if (root.liveAppRulesJson === "{}") {
            const persistedRules = taskBackend.readUserJsonFile("app_rules.json")
            if (persistedRules !== "") root.liveAppRulesJson = persistedRules
        }
        if (root.liveCustomCommandsJson === "{}") {
            const persistedCommands = taskBackend.readUserJsonFile("custom_commands.json")
            if (persistedCommands !== "") root.liveCustomCommandsJson = persistedCommands
        }
        if (root.liveWidgetsJson === "[]") {
            const persistedWidgets = taskBackend.readUserJsonFile("widgets.json")
            if (persistedWidgets !== "") root.liveWidgetsJson = persistedWidgets
        }
        dockSettings.profilesJson = root.liveProfilesJson
        dockSettings.appRulesJson = root.liveAppRulesJson
        dockSettings.customCommandsJson = root.liveCustomCommandsJson
        dockSettings.userWidgetsJson = root.liveWidgetsJson

        root.liveBehaviorAutoHide = dockSettings.behaviorAutoHide
        root.liveBehaviorDodgeWindows = dockSettings.behaviorDodgeWindows
        root.liveBehaviorKeepAppsFocused = dockSettings.behaviorKeepAppsFocused
        root.liveBehaviorAutoHideDelayMs = dockSettings.behaviorAutoHideDelayMs

        applyScheduledThemeByClock()
        updateZone()
        let savedData = dockSettings.dockApps
        if (savedData === "") {
            // Guard rail: tenta snapshot atômico antes de cair no preset.
            const recovered = taskBackend.loadDockAppsSnapshot()
            if (recovered !== "") {
                savedData = recovered
                dockSettings.dockApps = recovered
                if (typeof dockSettings.sync === "function") dockSettings.sync()
            }
        }

        if (savedData === "") {
            appModel.append({name: qsTr("Terminal"), icon: "konsole", cmd: "konsole"})
            appModel.append({name: qsTr("Ficheiros"), icon: "system-file-manager", cmd: "dolphin"})
            appModel.append({name: qsTr("Steam"), icon: "steam", cmd: "steam"})
            saveApps()
        } else {
            if (!populatePinnedAppsFromJson(savedData)) {
                const recovered = taskBackend.loadDockAppsSnapshot()
                if (recovered !== "" && recovered !== savedData && populatePinnedAppsFromJson(recovered)) {
                    dockSettings.dockApps = recovered
                    if (typeof dockSettings.sync === "function") dockSettings.sync()
                    taskBackend.saveDockAppsSnapshot(dockSettings.dockApps)
                    console.warn(qsTr("Configuração recuperada do backup local de segurança."))
                } else {
                    console.warn(qsTr("Configuração de apps inválida; a usar lista vazia."))
                    dockSettings.dockApps = JSON.stringify({ version: 2, savedAt: Date.now(), apps: [] })
                    if (typeof dockSettings.sync === "function") dockSettings.sync()
                }
            } else {
                // Garante snapshot seguro mesmo quando a sessão só lê config e não edita ícones.
                taskBackend.saveDockAppsSnapshot(dockSettings.dockApps)
            }
        }
        systemModel.append({name: qsTr("Transferências"), icon: "folder-downloads", cmd: "dolphin ~/Downloads", isSystem: true})
        systemModel.append({name: qsTr("Reciclagem"), icon: "user-trash", cmd: "dolphin trash:/", isSystem: true})
        reloadCustomWidgets()
        updateDynamicApps()
    }

    function saveApps() {
        let arr = []
        for (let i = 0; i < appModel.count; i++) {
            let item = appModel.get(i)
            if (item) arr.push({ name: item.name, icon: item.icon, cmd: item.cmd })
        }
        dockSettings.dockApps = JSON.stringify({ version: 2, savedAt: Date.now(), apps: arr })
        taskBackend.saveDockAppsSnapshot(dockSettings.dockApps)
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

        MouseArea {
            anchors.fill: parent
            z: 300000
            enabled: root.dockContextMenuOpen
            hoverEnabled: false
            propagateComposedEvents: false
            acceptedButtons: Qt.AllButtons
            onPressed: (mouse) => {
                iconContextMenu.closeMenu()
                mouse.accepted = true
            }
        }

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
            anchors.horizontalCenter: (root.liveDockEdge === 0 || root.liveDockEdge === 1) ? parent.horizontalCenter : undefined
            anchors.verticalCenter: (root.liveDockEdge === 2 || root.liveDockEdge === 3) ? parent.verticalCenter : undefined
            anchors.bottom: root.liveDockEdge === 0 ? parent.bottom : undefined
            anchors.top: root.liveDockEdge === 1 ? parent.top : undefined
            anchors.left: root.liveDockEdge === 2 ? parent.left : undefined
            anchors.right: root.liveDockEdge === 3 ? parent.right : undefined
            anchors.bottomMargin: root.liveDockEdge === 0 ? Math.round((root.liveDockMargin * root.liveScaleFactor) - dockContainer.startupOffsetY + root.liveDockOffsetY) : 0
            anchors.topMargin: root.liveDockEdge === 1 ? Math.round((root.liveDockMargin * root.liveScaleFactor) + dockContainer.startupOffsetY + root.liveDockOffsetY) : 0
            anchors.leftMargin: root.liveDockEdge === 2 ? Math.round((root.liveDockMargin * root.liveScaleFactor) + root.liveDockOffsetX) : 0
            anchors.rightMargin: root.liveDockEdge === 3 ? Math.round((root.liveDockMargin * root.liveScaleFactor) - root.liveDockOffsetX) : 0
            transform: Translate {
                x: (root.liveDockEdge === 0 || root.liveDockEdge === 1) ? Math.round(root.liveDockOffsetX) : 0
                y: (root.liveDockEdge === 2 || root.liveDockEdge === 3) ? Math.round(root.liveDockOffsetY) : 0
            }

            property real waveExtraWidth: root.wavePeakDeltaPx * 3.15 * root.liveScaleFactor * root.liveWaveIntensity
            property real rawBgWidth: root.baseRowWidth + (30 * root.liveScaleFactor) + (waveExtraWidth * root.waveAmplitude)

            width:  Math.round(rawBgWidth / 2) * 2
            height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)

            color: root.liveBg3dStyle === 0
                   ? Qt.rgba(root.themeColors.dockR, root.themeColors.dockG, root.themeColors.dockB, root.liveBgOpacity)
                   : "transparent"
            radius: Math.round(root.liveDockRadius * root.liveScaleFactor)
            border.color: Qt.rgba(1, 1, 1, root.liveBorderGlow)
            border.width: Math.max(1, Math.round(root.liveBorderWidth))
            antialiasing: true
            clip: true

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
                var p = dockBg.mapToItem(dockContainer, 0, 0)
                taskBackend.setBlurRegion(
                    Math.round(p.x),
                    Math.round(p.y),
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
                anchors.fill: parent
                radius: parent.radius
                visible: root.liveBg3dStyle > 0
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: Qt.tint(
                            root.liveGradientColorA,
                            Qt.rgba(1, 1, 1, Math.max(0.0, root.liveGradientMix * (root.liveBg3dStyle === 2 ? 0.58 : 0.40))))
                    }
                    GradientStop {
                        position: 0.38
                        color: Qt.tint(root.liveGradientColorB, Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.12 : 0.06))
                    }
                    GradientStop {
                        position: 0.72
                        color: Qt.tint(root.liveGradientColorB, Qt.rgba(0, 0, 0, root.liveBg3dStyle === 2 ? 0.09 : 0.05))
                    }
                    GradientStop {
                        position: 1.0
                        color: Qt.tint(
                            root.liveGradientColorC,
                            Qt.rgba(0, 0, 0, Math.max(0.0, (root.liveBg3dStyle === 2 ? 0.40 : 0.28) - (root.liveGradientMix * 0.20))))
                    }
                }
                opacity: root.liveBgOpacity
                border.color: Qt.rgba(1, 1, 1, root.liveBorderGlow)
                border.width: Math.max(1, Math.round(root.liveBorderWidth))
            }

            // brilho superior de "vidro curvo" (uniforme, sem faixa branca central)
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 1
                height: Math.max(7, Math.round(parent.height * 0.28))
                radius: parent.radius
                visible: root.liveBg3dStyle > 0
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.19 : 0.16) }
                    GradientStop { position: 0.42; color: Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.065 : 0.05) }
                    GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                }

                // Vinheta horizontal para evitar "bloco branco" no miolo.
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.0) }
                        GradientStop { position: 0.22; color: Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.045 : 0.035) }
                        GradientStop { position: 0.50; color: Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.04 : 0.03) }
                        GradientStop { position: 0.78; color: Qt.rgba(1, 1, 1, root.liveBg3dStyle === 2 ? 0.045 : 0.035) }
                        GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.0) }
                    }
                }
            }

            // vinheta lateral para dar profundidade sem escurecer a base inteira
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                visible: root.liveBg3dStyle > 0
                antialiasing: true
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, root.liveShadowStrength * (root.liveBg3dStyle === 2 ? 0.30 : 0.24)) }
                    GradientStop { position: 0.18; color: Qt.rgba(0, 0, 0, 0.02) }
                    GradientStop { position: 0.82; color: Qt.rgba(0, 0, 0, 0.02) }
                    GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, root.liveShadowStrength * (root.liveBg3dStyle === 2 ? 0.30 : 0.24)) }
                }
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 1
                anchors.leftMargin: 15
                anchors.rightMargin: 15
                height: 1
                color: root.themeColors.dockTopLine
                visible: root.liveBg3dStyle === 0
                radius: parent.radius
                antialiasing: true
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.RightButton
                onClicked: {
                    settingsWin.show()
                    settingsWin.raise()
                    settingsWin.requestActivate()
                }
            }
        }

        // Sombra 3D externa (fora do clip da dock) para responder ao slider.
        Rectangle {
            anchors.horizontalCenter: dockBg.horizontalCenter
            anchors.top: dockBg.bottom
            anchors.topMargin: Math.round(3 * root.liveScaleFactor)
            width: Math.round(dockBg.width * 0.88)
            height: Math.max(8, Math.round(dockBg.height * 0.20))
            radius: height / 2
            visible: root.liveBg3dStyle > 0
            color: Qt.rgba(0, 0, 0, root.liveShadowStrength * (root.liveBg3dStyle === 2 ? 0.62 : 0.52))
            opacity: root.liveBg3dStyle === 2 ? 0.42 : 0.36
            z: -2
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
                    color: root.themeColors.divider
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
                    color: root.themeColors.divider
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
            visible: root.dockTipVisible && !root.dockContextMenuOpen
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
                color: root.themeColors.tipBg
                border.color: root.themeColors.tipBorder
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
                        color: root.themeColors.textPrimary
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
                        color: root.themeColors.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item {
            id: minimizeSuckOverlay
            anchors.fill: parent
            z: 210000

            ListModel {
                id: minimizeSuckModel
            }

            Repeater {
                model: minimizeSuckModel
                delegate: Item {
                    required property int uid
                    required property real startX
                    required property real startY
                    required property real destX
                    required property real destY
                    required property real size
                    required property int durationMs

                    x: startX - (size * 0.5)
                    y: startY - (size * 0.5)
                    width: size
                    height: size
                    opacity: 0.0
                    scale: 1.0

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width
                        height: parent.height
                        radius: width * 0.5
                        color: root.accentFocus
                        opacity: 0.85
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 1.9
                        height: parent.height * 0.44
                        radius: height * 0.5
                        color: root.accentIdle
                        opacity: 0.45
                        rotation: -90
                    }

                    ParallelAnimation {
                        running: true
                        NumberAnimation {
                            target: parent
                            property: "x"
                            to: destX - (size * 0.5)
                            duration: durationMs
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: parent
                            property: "y"
                            to: destY - (size * 0.5)
                            duration: durationMs
                            easing.type: Easing.InCubic
                        }
                        NumberAnimation {
                            target: parent
                            property: "scale"
                            to: 0.2
                            duration: durationMs
                            easing.type: Easing.InCubic
                        }
                        SequentialAnimation {
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                from: 0.0
                                to: 0.9
                                duration: Math.max(40, durationMs * 0.30)
                                easing.type: Easing.OutQuad
                            }
                            NumberAnimation {
                                target: parent
                                property: "opacity"
                                to: 0.0
                                duration: Math.max(90, durationMs * 0.70)
                                easing.type: Easing.InQuad
                            }
                        }
                        onFinished: root.removeMinimizeSuck(uid)
                    }
                }
            }
        }
    }

    DockIconContextMenu {
        id: iconContextMenu
        dock: root
    }

    DropArea {
        anchors.fill: dockContainer
        enabled: !root.dockContextMenuOpen
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
        sequences: [StandardKey.Preferences, root.liveOpenSettingsShortcut]
        onActivated: {
            settingsWin.show()
            settingsWin.raise()
            settingsWin.requestActivate()
        }
    }

    Shortcut {
        sequences: [root.liveToggleDockShortcut]
        onActivated: {
            root.visible = !root.visible
            if (root.visible) {
                root.raise()
                root.requestActivate()
            }
        }
    }
}
