import QtQuick

// Componente encarregado do armazenamento, manipulação e persistência dos modelos da doca.
QtObject {
    id: storeRoot

    required property var dockRoot

    // Modelos
    readonly property ListModel launcherModel: ListModel {
        ListElement {
            name: qsTr("Menu de Aplicativos")
            icon: "start-here-kde"
            cmd: "qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.activateLauncherMenu"
            isLauncher: true
        }
    }
    readonly property ListModel appModel: ListModel {}
    readonly property ListModel dynamicModel: ListModel {}
    readonly property ListModel systemModel: ListModel {}

    // Ponto de acoplamento único e explícito para a física e layout
    readonly property int totalItemsCount: launcherModel.count + appModel.count + dynamicModel.count + systemModel.count

    // Timers de manutenção dos modelos
    property var ghostClearTimer: Timer {
        interval: 40000
        repeat: false
        running: false
        onTriggered: storeRoot.clearGhostApps()
    }

    property var saveFlushTimer: Timer {
        interval: 350
        repeat: false
        running: false
        onTriggered: {
            if (typeof dockSettings !== "undefined" && dockSettings && typeof dockSettings.sync === "function") {
                dockSettings.sync()
            }
        }
    }

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

    function saveLastSeenDynamic() {
        if (!dockRoot.liveBehaviorRememberRecentApps) return
        let apps = []
        for (let i = 0; i < dynamicModel.count; i++) {
            let e = dynamicModel.get(i)
            if (!e.isGhost) {
                apps.push({ name: e.name, icon: e.icon, cmd: e.cmd })
            }
        }
        taskBackend.writeUserJsonFile("last_seen_dynamic.json", JSON.stringify(apps))
    }

    function loadLastSeenDynamic() {
        if (!dockRoot.liveBehaviorRememberRecentApps) return
        let raw = taskBackend.readUserJsonFile("last_seen_dynamic.json")
        if (!raw || raw === "") return
        let apps = []
        try { apps = JSON.parse(raw) } catch (e) { return }
        for (let i = 0; i < apps.length; i++) {
            let a = apps[i]
            if (!a.cmd || !a.name) continue
            if (isCommandPinned(a.cmd)) continue
            dynamicModel.append({
                name: a.name, icon: a.icon || "", cmd: a.cmd,
                isDynamic: true, removing: false, isGhost: true
            })
        }
    }

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

    function reloadCustomWidgets() {
        for (let i = systemModel.count - 1; i >= 0; i--) {
            if (systemModel.get(i).isWidget === true) {
                systemModel.remove(i)
            }
        }
        try {
            let arr = JSON.parse(dockRoot.liveWidgetsJson || "[]")
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
        const norm = dockRoot.normalizeAppCommandKey(cmd)
        for (let i = 0; i < appModel.count; i++) {
            const pinned = appModel.get(i).cmd
            if (pinned === cmd) {
                return true
            }
            if (norm.length > 0 && dockRoot.normalizeAppCommandKey(pinned) === norm) {
                return true
            }
        }
        return false
    }

    function updateDynamicApps() {
        if (!dockRoot.liveBehaviorShowUnpinnedApps) {
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
            let rule = dockRoot.appRuleForCommand(rawRunning[k].cmd)
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
                if (row.isGhost === true) continue
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
        const norm = dockRoot.normalizeAppCommandKey(cmd)
        for (let i = 0; i < systemModel.count; i++) {
            const item = systemModel.get(i)
            if (!item || !item.cmd) {
                continue
            }
            if (item.cmd === cmd) {
                return true
            }
            if (norm.length > 0 && dockRoot.normalizeAppCommandKey(item.cmd) === norm) {
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
            arr = JSON.parse(dockRoot.liveWidgetsJson || "[]")
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
        dockRoot.liveWidgetsJson = JSON.stringify(arr)
        dockSettings.userWidgetsJson = dockRoot.liveWidgetsJson
        if (typeof dockSettings.sync === "function") {
            dockSettings.sync()
        }
        taskBackend.writeUserJsonFile("widgets.json", dockRoot.liveWidgetsJson)
        reloadCustomWidgets()
        return true
    }

    function addWidgetShortcutFromDesktopUrl(urlStr) {
        const info = taskBackend.parseDropInfo(urlStr)
        return addWidgetShortcutFromDesktopUrlInfo(info)
    }

    function addPlasmoidFromDropInfo(info) {
        if (!info) return false
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

        try {
            let arr = JSON.parse(dockRoot.liveWidgetsJson || "[]")
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
                    dockRoot.liveWidgetsJson = JSON.stringify(arr)
                    dockSettings.userWidgetsJson = dockRoot.liveWidgetsJson
                    if (typeof dockSettings.sync === "function") dockSettings.sync()
                    taskBackend.writeUserJsonFile("widgets.json", dockRoot.liveWidgetsJson)
                    reloadCustomWidgets()
                    removed = true
                }
            }
        } catch (e) {
            taskBackend.debugLog("persist", "Erro ao remover de widgets.json: " + e)
        }

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
}
