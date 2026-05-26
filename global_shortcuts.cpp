#include "global_shortcuts.h"

#include <QAction>
#include <QKeySequence>
#include <QMetaObject>
#include <QObject>
#include <QWindow>

#ifdef AGILDO_HAVE_KGLOBALACCEL
#include <KGlobalAccel>
#endif

namespace AgildoDock {

namespace {

void invocar(QObject *alvo, const char *metodo)
{
    if (!alvo) {
        return;
    }
    QMetaObject::invokeMethod(alvo, metodo, Qt::QueuedConnection);
}

} // namespace

void configurarAtalhosGlobais(QObject *acaoAlvo, QWindow * /*janelaPreferencias*/)
{
#ifdef AGILDO_HAVE_KGLOBALACCEL
    auto *prefs = new QAction(QObject::tr("Preferências do AgildoDock"), acaoAlvo);
    prefs->setObjectName(QStringLiteral("agildodock_prefs"));
    QObject::connect(prefs, &QAction::triggered, acaoAlvo, [acaoAlvo]() {
        invocar(acaoAlvo, "abrirPreferencias");
    });
    KGlobalAccel::self()->setGlobalShortcut(prefs, QKeySequence(QStringLiteral("Ctrl+,")));

    auto *mostrar = new QAction(QObject::tr("Mostrar/ocultar AgildoDock"), acaoAlvo);
    mostrar->setObjectName(QStringLiteral("agildodock_toggle"));
    QObject::connect(mostrar, &QAction::triggered, acaoAlvo, [acaoAlvo]() {
        invocar(acaoAlvo, "alternarVisibilidadeDock");
    });
    KGlobalAccel::self()->setGlobalShortcut(mostrar, QKeySequence(QStringLiteral("Meta+Alt+D")));
#else
    Q_UNUSED(acaoAlvo);
#endif
}

} // namespace AgildoDock
