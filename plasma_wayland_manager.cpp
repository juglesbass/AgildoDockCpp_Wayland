#include "plasma_wayland_manager.h"
#include <QGuiApplication>
#include <QDebug>
#include <wayland-client.h>

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
#include <QtGui/QGuiApplication>
#include <QtGui/QWindow>
#include <QtGui/qpa/qplatformwindow_p.h>
#endif

// Generated Wayland bindings
#include "qwayland-plasma-window-management.h"
#include "wayland-plasma-window-management-client-protocol.h"

using namespace QtWayland;

struct PlasmaWaylandManager::Private {
    QtWayland::org_kde_plasma_window_management *manager = nullptr;
    wl_registry *registry = nullptr;
    
    static void registry_global(void *data, struct wl_registry *registry, uint32_t name, const char *interface, uint32_t version) {
        auto *d = static_cast<Private*>(data);
        if (qstrcmp(interface, org_kde_plasma_window_management_interface.name) == 0) {
            auto *obj = static_cast<struct ::org_kde_plasma_window_management *>(
                wl_registry_bind(registry, name, &org_kde_plasma_window_management_interface, qMin(version, 16u))
            );
            d->manager = new QtWayland::org_kde_plasma_window_management(obj);
        }
    }
    
    static void registry_global_remove(void *data, struct wl_registry *registry, uint32_t name) {
        Q_UNUSED(data);
        Q_UNUSED(registry);
        Q_UNUSED(name);
    }
    
    static const struct wl_registry_listener registry_listener;
};

const struct wl_registry_listener PlasmaWaylandManager::Private::registry_listener = {
    PlasmaWaylandManager::Private::registry_global,
    PlasmaWaylandManager::Private::registry_global_remove
};

PlasmaWaylandManager *PlasmaWaylandManager::instance()
{
    static PlasmaWaylandManager s_instance;
    return &s_instance;
}

PlasmaWaylandManager::PlasmaWaylandManager(QObject *parent)
    : QObject(parent)
    , d(new Private)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    if (auto *waylandApp = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>()) {
        wl_display *display = waylandApp->display();
        if (display) {
            d->registry = wl_display_get_registry(display);
            wl_registry_add_listener(d->registry, &Private::registry_listener, d);
            wl_display_roundtrip(display); // Populate registry
        }
    }
#endif
}

PlasmaWaylandManager::~PlasmaWaylandManager()
{
    if (d->manager) {
        delete d->manager;
    }
    if (d->registry) {
        wl_registry_destroy(d->registry);
    }
    delete d;
}

bool PlasmaWaylandManager::isAvailable() const
{
    return d->manager != nullptr && d->manager->isInitialized();
}

void PlasmaWaylandManager::reportIconGeometry(const QString &uuid, int x, int y, int width, int height, QQuickWindow *dockWindow)
{
    if (!isAvailable() || uuid.isEmpty() || !dockWindow) {
        return;
    }

#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    auto *waylandWindow = dockWindow->nativeInterface<QNativeInterface::Private::QWaylandWindow>();
    if (!waylandWindow) {
        qWarning() << "PlasmaWaylandManager: Could not get Wayland window interface.";
        return;
    }
    
    wl_surface *surface = waylandWindow->surface();
    if (!surface) {
        qWarning() << "PlasmaWaylandManager: Could not get wl_surface from WaylandWindow!";
        return;
    }
    
    // Retrieve the target window object by UUID
    struct ::org_kde_plasma_window *wl_win = d->manager->get_window_by_uuid(uuid);
    if (!wl_win) {
        // qWarning() << "PlasmaWaylandManager: Window not found for UUID" << uuid;
        return;
    }
    
    // Set the geometry on the Wayland level
    org_kde_plasma_window_set_minimized_geometry(wl_win, surface, x, y, width, height);
    
    // Destroy the local proxy object to prevent memory leaks in Wayland connection
    org_kde_plasma_window_destroy(wl_win);
#endif
}
