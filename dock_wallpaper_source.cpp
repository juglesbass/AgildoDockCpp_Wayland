#include "dock_wallpaper_source.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFileSystemWatcher>
#include <QImageReader>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTextStream>
#include <QTimer>

namespace {

// Ficheiros que mudam quando o wallpaper muda. Nenhum e' obrigatorio; observa-se
// os que existirem. O QFileSystemWatcher perde o alvo quando a escrita e' feita
// por substituicao (escrever para .tmp e mudar o nome), por isso o caminho e'
// re-armado depois de cada disparo.
QStringList ficheirosDeEstado()
{
    const QString lar = QDir::homePath();
    return {
        lar + QStringLiteral("/.local/state/caelestia/wallpaper/path.txt"),
        lar + QStringLiteral("/.config/waypaper/config.ini"),
        lar + QStringLiteral("/.config/hypr/hyprpaper.conf"),
    };
}

QString expandeTil(QString caminho)
{
    if (caminho.startsWith(QLatin1Char('~'))) {
        caminho.replace(0, 1, QDir::homePath());
    }
    return caminho;
}

} // namespace

DockWallpaperSource::DockWallpaperSource(QObject *parent)
    : QObject(parent)
{
    m_debounce = new QTimer(this);
    m_debounce->setSingleShot(true);
    m_debounce->setInterval(250);
    connect(m_debounce, &QTimer::timeout, this, &DockWallpaperSource::refresh);

    // Rede de seguranca para quem troca o fundo por um caminho que nao passa por
    // nenhum dos ficheiros observados (um `swww img` directo, por exemplo).
    m_safetyNet = new QTimer(this);
    m_safetyNet->setInterval(8000);
    connect(m_safetyNet, &QTimer::timeout, this, &DockWallpaperSource::refresh);
}

DockWallpaperSource::~DockWallpaperSource() = default;

void DockWallpaperSource::setOutputName(const QString &name)
{
    if (m_outputName == name) {
        return;
    }
    m_outputName = name;
    Q_EMIT outputNameChanged();
    if (m_active) {
        refresh();
    }
}

void DockWallpaperSource::setActive(bool on)
{
    if (m_active == on) {
        return;
    }
    m_active = on;
    Q_EMIT activeChanged();

    if (!m_active) {
        m_safetyNet->stop();
        m_debounce->stop();
        delete m_watcher;
        m_watcher = nullptr;
        m_watchedFiles.clear();
        return;
    }

    m_watcher = new QFileSystemWatcher(this);
    connect(m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        m_debounce->start();
        // Re-armar tarde: quem escreveu pode ainda estar a substituir o ficheiro.
        QTimer::singleShot(400, this, &DockWallpaperSource::rearmWatcher);
    });
    rearmWatcher();
    m_safetyNet->start();
    refresh();
}

void DockWallpaperSource::rearmWatcher()
{
    if (!m_watcher) {
        return;
    }
    for (const QString &f : ficheirosDeEstado()) {
        if (!QFile::exists(f) || m_watcher->files().contains(f)) {
            continue;
        }
        m_watcher->addPath(f);
    }
}

void DockWallpaperSource::refresh()
{
    if (!m_active) {
        return;
    }
    querySwww();
}

void DockWallpaperSource::querySwww()
{
    const QString exe = QStandardPaths::findExecutable(QStringLiteral("swww"));
    if (exe.isEmpty()) {
        applyPath(fallbackFromFiles());
        return;
    }

    auto *proc = new QProcess(this);
    connect(proc, &QProcess::finished, this,
            [this, proc](int code, QProcess::ExitStatus) {
                const QString saida = QString::fromUtf8(proc->readAllStandardOutput());
                proc->deleteLater();
                QString achado = (code == 0) ? parseSwwwOutput(saida) : QString();
                if (achado.isEmpty()) {
                    achado = fallbackFromFiles();
                }
                applyPath(achado);
            });
    connect(proc, &QProcess::errorOccurred, this, [this, proc]() {
        proc->deleteLater();
        applyPath(fallbackFromFiles());
    });
    proc->start(exe, {QStringLiteral("query")});
}

// Uma linha por saida:
//   ": HDMI-A-1: 1920x1080, scale: 2, currently displaying: image: /caminho.jpg"
// O nome da saida e' o que permite acertar no monitor certo em multi-ecra; sem
// nome conhecido fica-se pela primeira linha com imagem.
QString DockWallpaperSource::parseSwwwOutput(const QString &texto) const
{
    static const QRegularExpression re(
        QStringLiteral("^:?\\s*([^:]+):.*?image:\\s*(.+?)\\s*$"));

    QString primeira;
    const QStringList linhas = texto.split(QLatin1Char('\n'), Qt::SkipEmptyParts);
    for (const QString &linha : linhas) {
        const QRegularExpressionMatch m = re.match(linha.trimmed());
        if (!m.hasMatch()) {
            continue;
        }
        const QString saida = m.captured(1).trimmed();
        const QString caminho = m.captured(2).trimmed();
        if (caminho.isEmpty()) {
            continue;
        }
        if (!m_outputName.isEmpty() && saida == m_outputName) {
            return caminho;
        }
        if (primeira.isEmpty()) {
            primeira = caminho;
        }
    }
    return primeira;
}

QString DockWallpaperSource::fallbackFromFiles() const
{
    const QString lar = QDir::homePath();

    // 1. Estado do caelestia: uma linha, so' o caminho.
    QFile estado(lar + QStringLiteral("/.local/state/caelestia/wallpaper/path.txt"));
    if (estado.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QString linha = QString::fromUtf8(estado.readLine()).trimmed();
        if (!linha.isEmpty() && QFile::exists(expandeTil(linha))) {
            return expandeTil(linha);
        }
    }

    // 2. waypaper: "wallpaper = ~/Pictures/..."
    QFile way(lar + QStringLiteral("/.config/waypaper/config.ini"));
    if (way.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream ts(&way);
        while (!ts.atEnd()) {
            const QString linha = ts.readLine().trimmed();
            if (!linha.startsWith(QStringLiteral("wallpaper"))) {
                continue;
            }
            const int igual = linha.indexOf(QLatin1Char('='));
            if (igual < 0) {
                continue;
            }
            const QString caminho = expandeTil(linha.mid(igual + 1).trimmed());
            if (QFile::exists(caminho)) {
                return caminho;
            }
        }
    }

    // 3. hyprpaper: "wallpaper = HDMI-A-1,/caminho" ou "wallpaper = ,/caminho"
    QFile hp(lar + QStringLiteral("/.config/hypr/hyprpaper.conf"));
    if (hp.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream ts(&hp);
        while (!ts.atEnd()) {
            const QString linha = ts.readLine().trimmed();
            if (!linha.startsWith(QStringLiteral("wallpaper"))) {
                continue;
            }
            const int igual = linha.indexOf(QLatin1Char('='));
            if (igual < 0) {
                continue;
            }
            QString resto = linha.mid(igual + 1).trimmed();
            const int virgula = resto.indexOf(QLatin1Char(','));
            if (virgula >= 0) {
                resto = resto.mid(virgula + 1).trimmed();
            }
            const QString caminho = expandeTil(resto);
            if (QFile::exists(caminho)) {
                return caminho;
            }
        }
    }

    return QString();
}

void DockWallpaperSource::applyPath(const QString &path)
{
    const QString limpo = path.trimmed();
    if (limpo == m_imagePath) {
        return;
    }
    if (!limpo.isEmpty() && !QFileInfo::exists(limpo)) {
        return;
    }
    m_imagePath = limpo;
    m_imageSize = QSize();
    if (!m_imagePath.isEmpty()) {
        QImageReader leitor(m_imagePath);
        m_imageSize = leitor.size();
    }
    Q_EMIT imagePathChanged();
}
