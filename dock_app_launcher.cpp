#include "dock_app_launcher.h"
#include "taskbackend.h"
#include "dock_browser_utils.h"
#include "dock_window_management.h"
#include <QProcess>
#include <QtConcurrent/QtConcurrentRun>
#include <QMetaObject>

namespace {
    constexpr int kKdotoolTimeoutMs = 400;
}

DockAppLauncher::DockAppLauncher(TaskBackend *backend)
    : m_backend(backend)
{
}

void DockAppLauncher::forceLaunchApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }

    QString desktopPath;
    if (m_backend->knownApps.contains(command) && m_backend->knownApps[command].contains(QStringLiteral("desktopPath"))) {
        desktopPath = m_backend->knownApps[command][QStringLiteral("desktopPath")].toString();
    }

    QProcess process;
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    env.remove(QStringLiteral("QT_WAYLAND_SHELL_INTEGRATION"));
    process.setProcessEnvironment(env);

    if (!desktopPath.isEmpty()) {
        process.setProgram(QStringLiteral("kioclient"));
        process.setArguments({QStringLiteral("exec"), desktopPath});
    } else {
        process.setProgram(QStringLiteral("sh"));
        process.setArguments({QStringLiteral("-c"), command});
    }

    process.startDetached();
}

bool DockAppLauncher::tryShowAppWindowOverview(const QString &command)
{
    if (command.isEmpty() || !m_backend->m_windowOverviewOnRefocus) {
        return false;
    }

    QStringList handles = m_backend->windowHandlesForCommand(command, m_backend->knownApps);

    if (handles.isEmpty() || handles.size() < 2) {
        return false;
    }
    return DockWindowManagement::activateKWinWindowView(handles);
}

void DockAppLauncher::completeLaunchApp(const QString &command, const QString &winToken)
{
    if (command.isEmpty()) {
        return;
    }

    if (!winToken.isEmpty()) {
        const bool dockItemMatchesForeground = m_backend->isAppFocused(command);

        if (winToken.startsWith(QLatin1String("x11:"))) {
            QString wmGuess;
            if (dockItemMatchesForeground) {
                if (tryShowAppWindowOverview(command)) {
                    m_backend->emitWindowsUpdatedCoalesced();
                    return;
                }
            }
            if (DockWindowManagement::activatePackedOrMinimize(winToken,
                                                               dockItemMatchesForeground,
                                                               command,
                                                               wmGuess)) {
                if (dockItemMatchesForeground) {
                    m_backend->m_activeAppClass.clear();
                    m_backend->m_activeAppTitle.clear();
                } else if (!wmGuess.isEmpty()) {
                    m_backend->m_activeAppClass = wmGuess;
                }
                m_backend->emitWindowsUpdatedCoalesced();
            }
            return;
        }

        if (dockItemMatchesForeground) {
            if (tryShowAppWindowOverview(command)) {
                m_backend->emitWindowsUpdatedCoalesced();
                return;
            }
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowminimize"), winToken});
            m_backend->m_activeAppClass.clear();
            m_backend->m_activeAppTitle.clear();
            m_backend->emitWindowsUpdatedCoalesced();
        } else {
            QProcess::startDetached(QStringLiteral("kdotool"), {QStringLiteral("windowactivate"), winToken});
            m_backend->m_activeAppClass = DockBrowserUtils::execBasenameFromCommand(command);
            m_backend->emitWindowsUpdatedCoalesced();
        }
    } else {
        forceLaunchApp(command);
    }
}

void DockAppLauncher::launchApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }
    if (TaskBackend::isDolphinScopedCommand(command.toLower())) {
        const QString scopedLower = command.toLower();
        if (m_backend->isAppFocused(command) && m_backend->m_kdotoolAvailable) {
            if (tryShowAppWindowOverview(command)) {
                m_backend->emitWindowsUpdatedCoalesced();
                return;
            }
            QProcess::startDetached(QStringLiteral("kdotool"),
                                    {QStringLiteral("getactivewindow"), QStringLiteral("windowminimize")});
            m_backend->m_activeAppClass.clear();
            m_backend->m_activeAppTitle.clear();
            m_backend->emitWindowsUpdatedCoalesced();
            return;
        }
        const QString existingWin = TaskBackend::firstScopedDolphinWindowId(scopedLower, m_backend->m_kdotoolAvailable);
        if (!existingWin.isEmpty() && m_backend->m_kdotoolAvailable) {
            QProcess::startDetached(QStringLiteral("kdotool"),
                                    {QStringLiteral("windowactivate"), existingWin});
            return;
        }
        forceLaunchApp(command);
        return;
    }
    const QString cmdCopy = command;
    const quint64 seq = ++m_backend->m_launchSeq[cmdCopy];
    const QHash<QString, QVariantMap> currentKnownApps = m_backend->knownApps;
    TaskBackend *backend = m_backend;
    const bool kdotoolAvailable = m_backend->m_kdotoolAvailable;
    (void)QtConcurrent::run([backend, cmdCopy, seq, currentKnownApps, kdotoolAvailable]() {
        const QString winId = DockWindowManagement::resolveWindowHandleForLaunch(cmdCopy, currentKnownApps, kdotoolAvailable, kKdotoolTimeoutMs);
        QMetaObject::invokeMethod(
            backend,
            [backend, cmdCopy, winId, seq]() {
                if (backend->m_launchSeq.value(cmdCopy) != seq) {
                    return;
                }
                DockAppLauncher(backend).completeLaunchApp(cmdCopy, winId);
            },
            Qt::QueuedConnection);
    });
}

void DockAppLauncher::completeCloseApp(const QString &command, const QString &winToken)
{
    if (!winToken.isEmpty()) {
        if (winToken.startsWith(QLatin1String("x11:"))) {
            DockWindowManagement::closePackedWindow(winToken, m_backend->m_kdotoolAvailable);
            return;
        }
        QProcess::startDetached(QStringLiteral("kdotool"),
                                {QStringLiteral("windowclose"), winToken});
        return;
    }
}

void DockAppLauncher::closeApp(const QString &command)
{
    if (command.isEmpty()) {
        return;
    }
    const QString cmdCopy = command;
    const quint64 seq = ++m_backend->m_closeSeq[cmdCopy];
    const QHash<QString, QVariantMap> currentKnownApps = m_backend->knownApps;
    TaskBackend *backend = m_backend;
    const bool kdotoolAvailable = m_backend->m_kdotoolAvailable;
    (void)QtConcurrent::run([backend, cmdCopy, seq, currentKnownApps, kdotoolAvailable]() {
        const QString winId = DockWindowManagement::resolveWindowHandleForLaunch(cmdCopy, currentKnownApps, kdotoolAvailable, kKdotoolTimeoutMs);
        QMetaObject::invokeMethod(
            backend,
            [backend, cmdCopy, winId, seq]() {
                if (backend->m_closeSeq.value(cmdCopy) != seq) {
                    return;
                }
                DockAppLauncher(backend).completeCloseApp(cmdCopy, winId);
            },
            Qt::QueuedConnection);
    });
}

void DockAppLauncher::cycleAppWindows(const QString &command, int direction)
{
    if (command.isEmpty() || direction == 0 || !m_backend->m_kdotoolAvailable) {
        return;
    }
    
    const QHash<QString, QVariantMap> currentKnownApps = m_backend->knownApps;
    TaskBackend *backend = m_backend;
    (void)QtConcurrent::run([backend, command, direction, currentKnownApps]() {
        const QStringList handles = backend->windowHandlesForCommand(command, currentKnownApps);
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
}
