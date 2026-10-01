import QtQuick
import Lain

// Capture host for visual-QA shots: paints the app background so grabs
// match the real window (a bare Item would render transparent → white).
Rectangle {
    id: host
    property Component content
    property int captureWidth: 1440
    // Access to the loaded view for tests that drive it (e.g. search).
    property alias view: loader.item
    // At least one viewport tall; taller when the content is taller.
    width: captureWidth
    height: Math.max(900, loader.item ? loader.item.implicitHeight : 900)
    color: Tokens.bgPrimary

    // Shots run standalone too (`-input tst_shot_x.qml`): sign in against
    // the stub when no earlier suite did.
    Component.onCompleted: if (server.state === "login") server.login("admin", "password123")
    Connections {
        target: server
        function onStateChanged() {
            if (server.state === "login")
                server.login("admin", "password123");
        }
    }

    Loader {
        id: loader
        width: parent.width
        sourceComponent: host.content
    }
}
