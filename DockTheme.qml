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

    // Temas da doca, em tabela.
    //
    // Antes eram cinco ramos de um if/else no applyAppearancePreset() e cinco
    // botoes escritos a mao na janela de configuracoes -- acrescentar um tema
    // obrigava a mexer nos dois sitios e a linha de botoes ja' nao cabia. Aqui
    // um tema e' uma entrada; a interface desenha-se a partir desta lista.
    //
    // Campos: themeMode 0 Escuro 1 Claro 2 Noite Azul 3 Ametista
    //         accent    0 Ciano 1 Roxo 2 Verde 3 Laranja 4 Rosa
    //         bg3d      0 padrao 3 vidro
    //         indicator 0 ponto 1 linha 2 barra 3 sublinhado 4 pulso
    function appearancePresets() {
        return [
            { id: "Dark Glass",   nome: qsTr("Vidro Escuro"),
              themeMode: 0, accent: 0, bg3d: 3, indicator: 0, mono: false,
              opacity: 0.42, mix: 0.35, glow: 0.24, shadow: 0.34,
              a: "#14161A", b: "#1A1D22", c: "#121418" },

            { id: "Light Glass",  nome: qsTr("Vidro Claro"),
              themeMode: 1, accent: 2, bg3d: 3, indicator: 1, mono: false,
              opacity: 0.36, mix: 0.30, glow: 0.28, shadow: 0.18,
              a: "#EEF1F6", b: "#E4E9F0", c: "#F8FAFC" },

            // Os canais alfa no hex sao propositais: e' o unico preset em que o
            // proprio gradiente e' translucido, e nao so' a opacidade global.
            // Opacidade baixa e brilho de borda alto: no Tahoe o material quase
            // nao tem cor propria -- o que se ve' e' o fundo atenuado e a luz a
            // acumular-se na aresta. Um vidro mais opaco le'-se como plastico.
            { id: "Liquid Glass", nome: qsTr("Vidro Líquido"),
              themeMode: 0, accent: 0, bg3d: 3, indicator: 4, mono: false,
              opacity: 0.14, mix: 0.10, glow: 0.42, shadow: 0.30,
              a: "#24FFFFFF", b: "#0AFFFFFF", c: "#18000000" },

            { id: "Neon",         nome: qsTr("Neon"),
              themeMode: 2, accent: 0, bg3d: 3, indicator: 4, mono: true,
              opacity: 0.40, mix: 0.38, glow: 0.30, shadow: 0.45,
              a: "#0A1424", b: "#101C32", c: "#081018" },

            { id: "Minimal",      nome: qsTr("Minimalista"),
              themeMode: 0, accent: 1, bg3d: 0, indicator: 3, mono: true,
              opacity: 0.42, mix: 0.35, glow: 0.07, shadow: 0.18,
              a: "#171717", b: "#171717", c: "#171717" },

            // ---- Paletas conhecidas -------------------------------------
            { id: "Catppuccin",   nome: qsTr("Catppuccin"),
              themeMode: 0, accent: 1, bg3d: 3, indicator: 0, mono: false,
              opacity: 0.46, mix: 0.40, glow: 0.22, shadow: 0.32,
              a: "#1E1E2E", b: "#181825", c: "#11111B" },

            { id: "Nord",         nome: qsTr("Nord"),
              themeMode: 0, accent: 0, bg3d: 3, indicator: 1, mono: false,
              opacity: 0.44, mix: 0.36, glow: 0.20, shadow: 0.30,
              a: "#2E3440", b: "#3B4252", c: "#242933" },

            { id: "Gruvbox",      nome: qsTr("Gruvbox"),
              themeMode: 0, accent: 3, bg3d: 3, indicator: 2, mono: false,
              opacity: 0.48, mix: 0.42, glow: 0.18, shadow: 0.36,
              a: "#282828", b: "#32302F", c: "#1D2021" },

            { id: "Dracula",      nome: qsTr("Drácula"),
              themeMode: 3, accent: 1, bg3d: 3, indicator: 4, mono: false,
              opacity: 0.45, mix: 0.38, glow: 0.26, shadow: 0.34,
              a: "#282A36", b: "#343746", c: "#21222C" },

            { id: "Tokyo Night",  nome: qsTr("Tokyo Night"),
              themeMode: 2, accent: 1, bg3d: 3, indicator: 0, mono: false,
              opacity: 0.46, mix: 0.34, glow: 0.28, shadow: 0.38,
              a: "#1A1B26", b: "#24283B", c: "#16161E" },

            { id: "Solarized",    nome: qsTr("Solarizado"),
              themeMode: 0, accent: 2, bg3d: 3, indicator: 1, mono: false,
              opacity: 0.44, mix: 0.36, glow: 0.20, shadow: 0.30,
              a: "#002B36", b: "#073642", c: "#001F27" },

            { id: "Rose",         nome: qsTr("Rosé"),
              themeMode: 3, accent: 4, bg3d: 3, indicator: 4, mono: false,
              opacity: 0.42, mix: 0.35, glow: 0.30, shadow: 0.28,
              a: "#2B2028", b: "#3A2A34", c: "#221A20" },

            // Sem gradiente e sem brilho: para quem quer a doca a desaparecer
            // no fundo em vez de se afirmar.
            { id: "Graphite",     nome: qsTr("Grafite"),
              themeMode: 0, accent: 0, bg3d: 0, indicator: 3, mono: true,
              opacity: 0.55, mix: 0.50, glow: 0.05, shadow: 0.22,
              a: "#202020", b: "#242424", c: "#181818" },
        ]
    }

    function presetById(id) {
        const lista = appearancePresets()
        for (let i = 0; i < lista.length; i++)
            if (lista[i].id === id)
                return lista[i]
        return null
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
