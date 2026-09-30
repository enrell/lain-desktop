import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/users: accounts with role, active switch, per-user playback
// limits (server D-042) and password reset. Destructive changes confirm.
SettingsPage {
    id: page
    readonly property var users: server.users || []
    property var target: null
    property var confirmAction: null
    property string newRole: "user"
    property string formError: ""
    property bool pendingCreate: false

    // Playback-limits draft.
    property bool limVideo: true
    property bool limAudio: true
    property bool limRemux: true
    property string limSubtitle: ""

    function isSelf(u) { return server.me && u.id === server.me.id; }
    function joined(ts) { return ts > 0 ? Qt.formatDate(new Date(ts * 1000), "d MMM yyyy") : ""; }
    function openLimits(u) {
        target = u;
        var p = u.playback || {};
        limVideo = p.allow_video_transcode !== false;
        limAudio = p.allow_audio_transcode !== false;
        limRemux = p.allow_remux !== false;
        bitrateField.text = String(p.max_bitrate_kbps || 0);
        streamsField.text = String(p.max_streams || 0);
        limSubtitle = p.subtitle_mode || "";
        limitsModal.open();
    }
    function focusAnchor(anchor) {
        if (anchor === "add")
            addModal.open();
    }

    Component.onCompleted: server.loadUsers()
    Connections {
        target: server
        function onActionFinished(action, ok) {
            if (action === "user-playback" && ok)
                limitsModal.close();
        }
        function onErrorMessageChanged() {
            if (page.pendingCreate && server.errorMessage !== "") {
                page.pendingCreate = false;
                page.formError = server.errorMessage;
            }
        }
        function onAdminStatusChanged() {
            if (page.pendingCreate && server.adminStatus.indexOf(userField.text.trim()) >= 0) {
                page.pendingCreate = false;
                addModal.close();
            }
        }
    }

    ColumnLayout {
        property string anchorId: "users"
        Layout.fillWidth: true
        spacing: 16
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: (page.users.length === 1 ? qsTr("1 account.") : qsTr("%1 accounts.").arg(page.users.length))
                      + " " + qsTr("Roles and disabling take effect on the next request.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
            UiButton {
                text: qsTr("Add user")
                icon: "users"
                variant: "secondary"
                size: "sm"
                onClicked: {
                    page.formError = "";
                    userField.text = "";
                    passField.text = "";
                    page.newRole = "user";
                    addModal.open();
                    userField.focusField();
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
            Repeater {
                model: page.users
                delegate: ColumnLayout {
                    id: userRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 12
                        Layout.bottomMargin: 12
                        Layout.leftMargin: 4
                        spacing: 12
                        Avatar { size: 36; user: userRow.modelData }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            RowLayout {
                                spacing: 8
                                Text {
                                    text: server.displayNameFor(userRow.modelData)
                                    color: Tokens.textPrimary
                                    font.family: Tokens.fontSans
                                    font.pixelSize: 14
                                    font.weight: Font.Medium
                                }
                                Text {
                                    visible: !!(userRow.modelData.profile && userRow.modelData.profile.display_name)
                                    text: "@" + userRow.modelData.username
                                    color: Tokens.textTertiary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 11
                                }
                                UiBadge { visible: page.isSelf(userRow.modelData); text: qsTr("you"); tone: "accent" }
                                UiBadge { visible: userRow.modelData.disabled === true; text: qsTr("disabled"); tone: "danger" }
                            }
                            Text {
                                text: userRow.modelData.role + " · " + qsTr("joined %1").arg(page.joined(userRow.modelData.created_at))
                                color: Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                            }
                        }
                        Item { Layout.fillWidth: true }
                        UiSelect {
                            implicitWidth: 120
                            enabled: !page.isSelf(userRow.modelData)
                            label: qsTr("Role for %1").arg(userRow.modelData.username)
                            model: [{ id: "user", label: qsTr("User") }, { id: "admin", label: qsTr("Admin") }]
                            current: userRow.modelData.role
                            onPicked: id => {
                                if (id === userRow.modelData.role)
                                    return;
                                page.confirmAction = { kind: "role", user: userRow.modelData, role: id };
                                confirmModal.description = qsTr("Change role of %1 to %2?").arg(userRow.modelData.username).arg(id);
                                confirmModal.open();
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: false
                            spacing: 8
                            Text { text: qsTr("Active"); color: Tokens.textSecondary; font.family: Tokens.fontSans; font.pixelSize: 13 }
                            UiSwitch {
                                label: qsTr("Active")
                                enabled: !page.isSelf(userRow.modelData)
                                checked: userRow.modelData.disabled !== true
                                onToggled: c => {
                                    if (c) {
                                        server.setUserDisabled(userRow.modelData.id, false);
                                    } else {
                                        checked = true;
                                        page.confirmAction = { kind: "disable", user: userRow.modelData };
                                        confirmModal.description = qsTr("Disable user %1? They will not be able to sign in.").arg(userRow.modelData.username);
                                        confirmModal.open();
                                    }
                                }
                            }
                        }
                        UiButton { text: qsTr("Playback"); icon: "sliders"; variant: "ghost"; size: "sm"; onClicked: page.openLimits(userRow.modelData) }
                        UiButton {
                            text: qsTr("Reset password")
                            icon: "key"
                            variant: "ghost"
                            size: "sm"
                            onClicked: { page.target = userRow.modelData; resetField.text = ""; resetModal.open(); resetField.focusField(); }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
                }
            }
        }
    }

    UiModal {
        id: addModal
        title: qsTr("Add a user")
        description: qsTr("Accounts are local to this server.")
        Text {
            Layout.fillWidth: true
            visible: page.formError !== ""
            text: page.formError
            color: Tokens.danger
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        UiField { id: userField; Layout.fillWidth: true; label: qsTr("Username"); onAccepted: passField.focusField() }
        UiField { id: passField; Layout.fillWidth: true; label: qsTr("Password"); password: true; hint: qsTr("At least 8 characters.") }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: qsTr("Role"); color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
            UiSelect {
                Layout.fillWidth: true
                model: [{ id: "user", label: qsTr("User") }, { id: "admin", label: qsTr("Admin") }]
                current: page.newRole
                onPicked: id => page.newRole = id
            }
        }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: addModal.close() },
            UiButton {
                text: qsTr("Create user")
                loading: page.pendingCreate
                onClicked: {
                    page.formError = "";
                    if (userField.text.trim() === "" || passField.text.length < 8) {
                        page.formError = qsTr("Username required, password at least 8 characters.");
                        return;
                    }
                    page.pendingCreate = true;
                    server.createUser(userField.text.trim(), passField.text, page.newRole);
                }
            }
        ]
    }

    UiModal {
        id: resetModal
        title: qsTr("Reset password")
        description: qsTr("The user's current sessions are signed out immediately.")
        Text {
            Layout.fillWidth: true
            text: qsTr("New password for %1").arg(page.target ? page.target.username : "")
            color: Tokens.textSecondary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        UiField { id: resetField; Layout.fillWidth: true; label: qsTr("New password"); password: true; hint: qsTr("At least 8 characters.") }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: resetModal.close() },
            UiButton {
                text: qsTr("Reset password")
                enabled: resetField.text.length >= 8
                onClicked: {
                    server.resetUserPassword(page.target.id, resetField.text);
                    resetModal.close();
                }
            }
        ]
    }

    UiModal {
        id: limitsModal
        title: qsTr("Playback limits")
        description: qsTr("Per-user transcoding permissions and the output bitrate cap for other clients.")
        Text {
            Layout.fillWidth: true
            text: qsTr("Limits for %1").arg(page.target ? page.target.username : "")
            color: Tokens.textSecondary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        Repeater {
            model: [
                { key: "limVideo", label: qsTr("Allow video transcoding"), hint: qsTr("A re-encode of the video stream (codec, HDR, quality).") },
                { key: "limAudio", label: qsTr("Allow audio transcoding"), hint: qsTr("Audio codec conversion or downmix.") },
                { key: "limRemux", label: qsTr("Allow remuxing"), hint: qsTr("Container-only conversion with stream copy.") }
            ]
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: modelData.label; color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
                    Text { Layout.fillWidth: true; text: modelData.hint; color: Tokens.textTertiary; font.family: Tokens.fontSans; font.pixelSize: 12; wrapMode: Text.WordWrap }
                }
                UiSwitch {
                    label: modelData.label
                    checked: page[modelData.key]
                    onToggled: c => page[modelData.key] = c
                }
            }
        }
        UiField { id: bitrateField; Layout.fillWidth: true; label: qsTr("Maximum bitrate (kbps, 0 = unlimited)"); mono: true }
        UiField { id: streamsField; Layout.fillWidth: true; label: qsTr("Maximum simultaneous streams (0 = unlimited)"); mono: true }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: qsTr("Subtitle handling"); color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
            UiSelect {
                Layout.fillWidth: true
                model: [
                    { id: "", label: qsTr("Server default") },
                    { id: "auto", label: qsTr("Auto — extract text, burn image tracks") },
                    { id: "extract", label: qsTr("Extract only") },
                    { id: "burn", label: qsTr("Always burn in") },
                    { id: "off", label: qsTr("Off") }
                ]
                current: page.limSubtitle
                onPicked: id => page.limSubtitle = id
            }
        }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: limitsModal.close() },
            UiButton {
                text: qsTr("Save limits")
                onClicked: server.setUserPlayback(page.target.id, {
                    allow_video_transcode: page.limVideo,
                    allow_audio_transcode: page.limAudio,
                    allow_remux: page.limRemux,
                    max_bitrate_kbps: Math.max(0, parseInt(bitrateField.text) || 0),
                    max_streams: Math.max(0, parseInt(streamsField.text) || 0),
                    subtitle_mode: page.limSubtitle
                })
            }
        ]
    }

    UiModal {
        id: confirmModal
        title: qsTr("Are you sure?")
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: { confirmModal.close(); page.confirmAction = null; } },
            UiButton {
                text: qsTr("Confirm")
                variant: "danger"
                onClicked: {
                    var a = page.confirmAction;
                    confirmModal.close();
                    page.confirmAction = null;
                    if (!a)
                        return;
                    if (a.kind === "disable")
                        server.setUserDisabled(a.user.id, true);
                    else if (a.kind === "role")
                        server.setUserRole(a.user.id, a.role);
                }
            }
        ]
    }
}
