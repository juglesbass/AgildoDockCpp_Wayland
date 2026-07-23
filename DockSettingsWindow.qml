import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Window

// Janela de configurações completa — estilo moderno inspirado no Latte Dock.
Window {
    id: settingsWin

    required property var dock

    visible: false
    width: 880
    height: 760
    minimumWidth: 740
    maximumWidth: 1300
    minimumHeight: 620
    maximumHeight: 1000
    title: qsTr("Configurações — AgildoDock")

    readonly property bool settingsDark: dock.liveThemeMode === 0 || dock.liveThemeMode === 2 || dock.liveThemeMode === 3
    readonly property color uiBgColor: settingsDark ? "#1A1D24" : "#F0F2F5"
    readonly property color uiHeaderBg: settingsDark ? "#13151A" : "#E4E7EC"
    readonly property color uiCardBg: settingsDark ? "#212631" : "#FFFFFF"
    readonly property color uiCardBorder: settingsDark ? "#2D3444" : "#D0D5DD"
    readonly property color uiTextPrimary: settingsDark ? "#F3F4F6" : "#111827"
    readonly property color uiTextSecondary: settingsDark ? "#9CA3AF" : "#6B7280"
    readonly property color uiAccent: "#3B82F6"
    readonly property color uiAccentActiveText: "#FFFFFF"

    color: uiBgColor
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    property int activeTab: 0 // 0: Behavior, 1: Appearance, 2: Tweaks
    property bool advancedMode: false

    // Componente de botão segmentado reutilizável
    component ActionBtn: Rectangle {
        id: btnRoot
        property string text: ""
        property bool highlighted: false
        signal clicked()

        implicitWidth: Math.max(92, btnText.implicitWidth + 24)
        implicitHeight: 34
        radius: 6
        color: highlighted ? (btnMouse.pressed ? Qt.darker(settingsWin.uiAccent, 1.2) : settingsWin.uiAccent)
                           : (btnMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))
        border.color: highlighted ? settingsWin.uiAccent : (btnMouse.containsMouse ? settingsWin.uiAccent : settingsWin.uiCardBorder)
        border.width: 1

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            id: btnText
            anchors.centerIn: parent
            text: btnRoot.text
            color: highlighted ? "#FFFFFF" : (btnMouse.containsMouse ? settingsWin.uiAccent : settingsWin.uiTextPrimary)
            font.pixelSize: 12
            font.bold: highlighted || btnMouse.containsMouse
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: btnRoot.clicked()
        }
    }

    component SegmentedButton: Rectangle {
        id: segBtn
        property string labelText: ""
        property bool selected: false
        signal clicked()

        implicitHeight: 32
        Layout.fillWidth: true
        radius: 6
        color: selected ? settingsWin.uiAccent : (mouseArea.containsMouse ? (settingsWin.settingsDark ? "#2E3646" : "#E5E7EB") : "transparent")
        border.color: selected ? settingsWin.uiAccent : (settingsWin.settingsDark ? "#3A4559" : "#D1D5DB")
        border.width: selected ? 0 : 1

        Behavior on color { ColorAnimation { duration: 120 } }

        RowLayout {
            anchors.centerIn: parent
            spacing: 4
            Text {
                text: segBtn.labelText
                color: segBtn.selected ? settingsWin.uiAccentActiveText : settingsWin.uiTextPrimary
                font.pixelSize: 12
                font.bold: segBtn.selected
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: segBtn.clicked()
        }
    }

    // Componente de seletor numérico compacto (ms delay)
    component DelayControl: RowLayout {
        id: delayCtrl
        property string labelText: ""
        property int delayValue: 0
        property int step: 50
        property int minValue: 0
        property int maxValue: 3000
        signal valueUpdated(int newValue)

        spacing: 8

        Label {
            text: delayCtrl.labelText
            color: settingsWin.uiTextSecondary
            font.pixelSize: 12
        }

        Rectangle {
            height: 30
            width: 120
            color: settingsWin.settingsDark ? "#13151A" : "#E4E7EC"
            radius: 6
            border.color: settingsWin.uiCardBorder
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 4
                spacing: 4

                Text {
                    text: delayCtrl.delayValue + " ms"
                    color: settingsWin.uiTextPrimary
                    font.pixelSize: 12
                    font.bold: true
                    Layout.fillWidth: true
                }

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: minusMouse.containsMouse ? (settingsWin.settingsDark ? "#323B4A" : "#D1D5DB") : "transparent"
                    Text { text: "-"; anchors.centerIn: parent; color: settingsWin.uiTextPrimary; font.bold: true }
                    MouseArea { id: minusMouse; anchors.fill: parent; hoverEnabled: true; onClicked: delayCtrl.valueUpdated(Math.max(delayCtrl.minValue, delayCtrl.delayValue - delayCtrl.step)) }
                }

                Rectangle {
                    width: 20; height: 20; radius: 4
                    color: plusMouse.containsMouse ? (settingsWin.settingsDark ? "#323B4A" : "#D1D5DB") : "transparent"
                    Text { text: "+"; anchors.centerIn: parent; color: settingsWin.uiTextPrimary; font.bold: true }
                    MouseArea { id: plusMouse; anchors.fill: parent; hoverEnabled: true; onClicked: delayCtrl.valueUpdated(Math.min(delayCtrl.maxValue, delayCtrl.delayValue + delayCtrl.step)) }
                }
            }
        }
    }

    // Editor JSON
    component JsonEditor: Rectangle {
        id: jsonEditor
        property alias text: editor.text
        property string placeholderText: ""
        color: settingsWin.settingsDark ? "#13151A" : "#FFFFFF"
        radius: 6
        border.color: settingsWin.uiCardBorder
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
                color: settingsWin.uiTextPrimary
                wrapMode: TextEdit.WrapAnywhere
                font.pixelSize: 12
                selectByMouse: true
            }
        }

        Text {
            anchors.fill: parent
            anchors.margins: 10
            text: jsonEditor.placeholderText
            color: settingsWin.uiTextSecondary
            wrapMode: Text.WrapAnywhere
            visible: editor.text.length === 0
            font.pixelSize: 11
        }
    }

    function dockMarginLabelText() {
        switch (dock.liveDockEdge) {
        case 1: return qsTr("Margem superior")
        case 2: return qsTr("Margem esquerda")
        case 3: return qsTr("Margem direita")
        default: return qsTr("Margem inferior")
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

    function adicionarWidgetPreset(preset) {
        let widgets = []
        try {
            widgets = JSON.parse(dock.liveWidgetsJson || "[]")
            if (!Array.isArray(widgets)) widgets = []
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
            indicatorStyle: dock.liveIndicatorStyle,
            indicatorScale: dock.liveIndicatorScale,
            scaleFactor: dock.liveScaleFactor,
            iconSpacing: dock.liveIconSpacing,
            dockMargin: dock.liveDockMargin,
            minIconSize: dock.liveMinIconSize,
            maxIconSize: dock.liveMaxIconSize,
            waveIntensity: dock.liveWaveIntensity,
            waveRadiusFactor: dock.liveWaveRadiusFactor,
            waveFalloff: dock.liveWaveFalloff,
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
            if (p.themeMode !== undefined) dock.liveThemeMode = p.themeMode
            if (p.accentMode !== undefined) dock.liveAccentMode = p.accentMode
            if (p.bg3dStyle !== undefined) dock.liveBg3dStyle = dock.normalizeBg3dStyle(p.bg3dStyle)
            if (p.bgOpacity !== undefined) dock.liveBgOpacity = p.bgOpacity
            if (p.gradientColorA !== undefined) dock.liveGradientColorA = p.gradientColorA
            if (p.gradientColorB !== undefined) dock.liveGradientColorB = p.gradientColorB
            if (p.gradientColorC !== undefined) dock.liveGradientColorC = p.gradientColorC
            if (p.gradientMix !== undefined) dock.liveGradientMix = p.gradientMix
            if (p.borderGlow !== undefined) dock.liveBorderGlow = p.borderGlow
            if (p.borderWidth !== undefined) dock.liveBorderWidth = p.borderWidth
            if (p.shadowStrength !== undefined) dock.liveShadowStrength = p.shadowStrength
            if (p.dockRadius !== undefined) dock.liveDockRadius = p.dockRadius
            if (p.monochromeIcons !== undefined) dock.liveMonochromeIcons = p.monochromeIcons
            if (p.indicatorStyle !== undefined) dock.liveIndicatorStyle = p.indicatorStyle
            if (p.indicatorScale !== undefined) dock.liveIndicatorScale = p.indicatorScale
            if (p.scaleFactor !== undefined) dock.liveScaleFactor = p.scaleFactor
            if (p.iconSpacing !== undefined) dock.liveIconSpacing = p.iconSpacing
            if (p.dockMargin !== undefined) dock.liveDockMargin = p.dockMargin
            if (p.minIconSize !== undefined) dock.liveMinIconSize = p.minIconSize
            if (p.maxIconSize !== undefined) {
                dock.liveMaxIconSize = Math.max(p.minIconSize || dock.liveMinIconSize, p.maxIconSize)
                dock.clampMaxIconSizeForZoomCap()
            }
            if (p.waveIntensity !== undefined) dock.liveWaveIntensity = p.waveIntensity
            if (p.waveRadiusFactor !== undefined) dock.liveWaveRadiusFactor = p.waveRadiusFactor
            if (p.waveFalloff !== undefined) dock.liveWaveFalloff = p.waveFalloff
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

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ================= HEADER / TOP BAR (ESTILO LATTE) =================
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: settingsWin.uiHeaderBg

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 16

                RowLayout {
                    spacing: 8
                    Text {
                        text: "AgildoDock"
                        font.pixelSize: 16
                        font.bold: true
                        color: settingsWin.uiTextPrimary
                    }
                }

                Item { Layout.fillWidth: true }

                // Seletor de Abas
                RowLayout {
                    spacing: 4

                    Rectangle {
                        implicitWidth: 120; implicitHeight: 34; radius: 6
                        color: settingsWin.activeTab === 0 ? settingsWin.uiCardBg : "transparent"
                        Text { anchors.centerIn: parent; text: qsTr("Comportamento"); font.pixelSize: 13; font.bold: settingsWin.activeTab === 0; color: settingsWin.uiTextPrimary }
                        MouseArea { anchors.fill: parent; onClicked: settingsWin.activeTab = 0 }
                    }
                    Rectangle {
                        implicitWidth: 100; implicitHeight: 34; radius: 6
                        color: settingsWin.activeTab === 1 ? settingsWin.uiCardBg : "transparent"
                        Text { anchors.centerIn: parent; text: qsTr("Aparência"); font.pixelSize: 13; font.bold: settingsWin.activeTab === 1; color: settingsWin.uiTextPrimary }
                        MouseArea { anchors.fill: parent; onClicked: settingsWin.activeTab = 1 }
                    }
                    Rectangle {
                        implicitWidth: 120; implicitHeight: 34; radius: 6
                        color: settingsWin.activeTab === 2 ? settingsWin.uiCardBg : "transparent"
                        Text { anchors.centerIn: parent; text: qsTr("Efeitos & Ajustes"); font.pixelSize: 13; font.bold: settingsWin.activeTab === 2; color: settingsWin.uiTextPrimary }
                        MouseArea { anchors.fill: parent; onClicked: settingsWin.activeTab = 2 }
                    }
                }

                Item { Layout.fillWidth: true }

                // Toggle Modo Avançado (Advanced)
                RowLayout {
                    spacing: 6
                    Label { text: qsTr("Avançado"); color: settingsWin.advancedMode ? settingsWin.uiAccent : settingsWin.uiTextSecondary; font.pixelSize: 12; font.bold: settingsWin.advancedMode }
                    Switch {
                        checked: settingsWin.advancedMode
                        onToggled: settingsWin.advancedMode = checked
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: settingsWin.uiCardBorder
            }
        }

        // ================= CONTEÚDO PRINCIPAL (ABAS) =================
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                width: settingsWin.width - 32
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Layout.topMargin: 16
                Layout.bottomMargin: 16

                Label {
                    visible: !taskBackend.windowManagementAvailable
                    text: qsTr("⚠️ Gestão de janelas indisponível: instala «kdotool» no Plasma/Wayland para suporte total.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: 12
                    color: "#F59E0B"
                    Layout.fillWidth: true
                }

                // ================= TAB 0: BEHAVIOR (COMPORTAMENTO) =================
                ColumnLayout {
                    visible: settingsWin.activeTab === 0
                    Layout.fillWidth: true
                    spacing: 16



                    // MODOS DE VISIBILIDADE (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: visCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: visCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Visibilidade"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 2
                                rowSpacing: 8
                                columnSpacing: 8

                                SegmentedButton {
                                    labelText: qsTr("Sempre Visível")
                                    selected: !dock.liveBehaviorAutoHide && !dock.liveBehaviorDodgeWindows
                                    onClicked: { dock.liveBehaviorAutoHide = false; dock.liveBehaviorDodgeWindows = false }
                                }
                                SegmentedButton {
                                    labelText: qsTr("Auto-Ocultar")
                                    selected: dock.liveBehaviorAutoHide && !dock.liveBehaviorDodgeWindows
                                    onClicked: { dock.liveBehaviorAutoHide = true; dock.liveBehaviorDodgeWindows = false }
                                }
                                SegmentedButton {
                                    labelText: qsTr("Desviar da Janela Ativa")
                                    selected: dock.liveBehaviorDodgeWindows
                                    onClicked: { dock.liveBehaviorDodgeWindows = true; dock.liveBehaviorAutoHide = false }
                                }
                                SegmentedButton {
                                    labelText: qsTr("Desviar de Maximizadas")
                                    selected: dock.liveBehaviorAutoHide && dock.liveBehaviorDodgeWindows
                                    onClicked: { dock.liveBehaviorAutoHide = true; dock.liveBehaviorDodgeWindows = true }
                                }
                            }
                        }
                    }

                    // COMPORTAMENTO DAS TAREFAS (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: appCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: appCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Label { text: qsTr("Exibição de Tarefas"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            CheckBox {
                                text: qsTr("Mostrar apps em execução não fixados (estilo macOS)")
                                checked: dock.liveBehaviorShowUnpinnedApps
                                onToggled: dock.liveBehaviorShowUnpinnedApps = checked
                                palette.text: settingsWin.uiTextPrimary
                            }
                        }
                    }

                    // ATRASOS E OPÇÕES AVANÇADAS DE JANELAS (REVELADAS PELO MODO AVANÇADO)
                    Rectangle {
                        visible: settingsWin.advancedMode
                        Layout.fillWidth: true
                        implicitHeight: actCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: actCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Label { text: qsTr("Ações e Ocultamento Avançado"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }
                                Rectangle { radius: 4; color: settingsWin.uiAccent; implicitWidth: 70; implicitHeight: 18; Text { anchors.centerIn: parent; text: "Avançado"; font.pixelSize: 10; color: "#FFF"; font.bold: true } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 24

                                DelayControl {
                                    labelText: qsTr("Atraso para ocultar:")
                                    delayValue: dock.liveBehaviorAutoHideDelayMs
                                    minValue: 100
                                    maxValue: 4000
                                    step: 50
                                    onValueUpdated: (val) => dock.liveBehaviorAutoHideDelayMs = val
                                }
                            }

                            CheckBox {
                                text: qsTr("Não roubar foco do teclado")
                                checked: dock.liveBehaviorKeepAppsFocused
                                onToggled: dock.liveBehaviorKeepAppsFocused = checked
                                palette.text: settingsWin.uiTextPrimary
                            }

                            CheckBox {
                                text: qsTr("Visão geral de janelas ao refocar no ícone (2+ janelas)")
                                checked: dock.liveBehaviorWindowOverviewOnRefocus
                                onToggled: {
                                    dock.liveBehaviorWindowOverviewOnRefocus = checked
                                    taskBackend.windowOverviewOnRefocus = checked
                                }
                                palette.text: settingsWin.uiTextPrimary
                            }

                            CheckBox {
                                text: qsTr("Lembrar apps da sessão anterior ao abrir a dock")
                                checked: dock.liveBehaviorRememberRecentApps
                                enabled: dock.liveBehaviorShowUnpinnedApps
                                onToggled: dock.liveBehaviorRememberRecentApps = checked
                                palette.text: settingsWin.uiTextPrimary
                            }

                            Rectangle { Layout.fillWidth: true; height: 1; color: settingsWin.uiCardBorder; Layout.topMargin: 4; Layout.bottomMargin: 4 }

                            // Ações de clique e scroll
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Ação clique esquerdo"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Padrão"), qsTr("Abrir menu"), qsTr("Sempre nova janela")]
                                        currentIndex: dock.liveLeftClickAction
                                        onActivated: dock.liveLeftClickAction = currentIndex
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Ação clique do meio"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Padrão"), qsTr("Fechar app"), qsTr("Nova janela"), qsTr("Minimizar/Restaurar")]
                                        currentIndex: dock.liveMiddleClickAction
                                        onActivated: dock.liveMiddleClickAction = currentIndex
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Scroll no ícone"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Alternar janelas"), qsTr("Volume"), qsTr("Brilho")]
                                        currentIndex: dock.liveScrollWheelAction
                                        onActivated: dock.liveScrollWheelAction = currentIndex
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Progresso de download"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
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
                                }
                            }
                        }
                    }
                }

                // ================= TAB 1: APPEARANCE (APARÊNCIA) =================
                ColumnLayout {
                    visible: settingsWin.activeTab === 1
                    Layout.fillWidth: true
                    spacing: 16

                    // PRESETS & TEMAS (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: presetCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: presetCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Presets e Temas"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SegmentedButton {
                                    labelText: "Vidro Escuro"
                                    selected: dock.livePresetName === "Dark Glass"
                                    onClicked: dock.applyAppearancePreset("Dark Glass")
                                }
                                SegmentedButton {
                                    labelText: "Vidro Claro"
                                    selected: dock.livePresetName === "Light Glass"
                                    onClicked: dock.applyAppearancePreset("Light Glass")
                                }
                                SegmentedButton {
                                    labelText: "Neon"
                                    selected: dock.livePresetName === "Neon"
                                    onClicked: dock.applyAppearancePreset("Neon")
                                }
                                SegmentedButton {
                                    labelText: "Minimalista"
                                    selected: dock.livePresetName === "Minimal"
                                    onClicked: dock.applyAppearancePreset("Minimal")
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Tema"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Escuro"), qsTr("Claro"), qsTr("Noite Azul"), qsTr("Ametista")]
                                        currentIndex: dock.liveThemeMode
                                        onActivated: dock.liveThemeMode = currentIndex
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Destaque"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Ciano"), qsTr("Roxo"), qsTr("Verde"), qsTr("Laranja"), qsTr("Rosa")]
                                        currentIndex: dock.liveAccentMode
                                        onActivated: dock.liveAccentMode = currentIndex
                                    }
                                }
                            }
                        }
                    }

                    // DIMENSÕES E ZOOM DA ONDA (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: dimCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: dimCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Label { text: qsTr("Dimensões, Ícones e Zoom"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Ícone base: %1 px").arg(Math.round(dock.liveMinIconSize)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider {
                                    Layout.fillWidth: true; from: 30; to: 80; stepSize: 1
                                    value: dock.liveMinIconSize
                                    onMoved: { dock.liveMinIconSize = value; dock.clampMaxIconSizeForZoomCap() }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Zoom máximo da onda: %1%").arg(Math.round(dock.liveMaxIconZoomPercent)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider {
                                    Layout.fillWidth: true; from: 0; to: 100; stepSize: 5
                                    value: dock.liveMaxIconZoomPercent
                                    onMoved: dock.setLiveMaxIconZoomPercent(value)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Escala Geral: %1%").arg(Math.round(dock.liveScaleFactor * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0.5; to: 1.8; stepSize: 0.05; value: dock.liveScaleFactor; onMoved: dock.liveScaleFactor = value }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Espaçamento dos Ícones: %1 px").arg(Math.round(dock.liveIconSpacing)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0; to: 40; stepSize: 1; value: dock.liveIconSpacing; onMoved: dock.liveIconSpacing = value }
                            }
                        }
                    }

                    // INDICADORES (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: indCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: indCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Indicadores de Tarefas"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                SegmentedButton { labelText: qsTr("Ponto"); selected: dock.liveIndicatorStyle === 0; onClicked: dock.liveIndicatorStyle = 0 }
                                SegmentedButton { labelText: qsTr("Linha"); selected: dock.liveIndicatorStyle === 1; onClicked: dock.liveIndicatorStyle = 1 }
                                SegmentedButton { labelText: qsTr("Barra"); selected: dock.liveIndicatorStyle === 2; onClicked: dock.liveIndicatorStyle = 2 }
                                SegmentedButton { labelText: qsTr("Sublinhado"); selected: dock.liveIndicatorStyle === 3; onClicked: dock.liveIndicatorStyle = 3 }
                                SegmentedButton { labelText: qsTr("Pulso"); selected: dock.liveIndicatorStyle === 4; onClicked: dock.liveIndicatorStyle = 4 }
                            }
                        }
                    }

                    // AJUSTES FINOS DE APARÊNCIA (REVELADOS PELO MODO AVANÇADO)
                    Rectangle {
                        visible: settingsWin.advancedMode
                        Layout.fillWidth: true
                        implicitHeight: advCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: advCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Label { text: qsTr("Ajustes Finos de Aparência e Geometria"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }
                                Rectangle { radius: 4; color: settingsWin.uiAccent; implicitWidth: 70; implicitHeight: 18; Text { anchors.centerIn: parent; text: "Avançado"; font.pixelSize: 10; color: "#FFF"; font.bold: true } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Estilo Fundo"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Padrão"), qsTr("Vidro")]
                                        currentIndex: dock.liveBg3dStyle === 0 ? 0 : 1
                                        onActivated: dock.liveBg3dStyle = currentIndex === 0 ? 0 : 3
                                    }
                                }

                                CheckBox {
                                    text: qsTr("Ícones monocromáticos")
                                    checked: dock.liveMonochromeIcons
                                    onToggled: dock.liveMonochromeIcons = checked
                                    palette.text: settingsWin.uiTextPrimary
                                }
                            }

                            Label { text: qsTr("Cores do Gradiente (Estilo Vidro)"); font.bold: true; font.pixelSize: 12; color: settingsWin.uiTextPrimary }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Cor A"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    TextField { Layout.fillWidth: true; text: dock.liveGradientColorA; onTextChanged: dock.liveGradientColorA = text }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Cor B"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    TextField { Layout.fillWidth: true; text: dock.liveGradientColorB; onTextChanged: dock.liveGradientColorB = text }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Cor C"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    TextField { Layout.fillWidth: true; text: dock.liveGradientColorC; onTextChanged: dock.liveGradientColorC = text }
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: dockMarginLabelText() + ": " + Math.round(dock.liveDockMargin) + " px"; color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0; to: 50; stepSize: 1; value: dock.liveDockMargin; onMoved: dock.liveDockMargin = value }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Raio dos Cantos: %1 px").arg(Math.round(dock.liveDockRadius)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 8; to: 40; stepSize: 1; value: dock.liveDockRadius; onMoved: dock.liveDockRadius = value }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Brilho da Borda: %1%").arg(Math.round(dock.liveBorderGlow * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0.05; to: 0.60; stepSize: 0.01; value: dock.liveBorderGlow; onMoved: dock.liveBorderGlow = value }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Opacidade do Fundo: %1%").arg(Math.round(dock.liveBgOpacity * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0.2; to: 1.0; stepSize: 0.05; value: dock.liveBgOpacity; onMoved: dock.liveBgOpacity = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Offset X: %1 px").arg(Math.round(dock.liveDockOffsetX)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetX; onMoved: dock.liveDockOffsetX = value }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Offset Y: %1 px").arg(Math.round(dock.liveDockOffsetY)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetY; onMoved: dock.liveDockOffsetY = value }
                                }
                            }
                        }
                    }
                }

                // ================= TAB 2: TWEAKS & ADVANCED (EFEITOS E REGRAS) =================
                ColumnLayout {
                    visible: settingsWin.activeTab === 2
                    Layout.fillWidth: true
                    spacing: 16

                    // ONDA E ANIMAÇÃO (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: waveCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: waveCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Label { text: qsTr("Efeito Magnético e Animações"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Intensidade da Onda: %1%").arg(Math.round(dock.liveWaveIntensity * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                Slider { Layout.fillWidth: true; from: 0.6; to: 1.0; stepSize: 0.02; value: dock.liveWaveIntensity; onMoved: dock.liveWaveIntensity = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Perfil de Animação"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Suave"), qsTr("Rápido"), qsTr("Elástico"), qsTr("Sem animação")]
                                        currentIndex: dock.liveAnimationProfile
                                        onActivated: dock.liveAnimationProfile = currentIndex
                                    }
                                }
                            }
                        }
                    }

                    // PERFIS RÁPIDOS (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: profCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: profCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Perfis Rápidos de Configuração"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                ActionBtn { text: qsTr("Salvar Trabalho"); onClicked: salvarPerfil("Trabalho") }
                                ActionBtn { text: qsTr("Salvar Gaming"); onClicked: salvarPerfil("Gaming") }
                                ActionBtn { text: qsTr("Salvar Streaming"); onClicked: salvarPerfil("Streaming") }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                ActionBtn { text: qsTr("Aplicar Trabalho"); onClicked: aplicarPerfil("Trabalho") }
                                ActionBtn { text: qsTr("Aplicar Gaming"); onClicked: aplicarPerfil("Gaming") }
                                ActionBtn { text: qsTr("Aplicar Streaming"); onClicked: aplicarPerfil("Streaming") }
                            }
                        }
                    }

                    // ATALHOS, REGRAS E AUTOMAÇÃO (REVELADOS PELO MODO AVANÇADO)
                    Rectangle {
                        visible: settingsWin.advancedMode
                        Layout.fillWidth: true
                        implicitHeight: advTweaksCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: 8
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: advTweaksCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Label { text: qsTr("Atalhos, Automações e JSON Avançado"); font.bold: true; font.pixelSize: 14; color: settingsWin.uiTextPrimary }
                                Rectangle { radius: 4; color: settingsWin.uiAccent; implicitWidth: 70; implicitHeight: 18; Text { anchors.centerIn: parent; text: "Avançado"; font.pixelSize: 10; color: "#FFF"; font.bold: true } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Atalho alternar dock"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    TextField { Layout.fillWidth: true; text: dock.liveToggleDockShortcut; onTextChanged: dock.liveToggleDockShortcut = text }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Atalho abrir ajustes"); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    TextField { Layout.fillWidth: true; text: dock.liveOpenSettingsShortcut; onTextChanged: dock.liveOpenSettingsShortcut = text }
                                }
                            }

                            CheckBox {
                                text: qsTr("Tema dinâmico por app em foco")
                                checked: dock.liveAutoThemeByActiveApp
                                onToggled: dock.liveAutoThemeByActiveApp = checked
                                palette.text: settingsWin.uiTextPrimary
                            }

                            CheckBox {
                                text: qsTr("Agenda automática de tema")
                                checked: dock.liveScheduleThemeEnabled
                                onToggled: dock.liveScheduleThemeEnabled = checked
                                palette.text: settingsWin.uiTextPrimary
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                visible: dock.liveScheduleThemeEnabled
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Início do dia: %1h").arg(dock.liveDayStartHour); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    Slider { Layout.fillWidth: true; from: 0; to: 23; stepSize: 1; value: dock.liveDayStartHour; onMoved: dock.liveDayStartHour = Math.round(value) }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Início da noite: %1h").arg(dock.liveNightStartHour); color: settingsWin.uiTextSecondary; font.pixelSize: 12 }
                                    Slider { Layout.fillWidth: true; from: 0; to: 23; stepSize: 1; value: dock.liveNightStartHour; onMoved: dock.liveNightStartHour = Math.round(value) }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                ActionBtn { text: qsTr("Exportar perfis"); onClicked: taskBackend.writeUserJsonFile("profiles_export.json", dock.liveProfilesJson) }
                                ActionBtn {
                                    text: qsTr("Importar perfis")
                                    onClicked: {
                                        const raw = taskBackend.readUserJsonFile("profiles_export.json")
                                        if (raw !== "") dock.liveProfilesJson = raw
                                    }
                                }
                                ActionBtn { text: qsTr("Desfazer"); onClicked: dock.undoCustomization() }
                                ActionBtn { text: qsTr("Refazer"); onClicked: dock.redoCustomization() }
                            }

                            Label { text: qsTr("Widgets/Plugins leves (JSON array)"); font.bold: true; font.pixelSize: 12; color: settingsWin.uiTextPrimary }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                ActionBtn {
                                    text: qsTr("+ Monitor")
                                    onClicked: adicionarWidgetPreset({
                                        name: qsTr("Monitor"),
                                        icon: "utilities-system-monitor",
                                        cmd: "plasma-systemmonitor"
                                    })
                                }
                                ActionBtn {
                                    text: qsTr("+ Separador")
                                    onClicked: adicionarWidgetPreset({
                                        name: qsTr("Separador"),
                                        icon: "draw-separator",
                                        type: "separator"
                                    })
                                }
                                ActionBtn {
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
                                Layout.preferredHeight: 64
                                text: dock.liveWidgetsJson
                                onTextChanged: dock.liveWidgetsJson = text
                                placeholderText: "[{\"name\":\"CPU\",\"icon\":\"utilities-system-monitor\",\"cmd\":\"plasma-systemmonitor\"}]"
                            }

                            Label { text: qsTr("Regras por app (JSON)"); font.bold: true; font.pixelSize: 12; color: settingsWin.uiTextPrimary }
                            JsonEditor {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                text: dock.liveAppRulesJson
                                onTextChanged: dock.liveAppRulesJson = text
                                placeholderText: "{\"firefox\":{\"badgeText\":\"3\"}}"
                            }

                            Label { text: qsTr("Comandos custom por app (JSON)"); font.bold: true; font.pixelSize: 12; color: settingsWin.uiTextPrimary }
                            JsonEditor {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                text: dock.liveCustomCommandsJson
                                onTextChanged: dock.liveCustomCommandsJson = text
                                placeholderText: "{\"konsole\":[{\"label\":\"Abrir htop\",\"command\":\"konsole -e htop\"}]}"
                            }
                        }
                    }
                }
            }
        }

        // ================= RODAPÉ / FOOTER (AÇÕES GLOBAIS) =================
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: settingsWin.uiHeaderBg

            Rectangle {
                anchors.top: parent.top
                width: parent.width
                height: 1
                color: settingsWin.uiCardBorder
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                ActionBtn {
                    text: qsTr("Encerrar doca")
                    onClicked: Qt.quit()
                }

                ActionBtn {
                    text: qsTr("Restaurar Padrões")
                    onClicked: settingsWin.carregarValores()
                }

                Item { Layout.fillWidth: true }

                ActionBtn {
                    text: qsTr("Cancelar")
                    onClicked: settingsWin.close()
                }

                ActionBtn {
                    text: qsTr("Aplicar & Fechar")
                    highlighted: true
                    onClicked: settingsWin.aplicarValores()
                }
            }
        }
    }
}
