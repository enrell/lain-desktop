import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: the four card types with real data in one shot.
TestCase {
    id: testCase
    name: "ShotCards"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    property var posterItem: server.catalog && server.catalog.length > 0 ? server.catalog[0] : null
    property var landItem: server.home && server.home.continueWatching && server.home.continueWatching.length > 0
        ? server.home.continueWatching[0]
        : (server.catalog && server.catalog.length > 0 ? server.catalog[0] : null)
    property var seriesItem: server.series && server.series.length > 0 ? server.series[0] : null
    property var epItem: {
        if (!server.series || server.series.length === 0)
            return null;
        var s = server.series[0];
        if (s.seasons && s.seasons.length > 0 && s.seasons[0].episodes.length > 0)
            return s.seasons[0].episodes[0];
        return s.specials && s.specials.length > 0 ? s.specials[0] : null;
    }

    ShotHost {
        id: host
        content: rowContent
    }
    Component {
        id: rowContent
        Row {
            padding: 32
            spacing: 28
            Column {
                spacing: 6
                PosterCard { media: testCase.posterItem }
                Text { text: "PosterCard"; color: Tokens.textTertiary; font.pixelSize: 10 }
            }
            Column {
                spacing: 6
                LandscapeCard { media: testCase.landItem }
                Text { text: "LandscapeCard"; color: Tokens.textTertiary; font.pixelSize: 10 }
            }
            Column {
                spacing: 6
                ShowCard { series: testCase.seriesItem }
                Text { text: "ShowCard"; color: Tokens.textTertiary; font.pixelSize: 10 }
            }
            Column {
                spacing: 6
                EpisodeCard { item: testCase.epItem }
                Text { text: "EpisodeCard"; color: Tokens.textTertiary; font.pixelSize: 10 }
            }
        }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.catalog.length > 0, 10000);
    }

    function test_cards() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/cards.png");
    }
}
