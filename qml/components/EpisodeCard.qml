import QtQuick
import Lain
import QtQuick.Layouts
import "../theme/Color.js" as Color

// Episode grid card (web TitleView episodeCard): 16:9 still, hover play
// button, SxxExx label in accent mono, progress/status line, missing state.
Rectangle {
    id: card
    property var item
    signal play(var item)
    signal open(var item)

    width: 240
    height: width * 9 / 16 + 74
    radius: Tokens.radiusMd
    clip: true
    color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.03))
    border.color: hover.containsMouse ? Qt.alpha(Tokens.themeFg, 0.15) : Qt.alpha(Tokens.themeFg, 0.06)
    opacity: item && item.missing ? 0.6 : 1.0
    y: hover.containsMouse && !(item && item.missing) ? -4 : 0
    Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

    readonly property string epLabel: {
        if (!item)
            return "";
        if (item.season > 0 && item.episode > 0)
            return "S" + (item.season < 10 ? "0" : "") + item.season + "E" + (item.episode < 10 ? "0" : "") + item.episode;
        if (item.episode > 0)
            return qsTr("Episode %1").arg(item.episode);
        return qsTr("Special");
    }
    readonly property real ratio: item && item.progress && !item.completed ? item.progress : 0

    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: card.width * 9 / 16
        clip: true
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Color.shade(item && item.accent ? item.accent : "#8A93A3", 0.34) }
                GradientStop { position: 1.0; color: Color.shade(item && item.accent ? item.accent : "#8A93A3", 0.14) }
            }
        }
        Image {
            id: still
            anchors.fill: parent
            source: item ? (item.thumb || item.cover || "") : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
            scale: hover.containsMouse ? 1.04 : 1.0
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            width: 32; height: 32; radius: 16
            color: Qt.alpha("black", 0.65)
            visible: hover.containsMouse && !(item && item.missing)
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                text: "▶"
                font.pixelSize: 12
                color: "white"
            }
        }
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: card.ratio > 0
            height: 4
            color: Qt.alpha("black", 0.5)
            Rectangle {
                width: parent.width * card.ratio
                height: parent.height
                color: Tokens.themeAccent
            }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.topMargin: card.width * 9 / 16 + 10
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 4
        Text {
            text: card.epLabel
            color: Tokens.themeAccent
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4
        }
        Text {
            Layout.fillWidth: true
            visible: item && item.title && item.title !== ""
            text: item ? (item.displayTitle && item.displayTitle !== "" ? item.displayTitle : item.title) : ""
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: {
                if (!item)
                    return "";
                if (item.missing)
                    return qsTr("Missing from disk");
                if (!item.completed && item.duration_sec > 0 && item.position_sec > 0)
                    return qsTr("Resume at %1%").arg(Math.min(100, Math.round(100 * item.position_sec / item.duration_sec)));
                if (item.completed)
                    return qsTr("Watched");
                if (item.size > 0)
                    return item.size_human || "";
                return qsTr("Not watched");
            }
            color: item && item.missing ? Tokens.themeUrgent : Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        enabled: !(item && item.missing)
        onClicked: card.play(card.item)
    }
}
