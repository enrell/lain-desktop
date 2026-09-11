import QtQuick
import Lain

// Horizontal row aligned by parent layout margins. rowHeight determines its
// complete height without unused bands.
Column {
    id: root
    property string title: ""
    property alias model: list.model
    property Component delegate
    property int rowHeight: 280
    spacing: 12
    width: parent ? parent.width : 0

    Text {
        text: root.title
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.sectionSize
        font.weight: Font.DemiBold
        font.letterSpacing: 0.1
    }
    ListView {
        id: list
        width: parent.width
        height: root.rowHeight
        orientation: ListView.Horizontal
        spacing: Tokens.cardGap
        delegate: root.delegate
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
    }
}
