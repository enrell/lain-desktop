import QtQuick
import QtQuick.Layouts
import Lain

// Web ListEntryCard: a 2:3 cover with a platform chip and progress rail,
// then title and "type · status · progress · ★ score".
Item {
    id: root
    property var entry
    implicitWidth: Tokens.posterWidth
    implicitHeight: cover.height + meta.implicitHeight + 12

    readonly property var statusLabels: ({
        "current": qsTr("Current"), "planning": qsTr("Planning"), "completed": qsTr("Completed"),
        "paused": qsTr("Paused"), "dropped": qsTr("Dropped"), "repeating": qsTr("Repeating")
    })
    readonly property string status: entry ? (statusLabels[entry.status] || entry.status) : ""
    readonly property string progressText: entry ? (entry.progress_total ? entry.progress + "/" + entry.progress_total : String(entry.progress || 0)) : ""
    readonly property real ratio: entry && entry.progress_total ? Math.min(1, entry.progress / entry.progress_total) : 0

    Accessible.role: Accessible.StaticText
    Accessible.name: entry ? entry.title + ", " + entry.media_type + " · " + status : ""

    Rectangle {
        id: cover
        width: parent.width
        height: width * 1.5
        radius: Tokens.radiusMd
        color: Tokens.surface1
        clip: true
        y: hover.hovered ? -4 : 0
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        HoverHandler { id: hover }
        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: art.status !== Image.Ready
            horizontalAlignment: Text.AlignHCenter
            text: root.entry ? root.entry.title : ""
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 14
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        Image {
            id: art
            anchors.fill: parent
            source: root.entry && root.entry.cover ? root.entry.cover : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            scale: hover.hovered ? 1.035 : 1
            Behavior on scale { NumberAnimation { duration: 400 } }
        }
        Rectangle {
            x: 8; y: 8
            implicitWidth: chip.implicitWidth + 14
            implicitHeight: 18
            radius: 9
            color: Qt.alpha("#000000", 0.65)
            Text {
                id: chip
                anchors.centerIn: parent
                text: root.entry ? String(root.entry.platform).toUpperCase() : ""
                color: "#ffffff"
                font.family: Tokens.fontSans
                font.pixelSize: 9
                font.weight: Font.DemiBold
                font.letterSpacing: 0.8
            }
        }
        Rectangle {
            visible: root.ratio > 0
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            height: 4
            radius: 2
            color: Qt.alpha("#000000", 0.5)
            Rectangle { width: parent.width * root.ratio; height: parent.height; radius: 2; color: Tokens.themeAccent }
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.color: Qt.alpha("#ffffff", hover.hovered ? 0.15 : 0.05)
        }
    }
    ColumnLayout {
        id: meta
        anchors.top: cover.bottom
        anchors.topMargin: 12
        width: parent.width
        spacing: 3
        Text {
            Layout.fillWidth: true
            text: root.entry ? root.entry.title : ""
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: 14
            font.weight: Font.DemiBold
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: root.entry ? [root.entry.media_type, root.status, root.progressText].join(" · ")
                               + (root.entry.score ? " · ★ " + root.entry.score : "") : ""
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }
}
