#include "dock_hyprland_helper.h"
#include "dock_browser_utils.h"

#include <QProcess>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QDateTime>
#include <QMutex>
#include <QMutexLocker>
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QTextStream>
#include <QStandardPaths>
#include <QLocalSocket>

namespace {
    struct CachedClients {
        qint64 timestampMs = 0;
        QList<HyprClient> clients;
    };
    static QMutex s_hyprMutex;
    static CachedClients s_cachedClients;

    struct CachedActiveWin {
        qint64 timestampMs = 0;
        HyprClient activeWin;
    };
    static CachedActiveWin s_cachedActive;

    static bool titleLooksLikeDownloads(const QString &titleLower)
    {
        return titleLower.contains(QStringLiteral("download"))
            || titleLower.contains(QStringLiteral("transferênc"))
            || titleLower.contains(QStringLiteral("descargas"));
    }

    static bool titleLooksLikeTrash(const QString &titleLower)
    {
        return titleLower.contains(QStringLiteral("trash"))
            || titleLower.contains(QStringLiteral("lixeira"))
            || titleLower.contains(QStringLiteral("corbeille"))
            || titleLower.contains(QStringLiteral("papelera"));
    }
}

bool DockHyprlandHelper::isHyprlandActive()
{
    static const bool s_isHypr = !qgetenv("HYPRLAND_INSTANCE_SIGNATURE").isEmpty()
        || QString::fromLocal8Bit(qgetenv("XDG_CURRENT_DESKTOP")).contains(QLatin1String("Hyprland"), Qt::CaseInsensitive)
        || QString::fromLocal8Bit(qgetenv("XDG_SESSION_DESKTOP")).contains(QLatin1String("Hyprland"), Qt::CaseInsensitive);
    return s_isHypr;
}

QList<HyprClient> DockHyprlandHelper::getClients()
{
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    {
        QMutexLocker locker(&s_hyprMutex);
        if (s_cachedClients.timestampMs > 0 && (nowMs - s_cachedClients.timestampMs) < 40) {
            return s_cachedClients.clients;
        }
    }

    QProcess proc;
    proc.start(QStringLiteral("hyprctl"), {QStringLiteral("clients"), QStringLiteral("-j")});
    if (!proc.waitForFinished(120)) {
        proc.kill();
        QMutexLocker locker(&s_hyprMutex);
        return s_cachedClients.clients;
    }

    const QByteArray data = proc.readAllStandardOutput();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isArray()) {
        QMutexLocker locker(&s_hyprMutex);
        return s_cachedClients.clients;
    }

    QList<HyprClient> list;
    const QJsonArray arr = doc.array();
    list.reserve(arr.size());
    for (const QJsonValue &val : arr) {
        if (!val.isObject()) continue;
        const QJsonObject obj = val.toObject();
        HyprClient c;
        c.address = obj.value(QStringLiteral("address")).toString();
        c.cls = obj.value(QStringLiteral("class")).toString();
        c.initialClass = obj.value(QStringLiteral("initialClass")).toString();
        c.title = obj.value(QStringLiteral("title")).toString();
        c.pid = obj.value(QStringLiteral("pid")).toVariant().toLongLong();
        c.mapped = obj.value(QStringLiteral("mapped")).toBool(true);
        c.visible = obj.value(QStringLiteral("visible")).toBool(true);
        c.hidden = obj.value(QStringLiteral("hidden")).toBool(false);
        c.fullscreen = obj.value(QStringLiteral("fullscreen")).toInt(0) != 0;
        const QJsonArray at = obj.value(QStringLiteral("at")).toArray();
        const QJsonArray sz = obj.value(QStringLiteral("size")).toArray();
        if (at.size() == 2 && sz.size() == 2) {
            c.geometry = QRect(at.at(0).toInt(), at.at(1).toInt(),
                               sz.at(0).toInt(), sz.at(1).toInt());
        }
        c.workspaceId = obj.value(QStringLiteral("workspace"))
                            .toObject()
                            .value(QStringLiteral("id"))
                            .toInt(-1);
        list.append(c);
    }

    {
        QMutexLocker locker(&s_hyprMutex);
        s_cachedClients.timestampMs = nowMs;
        s_cachedClients.clients = list;
    }
    return list;
}

namespace {

// Workspaces activos por monitor. A lente pergunta uma vez por segundo, mas
// isto so' consulta o compositor de dois em dois: trocar de workspace muda a
// resposta, e dois segundos de atraso num efeito que ja' desvanece em 260ms
// nao se notam -- enquanto um processo novo a cada pergunta notava-se.
QSet<int> activeWorkspaceIds()
{
    static QSet<int> cache;
    static qint64 quando = 0;
    const qint64 agora = QDateTime::currentMSecsSinceEpoch();
    if (quando > 0 && (agora - quando) < 2000) {
        return cache;
    }

    QProcess proc;
    proc.start(QStringLiteral("hyprctl"), {QStringLiteral("monitors"), QStringLiteral("-j")});
    if (!proc.waitForFinished(120)) {
        proc.kill();
        return cache;
    }
    const QJsonDocument doc = QJsonDocument::fromJson(proc.readAllStandardOutput());
    if (!doc.isArray()) {
        return cache;
    }

    QSet<int> encontrados;
    const QJsonArray arr = doc.array();
    for (const QJsonValue &v : arr) {
        const QJsonObject m = v.toObject();
        encontrados.insert(m.value(QStringLiteral("activeWorkspace"))
                               .toObject()
                               .value(QStringLiteral("id"))
                               .toInt(-1));
    }
    cache = encontrados;
    quando = agora;
    return cache;
}

} // namespace

bool DockHyprlandHelper::areaCoveredByWindow(const QRect &areaLogical)
{
    if (!isHyprlandActive() || areaLogical.isEmpty()) {
        return false;
    }

    const QSet<int> activos = activeWorkspaceIds();
    const QList<HyprClient> clientes = getClients();
    for (const HyprClient &c : clientes) {
        if (!c.mapped || c.hidden || c.geometry.isEmpty()) {
            continue;
        }
        if (!activos.isEmpty() && !activos.contains(c.workspaceId)) {
            continue;
        }
        if (c.geometry.intersects(areaLogical)) {
            return true;
        }
    }
    return false;
}

HyprClient DockHyprlandHelper::getActiveWindow()
{
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    {
        QMutexLocker locker(&s_hyprMutex);
        if (s_cachedActive.timestampMs > 0 && (nowMs - s_cachedActive.timestampMs) < 40) {
            return s_cachedActive.activeWin;
        }
    }

    QProcess proc;
    proc.start(QStringLiteral("hyprctl"), {QStringLiteral("activewindow"), QStringLiteral("-j")});
    if (!proc.waitForFinished(100)) {
        proc.kill();
        QMutexLocker locker(&s_hyprMutex);
        return s_cachedActive.activeWin;
    }

    const QByteArray data = proc.readAllStandardOutput();
    QJsonParseError err;
    const QJsonDocument doc = QJsonDocument::fromJson(data, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) {
        QMutexLocker locker(&s_hyprMutex);
        return s_cachedActive.activeWin;
    }

    const QJsonObject obj = doc.object();
    HyprClient c;
    c.address = obj.value(QStringLiteral("address")).toString();
    c.cls = obj.value(QStringLiteral("class")).toString();
    c.initialClass = obj.value(QStringLiteral("initialClass")).toString();
    c.title = obj.value(QStringLiteral("title")).toString();
    c.pid = obj.value(QStringLiteral("pid")).toVariant().toLongLong();

    {
        QMutexLocker locker(&s_hyprMutex);
        s_cachedActive.timestampMs = nowMs;
        s_cachedActive.activeWin = c;
    }
    return c;
}

bool DockHyprlandHelper::clientMatchesCommand(const HyprClient &client,
                                              const QString &command,
                                              const QHash<QString, QVariantMap> &knownApps)
{
    if (command.isEmpty() || (client.cls.isEmpty() && client.initialClass.isEmpty())) {
        return false;
    }

    const QString clientClsLower = client.cls.toLower();
    const QString initialClsLower = client.initialClass.toLower();
    const QString clientTitleLower = client.title.toLower();

    // 1. Dolphin & Scoped Targets (Downloads, Lixeira)
    if (command.startsWith(QStringLiteral("dolphin"), Qt::CaseInsensitive)
        || command.contains(QStringLiteral("/dolphin"), Qt::CaseInsensitive)
        || command.contains(QStringLiteral("org.kde.dolphin"), Qt::CaseInsensitive)) {
        const bool isDolphin = clientClsLower.contains(QStringLiteral("dolphin"))
            || initialClsLower.contains(QStringLiteral("dolphin"));
        if (!isDolphin) return false;

        const QString cmdLower = command.toLower();
        const bool isTrash = cmdLower.contains(QStringLiteral("trash:/"))
            || cmdLower.contains(QStringLiteral("trash://"))
            || cmdLower.contains(QStringLiteral("trash"));
        const bool isDownloads = cmdLower.contains(QStringLiteral("downloads"))
            || cmdLower.contains(QStringLiteral("download"));

        if (isTrash) {
            return titleLooksLikeTrash(clientTitleLower);
        }
        if (isDownloads) {
            return titleLooksLikeDownloads(clientTitleLower);
        }

        // Se for o Dolphin principal/geral (não scoped):
        // NÃO deve dar match se a janela aberta for Downloads ou Lixeira!
        if (titleLooksLikeTrash(clientTitleLower) || titleLooksLikeDownloads(clientTitleLower)) {
            return false;
        }
        return true;
    }

    // 2. Metadados do .desktop (wmClass, name)
    if (knownApps.contains(command)) {
        const QVariantMap &app = knownApps[command];
        const QString wmClass = app.value(QStringLiteral("wmclass")).toString().toLower();
        if (!wmClass.isEmpty()) {
            if (clientClsLower == wmClass || initialClsLower == wmClass
                || clientClsLower.contains(wmClass) || wmClass.contains(clientClsLower)) {
                return true;
            }
        }
        const QString appName = app.value(QStringLiteral("name")).toString().toLower();
        if (!appName.isEmpty()) {
            if (clientTitleLower.contains(appName) || clientClsLower == appName || initialClsLower == appName) {
                return true;
            }
        }
    }

    // 3. Executável base do comando
    const QString execBase = DockBrowserUtils::execBasenameFromCommand(command).toLower();
    if (!execBase.isEmpty()) {
        if (clientClsLower == execBase || initialClsLower == execBase
            || clientClsLower.contains(execBase) || execBase.contains(clientClsLower)) {
            return true;
        }

        // Navegadores
        if (execBase.contains(QStringLiteral("zen")) && (clientClsLower.contains(QStringLiteral("zen")) || initialClsLower.contains(QStringLiteral("zen")))) return true;
        if (execBase.contains(QStringLiteral("firefox")) && (clientClsLower.contains(QStringLiteral("firefox")) || initialClsLower.contains(QStringLiteral("firefox")))) return true;
        if (execBase.contains(QStringLiteral("chrom")) && (clientClsLower.contains(QStringLiteral("chrom")) || initialClsLower.contains(QStringLiteral("chrom")))) return true;
        if (execBase.contains(QStringLiteral("brave")) && (clientClsLower.contains(QStringLiteral("brave")) || initialClsLower.contains(QStringLiteral("brave")))) return true;
        if (execBase.contains(QStringLiteral("edge")) && (clientClsLower.contains(QStringLiteral("edge")) || initialClsLower.contains(QStringLiteral("edge")))) return true;
    }

    return false;
}

bool DockHyprlandHelper::isAppRunning(const QString &command,
                                      const QHash<QString, QVariantMap> &knownApps,
                                      const QSet<QString> &runningCmdLines)
{
    if (command.isEmpty()) {
        return false;
    }

    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        if (c.mapped && clientMatchesCommand(c, command, knownApps)) {
            return true;
        }
    }

    // Dolphin e LACT dependem estritamente de janelas mapeadas no Hyprland (para não acenderem juntos via /proc)
    const QString execBase = DockBrowserUtils::execBasenameFromCommand(command).toLower();
    if (execBase == QLatin1String("dolphin") || execBase.contains(QLatin1String("dolphin"))
        || command.contains(QLatin1String("dolphin"), Qt::CaseInsensitive)
        || execBase == QLatin1String("lact") || command.contains(QLatin1String("lact"), Qt::CaseInsensitive)) {
        return false;
    }

    // Fallback para processos sem janela mapeada (ex: apps inicializando)
    for (const QString &r : runningCmdLines) {
        if (r.startsWith(execBase) || r.contains(QStringLiteral("/") + execBase)) {
            return true;
        }
    }

    return false;
}

bool DockHyprlandHelper::isAppFocused(const QString &command,
                                      const QHash<QString, QVariantMap> &knownApps)
{
    if (command.isEmpty()) {
        return false;
    }

    const HyprClient active = getActiveWindow();
    if (active.address.isEmpty()) {
        return false;
    }

    return clientMatchesCommand(active, command, knownApps);
}

int DockHyprlandHelper::appWindowCount(const QString &command,
                                       const QHash<QString, QVariantMap> &knownApps)
{
    if (command.isEmpty()) {
        return 0;
    }

    int count = 0;
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        if (c.mapped && clientMatchesCommand(c, command, knownApps)) {
            count++;
        }
    }
    return count;
}

QStringList DockHyprlandHelper::windowAddressesForCommand(const QString &command,
                                                          const QHash<QString, QVariantMap> &knownApps)
{
    if (command.isEmpty()) {
        return {};
    }

    QStringList list;
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        if (c.mapped && clientMatchesCommand(c, command, knownApps)) {
            list.append(c.address);
        }
    }
    return list;
}

void DockHyprlandHelper::focusWindow(const QString &address)
{
    if (address.isEmpty()) {
        return;
    }
    QProcess proc;
    proc.start(QStringLiteral("hyprctl"), {QStringLiteral("activeworkspace"), QStringLiteral("-j")});
    QString wsId = QStringLiteral("1");
    if (proc.waitForFinished(100)) {
        const QJsonObject obj = QJsonDocument::fromJson(proc.readAllStandardOutput()).object();
        if (obj.contains(QStringLiteral("id"))) {
            wsId = QString::number(obj.value(QStringLiteral("id")).toInt(1));
        }
    }
    const QString batch = QStringLiteral("dispatch movetoworkspace ") + wsId + QStringLiteral(",address:") + address
        + QStringLiteral("; dispatch focuswindow address:") + address;
    QProcess::startDetached(QStringLiteral("hyprctl"), {QStringLiteral("--batch"), batch});
}

void DockHyprlandHelper::closeWindow(const QString &address)
{
    if (address.isEmpty()) {
        return;
    }
    QProcess::startDetached(QStringLiteral("hyprctl"),
                            {QStringLiteral("dispatch"), QStringLiteral("closewindow"), QStringLiteral("address:") + address});
}

bool DockHyprlandHelper::anyDolphinWindowExists()
{
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        if (c.cls.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive)
            || c.initialClass.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive)) {
            return true;
        }
    }
    return false;
}

bool DockHyprlandHelper::anyDolphinWindowMatchesScopedTarget(const QString &commandLower)
{
    const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        const bool isDolphin = c.cls.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive)
            || c.initialClass.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive);
        if (!isDolphin) continue;

        const QString titleLower = c.title.toLower();
        if (isTrash ? titleLooksLikeTrash(titleLower) : titleLooksLikeDownloads(titleLower)) {
            return true;
        }
    }
    return false;
}

QString DockHyprlandHelper::firstScopedDolphinWindowId(const QString &commandLower)
{
    const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        const bool isDolphin = c.cls.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive)
            || c.initialClass.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive);
        if (!isDolphin) continue;

        const QString titleLower = c.title.toLower();
        if (isTrash ? titleLooksLikeTrash(titleLower) : titleLooksLikeDownloads(titleLower)) {
            return c.address;
        }
    }
    return {};
}

QStringList DockHyprlandHelper::allScopedDolphinWindowIds(const QString &commandLower)
{
    const bool isTrash = commandLower.contains(QStringLiteral("trash:/"));
    QStringList list;
    const QList<HyprClient> clients = getClients();
    for (const HyprClient &c : clients) {
        const bool isDolphin = c.cls.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive)
            || c.initialClass.contains(QStringLiteral("dolphin"), Qt::CaseInsensitive);
        if (!isDolphin) continue;

        const QString titleLower = c.title.toLower();
        if (isTrash ? titleLooksLikeTrash(titleLower) : titleLooksLikeDownloads(titleLower)) {
            list.append(c.address);
        }
    }
    return list;
}

void DockHyprlandHelper::minimizeWindow(const QString &address)
{
    if (address.isEmpty()) return;
    QProcess::startDetached(QStringLiteral("hyprctl"), {QStringLiteral("dispatch"), QStringLiteral("movetoworkspacesilent"), QStringLiteral("99,address:") + address});
}

// ---------------------------------------------------------------------------
// Configuracao em runtime do compositor
// ---------------------------------------------------------------------------

void DockHyprlandHelper::applyKeyword(const QStringList &keywordArgs)
{
    if (!isHyprlandActive() || keywordArgs.isEmpty()) {
        return;
    }
    QProcess::startDetached(QStringLiteral("hyprctl"),
                            QStringList{QStringLiteral("keyword")} + keywordArgs);
}

namespace {

// O Hyprland 0.4x aceitava "layerrule = blur,<namespace>". A partir das series
// 0.5x a gramatica mudou para "layerrule = blur on, match:namespace <ns>", e a
// forma antiga passou a ser REJEITADA com "invalid field blur: missing a value"
// -- silenciosamente, porque o hyprctl devolve o erro mas ninguem o le.
//
// O efeito pratico da rejeicao era o ignorezero nunca chegar ao compositor: o
// blur passava a vazar pela parte transparente da superficie e deixava uma
// faixa borrada visivel no rodape quando o auto-ocultar recolhia a doca.
//
// Em vez de comparar numeros de versao (fragil, e a doca e' distribuida via
// AUR para utilizadores em versoes diferentes), sondamos uma vez: mandamos uma
// regra na sintaxe nova para um namespace inexistente e vemos se o compositor
// responde "ok". A sonda e' inofensiva -- a regra nunca casa com superficie
// nenhuma -- e o resultado fica em cache para o resto da sessao.
bool useModernLayerRuleSyntax()
{
    static const bool modern = []() -> bool {
        QProcess probe;
        probe.start(QStringLiteral("hyprctl"),
                    {QStringLiteral("keyword"), QStringLiteral("layerrule"),
                     QStringLiteral("blur on, match:namespace agildodock-syntax-probe")});
        if (!probe.waitForFinished(1500)) {
            probe.kill();
            probe.waitForFinished(200);
            return false;
        }
        const QString reply = QString::fromUtf8(probe.readAllStandardOutput()).trimmed();
        return reply.compare(QStringLiteral("ok"), Qt::CaseInsensitive) == 0;
    }();
    return modern;
}

} // namespace

void DockHyprlandHelper::applyDockLayerRules()
{
    if (!isHyprlandActive()) {
        return;
    }

    // Os tres escopos LayerShell realmente usados pela doca:
    //   agildodock             -> main.cpp, a doca em si
    //   agildodock-appmenu     -> DockAppMenuWindow.qml, via initLayerShellPopup
    //   agildodock-contextmenu -> DockIconContextMenu.qml, via initLayerShellPopup
    // Se acrescentares outra superficie LayerShell, o escopo dela entra aqui.
    static const QStringList scopes = {
        QStringLiteral("agildodock"),
        QStringLiteral("agildodock-appmenu"),
        QStringLiteral("agildodock-contextmenu"),
    };

    const bool modern = useModernLayerRuleSyntax();

    for (const QString &scope : scopes) {
        if (modern) {
            applyKeyword({QStringLiteral("layerrule"),
                          QStringLiteral("blur on, match:namespace ") + scope});
            // ignore_alpha e' o nome novo do antigo ignorezero: impede o blur de
            // "vazar" pelas zonas totalmente transparentes da superficie (cantos
            // arredondados, margens da doca -- e, sobretudo, a faixa fina que
            // sobra quando o auto-ocultar recolhe a doca).
            //
            // O valor e' deliberadamente minusculo para reproduzir a semantica do
            // ignorezero (ignorar apenas o que e' de fato transparente) sem
            // alcancar o fundo translucido da barra, que segue o bgOpacity do
            // utilizador e pode ser baixo.
            //
            // 0.01 ainda era alto demais: o preset Liquid Glass compunha ~0.0055
            // de alfa a meio da barra e essa faixa deixava de ser desfocada. O
            // limiar desce para 0.004 -- continua a excluir o que e' alfa zero
            // (cantos, doca recolhida) e ja' nao morde o vidro pintado. O piso
            // de 3% no substrato do DockBlurBackground faz o resto.
            applyKeyword({QStringLiteral("layerrule"),
                          QStringLiteral("ignore_alpha 0.004, match:namespace ") + scope});
        } else {
            applyKeyword({QStringLiteral("layerrule"), QStringLiteral("blur,") + scope});
            applyKeyword({QStringLiteral("layerrule"), QStringLiteral("ignorezero,") + scope});
        }
    }
}

// ---------------------------------------------------------------------------
// Listener de eventos (.socket2.sock)
// ---------------------------------------------------------------------------

DockHyprlandEventListener::DockHyprlandEventListener(QObject *parent)
    : QObject(parent)
{
}

bool DockHyprlandEventListener::start()
{
    if (!DockHyprlandHelper::isHyprlandActive() || m_socket) {
        return false;
    }

    const QByteArray sig = qgetenv("HYPRLAND_INSTANCE_SIGNATURE");
    const QByteArray runtimeDir = qgetenv("XDG_RUNTIME_DIR");
    if (sig.isEmpty() || runtimeDir.isEmpty()) {
        return false;
    }

    const QString path = QString::fromLocal8Bit(runtimeDir)
        + QStringLiteral("/hypr/") + QString::fromLocal8Bit(sig)
        + QStringLiteral("/.socket2.sock");
    if (!QFile::exists(path)) {
        return false;
    }

    m_socket = new QLocalSocket(this);
    connect(m_socket, &QLocalSocket::readyRead, this, &DockHyprlandEventListener::onReadyRead);
    m_socket->connectToServer(path, QIODevice::ReadOnly);
    // Ligacao assincrona de proposito: nao ha' motivo para bloquear o arranque
    // da doca por causa disto. Se falhar, perde-se apenas a reaplicacao
    // automatica depois de um `hyprctl reload`.
    return true;
}

void DockHyprlandEventListener::onReadyRead()
{
    if (!m_socket) {
        return;
    }
    m_buffer.append(m_socket->readAll());

    // O protocolo do socket2 e' uma linha por evento: "nome>>dados".
    int nl;
    while ((nl = m_buffer.indexOf('\n')) >= 0) {
        const QByteArray line = m_buffer.left(nl);
        m_buffer.remove(0, nl + 1);
        if (line.startsWith("configreloaded")) {
            Q_EMIT configReloaded();
        }
    }

    // Rede de seguranca: se algum evento gigante chegar sem newline, nao
    // deixar o buffer crescer sem limite.
    if (m_buffer.size() > 64 * 1024) {
        m_buffer.clear();
    }
}
