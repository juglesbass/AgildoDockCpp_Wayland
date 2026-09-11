#pragma once

#include <QObject>
#include <QSize>
#include <QString>
#include <QStringList>

class QFileSystemWatcher;
class QTimer;

// Descobre qual imagem esta' neste momento no fundo do ecra'.
//
// A doca e' uma superficie LayerShell: o compositor nunca lhe entrega os pixels
// que desenha por tras dela. Para a lente de vidro poder refractar o fundo, a
// unica via honesta e' abrir o MESMO ficheiro de wallpaper e reproduzir o
// enquadramento que o daemon de fundo usou.
//
// Fonte primaria: `swww query`, que diz a imagem por saida. Se o swww nao
// existir, tenta-se o hyprpaper e depois os ficheiros de estado que os shells
// mais comuns escrevem. Nenhuma destas leituras bloqueia a interface.
class DockWallpaperSource : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString imagePath READ imagePath NOTIFY imagePathChanged)
    Q_PROPERTY(QSize imageSize READ imageSize NOTIFY imagePathChanged)
    Q_PROPERTY(QString outputName READ outputName WRITE setOutputName NOTIFY outputNameChanged)
    Q_PROPERTY(bool active READ isActive WRITE setActive NOTIFY activeChanged)

public:
    explicit DockWallpaperSource(QObject *parent = nullptr);
    ~DockWallpaperSource() override;

    QString imagePath() const { return m_imagePath; }

    // Dimensao natural, lida do cabecalho do ficheiro sem descodificar os
    // pixels. E' o que permite ao QML recortar so' a faixa que fica atras da
    // doca em vez de carregar o wallpaper inteiro para a placa grafica.
    QSize imageSize() const { return m_imageSize; }

    QString outputName() const { return m_outputName; }
    void setOutputName(const QString &name);

    // Enquanto inactivo nao ha' processos nem temporizadores: a lente desligada
    // nao deve custar nada.
    bool isActive() const { return m_active; }
    void setActive(bool on);

    Q_INVOKABLE void refresh();

Q_SIGNALS:
    void imagePathChanged();
    void outputNameChanged();
    void activeChanged();

private:
    void applyPath(const QString &path);
    void querySwww();
    QString parseSwwwOutput(const QString &texto) const;
    QString fallbackFromFiles() const;
    void rearmWatcher();

    QString m_imagePath;
    QSize m_imageSize;
    QString m_outputName;
    bool m_active = false;
    QFileSystemWatcher *m_watcher = nullptr;
    QTimer *m_debounce = nullptr;
    QTimer *m_safetyNet = nullptr;
    QStringList m_watchedFiles;
};
