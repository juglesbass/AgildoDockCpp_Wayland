#include "dock_browser_utils.h"

#include <QFileInfo>

namespace DockBrowserUtils {

QString execBasenameFromCommand(const QString &command)
{
    QString trimmed = command.trimmed();
    if (trimmed.isEmpty()) {
        return QString();
    }
    const int space = trimmed.indexOf(QLatin1Char(' '));
    if (space > 0) {
        trimmed = trimmed.left(space);
    }
    trimmed.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
    return QFileInfo(trimmed).fileName().toLower();
}

bool commandLooksLikeChromiumBrowser(const QString &command)
{
    const QString base = execBasenameFromCommand(command);
    if (base.isEmpty()) {
        return false;
    }
    static const QStringList kChromiumBases = {
        QStringLiteral("chromium"),
        QStringLiteral("chromium-browser"),
        QStringLiteral("google-chrome"),
        QStringLiteral("google-chrome-stable"),
        QStringLiteral("microsoft-edge"),
        QStringLiteral("microsoft-edge-stable"),
        QStringLiteral("brave"),
        QStringLiteral("brave-browser"),
        QStringLiteral("opera"),
        QStringLiteral("vivaldi"),
    };
    for (const QString &known : kChromiumBases) {
        if (base == known || base.startsWith(known + QLatin1Char('-'))) {
            return true;
        }
    }
    return false;
}

bool commandLooksLikeGeckoBrowser(const QString &command)
{
    const QString base = execBasenameFromCommand(command);
    if (base.isEmpty()) {
        return false;
    }
    return base.contains(QStringLiteral("firefox"))
        || base.contains(QStringLiteral("zen"))
        || base.contains(QStringLiteral("librewolf"))
        || base.contains(QStringLiteral("waterfox"));
}

bool commandLooksLikeBrowser(const QString &command)
{
    return commandLooksLikeChromiumBrowser(command) || commandLooksLikeGeckoBrowser(command);
}

QStringList chromiumConfigRoots()
{
    return {
        QStringLiteral("chromium"),
        QStringLiteral("google-chrome"),
        QStringLiteral("microsoft-edge"),
        QStringLiteral("brave"),
        QStringLiteral("brave-browser"),
        QStringLiteral("opera"),
        QStringLiteral("vivaldi"),
    };
}

QStringList geckoConfigRoots()
{
    return {
        QStringLiteral("zen"),
        QStringLiteral("mozilla/firefox"),
        QStringLiteral("librewolf"),
        QStringLiteral("waterfox"),
    };
}

QString browserFamilyForCommand(const QString &command)
{
    if (commandLooksLikeChromiumBrowser(command)) {
        return QStringLiteral("chromium");
    }
    if (commandLooksLikeGeckoBrowser(command)) {
        return QStringLiteral("gecko");
    }
    return QString();
}

bool commandMatchesWmClass(const QString &command, const QString &wmClassLower)
{
    const QString cls = wmClassLower.trimmed().toLower();
    if (cls.isEmpty()) {
        return false;
    }
    const QString base = execBasenameFromCommand(command);
    if (base.isEmpty()) {
        return false;
    }
    if (cls.contains(base) || base.contains(cls)) {
        return true;
    }
    const QString family = browserFamilyForCommand(command);
    if (family == QStringLiteral("chromium")) {
        return cls.contains(QStringLiteral("chrom")) || cls.contains(QStringLiteral("chrome"))
            || cls.contains(QStringLiteral("edge")) || cls.contains(QStringLiteral("brave"))
            || cls.contains(QStringLiteral("opera")) || cls.contains(QStringLiteral("vivaldi"));
    }
    if (family == QStringLiteral("gecko")) {
        return cls.contains(QStringLiteral("firefox")) || cls.contains(QStringLiteral("zen"))
            || cls.contains(QStringLiteral("librewolf")) || cls.contains(QStringLiteral("waterfox"));
    }
    return false;
}

} // namespace DockBrowserUtils
