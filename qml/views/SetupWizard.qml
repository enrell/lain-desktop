import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Lain
import "../components"

// First-run setup wizard (DD-022..DD-026). Detection only in this slice:
// it probes the default server plus Docker/systemd tooling, defaults to
// connecting to an existing server, and records desktop-provisioned
// ownership without touching external installations.
ColumnLayout {
    id: root
    spacing: 10

    property string serverUrl: server.serverUrl
    property string expandedMethod: ""
    property string mediaDir: ""

    Component.onCompleted: provisioning.probe(serverUrl)

    Text {
        Layout.fillWidth: true
        text: qsTr("Set up your media server")
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.sectionSize
        font.weight: Font.DemiBold
    }

    Text {
        Layout.fillWidth: true
        visible: provisioning.statusMessage !== ""
        text: provisioning.statusMessage
        color: Tokens.textSecondary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize
        wrapMode: Text.WordWrap
    }

    // Existing server: connect by default (DD-023).
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 64
        radius: Tokens.radiusMd
        color: Tokens.surface1
        border.color: Tokens.borderSubtle
        visible: provisioning.serverReachable
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: qsTr("Connect")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.bodySize
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Connect to the existing server to avoid a duplicate setup.")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    wrapMode: Text.WordWrap
                }
            }
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 34
                radius: Tokens.radiusMd
                color: Tokens.themeAccent
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Connect")
                    color: "black"
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        server.serverUrl = root.serverUrl;
                        server.retry();
                    }
                }
            }
        }
    }

    // Provisioning methods (DD-025 hides Docker without a daemon).
    Text {
        Layout.topMargin: 6
        visible: !provisioning.serverReachable
        text: qsTr("Set up a new local server")
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.bodySize
        font.weight: Font.DemiBold
    }
    Text {
        Layout.fillWidth: true
        visible: !provisioning.serverReachable
        text: qsTr("How do you want to run it?")
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize
    }
    Repeater {
        objectName: "methodRepeater"
        model: provisioning.methods
        delegate: ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            property string methodId: modelData.id
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    Text {
                        Layout.fillWidth: true
                        text: modelData.label
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.bodySize
                    }
                    Text {
                        visible: provisioning.owned && provisioning.ownedMethod === modelData.id
                        text: qsTr("Managed by this app")
                        color: Tokens.themeAccent
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: !provisioning.busy
                    onClicked: root.expandedMethod = root.expandedMethod === methodId ? "" : methodId
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                visible: root.expandedMethod === methodId
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 8
                    Text {
                        text: qsTr("Port")
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    TextInput {
                        id: portInput
                        Layout.preferredWidth: 70
                        text: "9360"
                        inputMethodHints: Qt.ImhDigitsOnly
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.mediaDir === "" ? qsTr("Default location") : root.mediaDir
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        elide: Text.ElideMiddle
                    }
                    Text {
                        text: qsTr("Choose…")
                        color: Tokens.themeAccent
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        MouseArea {
                            anchors.fill: parent
                            onClicked: mediaPicker.open()
                        }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 150
                    Layout.preferredHeight: 34
                    radius: Tokens.radiusMd
                    color: provisioning.busy ? Tokens.surface2 : Tokens.themeAccent
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Provision")
                        color: provisioning.busy ? Tokens.textTertiary : "black"
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !provisioning.busy
                        onClicked: provisioning.provision(methodId, {
                            port: parseInt(portInput.text) || 9360,
                            mediaDir: root.mediaDir
                        })
                    }
                }
            }
        }
    }
    // Owned installation lifecycle (DD-018/DD-024: owned only).
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 8
        visible: provisioning.owned
        Text {
            Layout.topMargin: 8
            text: qsTr("Managed installation")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.bodySize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            visible: provisioning.updateAvailable
            text: qsTr("Update available: %1").arg(provisioning.latestVersion)
            color: Tokens.themeAccent
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        RowLayout {
            spacing: 8
            Repeater {
                model: [
                    { id: "start", label: qsTr("Start") },
                    { id: "stop", label: qsTr("Stop") },
                    { id: "update", label: qsTr("Update") },
                    { id: "uninstall", label: qsTr("Uninstall") }
                ]
                delegate: Rectangle {
                    Layout.preferredWidth: 90
                    Layout.preferredHeight: 32
                    radius: Tokens.radiusMd
                    color: Tokens.surface2
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !provisioning.busy
                        onClicked: {
                            if (modelData.id === "start") provisioning.startOwned();
                            else if (modelData.id === "stop") provisioning.stopOwned();
                            else if (modelData.id === "update") provisioning.updateOwned();
                            else if (modelData.id === "uninstall") root.askUninstall();
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Uninstalling removes the server but keeps your data.")
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize - 1
            wrapMode: Text.WordWrap
        }
        RowLayout {
            spacing: 8
            Text {
                text: qsTr("Check for updates")
                color: Tokens.themeAccent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                MouseArea {
                    anchors.fill: parent
                    onClicked: provisioning.checkForUpdates()
                }
            }
            Text {
                text: qsTr("Fix media permissions…")
                color: Tokens.themeAccent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                MouseArea {
                    anchors.fill: parent
                    onClicked: fixPicker.open()
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        visible: !provisioning.dockerAvailable
        text: qsTr("Docker needs a running daemon. Install Docker manually, then return.")
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize
        wrapMode: Text.WordWrap
    }
    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: qsTr("You can change this later. Provisioning never touches external servers.")
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize - 1
        wrapMode: Text.WordWrap
    }

    function askUninstall() {
        uninstallConfirm.open(qsTr("Uninstalling removes the server but keeps your data."));
    }

    FolderDialog {
        id: mediaPicker
        title: qsTr("Media directory")
        onAccepted: root.mediaDir = String(mediaPicker.selectedFolder).replace(/^file:\/\//, "")
    }

    FolderDialog {
        id: fixPicker
        title: qsTr("Media directory")
        onAccepted: provisioning.fixMediaPermissions(String(fixPicker.selectedFolder).replace(/^file:\/\//, ""))
    }

    ConfirmDialog {
        id: uninstallConfirm
        confirmLabel: qsTr("Uninstall")
        onAccepted: provisioning.uninstallOwned()
    }
}
