#include "dock_browser_integration.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

void ensurePlasmaBrowserIntegrationHosts()
{
    const QStringList systemSources = {
        QStringLiteral("/usr/lib/mozilla/native-messaging-hosts/org.kde.plasma.browser_integration.json"),
        QStringLiteral("/usr/lib64/mozilla/native-messaging-hosts/org.kde.plasma.browser_integration.json"),
        QStringLiteral("/etc/chromium/native-messaging-hosts/org.kde.plasma.browser_integration.json"),
    };

    QString sourcePath;
    for (const QString &candidate : systemSources) {
        if (QFile::exists(candidate)) {
            sourcePath = candidate;
            break;
        }
    }
    if (sourcePath.isEmpty()) {
        return;
    }

    const QString configHome = QStandardPaths::writableLocation(QStandardPaths::ConfigLocation);
    if (configHome.isEmpty()) {
        return;
    }

    // Zen/Firefox procuram hosts em pastas específicas por perfil/navegador.
    const QStringList targetDirs = {
        configHome + QStringLiteral("/zen/NativeMessagingHosts"),
        QDir::homePath() + QStringLiteral("/.mozilla/native-messaging-hosts"),
    };

    const QString fileName = QStringLiteral("org.kde.plasma.browser_integration.json");
    for (const QString &dirPath : targetDirs) {
        QDir().mkpath(dirPath);
        const QString destPath = dirPath + QLatin1Char('/') + fileName;
        if (QFile::exists(destPath)) {
            const QFileInfo srcInfo(sourcePath);
            const QFileInfo dstInfo(destPath);
            if (dstInfo.size() == srcInfo.size() && dstInfo.lastModified() >= srcInfo.lastModified()) {
                continue;
            }
            QFile::remove(destPath);
        }
        QFile::copy(sourcePath, destPath);
    }
}
