import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"
import "../../theme/Format.js" as Format

// Web settings/connections: linked list accounts (AniList today). The
// remote stays the source of truth; disconnecting removes its entries.
// Redirect sign-in opens the browser; the pin flow needs no admin setup.
SettingsPage {
    id: page
    property string busy: ""
    property bool pinOpen: false
    property string pinError: ""
    readonly property var link: {
        var l = server.links || [];
        for (var i = 0; i < l.length; ++i)
            if (l[i].platform === "anilist")
                return l[i];
        return null;
    }
    readonly property bool needsReconnect: !!link && (link.token_expired === true
        || link.last_sync_error === "token-invalid" || link.last_sync_error === "token-expired")

    function relative(ts) { return Format.relative(ts); }
    function hintFor() {
        if (!link)
            return qsTr("Import your list. The remote stays the source of truth; disconnecting removes its entries.");
        var parts = [link.remote_username || link.remote_user_id,
                     link.entry_count === 1 ? qsTr("1 entry") : qsTr("%1 entries").arg(link.entry_count)];
        if (link.last_sync_at)
            parts.push(qsTr("synced %1").arg(relative(link.last_sync_at)));
        else if (link.last_sync_error)
            parts.push(qsTr("sync failed (%1)").arg(link.last_sync_error));
        return parts.join(" · ");
    }

    Component.onCompleted: server.loadLinks()
    Connections {
        target: server
        function onActionFinished(action, ok, message) {
            if (action.indexOf("link") === 0 || action === "unlink")
                page.busy = "";
            if (action === "link-code") {
                page.pinError = ok ? "" : message;
                if (ok) {
                    page.pinOpen = false;
                    pinField.text = "";
                }
            } else if (action === "link" && !ok && server.linkPinUrl !== "") {
                page.pinOpen = true;
            }
        }
        function onLinksChanged() { page.busy = ""; }
    }

    SettingsGroup {
        first: true
        anchorId: "anilist"
        title: qsTr("Lists")
        UiSpinner { Layout.alignment: Qt.AlignHCenter; Layout.margins: 24; visible: !server.linksLoaded; size: 20 }
        SettingRow {
            visible: server.linksLoaded
            label: "AniList"
            hint: page.hintFor()
            RowLayout {
                visible: !!page.link
                spacing: 6
                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: page.needsReconnect ? Tokens.danger : Tokens.themeAccent
                }
                Text {
                    text: page.needsReconnect ? qsTr("RECONNECT") : qsTr("CONNECTED")
                    color: page.needsReconnect ? Tokens.danger : Tokens.themeAccent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                }
            }
            UiButton {
                visible: !!page.link && page.needsReconnect
                text: qsTr("Reconnect")
                variant: "secondary"
                size: "sm"
                loading: page.busy === "anilist"
                onClicked: { page.busy = "anilist"; server.connectLink("anilist"); }
            }
            UiButton {
                visible: !!page.link && !page.needsReconnect
                text: qsTr("Sync")
                icon: "refresh"
                variant: "ghost"
                size: "sm"
                loading: page.busy === "anilist"
                onClicked: { page.busy = "anilist"; server.syncLink("anilist"); }
            }
            UiButton {
                visible: !!page.link
                text: qsTr("Disconnect")
                icon: "unlink"
                variant: "ghost"
                size: "sm"
                enabled: page.busy === ""
                onClicked: confirmUnlink.open()
            }
            UiButton {
                visible: !page.link
                text: qsTr("Connect")
                size: "sm"
                loading: page.busy === "anilist"
                onClicked: { page.busy = "anilist"; server.connectLink("anilist"); }
            }
            UiButton {
                visible: !page.link && server.linkPinUrl !== "" && !page.pinOpen
                text: qsTr("Use a code")
                variant: "ghost"
                size: "sm"
                onClicked: page.pinOpen = true
            }
            below: [
                RowLayout {
                    visible: !page.link && page.pinOpen && server.linkPinUrl !== ""
                    Layout.fillWidth: true
                    spacing: 8
                    UiButton {
                        Layout.alignment: Qt.AlignTop
                        text: qsTr("1 · Open AniList")
                        icon: "external"
                        variant: "secondary"
                        size: "sm"
                        onClicked: Qt.openUrlExternally(server.linkPinUrl)
                    }
                    UiField {
                        id: pinField
                        Layout.fillWidth: true
                        password: true
                        placeholder: qsTr("2 · Paste the code")
                        error: page.pinError
                        onAccepted: server.submitLinkCode("anilist", text)
                    }
                    UiButton {
                        Layout.alignment: Qt.AlignTop
                        text: qsTr("3 · Link")
                        size: "sm"
                        onClicked: server.submitLinkCode("anilist", pinField.text)
                    }
                }
            ]
        }
        SettingRow {
            visible: !!page.link
            label: qsTr("Update AniList when I finish an episode")
            hint: qsTr("Advances entries you already track. Never lowers progress or reopens completed titles.")
            UiSwitch {
                label: qsTr("Scrobble to AniList")
                checked: !!page.link && page.link.scrobble === true
                enabled: page.busy === ""
                onToggled: c => { page.busy = "anilist"; server.setLinkScrobble("anilist", c); }
            }
        }
    }

    UiModal {
        id: confirmUnlink
        title: qsTr("Disconnect AniList?")
        description: qsTr("Entries imported from it leave your list. The AniList account itself is untouched.")
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: confirmUnlink.close() },
            UiButton {
                text: qsTr("Disconnect")
                variant: "danger"
                onClicked: { confirmUnlink.close(); page.busy = "anilist"; server.unlink("anilist"); }
            }
        ]
    }
}
