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

    readonly property alias appRules: appRules
    property alias liveAppRulesJson: appRules.liveAppRulesJson
    property alias liveCustomCommandsJson: appRules.liveCustomCommandsJson

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

    property bool dockRetracted: false
    property bool dockAutoHideLatched: false
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

    function addPinnedAppFromDesktopUrl(urlStr) {
        const info = taskBackend.parseDropInfo(urlStr)
        if (!info.cmd) {
            return false
        }
        if (isCommandPinned(info.cmd)) {
            return false
        }
        appModel.append({
            name: info.name,
            icon: info.icon,
            cmd: info.cmd
        })
        saveApps()
        return true
    }

    function systemModelContainsCmd(cmd) {
        const norm = normalizeAppCommandKey(cmd)
        for (let i = 0; i < systemModel.count; i++) {
            const item = systemModel.get(i)
            if (!item || !item.cmd) {
                continue
            }
            if (item.cmd === cmd) {
                return true
            }
            if (norm.length > 0 && normalizeAppCommandKey(item.cmd) === norm) {
                return true
            }
        }
        return false
    }

    function addWidgetShortcutFromDesktopUrlInfo(info) {
        if (!info || !info.cmd) {
            return false
        }
        if (systemModelContainsCmd(info.cmd)) {
            return false
        }
        let arr = []
        try {
            arr = JSON.parse(liveWidgetsJson || "[]")
        } catch (e) {
            arr = []
        }
        if (!Array.isArray(arr)) {
            arr = []
        }
        arr.push({
            name: info.name,
            icon: info.icon || "applications-system",
            cmd: info.cmd
        })
        liveWidgetsJson = JSON.stringify(arr)
        dockSettings.userWidgetsJson = liveWidgetsJson
        if (typeof dockSettings.sync === "function") {
            dockSettings.sync()
        }
        taskBackend.writeUserJsonFile("widgets.json", liveWidgetsJson)
        reloadCustomWidgets()
        return true
    }

    function addWidgetShortcutFromDesktopUrl(urlStr) {
        const info = taskBackend.parseDropInfo(urlStr)
        return addWidgetShortcutFromDesktopUrlInfo(info)
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

    property int totalItemsCount: launcherModel.count + appModel.count + dynamicModel.count + systemModel.count
    property real baseRowWidth: (totalItemsCount * baseItemWidth) + (Math.max(0, totalItemsCount - 1) * baseSpacing) + dividersWidth

    readonly property alias mainRowRef: mainRow
    readonly property alias mainColumnRef: mainColumn

    property real smoothedWaveRowWidth: baseRowWidth
    onBaseRowWidthChanged: smoothedWaveRowWidth = baseRowWidth

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

    function _processHoverPoint(px, py) {
        if (px === undefined || py === undefined) return;

        root.dockMouseX = px
        root.dockMouseY = py

        var tw = root.dockLayoutVertical ? mainColumn.height : mainRow.width
        if (tw <= 0) {
            tw = root.baseRowWidth
        }

        var waveOn = root.waveAmplitude > DockConstants.waveAmplitudeCutoff
        var alpha = 1.0
        if (root.liveWaveInertia === 2) {
            alpha = waveOn ? DockConstants.waveInertiaButteryActiveAlpha : DockConstants.waveInertiaButteryIdleAlpha
        } else if (root.liveWaveInertia === 1) {
            alpha = waveOn ? DockConstants.waveInertiaSmoothActiveAlpha : DockConstants.waveInertiaSmoothIdleAlpha
        } else {
            alpha = 1.0
        }

        root.smoothedWaveRowWidth = Math.max(
            root.baseRowWidth,
            (root.smoothedWaveRowWidth * (1.0 - alpha)) + (tw * alpha)
        )

        var lxRaw = 0
        if (root.dockLayoutVertical) {
            var colTop = (root.height * 0.5) - (root.baseRowWidth * 0.5)
            lxRaw = root.dockMouseY - colTop
        } else {
            var rowLeft = (root.width * 0.5) - (root.baseRowWidth * 0.5)
            lxRaw = root.dockMouseX - rowLeft
        }
        lxRaw = Math.max(0, Math.min(root.baseRowWidth, lxRaw))

        var beta = 1.0
        if (root.liveWaveInertia === 0) {
            beta = 1.0  // 100% Instantânea 1:1 estilo macOS (0ms de atraso / resposta de hardware perfeita)
        } else if (root.liveWaveInertia === 2) {
            beta = waveOn ? DockConstants.waveInertiaButteryActiveAlpha : DockConstants.waveInertiaButteryIdleAlpha // Amanteigada / Fluida
        } else {
            beta = waveOn ? DockConstants.waveInertiaSmoothActiveAlpha : DockConstants.waveInertiaSmoothIdleAlpha // Suave (Padrão)
        }
        var lxOut = lxRaw
        if (root.logicalMouseX > DockConstants.mouseInitializedThreshold) {
            lxOut = root.logicalMouseX + (lxRaw - root.logicalMouseX) * beta
        }
        root.logicalMouseX = lxOut

        if (root.dockRetracted && root.dockRevealEdgeHovered()) {
            root.dockAutoHideLatched = false
            root.dockRetracted = false
            root.updateZone()
        }
    }

    property real dockMouseX: -1000
    property real dockMouseY: -1000
    property bool isDraggingOverDock: false
    property real logicalMouseX: -1000

    property bool dockHovered: {
        if (!globalHover.hovered && !isDraggingOverDock) return false
        if (root.dockRetracted) return false

        var maxIcon = Math.max(root.liveMinIconSize, root.liveMaxIconSize) * root.liveScaleFactor
        var waveExtra = root.wavePeakDeltaPx * DockConstants.waveHoverSpanFactor * root.liveScaleFactor * root.liveWaveIntensity
        var hoverSpan = root.baseRowWidth + (DockConstants.dockHoverPaddingPx * root.liveScaleFactor) + waveExtra

        if (root.dockLayoutVertical) {
            var safeHitX = root.liveDockEdge === 2
            ? (maxIcon + DockConstants.dockHoverMarginPx)
            : (root.width - (maxIcon + DockConstants.dockHoverMarginPx))
            var dockTop = (root.height / 2) - (hoverSpan / 2)
            var dockBottom = dockTop + hoverSpan
            if (root.liveDockEdge === 2) {
                return (dockMouseX < safeHitX) && (dockMouseY >= dockTop) && (dockMouseY <= dockBottom)
            }
            return (dockMouseX > safeHitX) && (dockMouseY >= dockTop) && (dockMouseY <= dockBottom)
        }

        var safeHitY = root.height - (maxIcon + DockConstants.dockHoverMarginPx)
        if (root.liveDockEdge === 1) {
            safeHitY = maxIcon + DockConstants.dockHoverMarginPx
        }
        var dockLeft = (root.width / 2) - (hoverSpan / 2)
        var dockRight = dockLeft + hoverSpan

        if (root.liveDockEdge === 1) {
            return (dockMouseY < safeHitY) && (dockMouseX >= dockLeft) && (dockMouseX <= dockRight)
        }
        return (dockMouseY > safeHitY) && (dockMouseX >= dockLeft) && (dockMouseX <= dockRight)
    }

    property real waveAmplitude: 0.0
    property bool waveCollapseArmed: false
    readonly property bool waveBlurAnimating:
    waveAmpAnim.running || waveCollapseTimer.running || waveCollapseArmed

    onWaveBlurAnimatingChanged: taskBackend.setDockWaveAnimating(waveBlurAnimating)

    Timer {
        id: waveCollapseTimer
        interval: DockConstants.waveCollapseIntervalMs
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
            if (settingsWin.visible || root.isAppMenuOpen || root.isWidgetPickerOpen || taskBackend.isPlasmaEditMode || mainDropArea.containsDrag) return
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
        if (settingsWin.visible || root.isAppMenuOpen || root.isWidgetPickerOpen || taskBackend.isPlasmaEditMode || mainDropArea.containsDrag) {
            autoHideDockTimer.stop()
            root.dockAutoHideLatched = false
            return
        }
        autoHideDockTimer.interval = Math.max(DockConstants.minAutoHideDelayMs, root.liveBehaviorAutoHideDelayMs)
        autoHideDockTimer.restart()
    }

    onLiveDockEdgeChanged: taskBackend.applyLayerShellEdge(root.liveDockEdge)
    onLiveDownloadProgressDisplayModeChanged: taskBackend.setDownloadProgressDisplayMode(root.liveDownloadProgressDisplayMode)

    function applyLayerShellFromSettings() {
        var mode = root.liveBehaviorKeepAppsFocused ? 0 : 2
        taskBackend.applyLayerShellKeyboardMode(mode)
        taskBackend.setLayerShellActivateOnShow(!root.liveBehaviorKeepAppsFocused)
        taskBackend.applyLayerShellEdge(root.liveDockEdge)
    }

    function dockRevealEdgeHovered() {
        if (!globalHover.hovered)
            return false
            var band = root.dockRevealBandPx
            switch (root.liveDockEdge) {
                case 1: return root.dockMouseY < band
                case 2: return root.dockMouseX < band
                case 3: return root.dockMouseX > root.width - band
                default: return root.dockMouseY > root.height - band
            }
    }

    function applyDockRetractedState() {
        if (settingsWin.visible || root.isAppMenuOpen || root.isWidgetPickerOpen || taskBackend.isPlasmaEditMode || mainDropArea.containsDrag) {
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
        var edgePeek = root.dockRevealEdgeHovered()
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
            id: waveAmpAnim
            duration: root.liveWaveInertia === 0 ? DockConstants.waveAmpFastDurationMs : (root.liveWaveInertia === 2 ? DockConstants.waveAmpButteryDurationMs : DockConstants.waveAmpSmoothDurationMs)
            easing.type: Easing.OutCubic
            onRunningChanged: {
                if (running)
                    root.waveCollapseArmed = false
                    else if (!root.dockHovered && root.waveAmplitude < DockConstants.waveAmplitudeCutoff)
                        root.waveCollapseArmed = false
            }
        }
    }

    onDockHoveredChanged: {
        if (dockHovered) {
            waveCollapseArmed = false
            waveCollapseTimer.stop()
            waveAmplitude = 1.0
            root.smoothedWaveRowWidth = root.baseRowWidth
            root.logicalMouseX = -1000
            root.dockAutoHideLatched = false
            autoHideDockTimer.stop()
            root.dockRetracted = false
            updateZone()
        } else {
            waveCollapseArmed = true
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

    property bool dockTipVisible: false
    property string dockTipName: ""
    property string dockTipStatus: ""
    property color dockTipStatusColor: "#00E5FF"
    property string dockTipHint: ""
    property real dockTipAnchorX: 0
    property real dockTipAnchorY: 0
    property var dockTipWindowData: null
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
        var startY = Math.max(0, dockBg.y - (DockConstants.minimizeSuckStartOffsetYPx * root.liveScaleFactor))
        var uid = ++root.minimizeSuckSerial
        // Rastro curto para simular "sugar/suck" ao minimizar.
        minimizeSuckModel.append({
            uid: uid,
            startX: center.x,
            startY: startY,
            destX: center.x,
            destY: center.y,
            size: Math.max(DockConstants.minMinimizeSuckSizePx, DockConstants.baseMinimizeSuckSizePx * root.liveScaleFactor),
            durationMs: DockConstants.minimizeSuckDurationMs
        })
    }

    function showDockIconTip(iconItem, name, statusLine, statusColor, hintLine, winData) {
        if (!iconItem) {
            return
        }
        var pTop = iconItem.mapToItem(dockContainer, iconItem.width * 0.5, 0)
        var pCenter = iconItem.mapToItem(dockContainer, iconItem.width * 0.5, iconItem.height * 0.5)
        root.dockTipAnchorX = pCenter.x
        root.dockTipAnchorY = pTop.y
        root.dockTipName = name !== undefined ? name : ""
        root.dockTipStatus = statusLine !== undefined ? statusLine : ""
        root.dockTipStatusColor = statusColor
        root.dockTipHint = hintLine !== undefined ? hintLine : ""
        root.dockTipWindowData = winData || null
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
            name: qsTr("Menu de Aplicativos")
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
            if (apps.length === 0) {
                return false
            }
            for (let i = 0; i < apps.length; i++) {
                if (apps[i] && apps[i].name && apps[i].cmd) {
                    appModel.append(apps[i])
                }
            }
            return appModel.count > 0
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

    // Salva apps dinâmicos reais para opcionalmente mostrar como ghost no próximo arranque.
    function saveLastSeenDynamic() {
        if (!root.liveBehaviorRememberRecentApps)
            return
            let apps = []
            for (let i = 0; i < dynamicModel.count; i++) {
                let e = dynamicModel.get(i)
                if (!e.isGhost) {
                    apps.push({ name: e.name, icon: e.icon, cmd: e.cmd })
                }
            }
            taskBackend.writeUserJsonFile("last_seen_dynamic.json", JSON.stringify(apps))
    }

    // Carrega ghosts do arranque anterior (só se o utilizador activou a opção).
    function loadLastSeenDynamic() {
        if (!root.liveBehaviorRememberRecentApps)
            return
            let raw = taskBackend.readUserJsonFile("last_seen_dynamic.json")
            if (!raw || raw === "") return
                let apps = []
                try { apps = JSON.parse(raw) } catch (e) { return }
                for (let i = 0; i < apps.length; i++) {
                    let a = apps[i]
                    if (!a.cmd || !a.name) continue
                        if (isCommandPinned(a.cmd)) continue
                            dynamicModel.append({ name: a.name, icon: a.icon || "", cmd: a.cmd,
                                isDynamic: true, removing: false, isGhost: true })
                }
    }

    // Remove todos os ghosts restantes (chamado por timer após arranque).
    function clearGhostApps() {
        for (let i = dynamicModel.count - 1; i >= 0; i--) {
            if (dynamicModel.get(i).isGhost === true) {
                dynamicModel.remove(i)
            }
        }
    }

    function clearDynamicModel() {
        for (let i = dynamicModel.count - 1; i >= 0; i--)
            dynamicModel.remove(i)
    }

    Timer {
        id: ghostClearTimer
        interval: 40000
        repeat: false
        running: false
        onTriggered: root.clearGhostApps()
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

    function isCommandPinned(cmd) {
        const norm = normalizeAppCommandKey(cmd)
        for (let i = 0; i < appModel.count; i++) {
            const pinned = appModel.get(i).cmd
            if (pinned === cmd) {
                return true
            }
            if (norm.length > 0 && normalizeAppCommandKey(pinned) === norm) {
                return true
            }
        }
        return false
    }

    function updateDynamicApps() {
        if (!root.liveBehaviorShowUnpinnedApps) {
            if (dynamicModel.count > 0)
                clearDynamicModel()
                return
        }

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
                    if (row.isGhost === true) continue  // ghost aguarda o timer de limpeza
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
                    // App ghost voltou — promove para app real
                    if (dynamicModel.get(i).isGhost === true) {
                        dynamicModel.setProperty(i, "isGhost", false)
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
                    removing: false,
                    isGhost: false
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
        function onPlasmaEditModeChanged() {
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
        interval: DockConstants.saveSettingsFlushDelayMs
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
        Accessible.description: {
            switch (root.liveDockEdge) {
                case 1: return qsTr("Dock de aplicações na margem superior do ecrã.")
                case 2: return qsTr("Dock de aplicações na margem esquerda do ecrã.")
                case 3: return qsTr("Dock de aplicações na margem direita do ecrã.")
                default: return qsTr("Dock de aplicações na margem inferior do ecrã.")
            }
        }

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
        Behavior on dockSlidePixels { enabled: !settingsWin.visible; NumberAnimation { duration: DockConstants.dockSlideAnimDurationMs; easing.type: Easing.OutBack; easing.overshoot: DockConstants.dockSlideEasingOvershoot } }
        transform: Translate {
            x: root.liveDockEdge === 2 ? -dockContainer.dockSlidePixels : (root.liveDockEdge === 3 ? dockContainer.dockSlidePixels : 0)
            y: root.liveDockEdge === 1 ? -dockContainer.dockSlidePixels : (root.liveDockEdge === 0 ? dockContainer.dockSlidePixels : 0)
        }

        onDockSlidePixelsChanged: dockBg.syncBlurAfterStyleChange()

        property real startupOffsetY: 0

        onStartupOffsetYChanged: {
            if (startupOffsetY < 0.5)
                dockBg.syncBlurAfterStyleChange()
        }

        Component.onCompleted: {
            startupOffsetY = DockConstants.startupOffsetYPx * root.liveScaleFactor
            startupAnim.start()
        }

        Timer {
            id: blurStartupSettleTimer
            interval: DockConstants.blurStartupSettleDelayMs
            repeat: false
            onTriggered: dockBg.syncBlurAfterStyleChange()
        }

        ParallelAnimation {
            id: startupAnim
            NumberAnimation {
                target: dockContainer
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: DockConstants.startupFadeDurationMs
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: dockContainer
                property: "startupOffsetY"
                to: 0
                duration: DockConstants.startupSlideDurationMs
                easing.type: Easing.OutBack
            }
            onFinished: {
                dockBg.syncBlurAfterStyleChange()
                blurStartupSettleTimer.restart()
            }
        }

        DockBlurBackground {
            id: dockBg
            dockRoot: root
            dockContainer: dockContainer
            waveAmpAnim: waveAmpAnim
            onSurfaceContextMenuRequested: (surface, globalX, globalY) =>
            root.showDockSurfaceContextMenu(surface, globalX, globalY)
        }

        Row {
            id: mainRow
            visible: !root.dockLayoutVertical
            anchors.horizontalCenter: dockBg.horizontalCenter
            anchors.bottom: root.liveDockEdge === 0 ? dockBg.bottom : undefined
            anchors.top: root.liveDockEdge === 1 ? dockBg.top : undefined

            height: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
            spacing: root.baseSpacing

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: DockConstants.iconAddScaleDurationMs; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: DockConstants.iconAddOpacityDurationMs }
            }

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
                    anchors.bottomMargin: -DockConstants.dividerHitBottomMarginPx

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

        Column {
            id: mainColumn
            visible: root.dockLayoutVertical
            anchors.verticalCenter: dockBg.verticalCenter
            anchors.left: root.liveDockEdge === 2 ? dockBg.left : undefined
            anchors.right: root.liveDockEdge === 3 ? dockBg.right : undefined
            width: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
            spacing: root.baseSpacing

            add: Transition {
                NumberAnimation { property: "scale"; from: 0; to: 1; duration: 300; easing.type: Easing.OutBack }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 200 }
            }

            Repeater {
                model: launcherModel
                delegate: DockIconDelegate { dock: root }
            }
            Repeater {
                model: appModel
                delegate: DockIconDelegate { dock: root }
            }

            Item {
                width: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
                height: root.dividerWidth
                visible: root.div1Count > 0
                Rectangle {
                    width: Math.round(root.dockBarHeightPx * root.liveScaleFactor) * 0.45
                    height: Math.max(2, Math.round(2 * root.liveScaleFactor))
                    color: root.themeColors.divider
                    anchors.centerIn: parent
                    radius: 1
                }
            }

            Repeater {
                model: dynamicModel
                delegate: DockIconDelegate { dock: root }
            }

            Item {
                width: Math.round(root.dockBarHeightPx * root.liveScaleFactor)
                height: root.dividerWidth
                visible: root.div2Count > 0
                Rectangle {
                    width: Math.round(root.dockBarHeightPx * root.liveScaleFactor) * 0.45
                    height: Math.max(2, Math.round(2 * root.liveScaleFactor))
                    color: root.themeColors.divider
                    anchors.centerIn: parent
                    radius: 1
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
            width: windowPreviewCard.visible ? windowPreviewCard.implicitWidth : globalTipBox.width
            height: windowPreviewCard.visible ? windowPreviewCard.implicitHeight : globalTipBox.height

            readonly property real marginGap: Math.round(10 * root.liveScaleFactor)

            x: {
                var edge = root.liveDockEdge
                if (edge === 2) {
                    return Math.round(dockBg.x + dockBg.width + marginGap)
                } else if (edge === 3) {
                    return Math.round(dockBg.x - width - marginGap)
                } else {
                    var targetX = root.dockTipAnchorX - (width * 0.5)
                    return Math.round(Math.max(8, Math.min(targetX, root.width - width - 8)))
                }
            }

            y: {
                var edge = root.liveDockEdge
                if (edge === 1) {
                    return Math.round(dockBg.y + dockBg.height + marginGap)
                } else if (edge === 2 || edge === 3) {
                    var targetY = root.dockTipAnchorY - (height * 0.5)
                    return Math.round(Math.max(8, Math.min(targetY, root.height - height - 8)))
                } else {
                    var iconTop = Math.min(dockBg.y, root.dockTipAnchorY)
                    return Math.round(iconTop - height - marginGap)
                }
            }

            DockWindowPreviewTooltip {
                id: windowPreviewCard
                dock: root
                windowData: root.dockTipWindowData
                visible: root.dockTipWindowData && root.dockTipWindowData.isRunning
            }

            Rectangle {
                id: globalTipBox
                visible: !windowPreviewCard.visible
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

    function addPlasmoidFromDropInfo(info) {
        if (!info || !info.name) return false
        if (info.isSeparator || info.cmd === "separator") {
            appModel.append({
                name: info.name || "Separador",
                icon: "draw-separator",
                cmd: "separator",
                isSeparator: true,
                isSystemItem: true
            })
            saveApps()
            return true
        }
        if (info.widgetPreset) {
            if (info.widgetPreset === "trash") {
                if (!systemModelContainsCmd("dolphin trash://")) {
                    systemModel.append({
                        name: "Lixeira",
                        icon: "user-trash",
                        cmd: "dolphin trash://",
                        isTrash: true,
                        isSystemItem: true
                    })
                    saveApps()
                    return true
                }
            } else if (info.widgetPreset === "clock") {
                return addWidgetShortcutFromDesktopUrlInfo({
                    name: "Relógio",
                    icon: "preferences-system-time",
                    cmd: "kcmshell6 kcm_clock"
                })
            } else if (info.widgetPreset === "volume") {
                return addWidgetShortcutFromDesktopUrlInfo({
                    name: "Volume",
                    icon: "audio-volume-high",
                    cmd: "kcmshell6 kcm_pulseaudio"
                })
            } else if (info.widgetPreset === "media") {
                return addWidgetShortcutFromDesktopUrlInfo({
                    name: "Player de Mídia",
                    icon: "media-playback-start",
                    cmd: "plasma-browser-integration"
                })
            }
        }
        if (info.cmd) {
            appModel.append({
                name: info.name,
                icon: info.icon || "application-x-executable",
                cmd: info.cmd,
                isSystemItem: info.isSystemItem || false
            })
            saveApps()
            return true
        }
        return false
    }

    function isItemInDock(info) {
        if (!info) return false
        const cmd = info.cmd || ""
        const name = info.name || ""
        const preset = info.widgetPreset || ""

        if (preset === "trash" || cmd === "dolphin trash://") {
            return systemModelContainsCmd("dolphin trash://")
        }

        for (let i = 0; i < systemModel.count; i++) {
            const item = systemModel.get(i)
            if (item && item.cmd === cmd) return true
        }

        for (let i = 0; i < appModel.count; i++) {
            const item = appModel.get(i)
            if (!item) continue
            if (cmd.length > 0 && item.cmd === cmd) return true
            if (name.length > 0 && item.name === name) return true
        }

        return false
    }

    function removeAppOrWidget(info) {
        if (!info) return false
        const cmd = info.cmd || ""
        const name = info.name || ""
        const preset = info.widgetPreset || ""

        let removed = false

        // 1. Clean from liveWidgetsJson / widgets.json / userWidgetsJson
        try {
            let arr = JSON.parse(liveWidgetsJson || "[]")
            if (Array.isArray(arr) && arr.length > 0) {
                let origLen = arr.length
                arr = arr.filter(function(w) {
                    if (!w) return false
                    if (cmd.length > 0 && w.cmd === cmd) return false
                    if (name.length > 0 && w.name === name) return false
                    if (preset === "clock" && w.cmd && w.cmd.indexOf("kcm_clock") >= 0) return false
                    if (preset === "volume" && w.cmd && w.cmd.indexOf("kcm_pulseaudio") >= 0) return false
                    if (preset === "media" && w.cmd && w.cmd.indexOf("plasma-browser-integration") >= 0) return false
                    if (preset === "trash" && w.cmd && w.cmd.indexOf("trash:/") >= 0) return false
                    return true
                })
                if (arr.length !== origLen) {
                    liveWidgetsJson = JSON.stringify(arr)
                    dockSettings.userWidgetsJson = liveWidgetsJson
                    if (typeof dockSettings.sync === "function") dockSettings.sync()
                    taskBackend.writeUserJsonFile("widgets.json", liveWidgetsJson)
                    reloadCustomWidgets()
                    removed = true
                }
            }
        } catch (e) {
            taskBackend.debugLog("persist", "Erro ao remover de widgets.json: " + e)
        }

        // 2. Clean from systemModel
        for (let i = systemModel.count - 1; i >= 0; i--) {
            const item = systemModel.get(i)
            if (!item) continue
            let match = false
            if (preset === "trash" || cmd === "dolphin trash://") {
                if (item.isTrash || item.cmd === "dolphin trash://" || (item.cmd && item.cmd.indexOf("trash:/") >= 0)) match = true
            } else if (cmd.length > 0 && item.cmd === cmd) {
                match = true
            } else if (name.length > 0 && item.name === name) {
                match = true
            } else if (preset === "clock" && item.cmd && item.cmd.indexOf("kcm_clock") >= 0) {
                match = true
            } else if (preset === "volume" && item.cmd && item.cmd.indexOf("kcm_pulseaudio") >= 0) {
                match = true
            } else if (preset === "media" && item.cmd && item.cmd.indexOf("plasma-browser-integration") >= 0) {
                match = true
            }
            if (match) {
                systemModel.remove(i)
                removed = true
            }
        }

        // 3. Clean from appModel
        for (let i = appModel.count - 1; i >= 0; i--) {
            const item = appModel.get(i)
            if (!item) continue
            let match = false
            if (cmd.length > 0 && item.cmd === cmd) match = true
            if (name.length > 0 && item.name === name) match = true
            if (preset === "clock" && item.cmd && item.cmd.indexOf("kcm_clock") >= 0) match = true
            if (preset === "volume" && item.cmd && item.cmd.indexOf("kcm_pulseaudio") >= 0) match = true
            if (preset === "media" && item.cmd && item.cmd.indexOf("plasma-browser-integration") >= 0) match = true
            if (match) {
                appModel.remove(i)
                removed = true
            }
        }

        if (removed) {
            saveApps()
        }
        return removed
    }

    DropArea {
        id: edgeDragDropArea
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Math.max(70, root.dockExpandedHeight)
        z: 99999
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
        z: 99999
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
