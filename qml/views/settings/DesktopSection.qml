import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Desktop-only controls (DD-037): the server this app talks to, the
// offline progress queue (DD-032), automatic enrichment, the live Omarchy
// palette (DD-008), and app updates (DD-026).
SettingsPage {
    id: page
    signal loggedOut()

    function stateLabel() {
        switch (server.state) {
        case "ready": return qsTr("Connected");
        case "login": return qsTr("Waiting for sign-in");
        case "setup": return qsTr("First access");
        default: return qsTr("Offline");
        }
    }

    SettingsGroup {
        first: true
        anchorId: "server"
        title: qsTr("Server")
        SettingRow {
            label: qsTr("Address")
            hint: server.errorMessage !== "" ? server.errorMessage : qsTr("The Lain server this app reads from.")
            RowLayout {
                spacing: 6
                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: server.ready ? Tokens.themeAccent : Tokens.danger
                }
                Text {
                    text: page.stateLabel().toUpperCase()
                    color: server.ready ? Tokens.themeAccent : Tokens.danger
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                }
            }
            Text {
                text: server.serverUrl
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 13
            }
        }
        SettingRow {
            label: qsTr("Queued progress")
            hint: qsTr("Positions saved while the server was unreachable. They are sent on reconnect.")
            Text {
                text: server.pendingProgress === 1 ? qsTr("1 queued update")
                                                   : qsTr("%1 queued updates").arg(server.pendingProgress)
                color: server.pendingProgress > 0 ? Tokens.warning : Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
            }
            UiButton {
                text: qsTr("Reconnect")
                icon: "refresh"
                variant: "secondary"
                size: "sm"
                onClicked: { server.refresh(); server.flushProgress(); }
            }
        }
        SettingRow {
            label: qsTr("Session")
            hint: qsTr("Sign out to switch accounts or servers.")
            UiButton {
                text: qsTr("Sign out")
                icon: "log-out"
                variant: "ghost"
                size: "sm"
                onClicked: { server.logout(); page.loggedOut(); }
            }
        }
    }

    SettingsGroup {
        anchorId: "metadata"
        title: qsTr("Metadata")
        SettingRow {
            id: enrichRow
            label: qsTr("Enrich new items automatically")
            hint: server.pendingEnrichment > 0
                  ? (server.pendingEnrichment === 1 ? qsTr("1 item left to enrich")
                                                     : qsTr("%1 items left to enrich").arg(server.pendingEnrichment))
                  : qsTr("Fetches titles, posters and synopses with the Auto provider. Removed overlays stay removed.")
            UiSwitch {
                label: qsTr("Enrich new items automatically")
                checked: server.autoEnrich
                onToggled: c => { server.setAutoEnrich(c); enrichRow.flash(); }
            }
        }
    }

    SettingsGroup {
        anchorId: "appearance"
        title: qsTr("Appearance")
        SettingRow {
            label: qsTr("Omarchy palette")
            hint: qsTr("Follows the Omarchy theme live, without restarting. Corners mirror Hyprland rounding (%1).").arg(omarchy.cornerRadius)
            stack: true
            RowLayout {
                spacing: 12
                Repeater {
                    model: [
                        { name: "background", c: omarchy.background },
                        { name: "foreground", c: omarchy.foreground },
                        { name: "accent", c: omarchy.accent },
                        { name: "urgent", c: omarchy.urgent },
                        { name: "muted", c: omarchy.muted }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            implicitWidth: 64
                            implicitHeight: 44
                            radius: Tokens.radiusSm
                            color: modelData.c
                            border.color: Tokens.hairline
                        }
                        Text {
                            text: modelData.name.toUpperCase()
                            color: Tokens.textTertiary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 9
                            font.letterSpacing: 1.2
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        anchorId: "about"
        title: qsTr("About")
        SettingRow {
            label: qsTr("Lain desktop %1").arg(appVersion)
            hint: provisioning.desktopUpdateAvailable
                  ? qsTr("App update available: %1").arg(provisioning.desktopLatest)
                  : qsTr("Build %1").arg(buildTs)
            UiButton {
                text: qsTr("Check for app updates")
                variant: "ghost"
                size: "sm"
                enabled: !provisioning.busy
                onClicked: provisioning.checkDesktopUpdates()
            }
            UiButton {
                visible: provisioning.desktopUpdateAvailable
                text: qsTr("Update to %1").arg(provisioning.desktopLatest)
                size: "sm"
                enabled: !provisioning.busy
                onClicked: provisioning.applyDesktopUpdate(provisioning.desktopExecutable)
            }
        }
    }
}
