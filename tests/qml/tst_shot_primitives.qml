import QtQuick
import QtQuick.Layouts
import QtTest
import Lain
import "../helpers"

// Visual QA: web design-system primitives (buttons, fields, select,
// switch, badges, avatars, mascots, a settings row group).
TestCase {
    id: testCase
    name: "ShotPrimitives"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost {
        id: host
        content: body
    }
    Component {
        id: body
        ColumnLayout {
            width: host.captureWidth
            spacing: 24
            RowLayout {
                Layout.margins: 32
                spacing: 12
                UiButton { text: "Primary"; icon: "play" }
                UiButton { text: "Secondary"; variant: "secondary"; icon: "folder-plus" }
                UiButton { text: "Ghost"; variant: "ghost"; icon: "refresh" }
                UiButton { text: "Danger"; variant: "danger"; icon: "trash" }
                UiButton { text: "Small"; size: "sm" }
                UiButton { text: "Loading"; loading: true; variant: "secondary" }
                UiButton { text: "Disabled"; enabled: false }
                UiSwitch { checked: true }
                UiSwitch { checked: false }
                UiBadge { text: "admin"; tone: "accent" }
                UiBadge { text: "disabled"; tone: "danger" }
                UiBadge { text: "anime" }
            }
            RowLayout {
                Layout.leftMargin: 32
                spacing: 12
                UiField { fieldWidth: 240; placeholder: "Display name" }
                UiField { fieldWidth: 240; text: "admin"; label: "Username"; hint: "At least 8 characters." }
                UiField { fieldWidth: 200; text: "x"; error: "Passwords do not match." }
                UiSelect { model: [{ id: "a", label: "Anime" }, { id: "b", label: "Movies" }]; current: "a" }
                UiTextArea { placeholder: "A line about you." }
            }
            RowLayout {
                Layout.leftMargin: 32
                spacing: 16
                Repeater {
                    model: ["wired", "moth", "static", "orbit", "glyph", "shell", "neon", "void"]
                    Mascot { width: 48; height: 48; mascotId: modelData }
                }
                Avatar { size: 40 }
                Avatar { size: 40; user: ({ id: "x", username: "zed", profile: { avatar: { kind: "mascot", mascot: "orbit" } } }) }
                Repeater {
                    model: ["play", "trash", "folder", "refresh", "search", "user", "users", "key", "upload", "unlink", "list", "scan", "book", "sliders", "info", "check-circle", "clipboard", "rotate-ccw", "sparkles", "shield", "plug", "database", "cpu", "monitor"]
                    Glyph { name: modelData; size: 20; color: Tokens.textPrimary }
                }
            }
            ColumnLayout {
                objectName: "col760"
                Layout.leftMargin: 32
                Layout.preferredWidth: 760
                Layout.fillWidth: false
                SettingsGroup {
                    objectName: "grp"
                    title: "Details"
                    SettingRow {
                        label: "Display name"
                        hint: "Shown instead of @admin."
                        UiField { fieldWidth: 288; placeholder: "admin" }
                        Text { text: "0/40"; color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: 10 }
                    }
                    SettingRow {
                        label: "Update AniList when I finish an episode"
                        hint: "Advances entries you already track. Never lowers progress."
                        UiSwitch { checked: true }
                    }
                    SettingRow {
                        label: "Session"
                        hint: "Signs out of this app only."
                        UiButton { text: "Sign out"; variant: "ghost"; size: "sm"; icon: "log-out" }
                    }
                }
            }
            Item { Layout.preferredHeight: 24 }
        }
    }

    function test_primitives() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        wait(600);
        grabImage(host).save(shotsDir + "/primitives.png");
    }
}
