import QtQuick
import QtQuick.Layouts
import Lain

// Web Modal: a scrim plus a surface card with title, description, body and
// an optional right-aligned footer. Lifts itself to the window overlay so
// it covers the whole app even when declared inside a scrolled pane.
// Esc and the × close it; focus moves into the card on open.
Item {
    id: root
    property string title: ""
    property string description: ""
    property int cardWidth: 544
    default property alias content: body.data
    property alias footer: footerRow.data
    readonly property bool opened: visible
    signal closed()

    visible: false
    z: 2000
    width: parent ? parent.width : 0
    height: parent ? parent.height : 0

    function open() {
        var host = root.Window.window ? root.Window.window.contentItem : null;
        if (host && parent !== host)
            parent = host;
        visible = true;
        card.forceActiveFocus();
    }
    function close() {
        if (!visible)
            return;
        visible = false;
        closed();
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("#000000", 0.7)
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(root.cardWidth, root.width * 0.92)
        height: Math.min(cardCol.implicitHeight + 40, root.height * 0.9)
        radius: Tokens.radiusLg
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        clip: true
        Keys.onEscapePressed: root.close()
        activeFocusOnTab: false
        MouseArea { anchors.fill: parent }

        Flickable {
            anchors.fill: parent
            anchors.margins: 20
            contentHeight: cardCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: cardCol
                width: parent.width
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text {
                            Layout.fillWidth: true
                            text: root.title
                            color: Tokens.textPrimary
                            font.family: Tokens.fontSans
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: root.description !== ""
                            text: root.description
                            color: Tokens.textTertiary
                            font.family: Tokens.fontSans
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                    }
                    UiButton {
                        Layout.alignment: Qt.AlignTop
                        variant: "ghost"
                        size: "sm"
                        icon: "x"
                        Accessible.name: qsTr("Close")
                        implicitWidth: 32
                        onClicked: root.close()
                    }
                }
                ColumnLayout {
                    id: body
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 14
                }
                RowLayout {
                    id: footerRow
                    Layout.alignment: Qt.AlignRight
                    Layout.topMargin: children.length > 0 ? 22 : 0
                    spacing: 8
                }
            }
        }
    }
}
