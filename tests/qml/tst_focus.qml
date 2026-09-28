import QtQuick
import QtTest
import Lain

// DD-036: interactive components activate from the keyboard.
TestCase {
    name: "FocusActivation"
    when: windowShown
    width: 800
    height: 600
    visible: true

    Component {
        id: cardComp
        PosterCard {
            width: 176
            media: ({ id: "movie-1", title: "Some Movie", displayTitle: "Some Movie" })
        }
    }
    Component {
        id: btnComp
        PlayerButton { glyph: "\uf053"; label: "Back" }
    }

    SignalSpy { id: cardSpy; signalName: "open" }
    SignalSpy { id: btnSpy; signalName: "pressed" }

    function test_card_activates_on_enter() {
        var card = createTemporaryObject(cardComp, this);
        verify(card);
        cardSpy.target = card;
        card.forceActiveFocus();
        verify(card.activeFocus);
        keyClick(Qt.Key_Return);
        compare(cardSpy.count, 1, "focused card must open on Return");
        card.destroy();
    }

    function test_button_activates_on_space() {
        var btn = createTemporaryObject(btnComp, this);
        verify(btn);
        btnSpy.target = btn;
        btn.forceActiveFocus();
        verify(btn.activeFocus);
        keyClick(Qt.Key_Space);
        compare(btnSpy.count, 1, "focused button must press on Space");
        btn.destroy();
    }

    function test_focus_ring_shows() {
        var btn = createTemporaryObject(btnComp, this);
        verify(btn);
        compare(btn.border.width, 0);
        btn.forceActiveFocus();
        tryCompare(btn, "activeFocus", true);
        compare(btn.border.width, 2, "focus ring must be visible");
        btn.destroy();
    }
}
