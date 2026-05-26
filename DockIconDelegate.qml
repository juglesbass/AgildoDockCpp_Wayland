import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Item {
    id: delegateRoot

    required property var dock
    required property int index
    required property var model

    // Comando da app — o «model» do ListModel perde-se dentro de Menu/Repeater.
    readonly property string itemCmd: (model.isSeparator === true || model.cmd === undefined)
        ? "" : String(model.cmd)

    property bool isRunning: false
    property bool isFocused: false
    property bool isDynamicItem: model.isDynamic === true
    property bool isSystemItem: model.isSystem === true
    property bool isLauncherItem: model.isLauncher === true
    property bool isSeparator: model.isSeparator === true
    property bool isPinned: !isDynamicItem && !isSystemItem && !isLauncherItem
    property int itemIndex: index
    property bool isLaunching: false
    property int windowCount: 0
    property bool isValid: isSeparator || (model.name !== undefined && model.icon !== "")
    property bool scheduledRemove: model.removing === true

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
        if (mouseArea.containsMouse && !hoverDelay.running) {
            refreshNameTip()
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
        if (dock.waveAmplitude === 0.0 || maxSize <= minSize) {
            return minSize
        }
        var dist = Math.abs(dock.logicalMouseX - myLogicalCenter)
        var wRadius = dock.baseStride * dock.dockWaveRadiusStrideFactor
        if (dist >= wRadius) {
            return minSize
        }
        var factor = Math.cos((dist / wRadius) * (Math.PI / 2))
        return minSize + ((maxSize - minSize) * factor * dock.waveAmplitude)
    }

    width: isValid ? (isSeparator ? dock.dividerWidth : (targetIconSize + (15 * dock.liveScaleFactor))) : 0

    Behavior on width {
        enabled: dock.waveAmplitude > 0.02 && !mouseArea.drag.active
        NumberAnimation {
            duration: 90
            easing.type: Easing.OutCubic
        }
    }
    height: isValid ? (dock.dockBarHeightPx * dock.liveScaleFactor) : 0

    Connections {
        target: taskBackend
        function onWindowsUpdated() {
            if (!isLauncherItem && delegateRoot.isValid) {
                delegateRoot.isRunning = taskBackend.isAppRunning(delegateRoot.itemCmd)
                delegateRoot.isFocused = delegateRoot.isRunning ? taskBackend.isAppFocused(delegateRoot.itemCmd) : false
                if (delegateRoot.isRunning && dock.liveShowWindowBadge && !isSystemItem) {
                    delegateRoot.windowCount = taskBackend.windowCountForCommand(delegateRoot.itemCmd)
                } else {
                    delegateRoot.windowCount = 0
                }
            }
        }
    }

    Component.onCompleted: {
        if (!isLauncherItem && delegateRoot.isValid) {
            delegateRoot.isRunning = taskBackend.isAppRunning(delegateRoot.itemCmd)
            delegateRoot.isFocused = delegateRoot.isRunning ? taskBackend.isAppFocused(delegateRoot.itemCmd) : false
            if (delegateRoot.isRunning && dock.liveShowWindowBadge && !isSystemItem) {
                delegateRoot.windowCount = taskBackend.windowCountForCommand(delegateRoot.itemCmd)
            }
        }
    }

    function refreshNameTip() {
        if (!mouseArea.containsMouse || dock.dockContextMenuOpen || mouseArea.drag.active) {
            dock.hideDockIconTip()
            return
        }
        var status = ""
        var statusColor = "#00E5FF"
        var hint = ""
        if (!isLauncherItem && !isSystemItem) {
            if (delegateRoot.isFocused) {
                status = "● " + qsTr("Em foco")
                statusColor = "#00FFCC"
            } else if (delegateRoot.isRunning) {
                status = "● " + qsTr("Em execução")
                if (delegateRoot.windowCount > 1) {
                    status += " (" + delegateRoot.windowCount + ")"
                }
            } else if (isDynamicItem) {
                hint = qsTr("Clique para fixar na doca")
            }
        }
        dock.showDockIconTip(appIcon, model.name, status, statusColor, hint)
    }

    Item {
        id: visualItem
        width: parent.width
        height: parent.height
        z: mouseArea.drag.active ? 10 : 0

        transform: Translate {
            id: visualEntrySlide
            y: 0
        }

        // Sem Behavior em visualItem.y: OutBack + y=0 após drag lutava com visualEntrySlide / entrada dinâmica.
        scale: 0.0
        opacity: 0.0

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
                to: 1.0
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

        Drag.active: mouseArea.drag.active
        Drag.source: delegateRoot
        Drag.keys: ["appItemDrag"]
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        Timer {
            id: hoverDelay
            interval: 320
            running: mouseArea.containsMouse && !dock.dockContextMenuOpen && !mouseArea.drag.active
            repeat: false
            onTriggered: delegateRoot.refreshNameTip()
        }

        Rectangle {
            visible: isSeparator
            width: Math.max(2, Math.round(2 * dock.liveScaleFactor))
            height: parent.height * 0.45
            anchors.centerIn: parent
            color: "#30FFFFFF"
            radius: 1
        }

        Kirigami.Icon {
            id: appIcon
            visible: !isSeparator
            source: model.icon
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

            Behavior on scale {
                enabled: dock.waveAmplitude > 0.02 && !mouseArea.drag.active
                NumberAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
            transformOrigin: Item.Bottom
            x: Math.round((parent.width - maxVisualSize) / 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10 * dock.liveScaleFactor

            transform: Translate {
                id: bounceTranslate
                y: 0
            }

            SequentialAnimation {
                id: singleJumpAnim
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: -14 * dock.liveScaleFactor
                    duration: 140
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: 300
                    easing.type: Easing.OutBounce
                }
            }

            SequentialAnimation {
                id: launchAnim
                loops: Animation.Infinite
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: -20 * dock.liveScaleFactor
                    duration: 240
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: 240
                    easing.type: Easing.InQuad
                }
            }

            SequentialAnimation {
                id: stopLaunchAnim
                NumberAnimation {
                    target: bounceTranslate
                    property: "y"
                    to: 0
                    duration: 120
                    easing.type: Easing.OutBounce
                }
            }
        }

        Rectangle {
            id: activeIndicator
            x: Math.round((parent.width - width) / 2)
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 2 * dock.liveScaleFactor
            width: delegateRoot.isFocused ? (18 * dock.liveScaleFactor) : (6 * dock.liveScaleFactor)
            height: delegateRoot.isFocused ? (4 * dock.liveScaleFactor) : (6 * dock.liveScaleFactor)
            radius: delegateRoot.isFocused ? (2 * dock.liveScaleFactor) : (3 * dock.liveScaleFactor)
            color: delegateRoot.isFocused ? "#00FFCC" : "#00E5FF"
            opacity: delegateRoot.isRunning ? 1.0 : 0.0

            Behavior on width {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutBack
                }
            }
            Behavior on height {
                NumberAnimation {
                    duration: 280
                    easing.type: Easing.OutBack
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.InOutQuad
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: 280
                }
            }
        }

        Rectangle {
            visible: dock.liveShowWindowBadge && delegateRoot.windowCount > 1
                     && !isLauncherItem && !isSystemItem
            z: 50
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 2 * dock.liveScaleFactor
            anchors.rightMargin: 4 * dock.liveScaleFactor
            width: Math.max(14, countLabel.implicitWidth + 8) * dock.liveScaleFactor
            height: Math.max(14, countLabel.implicitHeight + 4) * dock.liveScaleFactor
            radius: height * 0.45
            color: "#E53935"
            border.color: "#FFFFFF"
            border.width: 1

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: delegateRoot.windowCount > 9 ? "9+" : String(delegateRoot.windowCount)
                color: "#FFFFFF"
                font.bold: true
                font.pixelSize: 10 * dock.liveScaleFactor
            }
        }

        MouseArea {
            id: mouseArea
            z: 100
            anchors.fill: parent
            anchors.topMargin: -Math.max(0, delegateRoot.targetIconSize - delegateRoot.height + (10 * dock.liveScaleFactor))
            anchors.bottomMargin: -40
            anchors.leftMargin: -dock.baseSpacing / 2
            anchors.rightMargin: -dock.baseSpacing / 2
            enabled: !dock.dockContextMenuOpen
            hoverEnabled: enabled
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            drag.target: delegateRoot.isPinned ? visualItem : null
            drag.axis: Drag.XAxis

            function updateLogicalMouse(mx) {
                if (dock.dockContextMenuOpen) {
                    return
                }
                var logicalStart = delegateRoot.myLogicalX - (dock.baseSpacing / 2)
                var logicalWidth = dock.baseItemWidth + dock.baseSpacing
                var lxRaw = logicalStart + ((mx / width) * logicalWidth)
                if (dock.waveAmplitude > 0.02) {
                    // Onda activa: posição por ícone (suave, sem quantizar).
                    var beta = 0.14
                    if (dock.logicalMouseX > -100) {
                        dock.logicalMouseX = dock.logicalMouseX + (lxRaw - dock.logicalMouseX) * beta
                    } else {
                        dock.logicalMouseX = lxRaw
                    }
                    return
                }
                if (dock.dockHovered) {
                    return
                }
                dock.logicalMouseX = lxRaw
            }

            onPositionChanged: (mouse) => {
                updateLogicalMouse(mouse.x)
                if (mouseArea.containsMouse && !hoverDelay.running && !dock.dockContextMenuOpen && !mouseArea.drag.active) {
                    delegateRoot.refreshNameTip()
                }
                if (mouseArea.drag.active && delegateRoot.isPinned) {
                    var jumpLimit = dock.baseStride * 0.60
                    while (visualItem.x > jumpLimit && delegateRoot.itemIndex < dock.appModel.count - 1) {
                        dock.appModel.move(delegateRoot.itemIndex, delegateRoot.itemIndex + 1, 1)
                        visualItem.x -= dock.baseStride
                    }
                    while (visualItem.x < -jumpLimit && delegateRoot.itemIndex > 0) {
                        dock.appModel.move(delegateRoot.itemIndex, delegateRoot.itemIndex - 1, 1)
                        visualItem.x += dock.baseStride
                    }
                }
            }

            onEntered: updateLogicalMouse(mouseX)

            onContainsMouseChanged: {
                if (!mouseArea.containsMouse) {
                    dock.hideDockIconTip()
                }
            }

            onReleased: {
                if (visualItem.Drag.active || visualItem.x !== 0) {
                    visualItem.Drag.drop()
                    visualItem.x = 0
                    visualItem.y = 0
                    dock.saveApps()
                }
            }

            onClicked: (mouse) => {
                if (isSeparator) {
                    return
                }
                if (mouse.button === Qt.RightButton) {
                    dock.showIconContextMenu(appIcon, {
                        cmd: delegateRoot.itemCmd,
                        name: model.name,
                        icon: model.icon,
                        logicalCenter: delegateRoot.myLogicalCenter,
                        isLauncher: isLauncherItem,
                        isSeparator: isSeparator,
                        isSystem: isSystemItem,
                        isDynamic: isDynamicItem,
                        isRunning: delegateRoot.isRunning,
                        isFocused: delegateRoot.isFocused,
                        windowCount: delegateRoot.windowCount,
                        itemIndex: delegateRoot.itemIndex,
                        delegate: delegateRoot
                    })
                    return
                }
                if (mouse.button === Qt.MiddleButton) {
                    if (dock.liveMiddleClickCloses && !isLauncherItem && !isSystemItem) {
                        taskBackend.closeApp(delegateRoot.itemCmd, true)
                        delegateRoot.isRunning = false
                        delegateRoot.isFocused = false
                        delegateRoot.windowCount = 0
                    }
                    return
                }
                if (delegateRoot.isLaunching) {
                    return
                }
                if (!isLauncherItem && !delegateRoot.isRunning) {
                    delegateRoot.isLaunching = true
                    launchAnim.start()
                } else {
                    singleJumpAnim.start()
                }
                taskBackend.launchApp(delegateRoot.itemCmd)
            }
        }

        Item {
            id: wheelCapture
            z: 99
            anchors.fill: mouseArea
            enabled: mouseArea.enabled
            WheelHandler {
                // WheelHandler não tem anchors/z — a área é o Item pai (wheelCapture).
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => {
                    if (isLauncherItem || isSystemItem || !delegateRoot.isRunning) {
                        return
                    }
                    if (delegateRoot.windowCount <= 1) {
                        return
                    }
                    taskBackend.cycleAppWindows(delegateRoot.itemCmd, event.angleDelta.y < 0)
                    event.accepted = true
                }
            }
        }
    }
}
