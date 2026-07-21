import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: delegateRoot

    required property var dock
    required property int index
    required property var model

    property bool isRunning: false
    property bool isFocused: false
    readonly property bool isGhost: model.isGhost === true
    property bool isDynamicItem: model.isDynamic === true
    property bool isSystemItem: model.isSystem === true
    property bool isLauncherItem: model.isLauncher === true
    property bool isPinned: !isDynamicItem && !isSystemItem && !isLauncherItem
    property int itemIndex: index
    property bool isLaunching: false
    property int windowCount: 0
    property bool isValid: model.name !== undefined && model.icon !== ""
    property bool scheduledRemove: model.removing === true
    property bool reorderDragging: false
    property var appRule: dock.appRuleForCommand(model.cmd)

    // Barra de progresso — estado local; permanece visível na onda (sem Loader)
    property real downloadProgress: 0
    property bool downloadProgressVisible: false
    property color downloadProgressColor: dock.accentFocus
    property string downloadProgressIcon: ""
    property string downloadProgressFileName: ""
    readonly property bool isDownloadsSystemItem: isSystemItem && model.icon === "folder-downloads"
    readonly property bool showDownloadFileIcon: downloadProgressVisible
        && dock.liveDownloadProgressDisplayMode === 2
        && downloadProgressFileName.length > 0
        && downloadProgressIcon.length > 0
        && isDownloadsSystemItem
        && !downloadCompleteFlash
    property bool downloadCompleteFlash: false

    function syncDownloadProgress() {
        if (!model.cmd) {
            if (downloadProgressVisible)
                downloadProgressVisible = false
            return
        }
        const lp = taskBackend.launcherProgress[model.cmd]
        const visible = lp !== undefined && lp.progressVisible === true
        if (visible) {
            const p = Math.max(0, Math.min(1, Number(lp.progress) || 0))
            const rule = dock.appRuleForCommand(model.cmd)
            const color = rule.progressColor ? rule.progressColor : dock.accentFocus
            const icon = lp.progressIcon !== undefined ? String(lp.progressIcon) : ""
            const fileName = lp.progressFileName !== undefined ? String(lp.progressFileName) : ""
            if (!downloadProgressVisible) {
                downloadProgressVisible = true
                downloadProgress = p
                downloadProgressColor = color
                downloadProgressIcon = icon
                downloadProgressFileName = fileName
            } else {
                if (downloadProgress !== p)
                    downloadProgress = p
                if (downloadProgressColor !== color)
                    downloadProgressColor = color
                if (icon.length > 0 && downloadProgressIcon !== icon)
                    downloadProgressIcon = icon
                if (downloadProgressFileName !== fileName)
                    downloadProgressFileName = fileName
            }
        } else if (downloadProgressVisible) {
            downloadProgressVisible = false
            downloadProgressIcon = ""
            downloadProgressFileName = ""
            if (isDownloadsSystemItem) {
                downloadCompleteFlash = true
                downloadFolderFlashTimer.restart()
            }
        }
    }

    Timer {
        id: downloadFolderFlashTimer
        interval: dock.animationDuration(700)
        repeat: false
        onTriggered: delegateRoot.downloadCompleteFlash = false
    }

    Accessible.role: Accessible.Button
    Accessible.name: isValid && model.name !== undefined ? model.name : ""
    Accessible.description: isLauncherItem ? qsTr("Lançador na doca")
    : isSystemItem ? qsTr("Item de sistema")
    : isDynamicItem ? qsTr("Aplicação em execução (área dinâmica)")
    : qsTr("Aplicação fixada na doca")
    Accessible.focusable: isValid

    visible: isValid

    onScheduledRemoveChanged: {
        if (scheduledRemove && isDynamicItem) {
            exitAnim.start()
        } else if (!scheduledRemove && isDynamicItem) {
            exitAnim.stop()
            visualItem.scale = 1
            visualItem.opacity = 1
            visualEntrySlide.y = 0
        }
    }

    onIsRunningChanged: {
        if (isRunning) {
            refreshWindowCount()
        } else {
            windowCount = 0
        }
        if (isRunning && isLaunching) {
            delegateRoot.isLaunching = false
            launchAnim.stop()
            stopLaunchAnim.start()
        }
        if (mouseArea.containsMouse && !hoverDelay.running) {
            refreshNameTip()
        }
    }

    onIsFocusedChanged: {
        if (isFocused) {
            dock.applyThemeForCommand(model.cmd)
        }
        if (mouseArea.containsMouse && !hoverDelay.running) {
            refreshNameTip()
        }
    }

    function refreshWindowCount() {
        if (!delegateRoot.isRunning || !model.cmd) {
            delegateRoot.windowCount = 0
            return
        }
        delegateRoot.windowCount = taskBackend.appWindowCount(model.cmd)
    }

    Connections {
        target: taskBackend
        function onWindowsUpdated() {
            if (dock.waveBlurAnimating)
                return
            if (delegateRoot.isRunning) {
                delegateRoot.refreshWindowCount()
            }
        }
        function onNotificationBadgesChanged() {
            // força reavaliação de appRule (badge de notificação)
        }
        function onLauncherProgressForCommandChanged(cmd) {
            if (cmd === model.cmd)
                delegateRoot.syncDownloadProgress()
        }
    }

    Connections {
        target: dock
        function onWaveBlurAnimatingChanged() {
            if (!dock.waveBlurAnimating)
                delegateRoot.syncDownloadProgress()
        }
    }

    Timer {
        id: launchTimeoutTimer
        interval: 12000
        running: delegateRoot.isLaunching
        onTriggered: {
            delegateRoot.isLaunching = false
            launchAnim.stop()
            stopLaunchAnim.start()
        }
    }

    property real myLogicalX: {
        if (isLauncherItem) {
            return itemIndex * dock.baseStride
        }
        if (isSystemItem) {
            return ((dock.launcherModel.count + dock.appModel.count + dock.dynamicModel.count) * dock.baseStride)
            + ((dock.div1Count * dock.dividerWidth) + (dock.div2Count * dock.dividerWidth))
            + (itemIndex * dock.baseStride)
        }
        if (isDynamicItem) {
            return ((dock.launcherModel.count + dock.appModel.count) * dock.baseStride)
            + (dock.div1Count * dock.dividerWidth) + (itemIndex * dock.baseStride)
        }
        return (dock.launcherModel.count * dock.baseStride) + (itemIndex * dock.baseStride)
    }

    property real myLogicalCenter: myLogicalX + (dock.baseItemWidth / 2)

    property real targetIconSize: {
        var minSize = dock.baseMinSize
        var maxSize = Math.max(dock.liveMinIconSize, dock.liveMaxIconSize) * dock.liveScaleFactor
        var effAmp = Math.max(0.0, Math.min(1.0, dock.waveAmplitude * dock.liveWaveIntensity))
        if (effAmp === 0.0 || maxSize <= minSize) {
            return minSize
        }
        var dist = Math.abs(dock.logicalMouseX - myLogicalCenter)
        var wRadius = dock.baseStride * dock.dockWaveRadiusStrideFactor
        if (dist >= wRadius) {
            return minSize
        }
        var curveT = Math.max(0, Math.min(1, dist / wRadius))
        var factor = Math.pow(Math.cos(curveT * (Math.PI / 2)), Math.max(0.2, dock.liveWaveFalloff))
        var v = minSize + ((maxSize - minSize) * factor * effAmp)
        // Passos de 0,5px no tamanho lógico: menos variação frame-a-frame do scale do ícone na onda.
        if (effAmp > 0.02) {
            return Math.round(v * 2) / 2
        }
        return v
    }

    width: isValid ? (targetIconSize + (15 * dock.liveScaleFactor)) : 0
    height: isValid ? (dock.dockBarHeightPx * dock.liveScaleFactor) : 0
    z: reorderDragging ? 5000 : 0

    Connections {
        target: taskBackend
        function onWindowsUpdated() {
            if (!isLauncherItem && delegateRoot.isValid) {
                delegateRoot.isRunning = taskBackend.isAppRunning(model.cmd)
                delegateRoot.isFocused = delegateRoot.isRunning ? taskBackend.isAppFocused(model.cmd) : false
            }
        }
    }

    Component.onCompleted: {
        syncDownloadProgress()
        if (!isLauncherItem && delegateRoot.isValid) {
            delegateRoot.isRunning = taskBackend.isAppRunning(model.cmd)
            delegateRoot.isFocused = delegateRoot.isRunning ? taskBackend.isAppFocused(model.cmd) : false
        }
    }

    Timer {
        id: waylandGeometrySyncTimer
        interval: 1000
        running: delegateRoot.isRunning && delegateRoot.isValid && !dock.waveBlurAnimating
        repeat: true
        onTriggered: {
            if (typeof taskBackend.reportIconGeometry === "function") {
                var pt = delegateRoot.mapToItem(null, 0, 0)
                taskBackend.reportIconGeometry(model.cmd, Math.round(pt.x), Math.round(pt.y), Math.round(delegateRoot.width), Math.round(delegateRoot.height))
            }
        }
    }

    function playFocusBounce() {
        singleJumpAnim.start()
    }

    function refreshNameTip() {
        if (!mouseArea.containsMouse || dock.dockContextMenuOpen || delegateRoot.reorderDragging) {
            dock.hideDockIconTip()
            return
        }
        var status = ""
        var statusColor = dock.accentIdle
        var hint = ""
        if (!isLauncherItem && !isSystemItem) {
            if (delegateRoot.isFocused) {
                status = "● " + qsTr("Em foco")
                statusColor = dock.accentFocus
            } else if (delegateRoot.isRunning) {
                status = "● " + qsTr("Em execução")
            } else if (isDynamicItem) {
                hint = qsTr("Clique para fixar na doca")
            }
        }
        if (downloadProgressVisible && downloadProgressFileName.length > 0 && isDownloadsSystemItem) {
            const pct = Math.round(downloadProgress * 100)
            dock.showDockIconTip(appIcon, downloadProgressFileName,
                                 qsTr("A transferir… %1%").arg(pct), dock.accentFocus, "")
            return
        }
        dock.showDockIconTip(appIcon, model.name, status, statusColor, hint)
    }

    Item {
        id: visualItem
        width: parent.width
        height: parent.height
        z: delegateRoot.reorderDragging ? 10 : 0

        property real entryOpacity: delegateRoot.isGhost ? 0.35 : 1.0
        opacity: entryOpacity
        scale: 0.0

        transform: [
            Translate {
                id: visualEntrySlide
                y: 0
            },
            Scale {
                id: dragLift
                origin.x: visualItem.width / 2
                origin.y: visualItem.height - (12 * dock.liveScaleFactor)
                xScale: delegateRoot.reorderDragging ? 1.14 : 1.0
                yScale: delegateRoot.reorderDragging ? 1.14 : 1.0
                Behavior on xScale {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.06 }
                }
                Behavior on yScale {
                    NumberAnimation { duration: 240; easing.type: Easing.OutBack; easing.overshoot: 1.06 }
                }
            }
        ]

        Behavior on opacity {
            enabled: !delegateRoot.isGhost && !delegateRoot.reorderDragging
            NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
        }

        Component.onCompleted: {
            if (delegateRoot.isDynamicItem) {
                visualEntrySlide.y = 22 * dock.liveScaleFactor
                dynamicEntryAnim.start()
            } else {
                entryAnim.start()
            }
        }

        ParallelAnimation {
            id: entryAnim
            NumberAnimation {
                target: visualItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: 420
                easing.type: Easing.OutBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: visualItem
                property: "opacity"
                from: 0.0
                to: visualItem.entryOpacity
                duration: 280
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: dynamicEntryAnim
            NumberAnimation {
                target: visualEntrySlide
                property: "y"
                from: 22 * dock.liveScaleFactor
                to: 0
                duration: 520
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: visualItem
                property: "scale"
                from: 0.0
                to: 1.0
                duration: 520
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: visualItem
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: 480
                easing.type: Easing.OutCubic
            }
        }

        ParallelAnimation {
            id: exitAnim
            onFinished: {
                if (delegateRoot.scheduledRemove && model.removing === true) {
                    dock.finalizeDynamicRemove(model.cmd)
                }
            }
            NumberAnimation {
                target: visualEntrySlide
                property: "y"
                to: 18 * dock.liveScaleFactor
                duration: 380
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: visualItem
                property: "scale"
                to: 0.45
                duration: 380
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: visualItem
                property: "opacity"
                to: 0.0
                duration: 360
                easing.type: Easing.InOutCubic
            }
        }

        Drag.active: delegateRoot.reorderDragging
        Drag.source: delegateRoot
        Drag.keys: ["appItemDrag"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Timer {
            id: hoverDelay
            interval: 200
            running: mouseArea.containsMouse && !dock.dockContextMenuOpen && !delegateRoot.reorderDragging
            repeat: false
            onTriggered: delegateRoot.refreshNameTip()
        }

        Kirigami.Icon {
            id: appIcon
            source: delegateRoot.showDownloadFileIcon ? delegateRoot.downloadProgressIcon : model.icon
            // Padrão true: arredonda a 32/48/64… do tema; a onda volta a escalar → menos nitidez.
            roundToIconSize: false
            // Mesmo critério que o pico da onda em targetIconSize (evita scale>1 se min>max nas definições).
            property real maxVisualSize: Math.round(
                Math.max(dock.liveMinIconSize, dock.liveMaxIconSize) * dock.liveScaleFactor)
            width: maxVisualSize
            height: maxVisualSize
            scale: delegateRoot.targetIconSize / maxVisualSize
            smooth: true
            antialiasing: true
            color: dock.liveMonochromeIcons ? (delegateRoot.isFocused ? dock.accentFocus : dock.themeTextPrimary) : "transparent"
            transformOrigin: Item.Bottom
            x: Math.round((parent.width - maxVisualSize) / 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * dock.liveScaleFactor

            // Sombra suave ao arrastar (efeito “levitar”).
            Rectangle {
                visible: delegateRoot.reorderDragging
                z: -1
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: Math.round(2 * dock.liveScaleFactor)
                width: Math.round(parent.width * 0.72)
                height: Math.max(5, Math.round(7 * dock.liveScaleFactor))
                radius: height / 2
                color: "#000000"
                opacity: 0.42
                scale: 1.0 + Math.min(0.25, Math.max(Math.abs(visualItem.x), Math.abs(visualItem.y)) / Math.max(1, dock.baseStride))

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }
            }

            transform: Translate {
                id: bounceTranslate
                y: 0
            }

            SequentialAnimation {
                id: singleJumpAnim
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: -14 * dock.liveScaleFactor * dock.liveLaunchBounceIntensity
                    duration: dock.animationDuration(140)
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: dock.animationDuration(300)
                    easing.type: Easing.OutBounce
                }
            }

            SequentialAnimation {
                id: launchAnim
                loops: Animation.Infinite
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: -20 * dock.liveScaleFactor * dock.liveLaunchBounceIntensity
                    duration: dock.animationDuration(240)
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: dock.animationDuration(240)
                    easing.type: Easing.InQuad
                }
            }

            SequentialAnimation {
                id: stopLaunchAnim
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: dock.animationDuration(120)
                    easing.type: Easing.OutBounce
                }
            }
        }

        Rectangle {
            id: activeIndicator
            x: Math.round((parent.width - width) / 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2 * dock.liveScaleFactor
            width: {
                const scale = dock.liveIndicatorScale
                if (dock.liveIndicatorStyle === 1) return (22 * dock.liveScaleFactor) * scale
                if (dock.liveIndicatorStyle === 2) return (26 * dock.liveScaleFactor) * scale
                if (dock.liveIndicatorStyle === 3) return (30 * dock.liveScaleFactor) * scale
                return (delegateRoot.isFocused ? 18 : 6) * dock.liveScaleFactor * scale
            }
            height: {
                const scale = dock.liveIndicatorScale
                if (dock.liveIndicatorStyle === 1) return (2 * dock.liveScaleFactor) * scale
                if (dock.liveIndicatorStyle === 2) return (6 * dock.liveScaleFactor) * scale
                if (dock.liveIndicatorStyle === 3) return (1.5 * dock.liveScaleFactor) * scale
                return (delegateRoot.isFocused ? 4 : 6) * dock.liveScaleFactor * scale
            }
            radius: Math.max(1, height / 2)
            color: delegateRoot.isFocused
                   ? (appRule.indicatorColorFocused ? appRule.indicatorColorFocused : dock.accentFocus)
                   : (appRule.indicatorColor ? appRule.indicatorColor : dock.accentIdle)
            opacity: delegateRoot.isRunning ? 1.0 : 0.0
            scale: (dock.liveIndicatorStyle === 4 && delegateRoot.isRunning) ? (delegateRoot.isFocused ? 1.12 : 1.0) : 1.0

            Behavior on width  { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            Behavior on height { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad } }
            Behavior on color  { ColorAnimation  { duration: 280 } }
        }

        // Ripple de confirmação de clique — expande e desaparece ao lançar um app
        Rectangle {
            id: ripple
            anchors.horizontalCenter: appIcon.horizontalCenter
            anchors.verticalCenter: appIcon.verticalCenter
            width: Math.round(delegateRoot.targetIconSize * 1.1)
            height: width
            radius: width / 2
            color: "transparent"
            border.color: Qt.rgba(1, 1, 1, 0.55)
            border.width: Math.max(1, Math.round(1.5 * dock.liveScaleFactor))
            scale: 0.0
            opacity: 0.0
            z: 8

            function play() {
                rippleScaleAnim.restart()
                rippleOpacityAnim.restart()
            }

            NumberAnimation {
                id: rippleScaleAnim
                target: ripple
                property: "scale"
                from: 0.4
                to: 1.5
                duration: 480
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                id: rippleOpacityAnim
                target: ripple
                property: "opacity"
                from: 0.7
                to: 0.0
                duration: 480
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            visible: delegateRoot.windowCount >= 2 && dock.liveBehaviorWindowOverviewOnRefocus
            anchors.left: appIcon.left
            anchors.bottom: appIcon.bottom
            anchors.leftMargin: -3
            anchors.bottomMargin: -2
            width: Math.max(14, winCountLabel.implicitWidth + 8)
            height: 14
            radius: 7
            color: "#455A64"
            border.color: "#88FFFFFF"
            border.width: 1
            z: 5

            Text {
                id: winCountLabel
                anchors.centerIn: parent
                text: String(delegateRoot.windowCount)
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }

        Rectangle {
            visible: appRule && appRule.badgeText !== undefined && String(appRule.badgeText).length > 0
            anchors.right: appIcon.right
            anchors.top: appIcon.top
            anchors.rightMargin: -4
            anchors.topMargin: -2
            width: Math.max(14, badgeLabel.implicitWidth + 8)
            height: 14
            radius: 7
            color: appRule.badgeColor ? appRule.badgeColor : "#E53935"
            border.color: "#88FFFFFF"
            border.width: 1

            Text {
                id: badgeLabel
                anchors.centerIn: parent
                text: String(appRule.badgeText)
                color: "white"
                font.pixelSize: 9
                font.bold: true
            }
        }

        Item {
            id: progressBarRoot
            visible: downloadProgressVisible
            z: 6
            anchors.horizontalCenter: appIcon.horizontalCenter
            anchors.bottom: appIcon.bottom
            anchors.bottomMargin: 1 * dock.liveScaleFactor
            width: Math.round(appIcon.width * appIcon.scale * 0.84)
            height: Math.max(2, Math.round(3 * dock.liveScaleFactor))

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: "#55000000"
            }
            Rectangle {
                height: parent.height
                width: Math.max(0, Math.round(parent.width * downloadProgress))
                radius: height / 2
                color: downloadProgressColor

                Behavior on width {
                    enabled: !dock.waveBlurAnimating
                    NumberAnimation {
                        duration: dock.animationDuration(120)
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // MouseArea fora do visualItem: arrastar o filho a partir daqui funciona no Wayland.
    MouseArea {
        id: mouseArea
        z: 100
        anchors.fill: parent
        anchors.topMargin: -Math.max(0, delegateRoot.targetIconSize - delegateRoot.height + (10 * dock.liveScaleFactor))
        anchors.bottomMargin: -40
        anchors.leftMargin: -dock.baseSpacing / 2
        anchors.rightMargin: -dock.baseSpacing / 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        propagateComposedEvents: false

        readonly property real reorderDragThreshold: Math.max(8, Math.round(14 * dock.liveScaleFactor))
        property bool suppressNextClick: false
        property int reorderStartIndex: delegateRoot.itemIndex
        property real reorderPressAxis: 0

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: (event) => {
                if (!delegateRoot.isRunning || delegateRoot.isLaunching || delegateRoot.reorderDragging) {
                    return
                }
                const delta = event.angleDelta.y > 0 ? 1 : -1
                if (dock.liveScrollWheelAction === 0) {
                    taskBackend.cycleAppWindows(model.cmd, delta)
                } else if (dock.liveScrollWheelAction === 1) {
                    taskBackend.adjustVolume(delta)
                } else {
                    taskBackend.adjustBrightness(delta)
                }
                event.accepted = true
            }
        }

        function updateLogicalMouse(mx, my) {
            if (dock.dockHovered || dock.waveAmplitude > 0.02) {
                return
            }
            var logicalStart = delegateRoot.myLogicalX - (dock.baseSpacing / 2)
            var logicalWidth = dock.baseItemWidth + dock.baseSpacing
            if (dock.dockLayoutVertical) {
                dock.logicalMouseX = logicalStart + ((my / height) * logicalWidth)
            } else {
                dock.logicalMouseX = logicalStart + ((mx / width) * logicalWidth)
            }
        }

        onPressed: (mouse) => {
            if (mouse.button !== Qt.LeftButton) {
                return
            }
            if (delegateRoot.isPinned) {
                reorderStartIndex = delegateRoot.itemIndex
                reorderPressAxis = dock.dockLayoutVertical ? mouse.y : mouse.x
                delegateRoot.reorderDragging = false
            }
        }

        onPositionChanged: (mouse) => {
            updateLogicalMouse(mouse.x, mouse.y)

            if ((mouse.buttons & Qt.LeftButton) && delegateRoot.isPinned) {
                const curAxis = dock.dockLayoutVertical ? mouse.y : mouse.x
                const delta = curAxis - reorderPressAxis
                if (!delegateRoot.reorderDragging && Math.abs(delta) >= reorderDragThreshold) {
                    delegateRoot.reorderDragging = true
                    dock.hideDockIconTip()
                    dock.waveAmplitude = 0
                }
                if (delegateRoot.reorderDragging) {
                    if (dock.dockLayoutVertical) {
                        visualItem.y = delta
                    } else {
                        visualItem.x = delta
                    }
                }
            }

            if (mouseArea.containsMouse && !hoverDelay.running && !dock.dockContextMenuOpen && !delegateRoot.reorderDragging) {
                delegateRoot.refreshNameTip()
            }
        }

        onEntered: updateLogicalMouse(mouseX, mouseY)

        onContainsMouseChanged: {
            if (!mouseArea.containsMouse) {
                dock.hideDockIconTip()
            }
        }

        onReleased: (mouse) => {
            if (delegateRoot.reorderDragging) {
                suppressNextClick = true
                const startIdx = reorderStartIndex
                const axisOffset = dock.dockLayoutVertical ? visualItem.y : visualItem.x
                const stride = dock.baseStride
                const delta = Math.round(axisOffset / stride)
                const target = Math.max(0, Math.min(dock.appModel.count - 1, startIdx + delta))

                // Reordena primeiro; reset visual depois — evita “voltar ao slot antigo e saltar”.
                if (target !== startIdx) {
                    dock.appModel.move(startIdx, target, 1)
                    dock.saveApps()
                }

                visualItem.x = 0
                visualItem.y = 0
                delegateRoot.reorderDragging = false
                if (dock.dockHovered) {
                    dock.waveAmplitude = 1.0
                }
                mouse.accepted = true
                return
            }
            if (visualItem.x !== 0 || visualItem.y !== 0) {
                visualItem.x = 0
                visualItem.y = 0
            }
        }

        onClicked: (mouse) => {
            if (suppressNextClick) {
                suppressNextClick = false
                return
            }
            if (mouse.button === Qt.RightButton) {
                dock.showIconContextMenu(appIcon, {
                    cmd: model.cmd,
                    name: model.name,
                    icon: model.icon,
                    logicalCenter: delegateRoot.myLogicalCenter,
                    isLauncher: isLauncherItem,
                    isSeparator: false,
                    isSystem: isSystemItem,
                    isDynamic: isDynamicItem,
                    isRunning: delegateRoot.isRunning,
                    isFocused: delegateRoot.isFocused,
                    itemIndex: delegateRoot.itemIndex,
                    delegate: delegateRoot
                })
                return
            }
            if (mouse.button === Qt.MiddleButton) {
                const midAct = dock.effectiveMiddleClickAction(model.cmd)
                if (midAct === 1) {
                    taskBackend.closeApp(model.cmd)
                    return
                }
                if (midAct === 2) {
                    taskBackend.forceLaunchApp(model.cmd)
                    return
                }
                if (midAct === 3 && delegateRoot.isRunning) {
                    taskBackend.launchApp(model.cmd)
                    return
                }
                return
            }
            if (delegateRoot.isLaunching) {
                return
            }
            const leftAct = dock.effectiveLeftClickAction(model.cmd)
            if (leftAct === 1) {
                dock.showIconContextMenu(appIcon, {
                    cmd: model.cmd,
                    name: model.name,
                    icon: model.icon,
                    logicalCenter: delegateRoot.myLogicalCenter,
                    isLauncher: isLauncherItem,
                    isSeparator: false,
                    isSystem: isSystemItem,
                    isDynamic: isDynamicItem,
                    isRunning: delegateRoot.isRunning,
                    isFocused: delegateRoot.isFocused,
                    itemIndex: delegateRoot.itemIndex,
                    delegate: delegateRoot
                })
                return
            }
            if (leftAct === 2) {
                taskBackend.forceLaunchApp(model.cmd)
                return
            }
            ripple.play()
            if (!isLauncherItem && !delegateRoot.isRunning) {
                delegateRoot.isLaunching = true
                launchAnim.start()
            } else {
                if (typeof taskBackend.reportIconGeometry === "function" && !isLauncherItem) {
                    var pt = delegateRoot.mapToItem(null, 0, 0)
                    taskBackend.reportIconGeometry(model.cmd, Math.round(pt.x), Math.round(pt.y), Math.round(delegateRoot.width), Math.round(delegateRoot.height))
                }
                singleJumpAnim.start()
            }
            if (!isLauncherItem && !isSystemItem && delegateRoot.isFocused) {
                const willMinimize = !dock.liveBehaviorWindowOverviewOnRefocus
                        || taskBackend.appWindowCount(model.cmd) < 2
                if (willMinimize) {
                    dock.playMinimizeSuckAt(appIcon)
                }
            }
            taskBackend.launchApp(model.cmd)
        }
    }
}
