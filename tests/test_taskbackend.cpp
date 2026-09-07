#include "taskbackend.h"

#include <QTest>
#include <QSignalSpy>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

#include "dock_hyprland_helper.h"

class TestTaskBackend : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void cleanupTestCase();
    void parseDropInfoFileUrl();
    void parseDropInfoQuoted();
    void shouldHideFromDockSelf();
    void userJsonFileReadWrite();
    void hyprlandClientMatching();
    void hyprlandDolphinMatching();
};

static int initAppDetails() {
    qputenv("XDG_CONFIG_HOME", QByteArray(QDir::currentPath().toUtf8() + "/test_env/config"));
    qputenv("XDG_DATA_HOME", QByteArray(QDir::currentPath().toUtf8() + "/test_env/data"));
    QCoreApplication::setOrganizationName(QStringLiteral("AgildoSoft"));
    QCoreApplication::setApplicationName(QStringLiteral("AgildoDock"));
    return 0;
}
static int s_dummyInit = initAppDetails();

void TestTaskBackend::initTestCase()
{
}

void TestTaskBackend::cleanupTestCase()
{
}

void TestTaskBackend::parseDropInfoFileUrl()
{
    TaskBackend backend;
    QVariantMap res = backend.parseDropInfo(QStringLiteral("file:///usr/share/applications/org.kde.dolphin.desktop"));
    QCOMPARE(res.value(QStringLiteral("desktopPath")).toString(), QStringLiteral("/usr/share/applications/org.kde.dolphin.desktop"));
}

void TestTaskBackend::parseDropInfoQuoted()
{
    TaskBackend backend;
    QVariantMap res = backend.parseDropInfo(QStringLiteral("\"/usr/share/applications/org.kde.konsole.desktop\""));
    QCOMPARE(res.value(QStringLiteral("desktopPath")).toString(), QStringLiteral("/usr/share/applications/org.kde.konsole.desktop"));
}

void TestTaskBackend::shouldHideFromDockSelf()
{
    TaskBackend backend;
    QVERIFY(backend.shouldHideFromDock(QStringLiteral("agildodock"), QStringLiteral("Agildo Dock")));
    QVERIFY(backend.shouldHideFromDock(QStringLiteral("agildomonitor"), QStringLiteral("Agildo Monitor")));
    QVERIFY(!backend.shouldHideFromDock(QStringLiteral("dolphin"), QStringLiteral("Dolphin")));
}

void TestTaskBackend::userJsonFileReadWrite()
{
    TaskBackend backend;
    const QString testFile = QStringLiteral("test_unit_data.json");
    const QString testContent = QStringLiteral("{\"test\": 123}");

    QVERIFY(backend.writeUserJsonFile(testFile, testContent));
    const QString readBack = backend.readUserJsonFile(testFile);
    QCOMPARE(readBack, testContent);
}

void TestTaskBackend::hyprlandClientMatching()
{
    HyprClient zenClient;
    zenClient.address = QStringLiteral("0x1234");
    zenClient.cls = QStringLiteral("zen-beta");
    zenClient.initialClass = QStringLiteral("zen-beta");
    zenClient.title = QStringLiteral("Google - Zen Browser");
    zenClient.mapped = true;

    QHash<QString, QVariantMap> knownApps;
    QVariantMap zenApp;
    zenApp[QStringLiteral("cmd")] = QStringLiteral("zen-browser");
    zenApp[QStringLiteral("name")] = QStringLiteral("Zen Browser");
    zenApp[QStringLiteral("wmclass")] = QStringLiteral("zen-beta");
    knownApps.insert(QStringLiteral("zen-browser"), zenApp);

    QVERIFY(DockHyprlandHelper::clientMatchesCommand(zenClient, QStringLiteral("zen-browser"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(zenClient, QStringLiteral("dolphin"), knownApps));
}

void TestTaskBackend::hyprlandDolphinMatching()
{
    QHash<QString, QVariantMap> knownApps;

    // 1. Janela de Downloads
    HyprClient downloadsClient;
    downloadsClient.address = QStringLiteral("0x5678");
    downloadsClient.cls = QStringLiteral("org.kde.dolphin");
    downloadsClient.initialClass = QStringLiteral("org.kde.dolphin");
    downloadsClient.title = QStringLiteral("Downloads — Dolphin");
    downloadsClient.mapped = true;

    QVERIFY(DockHyprlandHelper::clientMatchesCommand(downloadsClient, QStringLiteral("dolphin ~/Downloads"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(downloadsClient, QStringLiteral("dolphin"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(downloadsClient, QStringLiteral("dolphin trash:/"), knownApps));

    // 2. Janela de pasta comum (Home / Geral)
    HyprClient homeClient;
    homeClient.address = QStringLiteral("0x5679");
    homeClient.cls = QStringLiteral("org.kde.dolphin");
    homeClient.initialClass = QStringLiteral("org.kde.dolphin");
    homeClient.title = QStringLiteral("Pasta pessoal — Dolphin");
    homeClient.mapped = true;

    QVERIFY(DockHyprlandHelper::clientMatchesCommand(homeClient, QStringLiteral("dolphin"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(homeClient, QStringLiteral("dolphin ~/Downloads"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(homeClient, QStringLiteral("dolphin trash:/"), knownApps));

    // 3. Janela da Lixeira
    HyprClient trashClient;
    trashClient.address = QStringLiteral("0x5680");
    trashClient.cls = QStringLiteral("org.kde.dolphin");
    trashClient.initialClass = QStringLiteral("org.kde.dolphin");
    trashClient.title = QStringLiteral("Lixeira — Dolphin");
    trashClient.mapped = true;

    QVERIFY(DockHyprlandHelper::clientMatchesCommand(trashClient, QStringLiteral("dolphin trash:/"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(trashClient, QStringLiteral("dolphin"), knownApps));
    QVERIFY(!DockHyprlandHelper::clientMatchesCommand(trashClient, QStringLiteral("dolphin ~/Downloads"), knownApps));
}

QTEST_MAIN(TestTaskBackend)
#include "test_taskbackend.moc"
