import QtQuick
import QtTest
import Lain

// LoginView against the real ServerClient plus HTTP stub, all offscreen.
TestCase {
    id: testCase
    name: "LoginView"
    visible: true
    width: 1280
    height: 800
    when: windowShown

    property Item host

    Component {
        id: loginComponent
        LoginView { anchors.fill: parent }
    }

    function init() {
        host = createTemporaryQmlObject("import QtQuick; Item { width: 900; height: 700 }", testCase);
    }

    function cleanup() {
        if (host) {
            host.destroy();
            host = null;
        }
        stub.failLogin = false;
    }

    function ensureLoginState() {
        if (server.ready)
            server.logout();
        tryCompare(server, "state", "login");
    }

    function test_submits_credentials() {
        ensureLoginState();
        const view = createTemporaryObject(loginComponent, host);
        verify(view);
        waitForRendering(view);

        const user = findChild(view, "userField");
        const pass = findChild(view, "passwordField");
        const submit = findChild(view, "submitButton");
        verify(user && pass && submit);

        user.text = "admin";
        pass.text = "password123";
        mouseClick(submit, submit.width / 2, submit.height / 2);

        tryCompare(server, "ready", true);
        compare(server.username, "admin");
        compare(server.state, "ready");
    }

    function test_reports_bad_password() {
        ensureLoginState();
        stub.failLogin = true;
        const view = createTemporaryObject(loginComponent, host);
        verify(view);
        waitForRendering(view);

        const user = findChild(view, "userField");
        const pass = findChild(view, "passwordField");
        const submit = findChild(view, "submitButton");
        user.text = "admin";
        pass.text = "wrong";
        mouseClick(submit, submit.width / 2, submit.height / 2);

        tryVerify(() => server.errorMessage !== "");
        compare(server.state, "login");

        stub.failLogin = false;
        server.login("admin", "password123");
        tryCompare(server, "ready", true);
    }
}
