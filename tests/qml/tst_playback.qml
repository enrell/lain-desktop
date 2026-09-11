import QtQuick
import QtTest
import Lain

// Client playback contract (video itself does not render offscreen):
// a direct plan emits playbackReady with an authenticated URL and resume.
TestCase {
    id: testCase
    name: "PlaybackApi"
    visible: true
    width: 800
    height: 600
    when: windowShown

    property Item host

    Component {
        id: spyComponent
        SignalSpy {}
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 640; height: 480 }", testCase);
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

    function test_playback_ready_carries_stream_url() {
        ensureReady();
        const spy = createTemporaryObject(spyComponent, host, { target: server, signalName: "playbackReady" });
        verify(spy);

        server.requestPlayback("show-1");
        tryCompare(spy, "count", 1);

        const url = spy.signalArguments[0][0];
        verify(url.indexOf("/api/items/show-1/stream") >= 0);
        verify(url.indexOf("token=test-token") >= 0);
        compare(spy.signalArguments[0][1], 15);
        compare(spy.signalArguments[0][2], 30);
    }

    function test_playback_failure_is_reported() {
        ensureReady();
        const spy = createTemporaryObject(spyComponent, host, { target: server, signalName: "playbackFailed" });
        verify(spy);

        server.requestPlayback("does-not-exist");
        tryCompare(spy, "count", 1);
        verify(server.playbackError !== "");
    }
}
