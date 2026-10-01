import QtQuick
import Lain

// Multi-line field with the settings field styling (bio and similar).
Rectangle {
    id: root
    property alias text: edit.text
    property string placeholder: ""
    property int maximumLength: 160
    property int lines: 2
    signal submit()
    implicitWidth: 288
    implicitHeight: lines * 20 + 16
    radius: Math.max(4, Tokens.radiusSm + 2)
    color: Tokens.field
    border.width: edit.activeFocus ? 1 : 0
    border.color: Qt.alpha(Tokens.themeAccent, 0.7)
    TextEdit {
        id: edit
        property bool acceptsText: true
        anchors.fill: parent
        anchors.margins: 8
        anchors.leftMargin: 10
        color: Tokens.textPrimary
        selectionColor: Qt.alpha(Tokens.themeAccent, 0.32)
        font.family: Tokens.fontSans
        font.pixelSize: 13
        wrapMode: TextEdit.Wrap
        selectByMouse: true
        activeFocusOnTab: true
        clip: true
        Accessible.role: Accessible.EditableText
        Accessible.name: root.placeholder
        onTextChanged: if (text.length > root.maximumLength) text = text.substring(0, root.maximumLength)
        Keys.onReturnPressed: event => {
            if (event.modifiers & Qt.ControlModifier)
                root.submit();
            else
                event.accepted = false;
        }
        Text {
            visible: edit.text === "" && !edit.activeFocus
            text: root.placeholder
            color: Tokens.textTertiary
            font: edit.font
        }
    }
}
