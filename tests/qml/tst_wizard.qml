import QtQuick
import QtTest
import Lain

// Setup wizard lists available provisioning methods without touching
// external servers. Detection runs against the stub health endpoint.
TestCase {
    id: testCase
    name: "SetupWizard"
    visible: true
    width: 900
    height: 900
    when: windowShown

    property Item host

    Component {
        id: wizardComponent
        SetupWizard {}
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 800; height: 800 }", testCase);
    }

    function cleanup() {
        if (host) {
            host.destroy();
            host = null;
        }
    }

    function test_lists_fallback_methods() {
        const view = createTemporaryObject(wizardComponent, host);
        verify(view);
        const repeater = findChild(view, "methodRepeater");
        verify(repeater !== null);
        tryVerify(() => repeater.count >= 2);
        tryVerify(() => provisioning.statusMessage !== "");
    }
}
