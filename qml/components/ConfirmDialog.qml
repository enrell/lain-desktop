import QtQuick
import QtQuick.Layouts
import Lain

// Dense confirmation dialog for destructive admin actions (DD-028).
// Keyboard: Enter confirms, Esc cancels. Focus lands on Cancel.
Rectangle {
    id: root
    anchors.fill: parent
    color: "#000000B8"
    z: 50
    visible: false

    property string title: qsTr("Are you sure?")
    property string message: ""
    property string confirmLabel: qsTr("Confirm")

    signal accepted()
    signal rejected()

    function open(messageText) {
        message = messageText;
        visible = true;
        cancelBox.forceActiveFocus();
    }
    function close() {
        visible = false;
    }

    MouseArea {
        anchors.fill: parent
        onClicked: { root.close(); root.rejected(); }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(440, parent.width - 80)
        height: confirmCol.implicitHeight + 44
        radius: Tokens.radiusLg
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            id: confirmCol
            anchors.fill: parent
            anchors.margins: 22
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: root.title
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.bodySize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: root.message !== ""
                text: root.message
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                wrapMode: Text.WordWrap
            }
            RowLayout {
                Layout.topMargin: 8
                spacing: 10
                Item { Layout.fillWidth: true }
                Rectangle {
                    id: cancelBox
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 34
                    radius: Tokens.radiusMd
                    color: Tokens.surface2
                    focus: true
                    Accessible.name: qsTr("Cancel")
                    Accessible.role: Accessible.Button
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Cancel")
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.close(); root.rejected(); }
                    }
                    Keys.onEnterPressed: { root.close(); root.rejected(); }
                    Keys.onReturnPressed: { root.close(); root.rejected(); }
                    Keys.onEscapePressed: { root.close(); root.rejected(); }
                }
                Rectangle {
                    Layout.preferredWidth: 110
                    Layout.preferredHeight: 34
                    radius: Tokens.radiusMd
                    color: Tokens.themeUrgent
                    Accessible.name: root.confirmLabel
                    Accessible.role: Accessible.Button
                    Text {
                        anchors.centerIn: parent
                        text: root.confirmLabel
                        color: "white"
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { root.close(); root.accepted(); }
                    }
                    Keys.onEnterPressed: { root.close(); root.accepted(); }
                    Keys.onReturnPressed: { root.close(); root.accepted(); }
                }
            }
        }
    }

    Keys.onEscapePressed: { root.close(); root.rejected(); }
}
