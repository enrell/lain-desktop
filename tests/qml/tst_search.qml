import QtQuick
import QtTest
import Lain

// Asynchronous debounced search in the client plus overlay state.
TestCase {
    id: testCase
    name: "SearchOverlay"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: overlayComponent
        SearchOverlay {}
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 1200; height: 900 }", testCase);
    }

    function cleanup() {
        if (host) {
            host.destroy();
            host = null;
        }
        server.clearSearch();
    }

    function ensureReady() {
        if (!server.ready) {
            server.login("admin", "password123");
            tryCompare(server, "ready", true);
        }
    }

    function test_searches_the_server() {
        ensureReady();
        const overlay = createTemporaryObject(overlayComponent, host);
        verify(overlay);

        overlay.openWith("frieren");
        tryVerify(() => server.searchResults.length === 2);
        verify(!server.searching);

        // The result carries the enrichment overlay (title/year/genre).
        const first = server.searchResults[0];
        compare(first.year, 2023);
        compare(first.genre, "Adventure");

        overlay.visible = false;
    }
}
