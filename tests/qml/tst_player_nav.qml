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
}
