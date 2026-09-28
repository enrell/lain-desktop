import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: item detail page with real data.
TestCase {
    id: testCase
    name: "ShotDetail"
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
        DetailView {
            width: host.captureWidth
            media: server.currentMedia
        }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.catalog.length > 0, 10000);
        const id = server.catalog[0].id;
        server.openMedia(id);
        tryVerify(() => server.currentMedia.id === id, 10000);
    }

    function test_detail() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/detail.png");
    }
}
