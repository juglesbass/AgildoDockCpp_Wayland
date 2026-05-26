#ifndef GLOBAL_SHORTCUTS_H
#define GLOBAL_SHORTCUTS_H

class QObject;
class QWindow;

namespace AgildoDock {

/// Atalhos globais Plasma (KGlobalAccel), quando disponível em tempo de compilação.
void configurarAtalhosGlobais(QObject *acaoAlvo, QWindow *janelaPreferencias);

} // namespace AgildoDock

#endif
