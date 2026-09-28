import QtQuick
import Lain

// Player button with a centered glyph and hover pill.
// Keyboard: Tab-reachable, Enter/Space activates, accent focus ring (DD-036).
Rectangle {
    implicitWidth: 44
    implicitHeight: 40
    radius: 10
    color: "transparent"
    activeFocusOnTab: true
    border.width: activeFocus ? 2 : 0
    border.color: Tokens.themeAccent

    property string glyph: ""
    property int glyphSize: 13
    property bool bold: false
    // Human-readable label for screen readers and future tooltips —
    // the glyph is an icon-font codepoint, not text.
    property string label: ""
    signal pressed()

    Accessible.role: Accessible.Button
    Accessible.name: label !== "" ? label : glyph

    Keys.onSpacePressed: pressed()
    Keys.onReturnPressed: pressed()
    Keys.onEnterPressed: pressed()

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
