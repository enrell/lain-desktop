import QtQuick
import QtTest
import Lain

// Settings language selection uses the locale manager and retranslates
// visible strings without restarting.
// PT-BR literals below are intentional localization expectations.
TestCase {
    id: testCase
    name: "SettingsLanguage"
    visible: true
    width: 1280
    height: 900
    when: windowShown

    property Item host

    Component {
        id: settingsComponent
        SettingsView {}
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 1200; height: 900 }", testCase);
        localeManager.setSelected("en");
    }

    function cleanup() {
        localeManager.setSelected("en");
        if (host) {
            host.destroy();
            host = null;
        }
    }

    function test_offers_three_locales_and_retranslates() {
        if (server.ready)
            server.logout();
        tryVerify(() => !server.ready);
        compare(localeManager.available.length, 3);
        const view = createTemporaryObject(settingsComponent, host);
        verify(view);

        const title = findChild(view, "settingsTitle");
        verify(title !== null);
        tryCompare(title, "text", "Settings");

        const repeater = findChild(view, "languageRepeater");
        verify(repeater !== null);
        compare(repeater.count, 3);

        const playback = findChild(view, "playbackSection");
        verify(playback !== null && playback.visible);

        const users = findChild(view, "usersSection");
        verify(users !== null);
        verify(!users.visible);

        localeManager.setSelected("pt_BR");
        tryCompare(title, "text", "Configurações");

        localeManager.setSelected("en");
        tryCompare(title, "text", "Settings");
    }

    function test_shows_admin_sections_for_admins() {
        if (!server.ready) {
            server.login("admin", "password123");
            tryCompare(server, "ready", true);
        }
        tryCompare(server, "role", "admin");
        const view = createTemporaryObject(settingsComponent, host);
        verify(view);
        const users = findChild(view, "usersSection");
        verify(users !== null);
        tryVerify(() => users.visible);
    }
}
