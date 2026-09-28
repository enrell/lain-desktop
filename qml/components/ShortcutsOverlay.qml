import QtQuick
import QtQuick.Layouts
import Lain

// Keybindings overlay (DD-036): opened with `?` or the header button,
// dismissed by Esc, `?`, or clicking outside the panel.
Item {
    id: overlay
    anchors.fill: parent
    visible: false
    z: 90

    function open() { overlay.visible = true; closeBtn.forceActiveFocus(); }
    function close() { overlay.visible = false; }

    readonly property var groups: [
        {
            title: qsTr("Navigation"),
            keys: [
                ["g h", "Home"],
                ["g l", "Library"],
                ["g s", "Search"],
                ["g e", "Settings"],
                ["/ or Ctrl+F", "Search"],
                ["?", qsTr("This panel")],
                ["Esc", qsTr("Back / close")]
            ]
        },
        {
            title: qsTr("Player"),
            keys: [
                ["k or Space", qsTr("Play / pause")],
                ["j or h", qsTr("Rewind 10s")],
                ["l", qsTr("Forward 10s")],
                ["← →", qsTr("Seek ∓10s")],
                ["↑ ↓", qsTr("Volume ±5")],
                ["9 / 0", qsTr("Volume − / +")],
                ["m", qsTr("Mute")],
                ["a", qsTr("Cycle audio track")],
                ["s", qsTr("Cycle subtitles")],
                ["n / p", qsTr("Next / previous episode")],
                ["f", qsTr("Fullscreen")],
                ["Esc", qsTr("Exit fullscreen / back")]
            ]
        }
    ]

    // Dim + dismiss on click outside the panel.
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Tokens.bgPrimary, 0.72)
        TapHandler { onTapped: overlay.close() }
    }

    Rectangle {
        width: Math.min(560, overlay.width - 80)
        height: Math.min(col.implicitHeight + 40, overlay.height - 80)
        anchors.centerIn: parent
        radius: Tokens.radiusLg
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Keyboard shortcuts")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontSans
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    id: closeBtn
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    radius: 15
                    color: "transparent"
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 0
                    border.color: Tokens.themeAccent
                    Accessible.role: Accessible.Button
                    Accessible.name: qsTr("Close")
                    Keys.onSpacePressed: overlay.close()
                    Keys.onReturnPressed: overlay.close()
                    Keys.onEnterPressed: overlay.close()
                    Keys.onEscapePressed: overlay.close()
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: overlay.close()
                    }
                }
            }

            Repeater {
                model: overlay.groups
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: modelData.title
                        color: Tokens.themeAccent
                        font.family: Tokens.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6
                    }
                    Repeater {
                        model: modelData.keys
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 14
                            Text {
                                Layout.preferredWidth: 130
                                text: modelData[0]
                                color: Tokens.themeAccent
                                font.family: Tokens.fontFamily
                                font.pixelSize: 11
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData[1]
                                color: Tokens.textSecondary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }
    }
}
