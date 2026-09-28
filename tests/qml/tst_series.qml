import QtQuick
import QtTest
import Lain

// Series hierarchy (DD-030): the unified library shows one poster per
// multi-episode series, and the series page groups episodes by season
// with an explicit Specials section.
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
    Component {
        id: seriesComponent
        SeriesView { width: 1200 }
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
            seriesModel: server.series
        });
        verify(view);
        const repeater = findChild(view, "showsRepeater");
        verify(repeater !== null);
        compare(repeater.count, 1);
    }

    function test_series_view_lists_seasons_and_specials() {
        ensureReady();
        tryVerify(() => server.series.length === 1);
        const series = server.series[0];
        const view = createTemporaryObject(seriesComponent, host, { series: series });
        verify(view);
        // The stub groups several files under one title; numbered episodes
        // and specials partition the total (DD-030).
        const total = series.episodeCount + series.specialsCount;
        verify(total >= 2);
        var seasonSum = 0;
        for (var i = 0; i < series.seasons.length; ++i)
            seasonSum += series.seasons[i].episodes.length;
        compare(seasonSum, series.episodeCount);
        compare(series.specials.length, series.specialsCount);
    }
}
