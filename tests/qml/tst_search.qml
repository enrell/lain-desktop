import QtQuick
import QtTest
import Lain

// Busca assíncrona com debounce no cliente + estado do overlay.
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

        // o resultado carrega o overlay de enrichment (título/ano/gênero)
        const first = server.searchResults[0];
        compare(first.year, 2023);
        compare(first.genre, "Adventure");

        overlay.visible = false;
    }
}
