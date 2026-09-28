import QtQuick
import Lain
import QtQuick.Layouts
import "../theme/Color.js" as Color
import "../theme/Format.js" as Format

// 2:3 poster card matching the web MediaCard: rounded art, hover lift,
// circular play affordance top-right, "Watching" badge + progress rail.
Item {
    id: card
    width: Tokens.posterWidth
    height: width * 1.5 + 46
    property var media
    property string accent: media && media.accent ? media.accent : "#8A93A3"
    readonly property string artwork: media && (media.poster || media.cover || media.thumb)
                                       ? (media.poster || media.cover || media.thumb) : ""
    readonly property real ratio: media && media.progress && !media.completed ? media.progress : 0
    property bool highlighted: false
    signal open(var media)
    signal play(var media)

    Rectangle {
        id: art
        width: parent.width
        height: parent.width * 1.5
        radius: Tokens.radiusMd
        clip: true
        y: (card.highlighted || hover.containsMouse) ? -4 : 0
        border.color: hover.containsMouse || card.highlighted
            ? Qt.alpha(Tokens.themeFg, 0.15) : Qt.alpha(Tokens.themeFg, 0.05)
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Color.shade(card.accent, 0.38) }
            GradientStop { position: 1.0; color: Color.shade(card.accent, 0.15) }
        }
        Image {
            id: artImage
            anchors.fill: parent
            source: card.artwork
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
            scale: (card.highlighted || hover.containsMouse) ? 1.035 : 1.0
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        // Title-initial watermark used as a textured artwork fallback.
        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: card.media ? card.media.title.charAt(0) : ""
            color: "white"
            opacity: 0.08
            font.family: Tokens.fontSans
            font.pixelSize: 84
            font.bold: true
        }
        // Bottom readability gradient, stronger on hover.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha("black", 0.8) }
            }
            opacity: (card.highlighted || hover.containsMouse) ? 1.0 : 0.15
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        // Circular play affordance top-right (web hover play button).
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            width: 36; height: 36; radius: 18
            color: Qt.alpha("black", 0.65)
            visible: card.highlighted || hover.containsMouse
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                text: "▶"
                font.pixelSize: 14
                color: "white"
            }
        }
        // "Watching" badge for in-progress items (web MediaCard).
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 8
            visible: card.ratio > 0
            height: 18
            width: watchLabel.implicitWidth + 16
            radius: 9
            color: Qt.alpha("black", 0.65)
            Text {
                id: watchLabel
                anchors.centerIn: parent
                text: qsTr("Watching")
                color: "white"
                font.family: Tokens.fontSans
                font.pixelSize: 10
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 0.8
            }
        }
        // Progress rail inset at the bottom (web ProgressBar).
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            visible: card.ratio > 0
            height: 4
            radius: 2
            color: Qt.alpha("black", 0.5)
            Rectangle {
                width: parent.width * card.ratio
                height: parent.height
                radius: 2
                color: Tokens.themeAccent
            }
        }
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onClicked: card.open(card.media)
    }
    Column {
        anchors.top: art.bottom
        anchors.topMargin: 10
        width: card.width
        spacing: 3
        Text {
            width: parent.width
            text: card.media ? (card.media.displayTitle && card.media.displayTitle !== "" ? card.media.displayTitle : card.media.title) : ""
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.cardTitleSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: Format.cardMeta(card.media)
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize - 1
            elide: Text.ElideRight
        }
    }
}
