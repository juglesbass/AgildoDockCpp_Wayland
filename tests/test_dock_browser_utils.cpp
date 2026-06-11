#include "dock_browser_utils.h"

#include <QTest>

class TestDockBrowserUtils : public QObject
{
    Q_OBJECT

private slots:
    void execBasenameFromCommand_data();
    void execBasenameFromCommand();
    void chromiumBrowsers();
    void geckoBrowsers();
    void chromiumConfigRootsContainsForks();
};

void TestDockBrowserUtils::execBasenameFromCommand_data()
{
    QTest::addColumn<QString>("command");
    QTest::addColumn<QString>("expected");

    QTest::newRow("path") << QStringLiteral("/usr/bin/chromium --ozone-platform=wayland")
                          << QStringLiteral("chromium");
    QTest::newRow("quoted") << QStringLiteral("\"brave-browser\" %U") << QStringLiteral("brave-browser");
    QTest::newRow("plain") << QStringLiteral("firefox") << QStringLiteral("firefox");
}

void TestDockBrowserUtils::execBasenameFromCommand()
{
    QFETCH(QString, command);
    QFETCH(QString, expected);
    QCOMPARE(DockBrowserUtils::execBasenameFromCommand(command), expected);
}

void TestDockBrowserUtils::chromiumBrowsers()
{
    QVERIFY(DockBrowserUtils::commandLooksLikeChromiumBrowser(QStringLiteral("brave")));
    QVERIFY(DockBrowserUtils::commandLooksLikeChromiumBrowser(QStringLiteral("opera")));
    QVERIFY(DockBrowserUtils::commandLooksLikeChromiumBrowser(QStringLiteral("vivaldi-stable")));
    QVERIFY(!DockBrowserUtils::commandLooksLikeChromiumBrowser(QStringLiteral("firefox")));
}

void TestDockBrowserUtils::geckoBrowsers()
{
    QVERIFY(DockBrowserUtils::commandLooksLikeGeckoBrowser(QStringLiteral("zen")));
    QVERIFY(DockBrowserUtils::commandLooksLikeGeckoBrowser(QStringLiteral("firefox")));
    QVERIFY(!DockBrowserUtils::commandLooksLikeGeckoBrowser(QStringLiteral("brave")));
}

void TestDockBrowserUtils::chromiumConfigRootsContainsForks()
{
    const QStringList roots = DockBrowserUtils::chromiumConfigRoots();
    QVERIFY(roots.contains(QStringLiteral("brave")));
    QVERIFY(roots.contains(QStringLiteral("opera")));
    QVERIFY(roots.contains(QStringLiteral("vivaldi")));
}

QTEST_APPLESS_MAIN(TestDockBrowserUtils)
#include "test_dock_browser_utils.moc"
