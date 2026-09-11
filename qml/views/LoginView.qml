import QtQuick
import QtQuick.Layouts
import Lain
import "../theme/Color.js" as Color

// Entry point for server connection, first-access setup, and login.
Item {
    id: root

    readonly property bool failure: server.state === "offline"
    readonly property bool setupMode: server.state === "setup"

    function submit() {
        if (server.busy)
            return;
        if (failure) {
            server.serverUrl = serverField.text;
            server.retry();
        } else if (setupMode) {
            server.setup(userField.text, passField.text);
        } else {
            server.login(userField.text, passField.text);
        }
    }

    // Subtle accent wash over the background, aligned with Hero.
    Rectangle {
        anchors.fill: parent
        color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.04))
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(420, root.width - 80)
        spacing: 0

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Lain"
            color: Tokens.themeAccent
            font.family: Tokens.fontFamily
            font.pixelSize: 46
            font.bold: true
            font.letterSpacing: 6
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: root.failure ? qsTr("Could not connect to the server")
                : root.setupMode ? qsTr("First access — create the administrator account")
                                 : qsTr("Sign in to access your library")
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.bodySize
        }

        Field {
            id: serverField
            objectName: "serverField"
            Layout.fillWidth: true
            Layout.topMargin: 34
            label: qsTr("Server")
            placeholder: "http://127.0.0.1:9360"
            text: server.serverUrl
            onAccepted: userField.forceActiveFocus()
        }

        Field {
            id: userField
            objectName: "userField"
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: !root.failure
            label: qsTr("Username")
            placeholder: "admin"
            onAccepted: passField.forceActiveFocus()
        }

        Field {
            id: passField
            objectName: "passwordField"
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: !root.failure
            label: qsTr("Password")
            placeholder: "••••••••"
            password: true
            onAccepted: root.submit()
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            objectName: "errorText"
            visible: server.errorMessage !== ""
            text: server.errorMessage
            color: Tokens.themeUrgent
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
            wrapMode: Text.WordWrap
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 22
            Layout.preferredHeight: Tokens.buttonHeight
            objectName: "submitButton"
            radius: Tokens.radiusMd
            color: server.busy ? Qt.tint(Tokens.themeAccent, Qt.alpha(Tokens.bgPrimary, 0.5)) : Tokens.themeAccent
            Text {
                anchors.centerIn: parent
                text: server.busy ? qsTr("Connecting…")
                    : root.failure ? qsTr("Try again")
                    : root.setupMode ? qsTr("Create account") : qsTr("Sign in")
                color: "black"
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.bodySize
                font.bold: true
            }
            MouseArea {
                anchors.fill: parent
                enabled: !server.busy
                onClicked: root.submit()
            }
        }

        SetupWizard {
            Layout.fillWidth: true
            Layout.topMargin: 18
            visible: root.failure
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 26
            text: qsTr("Build %1").arg(buildTs)
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize - 2
        }
    }

    // Styled field without QtQuick.Controls, preserving the visual language.
    component Field: Rectangle {
        id: field
        property alias text: input.text
        property string label: ""
        property string placeholder: ""
        property bool password: false
        signal accepted()
        implicitHeight: 62
        radius: Tokens.radiusMd
        color: Tokens.surface1
        border.color: input.activeFocus ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 0
            Text {
                Layout.topMargin: 6
                text: field.label
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 11
                font.letterSpacing: 1
            }
            TextInput {
                id: input
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.bodySize
                echoMode: field.password ? TextInput.Password : TextInput.Normal
                selectByMouse: true
                onAccepted: field.accepted()
                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: field.placeholder
                    color: Tokens.textTertiary
                    font: input.font
                    visible: input.text === "" && !input.activeFocus
                }
            }
        }
    }

    Component.onCompleted: {
        if (!root.failure)
            userField.forceActiveFocus();
        else
            serverField.forceActiveFocus();
    }
}
