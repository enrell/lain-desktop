import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/integrations (admin): the server's AniList OAuth app. The
// secret is write-only: blank keeps the stored one.
SettingsPage {
    id: page
    readonly property var anilist: (server.integrations || {}).anilist || null
    property bool saving: false
    property bool copied: false

    Component.onCompleted: server.loadIntegrations()
    onAnilistChanged: if (anilist) clientField.text = anilist.client_id || ""
    Connections {
        target: server
        function onActionFinished(action, ok) {
            if (action === "integrations") {
                page.saving = false;
                if (ok)
                    secretField.text = "";
            }
        }
    }

    ColumnLayout {
        property string anchorId: "integrations"
        Layout.fillWidth: true
        Layout.maximumWidth: 620
        spacing: 16
        Text { text: "AniList"; color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 15; font.weight: Font.DemiBold }
        Text {
            Layout.fillWidth: true
            text: qsTr("One OAuth application for the whole server. Register it in the AniList developer settings, paste the client credentials below and set the redirect URL to exactly the callback shown here. Users can then link their own accounts from Settings › Connections.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        UiSpinner { visible: !page.anilist; size: 20 }
        ColumnLayout {
            Layout.fillWidth: true
            visible: !!page.anilist
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                Text { text: qsTr("Callback URL to register"); color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    UiField {
                        id: callbackField
                        Layout.fillWidth: true
                        readOnly: true
                        mono: true
                        text: page.anilist ? page.anilist.callback_url : ""
                    }
                    UiButton {
                        icon: page.copied ? "check" : "clipboard"
                        variant: "secondary"
                        Accessible.name: qsTr("Copy callback URL")
                        onClicked: {
                            callbackField.input.selectAll();
                            callbackField.input.copy();
                            callbackField.input.deselect();
                            page.copied = true;
                            copiedReset.restart();
                        }
                    }
                    Timer { id: copiedReset; interval: 1500; onTriggered: page.copied = false }
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("AniList requires an exact match. Behind a reverse proxy, this is the public URL users reach — not the internal bind address.")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                }
            }
            UiField { id: clientField; Layout.fillWidth: true; label: qsTr("Client ID"); placeholder: qsTr("The numeric id from the AniList app"); mono: true }
            UiField {
                id: secretField
                Layout.fillWidth: true
                label: qsTr("Client secret")
                password: true
                hint: page.anilist && page.anilist.secret_set
                      ? qsTr("A secret is stored — leave blank to keep it.")
                      : qsTr("Stored on the server only; it is never shown again.")
            }
            UiButton {
                text: qsTr("Save")
                loading: page.saving
                onClicked: { page.saving = true; server.saveIntegrations(clientField.text, secretField.text); }
            }
        }
    }
}
