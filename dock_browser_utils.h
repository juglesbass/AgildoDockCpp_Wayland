#pragma once

#include <QString>
#include <QStringList>

// Utilitários partilhados para deteção de navegadores e paths de configuração.
namespace DockBrowserUtils {

QString execBasenameFromCommand(const QString &command);
bool commandLooksLikeBrowser(const QString &command);
bool commandLooksLikeChromiumBrowser(const QString &command);
bool commandLooksLikeGeckoBrowser(const QString &command);

// Raízes relativas a QStandardPaths::ConfigLocation (Chromium / forks).
QStringList chromiumConfigRoots();
// Raízes relativas a ConfigLocation (Gecko: Firefox, Zen, etc.).
QStringList geckoConfigRoots();

QString browserFamilyForCommand(const QString &command);

// Compara comando .desktop / exec com classe WM activa (kdotool/KWin).
bool commandMatchesWmClass(const QString &command, const QString &wmClassLower);

} // namespace DockBrowserUtils
