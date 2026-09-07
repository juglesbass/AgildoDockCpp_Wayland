pragma Singleton
import QtQuick

// Constantes nomeadas para o AgildoDock.
// Centraliza todos os valores numéricos que antes estavam hardcoded no main.qml.
QtObject {

    // ── Animação & Duração ──────────────────────────────────────────────
    readonly property int minAnimationDurationMs: 60
    readonly property real fastProfileDurationFactor: 0.65
    readonly property real elasticProfileDurationFactor: 1.2
    // A altura da superficie LayerShell muda de golpe, de proposito -- 0 aqui
    // desliga a animacao dela.
    //
    // Animar esta altura significava redimensionar a superficie Wayland a cada
    // quadro: buffer novo em 4K e um round-trip de configure com o compositor,
    // 17 vezes em 280ms. Medido em video a 60fps, o movimento saia com pacing
    // irregular (passos -0.8 seguido de -10.8, quadros perdidos) e a doca ainda
    // derivava ~10px de volta depois de chegar. Com a mudanca instantanea os
    // passos ficam monotonicos (-5.4 -6.2 -4.7 -4.2 -2.6 -1.6 -1.0) e assenta.
    //
    // Nao ha' salto visivel porque a parte da janela que cresce e' transparente:
    // quem se ve' mover e' o conteudo, pelo Translate do DockContainer, e esse
    // continua animado. E a ordem em main.qml garante que ao ocultar a superficie
    // so' encolhe DEPOIS de a doca sair -- nunca corta a animacao a meio.
    readonly property int dockHeightAnimDurationMs: 0
    readonly property int waveAmpFastDurationMs: 120
    readonly property int waveAmpSmoothDurationMs: 220
    readonly property int waveAmpButteryDurationMs: 380
    // Deslize do auto-ocultar. 280 ms fica proximo do dock do macOS: rapido o
    // bastante para nao parecer arrastado, longo o bastante para a curva de
    // desaceleracao ser percebida.
    readonly property int dockSlideAnimDurationMs: 280
    // Usado apenas pelo perfil "elastico" (animationProfile 2).
    readonly property real dockSlideEasingOvershoot: 1.15
    // Curva de desaceleracao no estilo macOS: arranca depressa e assenta sem
    // ultrapassar o alvo. E' o oposto do OutBack, que ultrapassava e voltava --
    // origem do "pulo" na entrada e saida da doca.
    // Formato do Easing.Bezier: pontos de controlo terminando em 1,1.
    // Curva easeOutQuint: arranca depressa e assenta sem ultrapassar o alvo.
    //
    // A versao anterior usava [0.32, 0.72, 0.0, 1.0]: o x do segundo ponto de
    // controlo (0.0) era MENOR que o do primeiro (0.32), o que torna o
    // mapeamento nao-monotonico em x -- a curva dobra sobre si mesma. Dava um
    // ressalto reproduzivel de 2px no fim da subida (207 -> 205 -> 207).
    // Aqui os x sao crescentes (0.22 -> 0.36), como uma funcao de easing exige.
    readonly property var dockSlideSmoothBezier: [0.22, 1.0, 0.36, 1.0, 1.0, 1.0]

    // Curva de SAIDA: easeInCubic -- arranca devagar e acelera a sair de campo.
    //
    // Antes a saida usava a mesma curva da entrada (easeOutQuint), que comeca
    // depressa: medido em video a 60fps, a doca percorria 67% do caminho nos
    // primeiros 56ms e desaparecia em 2-3 quadros. Dava a sensacao de corte
    // seco em vez de movimento.
    //
    // A regra de sempre em animacao de interface: o que ENTRA desacelera (o
    // olho precisa de o apanhar e ver assentar), o que SAI acelera (basta
    // perceber a direccao em que se foi).
    readonly property var dockSlideExitBezier: [0.32, 0.0, 0.67, 0.0, 1.0, 1.0]

    // A saida e' ligeiramente mais longa que a entrada: com arranque suave,
    // 280ms ainda lia como abrupto.
    readonly property int dockSlideExitDurationMs: 340
    readonly property int startupFadeDurationMs: 600
    readonly property int startupSlideDurationMs: 900
    readonly property int iconAddScaleDurationMs: 300
    readonly property int iconAddOpacityDurationMs: 200

    // ── Timers & Intervalos ─────────────────────────────────────────────
    readonly property int waveCollapseIntervalMs: 120
    readonly property int minAutoHideDelayMs: 200
    readonly property int zoneUpdateDebounceMs: 150
    readonly property int pointerMaskDebounceMs: 48
    readonly property int startupZoneDelayMs: 1000
    readonly property int themeScheduleCheckIntervalMs: 60000
    readonly property int ghostAppClearTimeoutMs: 40000
    readonly property int saveSettingsFlushDelayMs: 300
    readonly property int blurStartupSettleDelayMs: 150
    readonly property int maxUndoStackDepth: 40

    // ── Wave Physics & Smoothing ────────────────────────────────────────
    readonly property real waveInertiaButteryActiveAlpha: 0.08
    readonly property real waveInertiaButteryIdleAlpha: 0.35
    readonly property real waveInertiaSmoothActiveAlpha: 0.22
    readonly property real waveInertiaSmoothIdleAlpha: 0.50
    readonly property real waveAmplitudeCutoff: 0.02
    readonly property real mouseInitializedThreshold: -100.0
    readonly property real waveExpansionMultiplier: 7.0
    readonly property real waveHoverSpanFactor: 3.15
    readonly property real dockHoverPaddingPx: 30.0
    readonly property real dockHoverMarginPx: 25.0

    // ── Geometria & Layout ──────────────────────────────────────────────
    readonly property real baseItemPaddingPx: 15.0
    readonly property real dividerWidthRatio: 0.4
    readonly property int fallbackScreenWidthPx: 1920
    readonly property int fallbackScreenHeightPx: 1080
    readonly property real dockTopOverflowOffsetPx: 10.0
    readonly property real motionSlopBufferPx: 165.0
    readonly property real minWinEdgeSlopPx: 40.0
    readonly property real wavePeakSlopMultiplier: 2.0
    readonly property real strideSlopRatio: 0.45
    readonly property real minVerticalDockWidthPx: 120.0
    readonly property real verticalDockWidthPaddingPx: 48.0
    readonly property real minDockWindowDimensionPx: 420.0
    readonly property real minDockPeekHeightPx: 48.0
    readonly property real minDockRadiusPx: 8.0
    readonly property real maxDockRadiusPx: 40.0
    readonly property real minDockThicknessPx: 4.0
    readonly property real maxDockThicknessPx: 120.0
    readonly property real startupOffsetYPx: 200.0
    readonly property real dividerLineHeightRatio: 0.45
    readonly property real dividerHitBottomMarginPx: 40.0
    readonly property real pointerMaskMinMarginPx: 32.0
    readonly property real minEdgeDropAreaHeightPx: 70.0

    // ── Z-Index Layers ──────────────────────────────────────────────────
    readonly property int zContextMenuOverlay: 300000
    readonly property int zTooltipLayer: 200000
    readonly property int zMinimizeSuckOverlay: 210000
    readonly property int zDropAreaLayer: 99999

    // ── Tooltip Styling ─────────────────────────────────────────────────
    readonly property real tooltipMarginGapPx: 10.0
    readonly property real tooltipScreenMarginPx: 8.0
    readonly property real maxTooltipWidthPx: 320.0
    readonly property real minTooltipWidthPx: 80.0
    readonly property real tooltipCornerRadiusPx: 8.0
    readonly property int tooltipTitleFontSizePx: 13
    readonly property int tooltipBodyFontSizePx: 12

    // ── Minimize Suck Animation ─────────────────────────────────────────
    readonly property int minimizeSuckDurationMs: 210
    readonly property real suckFadeInRatio: 0.30
    readonly property real suckFadeOutRatio: 0.70
    readonly property real suckStreakWidthRatio: 1.9
    readonly property real suckStreakHeightRatio: 0.44
    readonly property real suckEndScale: 0.2
    readonly property real minimizeSuckStartOffsetYPx: 120.0
    readonly property real baseMinimizeSuckSizePx: 14.0
    readonly property real minMinimizeSuckSizePx: 10.0
}
