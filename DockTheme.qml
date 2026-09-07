pragma Singleton
import QtQuick

// Funções puras de tema e perfil de animação para o AgildoDock.
QtObject {

    function themePalette(mode) {
        if (mode === 1) { // Claro
            return {
                dockR: 0.95, dockG: 0.95, dockB: 0.97,
                dockBorder: Qt.rgba(0.0, 0.0, 0.0, 0.18),
                dockTopLine: Qt.rgba(0.0, 0.0, 0.0, 0.10),
                divider: "#30000000",
                tipBg: "#F0F6F6F8",
                tipBorder: "#70000000",
                textPrimary: "#202020",
                textSecondary: "#4A4A4A",
                menuBg: Qt.rgba(0.96, 0.96, 0.98, 0.99),
                menuBorder: Qt.rgba(0.0, 0.0, 0.0, 0.14),
                menuHover: Qt.rgba(0.0, 0.0, 0.0, 0.08)
            }
        }
        if (mode === 2) { // Noite Azul
            return {
                dockR: 0.05, dockG: 0.09, dockB: 0.14,
                dockBorder: Qt.rgba(0.35, 0.60, 1.0, 0.28),
                dockTopLine: Qt.rgba(0.55, 0.75, 1.0, 0.25),
                divider: "#5090B8FF",
                tipBg: "#F0121A28",
                tipBorder: "#7090B8FF",
                textPrimary: "#EAF2FF",
                textSecondary: "#BCD0EE",
                menuBg: Qt.rgba(0.06, 0.11, 0.19, 0.98),
                menuBorder: Qt.rgba(0.45, 0.68, 1.0, 0.24),
                menuHover: Qt.rgba(0.45, 0.68, 1.0, 0.16)
            }
        }
        if (mode === 3) { // Ametista
            return {
                dockR: 0.10, dockG: 0.06, dockB: 0.12,
                dockBorder: Qt.rgba(0.82, 0.62, 1.0, 0.26),
                dockTopLine: Qt.rgba(0.90, 0.74, 1.0, 0.20),
                divider: "#60D0A0FF",
                tipBg: "#F01A1022",
                tipBorder: "#70C894FF",
                textPrimary: "#F7EAFF",
                textSecondary: "#D8C0E8",
                menuBg: Qt.rgba(0.14, 0.08, 0.18, 0.98),
                menuBorder: Qt.rgba(0.82, 0.62, 1.0, 0.22),
                menuHover: Qt.rgba(0.82, 0.62, 1.0, 0.16)
            }
        }
        // Escuro (padrão atual)
        return {
            dockR: 0.06, dockG: 0.06, dockB: 0.06,
            dockBorder: Qt.rgba(1.0, 1.0, 1.0, 0.15),
            dockTopLine: Qt.rgba(1.0, 1.0, 1.0, 0.12),
            divider: "#30FFFFFF",
            tipBg: "#F0222222",
            tipBorder: "#70FFFFFF",
            textPrimary: "#FFFFFF",
            textSecondary: "#CCCCCC",
            menuBg: Qt.rgba(0.10, 0.11, 0.13, 0.98),
            menuBorder: Qt.rgba(1.0, 1.0, 1.0, 0.14),
            menuHover: Qt.rgba(1.0, 1.0, 1.0, 0.08)
        }
    }

    function accentPalette(mode) {
        if (mode === 1) return { idle: "#B77BFF", focus: "#D4ACFF" } // Roxo
        if (mode === 2) return { idle: "#39D98A", focus: "#7CF0B5" } // Verde
        if (mode === 3) return { idle: "#FFB347", focus: "#FFD18A" } // Laranja
        if (mode === 4) return { idle: "#FF6FB5", focus: "#FF9CCB" } // Rosa
        return { idle: "#00E5FF", focus: "#00FFCC" } // Ciano
    }

    // Easing do deslize de auto-ocultar, por perfil de animacao.
    //
    // Antes, o Behavior em DockContainer.qml fixava Easing.OutBack com overshoot
    // e ignorava por completo o animationProfile escolhido nas definicoes: quem
    // pedia "suave" recebia a mesma animacao elastica de quem pedia "elastico".
    //   0 suave / 1 rapido -> curva macOS, sem ultrapassagem
    //   2 elastico         -> mantem o OutBack de sempre
    //   3 sem animacao     -> duracao 0, o easing e' irrelevante
    function slideEasingType(profile) {
        if (profile === 2) return Easing.OutBack
        if (profile === 3) return Easing.Linear
        return Easing.Bezier
    }

    // A entrada e a saida usam curvas diferentes de proposito -- ver o
    // comentario de dockSlideExitBezier. `retracting` = true quando a doca
    // esta' a recolher.
    function slideBezier(retracting) {
        return retracting ? DockConstants.dockSlideExitBezier
                          : DockConstants.dockSlideSmoothBezier
    }

    function slideDuration(profile, retracting) {
        return animationDuration(retracting ? DockConstants.dockSlideExitDurationMs
                                            : DockConstants.dockSlideAnimDurationMs,
                                 profile)
    }

    function slideEasingOvershoot(profile) {
        return profile === 2 ? DockConstants.dockSlideEasingOvershoot : 0
    }

    function animationDuration(baseMs, profile) {
        if (profile === 3) return 0
        if (profile === 1) return Math.max(DockConstants.minAnimationDurationMs, Math.round(baseMs * DockConstants.fastProfileDurationFactor))
        if (profile === 2) return Math.round(baseMs * DockConstants.elasticProfileDurationFactor)
        return baseMs
    }
}
