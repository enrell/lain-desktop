import QtQuick
import Lain
import "../theme/Color.js" as Color
import "../theme/Format.js" as Format

// 16:9 landscape card matching the web ContinueCard: episode still, hover
// play button, progress rail, episode label over the series title.
Item {
    id: card
    width: Tokens.landscapeWidth
    height: Tokens.landscapeWidth * 9 / 16 + 44
    property var media
    property string accent: media && media.accent ? media.accent : "#8A93A3"
    // The still frame is what the web continue-card shows; artwork is a
    // fallback when the thumbnail endpoint has nothing yet.
    readonly property string artwork: media && (media.thumb || media.cover || media.poster)
                                       ? (media.thumb || media.cover || media.poster) : ""
    readonly property real ratio: media && media.progress && !media.completed ? media.progress : 0
    readonly property string epLabel: {
        if (!media)
            return "";
        if (media.season > 0 && media.episode > 0)
            return "S" + (media.season < 10 ? "0" : "") + media.season
                 + "E" + (media.episode < 10 ? "0" : "") + media.episode;
        if (media.episode > 0)
            return qsTr("Episode %1").arg(media.episode);
        return "";
    }
    signal open(var media)

    Rectangle {
        id: art
        width: parent.width
        height: parent.width * 9 / 16
        radius: Tokens.radiusMd
        clip: true
        y: hover.containsMouse ? -4 : 0
        border.color: hover.containsMouse
            ? Qt.alpha(Tokens.themeFg, 0.14) : Qt.alpha(Tokens.themeFg, 0.05)
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Color.shade(card.accent, 0.34) }
            GradientStop { position: 1.0; color: Color.shade(card.accent, 0.14) }
        }
        Image {
            id: artImage
            anchors.fill: parent
            source: card.artwork
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
            scale: hover.containsMouse ? 1.035 : 1.0
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: card.media ? card.media.title.charAt(0) : ""
            color: "white"
            opacity: 0.07
            font.family: Tokens.fontSans
            font.pixelSize: 64
            font.bold: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.6; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha("black", 0.8) }
            }
            opacity: hover.containsMouse ? 1.0 : 0.3
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            width: 36; height: 36; radius: 18
            color: Qt.alpha("black", 0.65)
            visible: hover.containsMouse
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                text: "▶"
                font.pixelSize: 14
                color: "white"
            }
        }
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
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: card.open(card.media) }
    Column {
        anchors.top: art.bottom
        anchors.topMargin: 10
        width: card.width
        spacing: 3
        Text {
            width: parent.width
            text: {
                if (!card.media)
                    return "";
                if (card.media.episode > 0)
                    return qsTr("Episode %1").arg(card.media.episode);
                return card.media.displayTitle && card.media.displayTitle !== "" ? card.media.displayTitle : card.media.title;
            }
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.cardTitleSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: {
                if (!card.media)
                    return "";
                if (card.epLabel !== "")
                    return card.epLabel + " · " + (card.media.displayTitle && card.media.displayTitle !== "" ? card.media.displayTitle : card.media.title);
                var rest = Format.remaining(card.media);
                var t = card.media.displayTitle && card.media.displayTitle !== "" ? card.media.displayTitle : card.media.title;
                return rest === "" ? t : t + "  ·  " + rest;
            }
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize - 1
            elide: Text.ElideRight
        }
    }
}
