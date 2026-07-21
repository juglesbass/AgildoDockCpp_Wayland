#ifndef KWIN_DBUS_HELPER_H
#define KWIN_DBUS_HELPER_H

#include <QObject>
#include <QStringList>
#include <QRect>
#include <QSize>

class KWinDBusHelper : public QObject
{
    Q_OBJECT
public:
    static KWinDBusHelper* instance();

    bool isAvailable();
    void initialize();

    QString getActiveWindowInfo();
    QString getWindowInfo(const QString &internalId);
    QStringList searchWindows(const QString &query, bool exactMatch);
    bool activateWindow(const QString &internalId);
    bool closeWindow(const QString &internalId);

private:
    explicit KWinDBusHelper(QObject *parent = nullptr);
    ~KWinDBusHelper();

    bool m_initialized = false;
    bool m_available = false;
    QString m_scriptPath;
    
    bool loadScript();
    void unloadScript();
};

#endif // KWIN_DBUS_HELPER_H
