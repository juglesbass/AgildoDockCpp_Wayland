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
    QCoreApplication::setApplicationVersion(QStringLiteral("1.0"));

    for (int i = 1; i < argc; ++i) {
        if (qstrcmp(argv[i], "--version") == 0 || qstrcmp(argv[i], "-v") == 0) {
            QCoreApplication core(argc, argv);
            QTextStream out(stdout);
            out << QCoreApplication::applicationName() << QLatin1Char(' ')
                << QCoreApplication::applicationVersion() << Qt::endl;
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
        layerWindow->setLayer(LayerShellQt::Window::LayerTop);
        layerWindow->setAnchors(LayerShellQt::Window::AnchorBottom);
        // Teclado e activateOnShow: preferências vêm do QML (applyLayerShellFromSettings), chamado
        // depois de setMainWindow — Component.onCompleted corre antes e taskBackend ainda não tinha janela.
        // Zona exclusiva: updateZone → taskBackend.updateExclusiveZone.
    }

    QObject *rootObject = engine.rootObjects().first();
    QMetaObject::invokeMethod(rootObject, "applyLayerShellFromSettings", Qt::DirectConnection);
    QMetaObject::invokeMethod(rootObject, "updateZone", Qt::DirectConnection);
    QMetaObject::invokeMethod(rootObject, "applyDockRetractedState", Qt::DirectConnection);

    // MOSTRAMOS NOVAMENTE: Aplica o blur e a animação nativa!
    window->show();
    QMetaObject::invokeMethod(rootObject, "refreshPointerInputMask", Qt::QueuedConnection);

    return app.exec();
}
