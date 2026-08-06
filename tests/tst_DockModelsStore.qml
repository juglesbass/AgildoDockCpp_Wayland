import QtQuick 2.15
import QtTest 1.15
import ".."

TestCase {
    name: "DockModelsStoreTests"

    Item {
        id: mockDockRoot
        property string liveProfilesJson: "[]"
        property string liveAppRulesJson: "{}"
        property string liveCustomCommandsJson: "{}"
        property string liveWidgetsJson: "[]"
        property string liveDockAppsJson: "[]"
        function saveApps() {}
        function normalizeAppCommandKey(cmd) { return String(cmd).trim() }
    }

    DockModelsStore {
        id: modelsStore
        dockRoot: mockDockRoot
    }

    function test_initialCount() {
        compare(modelsStore.launcherModel.count, 1)
        compare(modelsStore.totalItemsCount, 1)
    }

    function test_populateAndUnpin() {
        modelsStore.populatePinnedAppsFromJson('[{"cmd":"org.kde.dolphin","name":"Dolphin"},{"cmd":"org.kde.konsole","name":"Konsole"}]')
        compare(modelsStore.appModel.count, 2)
        compare(modelsStore.totalItemsCount, 3)

        modelsStore.unpinApp(0)
        compare(modelsStore.appModel.count, 1)
        compare(modelsStore.totalItemsCount, 2)
    }

    function test_isCommandPinned() {
        modelsStore.populatePinnedAppsFromJson('[{"cmd":"org.kde.dolphin","name":"Dolphin"}]')
        verify(modelsStore.isCommandPinned("org.kde.dolphin"))
        verify(!modelsStore.isCommandPinned("org.kde.konsole"))
    }
}
