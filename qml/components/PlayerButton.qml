import QtQuick
import Lain

// Player button with a centered glyph and hover pill.
Rectangle {
    implicitWidth: 44
    implicitHeight: 40
    radius: 10
    color: "transparent"

    property string glyph: ""
    property int glyphSize: 13
    property bool bold: false
    signal pressed()

    Text {
        anchors.centerIn: parent
        text: glyph
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: glyphSize
        font.bold: bold
    }
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: parent.color = Tokens.hoverFill
        onExited: parent.color = "transparent"
        // `pressed` alone resolves to the MouseArea's own bool property —
        // it must emit the component's signal, not call a bool.
        onClicked: parent.pressed()
    }
}
