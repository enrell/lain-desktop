import QtQuick
import QtQuick.Layouts
import Lain

// Compact dropdown select matching the web Select primitive: bordered
// pill that opens a small surface menu.
Rectangle {
    id: root
    property var model: []
    property string current: ""
    signal picked(string id)

    height: 38
    width: 176
    radius: Tokens.radiusMd
    color: Tokens.surface1
    border.color: Tokens.borderSubtle

    function currentLabel() {
        for (var i = 0; i < model.length; ++i)
            if (model[i].id === current)
                return model[i].label;
        return model.length > 0 ? model[0].label : "";
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 12
        Text {
            Layout.fillWidth: true
            text: root.currentLabel()
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize
            elide: Text.ElideRight
        }
        Text {
            text: "▾"
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 12
        }
    }
    MouseArea {
        anchors.fill: parent
        onClicked: popup.visible = !popup.visible
    }

    Rectangle {
        id: popup
        visible: false
        anchors.top: parent.bottom
        anchors.topMargin: 6
        anchors.right: parent.right
        width: Math.max(parent.width, col.implicitWidth + 12)
        height: col.implicitHeight + 12
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        z: 50
        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            Repeater {
                model: root.model
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    Layout.preferredWidth: optText.implicitWidth + 20
                    radius: 8
                    color: "transparent"
                    Text {
                        id: optText
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: root.current === modelData.id ? Tokens.themeAccent : Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Tokens.hoverFill
                        onExited: parent.color = "transparent"
                        onClicked: { popup.visible = false; root.picked(modelData.id); }
                    }
                }
            }
        }
    }
}
