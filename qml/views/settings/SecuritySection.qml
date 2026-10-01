import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/security: change the password; every other session is
// signed out and this app keeps working on a freshly minted token.
SettingsPage {
    id: page
    property bool busy: false
    property string error: ""
    property string newError: ""
    property string confirmError: ""

    function submit() {
        error = "";
        newError = newField.text.length < 8 ? qsTr("At least 8 characters.") : "";
        confirmError = confirmField.text !== newField.text ? qsTr("Passwords do not match.") : "";
        if (newError !== "" || confirmError !== "")
            return;
        busy = true;
        server.changePassword(currentField.text, newField.text);
    }

    Connections {
        target: server
        function onActionFinished(action, ok, message) {
            if (action !== "password")
                return;
            page.busy = false;
            if (ok) {
                currentField.text = "";
                newField.text = "";
                confirmField.text = "";
            } else {
                page.error = message;
            }
        }
    }

    SettingsGroup {
        first: true
        anchorId: "password"
        title: qsTr("Password")
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            Layout.bottomMargin: 4
            visible: page.error !== ""
            text: page.error
            color: Tokens.danger
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        SettingRow {
            label: qsTr("Current password")
            UiField { id: currentField; fieldWidth: 288; password: true; onAccepted: newField.focusField() }
        }
        SettingRow {
            label: qsTr("New password")
            hint: qsTr("At least 8 characters.")
            UiField { id: newField; fieldWidth: 288; password: true; error: page.newError; onAccepted: confirmField.focusField() }
        }
        SettingRow {
            label: qsTr("Confirm new password")
            UiField { id: confirmField; fieldWidth: 288; password: true; error: page.confirmError; onAccepted: page.submit() }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Text {
                Layout.fillWidth: true
                text: qsTr("Every other session is signed out immediately.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 12
            }
            UiButton {
                text: qsTr("Update password")
                size: "sm"
                loading: page.busy
                onClicked: page.submit()
            }
        }
    }
}
