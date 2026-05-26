#include "dock_window_management.h"

#include <QCoreApplication>
#include <QHash>
#include <cassert>

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    QHash<QString, QVariantMap> known;

    assert(DockWindowManagement::commandMatchesForegroundHints(
        QStringLiteral("dolphin"),
        QStringView(u"dolphin dolphin"),
        QStringView(u"ficheiros"),
        known));

    assert(DockWindowManagement::commandMatchesForegroundHints(
        QStringLiteral("chromium --app-id=abc"),
        QStringView(u"crx_abc chromium"),
        QStringView(u"app"),
        known));

    assert(!DockWindowManagement::commandMatchesForegroundHints(
        QStringLiteral("konsole"),
        QStringView(u"dolphin dolphin"),
        QStringView(),
        known));

    return 0;
}
