import QtQuick
import QtTest
import Lain

TestCase {
    name: "MpvDiag"
    when: windowShown
    width: 800
    height: 600
    visible: true

    Component {
        id: comp
        MpvItem { width: 800; height: 600 }
    }

    function test_mpv_state() {
        var item = createTemporaryObject(comp, this);
        verify(item);
        wait(500);
        console.log("mpv errorText:", item.errorText);
        console.log("mpv paused:", item.paused, "volume:", item.volume, "duration:", item.duration);
        // Option changes fire observed-property events even at idle —
        // failure here means the mpv event thread never reaches us.
        item.setVolume(37);
        tryCompare(item, "volume", 37, 3000);
        console.log("mpv volume after:", item.volume);
    }
}
