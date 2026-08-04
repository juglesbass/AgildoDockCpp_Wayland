#include "taskbackend.h"

#include <QTest>
#include <QSignalSpy>
#include <QDir>
#include <QFile>
#include <QStandardPaths>

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

QTEST_MAIN(TestTaskBackend)
#include "test_taskbackend.moc"
