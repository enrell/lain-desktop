import QtQuick
import QtTest
import Lain

// Asynchronous debounced search in the client plus the search page state.
TestCase {
    id: testCase
    name: "SearchView"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: pageComponent
        SearchView { width: 1200 }
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
        const view = createTemporaryObject(pageComponent, host);
        verify(view);

        view.openWith("frieren");
        tryVerify(() => server.searchResults.length === 2);
        verify(!server.searching);

        // The result carries the enrichment overlay (title/year/genre).
        const first = server.searchResults[0];
        compare(first.year, 2023);
        compare(first.genre, "Adventure");
    }
}
