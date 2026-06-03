#ifndef DOCK_WINDOW_MANAGEMENT_H
#define DOCK_WINDOW_MANAGEMENT_H

#include <QtGui/qwindowdefs.h>
#include <QHash>
#include <QSize>
#include <QString>
#include <QStringView>
#include <QVariantMap>

/*!
 * Helpers para localizar janelas e aplicar operações típicas de doca —
 * usando KWinStacking/X quando a sessão é X11 nativa e, em Wayland Plasma,
 * repassando para o fluxo já existente com kdotool.
 */
namespace DockWindowManagement {

// true quando esta app está em sessão/Qt X11 — KX11Extras e KWindowInfo funcionam como cliente.
bool nativeX11ClientUsable();

/*!
 * Compara comando da doca contra metadados de janela em primeiro plano
 * (usado por isAppFocused e pela varredura X11/Wayland-heurísticas).
 */
bool commandMatchesForegroundHints(const QString &command,
                                   QStringView wmCombinedClassLower,
                                   QStringView captionLower,
                                   const QHash<QString, QVariantMap> &knownApps);

// true se temos pelo menos uma via completa para focar/minimizar/fechar janelas alheias.
bool fullForeignWindowCtlAvailable(bool kdotoolOnPath);

// Codifica/deserializa um WId do X para passar através da pilha atual (QString compatível).
QString encodeX11WId(WId wid);
bool decodeX11WId(const QString &packed, WId *out);

// Resolve janela alvo: primeiro X11 cliente; opcionalmente cadeia declarativa com kdotool.
QString resolveWindowHandleForLaunch(const QString &command,
                                     const QHash<QString, QVariantMap> &knownApps,
                                     bool kdotoolAvailable,
                                     int kdotoolTimeoutMs);

QString runFirstKdotoolSearchHit(const QStringList &args, int timeoutMs);

// Todas as janelas que batem com a cadeia de busca (primeiro filtro com resultado).
QStringList resolveAllWindowHandlesForLaunch(const QString &command,
                                             const QHash<QString, QVariantMap> &knownApps,
                                             bool kdotoolAvailable,
                                             int kdotoolTimeoutMs);

// Window View do KWin (estilo Exposé por app) — handles no formato kdotool/KWin uuid.
bool activateKWinWindowView(const QStringList &handles);

// Atualiza texto de classe+título WM da janela ativa; retorna false se só kdotool puder fazê‑lo.
bool fillActiveHintsFromNativeStacking(QString &outClassLower,
                                       QString &outTitleLower,
                                       QSize *outInnerSizeOpt,
                                       QSize *screenSizeOpt);

// Heurística «janela cobre área»: usa geometria já obtida quando possível (evita kdotool getwindowgeometry).
bool activeWindowProbablyCoversWorkArea(const QSize &windowInner,
                                        const QSize &screenPx,
                                        qreal widthRatio = 0.88,
                                        qreal heightRatio = 0.82);

// operações quando o identificador for x11:…
bool activatePackedOrMinimize(const QString &packedWin,
                              bool minimizeIfFocused,
                              const QString &commandForHints,
                              QString &outActiveAppClassGuess);

bool closePackedWindow(const QString &packedWin, bool kdotoolAvailable);

} // namespace DockWindowManagement

#endif
