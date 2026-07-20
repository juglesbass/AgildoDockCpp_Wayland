import re

with open('taskbackend.cpp', 'r') as f:
    content = f.read()

# Replace struct DolphinCache to just hold ids and titles
old_struct = """    struct DolphinCache {
        QStringList ids;
        QStringList titlesLower;
        qint64 timestampMs = 0;
        bool valid = false;
    };

    static DolphinCache s_dolphinCache;"""

new_struct = """    struct DolphinCache {
        QStringList ids;
        QStringList titlesLower;
    };

    static DolphinCache s_dolphinCache;"""
content = content.replace(old_struct, new_struct)

# Replace ensureDolphinCache with fetchDolphinCache
# Old ensureDolphinCache goes from "static void ensureDolphinCache(bool kdotoolAvailable)"
# to "static DolphinCache fetchDolphinCache(bool kdotoolAvailable)"

old_ensure = """    static void ensureDolphinCache(bool kdotoolAvailable)
    {
        if (!kdotoolAvailable) {
            return;
        }
        QElapsedTimer t;
        t.start();
        const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
        if (s_dolphinCache.valid && (nowMs - s_dolphinCache.timestampMs) < kDolphinCacheTtlMs) {
            return;
        }

        s_dolphinCache.ids.clear();
        s_dolphinCache.titlesLower.clear();
        s_dolphinCache.valid = false;

        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            s_dolphinCache.valid = true;
            s_dolphinCache.timestampMs = nowMs;
            return;
        }

        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList rawIds = out.split(QLatin1Char('\\n'), Qt::SkipEmptyParts);
            for (const QString &idRaw : rawIds) {
                const QString id = idRaw.trimmed();
                if (id.isEmpty()) {
                    continue;
                }
                QProcess nameP;
                nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
                if (!nameP.waitForFinished(120)) {
                    nameP.kill();
                    continue;
                }
                const QString title = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
                s_dolphinCache.ids << id;
                s_dolphinCache.titlesLower << title;
            }
        }

        s_dolphinCache.valid = true;
        s_dolphinCache.timestampMs = nowMs;
    }"""

new_ensure = """    static DolphinCache fetchDolphinCache(bool kdotoolAvailable)
    {
        DolphinCache cache;
        if (!kdotoolAvailable) {
            return cache;
        }

        QProcess search;
        search.start(QStringLiteral("kdotool"),
                     {QStringLiteral("search"), QStringLiteral("--class"), QStringLiteral("dolphin")});
        if (!search.waitForFinished(220)) {
            search.kill();
            return cache;
        }

        const QString out = QString::fromUtf8(search.readAllStandardOutput()).trimmed();
        if (!out.isEmpty()) {
            const QStringList rawIds = out.split(QLatin1Char('\\n'), Qt::SkipEmptyParts);
            for (const QString &idRaw : rawIds) {
                const QString id = idRaw.trimmed();
                if (id.isEmpty()) {
                    continue;
                }
                QProcess nameP;
                nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
                if (!nameP.waitForFinished(120)) {
                    nameP.kill();
                    continue;
                }
                const QString title = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
                cache.ids << id;
                cache.titlesLower << title;
            }
        }
        return cache;
    }"""
content = content.replace(old_ensure, new_ensure)

# Remove calls to ensureDolphinCache
content = content.replace("ensureDolphinCache(kdotoolAvailable);", "")
content = content.replace("s_dolphinCache.valid = false;", "")

# Replace the updateSystemState logic
old_update = """    (void)QtConcurrent::run([this]() {
        QSet<QString> next;
        DIR *dir = opendir("/proc");
        if (dir) {
            struct dirent *ent;
            while ((ent = readdir(dir)) != nullptr) {
                if (ent->d_name[0] >= '1' && ent->d_name[0] <= '9') {
                    const QString path = QStringLiteral("/proc/%1/cmdline").arg(QString::fromUtf8(ent->d_name));
                    const QString line = readProcCmdlineFile(path);
                    if (!line.isEmpty()) {
                        next.insert(line);
                    }
                }
            }
            closedir(dir);
        }
        QMetaObject::invokeMethod(
            this,
            [this, next]() {
                m_procScanRunning = false;
                m_runningCmdLines = next;"""

new_update = """    (void)QtConcurrent::run([this]() {
        QSet<QString> next;
        DIR *dir = opendir("/proc");
        if (dir) {
            struct dirent *ent;
            while ((ent = readdir(dir)) != nullptr) {
                if (ent->d_name[0] >= '1' && ent->d_name[0] <= '9') {
                    const QString path = QStringLiteral("/proc/%1/cmdline").arg(QString::fromUtf8(ent->d_name));
                    const QString line = readProcCmdlineFile(path);
                    if (!line.isEmpty()) {
                        next.insert(line);
                    }
                }
            }
            closedir(dir);
        }
        
        DolphinCache newDolphinCache = fetchDolphinCache(m_kdotoolAvailable);
        
        QMetaObject::invokeMethod(
            this,
            [this, next, newDolphinCache]() {
                s_dolphinCache = newDolphinCache;
                m_procScanRunning = false;
                m_runningCmdLines = next;"""
content = content.replace(old_update, new_update)

with open('taskbackend.cpp', 'w') as f:
    f.write(content)

print("Replaced dolphin caching logic")
