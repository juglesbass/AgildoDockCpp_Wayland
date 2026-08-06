import QtQuick 2.15
import QtTest 1.15
import ".."

TestCase {
    name: "DockAppRulesTests"

    Item {
        id: mockDockRoot
        property string liveAppRulesJson: "{}"
        property string liveCustomCommandsJson: "{}"
    }

    DockAppRules {
        id: appRules
        dockRoot: mockDockRoot
    }

    function test_normalizeAppCommandKey() {
        var key = appRules.normalizeAppCommandKey("/usr/bin/dolphin")
        compare(key, "dolphin")
    }

    function test_customCommands() {
        appRules.liveCustomCommandsJson = '{"org.kde.dolphin":["custom_cmd"]}'
        var cmds = appRules.customCommandsFor("org.kde.dolphin")
        verify(cmds !== undefined)
        compare(cmds.length, 1)
        compare(cmds[0], "custom_cmd")
    }
}
