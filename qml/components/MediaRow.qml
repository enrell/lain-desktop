import QtQuick
import Lain

// Horizontal row aligned by parent layout margins. rowHeight determines its
// complete height without unused bands. Optional actionLabel renders a
// "View all" style link on the right like the web MediaRow.
Column {
    id: root
    property string title: ""
    property alias model: list.model
    property Component delegate
    property int rowHeight: 280
    property string actionLabel: ""
    signal action()
    spacing: 12
    width: parent ? parent.width : 0

    Item {
        width: root.width
        height: Math.max(rowTitle.implicitHeight, actionText.implicitHeight)
        Text {
            id: rowTitle
            text: root.title
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.sectionSize + 2
            font.weight: Font.DemiBold
            font.letterSpacing: -0.4
        }
        Text {
            id: actionText
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            visible: root.actionLabel !== ""
            text: root.actionLabel
            color: actionHover.containsMouse ? Tokens.themeAccent : Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize - 1
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.6
            MouseArea {
                id: actionHover
                anchors.fill: parent
                anchors.margins: -8
                hoverEnabled: true
                onClicked: root.action()
            }
        }
    }
    ListView {
        id: list
        width: parent.width
        height: root.rowHeight
        orientation: ListView.Horizontal
        spacing: Tokens.cardGap + 2
        delegate: root.delegate
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true
    }
}
