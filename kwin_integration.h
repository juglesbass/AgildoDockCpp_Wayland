#ifndef KWIN_INTEGRATION_H
#define KWIN_INTEGRATION_H

#include <QSize>
#include <QString>

/// Integração opcional com org.kde.KWin (Plasma/Wayland) para janela activa mais rápida que só kdotool.
namespace KwinIntegration {

bool isAvailable();

/// Preenche classe WM + título da janela activa. Retorna false se KWin não responder.
bool pollActiveWindow(QString *outClassLower, QString *outTitleLower, QSize *outInnerSizeOpt);

} // namespace KwinIntegration

#endif
