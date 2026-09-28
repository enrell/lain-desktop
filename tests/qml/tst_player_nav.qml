import QtQuick
import QtTest
import Lain

// PlayerView chrome: the back button must reach the back() signal.
TestCase {
    name: "PlayerNav"
    when: windowShown
    width: 1440
    height: 900
    visible: true

    Component {
        id: playerComp
        PlayerView {
            width: 1440
            height: 900
            media: ({ id: "show-1", title: "Frieren", displayTitle: "Frieren", thumb: "", thumbWide: "" })
        }
    }

    SignalSpy { id: spy; target: pv; signalName: "back" }

    property var pv: null

    function test_back_button_fires() {
        pv = createTemporaryObject(playerComp, this);
        verify(pv);
        pv.controlsVisible = true;
        wait(300);
        // Back button sits in the top-left control row (16px margin, ~22px center).
        mouseClick(pv, 38, 32);
        wait(200);
        compare(spy.count, 1, "back() must fire when the back button is clicked");
    }

    function test_mpv_responds_to_commands() {
        if (!pv) {
            pv = createTemporaryObject(playerComp, this);
            verify(pv);
        }
        // Sanity: the mpv core must actually process commands headless.
        pv.mpvItem.setVolume(37);
        tryCompare(pv.mpvItem, "volume", 37, 2000);
        pv.mpvItem.togglePause();
        tryCompare(pv.mpvItem, "paused", true, 2000);
    }

    function test_video_click_toggles_pause() {
        if (!pv) {
            pv = createTemporaryObject(playerComp, this);
            verify(pv);
        }
        pv.controlsVisible = true;
        var before = pv.mpvItem.paused;
        mouseClick(pv, 720, 450);
        tryCompare(pv.mpvItem, "paused", !before, 2000);
    }

    function test_pause_button_toggles_mpv() {
        if (!pv) {
            pv = createTemporaryObject(playerComp, this);
            verify(pv);
        }
        pv.controlsVisible = true;
        var before = pv.mpvItem.paused;
        // Accent play/pause is the first transport control (x=20 margins).
        mouseClick(pv, 42, pv.height - 32);
        tryCompare(pv.mpvItem, "paused", !before, 2000);
    }

    // DD-036: n/p moves through the episode rail, skipping missing files.
    function test_step_episode_skips_missing() {
        var eps = [
            { id: "e1", title: "Frieren", season: 1, episode: 1 },
            { id: "e2", title: "Frieren", season: 1, episode: 2, missing: true },
            { id: "e3", title: "Frieren", season: 1, episode: 3 }
        ];
        var p2 = Qt.createQmlObject(
            'import QtQuick; import Lain; PlayerView { width: 1440; height: 900; media: ({ id: "e1", title: "Frieren" }) }',
            this);
        verify(p2);
        // series.seasons[].episodes + series.specials is the ServerClient shape.
        p2.series = { title: "Frieren", seasons: [{ season: 1, episodes: eps }] };
        var fired = null;
        p2.playMedia.connect(function (m) { fired = m.id; });
        p2.stepEpisode(1);
        compare(fired, "e3", "next episode must skip the missing e2");
        p2.destroy();
    }

    function test_mute_button_toggles_mpv() {
        if (!pv) {
            pv = createTemporaryObject(playerComp, this);
            verify(pv);
        }
        pv.controlsVisible = true;
        var before = pv.mpvItem.muted;
        // Mute sits after play, -10s and +10s in the transport row.
        mouseClick(pv, 186, pv.height - 32);
        tryCompare(pv.mpvItem, "muted", !before, 2000);
    }
}
