import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: unified library route with real data.
TestCase {
    id: testCase
    name: "ShotLibrary"
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
        LibraryView { width: host.captureWidth }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.catalog.length > 0, 10000);
    }

    function test_library() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/library.png");
    }
}
