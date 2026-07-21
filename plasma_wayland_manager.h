#pragma once

#include <QObject>
#include <QString>
#include <QRect>
#include <QQuickWindow>

class PlasmaWaylandManager : public QObject
{
    Q_OBJECT
public:
    static PlasmaWaylandManager *instance();

    bool isAvailable() const;

    Q_INVOKABLE void reportIconGeometry(const QString &uuid, int x, int y, int width, int height, QQuickWindow *dockWindow);

private:
    explicit PlasmaWaylandManager(QObject *parent = nullptr);
    ~PlasmaWaylandManager() override;

    struct Private;
    Private *d;
};
