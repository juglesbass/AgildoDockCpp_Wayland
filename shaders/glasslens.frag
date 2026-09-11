#version 440

// Lente de vidro: o wallpaper visto ATRAVES da doca.
//
// A doca nao consegue ler os pixels que o compositor desenha por tras dela, mas
// consegue abrir o MESMO ficheiro de wallpaper e saber exactamente que pedaco
// dele lhe fica atras. Este shader mostra esse pedaco atraves de todo o vidro,
// nao so' na aresta: um bloco de vidro com faces paralelas deixa passar o
// centro quase intacto e dobra a luz cada vez mais a' medida que a superficie
// se curva na borda. E' esse o modelo aqui -- ampliacao ligeira no meio,
// compressao forte no rebordo.
//
// A versao anterior so' pintava o rebordo, e o resultado era uma barra com as
// beiras vivas e o meio fosco: via-se a diferenca entre o wallpaper refractado
// e o desfoque do compositor por baixo. Cobrindo tudo, a leitura fica uniforme.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4  qt_Matrix;
    float qt_Opacity;
    vec2  dockSize;     // tamanho da barra, em px logicos
    vec2  wallScale;    // px da barra -> uv da textura
    vec2  wallOffset;   // uv do canto superior esquerdo da barra
    float radiusPx;     // raio dos cantos
    float rimPx;        // espessura do rebordo trabalhado
    float pushPx;       // quanto a amostra e' empurrada para fora
    float strength;     // mistura final com o vidro por baixo
    float aberration;   // separacao cromatica no extremo
    float sheen;        // fio de luz no perimetro
    float zoom;         // ampliacao suave em todo o vidro
};

layout(binding = 1) uniform sampler2D src;

// Distancia com sinal a um rectangulo de cantos redondos: <0 dentro, 0 na borda.
float sdRoundBox(vec2 p, vec2 b, float r)
{
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

vec3 amostra(vec2 uv)
{
    return texture(src, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
}

void main()
{
    vec2 p = qt_TexCoord0 * dockSize;
    vec2 meio = dockSize * 0.5;
    vec2 rel = p - meio;

    float r = min(radiusPx, min(meio.x, meio.y));
    float d = sdRoundBox(rel, meio, r);

    // Fora do vidro nao ha' nada a desenhar.
    if (d > 0.0) {
        fragColor = vec4(0.0);
        return;
    }

    // Distancia para dentro, em px. O rebordo e' onde a face do vidro curva.
    float dentro = -d;
    float t = clamp(dentro / max(rimPx, 1.0), 0.0, 1.0);

    // Normal para fora, tirada do gradiente da propria distancia. Assim os
    // cantos redondos curvam na direccao certa sem casos especiais.
    const vec2 h = vec2(1.0, 0.0);
    float dx = sdRoundBox(rel + h.xy, meio, r) - sdRoundBox(rel - h.xy, meio, r);
    float dy = sdRoundBox(rel + h.yx, meio, r) - sdRoundBox(rel - h.yx, meio, r);
    vec2 n = normalize(vec2(dx, dy) + vec2(1e-6));

    // O desvio cresce depressa ao aproximar-se da aresta: e' isso que da' a
    // sensacao de espessura em vez de um degrade pintado.
    float curva = pow(1.0 - t, 2.6);
    float push = pushPx * curva;

    // Ampliacao suave em todo o vidro. Sem ela o centro seria uma copia exacta
    // do fundo e a doca lia-se como um buraco no ecra' em vez de um bloco de
    // vidro pousado por cima.
    vec2 pAmostra = meio + rel / (1.0 + zoom);

    vec2 baseUv = wallOffset + pAmostra * wallScale;
    vec2 passo = n * wallScale;

    // Tres amostras ao longo da normal suavizam o serrilhado sem apagar o
    // detalhe -- o rebordo deve ler-se mais nitido do que o corpo desfocado.
    vec3 cor;
    cor.r = ( amostra(baseUv + passo * (push * (1.0 + aberration))).r
            + amostra(baseUv + passo * (push * (1.0 + aberration) + 0.6)).r ) * 0.5;
    cor.g = ( amostra(baseUv + passo * push).g
            + amostra(baseUv + passo * (push + 0.6)).g ) * 0.5;
    cor.b = ( amostra(baseUv + passo * (push * (1.0 - aberration))).b
            + amostra(baseUv + passo * (push * (1.0 - aberration) + 0.6)).b ) * 0.5;

    // Fio de luz na aresta: o vidro apanha o brilho onde e' mais espesso.
    //
    // Ja' se tentou aqui um brilho largo na face de cima, para a barra manter
    // cara de vidro sobre zonas lisas do wallpaper. Ficou pior -- lia-se como
    // uma faixa clara pintada, nao como vidro. Fica so' o fio do perimetro.
    cor += vec3(pow(1.0 - t, 7.0) * sheen);

    // Cobertura constante: o vidro e' o mesmo material do centro a' borda. So'
    // o ultimo pixel e meio desvanece, para o recorte nao ficar serrilhado.
    float a = smoothstep(0.0, 1.5, dentro) * strength;
    fragColor = vec4(cor * a, a) * qt_Opacity;
}
