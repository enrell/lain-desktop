import QtQuick
import QtTest
import Lain

// HomeView renderiza os dados reais normalizados (hero, continue, recentes).
TestCase {
    id: testCase
    name: "HomeView"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: homeComponent
        HomeView { anchors.fill: parent }
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

    function test_renders_hero_and_rows() {
        ensureReady();
        tryVerify(() => server.home.hero !== undefined && server.home.hero.id === "show-1");

        const view = createTemporaryObject(homeComponent, host, { home: server.home });
        verify(view);

        const title = findChild(view, "heroTitle");
        verify(title !== null);
        tryVerify(() => title.text === "Frieren: Beyond Journey's End");

        const continueRow = findChild(view, "continueRow");
        const recentRow = findChild(view, "recentRow");
        verify(continueRow !== null && recentRow !== null);
        compare(continueRow.model.length, 1);
        compare(recentRow.model.length, 3);
    }
}
