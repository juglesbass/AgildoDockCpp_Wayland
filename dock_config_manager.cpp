#include "dock_config_manager.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <QDebug>

namespace {
    static bool debugLogsEnabled() {
        const QByteArray v = qgetenv("AGILDO_DOCK_DEBUG").trimmed();
        return !v.isEmpty() && v != "0" && v.toLower() != "false" && v.toLower() != "off";
    }
    
    static bool persistLogEnabled() {
        if (!debugLogsEnabled()) return false;
        const QString raw = QString::fromUtf8(qgetenv("AGILDO_DOCK_DEBUG_CATS")).trimmed().toLower();
        if (raw.isEmpty()) return true;
        const QStringList parts = raw.split(',', Qt::SkipEmptyParts);
        for (const QString &p : parts) {
            if (p.trimmed() == QLatin1String("persist")) return true;
        }
        return false;
    }
}

QString DockConfigManager::dockAppsSnapshotPath()
{
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + QStringLiteral("/dock_apps_snapshot.json");
}

QString DockConfigManager::dockAppsSnapshotBackupPath()
{
    return dockAppsSnapshotPath() + QStringLiteral(".bak");
}

bool DockConfigManager::saveDockAppsSnapshot(const QString &dockAppsJson)
{
    if (dockAppsJson.trimmed().isEmpty()) {
        return false;
    }

    QJsonParseError jerr;
    QJsonDocument::fromJson(dockAppsJson.toUtf8(), &jerr);
    if (jerr.error != QJsonParseError::NoError) {
        if (debugLogsEnabled()) {
            qWarning() << "AgildoDock[debug]: snapshot dockApps inválido, ignorando:"
                       << jerr.errorString();
        }
        return false;
    }

    const QString targetPath = dockAppsSnapshotPath();
    const QString backupPath = dockAppsSnapshotBackupPath();
    const QString targetDir = QFileInfo(targetPath).absolutePath();
    QDir().mkpath(targetDir);

    if (QFile::exists(targetPath)) {
        QFile::remove(backupPath);
        QFile::copy(targetPath, backupPath);
    }

    QSaveFile out(targetPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "AgildoDock: falha ao abrir snapshot dockApps para escrita:" << targetPath;
        return false;
    }
    out.write(dockAppsJson.toUtf8());
    if (!out.commit()) {
        qWarning() << "AgildoDock: falha ao gravar snapshot dockApps:" << targetPath;
        return false;
    }

    if (debugLogsEnabled()) {
        qInfo() << "AgildoDock[debug]: snapshot dockApps salvo em" << targetPath;
    }
    return true;
}

QString DockConfigManager::loadDockAppsSnapshot()
{
    const QStringList paths = {dockAppsSnapshotPath(), dockAppsSnapshotBackupPath()};
    for (const QString &p : paths) {
        QFile f(p);
        if (!f.exists() || !f.open(QIODevice::ReadOnly)) {
            continue;
        }
        const QByteArray raw = f.readAll();
        f.close();
        if (raw.trimmed().isEmpty()) {
            continue;
        }
        QJsonParseError jerr;
        QJsonDocument::fromJson(raw, &jerr);
        if (jerr.error == QJsonParseError::NoError) {
            if (debugLogsEnabled()) {
                qInfo() << "AgildoDock[debug]: snapshot dockApps carregado de" << p;
            }
            return QString::fromUtf8(raw);
        }
    }
    return {};
}

QString DockConfigManager::appDataPathForFile(const QString &relativeName)
{
    QString safe = relativeName;
    safe.replace('\\', '/');
    safe.remove(QStringLiteral(".."));
    while (safe.startsWith('/')) {
        safe.remove(0, 1);
    }
    QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    if (dir.isEmpty()) {
        dir = QDir::tempPath() + QStringLiteral("/agildodock");
    }
    return dir + QLatin1Char('/') + safe;
}

bool DockConfigManager::writeUserJsonFile(const QString &relativeName, const QString &jsonText)
{
    if (relativeName.trimmed().isEmpty() || jsonText.trimmed().isEmpty()) {
        return false;
    }
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(jsonText.toUtf8(), &err);
    if (err.error != QJsonParseError::NoError) {
        qWarning() << "AgildoDock[debug][persist]: JSON inválido para" << relativeName << err.errorString();
        return false;
    }
    const QString outPath = appDataPathForFile(relativeName);
    const QString outDir = QFileInfo(outPath).absolutePath();
    bool mkOk = QDir().mkpath(outDir);
    if (!mkOk) {
        qWarning() << "AgildoDock[debug][persist]: mkpath falhou para" << outDir;
    }
    QSaveFile out(outPath);
    if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qWarning() << "AgildoDock[debug][persist]: Falha ao abrir QSaveFile" << outPath << out.errorString();
        return false;
    }
    out.write(jsonText.toUtf8());
    const bool ok = out.commit();
    if (!ok) {
        qWarning() << "AgildoDock[debug][persist]: Falha ao dar commit QSaveFile" << outPath << out.errorString();
    } else if (persistLogEnabled()) {
        qInfo() << "AgildoDock[debug][persist]: arquivo salvo" << outPath;
    }
    return ok;
}

QString DockConfigManager::readUserJsonFile(const QString &relativeName)
{
    if (relativeName.trimmed().isEmpty()) {
        return {};
    }
    const QString inPath = appDataPathForFile(relativeName);
    QFile in(inPath);
    if (!in.exists() || !in.open(QIODevice::ReadOnly)) {
        return {};
    }
    const QByteArray raw = in.readAll();
    in.close();
    if (raw.trimmed().isEmpty()) {
        return {};
    }
    QJsonParseError err;
    QJsonDocument::fromJson(raw, &err);
    if (err.error != QJsonParseError::NoError) {
        if (persistLogEnabled()) {
            qWarning() << "AgildoDock[debug][persist]: JSON inválido em" << inPath << err.errorString();
        }
        return {};
    }
    return QString::fromUtf8(raw);
}
