import re

with open('taskbackend.cpp', 'r') as f:
    content = f.read()

# Replace appWindowCount
old_count = """int TaskBackend::appWindowCount(const QString &command)
{
    if (command.isEmpty()) {
        return 0;
    }
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const auto it = s_windowCountCache.constFind(command);
    if (it != s_windowCountCache.cend() && (nowMs - it->timestampMs) < kWindowCountCacheTtlMs) {
        return it->count;
    }
    const QStringList handles = windowHandlesForCommand(command);
    const int count = handles.size();
    s_windowCountCache.insert(command, WindowCountCacheEntry{count, nowMs});
    return count;
}"""

new_count = """int TaskBackend::appWindowCount(const QString &command)
{
    if (command.isEmpty()) {
        return 0;
    }
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    const auto it = s_windowCountCache.constFind(command);
    if (it != s_windowCountCache.cend() && (nowMs - it->timestampMs) < kWindowCountCacheTtlMs) {
        return it->count;
    }
    
    // Atualiza o TTL temporariamente para evitar múltiplas chamadas simultâneas
    int lastCount = (it != s_windowCountCache.cend()) ? it->count : 0;
    s_windowCountCache.insert(command, WindowCountCacheEntry{lastCount, nowMs});
    
    (void)QtConcurrent::run([this, command]() {
        const QStringList handles = windowHandlesForCommand(command);
        const int count = handles.size();
        
        QMetaObject::invokeMethod(this, [this, command, count]() {
            s_windowCountCache.insert(command, WindowCountCacheEntry{count, QDateTime::currentMSecsSinceEpoch()});
            emitWindowsUpdatedCoalesced();
        });
    });
    
    return lastCount;
}"""
content = content.replace(old_count, new_count)

# Replace lactHasVisibleWindow
old_lact = """bool TaskBackend::lactHasVisibleWindow(const QString &command) const
{
    if (!m_kdotoolAvailable) {
        return true;
    }
    QString lactCmd = command;
    if (!knownApps.contains(lactCmd)) {
        for (auto it = knownApps.constBegin(); it != knownApps.constEnd(); ++it) {
            if (isLactCommand(it.key())) {
                lactCmd = it.key();
                break;
            }
        }
    }
    if (lactCmd.isEmpty()) {
        lactCmd = QStringLiteral("lact gui");
    }
    return !DockWindowManagement::resolveAllWindowHandlesForLaunch(
        lactCmd, knownApps, m_kdotoolAvailable, kKdotoolTimeoutMs).isEmpty();
}"""

new_lact = """bool TaskBackend::lactHasVisibleWindow(const QString &command) const
{
    if (!m_kdotoolAvailable) {
        return true;
    }
    QString lactCmd = command;
    if (!knownApps.contains(lactCmd)) {
        for (auto it = knownApps.constBegin(); it != knownApps.constEnd(); ++it) {
            if (isLactCommand(it.key())) {
                lactCmd = it.key();
                break;
            }
        }
    }
    if (lactCmd.isEmpty()) {
        lactCmd = QStringLiteral("lact gui");
    }
    
    // Usa o const_cast para aproveitar a função assíncrona appWindowCount
    return const_cast<TaskBackend*>(this)->appWindowCount(lactCmd) > 0;
}"""
content = content.replace(old_lact, new_lact)

with open('taskbackend.cpp', 'w') as f:
    f.write(content)

print("Fixed appWindowCount and lactHasVisibleWindow")
