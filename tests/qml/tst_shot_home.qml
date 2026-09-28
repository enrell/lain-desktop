import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: home route (hero + rows) with real data.
TestCase {
    id: testCase
    name: "ShotHome"
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
        HomeView {
            width: host.captureWidth
            home: server.home
        }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.home.continueWatching !== undefined, 10000);
    }

    function test_home() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/home.png");
    }
}
