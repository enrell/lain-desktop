import QtQuick
import QtTest
import Lain
import "../helpers"

// Shell surface: the fixed TopBar over a stub page.
TestCase {
    id: testCase
    name: "ShotShell"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost {
        id: host
        content: shellContent
    }
    Component {
        id: shellContent
        Rectangle {
            width: host.captureWidth
            height: 900
            color: Tokens.bgPrimary
            TopBar {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                current: "home"
                onNavigate: function (r) {}
            }
        }
    }

    function test_shell() {
        tryCompare(server, "ready", true, 10000);
        wait(600);
        grabImage(host).save(shotsDir + "/shell.png");
    }
}
