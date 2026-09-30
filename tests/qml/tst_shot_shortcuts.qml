import QtQuick
import QtTest
import Lain

// Visual QA: the keybindings overlay (DD-036/DD-037).
TestCase {
    name: "ShotShortcuts"
    visible: true
    width: 1440
    height: 900
    when: windowShown
    Rectangle { id: bg; width: 1440; height: 900; color: Tokens.bgPrimary; ShortcutsOverlay { id: o } }
    function test_overlay() {
        o.open();
        wait(300);
        verify(o.visible);
        grabImage(bg).save(shotsDir + "/shortcuts.png");
        o.close();
    }
}
