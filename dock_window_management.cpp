#include "dock_window_management.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QtGui/qguiapplication_platform.h>
#include <QProcess>
#include <QStringList>

#include <KWindowSystem/kwindowsystem.h>
#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
#include <KWindowSystem/KWindowInfo>
#include <KWindowSystem/KX11Extras>
#include <KWindowSystem/netwm.h>
#endif

namespace {

// --- Declarativo para kdotool search (--class / --name) ---

struct KdotoolSearchFilter {
    bool byName = false; // false ⇒ --class; true ⇒ --name
    QString needle;
};

static QString strippedExecBasename(const QString &command)
{
    QString exec =
        command.split(QLatin1Char(' '), Qt::SkipEmptyParts).value(0).split(QLatin1Char('/')).last().toLower();
    exec.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
    return exec;
}

static bool exeLooksLikeChromFamily(QStringView exe)
{
    const QString e = exe.toString();
    return e.contains(QLatin1String("chrom")) || e.contains(QLatin1String("chrome")) || e.contains(QLatin1String("edge"))
           || e.contains(QLatin1String("zen"));
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

    if (exeLower.contains(QLatin1String("agildomonitor"))) {
        chain.push_back(KdotoolSearchFilter{true, QStringLiteral("Agildo Monitor")});
        return chain;
    }
    if (exeLower.contains(QLatin1String("zen"))) {
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("zen")});
        return chain;
    }
    if (exeLower.contains(QLatin1String("faugus"))) {
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("faugus-launcher")});
        return chain;
    }
    if (exeLower.contains(QLatin1String("chrom"))) {
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("chromium")});
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("Chromium")});
        chain.push_back(KdotoolSearchFilter{false, QStringLiteral("google-chrome")});
        return chain;
    }

    const bool isBrowserWide = exeLooksLikeChromFamily(QStringView(exeLower));

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

static QString combinedWmLower(const QByteArray &classNameBytes, const QByteArray &classClassBytes)
{
    const QString cn = QString::fromUtf8(classNameBytes).toLower();
    const QString cc = QString::fromUtf8(classClassBytes).toLower();
    return cn + QLatin1Char(' ') + cc;
}

// Mesma filosofia da antiga findWindowIdForCmd, mas usando metadados reais das janelas X11 visitadas.
static bool stackingWindowBelongsToCommand(const QString &command,
                                           const QString &clsBlobLower,
                                           const QString &captionLower,
                                           const QHash<QString, QVariantMap> &knownApps)
{
    QString wmClassDesk;
    QString appNameDesk;
    if (knownApps.contains(command)) {
        wmClassDesk = knownApps.value(command)[QStringLiteral("wmclass")].toString().toLower();
        appNameDesk = knownApps.value(command)[QStringLiteral("name")].toString().toLower();
    }

    QString appIdCaptured;
    if (command.contains(QLatin1String("--app-id="), Qt::CaseInsensitive)) {
        const QStringList parts = command.split(QLatin1Char(' '), Qt::SkipEmptyParts);
        for (const QString &part : parts) {
            if (part.startsWith(QLatin1String("--app-id="), Qt::CaseInsensitive)) {
                appIdCaptured = part.mid(9);
                appIdCaptured.remove(QLatin1Char('"')).remove(QLatin1Char('\''));
                appIdCaptured = appIdCaptured.toLower();
                break;
            }
        }
    }

    const QString cls = clsBlobLower;
    const QString cap = captionLower;

    if (command.contains(QLatin1String("--app-id="), Qt::CaseInsensitive)) {
        const bool idHit = cls.contains(QLatin1String("crx_") + appIdCaptured)
                           || cls.contains(QLatin1String("chrome-") + appIdCaptured);
        if (idHit) {
            return true;
        }
        if (!appNameDesk.isEmpty() && cap.contains(appNameDesk)) {
            return true;
        }
        return false;
    }

    const QString execFull = strippedExecBasename(command);
    const bool isBrowserWide = exeLooksLikeChromFamily(QStringView(execFull));

    if (execFull.contains(QLatin1String("agildomonitor"))) {
        return cls.contains(QLatin1String("agildomonitor")) || cap.contains(QLatin1String("agildo monitor"));
    }
    if (execFull.contains(QLatin1String("zen"))) {
        return cls.contains(QLatin1String("zen"));
    }
    if (execFull.contains(QLatin1String("faugus"))) {
        return cls.contains(QLatin1String("faugus")) || cls.contains(QLatin1String("faugus-launcher"));
    }
    if (execFull.contains(QLatin1String("chrom"))) {
        const bool chromiumish = cls.contains(QLatin1String("chromium")) || cls.contains(QLatin1String("google-chrome"))
                                 || cls.contains(QLatin1String("chrome"));
        const bool edged = execFull.contains(QLatin1String("edge")) && cls.contains(QLatin1String("edge"));
        return chromiumish || edged;
    }

    if (!wmClassDesk.isEmpty() && cls.contains(wmClassDesk)) {
        return true;
    }
    if (!appNameDesk.isEmpty() && cap.contains(appNameDesk)) {
        return true;
    }
    if (!isBrowserWide && cls.contains(execFull)) {
        return true;
    }
    return false;
}

#if defined(KWINDOWSYSTEM_HAVE_X11) && QT_CONFIG(xcb)
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
    return nativeX11ClientUsable() || kdotoolOnPath;
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

    if (cls.isEmpty()) {
        return false;
    }

    QString execName = strippedExecBasename(command);

    if (execName.contains(QLatin1String("faugus"))) {
        return cls.contains(QLatin1String("faugus"));
    }
    if (execName.contains(QLatin1String("zen"))) {
        return cls.contains(QLatin1String("zen"));
    }
    if (execName.contains(QLatin1String("agildomonitor"))) {
        return cap.contains(QLatin1String("agildo monitor"));
    }

    if (execName.contains(QLatin1String("chromium")) || execName.contains(QLatin1String("chrome"))
        || execName.contains(QLatin1String("edge"))) {
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
    QProcess p;
    p.start(QStringLiteral("kdotool"), args);
    p.waitForFinished(timeoutMs);
    return QString::fromUtf8(p.readAllStandardOutput()).trimmed().split(QLatin1Char('\n')).value(0).trimmed();
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

    if (!kdotoolAvailable) {
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

    if (kdotoolAvailable)
        QProcess::startDetached(QStringLiteral("kdotool"),
                                {QStringLiteral("windowclose"),
                                 QStringLiteral("0x") + QString::number(static_cast<quintptr>(wid), 16)});
    return kdotoolAvailable;
}

} // namespace DockWindowManagement