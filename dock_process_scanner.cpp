#include "dock_process_scanner.h"
#include "dock_browser_utils.h"
#include <QFile>
#include <QByteArray>

QString DockProcessScanner::readProcCmdlineFile(const QString &path)
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly)) {
        return {};
    }
    QByteArray raw = f.readAll();
    for (int i = 0; i < raw.size(); ++i) {
        if (raw.at(i) == '\0') {
            raw[i] = ' ';
        }
    }
    return QString::fromUtf8(raw).toLower().trimmed();
}

bool DockProcessScanner::appMatchesRunningCmdLine(const QString &cmdLineLower, const QVariantMap &app)
{
    const QString appCmd = app[QStringLiteral("cmd")].toString();
    const QString appCmdLower = appCmd.toLower();
    QString appExec = appCmd.split(' ').first().split('/').last().toLower();
    appExec.remove('"').remove('\'');

    if (appCmdLower.contains(QStringLiteral("--app-id"))) {
        QString appId;
        const QStringList parts = appCmdLower.split(' ');
        for (const QString &p : parts) {
            if (p.startsWith(QStringLiteral("--app-id="))) {
                appId = p;
                appId.remove('"').remove('\'');
                break;
            }
        }
        if (!appId.isEmpty() && cmdLineLower.contains(appId)) {
            return true;
        }
        return false;
    }
    if (appExec.isEmpty()) {
        return false;
    }

    QStringList appExecAlts;
    appExecAlts << appExec;
    if (appExec == QLatin1String("google-chrome-stable") || appExec == QLatin1String("google-chrome") || appExec == QLatin1String("chrome")) {
        appExecAlts << QStringLiteral("google-chrome-stable") << QStringLiteral("google-chrome") << QStringLiteral("chrome");
    } else if (appExec == QLatin1String("microsoft-edge-stable") || appExec == QLatin1String("microsoft-edge") || appExec == QLatin1String("msedge")) {
        appExecAlts << QStringLiteral("microsoft-edge-stable") << QStringLiteral("microsoft-edge") << QStringLiteral("msedge");
    } else if (appExec == QLatin1String("brave-browser") || appExec == QLatin1String("brave")) {
        appExecAlts << QStringLiteral("brave-browser") << QStringLiteral("brave");
    }

    if (DockBrowserUtils::commandLooksLikeBrowser(appExec)) {
        if (!cmdLineLower.contains(QStringLiteral("--app-id")) && !cmdLineLower.contains(QStringLiteral("--type=renderer"))
            && !cmdLineLower.contains(QStringLiteral("--type=zygote"))) {
            for (const QString &alt : appExecAlts) {
                if (cmdLineLower.startsWith(alt) || cmdLineLower.contains(QStringLiteral("/") + alt)) {
                    return true;
                }
            }
        }
        return false;
    }

    for (const QString &alt : appExecAlts) {
        if (cmdLineLower.startsWith(alt) || cmdLineLower.contains(QStringLiteral("/") + alt)) {
            return true;
        }
    }
    return false;
}
