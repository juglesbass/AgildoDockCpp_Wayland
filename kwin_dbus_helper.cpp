#include "kwin_dbus_helper.h"
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusReply>
#include <QTemporaryDir>
#include <QFile>
#include <QTextStream>
#include <QStandardPaths>
#include <QProcess>
#include <QDebug>
#include <QDir>
#include <QCoreApplication>

static const QString KWIN_SERVICE = QStringLiteral("org.kde.KWin");
static const QString SCRIPTING_PATH = QStringLiteral("/Scripting");
static const QString SCRIPTING_IFACE = QStringLiteral("org.kde.kwin.Scripting");

// O script JS que injetamos no KWin
static const char* AGILDO_KWIN_SCRIPT = R"(
function getWins() {
    return workspace.windowList ? workspace.windowList() : workspace.clientList();
}
function runCmd(cmd, arg1, arg2) {
    if (cmd == "active") {
        var c = workspace.activeWindow;
        if (!c) return "";
        var cls = (c.resourceClass || c.desktopFileName || c.desktopWindowAppId || c.resourceName || "").toString().replace(".desktop", "");
        return c.internalId.toString() + "\n" + cls + "\n" + (c.caption || "").toString() + "\n" + c.width + "x" + c.height;
    } else if (cmd == "search") {
        var wins = getWins();
        var res = [];
        var exact = (arg2 == "true");
        for (var i=0; i<wins.length; i++) {
            var c = wins[i];
            var matchStr = (arg1 || "").toLowerCase();
            var cls = (c.resourceClass || c.desktopFileName || c.desktopWindowAppId || "").toString().toLowerCase().replace(".desktop", "");
            var resName = (c.resourceName || "").toString().toLowerCase();
            if (exact ? (cls == matchStr || resName == matchStr) : (cls.indexOf(matchStr) !== -1 || resName.indexOf(matchStr) !== -1)) {
                res.push(c.internalId.toString());
            }
        }
        return res.join("\n");
    } else if (cmd == "activate") {
        var wins = getWins();
        for (var i=0; i<wins.length; i++) {
            if (wins[i].internalId.toString() == arg1) {
                workspace.activeWindow = wins[i];
                return "1";
            }
        }
        return "0";
    } else if (cmd == "close") {
        var wins = getWins();
        for (var i=0; i<wins.length; i++) {
            if (wins[i].internalId.toString() == arg1) {
                wins[i].closeWindow();
                return "1";
            }
        }
        return "0";
    } else if (cmd == "info") {
        var wins = getWins();
        for (var i=0; i<wins.length; i++) {
            if (wins[i].internalId.toString() == arg1) {
                var cls = (wins[i].resourceClass || wins[i].desktopFileName || wins[i].desktopWindowAppId || wins[i].resourceName || "").toString().replace(".desktop", "");
        return cls + "\n" + (wins[i].caption || "").toString();
            }
        }
        return "\n";
    }
    return "";
}

registerDBusCall("agildoCmd", function(cmd, arg1, arg2) {
    return runCmd(cmd, arg1, arg2);
});
)";

KWinDBusHelper* KWinDBusHelper::instance()
{
    static KWinDBusHelper s_instance;
    return &s_instance;
}

KWinDBusHelper::KWinDBusHelper(QObject *parent)
    : QObject(parent)
{
}

KWinDBusHelper::~KWinDBusHelper()
{
    unloadScript();
}

void KWinDBusHelper::initialize()
{
    if (m_initialized) return;
    m_initialized = true;
    m_available = loadScript();
    
    if (m_available) {
        qDebug() << "AgildoDock: KWin DBus Helper initialized successfully at" << m_scriptPath;
    } else {
        qWarning() << "AgildoDock: Failed to initialize KWin DBus Helper. Ensure KWin is running.";
    }
}

bool KWinDBusHelper::isAvailable()
{
    if (!m_initialized) initialize();
    return m_available;
}

bool KWinDBusHelper::loadScript()
{
    // Try Plasma 5 fast approach first (loadScript via DBus)
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, SCRIPTING_PATH, SCRIPTING_IFACE, QStringLiteral("loadScript"));
    
    // We create a temp file for the script
    static QTemporaryDir tempDir;
    if (!tempDir.isValid()) return false;
    
    QString jsFile = tempDir.path() + QStringLiteral("/agildodock_helper.js");
    QFile f(jsFile);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text)) {
        QTextStream out(&f);
        out << AGILDO_KWIN_SCRIPT;
        f.close();
    }
    
    msg << jsFile << QStringLiteral("AgildoDockHelper");
    QDBusReply<int> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 2000);
    
    if (reply.isValid() && reply.value() > 0) {
        int scriptId = reply.value();
        m_scriptPath = QStringLiteral("/Scripting/Script%1").arg(scriptId);
        
        // Iniciar o script
        QDBusMessage runMsg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral("org.kde.kwin.Script"), QStringLiteral("run"));
        QDBusConnection::sessionBus().call(runMsg, QDBus::Block, 2000);
        
        // Verificar se responde
        QDBusMessage testMsg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
        testMsg << QStringLiteral("test") << QStringLiteral("") << QStringLiteral("");
        QDBusMessage res = QDBusConnection::sessionBus().call(testMsg, QDBus::Block, 100);
        if (res.type() == QDBusMessage::ReplyMessage) {
            return true;
        }
        return false;
    }

    // Plasma 6 removed loadScript. Fallback to installing a KPackage!
    // Construct KWin Script Package structure
    QString pkgDir = tempDir.path() + QStringLiteral("/pkg");
    QDir().mkpath(pkgDir + QStringLiteral("/contents/code"));
    
    QFile meta(pkgDir + QStringLiteral("/metadata.json"));
    if (meta.open(QIODevice::WriteOnly)) {
        meta.write("{\n"
                   "  \"KPlugin\": {\n"
                   "    \"Name\": \"AgildoDock KWin Helper\",\n"
                   "    \"Description\": \"DBus API for AgildoDock\",\n"
                   "    \"Id\": \"org.agildosoft.agildodock.kwinhelper\",\n"
                   "    \"Category\": \"Window Management\"\n"
                   "  },\n"
                   "  \"X-Plasma-API\": \"javascript\",\n"
                   "  \"X-Plasma-MainScript\": \"code/main.js\"\n"
                   "}\n");
        meta.close();
    }
    
    QFile mainJs(pkgDir + QStringLiteral("/contents/code/main.js"));
    if (mainJs.open(QIODevice::WriteOnly)) {
        mainJs.write(AGILDO_KWIN_SCRIPT);
        mainJs.close();
    }
    
    // Install via kpackagetool6 (or 5)
    QProcess p;
    QString kpackageBin = QStandardPaths::findExecutable(QStringLiteral("kpackagetool6"));
    if (kpackageBin.isEmpty()) kpackageBin = QStandardPaths::findExecutable(QStringLiteral("kpackagetool5"));
    
    if (!kpackageBin.isEmpty()) {
        p.start(kpackageBin, {QStringLiteral("-i"), pkgDir, QStringLiteral("-t"), QStringLiteral("KWin/Script")});
        p.waitForFinished(3000);
        // It might already be installed, so upgrade
        p.start(kpackageBin, {QStringLiteral("-u"), pkgDir, QStringLiteral("-t"), QStringLiteral("KWin/Script")});
        p.waitForFinished(3000);
        
        // Enable it in kwinrc
        QProcess::execute(QStringLiteral("kwriteconfig6"), {QStringLiteral("--file"), QStringLiteral("kwinrc"), QStringLiteral("--group"), QStringLiteral("Plugins"), QStringLiteral("--key"), QStringLiteral("org.agildosoft.agildodock.kwinhelperEnabled"), QStringLiteral("true")});
        QProcess::execute(QStringLiteral("kwriteconfig5"), {QStringLiteral("--file"), QStringLiteral("kwinrc"), QStringLiteral("--group"), QStringLiteral("Plugins"), QStringLiteral("--key"), QStringLiteral("org.agildosoft.agildodock.kwinhelperEnabled"), QStringLiteral("true")});
        
        // Reconfigure KWin
        QDBusMessage reconfMsg = QDBusMessage::createMethodCall(KWIN_SERVICE, QStringLiteral("/KWin"), QStringLiteral("org.kde.KWin"), QStringLiteral("reconfigure"));
        QDBusConnection::sessionBus().call(reconfMsg, QDBus::Block, 2000);
        
        // The script is now active and registers dbus on org.kde.KWin!
        // In Plasma 6, registerDBusCall registers the method on the script's path (which is /Scripting/ScriptXYZ where XYZ is internal).
        // BUT wait! If we don't know the path, how do we call it?
        // Let's use the broadcast feature or find the path by introspecting /Scripting!
        
        // Find the script path by introspecting /Scripting
        QDBusMessage introspectMsg = QDBusMessage::createMethodCall(KWIN_SERVICE, SCRIPTING_PATH, QStringLiteral("org.freedesktop.DBus.Introspectable"), QStringLiteral("Introspect"));
        QDBusReply<QString> introReply = QDBusConnection::sessionBus().call(introspectMsg, QDBus::Block, 2000);
        if (introReply.isValid()) {
            QString xml = introReply.value();
            // Basic parse for <node name="ScriptXYZ"/>
            int offset = 0;
            while ((offset = xml.indexOf(QStringLiteral("<node name=\"Script"), offset)) != -1) {
                int end = xml.indexOf(QStringLiteral("\""), offset + 12);
                QString nodeName = xml.mid(offset + 12, end - (offset + 12));
                offset = end;
                
                QString candidatePath = SCRIPTING_PATH + QStringLiteral("/") + nodeName;
                // Test if it responds to agildoCmd
                QDBusMessage testMsg = QDBusMessage::createMethodCall(KWIN_SERVICE, candidatePath, QStringLiteral(""), QStringLiteral("agildoCmd"));
                testMsg << QStringLiteral("test") << QStringLiteral("") << QStringLiteral("");
                QDBusMessage res = QDBusConnection::sessionBus().call(testMsg, QDBus::Block, 100);
                if (res.type() == QDBusMessage::ReplyMessage) {
                    m_scriptPath = candidatePath;
                    return true;
                }
            }
        }
    }
    
    return false;
}

void KWinDBusHelper::unloadScript()
{
    if (m_scriptPath.isEmpty()) return;
    
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral("org.kde.kwin.Script"), QStringLiteral("stop"));
    QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
}

QString KWinDBusHelper::getActiveWindowInfo()
{
    if (!isAvailable()) return {};
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
    msg << QStringLiteral("active") << QStringLiteral("") << QStringLiteral("");
    QDBusReply<QString> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
    if (reply.isValid()) return reply.value();
    return {};
}

QStringList KWinDBusHelper::searchWindows(const QString &query, bool exactMatch)
{
    if (!isAvailable()) return {};
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
    msg << QStringLiteral("search") << query << (exactMatch ? QStringLiteral("true") : QStringLiteral("false"));
    QDBusReply<QString> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
    if (reply.isValid()) {
        QString out = reply.value().trimmed();
        if (out.isEmpty()) return {};
        return out.split(QLatin1Char('\n'));
    }
    return {};
}

QString KWinDBusHelper::getWindowInfo(const QString &internalId)
{
    if (!isAvailable()) return {};
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
    msg << QStringLiteral("info") << internalId << QStringLiteral("");
    QDBusReply<QString> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
    if (reply.isValid()) return reply.value();
    return {};
}

bool KWinDBusHelper::activateWindow(const QString &internalId)
{
    if (!isAvailable()) return false;
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
    msg << QStringLiteral("activate") << internalId << QStringLiteral("");
    QDBusReply<QString> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
    return reply.isValid() && reply.value() == QStringLiteral("1");
}

bool KWinDBusHelper::closeWindow(const QString &internalId)
{
    if (!isAvailable()) return false;
    QDBusMessage msg = QDBusMessage::createMethodCall(KWIN_SERVICE, m_scriptPath, QStringLiteral(""), QStringLiteral("agildoCmd"));
    msg << QStringLiteral("close") << internalId << QStringLiteral("");
    QDBusReply<QString> reply = QDBusConnection::sessionBus().call(msg, QDBus::Block, 1000);
    return reply.isValid() && reply.value() == QStringLiteral("1");
}
