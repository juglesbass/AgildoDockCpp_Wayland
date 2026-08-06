import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Window
import org.kde.kirigami as Kirigami
import org.kde.taskmanager as TaskManager
import QtCore

Window {
    id: root

    // Accessible: só em tipos derivados de Item — ver dockContainer.

    // Métricas nomeadas (geometria da onda e da barra)
    readonly property real dockWaveRadiusStrideFactor: liveWaveRadiusFactor
    readonly property real dockBarHeightPx: liveDockThickness
    readonly property real dockRevealBandPx: 36

    property real liveScaleFactor: 1.0
    property real liveIconSpacing: 10.0
    property real liveDockMargin: 5.0
    property real liveBgOpacity: 0.66
    property real liveMinIconSize: 45.0
    property real liveMaxIconSize: 75.0
    // Zoom máximo em % acima do ícone base (teto 100% = no máximo o dobro do mínimo)
    readonly property real maxIconZoomPercentCap: 100.0
    readonly property real liveMaxIconZoomPercent: liveMinIconSize > 0
    ? Math.max(0, Math.min(maxIconZoomPercentCap, ((liveMaxIconSize / liveMinIconSize) - 1.0) * 100.0))
    : 0

    function clampMaxIconSizeForZoomCap() {
        var lo = liveMinIconSize
        var hi = lo * (1.0 + maxIconZoomPercentCap / 100.0)
        liveMaxIconSize = Math.max(lo, Math.min(liveMaxIconSize, hi))
    }

    function setLiveMaxIconZoomPercent(pct) {
        var p = Math.max(0, Math.min(maxIconZoomPercentCap, pct))
        liveMaxIconSize = liveMinIconSize * (1.0 + p / 100.0)
    }

    onLiveMinIconSizeChanged: clampMaxIconSizeForZoomCap()
    property int liveThemeMode: 0 // 0 Escuro, 1 Claro, 2 Noite Azul, 3 Ametista
    property int liveAccentMode: 0 // 0 Ciano, 1 Roxo, 2 Verde, 3 Laranja, 4 Rosa
    property real liveWaveIntensity: 1.0 // 0.6..1.0 (máx. 100%)
    property real liveDockRadius: 22.0 // px base antes da escala
    property real liveDockThickness: 68.0
    property bool liveMonochromeIcons: false
    property int liveIndicatorStyle: 0 // 0 ponto, 1 linha, 2 barra, 3 sublinhado, 4 pulso
    property real liveIndicatorScale: 1.0
    property int liveBg3dStyle: 3 // 0 padrão, 3 vidro (1/2 legado migrado para 3)

    function normalizeBg3dStyle(style) {
        if (style === 1 || style === 2)
            return 3
            return style === 0 ? 0 : 3
    }
    property string liveGradientColorA: "#111111"
    property string liveGradientColorB: "#191D22"
    property string liveGradientColorC: "#1E1E1E"
    property real liveGradientMix: 0.65
    // liveGradientAngle removido — propriedade sem efeito visual (gradiente é sempre vertical)
    property real liveBorderWidth: 1.0
    property real liveBorderGlow: 0.24
    property real liveShadowStrength: 0.30
    property int liveAnimationProfile: 0 // 0 suave, 1 rapido, 2 elastico, 3 sem animacao
    property real liveWaveRadiusFactor: 3.15
    property real liveWaveFalloff: 1.0
    property int liveWaveInertia: 1 // 0: Rápida/macOS, 1: Suave (Padrão), 2: Amanteigada
    property real liveLaunchBounceIntensity: 1.0
    property bool liveAutoThemeByActiveApp: false
    property bool liveDockEditMode: false
    property int liveDockEdge: 0 // 0 baixo, 1 topo, 2 esquerda, 3 direita
    readonly property bool dockLayoutVertical: liveDockEdge === 2 || liveDockEdge === 3
    property real liveDockOffsetX: 0
    property real liveDockOffsetY: 0
    property int liveLeftClickAction: 0 // 0 padrao, 1 menu, 2 nova janela
    property int liveMiddleClickAction: 2 // 0 padrao, 1 fechar, 2 nova janela, 3 minimizar
    property int liveRightClickAction: 1 // 0 padrao, 1 menu
    property string liveToggleDockShortcut: "Ctrl+Alt+D"
    property string liveOpenSettingsShortcut: "Meta+D"
    property int liveScrollWheelAction: 0
    property int liveDownloadProgressDisplayMode: 2 // 0 navegador, 1 pasta, 2 macOS (ícone do arquivo)
    property bool liveScheduleThemeEnabled: false
    property int liveDayThemeMode: 1
    property int liveNightThemeMode: 0
    property int liveNightStartHour: 18
    property int liveDayStartHour: 7
    property string liveProfilesJson: "{}"
    property string liveWidgetsJson: "[]"
    property string livePresetName: "Dark Glass"
    property var customizationUndoStack: []
    property var customizationRedoStack: []

    // ── Propriedades de tema derivadas de DockTheme (singleton) ──
    readonly property var themeColors: DockTheme.themePalette(liveThemeMode)
    readonly property var accentColors: DockTheme.accentPalette(liveAccentMode)
    readonly property color accentFocus: accentColors.focus
    readonly property color accentIdle: accentColors.idle
    readonly property color accentGlow: accentFocus
    readonly property color themeTextPrimary: themeColors.textPrimary
    readonly property color themeTextSecondary: themeColors.textSecondary
    readonly property color themeDivider: themeColors.divider
    readonly property color themeMenuBg: themeColors.menuBg
    readonly property color themeMenuBorder: themeColors.menuBorder
    readonly property color themeMenuHover: themeColors.menuHover
    readonly property color themeTipBg: themeColors.tipBg
    readonly property color themeTipBorder: themeColors.tipBorder
    readonly property color themeDockBorder: themeColors.dockBorder
    readonly property color themeDockTopLine: themeColors.dockTopLine

    function animationDuration(baseMs) {
        return DockTheme.animationDuration(baseMs, liveAnimationProfile)
    }

    function applyThemeForCommand(cmd) {
        if (!liveAutoThemeByActiveApp) return
        var rule = appRuleForCommand(cmd)
        if (rule && rule.themeMode !== undefined) {
            liveThemeMode = rule.themeMode
        }
        if (rule && rule.accentMode !== undefined) {
            liveAccentMode = rule.accentMode
        }
    }

    DockAppRules {
        id: appRules
        dockRoot: root
    }

    DockModelsStore {
        id: modelsStore
        dockRoot: root
    }

    DockPhysicsState {
        id: physicsState
        dockRoot: root
        globalHover: globalHover
        mainRow: dockContainer.mainRowRef
        mainColumn: dockContainer.mainColumnRef
    }

    readonly property alias dockBg: dockContainer.dockBgRef

    readonly property alias appRules: appRules
    property alias liveAppRulesJson: appRules.liveAppRulesJson
    property alias liveCustomCommandsJson: appRules.liveCustomCommandsJson

    readonly property alias modelsStore: modelsStore
    readonly property alias launcherModel: modelsStore.launcherModel
    readonly property alias appModel: modelsStore.appModel
    readonly property alias dynamicModel: modelsStore.dynamicModel
    readonly property alias systemModel: modelsStore.systemModel
    readonly property alias ghostClearTimer: modelsStore.ghostClearTimer

    readonly property alias physicsState: physicsState
    property alias dockMouseX: physicsState.dockMouseX
    property alias dockMouseY: physicsState.dockMouseY
    property alias logicalMouseX: physicsState.logicalMouseX
    property alias dockHovered: physicsState.dockHovered
    property alias waveAmplitude: physicsState.waveAmplitude
    property alias smoothedWaveRowWidth: physicsState.smoothedWaveRowWidth
    property alias dockRetracted: physicsState.dockRetracted
    property alias dockAutoHideLatched: physicsState.dockAutoHideLatched
    property alias waveBlurAnimating: physicsState.waveBlurAnimating
    property alias waveAmpAnim: physicsState.waveAmpAnim
    property alias autoHideDockTimer: physicsState.autoHideDockTimer
    property alias waveCollapseTimer: physicsState.waveCollapseTimer
    property alias isDraggingOverDock: physicsState.isDraggingOverDock

    function _processHoverPoint(px, py) { physicsState._processHoverPoint(px, py) }
    function applyDockRetractedState() { physicsState.applyDockRetractedState() }
    function restartAutoHideTimer() { physicsState.restartAutoHideTimer() }
    function dockRevealEdgeHovered() { return physicsState.dockRevealEdgeHovered() }

    function unpinApp(indexToRemove) { return modelsStore.unpinApp(indexToRemove) }
    function populatePinnedAppsFromJson(rawJson) { return modelsStore.populatePinnedAppsFromJson(rawJson) }
    function finalizeDynamicRemove(cmd) { return modelsStore.finalizeDynamicRemove(cmd) }
    function saveLastSeenDynamic() { return modelsStore.saveLastSeenDynamic() }
    function loadLastSeenDynamic() { return modelsStore.loadLastSeenDynamic() }
    function clearGhostApps() { return modelsStore.clearGhostApps() }
    function clearDynamicModel() { return modelsStore.clearDynamicModel() }
    function reloadCustomWidgets() { return modelsStore.reloadCustomWidgets() }
    function isCommandPinned(cmd) { return modelsStore.isCommandPinned(cmd) }
    function updateDynamicApps() { return modelsStore.updateDynamicApps() }
    function saveApps() { return modelsStore.saveApps() }
    function systemModelContainsCmd(cmd) { return modelsStore.systemModelContainsCmd(cmd) }
    function addPinnedAppFromDesktopUrl(urlStr) { return modelsStore.addPinnedAppFromDesktopUrl(urlStr) }
    function addWidgetShortcutFromDesktopUrlInfo(info) { return modelsStore.addWidgetShortcutFromDesktopUrlInfo(info) }
    function addWidgetShortcutFromDesktopUrl(urlStr) { return modelsStore.addWidgetShortcutFromDesktopUrl(urlStr) }
    function addPlasmoidFromDropInfo(info) { return modelsStore.addPlasmoidFromDropInfo(info) }
    function isItemInDock(info) { return modelsStore.isItemInDock(info) }
    function removeAppOrWidget(info) { return modelsStore.removeAppOrWidget(info) }

    function customCommandsFor(cmd) { return appRules.customCommandsFor(cmd) }
    function normalizeAppCommandKey(cmd) { return appRules.normalizeAppCommandKey(cmd) }
    function appRuleForCommand(cmd) { return appRules.appRuleForCommand(cmd) }
    function effectiveLeftClickAction(cmd) { return appRules.effectiveLeftClickAction(cmd) }
    function effectiveMiddleClickAction(cmd) { return appRules.effectiveMiddleClickAction(cmd) }
    function effectiveRightClickAction(cmd) { return appRules.effectiveRightClickAction(cmd) }
    function setAppClickRule(cmd, field, value) { return appRules.setAppClickRule(cmd, field, value) }
    function migrateAppRulesJson() { return appRules.migrateAppRulesJson() }

    function openSettingsGlobal() {
        settingsWin.show()
        settingsWin.raise()
        settingsWin.requestActivate()
    }

    function toggleDockGlobal() {
        root.visible = !root.visible
        if (root.visible) {
            root.raise()
            root.requestActivate()
        }
    }

    function syncGlobalShortcuts() {
        if (typeof globalShortcuts !== "undefined" && globalShortcuts) {
            globalShortcuts.setOpenSettingsShortcut(liveOpenSettingsShortcut)
            globalShortcuts.setToggleDockShortcut(liveToggleDockShortcut)
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
            liveMinIconSize = s.min; liveMaxIconSize = s.max
            clampMaxIconSizeForZoomCap()
            liveThemeMode = s.theme; liveAccentMode = s.accent
            liveWaveIntensity = s.wave; liveDockRadius = s.radius; liveBg3dStyle = normalizeBg3dStyle(s.bgStyle)
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
            liveThemeMode = 0; liveAccentMode = 0; liveBg3dStyle = 3
            liveBgOpacity = 0.42
            liveGradientColorA = "#14161A"; liveGradientColorB = "#1A1D22"; liveGradientColorC = "#121418"
            liveGradientMix = 0.35; liveBorderGlow = 0.24; liveShadowStrength = 0.34
            liveMonochromeIcons = false; liveIndicatorStyle = 0
        } else if (presetName === "Light Glass") {
            liveThemeMode = 1; liveAccentMode = 2; liveBg3dStyle = 3
            liveBgOpacity = 0.36
            liveGradientColorA = "#EEF1F6"; liveGradientColorB = "#E4E9F0"; liveGradientColorC = "#F8FAFC"
            liveGradientMix = 0.30; liveBorderGlow = 0.28; liveShadowStrength = 0.18
            liveMonochromeIcons = false; liveIndicatorStyle = 1
        } else if (presetName === "Liquid Glass") {
            liveThemeMode = 0; liveAccentMode = 0; liveBg3dStyle = 3
            liveBgOpacity = 0.20
            liveGradientColorA = "#20FFFFFF"
            liveGradientColorB = "#08FFFFFF"
            liveGradientColorC = "#12000000"
            liveGradientMix = 0.10; liveBorderGlow = 0.20; liveShadowStrength = 0.25
            liveMonochromeIcons = false; liveIndicatorStyle = 4
        } else if (presetName === "Neon") {
            liveThemeMode = 2; liveAccentMode = 0; liveBg3dStyle = 3
            liveBgOpacity = 0.40
            liveGradientColorA = "#0A1424"; liveGradientColorB = "#101C32"; liveGradientColorC = "#081018"
            liveGradientMix = 0.38; liveBorderGlow = 0.30; liveShadowStrength = 0.45
            liveMonochromeIcons = true; liveIndicatorStyle = 4
        } else if (presetName === "Minimal") {
            liveThemeMode = 0; liveAccentMode = 1; liveBg3dStyle = 0
            liveGradientColorA = "#171717"; liveGradientColorB = "#171717"; liveGradientColorC = "#171717"
            liveBorderGlow = 0.07; liveShadowStrength = 0.18; liveMonochromeIcons = true; liveIndicatorStyle = 3
        }
        updateZone()
        dockBg.syncBlurAfterStyleChange()
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
    property bool liveBehaviorWindowOverviewOnRefocus: true
    property bool liveBehaviorShowUnpinnedApps: true
    property bool liveBehaviorRememberRecentApps: false
    property int liveBehaviorAutoHideDelayMs: 900

    onLiveBehaviorKeepAppsFocusedChanged: applyLayerShellFromSettings()
    onLiveBehaviorDodgeWindowsChanged: applyDockRetractedState()
    onLiveBehaviorAutoHideChanged: {
        restartAutoHideTimer()
        applyDockRetractedState()
    }
    onLiveBehaviorAutoHideDelayMsChanged: restartAutoHideTimer()

    property bool dockContextMenuOpen: false

    onDockRetractedChanged: {
    }

    onLiveDockEditModeChanged: {
        // Legado: preferência antiga; reordenação é sempre por arrasto (estilo macOS).
        if (liveDockEditMode) {
            liveDockEditMode = false
            dockSettings.dockEditMode = false
        }
    }

    function showIconContextMenu(anchorItem, data) {
        iconContextMenu.openForIcon(anchorItem, data)
    }

    function showDockSurfaceContextMenu(anchorItem, globalX, globalY) {
        iconContextMenu.openForSurface(anchorItem, globalX, globalY)
    }

    function setDockEdge(edge) {
        liveDockEdge = 0
        dockSettings.dockEdge = 0
        if (typeof dockSettings.sync === "function")
            dockSettings.sync()
        updateZone()
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
        if (settingsWin.visible || root.isAppMenuOpen) {
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
        }
        updateZone()
    }
    onLiveDockMarginChanged: updateZone()
    onLiveDockThicknessChanged: {
        updateZone()
        dockBg.invalidateBlurGeometry()
    }

    onLiveMaxIconSizeChanged: {
        updateZone()
        dockBg.invalidateBlurGeometry()
    }
    onLiveWaveIntensityChanged: dockBg.invalidateBlurGeometry()
    onLiveWaveRadiusFactorChanged: dockBg.invalidateBlurGeometry()
    onLiveBg3dStyleChanged: Qt.callLater(function() { dockBg.syncBlurAfterStyleChange() })

    // --- MAPA MATEMÁTICO BÁSICO ---
    property real baseMinSize: root.liveMinIconSize * root.liveScaleFactor

    property real baseSpacing: root.liveIconSpacing * root.liveScaleFactor
    property real baseItemWidth: baseMinSize + (DockConstants.baseItemPaddingPx * root.liveScaleFactor)
    property real baseStride: baseItemWidth + baseSpacing

    property real dividerWidth: baseStride * DockConstants.dividerWidthRatio
    property int div1Count: dynamicModel.count > 0 ? 1 : 0
    property int div2Count: systemModel.count > 0 ? 1 : 0
    property real dividersWidth: (div1Count + div2Count) * dividerWidth

    property int totalItemsCount: modelsStore.totalItemsCount
    property real baseRowWidth: (totalItemsCount * baseItemWidth) + (Math.max(0, totalItemsCount - 1) * baseSpacing) + dividersWidth

    readonly property alias mainRowRef: dockContainer.mainRowRef
    readonly property alias mainColumnRef: dockContainer.mainColumnRef



    readonly property int maxWinWidth: root.screen ? root.screen.width : DockConstants.fallbackScreenWidthPx
    readonly property int maxWinHeight: root.screen ? root.screen.height : DockConstants.fallbackScreenHeightPx

    readonly property real wavePeakDeltaPx: Math.max(0, root.liveMaxIconSize - root.liveMinIconSize)
    property real maxIconsExpansion: root.wavePeakDeltaPx * DockConstants.waveExpansionMultiplier * root.liveScaleFactor * 1.0

    readonly property real dockIconTopOverflowPx: Math.max(
        0,
        (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor)
        - (root.dockBarHeightPx * root.liveScaleFactor)
        + (DockConstants.dockTopOverflowOffsetPx * root.liveScaleFactor)
    )

    readonly property real dockVerticalMotionSlopPx: DockConstants.motionSlopBufferPx * root.liveScaleFactor

    // Matemática global blindada contra retornos `undefined` durante animações
    property real dividerExtraHitArea: Math.max(0, (Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor * root.waveAmplitude) - Math.round(root.dockBarHeightPx * root.liveScaleFactor) + (DockConstants.dockTopOverflowOffsetPx * root.liveScaleFactor))

    // Janela Layer Shell: só o necessário para a onda (antes safePadding somava ~160–380px à toa)
    readonly property real winEdgeSlopPx: Math.max(
        DockConstants.minWinEdgeSlopPx * root.liveScaleFactor,
        root.wavePeakDeltaPx * root.liveScaleFactor * DockConstants.wavePeakSlopMultiplier,
        root.baseStride * DockConstants.strideSlopRatio
    )

    property real rawWinWidth: baseRowWidth + maxIconsExpansion + (winEdgeSlopPx * 2)
    width: dockLayoutVertical
    ? Math.min(maxWinWidth, Math.max(DockConstants.minVerticalDockWidthPx, Math.round((dockBarHeightPx + liveDockMargin * 2) * liveScaleFactor + dockIconTopOverflowPx + DockConstants.verticalDockWidthPaddingPx)))
    : Math.min(maxWinWidth, Math.max(DockConstants.minDockWindowDimensionPx, Math.round(rawWinWidth / 2) * 2))

    readonly property real dockExpandedHeight: Math.round(
        (root.liveDockMargin + root.dockBarHeightPx) * root.liveScaleFactor
        + root.dockIconTopOverflowPx
        + root.dockVerticalMotionSlopPx
    )

    readonly property real dockPeekHeight: Math.round(Math.max(root.dockRevealBandPx, DockConstants.minDockPeekHeightPx) * root.liveScaleFactor)

    // Deslocamento visual ao recolher (Translate no dockContainer);
    readonly property real dockRetractSlidePixels: Math.max(0, root.dockExpandedHeight - root.dockPeekHeight)

    height: dockLayoutVertical
    ? Math.min(maxWinHeight, Math.max(DockConstants.minDockWindowDimensionPx, Math.round(rawWinWidth / 2) * 2))
    : (root.dockRetracted ? root.dockPeekHeight : root.dockExpandedHeight)

    onHeightChanged: {
        pointerMaskDebouncer.restart()
    }
    onWidthChanged: {
        pointerMaskDebouncer.restart()
    }

    Behavior on height {
        enabled: !settingsWin.visible
        NumberAnimation {
            duration: DockConstants.dockHeightAnimDurationMs
            easing.type: Easing.OutCubic
        }
    }

    color: "transparent"
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint

    Component.onDestruction: {
        console.log(qsTr("Doca a fechar; a gravar a lista de aplicações."))
        saveApps()
        if (root.liveBehaviorRememberRecentApps)
            saveLastSeenDynamic()
    }

    onLiveBehaviorShowUnpinnedAppsChanged: {
        if (!liveBehaviorShowUnpinnedApps) {
            ghostClearTimer.stop()
            clearDynamicModel()
        } else {
            updateDynamicApps()
        }
        updateZone()
    }

    onLiveBehaviorRememberRecentAppsChanged: {
        if (!liveBehaviorRememberRecentApps) {
            ghostClearTimer.stop()
            clearGhostApps()
            taskBackend.writeUserJsonFile("last_seen_dynamic.json", "[]")
        }
    }

    HoverHandler {
        id: globalHover
        property bool updatePending: false

        onPointChanged: {
            if (updatePending) return
            updatePending = true
            Qt.callLater(function() {
                updatePending = false
                root._processHoverPoint(globalHover.point.position.x, globalHover.point.position.y)
            })
        }
    }



    onLiveDockEdgeChanged: taskBackend.applyLayerShellEdge(root.liveDockEdge)
    onLiveDownloadProgressDisplayModeChanged: taskBackend.setDownloadProgressDisplayMode(root.liveDownloadProgressDisplayMode)

    function applyLayerShellFromSettings() {
        var mode = root.liveBehaviorKeepAppsFocused ? 0 : 2
        taskBackend.applyLayerShellKeyboardMode(mode)
        taskBackend.setLayerShellActivateOnShow(!root.liveBehaviorKeepAppsFocused)
        taskBackend.applyLayerShellEdge(root.liveDockEdge)
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
        property real dockThickness: 68.0
        property bool monochromeIcons: false
        property int indicatorStyle: 0
        property real indicatorScale: 1.0
        property int bg3dStyle: 3
        property string gradientColorA: "#111111"
        property string gradientColorB: "#191D22"
        property string gradientColorC: "#1E1E1E"
        property real gradientMix: 0.65
        property real borderWidth: 1.0
        property real borderGlow: 0.24
        property real shadowStrength: 0.30
        property int animationProfile: 0
        property real waveRadiusFactor: 3.15
        property real waveFalloff: 1.0
        property int waveInertia: 1
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
        property string openSettingsShortcut: "Meta+D"
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
        property bool behaviorWindowOverviewOnRefocus: true
        property bool behaviorShowUnpinnedApps: true
        property bool behaviorRememberRecentApps: false
        property int behaviorAutoHideDelayMs: 900
        property int scrollWheelAction: 0
        property int downloadProgressDisplayMode: 2
    }

    property alias appSettings: dockSettings

    Timer {
        id: zoneDebouncer
        interval: DockConstants.zoneUpdateDebounceMs
        repeat: false
        onTriggered: {
            var espacoTotal = 0
            if (!root.dockRetracted) {
                var isVertical = (root.liveDockEdge === 2 || root.liveDockEdge === 3)
                if (isVertical) {
                    // Zona exclusiva lateral = largura da barra + margem
                    espacoTotal = (dockBg.width + root.liveDockMargin * root.liveScaleFactor)
                } else {
                    // Zona exclusiva superior/inferior = altura da barra + margem
                    espacoTotal = ((root.dockBarHeightPx + root.liveDockMargin) * root.liveScaleFactor)
                }
            }
            taskBackend.updateExclusiveZone(Math.round(espacoTotal))
        }
    }

    Timer {
        id: pointerMaskDebouncer
        interval: DockConstants.pointerMaskDebounceMs
        repeat: false
        onTriggered: {
            if (root.dockRetracted) {
                taskBackend.setPointerInputExcludeTop(0)
                return
            }
            var ex = Math.round(root.dockVerticalMotionSlopPx)
            if (ex <= 0 || root.height < ex + DockConstants.pointerMaskMinMarginPx) {
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

    function refreshDockBlur() {
        dockBg.syncBlurAfterStyleChange()
    }

    function showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData) {
        dockContainer.showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData)
    }

    function hideDockIconTip() {
        dockContainer.hideDockIconTip()
    }

    function playMinimizeSuckAt(iconItem) {
        dockContainer.playMinimizeSuckAt(iconItem)
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
        root.clampMaxIconSizeForZoomCap()
        root.liveThemeMode    = dockSettings.themeMode
        root.liveAccentMode   = dockSettings.accentMode
        root.liveWaveIntensity = Math.max(0.6, Math.min(1.0, dockSettings.waveIntensity))
        root.liveDockRadius   = Math.max(8, Math.min(40, dockSettings.dockRadius !== undefined ? dockSettings.dockRadius : 22.0))
        root.liveDockThickness = Math.max(4, Math.min(120, dockSettings.dockThickness !== undefined && !isNaN(dockSettings.dockThickness) ? dockSettings.dockThickness : 68.0))
        root.liveMonochromeIcons = dockSettings.monochromeIcons
        root.liveIndicatorStyle = dockSettings.indicatorStyle
        root.liveIndicatorScale = dockSettings.indicatorScale
        root.liveBg3dStyle = root.normalizeBg3dStyle(dockSettings.bg3dStyle)
        root.liveGradientColorA = dockSettings.gradientColorA
        root.liveGradientColorB = dockSettings.gradientColorB
        root.liveGradientColorC = dockSettings.gradientColorC
        root.liveGradientMix = dockSettings.gradientMix
        // gradientAngle: propriedade removida — sem efeito visual
        root.liveBorderWidth = dockSettings.borderWidth
        root.liveBorderGlow = dockSettings.borderGlow
        root.liveShadowStrength = dockSettings.shadowStrength
        root.liveAnimationProfile = dockSettings.animationProfile
        root.liveWaveRadiusFactor = dockSettings.waveRadiusFactor
        root.liveWaveFalloff = dockSettings.waveFalloff
        root.liveWaveInertia = dockSettings.waveInertia !== undefined ? dockSettings.waveInertia : 1
        root.liveLaunchBounceIntensity = dockSettings.launchBounceIntensity
        root.liveAutoThemeByActiveApp = dockSettings.autoThemeByActiveApp
        root.liveDockEditMode = dockSettings.dockEditMode
        root.liveDockEdge = 0
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
        migrateAppRulesJson()
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
        root.liveBehaviorWindowOverviewOnRefocus = dockSettings.behaviorWindowOverviewOnRefocus
        root.liveBehaviorShowUnpinnedApps = dockSettings.behaviorShowUnpinnedApps
        root.liveBehaviorRememberRecentApps = dockSettings.behaviorRememberRecentApps
        root.liveBehaviorAutoHideDelayMs = dockSettings.behaviorAutoHideDelayMs
        root.liveScrollWheelAction = dockSettings.scrollWheelAction
        root.liveDownloadProgressDisplayMode = dockSettings.downloadProgressDisplayMode
        taskBackend.windowOverviewOnRefocus = root.liveBehaviorWindowOverviewOnRefocus
        taskBackend.setDownloadProgressDisplayMode(root.liveDownloadProgressDisplayMode)
        syncGlobalShortcuts()

        applyScheduledThemeByClock()
        updateZone()
        let savedData = dockSettings.dockApps
        let success = populatePinnedAppsFromJson(savedData)
        if (!success || appModel.count === 0) {
            const recovered = taskBackend.loadDockAppsSnapshot()
            if (recovered !== "" && populatePinnedAppsFromJson(recovered) && appModel.count > 0) {
                dockSettings.dockApps = recovered
                if (typeof dockSettings.sync === "function") dockSettings.sync()
                console.warn(qsTr("Configuração recuperada do backup local de segurança."))
            }
        }

        if (appModel.count === 0) {
            appModel.append({name: qsTr("Terminal"), icon: "konsole", cmd: "konsole"})
            appModel.append({name: qsTr("Ficheiros"), icon: "system-file-manager", cmd: "dolphin"})
            appModel.append({name: qsTr("Steam"), icon: "steam", cmd: "steam"})
            saveApps()
        } else {
            taskBackend.saveDockAppsSnapshot(dockSettings.dockApps)
        }

        systemModel.clear()
        systemModel.append({name: qsTr("Transferências"), icon: "folder-downloads", cmd: "dolphin ~/Downloads", isSystem: true})
        systemModel.append({name: qsTr("Reciclagem"), icon: "user-trash", cmd: "dolphin trash:/", isSystem: true})
        reloadCustomWidgets()
        if (root.liveBehaviorRememberRecentApps) {
            loadLastSeenDynamic()
            ghostClearTimer.start()
        }
        if (root.liveBehaviorShowUnpinnedApps)
            updateDynamicApps()
    }



    DockContainer {
        id: dockContainer
        dockRoot: root
    }

    DockIconContextMenu {
        id: iconContextMenu
        dock: root
    }

    DockAppMenuWindow {
        id: appMenuWindow
        dock: root
    }

    DockWidgetPickerWindow {
        id: widgetPickerWindow
        dock: root
    }

    function openWidgetPickerGlobal() {
        widgetPickerWindow.openPicker()
    }

    readonly property bool isWidgetPickerOpen: widgetPickerWindow && widgetPickerWindow.visible

    readonly property bool isAppMenuOpen: appMenuWindow && (appMenuWindow.visible || appMenuWindow.menuOpen)

    onIsAppMenuOpenChanged: {
        if (isAppMenuOpen) {
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
            root.dockRetracted = false
            root.updateZone()
        } else {
            root.applyDockRetractedState()
        }
    }

    function toggleAppMenu(anchorItem, globalX, globalY) {
        if (appMenuWindow.visible && appMenuWindow.menuOpen) {
            appMenuWindow.closeMenu()
        } else {
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
            root.dockRetracted = false
            root.updateZone()
            appMenuWindow.openMenu(anchorItem, globalX, globalY)
        }
    }



    DropArea {
        id: edgeDragDropArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(DockConstants.minEdgeDropAreaHeightPx, root.dockExpandedHeight)
        z: DockConstants.zDropAreaLayer
        enabled: root.dockRetracted && !root.dockContextMenuOpen
        onContainsDragChanged: {
            if (containsDrag) {
                root.dockRetracted = false
                root.dockAutoHideLatched = false
                root.applyDockRetractedState()
            }
        }
        onEntered: {
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            root.applyDockRetractedState()
        }
    }

    DropArea {
        id: mainDropArea
        anchors.fill: dockContainer
        z: DockConstants.zDropAreaLayer
        enabled: !root.dockContextMenuOpen
        keys: ["text/uri-list", "text/plain", "application/x-desktop", "text/x-plasmoidservicename", "text/x-plasma-widget", "appItemDrag"]

        onEntered: function(drag) {
            if (drag.keys && drag.keys.indexOf("appItemDrag") >= 0) return
            drag.acceptProposedAction()
            root.dockRetracted = false
            root.dockAutoHideLatched = false
            root.applyDockRetractedState()
            
            root.isDraggingOverDock = true
            root.dockMouseX = drag.x
            root.dockMouseY = drag.y
            if (!root.dockLayoutVertical) {
                root.logicalMouseX = drag.x - mainRow.x
            } else {
                root.logicalMouseY = drag.y - mainColumn.y
            }
        }

        onPositionChanged: function(drag) {
            if (drag.keys && drag.keys.indexOf("appItemDrag") >= 0) return
            drag.acceptProposedAction()
            root.dockMouseX = drag.x
            root.dockMouseY = drag.y
            if (!root.dockLayoutVertical) {
                root.logicalMouseX = drag.x - mainRow.x
            } else {
                root.logicalMouseY = drag.y - mainColumn.y
            }
        }

        onExited: {
            root.isDraggingOverDock = false
        }

        onContainsDragChanged: {
            if (containsDrag) {
                root.dockRetracted = false
                root.dockAutoHideLatched = false
                root.applyDockRetractedState()
            } else {
                root.isDraggingOverDock = false
            }
        }
        onDropped: function(drop) {
            root.isDraggingOverDock = false
            drop.acceptProposedAction()
            var plasmoidId = ""
            var hasPlasmoidFormat = drop.keys ? drop.keys.indexOf("text/x-plasmoidservicename") >= 0 : false
            var hasWidgetFormat = drop.keys ? drop.keys.indexOf("text/x-plasma-widget") >= 0 : false
            var hasDesktopFormat = drop.keys ? drop.keys.indexOf("application/x-desktop") >= 0 : false

            if (hasPlasmoidFormat) {
                plasmoidId = String(drop.getDataAsString("text/x-plasmoidservicename")).trim()
            } else if (hasWidgetFormat) {
                plasmoidId = String(drop.getDataAsString("text/x-plasma-widget")).trim()
            }

            if (!plasmoidId && drop.hasText) {
                var txt = String(drop.text).trim()
                if (txt.indexOf("org.kde.plasma.") >= 0) {
                    plasmoidId = txt
                }
            }

            if (plasmoidId) {
                let info = taskBackend.parsePlasmoidDropInfo(plasmoidId)
                if (info && info.name) {
                    root.addPlasmoidFromDropInfo(info)
                    return
                }
            }

            if (hasDesktopFormat) {
                var desktopPath = String(drop.getDataAsString("application/x-desktop")).trim()
                if (desktopPath) {
                    root.addPinnedAppFromDesktopUrl(desktopPath)
                    return
                }
            }

            if (drop.hasUrls && drop.urls.length > 0) {
                for (var i = 0; i < drop.urls.length; i++) {
                    var urlStr = drop.urls[i].toString()
                    
                    if (urlStr.indexOf("org.kde.plasma.") >= 0 || urlStr.indexOf("/plasma/plasmoids/") >= 0) {
                        let info = taskBackend.parsePlasmoidDropInfo(urlStr)
                        if (info && info.name) {
                            root.addPlasmoidFromDropInfo(info)
                            continue
                        }
                    }
                    
                    root.addPinnedAppFromDesktopUrl(urlStr)
                }
                return
            }

            if (drop.hasText && drop.text) {
                var textLines = String(drop.text).split("\n")
                for (var j = 0; j < textLines.length; j++) {
                    var line = textLines[j].trim()
                    if (line.length > 0) {
                        root.addPinnedAppFromDesktopUrl(line)
                    }
                }
            }
        }
    }

    FileDialog {
        id: pinnedAppPicker
        title: qsTr("Escolher aplicativo para fixar na doca")
        nameFilters: [
            qsTr("Atalhos de aplicação (*.desktop)"),
            qsTr("Todos os ficheiros (*)")
        ]
        fileMode: FileDialog.OpenFile
        onAccepted: root.addPinnedAppFromDesktopUrl(selectedFile.toString())
    }

    FileDialog {
        id: systemShortcutPicker
        title: qsTr("Escolher atalho do sistema")
        nameFilters: [
            qsTr("Atalhos de aplicação (*.desktop)"),
            qsTr("Todos os ficheiros (*)")
        ]
        fileMode: FileDialog.OpenFile
        onAccepted: root.addWidgetShortcutFromDesktopUrl(selectedFile.toString())
    }

    function openPinnedAppPicker() {
        pinnedAppPicker.open()
    }

    function openSystemShortcutPicker() {
        systemShortcutPicker.open()
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

    Connections {
        target: widgetPickerWindow
        function onVisibleChanged() {
            if (widgetPickerWindow.visible) {
                root.dockAutoHideLatched = false
                autoHideDockTimer.stop()
                root.dockRetracted = false
                root.updateZone()
            } else {
                root.applyDockRetractedState()
            }
        }
    }

    Connections {
        target: appMenuWindow
        function onVisibleChanged() {
            if (root.isAppMenuOpen) {
                root.dockAutoHideLatched = false
                autoHideDockTimer.stop()
                root.dockRetracted = false
                root.updateZone()
            } else {
                root.applyDockRetractedState()
            }
        }
        function onMenuOpenChanged() {
            if (root.isAppMenuOpen) {
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
        onActivated: root.openSettingsGlobal()
    }

    onLiveOpenSettingsShortcutChanged: syncGlobalShortcuts()
    onLiveToggleDockShortcutChanged: syncGlobalShortcuts()

    Shortcut {
        sequences: [root.liveToggleDockShortcut]
        onActivated: root.toggleDockGlobal()
    }
}
