import QtQuick

// Componente encarregado do gerenciamento de regras customizadas e comandos por app.
QtObject {
    id: appRulesRoot

    required property var dockRoot

    property string liveAppRulesJson: "{}"
    property string liveCustomCommandsJson: "{}"

    property var _rulesCache: ({})
    property var _customCommandsCache: ({})

    onLiveAppRulesJsonChanged: _rebuildRulesCache()
    onLiveCustomCommandsJsonChanged: _rebuildCustomCommandsCache()

    Component.onCompleted: {
        _rebuildRulesCache()
        _rebuildCustomCommandsCache()
    }

    function _rebuildRulesCache() {
        try {
            _rulesCache = JSON.parse(liveAppRulesJson || "{}") || {}
        } catch (e) {
            _rulesCache = {}
        }
    }

    function _rebuildCustomCommandsCache() {
        try {
            _customCommandsCache = JSON.parse(liveCustomCommandsJson || "{}") || {}
        } catch (e) {
            _customCommandsCache = {}
        }
    }

    function customCommandsFor(cmd) {
        if (!cmd) return []
        let arr = _customCommandsCache[cmd]
        if (!arr) {
            const norm = normalizeAppCommandKey(cmd)
            arr = _customCommandsCache[norm]
        }
        return Array.isArray(arr) ? arr : []
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
        if (!cmd) return {}
        const norm = normalizeAppCommandKey(cmd)
        let rule = _rulesCache[cmd]
        if (!rule && norm.length > 0) {
            rule = _rulesCache[norm]
            if (!rule) {
                for (let key in _rulesCache) {
                    if (normalizeAppCommandKey(key) === norm) {
                        rule = _rulesCache[key]
                        break
                    }
                }
            }
        }
        rule = (rule && typeof rule === "object") ? Object.assign({}, rule) : {}
        const nb = (typeof taskBackend !== "undefined" && taskBackend) ? taskBackend.notificationBadges[cmd] : undefined
        if (nb !== undefined && Number(nb) > 0) {
            rule.badgeText = String(nb)
        }
        return rule
    }

    function effectiveLeftClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.leftClickAction !== undefined) return rule.leftClickAction
        return dockRoot ? dockRoot.liveLeftClickAction : 0
    }

    function effectiveMiddleClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.middleClickAction !== undefined) return rule.middleClickAction
        return dockRoot ? dockRoot.liveMiddleClickAction : 2
    }

    function effectiveRightClickAction(cmd) {
        const rule = appRuleForCommand(cmd)
        if (rule.rightClickAction !== undefined) return rule.rightClickAction
        return dockRoot ? dockRoot.liveRightClickAction : 1
    }

    function setAppClickRule(cmd, field, value) {
        let rules = {}
        try { rules = JSON.parse(liveAppRulesJson || "{}") } catch (e) { rules = {} }
        const norm = normalizeAppCommandKey(cmd)
        const key = norm.length > 0 ? norm : cmd
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
        if (dockRoot) {
            dockRoot.appSettings.appRulesJson = liveAppRulesJson
            dockRoot.taskBackend.writeUserJsonFile("app_rules.json", liveAppRulesJson)
        }
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
        if (out.chromium && out.chromium.leftClickAction === 1) {
            delete out.chromium.leftClickAction
            changed = true
        }
        if (changed) {
            liveAppRulesJson = JSON.stringify(out)
            if (dockRoot) {
                dockRoot.appSettings.appRulesJson = liveAppRulesJson
                dockRoot.taskBackend.writeUserJsonFile("app_rules.json", liveAppRulesJson)
            }
        }
    }
}
