import QtQuick

// Componente encarregado do gerenciamento de regras customizadas e comandos por app.
QtObject {
    id: appRulesRoot

    required property var dockRoot

    property string liveAppRulesJson: "{}"
    property string liveCustomCommandsJson: "{}"

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
            const nb = (typeof taskBackend !== "undefined" && taskBackend) ? taskBackend.notificationBadges[cmd] : undefined
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
