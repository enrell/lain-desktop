import QtQuick
import QtQuick.Layouts
import Lain

// Web SettingRow: label + one-line hint on the left, the control on the
// right, a hairline below. `stack` puts wide controls (tables, grids)
// under the label. `saved` flashes a check after an instant-apply change.
ColumnLayout {
    id: root
    property string label: ""
    property string hint: ""
    property bool stack: false
    property string anchorId: ""
    default property alias controls: controlRow.data
    property alias below: belowCol.data
    spacing: 0
    Layout.fillWidth: true

    function flash() { savedMark.opacity = 1; fade.restart(); }
    function pulse() { pulseAnim.restart(); }

    Rectangle {
        id: wash
        Layout.fillWidth: true
        implicitHeight: grid.implicitHeight + 32
        color: "transparent"
        SequentialAnimation {
            id: pulseAnim
            ColorAnimation { target: wash; property: "color"; to: Qt.alpha(Tokens.themeAccent, 0.12); duration: 1 }
            PauseAnimation { duration: 600 }
            ColorAnimation { target: wash; property: "color"; to: "transparent"; duration: 1200 }
        }

        GridLayout {
            id: grid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            columns: root.stack ? 1 : 2
            columnSpacing: 32
            rowSpacing: 0

            ColumnLayout {
                Layout.preferredWidth: root.stack ? -1 : 272
                Layout.maximumWidth: root.stack ? 100000 : 272
                Layout.fillWidth: root.stack
                Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft
                spacing: 2
                RowLayout {
                    spacing: 8
                    Text {
                        text: root.label
                        color: Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: 14
                        font.weight: Font.Medium
                    }
                    RowLayout {
                        id: savedMark
                        opacity: 0
                        spacing: 4
                        Glyph { name: "check"; size: 12; color: Tokens.themeAccent }
                        Text {
                            text: qsTr("SAVED")
                            color: Tokens.themeAccent
                            font.family: Tokens.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.4
                        }
                        SequentialAnimation {
                            id: fade
                            PauseAnimation { duration: 900 }
                            NumberAnimation { target: savedMark; property: "opacity"; to: 0; duration: 700 }
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    visible: root.hint !== ""
                    text: root.hint
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    lineHeight: 1.25
                    wrapMode: Text.WordWrap
                }
            }
            RowLayout {
                id: controlRow
                Layout.fillWidth: root.stack
                Layout.topMargin: root.stack ? 12 : 0
                Layout.alignment: root.stack ? Qt.AlignLeft : (Qt.AlignRight | Qt.AlignVCenter)
                spacing: 8
            }
            ColumnLayout {
                id: belowCol
                Layout.columnSpan: root.stack ? 1 : 2
                Layout.fillWidth: true
                // Always present; empty (or all-hidden) content has no height.
                Layout.topMargin: implicitHeight > 0 ? 12 : 0
                spacing: 6
            }
        }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
}
