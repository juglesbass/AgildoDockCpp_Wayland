import QtQuick 2.15
import QtTest 1.15

TestCase {
    name: "DockThemeTests"

    property var theme: null

    function initTestCase() {
        var comp = Qt.createComponent("../DockTheme.qml")
        theme = comp.createObject()
    }

    function test_themePaletteDark() {
        var colors = theme.themePalette(0) // Dark
        verify(colors !== undefined)
        verify(colors.dockR !== undefined)
    }

    function test_themePaletteLight() {
        var colors = theme.themePalette(1) // Light
        verify(colors !== undefined)
        verify(colors.dockR !== undefined)
    }

    function test_animationDuration() {
        var durInstant = theme.animationDuration(300, 3)
        compare(durInstant, 0)
        var durNormal = theme.animationDuration(300, 0)
        compare(durNormal, 300)
    }
}
