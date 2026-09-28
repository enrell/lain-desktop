import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: settings route with real data (DD-027 structure).
TestCase {
    id: testCase
    name: "ShotSettings"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost {
        id: host
        content: viewContent
    }
    Component {
        id: viewContent
        SettingsView { width: host.captureWidth }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.libraries.length > 0, 10000);
    }

    function test_settings() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/settings.png");
    }
}
