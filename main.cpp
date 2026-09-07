#include <QCoreApplication>
#include <QGuiApplication>
#include <QIcon>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QMetaObject>
#include <QObject>
#include <QTextStream>
#include <QTranslator>
#include <QUrl>
#include <QWindow>
#include <QtGlobal>
#include <LayerShellQt/Window>
#include "taskbackend.h"
#include "dock_global_shortcuts.h"
#include "dock_hyprland_helper.h"
#include "dock_ipc_server.h"

namespace {

void installAgildoTranslators(QGuiApplication &app)
{
    QStringList qmCandidates;

    const QByteArray forced = qgetenv("AGILDO_DOCK_LOCALE");
    if (!forced.isEmpty()) {
        qmCandidates << QStringLiteral(":/i18n/agildodock_") + QString::fromUtf8(forced).trimmed() + QStringLiteral(".qm");
    }

    const QLocale systemLocale;
    qmCandidates << QStringLiteral(":/i18n/agildodock_") + systemLocale.name() + QStringLiteral(".qm");
    QString underscoredBcp = systemLocale.bcp47Name();
    underscoredBcp.replace(QLatin1Char('-'), QLatin1Char('_'));
    if (underscoredBcp != systemLocale.name()) {
        qmCandidates << QStringLiteral(":/i18n/agildodock_") + underscoredBcp + QStringLiteral(".qm");
    }
    if (systemLocale.language() == QLocale::Portuguese) {
        const QString locName = systemLocale.name();
        if (locName.startsWith(QLatin1String("pt_PT"))) {
            qmCandidates << QStringLiteral(":/i18n/agildodock_pt_PT.qm");
        } else if (locName.startsWith(QLatin1String("pt_BR"))) {
            // Coberto por systemLocale.name(); fallback explícito se o ficheiro tiver outro nome.
            qmCandidates << QStringLiteral(":/i18n/agildodock_pt_BR.qm");
        } else {
            // «pt», pt_AO, etc.: tentar Brasil antes de Portugal.
            qmCandidates << QStringLiteral(":/i18n/agildodock_pt_BR.qm");
            qmCandidates << QStringLiteral(":/i18n/agildodock_pt_PT.qm");
        }
    }
    if (systemLocale.language() == QLocale::English) {
        qmCandidates << QStringLiteral(":/i18n/agildodock_en_US.qm");
    }

    QStringList unique;
    for (const QString &path : qmCandidates) {
        if (!path.isEmpty() && !unique.contains(path)) {
            unique.append(path);
        }
    }

    auto *translator = new QTranslator(&app);
    for (const QString &path : unique) {
        if (translator->load(path)) {
            app.installTranslator(translator);
            return;
        }
    }
    delete translator;
}

QIcon carregarIconeAgildoDock()
{
    QIcon icone = QIcon::fromTheme(QStringLiteral("org.agildosoft.agildodock"));
    if (icone.isNull()) {
        icone = QIcon(QStringLiteral(":/icons/org.agildosoft.agildodock.svg"));
    }
    return icone;
}

} // namespace

int main(int argc, char *argv[]) {
    // Sem a variável global qputenv aqui para manter as configurações flutuando pequenas.

    QCoreApplication::setOrganizationName("AgildoSoft");
    QCoreApplication::setOrganizationDomain("agildosoft.com");
    QCoreApplication::setApplicationName("AgildoDock");
    QCoreApplication::setApplicationVersion(QStringLiteral(AGILDO_DOCK_VERSION));

    // Comando pedido na linha de comandos (--toggle-dock / --open-settings).
    // Vazio quando a doca foi arrancada normalmente.
    QString pendingCommand;

    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], "--version") == 0 || qstrcmp(argv[i], "-v") == 0) {
            QCoreApplication core(argc, argv);
            QTextStream out(stdout);
            out << QCoreApplication::applicationName() << QLatin1Char(' ')
                << QCoreApplication::applicationVersion() << Qt::endl;
            return 0;
        }
        if (qstrcmp(argv[i], "--open-settings") == 0) {
            pendingCommand = QStringLiteral("open-settings");
        } else if (qstrcmp(argv[i], "--toggle-dock") == 0) {
            pendingCommand = QStringLiteral("toggle-dock");
        }
    }

    // Estes dois argumentos existem para os atalhos globais do Hyprland: o
    // compositor executa `agildodock --toggle-dock`, e este processo efémero
    // limita-se a passar o pedido à doca que já está a correr e a sair.
    //
    // O QCoreApplication vive só neste bloco: se não houver doca do outro lado
    // seguimos para o arranque normal, e aí é o QGuiApplication que manda —
    // não pode haver duas instâncias de QCoreApplication ao mesmo tempo.
    // A verificacao corre SEMPRE, tenha havido argumento ou nao.
    //
    // Antes estava dentro do `if (!pendingCommand.isEmpty())`: arrancar a doca
    // sem argumentos -- que e' o arranque normal -- nao verificava nada e subia
    // uma segunda doca por cima da que ja' corria. Duas superficies LayerShell
    // sobrepostas, cada uma com a sua animacao, davam a impressao de movimento
    // aos solavancos ao revelar e ocultar.
    {
        QCoreApplication probe(argc, argv);
        if (!pendingCommand.isEmpty()) {
            if (DockIpcServer::sendToRunningInstance(pendingCommand)) {
                return 0;
            }
            // Nao houve resposta: nao ha' doca a correr, seguimos para o
            // arranque normal e o comando perde-se -- e' o comportamento antigo.
        } else if (DockIpcServer::isAnotherInstanceRunning()) {
            QTextStream(stderr)
                << QCoreApplication::applicationName()
                << ": ja' existe uma doca em execucao nesta sessao." << Qt::endl;
            return 0;
        }
    }

    QGuiApplication::setDesktopFileName(QStringLiteral("org.agildosoft.agildodock"));
    QGuiApplication app(argc, argv);

    const QIcon iconeApp = carregarIconeAgildoDock();
    if (!iconeApp.isNull()) {
        QGuiApplication::setWindowIcon(iconeApp);
    }

    installAgildoTranslators(app);

    QQmlApplicationEngine engine;

    TaskBackend *taskBackend = new TaskBackend(&app);
    engine.rootContext()->setContextProperty("taskBackend", taskBackend);

    // Atalhos globais (KGlobalAccel) — independentes do foco na doca.

    // Com QTP0001 o QML fica em :/qt/qml/<URI>/ (não :/AgildoDock/). main.qml não é tipo no qmldir — carregar por URL.
    const QUrl url(QStringLiteral("qrc:/qt/qml/AgildoDock/main.qml"));
    engine.load(url);

    if (engine.rootObjects().isEmpty()) {
        qWarning("AgildoDock: falha ao carregar QML em %s", qPrintable(url.toString()));
        return -1;
    }

    QWindow *window = qobject_cast<QWindow*>(engine.rootObjects().first());
    if (!window) {
        qWarning("AgildoDock: raiz QML não é uma QWindow.");
        return -1;
    }

    taskBackend->setMainWindow(window);

    if (!iconeApp.isNull()) {
        window->setIcon(iconeApp);
    }

    // Workaround (testado em Plasma/Wayland + LayerShellQt): fechar e voltar a mostrar a QQuickWindow
    // raiz evita o primeiro frame sem decoração de superfície/blur; sem isto a doca pode aparecer
    // transparente até à primeira animação. Se mudares de compositor ou versão Qt, valida este fluxo.
    window->close();

    auto layerWindow = LayerShellQt::Window::get(window);
    if (layerWindow) {
        layerWindow->setScope(QStringLiteral("agildodock"));
        layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        // Âncora default segura: o protocolo Layer Shell exige âncora antes de mapear a superfície.
        // applyLayerShellFromSettings (abaixo) sobrescreve com a borda correta salva pelo utilizador.
        layerWindow->setAnchors(LayerShellQt::Window::AnchorBottom);
    }

    // Blur sob Hyprland. Ao contrário do KWin, que aplica blur às superfícies
    // Layer Shell por omissão, o Hyprland exige uma `layerrule` explícita por
    // escopo — sem isto a doca fica sem blur nenhum. Aplicado em runtime com
    // `hyprctl keyword`: não escreve no ~/.config/hypr/hyprland.conf.
    // No-op fora do Hyprland.
    DockHyprlandHelper::applyDockLayerRules();

    QObject *rootObject = engine.rootObjects().first();
    auto *globalShortcuts = new DockGlobalShortcuts(rootObject, &app);
    engine.rootContext()->setContextProperty("globalShortcuts", globalShortcuts);

    // Canal de instância única: é por aqui que os atalhos globais do Hyprland
    // chegam à doca (ver DockGlobalShortcuts e DockIpcServer).
    auto *ipcServer = new DockIpcServer(&app);
    QObject::connect(ipcServer, &DockIpcServer::openSettingsRequested, rootObject, [rootObject]() {
        QMetaObject::invokeMethod(rootObject, "openSettingsGlobal");
    });
    QObject::connect(ipcServer, &DockIpcServer::toggleDockRequested, rootObject, [rootObject]() {
        QMetaObject::invokeMethod(rootObject, "toggleDockGlobal");
    });
    ipcServer->listen();

    // `hyprctl keyword` aplica na hora mas não persiste: um `hyprctl reload`
    // limpa as layerrule e os binds acima. Este listener ouve só o evento
    // `configreloaded` e volta a aplicá-los.
    auto *hyprEvents = new DockHyprlandEventListener(&app);
    QObject::connect(hyprEvents, &DockHyprlandEventListener::configReloaded,
                     globalShortcuts, [globalShortcuts]() {
        DockHyprlandHelper::applyDockLayerRules();
        globalShortcuts->reapplyHyprlandBinds();
    });
    hyprEvents->start();

    QMetaObject::invokeMethod(rootObject, "applyLayerShellFromSettings", Qt::DirectConnection);
    QMetaObject::invokeMethod(rootObject, "updateZone", Qt::DirectConnection);
    QMetaObject::invokeMethod(rootObject, "applyDockRetractedState", Qt::DirectConnection);

    // MOSTRAMOS NOVAMENTE: Aplica o blur e a animação nativa!
    window->show();
    QMetaObject::invokeMethod(rootObject, "refreshPointerInputMask", Qt::QueuedConnection);
    QMetaObject::invokeMethod(rootObject, "refreshDockBlur", Qt::QueuedConnection);

    // Arrancámos por causa de um atalho e não havia doca a correr: honrar o
    // pedido agora que o QML existe.
    if (!pendingCommand.isEmpty()) {
        const char *slot = pendingCommand == QLatin1String("open-settings")
            ? "openSettingsGlobal"
            : "toggleDockGlobal";
        QMetaObject::invokeMethod(rootObject, slot, Qt::QueuedConnection);
    }

    return app.exec();
}
