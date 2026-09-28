import QtQuick
import QtTest
import Lain

// Screenshot spike: grab a full view taller than the window.
TestCase {
    id: testCase
    name: "ShotSpike"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    property Item host

    Component {
        id: libraryComponent
        Item {
            width: 1440
            height: library.implicitHeight
            LibraryView {
                id: library
                width: 1440
            }
        }
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 1440; height: 900 }", testCase);
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

    function test_grab_full_library_view() {
        ensureReady();
        tryVerify(() => server.catalog.length > 0);
        const item = createTemporaryObject(libraryComponent, host);
        verify(item);
        wait(50);
        const img = grabImage(item);
        console.log("grabbed " + img.width + "x" + img.height);
        img.save("/tmp/lain-shot-library.png");
        verify(img.height > 0);
    }
}
