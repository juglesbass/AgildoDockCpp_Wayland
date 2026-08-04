#ifndef DOCK_PROCESS_SCANNER_H
#define DOCK_PROCESS_SCANNER_H

#include <QString>
#include <QVariantMap>

class DockProcessScanner {
public:
    static QString readProcCmdlineFile(const QString &path);
    static bool appMatchesRunningCmdLine(const QString &cmdLineLower, const QVariantMap &app);
};

#endif // DOCK_PROCESS_SCANNER_H
