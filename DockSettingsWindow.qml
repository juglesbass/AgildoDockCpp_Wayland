import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Dialogs
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
    readonly property color uiBgColor: settingsDark ? "#16181F" : "#F0F2F5"
    readonly property color uiHeaderBg: settingsDark ? "#101218" : "#E4E7EC"
    readonly property color uiCardBg: settingsDark ? "#1E2129" : "#FFFFFF"
    // Borda quase invisivel: o card passa a separar-se do fundo pelo contraste
    // e pela sombra, nao por um risco duro de 1px. Ver uiCardRadius.
    readonly property color uiCardBorder: settingsDark ? "#282C36" : "#D0D5DD"
    readonly property color uiTextPrimary: settingsDark ? "#F3F4F6" : "#111827"
    readonly property color uiTextSecondary: settingsDark ? "#9AA1AE" : "#6B7280"

    // O destaque vem da MESMA paleta que a doca usa, em vez de um azul cravado.
    // Antes o utilizador escolhia "Destaque: Roxo" e a propria janela onde fez a
    // escolha continuava azul -- a unica peca do sistema que ignorava a opcao.
    readonly property color uiAccent: DockTheme.accentPalette(dock.liveAccentMode).idle
    readonly property color uiAccentSoft: DockTheme.accentPalette(dock.liveAccentMode).focus
    // Texto sobre o destaque: as cinco cores da paleta sao claras, por isso o
    // contraste vem de escurecer, nao de branco por cima.
    readonly property color uiAccentActiveText: "#14161B"

    // ---- Escala tipografica -------------------------------------------------
    // Havia 32 usos de 12px e 11 de 14px: praticamente dois niveis para titulo,
    // rotulo, valor e descricao, todos a competir. Tres degraus claros bastam.
    readonly property int fsTitle: 15    // titulo de seccao
    readonly property int fsBody: 13     // rotulo de controlo
    readonly property int fsHint: 12     // descricao, valores, auxiliar

    // Cantos mais macios e sombra em vez de borda dura.
    readonly property int uiCardRadius: 14

    color: uiBgColor
    flags: Qt.Dialog | Qt.WindowTitleHint | Qt.WindowCloseButtonHint

    onClosing: {
        aplicarValores()
    }

    property int activeTab: 0 // 0: Behavior, 1: Appearance, 2: Tweaks

    // ---- Busca -------------------------------------------------------------
    // Sao 54 controlos espalhados por tres abas, mais os que o modo avancado
    // revela. Sem busca, encontrar uma opcao concreta obrigava a percorrer tudo.
    property string searchText: ""
    readonly property bool searching: searchText.trim().length > 0

    // Enquanto se procura, as tres abas ficam visiveis ao mesmo tempo: a opcao
    // pode estar em qualquer uma, e obrigar a adivinhar qual derrotava o efeito.
    function cardMatch(terms) {
        if (!searching)
            return true
        const q = searchText.trim().toLowerCase()
        return terms.toLowerCase().indexOf(q) !== -1
    }
    property bool advancedMode: false

    // Componente de botão segmentado reutilizável
    // Amostra de cor clicavel + campo hex.
    //
    // So' havia o campo hex. Numa aba chamada "Aparencia", escolher cor
    // escrevendo #14161A e' o oposto de pratico: nao se ve' o que se esta' a
    // escolher ate' confirmar. O hex fica, para quem quer colar um valor exacto.
    // Uma linha de contexto sob o titulo da seccao. As opcoes eram rotulos
    // nus: "Desviar da Janela Ativa" nao diz o que faz nem em que difere de
    // "Desviar de Maximizadas". Alem de esclarecer, preenche com algo util o
    // espaco que sobrava nas abas.
    component SectionHint: Label {
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        font.pixelSize: settingsWin.fsHint
        color: settingsWin.uiTextSecondary
        Layout.bottomMargin: 2
    }

    component ColorField: ColumnLayout {
        id: cf
        property string label: ""
        property string value: "#000000"
        signal edited(string novaCor)

        spacing: 4

        Label { text: cf.label; color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                width: 30; height: 30; radius: 6
                color: cf.value
                border.width: 1
                border.color: settingsWin.uiCardBorder
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: corDlg.open()
                }
            }

            TextField {
                Layout.fillWidth: true
                text: cf.value
                onTextChanged: if (text !== cf.value) cf.edited(text)
            }
        }

        ColorDialog {
            id: corDlg
            selectedColor: cf.value
            // toString() de uma cor Qt devolve #AARRGGBB; a doca guarda #RRGGBB.
            onAccepted: cf.edited("#" + selectedColor.toString().slice(3))
        }
    }

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
            font.pixelSize: settingsWin.fsHint
            font.bold: highlighted || btnMouse.containsMouse
        }

        MouseArea {
            id: btnMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            z: 10
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
                font.pixelSize: settingsWin.fsHint
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
            font.pixelSize: settingsWin.fsHint
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
                    font.pixelSize: settingsWin.fsHint
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
                font.pixelSize: settingsWin.fsHint
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
        dock.liveDockThickness = dock.appSettings.dockThickness !== undefined ? dock.appSettings.dockThickness : 68.0
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
        dock.liveWaveInertia = dock.appSettings.waveInertia !== undefined ? dock.appSettings.waveInertia : 1
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

    // Separado do aplicarValores() para existir um "Aplicar" que nao fecha.
    // O corpo e' o mesmo; a diferenca e' so' o fecho no fim daquele.
    function gravarValores() {
        try {
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
            dock.appSettings.dockThickness = dock.liveDockThickness
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
            dock.appSettings.waveInertia = dock.liveWaveInertia
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
        } catch (e) {
            taskBackend.debugLog("settings", "Aviso em aplicarValores: " + e)
        }
    }

    function aplicarValores() {
        gravarValores()
        settingsWin.visible = false
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
            dockThickness: dock.liveDockThickness,
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
            if (p.dockThickness !== undefined) dock.liveDockThickness = p.dockThickness
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
                    Rectangle {
                        width: 26; height: 26; radius: 13
                        color: "#C59B27"
                        border.color: "#E2B845"; border.width: 1
                        Text { anchors.centerIn: parent; text: "A"; font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: "#FFFFFF" }
                    }
                    Text {
                        text: "AgildoDock"
                        font.pixelSize: 15
                        font.italic: true
                        font.bold: true
                        color: settingsWin.uiTextPrimary
                    }
                }

                Item { Layout.fillWidth: true }


                // Toggle Modo Avançado (Advanced)
                RowLayout {
                    spacing: 6
                    Label { text: qsTr("Avançado"); color: settingsWin.advancedMode ? settingsWin.uiAccent : settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint; font.bold: settingsWin.advancedMode }
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

        // ================= CORPO: BARRA LATERAL + CONTEÚDO =================
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Barra lateral no lugar das abas no topo. As abas horizontais nao
            // escalam: cada categoria nova rouba largura das outras. Numa
            // coluna cabem quantas forem precisas, e a busca fica logo acima,
            // que e' onde se procura por ela.
            Rectangle {
                Layout.preferredWidth: 208
                Layout.fillHeight: true
                color: settingsWin.uiHeaderBg

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 6

                    // ---- Busca ----
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 34
                        radius: 8
                        color: settingsWin.uiCardBg
                        border.width: 1
                        border.color: buscaField.activeFocus ? settingsWin.uiAccent
                                                             : settingsWin.uiCardBorder

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 6
                            spacing: 4

                            Label {
                                text: "⌕"
                                font.pixelSize: 15
                                color: settingsWin.uiTextSecondary
                            }
                            TextField {
                                id: buscaField
                                Layout.fillWidth: true
                                placeholderText: qsTr("Procurar…")
                                text: settingsWin.searchText
                                onTextChanged: settingsWin.searchText = text
                                background: Item {}
                                color: settingsWin.uiTextPrimary
                                font.pixelSize: settingsWin.fsHint
                            }
                            Label {
                                visible: settingsWin.searching
                                text: "✕"
                                color: settingsWin.uiTextSecondary
                                font.pixelSize: settingsWin.fsHint
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { settingsWin.searchText = ""; buscaField.text = "" }
                                }
                            }
                        }
                    }

                    Item { implicitHeight: 6 }

                    // ---- Categorias ----
                    Repeater {
                        model: [qsTr("Comportamento"), qsTr("Aparência"), qsTr("Ajustes & Efeitos")]

                        Rectangle {
                            required property int index
                            required property string modelData
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: 8
                            // Enquanto se procura, nenhuma categoria fica marcada:
                            // o resultado vem de todas, e destacar uma seria mentira.
                            color: (!settingsWin.searching && settingsWin.activeTab === index)
                                   ? settingsWin.uiAccent : "transparent"

                            Label {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: parent.modelData
                                font.pixelSize: settingsWin.fsBody
                                font.weight: (!settingsWin.searching && settingsWin.activeTab === parent.index)
                                             ? Font.DemiBold : Font.Normal
                                color: (!settingsWin.searching && settingsWin.activeTab === parent.index)
                                       ? settingsWin.uiAccentActiveText : settingsWin.uiTextPrimary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    settingsWin.activeTab = parent.index
                                    settingsWin.searchText = ""
                                    buscaField.text = ""
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                }

                Rectangle {
                    anchors.right: parent.right
                    height: parent.height
                    width: 1
                    color: settingsWin.uiCardBorder
                }
            }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ScrollBar.vertical.policy: ScrollBar.AsNeeded

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 16
                spacing: 16
                Layout.topMargin: 16
                Layout.bottomMargin: 16

                Label {
                    visible: !taskBackend.windowManagementAvailable
                    text: qsTr("⚠️ Gestão de janelas indisponível: instala «kdotool» no Plasma/Wayland para suporte total.")
                    wrapMode: Text.WordWrap
                    font.pixelSize: settingsWin.fsHint
                    color: "#F59E0B"
                    Layout.fillWidth: true
                }

                // ================= TAB 0: BEHAVIOR (COMPORTAMENTO) =================
                ColumnLayout {
                    // Durante a busca a aba so' aparece se algo nela bater;
                    // caso contrario ficava um bloco vazio a ocupar o ecra.
                    visible: settingsWin.searching ? settingsWin.cardMatch("posicao doca inferior superior esquerda direita visibilidade ocultar auto-ocultar desviar janela maximizada tarefas apps execucao fixados macos acoes clique atraso")
                                                   : settingsWin.activeTab === 0
                    Layout.fillWidth: true
                    spacing: 16

                    // POSIÇÃO DA DOCA (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: posCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("posicao doca lado inferior superior esquerda direita orientacao")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: posCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Posição da Doca"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("Em que borda do ecrã a doca fica ancorada.") }

                            GridLayout {
                                Layout.fillWidth: true
                                columns: 4
                                rowSpacing: 8
                                columnSpacing: 8

                                SegmentedButton {
                                    labelText: qsTr("▾ Inferior")
                                    selected: dock.liveDockEdge === 0
                                    onClicked: dock.liveDockEdge = 0
                                }
                                SegmentedButton {
                                    labelText: qsTr("◂ Esquerda")
                                    selected: dock.liveDockEdge === 1
                                    onClicked: dock.liveDockEdge = 1
                                }
                                SegmentedButton {
                                    labelText: qsTr("▴ Superior")
                                    selected: dock.liveDockEdge === 2
                                    onClicked: dock.liveDockEdge = 2
                                }
                                SegmentedButton {
                                    labelText: qsTr("▸ Direita")
                                    selected: dock.liveDockEdge === 3
                                    onClicked: dock.liveDockEdge = 3
                                }
                            }
                        }
                    }

                    // MODOS DE VISIBILIDADE (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: visCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("visibilidade ocultar auto-ocultar esconder desviar janela maximizada mostrar")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: visCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Visibilidade"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("Quando a doca aparece e se cede espaço às janelas.") }

                            // Uma linha, igual a "Posicao da Doca" logo acima.
                            // Eram dois grupos da mesma natureza -- escolha
                            // unica entre quatro -- desenhados de formas
                            // diferentes: um em linha, outro em grelha 2x2.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

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

                            // Sao quatro botoes lado a lado, sem espaco para uma
                            // descricao debaixo de cada um. Uma linha so', que
                            // acompanha a escolha, explica sem ocupar quatro vezes.
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: settingsWin.fsHint
                                color: settingsWin.uiTextSecondary
                                text: {
                                    if (dock.liveBehaviorAutoHide && dock.liveBehaviorDodgeWindows)
                                        return qsTr("Recolhe apenas quando existe uma janela maximizada. Nos restantes casos fica visível.")
                                    if (dock.liveBehaviorDodgeWindows)
                                        return qsTr("Recolhe quando a janela em foco se aproxima da doca, mesmo sem estar maximizada.")
                                    if (dock.liveBehaviorAutoHide)
                                        return qsTr("Fica recolhida e volta ao aproximar o rato da borda. Não reserva espaço às janelas.")
                                    return qsTr("Sempre à vista. Reserva espaço no ecrã: as janelas param antes de a alcançar.")
                                }
                            }
                        }
                    }

                    // COMPORTAMENTO DAS TAREFAS (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: appCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("tarefas apps execucao nao fixados macos exibicao")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: appCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Label { text: qsTr("Exibição de Tarefas"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("O que mostrar além dos ícones que fixaste.") }

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
                        // So' no modo avancado, e ainda assim so' se a busca bater.
                        visible: settingsWin.advancedMode && settingsWin.cardMatch("acoes clique ocultamento avancado atraso delay botao")
                        Layout.fillWidth: true
                        implicitHeight: actCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: actCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            RowLayout {
                                Label { text: qsTr("Ações e Ocultamento Avançado"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                                SectionHint { text: qsTr("Cliques do rato e tempos de resposta ao ocultar.") }
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
                                    Label { text: qsTr("Ação clique esquerdo"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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
                                    Label { text: qsTr("Ação clique do meio"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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
                                    Label { text: qsTr("Scroll no ícone"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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
                                    Label { text: qsTr("Progresso de download"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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

                // ================= TAB 1: APPEARANCE (APARÊNCIA ESTILO LATTE) =================
                ColumnLayout {
                    // Durante a busca a aba so' aparece se algo nela bater;
                    // caso contrario ficava um bloco vazio a ocupar o ecra.
                    visible: settingsWin.searching ? settingsWin.cardMatch("aparencia presets temas vidro escuro claro liquido neon minimalista tema destaque cor itens tamanho absoluto zoom mouse comprimento maximo plano fundo contorno opacidade gradiente indicadores geometria margem espacamento raio")
                                                   : settingsWin.activeTab === 1

                    // ---- Prévia ao vivo -------------------------------------
                    // Os controlos ja' aplicavam ao vivo na doca de verdade, mas
                    // a doca fica atras desta janela: para ver o efeito era
                    // preciso arrastar a janela para o lado ou fecha-la. Aqui a
                    // mudanca ve-se sem sair de onde se esta' a mexer.
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 132
                        radius: settingsWin.uiCardRadius
                        color: settingsWin.uiHeaderBg
                        border.width: 1
                        border.color: settingsWin.uiCardBorder
                        clip: true

                        // Xadrez discreto por tras: sem ele, uma doca muito
                        // transparente ficaria indistinguivel do fundo do card
                        // e a opacidade nao se perceberia.
                        Canvas {
                            anchors.fill: parent
                            opacity: 0.5
                            onPaint: {
                                const ctx = getContext("2d")
                                const t = 10
                                ctx.clearRect(0, 0, width, height)
                                for (let y = 0; y < height; y += t)
                                    for (let x = 0; x < width; x += t) {
                                        ctx.fillStyle = ((x / t + y / t) % 2 === 0)
                                            ? "#20242C" : "#191C22"
                                        ctx.fillRect(x, y, t, t)
                                    }
                            }
                        }

                        // A barra da doca
                        Rectangle {
                            id: previewBar
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 32, previewRow.width + 28)
                            height: previewRow.height + 16
                            radius: Math.min(height / 2, dock.liveDockRadius)
                            opacity: dock.liveBgOpacity
                            border.width: dock.liveBorderWidth
                            border.color: Qt.rgba(1, 1, 1, dock.liveBorderGlow)

                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: dock.liveGradientColorA }
                                GradientStop { position: dock.liveGradientMix; color: dock.liveGradientColorB }
                                GradientStop { position: 1.0; color: dock.liveGradientColorC }
                            }

                            Behavior on radius { NumberAnimation { duration: 120 } }
                            Behavior on opacity { NumberAnimation { duration: 120 } }
                        }

                        // Os icones. O do meio aparece ampliado, para o zoom
                        // maximo ser visivel sem precisar de passar o rato.
                        Row {
                            id: previewRow
                            anchors.centerIn: previewBar
                            spacing: dock.liveIconSpacing

                            Repeater {
                                model: 7
                                Rectangle {
                                    required property int index
                                    readonly property bool destaque: index === 3
                                    readonly property real base: dock.liveMinIconSize
                                    width: destaque
                                        ? Math.min(dock.liveMaxIconSize,
                                                   base * (1 + dock.liveMaxIconZoomPercent / 100))
                                        : base
                                    height: width
                                    radius: width * 0.28
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: destaque ? settingsWin.uiAccent : settingsWin.uiAccentSoft
                                    opacity: destaque ? 1.0 : 0.55
                                    Behavior on width { NumberAnimation { duration: 120 } }
                                }
                            }
                        }

                        Label {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 10
                            text: qsTr("Prévia")
                            font.pixelSize: settingsWin.fsHint
                            color: settingsWin.uiTextSecondary
                        }
                    }
                    Layout.fillWidth: true
                    spacing: 20

                    // SEÇÃO 0: ESTILOS PREDEFINIDOS (PRESETS)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: qsTr("Presets e Temas")
                            font.pixelSize: 18
                            font.bold: true
                            color: settingsWin.uiTextPrimary
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            SegmentedButton {
                                labelText: qsTr("Vidro Escuro")
                                selected: dock.livePresetName === "Dark Glass"
                                onClicked: dock.applyAppearancePreset("Dark Glass")
                            }

                            SegmentedButton {
                                labelText: qsTr("Vidro Claro")
                                selected: dock.livePresetName === "Light Glass"
                                onClicked: dock.applyAppearancePreset("Light Glass")
                            }

                            SegmentedButton {
                                labelText: qsTr("Vidro Líquido")
                                selected: dock.livePresetName === "Liquid Glass"
                                onClicked: dock.applyAppearancePreset("Liquid Glass")
                            }

                            SegmentedButton {
                                labelText: qsTr("Neon")
                                selected: dock.livePresetName === "Neon"
                                onClicked: dock.applyAppearancePreset("Neon")
                            }

                            SegmentedButton {
                                labelText: qsTr("Minimalista")
                                selected: dock.livePresetName === "Minimal"
                                onClicked: dock.applyAppearancePreset("Minimal")
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Tema"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Escuro"), qsTr("Claro"), qsTr("Escuro Translúcido"), qsTr("Neon")]
                                    currentIndex: dock.liveThemeMode
                                    onActivated: dock.liveThemeMode = currentIndex
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Destaque"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                ComboBox {
                                    Layout.fillWidth: true
                                    model: [qsTr("Ciano"), qsTr("Roxo"), qsTr("Verde"), qsTr("Laranja"), qsTr("Rosa")]
                                    currentIndex: dock.liveAccentMode
                                    onActivated: dock.liveAccentMode = currentIndex
                                }
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: settingsWin.uiCardBorder }

                    // SEÇÃO 1: ITENS (ESTILO IMAGEM REFERÊNCIA)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: qsTr("Itens")
                            font.pixelSize: 18
                            font.bold: true
                            color: settingsWin.uiTextPrimary
                        }

                        Label {
                            text: qsTr("Tamanho")
                            font.pixelSize: settingsWin.fsHint
                            color: settingsWin.uiTextSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        LatteSliderRow {
                            labelText: qsTr("Absoluto")
                            valueText: Math.round(dock.liveMinIconSize) + " px."
                            fromValue: 30
                            toValue: 80
                            stepValue: 1
                            currentValue: dock.liveMinIconSize
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => { dock.liveMinIconSize = val; dock.clampMaxIconSizeForZoomCap() }
                        }

                        Label {
                            text: qsTr("Efeitos")
                            font.pixelSize: settingsWin.fsHint
                            color: settingsWin.uiTextSecondary
                            Layout.alignment: Qt.AlignHCenter
                        }

                        LatteSliderRow {
                            labelText: qsTr("Zoom ao passar o mouse")
                            valueText: Math.round(dock.liveMaxIconZoomPercent) + " %"
                            fromValue: 0
                            toValue: 100
                            stepValue: 5
                            currentValue: dock.liveMaxIconZoomPercent
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => dock.setLiveMaxIconZoomPercent(val)
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: settingsWin.uiCardBorder }

                    // SEÇÃO 2: COMPRIMENTO (ESTILO IMAGEM REFERÊNCIA)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Label {
                            text: qsTr("Comprimento")
                            font.pixelSize: 18
                            font.bold: true
                            color: settingsWin.uiTextPrimary
                        }

                        LatteSliderRow {
                            labelText: qsTr("Máximo")
                            valueText: Math.round(dock.liveScaleFactor * 100) + " %"
                            fromValue: 0.5
                            toValue: 1.8
                            stepValue: 0.05
                            currentValue: dock.liveScaleFactor
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => dock.liveScaleFactor = val
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: settingsWin.uiCardBorder }

                    // SEÇÃO 3: PLANO DE FUNDO (ESTILO IMAGEM REFERÊNCIA)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            Label {
                                text: qsTr("Plano de fundo")
                                font.pixelSize: 18
                                font.bold: true
                                color: settingsWin.uiTextPrimary
                            }
                            Item { Layout.fillWidth: true }
                            Switch {
                                checked: dock.liveBg3dStyle !== 0
                                onToggled: dock.liveBg3dStyle = checked ? 3 : 0
                            }
                        }

                        LatteSliderRow {
                            labelText: qsTr("Tamanho")
                            valueText: Math.round(dock.liveDockThickness) + " px."
                            fromValue: 4
                            toValue: 120
                            stepValue: 1
                            currentValue: dock.liveDockThickness
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => dock.liveDockThickness = val
                        }

                        LatteSliderRow {
                            labelText: qsTr("Contorno")
                            valueText: Math.round(dock.liveDockRadius) + " px."
                            fromValue: 8
                            toValue: 40
                            stepValue: 1
                            currentValue: dock.liveDockRadius
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => dock.liveDockRadius = val
                        }

                        LatteSliderRow {
                            labelText: qsTr("Opacidade")
                            valueText: Math.round(dock.liveBgOpacity * 100) + " %"
                            fromValue: 0.2
                            toValue: 1.0
                            stepValue: 0.05
                            currentValue: dock.liveBgOpacity
                            uiTextPrimary: settingsWin.uiTextPrimary
                            uiAccent: settingsWin.uiAccent
                            settingsDark: settingsWin.settingsDark
                            onMoved: (val) => dock.liveBgOpacity = val
                        }

                        Label {
                            text: qsTr("Cores do Gradiente (Estilo Vidro)")
                            font.pixelSize: settingsWin.fsBody
                            font.bold: true
                            color: settingsWin.uiTextPrimary
                            Layout.topMargin: 4
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColorField {
                                Layout.fillWidth: true
                                label: qsTr("Cor A")
                                value: dock.liveGradientColorA
                                onEdited: (c) => dock.liveGradientColorA = c
                            }

                            ColorField {
                                Layout.fillWidth: true
                                label: qsTr("Cor B")
                                value: dock.liveGradientColorB
                                onEdited: (c) => dock.liveGradientColorB = c
                            }

                            ColorField {
                                Layout.fillWidth: true
                                label: qsTr("Cor C")
                                value: dock.liveGradientColorC
                                onEdited: (c) => dock.liveGradientColorC = c
                            }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: settingsWin.uiCardBorder }

                    // INDICADORES (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: indCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("indicadores pontos luz tarefas abertas estilo")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: indCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Indicadores de Tarefas"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("A marca que assinala uma aplicação aberta.") }

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
                }

                // ================= TAB 2: TWEAKS & ADVANCED (EFEITOS E REGRAS) =================
                ColumnLayout {
                    // Durante a busca a aba so' aparece se algo nela bater;
                    // caso contrario ficava um bloco vazio a ocupar o ecra.
                    visible: settingsWin.searching ? settingsWin.cardMatch("ajustes efeitos magnetico onda animacao inercia perfil suave perfis rapidos trabalho gaming streaming salvar aplicar atalhos automacoes json encerrar doca")
                                                   : settingsWin.activeTab === 2
                    Layout.fillWidth: true
                    spacing: 16

                    // ONDA E ANIMAÇÃO (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: waveCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("efeito magnetico onda animacao inercia zoom ampliacao perfil suave")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: waveCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            Label { text: qsTr("Efeito Magnético e Animações"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("Como os ícones reagem ao rato e a que velocidade.") }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Intensidade da Onda: %1%").arg(Math.round(dock.liveWaveIntensity * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                Slider { Layout.fillWidth: true; from: 0.6; to: 1.0; stepSize: 0.02; value: dock.liveWaveIntensity; onMoved: dock.liveWaveIntensity = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Inércia da Onda (Resposta)"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                    ComboBox {
                                        Layout.fillWidth: true
                                        model: [qsTr("Rápida / Instantânea (Estilo macOS)"), qsTr("Suave (Padrão)"), qsTr("Amanteigada / Fluida")]
                                        currentIndex: dock.liveWaveInertia
                                        onActivated: dock.liveWaveInertia = currentIndex
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Perfil de Animação"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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

                    // Card vindo da aba "Aparencia". Aquela transbordava e
                    // precisava de rolagem, enquanto esta e a "Comportamento"
                    // ficavam com metade da janela vazia. Alem do equilibrio,
                    // "Ajustes Finos" pertence por nome a "Ajustes & Efeitos".
                    Rectangle {
                        // So' no modo avancado, e ainda assim so' se a busca bater.
                        visible: settingsWin.advancedMode && settingsWin.cardMatch("ajustes finos aparencia geometria margem espacamento raio borda")
                        Layout.fillWidth: true
                        implicitHeight: advCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: advCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Label { text: qsTr("Ajustes Finos de Aparência e Geometria"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                                SectionHint { text: qsTr("Detalhes de fundo, margem e deslocamento da doca.") }
                                Rectangle { radius: 4; color: settingsWin.uiAccent; implicitWidth: 70; implicitHeight: 18; Text { anchors.centerIn: parent; text: "Avançado"; font.pixelSize: 10; color: "#FFF"; font.bold: true } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Estilo Fundo"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: dockMarginLabelText() + ": " + Math.round(dock.liveDockMargin) + " px"; color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                Slider { Layout.fillWidth: true; from: 0; to: 50; stepSize: 1; value: dock.liveDockMargin; onMoved: dock.liveDockMargin = value }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Label { text: qsTr("Brilho da Borda: %1%").arg(Math.round(dock.liveBorderGlow * 100)); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                Slider { Layout.fillWidth: true; from: 0.05; to: 0.60; stepSize: 0.01; value: dock.liveBorderGlow; onMoved: dock.liveBorderGlow = value }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Offset X: %1 px").arg(Math.round(dock.liveDockOffsetX)); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                    Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetX; onMoved: dock.liveDockOffsetX = value }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Offset Y: %1 px").arg(Math.round(dock.liveDockOffsetY)); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                    Slider { Layout.fillWidth: true; from: -300; to: 300; stepSize: 1; value: dock.liveDockOffsetY; onMoved: dock.liveDockOffsetY = value }
                                }
                            }
                        }
                    }

                    // PERFIS RÁPIDOS (BÁSICO)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: profCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        // Filtro da busca: o card some quando o texto procurado nao bate.
                        visible: settingsWin.cardMatch("perfis rapidos trabalho gaming streaming salvar aplicar preset")
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: profCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 10

                            Label { text: qsTr("Perfis Rápidos de Configuração"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                            SectionHint { text: qsTr("Guarda a configuração atual e volta a ela num clique.") }

                            // Uma linha por perfil, em vez de duas grelhas de
                            // tres botoes ("Salvar X" numa, "Aplicar X" noutra).
                            // Eram seis botoes para tres perfis, e obrigava a
                            // ler o nome duas vezes para encontrar o certo.
                            Repeater {
                                model: [qsTr("Trabalho"), qsTr("Gaming"), qsTr("Streaming")]

                                RowLayout {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Label {
                                        text: parent.modelData
                                        color: settingsWin.uiTextPrimary
                                        font.pixelSize: settingsWin.fsBody
                                        Layout.preferredWidth: 110
                                    }

                                    Item { Layout.fillWidth: true }

                                    ActionBtn {
                                        text: qsTr("Aplicar")
                                        onClicked: aplicarPerfil(parent.modelData)
                                    }
                                    ActionBtn {
                                        text: qsTr("Salvar")
                                        onClicked: salvarPerfil(parent.modelData)
                                    }
                                }
                            }
                        }
                    }

                    // ENCERRAR A DOCA — accao destrutiva, longe dos botoes normais
                    Rectangle {
                        // So' no modo avancado, e ainda assim so' se a busca bater.
                        visible: settingsWin.advancedMode && settingsWin.cardMatch("atalhos automacoes json avancado teclas")
                        Layout.fillWidth: true
                        implicitHeight: quitCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiCardBorder

                        ColumnLayout {
                            id: quitCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8

                            Label {
                                text: qsTr("Encerrar a doca")
                                font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle
                                color: settingsWin.uiTextPrimary
                            }
                            Label {
                                text: qsTr("Fecha a doca por completo. Para a trazer de volta, reinicie o serviço ou volte a executá-la.")
                                font.pixelSize: settingsWin.fsHint
                                color: settingsWin.uiTextSecondary
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                Item { Layout.fillWidth: true }

                                // Confirmacao em dois passos. Antes este botao
                                // vivia no rodape, encostado ao "Restaurar
                                // Padroes" e a dois do "Cancelar": um clique ao
                                // lado fechava a doca sem aviso nenhum.
                                ActionBtn {
                                    id: quitBtn
                                    property bool armed: false
                                    text: armed ? qsTr("Confirmar encerramento") : qsTr("Encerrar doca")
                                    highlighted: armed
                                    onClicked: {
                                        if (armed) {
                                            Qt.quit()
                                        } else {
                                            armed = true
                                            quitDisarm.restart()
                                        }
                                    }
                                    Timer {
                                        id: quitDisarm
                                        interval: 4000
                                        onTriggered: quitBtn.armed = false
                                    }
                                }
                            }
                        }
                    }

                    // ATALHOS, REGRAS E AUTOMAÇÃO (REVELADOS PELO MODO AVANÇADO)
                    Rectangle {
                        visible: settingsWin.advancedMode
                        Layout.fillWidth: true
                        implicitHeight: advTweaksCol.implicitHeight + 24
                        color: settingsWin.uiCardBg
                        radius: settingsWin.uiCardRadius
                        border.color: settingsWin.uiAccent

                        ColumnLayout {
                            id: advTweaksCol
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 12

                            RowLayout {
                                Label { text: qsTr("Atalhos, Automações e JSON Avançado"); font.weight: Font.DemiBold; font.pixelSize: settingsWin.fsTitle; color: settingsWin.uiTextPrimary }
                                Rectangle { radius: 4; color: settingsWin.uiAccent; implicitWidth: 70; implicitHeight: 18; Text { anchors.centerIn: parent; text: "Avançado"; font.pixelSize: 10; color: "#FFF"; font.bold: true } }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Atalho alternar dock"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                    TextField { Layout.fillWidth: true; text: dock.liveToggleDockShortcut; onTextChanged: dock.liveToggleDockShortcut = text }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Atalho abrir ajustes"); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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
                                    Label { text: qsTr("Início do dia: %1h").arg(dock.liveDayStartHour); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
                                    Slider { Layout.fillWidth: true; from: 0; to: 23; stepSize: 1; value: dock.liveDayStartHour; onMoved: dock.liveDayStartHour = Math.round(value) }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: qsTr("Início da noite: %1h").arg(dock.liveNightStartHour); color: settingsWin.uiTextSecondary; font.pixelSize: settingsWin.fsHint }
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

                            Label { text: qsTr("Widgets/Plugins leves (JSON array)"); font.bold: true; font.pixelSize: settingsWin.fsHint; color: settingsWin.uiTextPrimary }

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

                            Label { text: qsTr("Regras por app (JSON)"); font.bold: true; font.pixelSize: settingsWin.fsHint; color: settingsWin.uiTextPrimary }
                            JsonEditor {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                text: dock.liveAppRulesJson
                                onTextChanged: dock.liveAppRulesJson = text
                                placeholderText: "{\"firefox\":{\"badgeText\":\"3\"}}"
                            }

                            Label { text: qsTr("Comandos custom por app (JSON)"); font.bold: true; font.pixelSize: settingsWin.fsHint; color: settingsWin.uiTextPrimary }
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

                // "Encerrar doca" saiu daqui de proposito. Fechava a doca
                // inteira e estava encostado ao "Restaurar Padroes", a dois
                // botoes do "Cancelar" -- um clique ao lado e a doca desaparecia.
                // Passou para a seccao avancada, com confirmacao.
                ActionBtn {
                    text: qsTr("Restaurar Padrões")
                    onClicked: settingsWin.carregarValores()
                }

                Item { Layout.fillWidth: true }

                ActionBtn {
                    text: qsTr("Cancelar")
                    onClicked: {
                        settingsWin.visible = false
                        settingsWin.close()
                    }
                }

                // Os controlos ja' aplicam ao vivo, mas so' havia como confirmar
                // saindo. Para acertar o visual era preciso fechar, olhar e
                // reabrir a cada ajuste.
                ActionBtn {
                    text: qsTr("Aplicar")
                    onClicked: settingsWin.gravarValores()
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
