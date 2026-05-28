// Efeito KWin: “sugar” janela ao minimizar até o ícone na AgildoDock.
//
// No KWin 6, minimizedChanged existe por janela (não em effects.*).
// Baseado no efeito oficial squash (/usr/share/kwin-wayland/effects/squash).

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

function getIconRectForKey(appKey) {
    if (!appKey) {
        return null;
    }
    try {
        const res = callDBus(DOCK_SERVICE, DOCK_PATH, DOCK_IFACE, "GetIconRect", String(appKey));
        if (!res) {
            return null;
        }
        const x = Number(res.x);
        const y = Number(res.y);
        const w = Number(res.w);
        const h = Number(res.h);
        if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) {
            return null;
        }
        return { x: x, y: y, width: w, height: h };
    } catch (e) {
        return null;
    }
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

function lookupIconRect(keys) {
    for (let i = 0; i < keys.length; i++) {
        const r = getIconRectForKey(keys[i]);
        if (r) {
            return r;
        }
    }
    return null;
}

function bestIconRect(window) {
    const keys = window._agildoDockMatchKeys ? window._agildoDockMatchKeys.slice() : [];
    const fresh = keysForWindow(window);
    for (let i = 0; i < fresh.length; i++) {
        pushMatchKey(keys, fresh[i]);
    }
    window._agildoDockMatchKeys = keys;
    return lookupIconRect(keys);
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

    slotWindowMinimized: function (window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!shouldAnimateWindow(window)) {
            return;
        }

        const iconRect = bestIconRect(window);
        if (!iconRect) {
            const keys = window._agildoDockMatchKeys || [];
            log("sem retângulo de ícone para windowClass=" + (window.windowClass || "") +
                " keys=" + keys.join(","));
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

    slotWindowUnminimized: function (window) {
        if (effects.hasActiveFullScreenEffect) {
            return;
        }
        if (!shouldAnimateWindow(window)) {
            return;
        }

        const iconRect = bestIconRect(window);
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
        log("inicializado (hook por janela: minimizedChanged)");
    }
};

dockSuckEffect.init();
