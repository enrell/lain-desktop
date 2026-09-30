import QtQuick
import QtQuick.Layouts
import Lain

// Web Input on a settings surface: a filled field, bordered only on focus
// (app.css .settings-body). Optional label above and hint/error below.
ColumnLayout {
    id: root
    property alias text: input.text
    property string label: ""
    property string placeholder: ""
    property string hint: ""
    property string error: ""
    property bool password: false
    property bool mono: false
    property bool readOnly: false
    property int maximumLength: 32767
    property int fieldWidth: -1
    property alias input: input
    signal accepted()
    signal editingFinished()
    spacing: 6
    // Layouts default to filling; a sized field keeps its width in rows.
    Layout.fillWidth: fieldWidth < 0

    function focusField() { input.forceActiveFocus(); }

    Text {
        visible: root.label !== ""
        text: root.label
        color: Tokens.textPrimary
        font.family: Tokens.fontSans
        font.pixelSize: 13
        font.weight: Font.Medium
    }
    Rectangle {
        Layout.fillWidth: true
        implicitWidth: root.fieldWidth < 0 ? 240 : root.fieldWidth
        implicitHeight: Tokens.controlHeight
        radius: Math.max(4, Tokens.radiusSm + 2)
        color: hover.hovered && !input.activeFocus ? Tokens.fieldHover : Tokens.field
        border.width: input.activeFocus || root.error !== "" ? 1 : 0
        border.color: root.error !== "" ? Qt.alpha(Tokens.danger, 0.7) : Qt.alpha(Tokens.themeAccent, 0.7)
        HoverHandler { id: hover; cursorShape: Qt.IBeamCursor }
        TextInput {
            id: input
            property bool acceptsText: true
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: Tokens.textPrimary
            selectionColor: Qt.alpha(Tokens.themeAccent, 0.32)
            selectedTextColor: Tokens.textPrimary
            font.family: root.mono ? Tokens.fontFamily : Tokens.fontSans
            font.pixelSize: 13
            echoMode: root.password ? TextInput.Password : TextInput.Normal
            readOnly: root.readOnly
            maximumLength: root.maximumLength
            clip: true
            selectByMouse: true
            activeFocusOnTab: true
            Accessible.role: Accessible.EditableText
            Accessible.name: root.label !== "" ? root.label : root.placeholder
            onAccepted: root.accepted()
            onEditingFinished: root.editingFinished()
            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text === "" && !input.activeFocus
                text: root.placeholder
                color: Tokens.textTertiary
                font: input.font
                elide: Text.ElideRight
            }
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.maximumWidth: root.fieldWidth < 0 ? 100000 : root.fieldWidth
        visible: root.error !== "" || root.hint !== ""
        text: root.error !== "" ? root.error : root.hint
        color: root.error !== "" ? Tokens.danger : Tokens.textTertiary
        font.family: Tokens.fontSans
        font.pixelSize: 12
        wrapMode: Text.WordWrap
    }
}
