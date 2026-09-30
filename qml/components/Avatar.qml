import QtQuick
import Lain

// Account face (web Avatar.svelte): the uploaded picture, else a mascot,
// else the initial on an accent wash. Always round with a faint ring.
Item {
    id: root
    // A /api/me or /api/users object; defaults to the signed-in account.
    property var user: server.me
    property int size: 32
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    readonly property var avatar: user && user.profile && user.profile.avatar ? user.profile.avatar : ({})
    readonly property string src: user ? server.avatarUrlFor(user) : ""
    readonly property string name: user ? server.displayNameFor(user) : ""
    readonly property bool showPicture: src !== "" && picture.status === Image.Ready
    readonly property bool showMascot: !showPicture && avatar.kind === "mascot" && !!avatar.mascot

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: Tokens.accentSoft
        visible: !root.showPicture && !root.showMascot
        Text {
            anchors.centerIn: parent
            text: (root.name || "?").charAt(0).toUpperCase()
            color: Tokens.themeAccent
            font.family: Tokens.fontSans
            font.pixelSize: Math.round(root.size * 0.45)
            font.weight: Font.DemiBold
        }
    }
    Mascot {
        anchors.fill: parent
        round: true
        visible: root.showMascot
        mascotId: root.avatar.mascot || "wired"
    }
    // Loaded off-screen; painted through a circular clip below.
    Image {
        id: picture
        visible: false
        source: root.src
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        asynchronous: true
        onStatusChanged: face.requestPaint()
    }
    Canvas {
        id: face
        anchors.fill: parent
        visible: root.showPicture
        antialiasing: true
        onVisibleChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            if (picture.status !== Image.Ready)
                return;
            ctx.save();
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, width / 2, 0, 2 * Math.PI, false);
            ctx.clip();
            // Cover-crop the picture into the square.
            var iw = picture.implicitWidth, ih = picture.implicitHeight;
            var scale = Math.max(width / iw, height / ih);
            var dw = iw * scale, dh = ih * scale;
            ctx.drawImage(picture, (width - dw) / 2, (height - dh) / 2, dw, dh);
            ctx.restore();
        }
    }
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Qt.alpha("#ffffff", 0.10)
    }
}
