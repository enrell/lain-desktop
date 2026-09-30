import QtQuick
import QtQuick.Layouts
import Lain
import "../components"
import "settings"

// Web Settings shell (DD-037, web routes/settings/+layout.svelte): a rail
// split into YOU and SERVER beside one reading column. Keyboard-first:
//   g+letter  open a section (mnemonic, stable across roles)
//   [ / ]     previous / next section
// The command palette (Ctrl+K) lands on sections and their rows.
Item {
    id: root
    signal loggedOut()

    // Main's Flickable offset, so the rail stays put like a tiled window.
    property real scrollY: 0
    readonly property bool isAdmin: server.ready && server.role === "admin"

    readonly property var allSections: [
        { id: "profile", scope: "you", key: "p", label: qsTr("Profile"), hint: qsTr("Name, avatar, language and session.") },
        { id: "playback", scope: "you", key: "y", label: qsTr("Playback"), hint: qsTr("Resume, autoplay, language and video effects.") },
        { id: "connections", scope: "you", key: "c", label: qsTr("Connections"), hint: qsTr("Linked list accounts such as AniList.") },
        { id: "security", scope: "you", key: "s", label: qsTr("Security"), hint: qsTr("Change your password.") },
        { id: "desktop", scope: "you", key: "d", label: qsTr("Desktop"), hint: qsTr("Server connection, appearance, metadata and updates.") },
        { id: "libraries", scope: "server", key: "l", label: qsTr("Libraries"), hint: qsTr("Media folders and scanning.") },
        { id: "users", scope: "server", key: "u", label: qsTr("Users"), hint: qsTr("Accounts, roles and playback limits.") },
        { id: "transcoding", scope: "server", key: "t", label: qsTr("Transcoding"), hint: qsTr("How the server converts media for other clients.") },
        { id: "integrations", scope: "server", key: "i", label: qsTr("Integrations"), hint: qsTr("OAuth applications for list sync.") },
        { id: "plugins", scope: "server", key: "x", label: qsTr("Plugins"), hint: qsTr("Which plugin does each server job.") },
        { id: "backup", scope: "server", key: "b", label: qsTr("Backup"), hint: qsTr("Download a database snapshot.") }
    ]
    readonly property var sections: allSections.filter(s => isAdmin || s.scope === "you")

    property string section: String(server.pref("settings/last", "profile"))
    readonly property var current: {
        for (var i = 0; i < sections.length; ++i)
            if (sections[i].id === section)
                return sections[i];
        return sections[0];
    }
    // A row anchor to pulse once the section is loaded (from Ctrl+K).
    property string pendingAnchor: ""

    function open(id, anchor) {
        for (var i = 0; i < sections.length; ++i) {
            if (sections[i].id === id) {
                section = id;
                server.setPref("settings/last", id);
                pendingAnchor = anchor || "";
                if (pane.item && pane.item.focusAnchor && pendingAnchor !== "")
                    Qt.callLater(() => { if (pane.item) pane.item.focusAnchor(root.pendingAnchor); root.pendingAnchor = ""; });
                return true;
            }
        }
        return false;
    }
    function cycle(delta) {
        var at = 0;
        for (var i = 0; i < sections.length; ++i)
            if (sections[i].id === current.id)
                at = i;
        open(sections[(at + delta + sections.length) % sections.length].id);
    }
    // Second key of a `g` chord while Settings is open.
    function chord(key) {
        for (var i = 0; i < sections.length; ++i)
            if (sections[i].key === key)
                return open(sections[i].id);
        return false;
    }

    implicitHeight: Math.max(rail.implicitHeight + 40, (pane.item ? pane.item.implicitHeight : 0) + paneHeader.implicitHeight + 40) + 80

    readonly property int columnWidth: Math.min(Tokens.settingsColumn, width - 2 * Tokens.pageMargin)
    readonly property int columnX: Math.round((width - columnWidth) / 2)

    // ------------------------------------------------------------------ rail
    ColumnLayout {
        id: rail
        x: root.columnX
        y: Math.max(40, Math.min(root.scrollY + 40, root.height - implicitHeight - 40))
        width: Tokens.settingsRailWidth
        spacing: 0

        Text {
            objectName: "settingsTitle"
            text: qsTr("Settings")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 2.6
            font.capitalization: Font.AllUppercase
        }

        Repeater {
            model: ["you", "server"]
            delegate: ColumnLayout {
                id: group
                required property string modelData
                readonly property var entries: root.allSections.filter(s => s.scope === modelData)
                Layout.fillWidth: true
                Layout.topMargin: 24
                spacing: 1
                visible: modelData === "you" || root.isAdmin
                Text {
                    Layout.bottomMargin: 4
                    text: group.modelData === "you" ? qsTr("You") : qsTr("Server")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 2.6
                    font.capitalization: Font.AllUppercase
                }
                Repeater {
                    model: group.entries
                    delegate: Rectangle {
                        id: entry
                        required property var modelData
                        readonly property bool on: root.current && root.current.id === modelData.id
                        objectName: "rail-" + modelData.id
                        visible: modelData.scope === "you" || root.isAdmin
                        Layout.fillWidth: true
                        implicitHeight: 32
                        radius: Math.max(4, Tokens.radiusSm + 2)
                        color: on ? Tokens.selectedFill : hover.hovered ? Tokens.hoverFill : "transparent"
                        border.width: activeFocus ? 2 : 0
                        border.color: Tokens.themeAccent
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Link
                        Accessible.name: modelData.label
                        Keys.onReturnPressed: root.open(modelData.id)
                        Keys.onSpacePressed: root.open(modelData.id)
                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: root.open(entry.modelData.id) }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 2
                                Layout.preferredHeight: 14
                                radius: 1
                                color: entry.on ? Tokens.themeAccent : "transparent"
                            }
                            Text {
                                Layout.fillWidth: true
                                text: entry.modelData.label
                                color: entry.on || hover.hovered ? Tokens.textPrimary : Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 14
                            }
                            Text {
                                text: "g" + entry.modelData.key
                                color: Qt.alpha(Tokens.textTertiary, 0.7)
                                font.family: Tokens.fontFamily
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.topMargin: 28
            Layout.fillWidth: true
            text: qsTr("Ctrl K  find a setting\n[ ]  previous · next section")
            color: Qt.alpha(Tokens.textTertiary, 0.8)
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            lineHeight: 1.5
        }
    }

    // ------------------------------------------------------------------ pane
    ColumnLayout {
        id: paneHeader
        x: root.columnX + Tokens.settingsRailWidth + 48
        y: 40
        width: root.columnWidth - Tokens.settingsRailWidth - 48
        spacing: 0
        Text {
            Layout.bottomMargin: 20
            text: ((root.current.scope === "you" ? qsTr("You") : qsTr("Server")) + " › " + root.current.label).toLowerCase()
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 2.2
        }
    }
    Loader {
        id: pane
        objectName: "settingsPane"
        x: paneHeader.x
        y: paneHeader.y + paneHeader.implicitHeight
        width: paneHeader.width
        readonly property var components: ({
            "profile": profileSection, "playback": playbackSection, "connections": connectionsSection,
            "security": securitySection, "desktop": desktopSection, "libraries": librariesSection,
            "users": usersSection, "transcoding": transcodingSection, "integrations": integrationsSection,
            "plugins": pluginsSection, "backup": backupSection
        })
        sourceComponent: components[root.current.id]
        onLoaded: {
            if (root.pendingAnchor !== "" && item.focusAnchor) {
                var a = root.pendingAnchor;
                root.pendingAnchor = "";
                Qt.callLater(() => item.focusAnchor(a));
            }
        }
    }

    Component { id: profileSection; ProfileSection { onLoggedOut: root.loggedOut() } }
    Component { id: playbackSection; PlaybackSection {} }
    Component { id: connectionsSection; ConnectionsSection {} }
    Component { id: securitySection; SecuritySection {} }
    Component { id: desktopSection; DesktopSection { onLoggedOut: root.loggedOut() } }
    Component { id: librariesSection; LibrariesSection {} }
    Component { id: usersSection; UsersSection {} }
    Component { id: transcodingSection; TranscodingSection {} }
    Component { id: integrationsSection; IntegrationsSection {} }
    Component { id: pluginsSection; PluginsSection {} }
    Component { id: backupSection; BackupSection {} }
}
