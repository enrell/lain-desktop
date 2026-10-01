import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: the Settings rail and each section (DD-037), one PNG per
// section under build/shots/settings-<id>.png.
TestCase {
    id: testCase
    name: "ShotSettings"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost {
        id: host
        content: viewContent
    }
    Component {
        id: viewContent
        SettingsView { width: host.captureWidth; height: implicitHeight }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.libraries.length > 0, 10000);
    }

    function shoot(id) {
        ensureReady();
        host.view.open(id);
        wait(700);
        grabImage(host).save(shotsDir + "/settings-" + id + ".png");
    }

    function test_profile() { shoot("profile"); }
    function test_playback() { shoot("playback"); }
    function test_connections() { shoot("connections"); }
    function test_security() { shoot("security"); }
    function test_desktop() { shoot("desktop"); }
    function test_libraries() { shoot("libraries"); }
    function test_users() { shoot("users"); }
    function test_transcoding() { shoot("transcoding"); }
    function test_integrations() { shoot("integrations"); }
    function test_plugins() { shoot("plugins"); }
    function test_libraries_add() {
        ensureReady();
        host.view.open("libraries", "add");
        tryVerify(() => server.browseResult.dirs && server.browseResult.dirs.length === 2, 5000);
        wait(500);
        grabImage(host.Window.window.contentItem).save(shotsDir + "/settings-libraries-add.png");
        const modal = findChild(host.Window.window.contentItem, "addLibraryModal");
        if (modal)
            modal.close();
    }
    function test_backup() { shoot("backup"); host.view.open("profile"); }
}
