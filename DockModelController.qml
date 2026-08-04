import QtQuick

Item {
    id: modelCtrl
    required property var dockRoot

    property string liveProfilesJson: "{}"

    property string liveAppRulesJson: "{}"

    property string liveCustomCommandsJson: "{}"

    property string liveWidgetsJson: "[]"

    readonly property alias ghostClearTimer: ghostClearTimer
    readonly property alias saveFlushTimer: saveFlushTimer

    Timer {
        id: ghostClearTimer
        interval: DockConstants.ghostAppClearTimeoutMs
        repeat: false
        onTriggered: clearGhostApps()
    }

    Timer {
        id: saveFlushTimer
        interval: DockConstants.saveSettingsFlushDelayMs
        repeat: false
        onTriggered: {
            let list = []
            for (let i = 0; i < appModel.count; i++) {
                let e = appModel.get(i)
                list.push({ name: e.name, icon: e.icon, cmd: e.cmd })
            }
            let text = JSON.stringify({ version: 2, savedAt: Date.now(), apps: list })
            dockRoot.dockSettings.dockApps = text
            if (typeof dockRoot.dockSettings.sync === "function") dockRoot.dockSettings.sync()
            taskBackend.saveDockAppsSnapshot(text)
        }
    }






    ListModel { id: _launcherModel }
    ListModel { id: _appModel }
    ListModel { id: _dynamicModel }
    ListModel { id: _systemModel }

    readonly property alias launcherModel: _launcherModel
    readonly property alias appModel: _appModel
    readonly property alias dynamicModel: _dynamicModel
    readonly property alias systemModel: _systemModel


    function customCommandsFor(cmd) {
        try {
            let parsed = JSON.parse(liveCustomCommandsJson || "{}")
            let arr = parsed[cmd]
            return Array.isArray(arr) ? arr : []
        } catch (e) {
            return []
        }
    }

    function normalizeAppCommandKey(cmd) {
        if (!cmd) {
            return ""
        }
        let token = String(cmd).trim().toLowerCase().split(/\s+/)[0] || ""
        const slash = token.lastIndexOf("/")
        if (slash >= 0) {
            token = token.substring(slash + 1)
        }
        return token.replace(/['"]/g, "")
    }

    function appRuleForCommand(cmd) {
        try {
            let parsed = JSON.parse(liveAppRulesJson || "{}")
            const norm = normalizeAppCommandKey(cmd)
            let rule = parsed[cmd]
            if (!rule && norm.length > 0) {
                for (let key in parsed) {
                    if (normalizeAppCommandKey(key) === norm) {
                        rule = parsed[key]
                        break
                    }
                }
            }
            rule = rule && typeof rule === "object" ? Object.assign({}, rule) : {}
            const nb = taskBackend.notificationBadges[cmd]
            if (nb !== undefined && Number(nb) > 0) {
                rule.badgeText = String(nb)
            }
            return rule
        } catch (e) {
            return {}
        }
    }

    function effectiveLeftClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.leftClickAction !== undefined) return rule.leftClickAction
            return dockRoot.liveLeftClickAction
    }

    function effectiveMiddleClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.middleClickAction !== undefined) return rule.middleClickAction
            return dockRoot.liveMiddleClickAction
    }

    function effectiveRightClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.rightClickAction !== undefined) return rule.rightClickAction
            return dockRoot.liveRightClickAction
    }

    function setAppClickRule(cmd, field, value) {
        let rules = {}
        try { rules = JSON.parse(liveAppRulesJson || "{}") } catch (e) { rules = {} }
        const norm = normalizeAppCommandKey(cmd)
        const key = norm.length > 0 ? norm : cmd
        // Remove chaves antigas equivalentes (ex.: "/usr/bin/chromium" vs "chromium").
        for (let oldKey in rules) {
            if (oldKey !== key && normalizeAppCommandKey(oldKey) === key) {
                delete rules[oldKey]
            }
        }
        if (!rules[key]) {
            rules[key] = {}
        }
        rules[key][field] = value
        liveAppRulesJson = JSON.stringify(rules)
        dockSettings.appRulesJson = liveAppRulesJson
        taskBackend.writeUserJsonFile("app_rules.json", liveAppRulesJson)
    }

    function migrateAppRulesJson() {
        let rules = {}
        try { rules = JSON.parse(liveAppRulesJson || "{}") } catch (e) { return }
        let out = {}
        let changed = false
        for (let key in rules) {
            const nk = normalizeAppCommandKey(key)
            const target = nk.length > 0 ? nk : key
            if (!out[target]) {
                out[target] = {}
            }
            Object.assign(out[target], rules[key])
            if (target !== key) {
                changed = true
            }
        }
        // Clique esquerdo em "Menu" no Chromium costuma ser acidental ao testar regras no menu.
        if (out.chromium && out.chromium.leftClickAction === 1) {
            delete out.chromium.leftClickAction
            changed = true
        }
        if (changed) {
            liveAppRulesJson = JSON.stringify(out)
            dockSettings.appRulesJson = liveAppRulesJson
            taskBackend.writeUserJsonFile("app_rules.json", liveAppRulesJson)
        }
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

    function saveLastSeenDynamic() {
        if (!dockRoot.liveBehaviorRememberRecentApps)
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

    function loadLastSeenDynamic() {
        if (!dockRoot.liveBehaviorRememberRecentApps)
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

    function openPinnedAppPicker() {
        pinnedAppPicker.open()
    }

    function openSystemShortcutPicker() {
        systemShortcutPicker.open()
    }

}
