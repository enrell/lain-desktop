import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Lain
import "../../components"

// Web settings/profile: identity preview, display name + bio, avatar
// (upload, initials, mascots), interface language, and the session.
SettingsPage {
    id: page
    signal loggedOut()

    readonly property var me: server.me || ({})
    readonly property var profile: me.profile || ({})
    readonly property var avatar: profile.avatar || ({})
    readonly property var mascots: [
        { id: "wired", name: "Wired" }, { id: "moth", name: "Moth" }, { id: "static", name: "Static" },
        { id: "orbit", name: "Orbit" }, { id: "glyph", name: "Glyph" }, { id: "shell", name: "Shell" },
        { id: "neon", name: "Neon" }, { id: "void", name: "Void" }
    ]
    readonly property bool dirty: !!nameField && !!bioField
                                  && (String(nameField.text).trim() !== (profile.display_name || "")
                                      || String(bioField.text).trim() !== (profile.bio || ""))
    property bool saving: false
    property bool uploading: false

    function resetFields() {
        var p = (server.me && server.me.profile) || {};
        nameField.text = p.display_name || "";
        bioField.text = p.bio || "";
    }
    function save() {
        saving = true;
        server.updateProfile({ display_name: nameField.text, bio: bioField.text });
    }
    function since(ts) {
        return ts > 0 ? Qt.formatDate(new Date(ts * 1000), "MMM yyyy") : "";
    }
    Component.onCompleted: resetFields()
    onMeChanged: if (!saving && !dirty) resetFields()

    Connections {
        target: server
        function onActionFinished(action, ok, message) {
            if (action === "profile") {
                page.saving = false;
                if (ok) {
                    page.resetFields();
                    detailsRow.flash();
                }
            } else if (action === "avatar") {
                page.uploading = false;
                if (ok)
                    pictureRow.flash();
            }
        }
    }

    // Identity: a live preview of what other people see.
    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        spacing: 20
        visible: server.ready
        Avatar {
            size: 80
            user: {
                var u = JSON.parse(JSON.stringify(page.me));
                u.profile = u.profile || { avatar: {} };
                u.profile.display_name = nameField.text;
                return u;
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: (nameField.text.trim() || server.username).toUpperCase()
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 24
                font.weight: Font.Black
                font.letterSpacing: -0.9
                elide: Text.ElideRight
            }
            Text {
                text: ("@" + server.username + " · " + server.role
                       + (page.me.created_at ? " · " + qsTr("since %1").arg(page.since(page.me.created_at)) : "")).toUpperCase()
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 2
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 560
                visible: bioField.text.trim() !== ""
                text: bioField.text.trim()
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 14
                wrapMode: Text.WordWrap
            }
        }
    }

    SettingsGroup {
        title: qsTr("Details")
        visible: server.ready
        SettingRow {
            id: detailsRow
            anchorId: "display-name"
            label: qsTr("Display name")
            hint: qsTr("Shown instead of @%1.").arg(server.username)
            UiField {
                id: nameField
                fieldWidth: 288
                placeholder: server.username
                maximumLength: 40
                onAccepted: if (page.dirty) page.save()
            }
            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: nameField.text.length + "/40"
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
            }
        }
        SettingRow {
            anchorId: "bio"
            label: qsTr("Bio")
            hint: qsTr("One or two lines.")
            UiTextArea {
                id: bioField
                implicitWidth: 288
                placeholder: qsTr("A line about you.")
                maximumLength: 160
                onSubmit: if (page.dirty) page.save()
            }
            Text {
                Layout.preferredWidth: 44
                horizontalAlignment: Text.AlignRight
                text: bioField.text.length + "/160"
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            visible: page.dirty
            Item { Layout.fillWidth: true }
            Text {
                text: "CTRL+ENTER"
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
                font.letterSpacing: 1.4
            }
            UiButton {
                text: qsTr("Save details")
                size: "sm"
                loading: page.saving
                onClicked: page.save()
            }
        }
    }

    SettingsGroup {
        anchorId: "avatar"
        title: qsTr("Avatar")
        visible: server.ready
        SettingRow {
            id: pictureRow
            label: qsTr("Picture")
            hint: qsTr("PNG, JPEG, GIF or WebP · up to 2 MB.")
            UiButton {
                text: qsTr("Upload")
                icon: "upload"
                variant: "secondary"
                size: "sm"
                loading: page.uploading
                onClicked: pictureDialog.open()
            }
            UiButton {
                visible: !!page.avatar.kind
                text: qsTr("Use initials")
                icon: "trash"
                variant: "ghost"
                size: "sm"
                onClicked: server.removeAvatar()
            }
        }
        SettingRow {
            label: qsTr("Mascot")
            hint: qsTr("Arrow keys move and pick.")
            stack: true
            GridLayout {
                id: mascotGrid
                columns: 8
                columnSpacing: 8
                rowSpacing: 8
                Accessible.role: Accessible.RadioButton
                Repeater {
                    model: page.mascots
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property bool on: page.avatar.kind === "mascot" && page.avatar.mascot === modelData.id
                        implicitWidth: 72
                        implicitHeight: 84
                        radius: Tokens.radiusMd
                        color: on ? Tokens.selectedFill : cellHover.hovered ? Tokens.hoverFill : "transparent"
                        border.width: activeFocus ? 2 : 0
                        border.color: Tokens.themeAccent
                        activeFocusOnTab: on || (index === 0 && page.avatar.kind !== "mascot")
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData.name
                        Accessible.checked: on
                        function pick(i) {
                            var n = page.mascots.length;
                            var to = (i + n) % n;
                            server.updateProfile({ mascot: page.mascots[to].id });
                            var target = mascotRepeater.itemAt(to);
                            if (target)
                                target.forceActiveFocus();
                        }
                        Keys.onRightPressed: pick(index + 1)
                        Keys.onLeftPressed: pick(index - 1)
                        Keys.onDownPressed: pick(index + 8)
                        Keys.onUpPressed: pick(index - 8)
                        Keys.onSpacePressed: pick(index)
                        Keys.onReturnPressed: pick(index)
                        HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: server.updateProfile({ mascot: cell.modelData.id }) }
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 52
                                implicitHeight: 52
                                radius: 26
                                color: "transparent"
                                border.width: 2
                                border.color: cell.on ? Tokens.themeAccent : "transparent"
                                Mascot {
                                    anchors.centerIn: parent
                                    width: 48
                                    height: 48
                                    round: true
                                    mascotId: cell.modelData.id
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: cell.modelData.name.toUpperCase()
                                color: cell.on ? Tokens.themeAccent : Tokens.textTertiary
                                font.family: Tokens.fontFamily
                                font.pixelSize: 9
                                font.letterSpacing: 1.4
                            }
                        }
                    }
                    id: mascotRepeater
                }
            }
        }
    }

    SettingsGroup {
        anchorId: "interface"
        title: qsTr("Interface")
        SettingRow {
            id: languageRow
            label: qsTr("Language")
            hint: qsTr("Follows the system until you pick one. Applies instantly.")
            Repeater {
                objectName: "languageRepeater"
                model: localeManager.available
                delegate: Rectangle {
                    required property var modelData
                    readonly property bool on: localeManager.selected === modelData.id
                    implicitHeight: Tokens.controlHeightSm
                    implicitWidth: langLabel.implicitWidth + 24
                    radius: Math.max(4, Tokens.radiusSm + 2)
                    color: on ? Tokens.selectedFill : langHover.hovered ? Tokens.hoverFill : Tokens.field
                    border.width: activeFocus ? 2 : 0
                    border.color: Tokens.themeAccent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.RadioButton
                    Accessible.name: modelData.label
                    Accessible.checked: on
                    Keys.onSpacePressed: { localeManager.setSelected(modelData.id); languageRow.flash(); }
                    Keys.onReturnPressed: { localeManager.setSelected(modelData.id); languageRow.flash(); }
                    HoverHandler { id: langHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: { localeManager.setSelected(parent.modelData.id); languageRow.flash(); } }
                    Text {
                        id: langLabel
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: parent.on ? Tokens.textPrimary : Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                    }
                }
            }
        }
    }

    SettingsGroup {
        anchorId: "account"
        title: qsTr("Account")
        visible: server.ready
        SettingRow {
            label: qsTr("Username")
            hint: qsTr("Used to sign in. Only an admin can change it.")
            Text {
                text: "@" + server.username
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 14
            }
        }
        SettingRow {
            label: qsTr("Role")
            RowLayout {
                spacing: 6
                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: server.role === "admin" ? Tokens.themeAccent : Tokens.textTertiary
                }
                Text {
                    text: server.role.toUpperCase()
                    color: server.role === "admin" ? Tokens.themeAccent : Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                }
            }
        }
        SettingRow {
            label: qsTr("Session")
            hint: qsTr("Signs out of this app only.")
            UiButton {
                text: qsTr("Sign out")
                icon: "log-out"
                variant: "ghost"
                size: "sm"
                onClicked: { server.logout(); page.loggedOut(); }
            }
        }
    }

    FileDialog {
        id: pictureDialog
        title: qsTr("Choose a picture")
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.gif *.webp)")]
        onAccepted: {
            page.uploading = true;
            server.uploadAvatar(selectedFile);
        }
    }
}
