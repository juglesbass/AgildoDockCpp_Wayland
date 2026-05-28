// Efeito KWin: “sugar” janela ao minimizar até o ícone na AgildoDock.
//
// No KWin 6, minimizedChanged existe por janela (não em effects.*).
// callDBus() é sempre assíncrono — a resposta chega no callback (ver API KWin).

"use strict";

const DOCK_SERVICE = "org.agildosoft.AgildoDock";
const DOCK_PATH = "/AgildoDock";
const DOCK_IFACE = "org.agildosoft.AgildoDock";

function log(msg) {
    try {
        console.info("agildodock_suck_minimize: " + msg);
    } catch (e) {
        // ignore
    }
}

function parseIconRectDBusReply(res) {
    if (res === undefined || res === null) {
        return null;
    }
    const x = Number(res.x !== undefined ? res.x : res["x"]);
    const y = Number(res.y !== undefined ? res.y : res["y"]);
    const w = Number(res.w !== undefined ? res.w : res["w"]);
    const h = Number(res.h !== undefined ? res.h : res["h"]);
    if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) {
        return null;
    }
    return { x: x, y: y, width: w, height: h };
}

function pushMatchKey(keys, value) {
    if (value === undefined || value === null) {
        return;
    }
    const s = String(value).trim();
    if (!s || keys.indexOf(s) !== -1) {
        return;
    }
    keys.push(s);
}

// Chaves para casar janela KWin ↔ ícone na doca (windowClass é o principal no KWin 6).
function keysForWindow(window) {
    const keys = [];
    if (!window) {
        return keys;
    }

    pushMatchKey(keys, window.windowClass);
    if (window.windowClass) {
        const parts = String(window.windowClass).trim().split(/\s+/);
        for (let i = 0; i < parts.length; i++) {
            pushMatchKey(keys, parts[i]);
        }
    }

    pushMatchKey(keys, window.desktopFileName);
    if (window.desktopFileName) {
        let df = String(window.desktopFileName).trim();
        const slash = df.lastIndexOf("/");
        if (slash >= 0) {
            df = df.substring(slash + 1);
        }
        if (df.endsWith(".desktop")) {
            df = df.substring(0, df.length - 8);
        }
        pushMatchKey(keys, df);
    }

    pushMatchKey(keys, window.appId);
    pushMatchKey(keys, window.resourceClass);
    pushMatchKey(keys, window.resourceName);

    return keys;
}

function matchKeysForWindow(window) {
    const keys = window._agildoDockMatchKeys ? window._agildoDockMatchKeys.slice() : [];
    const fresh = keysForWindow(window);
    for (let i = 0; i < fresh.length; i++) {
        pushMatchKey(keys, fresh[i]);
    }
    window._agildoDockMatchKeys = keys;
    return keys;
}

// Consulta a doca via D-Bus (assíncrono). callback(iconRect|null).
function requestIconRect(window, callback) {
    const keys = matchKeysForWindow(window);
    if (!keys.length) {
        callback(null);
        return;
    }

    const finish = function (res, methodName) {
        const rect = parseIconRectDBusReply(res);
        if (rect) {
            callback(rect);
            return;
        }
        if (res !== undefined && res !== null) {
            log("dbus " + methodName + " resposta vazia/inválida para keys=" + keys.join(","));
        } else {
            log("dbus " + methodName + " sem resposta (doca parada?) keys=" + keys.join(","));
        }
        callback(null);
    };

    try {
        callDBus(DOCK_SERVICE, DOCK_PATH, DOCK_IFACE, "GetIconRectForKeys", keys, function (res) {
            finish(res, "GetIconRectForKeys");
        });
    } catch (e1) {
        log("dbus GetIconRectForKeys falhou: " + e1 + "; tentando GetIconRect");
        try {
            callDBus(DOCK_SERVICE, DOCK_PATH, DOCK_IFACE, "GetIconRect", keys[0], function (res) {
                finish(res, "GetIconRect");
            });
        } catch (e2) {
            log("dbus GetIconRect falhou: " + e2);
            callback(null);
        }
    }
}

function shouldAnimateWindow(window) {
    if (!window || window.deleted) {
        return false;
    }
    if (window.popupWindow || window.outline || window.lockScreen) {
        return false;
    }
    if (!window.managed) {
        return false;
    }
    if (window.specialWindow && !window.hasDecoration) {
        return false;
    }
    return window.normalWindow || window.dialog;
}

var dockSuckEffect = {
    duration: animationTime(260),

    loadConfig: function () {
        dockSuckEffect.duration = animationTime(260);
    },

    restoreForceBlurState: function (window) {
        window.setData(Effect.WindowForceBlurRole, null);
    },

    runMinimizeAnimation: function (window, iconRect) {
        if (!window || window.deleted || !window.minimized) {
            return;
        }
        if (!iconRect) {
            return;
        }

        if (window.unminimizeAnimation) {
            if (redirect(window.unminimizeAnimation, Effect.Backward)) {
                return;
            }
            cancel(window.unminimizeAnimation);
            delete window.unminimizeAnimation;
        }

        if (window.minimizeAnimation) {
            if (redirect(window.minimizeAnimation, Effect.Forward)) {
                return;
            }
            cancel(window.minimizeAnimation);
        }

        const windowRect = window.geometry;
        if (windowRect.width <= 0 || windowRect.height <= 0) {
            return;
        }

        window.setData(Effect.WindowForceBlurRole, true);

        log("animando até x=" + iconRect.x + " y=" + iconRect.y +
            " w=" + iconRect.width + " h=" + iconRect.height);

        window.minimizeAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: dockSuckEffect.duration,
            keepAlive: false,
            animations: [
                {
                    type: Effect.Size,
                    from: {
                        value1: windowRect.width,
                        value2: windowRect.height
                    },
                    to: {
                        value1: iconRect.width,
                        value2: iconRect.height
                    }
                },
                {
                    type: Effect.Translation,
                    from: {
                        value1: 0.0,
                        value2: 0.0
                    },
                    to: {
                        value1: iconRect.x - windowRect.x -
                            (windowRect.width - iconRect.width) / 2,
                        value2: iconRect.y - windowRect.y -
                            (windowRect.height - iconRect.height) / 2
                    }
                },
                {
                    type: Effect.Opacity,
                    from: 1.0,
                    to: 0.0
                }
            ]
        });
    },

    runUnminimizeAnimation: function (window, iconRect) {
        if (!window || window.deleted || window.minimized) {
            return;
        }
        if (!iconRect) {
            return;
        }

        if (window.minimizeAnimation) {
            if (redirect(window.minimizeAnimation, Effect.Backward)) {
                return;
            }
            cancel(window.minimizeAnimation);
            delete window.minimizeAnimation;
        }

        if (window.unminimizeAnimation) {
            if (redirect(window.unminimizeAnimation, Effect.Forward)) {
                return;
            }
            cancel(window.unminimizeAnimation);
        }

        const windowRect = window.geometry;
        window.setData(Effect.WindowForceBlurRole, true);

        window.unminimizeAnimation = animate({
            window: window,
            curve: QEasingCurve.OutCubic,
            duration: dockSuckEffect.duration,
            keepAlive: false,
            animations: [
                {
                    type: Effect.Size,
                    from: {
                        value1: iconRect.width,
                        value2: iconRect.height
                    },
                    to: {
                        value1: windowRect.width,
                        value2: windowRect.height
                    }
                },
                {
                    type: Effect.Translation,
                    from: {
                        value1: iconRect.x - windowRect.x -
                            (windowRect.width - iconRect.width) / 2,
                        value2: iconRect.y - windowRect.y -
                            (windowRect.height - iconRect.height) / 2
                    },
                    to: {
                        value1: 0.0,
                        value2: 0.0
                    }
                },
                {
                    type: Effect.Opacity,
                    from: 0.0,
                    to: 1.0
                }
            ]
        });
    },

    slotWindowMinimized: function (window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!shouldAnimateWindow(window)) {
            return;
        }

        requestIconRect(window, function (iconRect) {
            if (!iconRect) {
                const keys = window._agildoDockMatchKeys || [];
                log("sem retângulo de ícone para windowClass=" + (window.windowClass || "") +
                    " keys=" + keys.join(","));
                return;
            }
            dockSuckEffect.runMinimizeAnimation(window, iconRect);
        });
    },

    slotWindowUnminimized: function (window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!shouldAnimateWindow(window)) {
            return;
        }

        requestIconRect(window, function (iconRect) {
            if (!iconRect) {
                return;
            }
            dockSuckEffect.runUnminimizeAnimation(window, iconRect);
        });
    },

    slotWindowAdded: function (window) {
        window._agildoDockMatchKeys = keysForWindow(window);

        window.minimizedChanged.connect(function () {
            if (window.minimized) {
                dockSuckEffect.slotWindowMinimized(window);
            } else {
                dockSuckEffect.slotWindowUnminimized(window);
            }
        });
    },

    init: function () {
        effect.configChanged.connect(dockSuckEffect.loadConfig);
        effect.animationEnded.connect(dockSuckEffect.restoreForceBlurState.bind(dockSuckEffect));

        effects.windowAdded.connect(dockSuckEffect.slotWindowAdded);
        for (const window of effects.stackingOrder) {
            dockSuckEffect.slotWindowAdded(window);
        }

        dockSuckEffect.loadConfig();
        log("inicializado (dbus assíncrono + minimizedChanged)");
    }
};

dockSuckEffect.init();
