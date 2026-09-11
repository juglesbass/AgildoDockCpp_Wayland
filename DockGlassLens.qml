import QtQuick
import QtQuick.Window

// Lente de vidro: o wallpaper a dobrar no rebordo da doca.
//
// A doca e' uma superficie LayerShell e nunca recebe os pixels que o compositor
// desenha por tras dela -- o desfoque que se ve' no meio da barra e' do
// Hyprland, nao nosso. Mas o ficheiro de wallpaper esta' ali, e o enquadramento
// que o daemon de fundo lhe deu e' reproduzivel: preenchimento "cover",
// centrado. Sabendo isso, da' para calcular exactamente que pedaco da imagem
// fica atras da barra e refracta-lo nos ultimos milimetros do vidro.
//
// Limite honesto: isto so' esta' certo por cima do WALLPAPER. Com uma janela
// atras da doca, o rebordo mostra o fundo em vez da janela. Por isso a curva de
// opacidade e' curta e discreta -- o efeito le'-se como espessura do vidro, nao
// como uma segunda imagem colada por cima.
Item {
    id: lens

    required property var dockRoot
    required property var dockBg

    // 0 desliga; 1 e' o maximo que ainda se le' como vidro e nao como recorte.
    property real intensity: 0.55

    readonly property bool temImagem: wallpaperSource.imagePath !== ""
                                      && wallpaperSource.imageSize.width > 0
                                      && wallpaperSource.imageSize.height > 0
    readonly property bool operacional: temImagem && intensity > 0.001
                                        && width > 4 && height > 4
                                        && Screen.width > 0 && Screen.height > 0

    // ---- So' por cima do ambiente de trabalho ----------------------------
    //
    // A lente le' o ficheiro de wallpaper, nao o ecra'. Sobre uma janela isso
    // deixa de ser refraccao e passa a ser invencao: via-se um anel com as
    // cores do fundo por cima de conteudo que nada tem a ver. Por isso o efeito
    // apaga-se quando ha' janela por tras, e volta sozinho quando a area
    // liberta. A transicao e' lenta de proposito -- um piscar seria pior do que
    // o artefacto que evita.
    property bool haJanelaAtras: false
    property real fade: haJanelaAtras ? 0.0 : 1.0
    Behavior on fade {
        NumberAnimation { duration: 260; easing.type: Easing.InOutQuad }
    }

    Timer {
        running: lens.operacional && lens.visible
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (typeof taskBackend === "undefined" || !taskBackend)
                return
            // A sonda e' exactamente o rectangulo da barra, sem folga.
            //
            // Com folga isto dava sempre positivo: o Hyprland ladrilha as
            // janelas ate' a' zona exclusiva da doca, e sobra uma frincha de
            // poucos pixeis entre o fundo da janela e o topo da barra. Qualquer
            // margem maior do que essa frincha fazia a lente pensar que tinha
            // uma janela por tras e apagava-se sempre.
            //
            // O rebordo chega a amostrar uns pixeis para fora da barra, mas sao
            // poucos e no extremo da curva -- nao se ve' a diferenca.
            lens.haJanelaAtras = taskBackend.areaHasWindowBehind(
                        Math.round(lens.barScreenX),
                        Math.round(lens.barScreenY),
                        Math.round(lens.width),
                        Math.round(lens.height))
        }
    }

    // ---- Geometria: onde a barra esta' no ecra' --------------------------
    //
    // No Wayland o mapToGlobal de uma layer surface nao devolve nada util, por
    // isso a posicao da janela deduz-se da aresta em que esta' ancorada. E' a
    // mesma regra que o compositor aplica, logo bate certo ao pixel.
    readonly property real winW: Window.window ? Window.window.width : 0
    readonly property real winH: Window.window ? Window.window.height : 0

    readonly property real winScreenX: dockRoot.liveDockEdge === 2
            ? 0
            : (dockRoot.liveDockEdge === 3 ? Screen.width - winW
                                           : (Screen.width - winW) / 2)
    readonly property real winScreenY: dockRoot.liveDockEdge === 0
            ? Screen.height - winH
            : (dockRoot.liveDockEdge === 1 ? 0
                                           : (Screen.height - winH) / 2)

    readonly property real barScreenX: winScreenX + dockBg.sceneOriginX
    readonly property real barScreenY: winScreenY + dockBg.sceneOriginY

    // ---- Geometria: como o wallpaper esta' esticado no ecra' -------------
    readonly property real natW: wallpaperSource.imageSize.width
    readonly property real natH: wallpaperSource.imageSize.height
    readonly property real coverScale: (natW > 0 && natH > 0)
            ? Math.max(Screen.width / natW, Screen.height / natH) : 1
    readonly property real desenhoX: (Screen.width - natW * coverScale) / 2
    readonly property real desenhoY: (Screen.height - natH * coverScale) / 2

    // ---- Recorte carregado para a GPU -----------------------------------
    //
    // Recorta-se apenas a faixa onde a doca vive, nao o wallpaper inteiro. O
    // recorte e' uma BANDA que atravessa a imagem toda no eixo em que a barra
    // cresce, porque a largura da barra muda a cada onda do rato -- se o
    // recorte a seguisse, a imagem era recarregada a cada frame.
    readonly property bool vertical: dockRoot.liveDockEdge === 2 || dockRoot.liveDockEdge === 3
    readonly property real folga: Math.max(8, pushPx * 2 + 4)

    function quantizaBaixo(v, passo) { return Math.floor(v / passo) * passo }
    function quantizaCima(v, passo) { return Math.ceil(v / passo) * passo }

    // Extremos da banda, ja' presos aos limites da imagem. Durante o arranque a
    // janela ainda nao tem tamanho e estas contas dao valores fora da imagem --
    // dai' o recorteValido mais abaixo, sem o qual o Qt tentava descodificar um
    // rectangulo impossivel e enchia o log de erros.
    readonly property real bandaIni: vertical
            ? quantizaBaixo((barScreenX - folga - desenhoX) / coverScale, 16)
            : quantizaBaixo((barScreenY - folga - desenhoY) / coverScale, 16)
    readonly property real bandaFim: vertical
            ? quantizaCima((barScreenX + dockBg.width + folga - desenhoX) / coverScale, 16)
            : quantizaCima((barScreenY + dockBg.height + folga - desenhoY) / coverScale, 16)

    readonly property real limite: vertical ? natW : natH
    readonly property real iniPreso: Math.max(0, Math.min(limite - 1, bandaIni))
    readonly property real fimPreso: Math.max(iniPreso + 1, Math.min(limite, bandaFim))

    readonly property real recorteX: vertical ? iniPreso : 0
    readonly property real recorteY: vertical ? 0 : iniPreso
    readonly property real recorteW: vertical ? (fimPreso - iniPreso) : natW
    readonly property real recorteH: vertical ? natH : (fimPreso - iniPreso)

    readonly property bool recorteValido: natW > 0 && natH > 0
            && recorteW >= 1 && recorteH >= 1
            && recorteX >= 0 && recorteY >= 0
            && (recorteX + recorteW) <= natW
            && (recorteY + recorteH) <= natH

    // O mesmo recorte, de volta em coordenadas de ecra': e' contra ele que o
    // shader normaliza as amostras.
    readonly property real faixaX: desenhoX + recorteX * coverScale
    readonly property real faixaY: desenhoY + recorteY * coverScale
    readonly property real faixaW: Math.max(1, recorteW * coverScale)
    readonly property real faixaH: Math.max(1, recorteH * coverScale)

    // ---- Afinacao do material -------------------------------------------
    readonly property real escala: dockRoot.liveScaleFactor
    readonly property real rimPx: Math.max(5, 12 * escala)
    readonly property real pushPx: 22 * escala * intensity

    Image {
        id: wallImg
        visible: false
        asynchronous: true
        cache: false
        smooth: true
        mipmap: false
        source: (lens.operacional && lens.recorteValido)
                ? ("file://" + wallpaperSource.imagePath) : ""
        // Sem sourceSize: com sourceClipRect definido, o QImageReader aplicaria
        // a escala ANTES do recorte e as duas contas deixavam de bater certo.
        sourceClipRect: lens.recorteValido
                ? Qt.rect(lens.recorteX, lens.recorteY, lens.recorteW, lens.recorteH)
                : Qt.rect(0, 0, 0, 0)
    }

    ShaderEffect {
        anchors.fill: parent
        visible: lens.operacional && lens.recorteValido
                 && wallImg.status === Image.Ready && lens.fade > 0.004
        blending: true
        fragmentShader: "qrc:/agildodock/shaders/glasslens.frag.qsb"

        property variant src: wallImg
        property vector2d dockSize: Qt.vector2d(Math.max(1, lens.width), Math.max(1, lens.height))
        property vector2d wallScale: Qt.vector2d(1.0 / lens.faixaW, 1.0 / lens.faixaH)
        property vector2d wallOffset: Qt.vector2d((lens.barScreenX - lens.faixaX) / lens.faixaW,
                                                  (lens.barScreenY - lens.faixaY) / lens.faixaH)
        property real radiusPx: Math.max(0, dockBg.radius - 1)
        property real rimPx: lens.rimPx
        property real pushPx: lens.pushPx
        property real strength: Math.max(0.0, Math.min(1.0, lens.intensity)) * lens.fade
        property real aberration: 0.10
        property real sheen: 0.30
        // Ampliacao do centro: pouca, so' o bastante para o vidro nao parecer
        // um recorte perfeito do fundo.
        property real zoom: 0.025 * lens.intensity
    }
}
