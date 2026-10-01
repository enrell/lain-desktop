import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA for DD-037 surfaces: my list, command palette, reader.
TestCase {
    id: testCase
    name: "ShotParity"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost { id: host; content: listContent }
    Component { id: listContent; MyListView { width: host.captureWidth; visible: false } }
    Component { id: paletteContent; Rectangle { width: 1440; height: 900; color: Tokens.bgPrimary; property alias palette: p; CommandPalette { id: p } } }
    Component { id: readerContent; ReaderView { width: 1440; height: 900; visible: false } }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.catalog.length > 0, 10000);
    }

    function test_list() {
        ensureReady();
        server.submitLinkCode("anilist", "good-code");
        tryVerify(() => server.links.length === 1, 5000);
        host.view.visible = true;
        tryCompare(server.listEntries, "length", 2);
        wait(500);
        grabImage(host).save(shotsDir + "/list.png");
        server.unlink("anilist");
        tryVerify(() => server.links.length === 0, 5000);
    }

    function test_palette() {
        ensureReady();
        const host2 = createTemporaryObject(paletteContent, testCase);
        host2.palette.open();
        findChild(host2.palette, "paletteInput").text = "a";
        wait(400);
        grabImage(host2).save(shotsDir + "/palette.png");
        host2.palette.close();
    }

    function test_reader() {
        ensureReady();
        const r = createTemporaryObject(readerContent, testCase, { media: server.catalog.find(m => m.id === "show-2") });
        r.visible = true;
        tryVerify(() => r.ready, 5000);
        wait(400);
        grabImage(r).save(shotsDir + "/reader.png");
        r.visible = false;
    }
}
