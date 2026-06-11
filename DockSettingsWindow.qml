import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window

// Janela de configurações — referencia a janela principal da doca via `dock`.
Window {
    id: settingsWin

    required property var dock

    visible: false
    width: 980
    height: 860
    minimumWidth: 760
    maximumWidth: 1480
    minimumHeight: 520
    maximumHeight: 1200
    title: qsTr("Configurações — AgildoDock")
    color: "#1A1A1A"
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    // Editor JSON estável para evitar warning do TextArea no Breeze.
    component JsonEditor: Rectangle {
        id: jsonEditor
        property alias text: editor.text
        property string placeholderText: ""
        color: "#101010"
        radius: 6
        border.color: "#30FFFFFF"
        border.width: 1
        clip: true

        Flickable {
            id: flick
            anchors.fill: parent
            anchors.margins: 6
            contentWidth: width
            contentHeight: Math.max(height, editor.paintedHeight + 4)
            clip: true

            TextEdit {
                id: editor
                width: flick.width
                color: "#EEEEEE"
                wrapMode: TextEdit.WrapAnywhere
                font.pixelSize: 12
                selectByMouse: true
            }
        }

        Text {
            anchors.fill: parent
            anchors.margins: 10
            text: jsonEditor.placeholderText
            color: "#77FFFFFF"
            wrapMode: Text.WrapAnywhere
            visible: editor.text.length === 0
            font.pixelSize: 11
        }
    }

    function carregarValores() {
        dock.liveScaleFactor = dock.appSettings.scaleFactor
        dock.liveIconSpacing = dock.appSettings.iconSpacing
        dock.liveDockMargin = dock.appSettings.dockMargin
        dock.liveBgOpacity = dock.appSettings.bgOpacity
        dock.liveMinIconSize = dock.appSettings.minIconSize
        dock.liveMaxIconSize = Math.max(dock.appSettings.minIconSize, dock.appSettings.maxIconSize)
        dock.clampMaxIconSizeForZoomCap()
        dock.liveThemeMode = dock.appSettings.themeMode
        dock.liveAccentMode = dock.appSettings.accentMode
        dock.liveWaveIntensity = Math.max(0.6, Math.min(1.0, dock.appSettings.waveIntensity))
        dock.liveDockRadius = dock.appSettings.dockRadius
        dock.liveMonochromeIcons = dock.appSettings.monochromeIcons
        dock.liveIndicatorStyle = dock.appSettings.indicatorStyle
        dock.liveIndicatorScale = dock.appSettings.indicatorScale
        dock.liveBg3dStyle = dock.normalizeBg3dStyle(dock.appSettings.bg3dStyle)
        dock.liveGradientColorA = dock.appSettings.gradientColorA
        dock.liveGradientColorB = dock.appSettings.gradientColorB
        dock.liveGradientColorC = dock.appSettings.gradientColorC
        dock.liveGradientMix = dock.appSettings.gradientMix
        // gradientAngle: propriedade removida
        dock.liveBorderWidth = dock.appSettings.borderWidth
        dock.liveBorderGlow = dock.appSettings.borderGlow
        dock.liveShadowStrength = dock.appSettings.shadowStrength
        dock.liveAnimationProfile = dock.appSettings.animationProfile
        dock.liveWaveRadiusFactor = dock.appSettings.waveRadiusFactor
        dock.liveWaveFalloff = dock.appSettings.waveFalloff
        dock.liveLaunchBounceIntensity = dock.appSettings.launchBounceIntensity
        dock.liveAutoThemeByActiveApp = dock.appSettings.autoThemeByActiveApp
        dock.liveDockEditMode = dock.appSettings.dockEditMode
        dock.liveDockEdge = dock.appSettings.dockEdge
        dock.liveDockOffsetX = dock.appSettings.dockOffsetX
        dock.liveDockOffsetY = dock.appSettings.dockOffsetY
        dock.liveLeftClickAction = dock.appSettings.leftClickAction
        dock.liveMiddleClickAction = dock.appSettings.middleClickAction
        dock.liveRightClickAction = dock.appSettings.rightClickAction
        dock.liveToggleDockShortcut = dock.appSettings.toggleDockShortcut
        dock.liveOpenSettingsShortcut = dock.appSettings.openSettingsShortcut
        dock.liveScheduleThemeEnabled = dock.appSettings.scheduleThemeEnabled
        dock.liveDayThemeMode = dock.appSettings.dayThemeMode
        dock.liveNightThemeMode = dock.appSettings.nightThemeMode
        dock.liveNightStartHour = dock.appSettings.nightStartHour
        dock.liveDayStartHour = dock.appSettings.dayStartHour
        dock.liveProfilesJson = dock.appSettings.profilesJson
        dock.liveAppRulesJson = dock.appSettings.appRulesJson
        dock.liveCustomCommandsJson = dock.appSettings.customCommandsJson
        dock.liveWidgetsJson = dock.appSettings.userWidgetsJson
        dock.livePresetName = dock.appSettings.presetName

        dock.liveBehaviorAutoHide = dock.appSettings.behaviorAutoHide
        dock.liveBehaviorDodgeWindows = dock.appSettings.behaviorDodgeWindows
        dock.liveBehaviorKeepAppsFocused = dock.appSettings.behaviorKeepAppsFocused
        dock.liveBehaviorWindowOverviewOnRefocus = dock.appSettings.behaviorWindowOverviewOnRefocus
        dock.liveBehaviorShowUnpinnedApps = dock.appSettings.behaviorShowUnpinnedApps
        dock.liveBehaviorRememberRecentApps = dock.appSettings.behaviorRememberRecentApps
        dock.liveBehaviorAutoHideDelayMs = dock.appSettings.behaviorAutoHideDelayMs
        dock.liveScrollWheelAction = dock.appSettings.scrollWheelAction
        dock.liveDownloadProgressDisplayMode = dock.appSettings.downloadProgressDisplayMode
        taskBackend.windowOverviewOnRefocus = dock.liveBehaviorWindowOverviewOnRefocus
        taskBackend.setDownloadProgressDisplayMode(dock.liveDownloadProgressDisplayMode)
        dock.syncGlobalShortcuts()
    }

    function cancelarValores() {
        carregarValores()
        settingsWin.close()
    }

    function aplicarValores() {
        var minSz = dock.liveMinIconSize
        var maxSz = Math.max(minSz, Math.min(dock.liveMaxIconSize, minSz * 2.0))
        dock.liveMaxIconSize = maxSz

        dock.appSettings.scaleFactor = dock.liveScaleFactor
        dock.appSettings.iconSpacing = dock.liveIconSpacing
        dock.appSettings.dockMargin = dock.liveDockMargin
        dock.appSettings.bgOpacity = dock.liveBgOpacity
        dock.appSettings.minIconSize = minSz
        dock.appSettings.maxIconSize = maxSz
        dock.appSettings.themeMode = dock.liveThemeMode
        dock.appSettings.accentMode = dock.liveAccentMode
        dock.appSettings.waveIntensity = dock.liveWaveIntensity
        dock.appSettings.dockRadius = dock.liveDockRadius
        dock.appSettings.monochromeIcons = dock.liveMonochromeIcons
        dock.appSettings.indicatorStyle = dock.liveIndicatorStyle
        dock.appSettings.indicatorScale = dock.liveIndicatorScale
        dock.appSettings.bg3dStyle = dock.liveBg3dStyle
        dock.appSettings.gradientColorA = dock.liveGradientColorA
        dock.appSettings.gradientColorB = dock.liveGradientColorB
        dock.appSettings.gradientColorC = dock.liveGradientColorC
        dock.appSettings.gradientMix = dock.liveGradientMix
        // gradientAngle: propriedade removida
        dock.appSettings.borderWidth = dock.liveBorderWidth
        dock.appSettings.borderGlow = dock.liveBorderGlow
        dock.appSettings.shadowStrength = dock.liveShadowStrength
        dock.appSettings.animationProfile = dock.liveAnimationProfile
        dock.appSettings.waveRadiusFactor = dock.liveWaveRadiusFactor
        dock.appSettings.waveFalloff = dock.liveWaveFalloff
        dock.appSettings.launchBounceIntensity = dock.liveLaunchBounceIntensity
        dock.appSettings.autoThemeByActiveApp = dock.liveAutoThemeByActiveApp
        dock.appSettings.dockEditMode = dock.liveDockEditMode
        dock.appSettings.dockEdge = dock.liveDockEdge
        dock.appSettings.dockOffsetX = dock.liveDockOffsetX
        dock.appSettings.dockOffsetY = dock.liveDockOffsetY
        dock.appSettings.leftClickAction = dock.liveLeftClickAction
        dock.appSettings.middleClickAction = dock.liveMiddleClickAction
        dock.appSettings.rightClickAction = dock.liveRightClickAction
        dock.appSettings.toggleDockShortcut = dock.liveToggleDockShortcut
        dock.appSettings.openSettingsShortcut = dock.liveOpenSettingsShortcut
        dock.appSettings.scheduleThemeEnabled = dock.liveScheduleThemeEnabled
        dock.appSettings.dayThemeMode = dock.liveDayThemeMode
        dock.appSettings.nightThemeMode = dock.liveNightThemeMode
        dock.appSettings.nightStartHour = dock.liveNightStartHour
        dock.appSettings.dayStartHour = dock.liveDayStartHour
        dock.appSettings.profilesJson = dock.liveProfilesJson
        dock.appSettings.appRulesJson = dock.liveAppRulesJson
        dock.appSettings.customCommandsJson = dock.liveCustomCommandsJson
        dock.appSettings.userWidgetsJson = dock.liveWidgetsJson
        dock.appSettings.presetName = dock.livePresetName

        dock.appSettings.behaviorAutoHide = dock.liveBehaviorAutoHide
        dock.appSettings.behaviorDodgeWindows = dock.liveBehaviorDodgeWindows
        dock.appSettings.behaviorKeepAppsFocused = dock.liveBehaviorKeepAppsFocused
        dock.appSettings.behaviorWindowOverviewOnRefocus = dock.liveBehaviorWindowOverviewOnRefocus
        dock.appSettings.behaviorShowUnpinnedApps = dock.liveBehaviorShowUnpinnedApps
        dock.appSettings.behaviorRememberRecentApps = dock.liveBehaviorRememberRecentApps
        dock.appSettings.behaviorAutoHideDelayMs = dock.liveBehaviorAutoHideDelayMs
        dock.appSettings.scrollWheelAction = dock.liveScrollWheelAction
        dock.appSettings.downloadProgressDisplayMode = dock.liveDownloadProgressDisplayMode
        taskBackend.windowOverviewOnRefocus = dock.liveBehaviorWindowOverviewOnRefocus
        taskBackend.setDownloadProgressDisplayMode(dock.liveDownloadProgressDisplayMode)
        dock.syncGlobalShortcuts()

        dock.pushCustomizationHistory()
        if (typeof dock.appSettings.sync === "function") {
            dock.appSettings.sync()
        }
        taskBackend.writeUserJsonFile("profiles.json", dock.liveProfilesJson)
        taskBackend.writeUserJsonFile("app_rules.json", dock.liveAppRulesJson)
        taskBackend.writeUserJsonFile("custom_commands.json", dock.liveCustomCommandsJson)
        taskBackend.writeUserJsonFile("widgets.json", dock.liveWidgetsJson)
        dock.reloadCustomWidgets()
        dock.updateZone()
        dock.applyLayerShellFromSettings()
        dock.applyDockRetractedState()
        settingsWin.close()
    }

    function ajustarAlturaAoConteudo() {
        // Mantém janela redimensionável sem “encolher” quando conteúdo muda.
        settingsWin.height = Math.max(settingsWin.minimumHeight,
                                      Math.min(settingsWin.maximumHeight, settingsWin.height))
    }

    function adicionarWidgetPreset(preset) {
        let widgets = []
        try {
            widgets = JSON.parse(dock.liveWidgetsJson || "[]")
            if (!Array.isArray(widgets))
                widgets = []
        } catch (e) {
            widgets = []
        }
        widgets.push(preset)
        dock.liveWidgetsJson = JSON.stringify(widgets, null, 2)
    }

    function salvarPerfil(nomePerfil) {
        let profiles = {}
        try { profiles = JSON.parse(dock.liveProfilesJson || "{}") } catch (e) { profiles = {} }
        profiles[nomePerfil] = {
            savedAt: Date.now(),
            // aparência
            themeMode: dock.liveThemeMode,
            accentMode: dock.liveAccentMode,
            bg3dStyle: dock.liveBg3dStyle,
            bgOpacity: dock.liveBgOpacity,
            gradientColorA: dock.liveGradientColorA,
            gradientColorB: dock.liveGradientColorB,
            gradientColorC: dock.liveGradientColorC,
            gradientMix: dock.liveGradientMix,
            borderGlow: dock.liveBorderGlow,
            borderWidth: dock.liveBorderWidth,
            shadowStrength: dock.liveShadowStrength,
            dockRadius: dock.liveDockRadius,
            monochromeIcons: dock.liveMonochromeIcons,
            // indicador
            indicatorStyle: dock.liveIndicatorStyle,
            indicatorScale: dock.liveIndicatorScale,
            // tamanhos e onda
            scaleFactor: dock.liveScaleFactor,
            iconSpacing: dock.liveIconSpacing,
            dockMargin: dock.liveDockMargin,
            minIconSize: dock.liveMinIconSize,
            maxIconSize: dock.liveMaxIconSize,
            waveIntensity: dock.liveWaveIntensity,
            waveRadiusFactor: dock.liveWaveRadiusFactor,
            waveFalloff: dock.liveWaveFalloff,
            // animação
            animationProfile: dock.liveAnimationProfile,
            launchBounceIntensity: dock.liveLaunchBounceIntensity
        }
        dock.liveProfilesJson = JSON.stringify(profiles)
    }

    function aplicarPerfil(nomePerfil) {
        try {
            let profiles = JSON.parse(dock.liveProfilesJson || "{}")
            let p = profiles[nomePerfil]
            if (!p) return
            dock.pushCustomizationHistory()
            // aparência
            if (p.themeMode    !== undefined) dock.liveThemeMode    = p.themeMode
            if (p.accentMode   !== undefined) dock.liveAccentMode   = p.accentMode
            if (p.bg3dStyle    !== undefined) dock.liveBg3dStyle    = dock.normalizeBg3dStyle(p.bg3dStyle)
            if (p.bgOpacity    !== undefined) dock.liveBgOpacity    = p.bgOpacity
            if (p.gradientColorA !== undefined) dock.liveGradientColorA = p.gradientColorA
            if (p.gradientColorB !== undefined) dock.liveGradientColorB = p.gradientColorB
            if (p.gradientColorC !== undefined) dock.liveGradientColorC = p.gradientColorC
            if (p.gradientMix  !== undefined) dock.liveGradientMix  = p.gradientMix
            if (p.borderGlow   !== undefined) dock.liveBorderGlow   = p.borderGlow
            if (p.borderWidth  !== undefined) dock.liveBorderWidth  = p.borderWidth
            if (p.shadowStrength !== undefined) dock.liveShadowStrength = p.shadowStrength
            if (p.dockRadius   !== undefined) dock.liveDockRadius   = p.dockRadius
            if (p.monochromeIcons !== undefined) dock.liveMonochromeIcons = p.monochromeIcons
            // indicador
            if (p.indicatorStyle !== undefined) dock.liveIndicatorStyle = p.indicatorStyle
            if (p.indicatorScale !== undefined) dock.liveIndicatorScale = p.indicatorScale
            // tamanhos e onda
            if (p.scaleFactor  !== undefined) dock.liveScaleFactor  = p.scaleFactor
            if (p.iconSpacing  !== undefined) dock.liveIconSpacing  = p.iconSpacing
            if (p.dockMargin   !== undefined) dock.liveDockMargin   = p.dockMargin
            if (p.minIconSize  !== undefined) dock.liveMinIconSize  = p.minIconSize
            if (p.maxIconSize  !== undefined) {
                dock.liveMaxIconSize = Math.max(p.minIconSize || dock.liveMinIconSize, p.maxIconSize)
                dock.clampMaxIconSizeForZoomCap()
            }
            if (p.waveIntensity !== undefined) dock.liveWaveIntensity = p.waveIntensity
            if (p.waveRadiusFactor !== undefined) dock.liveWaveRadiusFactor = p.waveRadiusFactor
            if (p.waveFalloff  !== undefined) dock.liveWaveFalloff  = p.waveFalloff
            // animação
            if (p.animationProfile !== undefined) dock.liveAnimationProfile = p.animationProfile
            if (p.launchBounceIntensity !== undefined) dock.liveLaunchBounceIntensity = p.launchBounceIntensity
        } catch (e) {}
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
        id: settingsContent
        anchors.fill: parent
        anchors.margins: 14
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        contentWidth: availableWidth

        ColumnLayout {
            id: mainLayout
            width: settingsContent.availableWidth
            spacing: 10

            Accessible.role: Accessible.Dialog
            Accessible.name: settingsWin.title

            Label {
                text: qsTr("Ajustes da doca")
                font.bold: true
                font.pixelSize: 17
                color: "#FFFFFF"
                Layout.fillWidth: true
            }

            Label {
                visible: !taskBackend.windowManagementAvailable
                text: qsTr("Gestão de janelas indisponível: instala «kdotool» no Plasma/Wayland.")
                wrapMode: Text.WordWrap
                font.pixelSize: 11
                color: "#FFB090"
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Frame {
                    Layout.fillWidth: true
                    padding: 12
                    background: Rectangle {
                        color: "#141414"
                        radius: 8
                        border.width: 1
                        border.color: "#26FFFFFF"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Label { text: qsTr("Aparência"); font.bold: true; color: "#FFFFFF" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Escala: %1%").arg(Math.round(dock.liveScaleFactor * 100)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0.5; to: 1.8; stepSize: 0.05; value: dock.liveScaleFactor; onMoved: dock.liveScaleFactor = value }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Espaçamento: %1 px").arg(Math.round(dock.liveIconSpacing)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0; to: 40; stepSize: 1; value: dock.liveIconSpacing; onMoved: dock.liveIconSpacing = value }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Margem inferior: %1 px").arg(Math.round(dock.liveDockMargin)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0; to: 50; stepSize: 1; value: dock.liveDockMargin; onMoved: dock.liveDockMargin = value }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Opacidade: %1%").arg(Math.round(dock.liveBgOpacity * 100)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0.2; to: 1.0; stepSize: 0.05; value: dock.liveBgOpacity; onMoved: dock.liveBgOpacity = value }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Tema"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Escuro"), qsTr("Claro"), qsTr("Noite Azul"), qsTr("Ametista")]
                                    currentIndex: dock.liveThemeMode
                                    onActivated: dock.liveThemeMode = currentIndex
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Destaque"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Ciano"), qsTr("Roxo"), qsTr("Verde"), qsTr("Laranja"), qsTr("Rosa")]
                                    currentIndex: dock.liveAccentMode
                                    onActivated: dock.liveAccentMode = currentIndex
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Atalho alternar dock"); color: "#CCCCCC"; font.pixelSize: 12 }
                                TextField { Layout.fillWidth: true; text: dock.liveToggleDockShortcut; onTextChanged: dock.liveToggleDockShortcut = text }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Atalho abrir ajustes"); color: "#CCCCCC"; font.pixelSize: 12 }
                                TextField { Layout.fillWidth: true; text: dock.liveOpenSettingsShortcut; onTextChanged: dock.liveOpenSettingsShortcut = text }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Preset visual"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    id: presetCombo
                                    Layout.fillWidth: true
                                    model: ["Dark Glass", "Light Glass", "Neon", "Minimal"]
                                    currentIndex: Math.max(0, model.indexOf(dock.livePresetName))
                                    onActivated: dock.applyAppearancePreset(currentText)
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Fundo"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Padrão"), qsTr("Vidro")]
                                    currentIndex: dock.liveBg3dStyle === 0 ? 0 : 1
                                    onActivated: dock.liveBg3dStyle = currentIndex === 0 ? 0 : 3
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Cor A gradiente"); color: "#CCCCCC"; font.pixelSize: 12 }
                                TextField { Layout.fillWidth: true; text: dock.liveGradientColorA; onTextChanged: dock.liveGradientColorA = text }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Cor B gradiente"); color: "#CCCCCC"; font.pixelSize: 12 }
                                TextField { Layout.fillWidth: true; text: dock.liveGradientColorB; onTextChanged: dock.liveGradientColorB = text }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Cor C gradiente"); color: "#CCCCCC"; font.pixelSize: 12 }
                                TextField { Layout.fillWidth: true; text: dock.liveGradientColorC; onTextChanged: dock.liveGradientColorC = text }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Indicador"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Ponto"), qsTr("Linha"), qsTr("Barra"), qsTr("Sublinhado"), qsTr("Pulso")]
                                    currentIndex: dock.liveIndicatorStyle
                                    onActivated: dock.liveIndicatorStyle = currentIndex
                                }
                            }
                        }

                        CheckBox {
                            text: qsTr("Ícones monocromáticos")
                            checked: dock.liveMonochromeIcons
                            onToggled: dock.liveMonochromeIcons = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Raio da dock: %1 px").arg(Math.round(dock.liveDockRadius)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 8; to: 40; stepSize: 1; value: dock.liveDockRadius; onMoved: dock.liveDockRadius = value }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Brilho da borda: %1%").arg(Math.round(dock.liveBorderGlow * 100)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0.05; to: 0.60; stepSize: 0.01; value: dock.liveBorderGlow; onMoved: dock.liveBorderGlow = value }
                        }
                    }
                }

                Frame {
                    Layout.fillWidth: true
                    padding: 12
                    background: Rectangle {
                        color: "#141414"
                        radius: 8
                        border.width: 1
                        border.color: "#26FFFFFF"
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        Label { text: qsTr("Comportamento e onda"); font.bold: true; color: "#FFFFFF" }

                        Label {
                            text: qsTr("Arraste ícones fixados na dock para reordenar (estilo macOS). Clique curto abre o app.")
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#22FFFFFF" }

                        CheckBox {
                            text: qsTr("Ocultar automaticamente")
                            checked: dock.liveBehaviorAutoHide
                            onToggled: {
                                dock.liveBehaviorAutoHide = checked
                            }
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            visible: dock.liveBehaviorAutoHide
                            spacing: 6
                            Label { text: qsTr("Atraso: %1 ms").arg(dock.liveBehaviorAutoHideDelayMs); color: "#AAAAAA"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 300; to: 4000; stepSize: 50; value: dock.liveBehaviorAutoHideDelayMs; onMoved: dock.liveBehaviorAutoHideDelayMs = Math.round(value) }
                        }

                        CheckBox {
                            text: qsTr("Desviar ao cobrir área útil")
                            checked: dock.liveBehaviorDodgeWindows
                            onToggled: dock.liveBehaviorDodgeWindows = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: dock.liveBehaviorDodgeWindows
                            text: qsTr("Usa heurística da janela ativa com kdotool.")
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        CheckBox {
                            text: qsTr("Não roubar foco do teclado")
                            checked: dock.liveBehaviorKeepAppsFocused
                            onToggled: dock.liveBehaviorKeepAppsFocused = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }

                        CheckBox {
                            text: qsTr("Mostrar janelas ao clicar no app focado (2+ janelas)")
                            checked: dock.liveBehaviorWindowOverviewOnRefocus
                            onToggled: {
                                dock.liveBehaviorWindowOverviewOnRefocus = checked
                                taskBackend.windowOverviewOnRefocus = checked
                            }
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#22FFFFFF" }

                        CheckBox {
                            text: qsTr("Mostrar apps em execução não fixados")
                            checked: dock.liveBehaviorShowUnpinnedApps
                            onToggled: dock.liveBehaviorShowUnpinnedApps = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: dock.liveBehaviorShowUnpinnedApps
                            text: qsTr("Apps abertos aparecem na dock até fecharem (estilo macOS).")
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        CheckBox {
                            text: qsTr("Lembrar apps da sessão anterior ao abrir a dock")
                            checked: dock.liveBehaviorRememberRecentApps
                            enabled: dock.liveBehaviorShowUnpinnedApps
                            onToggled: dock.liveBehaviorRememberRecentApps = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        Label {
                            visible: dock.liveBehaviorRememberRecentApps && dock.liveBehaviorShowUnpinnedApps
                            text: qsTr("Mostra ícones semitransparentes dos apps usados antes de reiniciar a dock.")
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Scroll no ícone"); color: "#CCCCCC"; font.pixelSize: 12 }
                            ComboBox {
                                Layout.fillWidth: true
                                model: [qsTr("Alternar janelas"), qsTr("Volume"), qsTr("Brilho")]
                                currentIndex: dock.liveScrollWheelAction
                                onActivated: dock.liveScrollWheelAction = currentIndex
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Progresso de download"); color: "#CCCCCC"; font.pixelSize: 12 }
                            ComboBox {
                                Layout.fillWidth: true
                                model: [
                                    qsTr("No ícone do navegador"),
                                    qsTr("Na pasta Transferências"),
                                    qsTr("Transferências com ícone do arquivo (macOS)")
                                ]
                                currentIndex: dock.liveDownloadProgressDisplayMode
                                onActivated: dock.liveDownloadProgressDisplayMode = currentIndex
                            }
                            Label {
                                text: qsTr("No macOS, a barra aparece em Transferências com o ícone do arquivo que está sendo baixado.")
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                                font.pixelSize: 11
                                color: "#888888"
                            }
                        }

                        Label {
                            text: qsTr("Atalho global de preferências (KGlobalAccel): %1").arg(dock.liveOpenSettingsShortcut)
                            wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            font.pixelSize: 11
                            color: "#888888"
                        }

                        Rectangle { Layout.fillWidth: true; height: 1; color: "#22FFFFFF" }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Ícone base: %1 px").arg(Math.round(dock.liveMinIconSize)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider {
                                Layout.fillWidth: true
                                from: 30; to: 80; stepSize: 1
                                value: dock.liveMinIconSize
                                onMoved: {
                                    dock.liveMinIconSize = value
                                    dock.clampMaxIconSizeForZoomCap()
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label {
                                text: qsTr("Zoom máximo: %1%").arg(Math.round(dock.liveMaxIconZoomPercent))
                                color: "#CCCCCC"; font.pixelSize: 12
                            }
                            Slider {
                                Layout.fillWidth: true
                                from: 0; to: 100; stepSize: 5
                                value: dock.liveMaxIconZoomPercent
                                onMoved: dock.setLiveMaxIconZoomPercent(value)
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Intensidade: %1%").arg(Math.round(dock.liveWaveIntensity * 100)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: 0.6; to: 1.0; stepSize: 0.05; value: dock.liveWaveIntensity; onMoved: dock.liveWaveIntensity = value }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Perfil de animação"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Suave"), qsTr("Rápido"), qsTr("Elástico"), qsTr("Sem animação")]
                                    currentIndex: dock.liveAnimationProfile
                                    onActivated: dock.liveAnimationProfile = currentIndex
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Ação clique esquerdo"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Padrão"), qsTr("Abrir menu"), qsTr("Sempre nova janela")]
                                    currentIndex: dock.liveLeftClickAction
                                    onActivated: dock.liveLeftClickAction = currentIndex
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Ação clique do meio"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Padrão"), qsTr("Fechar app"), qsTr("Nova janela"), qsTr("Minimizar/Restaurar")]
                                    currentIndex: dock.liveMiddleClickAction
                                    onActivated: dock.liveMiddleClickAction = currentIndex
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Posição da dock"); color: "#CCCCCC"; font.pixelSize: 12 }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Inferior"), qsTr("Superior"), qsTr("Esquerda"), qsTr("Direita")]
                                    currentIndex: dock.liveDockEdge
                                    onActivated: dock.liveDockEdge = currentIndex
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Offset X: %1 px").arg(Math.round(dock.liveDockOffsetX)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetX; onMoved: dock.liveDockOffsetX = value }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Label { text: qsTr("Offset Y: %1 px").arg(Math.round(dock.liveDockOffsetY)); color: "#CCCCCC"; font.pixelSize: 12 }
                            Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetY; onMoved: dock.liveDockOffsetY = value }
                        }

                        CheckBox {
                            text: qsTr("Tema dinâmico por app em foco")
                            checked: dock.liveAutoThemeByActiveApp
                            onToggled: dock.liveAutoThemeByActiveApp = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        CheckBox {
                            text: qsTr("Agenda automática de tema")
                            checked: dock.liveScheduleThemeEnabled
                            onToggled: dock.liveScheduleThemeEnabled = checked
                            palette.text: "#DDDDDD"
                            Layout.fillWidth: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: dock.liveScheduleThemeEnabled
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Início do dia: %1h").arg(dock.liveDayStartHour); color: "#CCCCCC"; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0; to: 23; stepSize: 1; value: dock.liveDayStartHour; onMoved: dock.liveDayStartHour = Math.round(value) }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Label { text: qsTr("Início da noite: %1h").arg(dock.liveNightStartHour); color: "#CCCCCC"; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0; to: 23; stepSize: 1; value: dock.liveNightStartHour; onMoved: dock.liveNightStartHour = Math.round(value) }
                            }
                        }
                        Label { text: qsTr("Regras por app (JSON)"); color: "#CCCCCC"; font.pixelSize: 12 }
                        JsonEditor {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            text: dock.liveAppRulesJson
                            onTextChanged: dock.liveAppRulesJson = text
                            placeholderText: "{\"firefox\":{\"badgeText\":\"3\"}}"
                        }

                        Label { text: qsTr("Comandos custom por app (JSON)"); color: "#CCCCCC"; font.pixelSize: 12 }
                        JsonEditor {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 64
                            text: dock.liveCustomCommandsJson
                            onTextChanged: dock.liveCustomCommandsJson = text
                            placeholderText: "{\"konsole\":[{\"label\":\"Abrir htop\",\"command\":\"konsole -e htop\"}]}"
                        }

                        Label { text: qsTr("Widgets/Plugins leves (JSON array)"); color: "#CCCCCC"; font.pixelSize: 12 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Button {
                                text: qsTr("+ Monitor")
                                onClicked: adicionarWidgetPreset({
                                    name: qsTr("Monitor"),
                                    icon: "utilities-system-monitor",
                                    cmd: "plasma-systemmonitor"
                                })
                            }
                            Button {
                                text: qsTr("+ Separador")
                                onClicked: adicionarWidgetPreset({
                                    name: qsTr("Separador"),
                                    icon: "draw-separator",
                                    type: "separator"
                                })
                            }
                            Button {
                                text: qsTr("+ Relógio")
                                onClicked: adicionarWidgetPreset({
                                    name: qsTr("Relógio"),
                                    icon: "clock",
                                    type: "clock"
                                })
                            }
                        }
                        JsonEditor {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 56
                            text: dock.liveWidgetsJson
                            onTextChanged: dock.liveWidgetsJson = text
                            placeholderText: "[{\"name\":\"CPU\",\"icon\":\"utilities-system-monitor\",\"cmd\":\"plasma-systemmonitor\"}]"
                        }

                        Label { text: qsTr("Perfis rápidos"); color: "#CCCCCC"; font.pixelSize: 12 }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Button { text: qsTr("Salvar Trabalho"); onClicked: salvarPerfil("Trabalho") }
                            Button { text: qsTr("Salvar Gaming"); onClicked: salvarPerfil("Gaming") }
                            Button { text: qsTr("Salvar Streaming"); onClicked: salvarPerfil("Streaming") }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Button { text: qsTr("Aplicar Trabalho"); onClicked: aplicarPerfil("Trabalho") }
                            Button { text: qsTr("Aplicar Gaming"); onClicked: aplicarPerfil("Gaming") }
                            Button { text: qsTr("Aplicar Streaming"); onClicked: aplicarPerfil("Streaming") }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Button { text: qsTr("Exportar perfis"); onClicked: taskBackend.writeUserJsonFile("profiles_export.json", dock.liveProfilesJson) }
                            Button {
                                text: qsTr("Importar perfis")
                                onClicked: {
                                    const raw = taskBackend.readUserJsonFile("profiles_export.json")
                                    if (raw !== "") dock.liveProfilesJson = raw
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Button { text: qsTr("Desfazer"); onClicked: dock.undoCustomization() }
                            Button { text: qsTr("Refazer"); onClicked: dock.redoCustomization() }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Button {
                    text: qsTr("Encerrar doca")
                    icon.name: "application-exit"
                    onClicked: Qt.quit()
                }

                Item { Layout.fillWidth: true }

                Button {
                    text: qsTr("Cancelar")
                    onClicked: settingsWin.cancelarValores()
                }

                Button {
                    text: qsTr("Guardar")
                    highlighted: true
                    onClicked: settingsWin.aplicarValores()
                }
            }

        }
    }
}
