import QtQuick
import Lain

// Web Switch: a 40×24 track on the field color; checked tints the track
// with the accent and slides the thumb. Space/Enter toggle.
Rectangle {
    id: root
    property bool checked: false
    property string label: ""
    signal toggled(bool checked)

    implicitWidth: 40
    implicitHeight: 24
    radius: 12
    opacity: enabled ? 1 : 0.5
    color: checked ? Qt.alpha(Tokens.themeAccent, 0.25) : Tokens.field
    border.width: activeFocus ? 2 : 1
    border.color: activeFocus ? Tokens.themeAccent : checked ? Qt.alpha(Tokens.themeAccent, 0.4) : Tokens.hairline
    activeFocusOnTab: enabled
    Accessible.role: Accessible.CheckBox
    Accessible.name: label
    Accessible.checked: checked
    function flip() {
        if (!enabled)
            return;
        checked = !checked;
        toggled(checked);
    }
    Keys.onSpacePressed: flip()
    Keys.onReturnPressed: flip()
    Behavior on color { ColorAnimation { duration: 120 } }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 4
        color: root.checked ? Tokens.themeAccent : Tokens.textTertiary
        Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.flip()
    }
}
