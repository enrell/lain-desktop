import QtQuick
import QtTest
import Lain

// Web-parity surfaces (DD-037): My list, the Ctrl+K palette, the reader.
TestCase {
    id: testCase
    name: "WebParity"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    Component { id: listComponent; MyListView { width: 1200 } }
    Component { id: paletteComponent; Item { width: 1200; height: 800; property alias palette: p; CommandPalette { id: p } } }
    Component { id: readerComponent; ReaderView { width: 1200; height: 800 } }

    function ensureReady() {
        if (!server.ready) {
            server.login("admin", "password123");
            tryCompare(server, "ready", true, 10000);
        }
        tryVerify(() => server.catalog.length > 0, 10000);
    }

    function test_list_filters_entries() {
        ensureReady();
        const view = createTemporaryObject(listComponent, testCase, { visible: false });
        view.visible = true;
        tryVerify(() => !server.listLoading);
        verify(findChild(view, "listEmpty").visible);
        server.submitLinkCode("anilist", "good-code");
        tryVerify(() => server.links.length === 1, 5000);
        view.reload();
        tryCompare(server.listEntries, "length", 2);
        verify(findChild(view, "listGrid").visible);
        mouseClick(findChild(view, "listType-manga"));
        tryCompare(server.listEntries, "length", 1);
        mouseClick(findChild(view, "listType-all"));
        tryCompare(server.listEntries, "length", 2);
        server.unlink("anilist");
        tryVerify(() => server.links.length === 0, 5000);
    }

    function test_palette_ranks_settings_and_titles() {
        ensureReady();
        const host = createTemporaryObject(paletteComponent, testCase);
        const p = host.palette;
        let settingsOpened = "";
        p.openSettings.connect((s, a) => settingsOpened = s + "#" + a);
        p.open();
        verify(p.visible);
        verify(p.results.length > 0);
        findChild(p, "paletteInput").text = "hard";
        tryVerify(() => p.results.length > 0);
        compare(p.results[0].label, "Hardware acceleration");
        p.runActive();
        compare(settingsOpened, "transcoding#hardware");
        verify(!p.visible);
        p.open();
        findChild(p, "paletteInput").text = "frieren";
        tryVerify(() => p.results.some(r => r.group === "titles"));
        // One entry per series title.
        compare(p.results.filter(r => r.group === "titles").length, 1);
    }

    function test_reader_pages_and_direction() {
        ensureReady();
        const media = server.catalog.find(m => m.id === "show-2");
        verify(media);
        const reader = createTemporaryObject(readerComponent, testCase, { visible: false, media: media });
        reader.visible = true;
        tryVerify(() => reader.ready, 5000);
        compare(reader.pages.length, 3);
        compare(reader.direction, "rtl");
        const counter = findChild(reader, "readerCounter");
        compare(counter.text, "1 / 3");
        reader.forward();
        compare(counter.text, "2 / 3");
        // Right-to-left: the right arrow goes back.
        reader.turnRight();
        compare(reader.page, 0);
        reader.toggleDirection();
        compare(reader.direction, "ltr");
        reader.turnRight();
        compare(reader.page, 1);
        reader.toggleDirection();
        reader.close();
    }
}
