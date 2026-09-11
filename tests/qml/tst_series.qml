import QtQuick
import QtTest
import Lain

// Series hierarchy (DD-030): shows browse as series/season/episode
// blocks with a Specials section for unnumbered items.
TestCase {
    id: testCase
    name: "SeriesHierarchy"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: libraryComponent
        LibraryView {}
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 1200; height: 900 }", testCase);
    }

    function cleanup() {
        if (host) {
            host.destroy();
            host = null;
        }
    }

    function ensureReady() {
        if (!server.ready) {
            server.login("admin", "password123");
            tryCompare(server, "ready", true);
        }
    }

    function test_groups_shows_into_series() {
        ensureReady();
        tryVerify(() => server.series.length === 1);
        const view = createTemporaryObject(libraryComponent, host, {
            title: "Shows",
            items: server.shows,
            seriesModel: server.series,
            showSeries: true
        });
        verify(view);
        const repeater = findChild(view, "seriesRepeater");
        verify(repeater !== null);
        compare(repeater.count, 1);
    }
}
