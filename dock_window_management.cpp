#include "dock_window_management.h"
#include "dock_browser_utils.h"
#include "kwin_dbus_helper.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>
#include <QProcess>
#include <QStringList>

#include <QDBusConnection>
#include <QDBusMessage>

#include <KWindowSystem/kwindowsystem.h>
#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
#include <KWindowSystem/KWindowInfo>
#include <KWindowSystem/KX11Extras>
#include <KWindowSystem/netwm.h>
#endif

namespace {

// --- Declarativo para kdotool search (--class / --name) ---

enum class AppType { Generic, AgildoMonitor, Zen, Faugus, Lact, Chromium };
static AppType identifyApp(const QString &execNameLower) {
    if (execNameLower.contains(QLatin1String("agildomonitor"))) return AppType::AgildoMonitor;
    if (execNameLower.contains(QLatin1String("zen"))) return AppType::Zen;
    if (execNameLower.contains(QLatin1String("faugus"))) return AppType::Faugus;
    if (execNameLower == QLatin1String("lact")) return AppType::Lact;
    if (execNameLower.contains(QLatin1String("chrom")) || execNameLower.contains(QLatin1String("edge"))) return AppType::Chromium;
    return AppType::Generic;
}

struct KdotoolSearchFilter {
    bool byName = false; // false ⇒ --class; true ⇒ --name
    QString needle;
};

static QString strippedExecBasename(const QString &command)
{
    return DockBrowserUtils::execBasenameFromCommand(command);
}

static QVector<KdotoolSearchFilter>
buildKdotoolSearchChain(const QString &command,
                        const QString &exeLower,
                        const QString &desktopWmClass,
                        const QString &desktopAppName,
                        QString *outAppId)
{
    QVector<KdotoolSearchFilter> chain;

    if (outAppId) {
        outAppId->clear();
    }

    if (command.contains(QLatin1String("--app-id="), Qt::CaseInsensitive)) {
        QString appId;
        const QStringList parts = command.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            if (part.startsWith(QLatin1String("--app-id="), Qt::CaseInsensitive)) {
                appId = part.mid(9);
                appId.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
                break;
            }
        }
        if (!appId.isEmpty()) {
            if (outAppId)
                *outAppId = appId.toLower();
            chain.push_back(KdotoolSearchFilter{false, QStringLiteral("crx_") + appId});
            chain.push_back(KdotoolSearchFilter{false, QStringLiteral("chrome-") + appId});
            if (!desktopAppName.trimmed().isEmpty()) {
                chain.push_back(KdotoolSearchFilter{true, desktopAppName});
            }
        }
        return chain;
    }

    switch (identifyApp(exeLower)) {
    case AppType::AgildoMonitor:
        chain.push_back(KdotoolSearchFilter{true, QStringLiteral("Agildo Monitor")});
        return chain;
    case AppType::Zen:
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("zen")});
        return chain;
    case AppType::Faugus:
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("faugus-launcher")});
        return chain;
    case AppType::Lact:
        if (!desktopAppName.trimmed().isEmpty()) {
            chain.push_back(KdotoolSearchFilter{true, desktopAppName});
        }
        return chain;
    case AppType::Chromium:
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("chromium")});
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("Chromium")});
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("google-chrome")});
        return chain;
    case AppType::Generic:
    default:
        break;
    }

    const bool isBrowserWide = DockBrowserUtils::commandLooksLikeBrowser(exeLower);

    if (!desktopWmClass.isEmpty()) {
        chain.push_back(KdotoolSearchFilter{false, desktopWmClass});
    }
    if (!desktopAppName.isEmpty()) {
        chain.push_back(KdotoolSearchFilter{true, desktopAppName});
    }
    if (!isBrowserWide) {
        chain.push_back(KdotoolSearchFilter{false, exeLower});
    }
    return chain;
}

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
static QStringList allOwnedX11Windows(const QString &command, const QHash<QString, QVariantMap> &knownApps)
{
    QStringList packed;
    const QList<WId> order = KX11Extras::stackingOrder();
    for (const WId wid : order) {
        KWindowInfo iw(wid, NET::WMVisibleName, NET::WM2WindowClass);
        if (!iw.valid(false)) {
            continue;
        }
        const QString clsBlob = combinedWmLower(iw.windowClassName(), iw.windowClassClass());
        const QString caption = iw.visibleName().toLower();
        if (stackingWindowBelongsToCommand(command, clsBlob, caption, knownApps)) {
            packed << encodeX11WId(wid);
        }
    }
    return packed;
}

static WId topmostOwnedX11Window(const QString &command, const QHash<QString, QVariantMap> &knownApps)
{
    const QList<WId> order = KX11Extras::stackingOrder();
    for (qsizetype i = order.size() - 1; i >= 0; --i) {
        const WId wid = order.at(i);
        KWindowInfo iw(wid, NET::WMVisibleName, NET::WM2WindowClass);
        if (!iw.valid(false)) {
            continue;
        }
        const QString clsBlob = combinedWmLower(iw.windowClassName(), iw.windowClassClass());
        const QString caption = iw.visibleName().toLower();
        if (stackingWindowBelongsToCommand(command, clsBlob, caption, knownApps)) {
            return wid;
        }
    }
    return 0;
}
#endif

} // namespace

namespace DockWindowManagement {

bool nativeX11ClientUsable()
{
#if QT_CONFIG(xcb)
    auto *gui = qobject_cast<QGuiApplication *>(QCoreApplication::instance());
    auto *iface = gui ? gui->nativeInterface<QNativeInterface::QX11Application>() : nullptr;
    return iface != nullptr && KWindowSystem::isPlatformX11();
#else
    return false;
#endif
}

bool fullForeignWindowCtlAvailable(bool kdotoolOnPath)
{
    return nativeX11ClientUsable() || kdotoolOnPath || KWinDBusHelper::instance()->isAvailable();
}

bool commandMatchesForegroundHints(const QString &command,
                                     QStringView wmCombinedClassLower,
                                     QStringView captionLower,
                                     const QHash<QString, QVariantMap> &knownApps)
{
    if (command.isEmpty()) {
        return false;
    }

    QString appName;
    QString wmClass;
    if (knownApps.contains(command)) {
        appName = knownApps[command][QStringLiteral("name")].toString().toLower();
        wmClass = knownApps[command][QStringLiteral("wmclass")].toString().toLower();
    }

    const QString cmdLower = command.toLower();
    const QString cls = QString(wmCombinedClassLower).trimmed();
    const QString cap = QString(captionLower);

    if (cmdLower.contains(QLatin1String("--app-id="))) {
        QString appId;
        const QStringList parts = cmdLower.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        for (const QString &p : parts) {
            if (p.startsWith(QLatin1String("--app-id="))) {
                appId = p.mid(9);
                appId.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
                break;
            }
        }

        if (!appId.isEmpty()
            && (cls.contains(QLatin1String("crx_") + appId) || cls.contains(QLatin1String("chrome-") + appId))) {
            return true;
        }
        if (!appName.isEmpty() && cap.contains(appName)) {
            return true;
        }
        return false;
    }

    QString execName = strippedExecBasename(command);
    AppType type = identifyApp(execName);

    if (type == AppType::Lact) {
        return !appName.isEmpty() && cap.toLower().contains(appName);
    }

    if (cls.isEmpty()) {
        return false;
    }

    switch (type) {
    case AppType::Faugus:
        return cls.contains(QLatin1String("faugus"));
    case AppType::Zen:
        return cls.contains(QLatin1String("zen"));
    case AppType::AgildoMonitor:
        return cap.contains(QLatin1String("agildo monitor"));
    case AppType::Chromium:
        if (!cls.contains(execName)) {
            return false;
        }
        for (const QVariantMap &app : knownApps) {
            if (app[QStringLiteral("cmd")].toString().toLower().contains(QLatin1String("--app-id"))) {
                const QString webAppName = app[QStringLiteral("name")].toString().toLower();
                if (!webAppName.isEmpty() && cap.contains(webAppName)) {
                    return false;
                }
            }
        }
        return true;
    case AppType::Generic:
    default:
        break;
    }

    return cls.contains(execName) || (!wmClass.isEmpty() && cls.contains(wmClass));
}

QString encodeX11WId(WId wid)
{
    return QStringLiteral("x11:") + QString::number(static_cast<quintptr>(wid), 16);
}

bool decodeX11WId(const QString &packed, WId *out)
{
    if (!out || !packed.startsWith(QLatin1String("x11:"))) {
        return false;
    }
    bool ok = false;
    const QString tail = packed.sliced(QStringLiteral("x11:").length());
    const quint64 v = tail.toULongLong(&ok, 16);
    if (!ok || v == 0) {
        return false;
    }
    *out = static_cast<WId>(v);
    return true;
}

QString runFirstKdotoolSearchHit(const QStringList &args, int timeoutMs)
{
    if (KWinDBusHelper::instance()->isAvailable()) {
        QString query = args.size() > 2 ? args.last() : QString();
        bool exact = args.contains(QStringLiteral("--exact"));
        QStringList res = KWinDBusHelper::instance()->searchWindows(query, exact);
        if (!res.isEmpty()) return res.first();
        return {};
    }
    QProcess p;
    p.start(QStringLiteral("kdotool"), args);
    if (!p.waitForFinished(timeoutMs)) {
        qWarning() << "AgildoDock kdotool: timeout" << args;
        p.kill();
        return {};
    }
    if (p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0) {
        const QString err = QString::fromUtf8(p.readAllStandardError()).trimmed();
        qWarning() << "AgildoDock kdotool:" << args.join(QLatin1Char(' '))
                   << "exit" << p.exitCode() << err;
    }
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed().split(QLatin1Char('\n')).value(0).trimmed();
}

static QStringList runAllKdotoolSearchHits(const QStringList &args, int timeoutMs)
{
    if (KWinDBusHelper::instance()->isAvailable()) {
        QString query = args.size() > 2 ? args.last() : QString();
        bool exact = args.contains(QStringLiteral("--exact"));
        return KWinDBusHelper::instance()->searchWindows(query, exact);
    }
    QProcess p;
    p.start(QStringLiteral("kdotool"), args);
    if (!p.waitForFinished(timeoutMs)) {
        qWarning() << "AgildoDock kdotool: timeout" << args;
        p.kill();
        return {};
    }
    if (p.exitStatus() != QProcess::NormalExit || p.exitCode() != 0) {
        const QString err = QString::fromUtf8(p.readAllStandardError()).trimmed();
        qWarning() << "AgildoDock kdotool:" << args.join(QLatin1Char(' '))
                   << "exit" << p.exitCode() << err;
    }
    const QString out = QString::fromUtf8(p.readAllStandardOutput()).trimmed();
    if (out.isEmpty()) {
        return {};
    }
    QStringList lines = out.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (QString &line : lines) {
        line = line.trimmed();
    }
    lines.removeDuplicates();
    return lines;
}

static QStringList filterKdotoolHandlesForCommand(const QStringList &handles,
                                                  const QString &command,
                                                  const QHash<QString, QVariantMap> &knownApps,
                                                  int timeoutMs)
{
    QStringList filtered;
    for (const QString &id : handles) {
        if (id.isEmpty()) {
            continue;
        }
        QString clsLower, nameLower;
        if (KWinDBusHelper::instance()->isAvailable()) {
            QString info = KWinDBusHelper::instance()->getWindowInfo(id);
            QStringList lines = info.split(QLatin1Char('\n'));
            if (lines.size() >= 2) {
                clsLower = lines[0].trimmed().toLower();
                nameLower = lines[1].trimmed().toLower();
            }
        } else {
            QProcess clsP;
            clsP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowclassname"), id});
            if (clsP.waitForFinished(timeoutMs)) {
                clsLower = QString::fromUtf8(clsP.readAllStandardOutput()).trimmed().toLower();
            }
            
            QProcess nameP;
            nameP.start(QStringLiteral("kdotool"), {QStringLiteral("getwindowname"), id});
            if (nameP.waitForFinished(timeoutMs)) {
                nameLower = QString::fromUtf8(nameP.readAllStandardOutput()).trimmed().toLower();
            }
        }
        if (commandMatchesForegroundHints(command, clsLower, nameLower, knownApps)) {
            filtered << id;
        }
    }
    return filtered;
}

QString resolveWindowHandleForLaunch(const QString &command,
                                     const QHash<QString, QVariantMap> &knownApps,
                                     bool kdotoolAvailable,
                                     int kdotoolTimeoutMs)
{
    if (command.isEmpty()) {
        return {};
    }

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
    if (nativeX11ClientUsable()) {
        const WId xid = topmostOwnedX11Window(command, knownApps);
        if (xid != 0) {
            return encodeX11WId(xid);
        }
    }
#else
    Q_UNUSED(knownApps);
#endif

    QString wmDesk = knownApps.value(command)[QStringLiteral("wmclass")].toString().toLower();
    QString nameDesk = knownApps.value(command)[QStringLiteral("name")].toString();

    QString appIdDummy;
    const QVector<KdotoolSearchFilter> chain =
        buildKdotoolSearchChain(command, strippedExecBasename(command), wmDesk, nameDesk, &appIdDummy);
    Q_UNUSED(appIdDummy);

    if (!kdotoolAvailable && !KWinDBusHelper::instance()->isAvailable()) {
        return {};
    }

    for (const KdotoolSearchFilter &f : chain) {
        QStringList args{QStringLiteral("search")};
        if (f.byName) {
            args << QStringLiteral("--name") << f.needle;
        } else {
            args << QStringLiteral("--class") << f.needle;
        }

        const QString hit = runFirstKdotoolSearchHit(args, kdotoolTimeoutMs);
        if (!hit.isEmpty()) {
            return hit;
        }
    }
    return {};
}

QStringList resolveAllWindowHandlesForLaunch(const QString &command,
                                             const QHash<QString, QVariantMap> &knownApps,
                                             bool kdotoolAvailable,
                                             int kdotoolTimeoutMs)
{
    if (command.isEmpty()) {
        return {};
    }

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
    if (nativeX11ClientUsable()) {
        const QStringList x11Packed = allOwnedX11Windows(command, knownApps);
        if (!x11Packed.isEmpty()) {
            return x11Packed;
        }
    }
#endif

    QString wmDesk = knownApps.value(command)[QStringLiteral("wmclass")].toString().toLower();
    QString nameDesk = knownApps.value(command)[QStringLiteral("name")].toString();

    QString appIdDummy;
    const QVector<KdotoolSearchFilter> chain =
        buildKdotoolSearchChain(command, strippedExecBasename(command), wmDesk, nameDesk, &appIdDummy);
    Q_UNUSED(appIdDummy);

    if (!kdotoolAvailable && !KWinDBusHelper::instance()->isAvailable()) {
        return {};
    }

    for (const KdotoolSearchFilter &f : chain) {
        QStringList args{QStringLiteral("search")};
        if (f.byName) {
            args << QStringLiteral("--name") << f.needle;
        } else {
            args << QStringLiteral("--class") << f.needle;
        }

        const QStringList hits = runAllKdotoolSearchHits(args, kdotoolTimeoutMs);
        if (hits.isEmpty()) {
            continue;
        }

        const QStringList filtered = filterKdotoolHandlesForCommand(hits, command, knownApps, kdotoolTimeoutMs);
        return filtered.isEmpty() ? hits : filtered;
    }
    return {};
}

bool activateKWinWindowView(const QStringList &handles)
{
    if (handles.isEmpty()) {
        return false;
    }

    QDBusMessage msg = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                      QStringLiteral("/org/kde/KWin/Effect/WindowView1"),
                                                      QStringLiteral("org.kde.KWin.Effect.WindowView1"),
                                                      QStringLiteral("activate"));
    msg.setArguments({handles});
    const QDBusMessage reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 600);
    return reply.type() == QDBusMessage::ReplyMessage;
}

bool fillActiveHintsFromNativeStacking(QString &outClassLower,
                                       QString &outTitleLower,
                                       QSize *outInnerSizeOpt,
                                       QSize * /*ignored*/)
{
#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
    if (!nativeX11ClientUsable()) {
        return false;
    }
    const WId wid = KX11Extras::activeWindow();
    if (wid == 0) {
        return false;
    }
    KWindowInfo iw(wid,
                     NET::WMGeometry | NET::WMVisibleName,
                     NET::WM2WindowClass);
    if (!iw.valid(false)) {
        return false;
    }
    const QString vn = iw.visibleName();
    outTitleLower = vn.toLower();
    // Primeira parcela WM_CLASS (paridade com primeira linha do kdotool getwindowclassname)
    outClassLower = QString::fromUtf8(iw.windowClassName()).toLower();


    if (outInnerSizeOpt) {
        *outInnerSizeOpt = iw.geometry().size();
    }
    return true;
#else
    Q_UNUSED(outClassLower);
    Q_UNUSED(outTitleLower);
    Q_UNUSED(outInnerSizeOpt);
    return false;
#endif
}

bool activeWindowProbablyCoversWorkArea(const QSize &windowInner,
                                        const QSize &screenPx,
                                        qreal widthRatio,
                                        qreal heightRatio)
{
    bool covers = false;
    if (windowInner.isValid() && screenPx.width() > 0 && screenPx.height() > 0) {
        covers = windowInner.width() >= int(screenPx.width() * widthRatio)
                 && windowInner.height() >= int(screenPx.height() * heightRatio);
    }
    return covers;
}

bool activatePackedOrMinimize(const QString &packedWin,
                              bool minimizeIfFocused,
                              const QString &commandForHints,
                              QString &outActiveAppClassGuess)
{
    WId wid = 0;
    outActiveAppClassGuess.clear();

    if (!decodeX11WId(packedWin, &wid)) {
        return false;
    }

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
    if (!nativeX11ClientUsable()) {
        return false;
    }

    if (minimizeIfFocused) {
        KX11Extras::minimizeWindow(wid);
        return true;
    }
    KX11Extras::forceActiveWindow(wid);
    outActiveAppClassGuess = strippedExecBasename(commandForHints);
    return true;
#else
    Q_UNUSED(minimizeIfFocused);
    Q_UNUSED(commandForHints);
    return false;
#endif
}

bool closePackedWindow(const QString &packedWin, bool kdotoolAvailable)
{
    WId wid = 0;
    if (!decodeX11WId(packedWin, &wid))
        return false;

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
    auto *gui = qobject_cast<QGuiApplication *>(QCoreApplication::instance());
    auto *iface = gui ? gui->nativeInterface<QNativeInterface::QX11Application>() : nullptr;
    auto *cx = iface ? iface->connection() : nullptr;
    if (cx) {
        NETRootInfo net(cx, NET::Supported, {}, -1, false);
        net.closeWindowRequest(static_cast<xcb_window_t>(wid));
        return true;
    }
#endif

    if (KWinDBusHelper::instance()->isAvailable()) {
        return KWinDBusHelper::instance()->closeWindow(QString::number(wid));
    }
    
    if (kdotoolAvailable) {
        QProcess::startDetached(QStringLiteral("kdotool"),
                                {QStringLiteral("windowclose"), QString::number(wid)});
        return true;
    }
    return false;
}

} // namespace DockWindowManagement