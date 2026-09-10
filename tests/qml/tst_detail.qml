import QtQuick
import QtTest
import Lain

// Detail: a seção de metadata aparece para admin, lista providers do
// servidor e oferece enrich/remover conforme o overlay existir.
TestCase {
    id: testCase
    name: "DetailView"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: detailComponent
        DetailView { anchors.fill: parent }
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 1200; height: 900 }", testCase);
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

    function test_shows_metadata_controls_for_admin() {
        ensureReady();
        server.openMedia("show-1");
        tryVerify(() => server.currentMedia.id === "show-1");

        const view = createTemporaryObject(detailComponent, host, { media: server.currentMedia });
        verify(view);

        const section = findChild(view, "metadataSection");
        const enrich = findChild(view, "enrichButton");
        const remove = findChild(view, "removeEnrichButton");
        verify(section && enrich && remove);
        verify(section.visible);
        verify(remove.visible); // show-1 tem overlay no stub

        // providers vêm de /api/plugins: NFO + AniList (+ Auto local)
        tryVerify(() => server.metadataProviders.length === 2);
    }
}
