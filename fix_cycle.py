import re

with open('taskbackend.cpp', 'r') as f:
    content = f.read()

# Replace cycleAppWindows body
old_cycle = """void TaskBackend::cycleAppWindows(const QString &command, int direction)
{
    if (command.isEmpty() || direction == 0 || !m_kdotoolAvailable) {
        return;
    }
    const QStringList handles = windowHandlesForCommand(command);
    if (handles.isEmpty()) {
        return;
    }
    if (handles.size() == 1) {
        QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.first()});
        return;
    }

    QString activeHandle;
    QProcess activeP;
    activeP.start(QStringLiteral("kdotool"), {QStringLiteral("getactivewindow")});
    if (activeP.waitForFinished(kKdotoolTimeoutMs)) {
        activeHandle = QString::fromUtf8(activeP.readAllStandardOutput()).trimmed();
    }

    int idx = handles.indexOf(activeHandle);
    if (idx < 0) {
        idx = 0;
    } else {
        idx = (idx + (direction > 0 ? 1 : handles.size() - 1)) % handles.size();
    }
    QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.at(idx)});
}"""

new_cycle = """void TaskBackend::cycleAppWindows(const QString &command, int direction)
{
    if (command.isEmpty() || direction == 0 || !m_kdotoolAvailable) {
        return;
    }
    
    (void)QtConcurrent::run([this, command, direction]() {
        const QStringList handles = windowHandlesForCommand(command);
        if (handles.isEmpty()) {
            return;
        }
        if (handles.size() == 1) {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.first()});
            return;
        }

        QString activeHandle;
        QProcess activeP;
        activeP.start(QStringLiteral("kdotool"), {QStringLiteral("getactivewindow")});
        if (activeP.waitForFinished(kKdotoolTimeoutMs)) {
            activeHandle = QString::fromUtf8(activeP.readAllStandardOutput()).trimmed();
        }

        int idx = handles.indexOf(activeHandle);
        if (idx < 0) {
            idx = 0;
        } else {
            idx = (idx + (direction > 0 ? 1 : handles.size() - 1)) % handles.size();
        }
        QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), handles.at(idx)});
    });
}"""

content = content.replace(old_cycle, new_cycle)

with open('taskbackend.cpp', 'w') as f:
    f.write(content)

print("Fixed cycleAppWindows")
