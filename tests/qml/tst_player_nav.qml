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
        // Play/pause is the second button in the bottom control row.
        mouseClick(pv, 90, pv.height - 55);
        tryCompare(pv.mpvItem, "paused", !before, 2000);
    }

    function test_mute_button_toggles_mpv() {
        if (!pv) {
            pv = createTemporaryObject(playerComp, this);
            verify(pv);
        }
        pv.controlsVisible = true;
        var before = pv.mpvItem.muted;
        // Mute button is the first control on the right side of the bar.
        mouseClick(pv, 1112, pv.height - 55);
        tryCompare(pv.mpvItem, "muted", !before, 2000);
    }
}
