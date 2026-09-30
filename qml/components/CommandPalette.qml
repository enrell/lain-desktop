import QtQuick
import QtQuick.Layouts
import Lain

// Ctrl+K launcher (web CommandPalette.svelte): common actions, pages,
// every Settings section and row (English keyword aliases work in every
// language), and library titles. ↑↓ or Ctrl+N/P move, Enter runs, Esc closes.
Item {
    id: root
    visible: false
    z: 2500
    anchors.fill: parent

    signal navigate(string route)
    signal openSettings(string section, string anchor)
    signal openMedia(var media)

    property int active: 0
    readonly property bool admin: server.ready && server.role === "admin"

    function open() {
        field.text = "";
        active = 0;
        visible = true;
        field.forceActiveFocus();
    }
    function close() { visible = false; }

    readonly property var settingEntries: [
        { label: qsTr("Display name"), section: "profile", anchor: "display-name", keywords: "nickname name profile" },
        { label: qsTr("Bio"), section: "profile", anchor: "bio", keywords: "about description profile" },
        { label: qsTr("Avatar"), section: "profile", anchor: "avatar", keywords: "picture photo mascot icon profile" },
        { label: qsTr("Interface language"), section: "profile", anchor: "interface", keywords: "language locale idioma translation i18n interface" },
        { label: qsTr("Sign out"), section: "profile", anchor: "account", keywords: "logout log out session" },
        { label: qsTr("Resume and autoplay"), section: "playback", anchor: "playing", keywords: "resume autoplay next episode continue" },
        { label: qsTr("Audio & subtitle language"), section: "playback", anchor: "language", keywords: "idioma audio subtitle captions language dub" },
        { label: qsTr("Video effects"), section: "playback", anchor: "effects", keywords: "anime4k upscale shader effect mpv" },
        { label: "AniList", section: "connections", anchor: "anilist", keywords: "anilist list sync scrobble tracker connect" },
        { label: qsTr("Change password"), section: "security", anchor: "password", keywords: "password security credentials" },
        { label: qsTr("Server connection"), section: "desktop", anchor: "server", keywords: "server url reconnect offline queue" },
        { label: qsTr("Automatic metadata"), section: "desktop", anchor: "metadata", keywords: "enrich metadata auto provider" },
        { label: qsTr("Appearance"), section: "desktop", anchor: "appearance", keywords: "theme omarchy palette color" },
        { label: qsTr("App updates"), section: "desktop", anchor: "about", keywords: "update version about build" },
        { label: qsTr("Libraries"), section: "libraries", anchor: "libraries", keywords: "folder path library add remove root", admin: true },
        { label: qsTr("Scan"), section: "libraries", anchor: "scan", keywords: "scan rescan index refresh", admin: true },
        { label: qsTr("Users"), section: "users", anchor: "users", keywords: "accounts roles admin disable reset password", admin: true },
        { label: qsTr("Transcoding mode"), section: "transcoding", anchor: "mode", keywords: "auto custom policy transcode", admin: true },
        { label: qsTr("Delivery"), section: "transcoding", anchor: "delivery", keywords: "hls segment timeout throttle progressive delivery stream", admin: true },
        { label: qsTr("Encoding"), section: "transcoding", anchor: "encoding", keywords: "crf preset hevc av1 h264 quality bitrate deinterlace", admin: true },
        { label: qsTr("Hardware acceleration"), section: "transcoding", anchor: "hardware", keywords: "gpu vaapi nvenc qsv hardware decode encode", admin: true },
        { label: qsTr("HDR processing"), section: "transcoding", anchor: "processing", keywords: "hdr tone mapping luminance", admin: true },
        { label: qsTr("Audio & subtitles"), section: "transcoding", anchor: "audio", keywords: "audio bitrate downmix subtitle burn font", admin: true },
        { label: qsTr("Resources"), section: "transcoding", anchor: "resources", keywords: "cache threads queue storage path ffmpeg", admin: true },
        { label: qsTr("Transcode sessions"), section: "transcoding", anchor: "sessions", keywords: "sessions running jobs cancel", admin: true },
        { label: qsTr("Integrations"), section: "integrations", anchor: "integrations", keywords: "oauth client id secret anilist", admin: true },
        { label: qsTr("Plugins"), section: "plugins", anchor: "capabilities", keywords: "plugin provider capability composition replace", admin: true },
        { label: qsTr("Backup"), section: "backup", anchor: "backup", keywords: "backup snapshot database export", admin: true }
    ]
    readonly property var sectionNames: ({
        "profile": qsTr("Profile"), "playback": qsTr("Playback"), "connections": qsTr("Connections"),
        "security": qsTr("Security"), "desktop": qsTr("Desktop"), "libraries": qsTr("Libraries"),
        "users": qsTr("Users"), "transcoding": qsTr("Transcoding"), "integrations": qsTr("Integrations"),
        "plugins": qsTr("Plugins"), "backup": qsTr("Backup")
    })
    readonly property var sectionKeys: ({
        "profile": "gp", "playback": "gy", "connections": "gc", "security": "gs", "desktop": "gd",
        "libraries": "gl", "users": "gu", "transcoding": "gt", "integrations": "gi", "plugins": "gx", "backup": "gb"
    })
    readonly property var serverSections: ["libraries", "users", "transcoding", "integrations", "plugins", "backup"]

    function staticCommands() {
        var out = [];
        if (admin) {
            out.push({ group: "actions", label: qsTr("Scan libraries now"), detail: qsTr("Walk every library root"), run: () => server.triggerScan() });
            out.push({ group: "actions", label: qsTr("Add a library"), run: () => root.openSettings("libraries", "add") });
            out.push({ group: "actions", label: qsTr("Add a user"), run: () => root.openSettings("users", "add") });
            out.push({ group: "actions", label: qsTr("Download a backup"), run: () => root.openSettings("backup", "backup") });
        }
        out.push({ group: "actions", label: qsTr("Sign out"), run: () => server.logout() });
        var pages = [["home", qsTr("Home"), "gh"], ["library", qsTr("Library"), "gl"], ["list", qsTr("My list"), "gm"], ["search", qsTr("Search"), "gs"]];
        for (var i = 0; i < pages.length; ++i) {
            let p = pages[i];
            out.push({ group: "goTo", label: p[1], keys: p[2], run: () => root.navigate(p[0]) });
        }
        for (var id in sectionNames) {
            if (!admin && serverSections.indexOf(id) >= 0)
                continue;
            let sid = id;
            out.push({ group: "goTo", label: qsTr("Settings › %1").arg(sectionNames[id]), keys: sectionKeys[id], run: () => root.openSettings(sid, "") });
        }
        for (var j = 0; j < settingEntries.length; ++j) {
            let e = settingEntries[j];
            if (e.admin && !admin)
                continue;
            out.push({ group: "settings", label: e.label, detail: sectionNames[e.section], keywords: e.keywords,
                       run: () => root.openSettings(e.section, e.anchor) });
        }
        return out;
    }

    // Web fuzzyScore: every query word must appear; earlier and
    // word-initial hits rank higher.
    function score(query, text) {
        var words = query.toLowerCase().split(/\s+/).filter(w => w !== "");
        if (words.length === 0)
            return 1;
        var t = text.toLowerCase();
        var total = 0;
        for (var i = 0; i < words.length; ++i) {
            var at = t.indexOf(words[i]);
            if (at < 0)
                return 0;
            var initial = at === 0 || /[\s(›\/-]/.test(t.charAt(at - 1));
            total += 100 - Math.min(at, 90) + (initial ? 50 : 0);
        }
        return total;
    }

    readonly property var results: {
        if (!visible)
            return [];
        var q = field.text.trim();
        var cmds = staticCommands();
        var ranked;
        if (q === "") {
            ranked = cmds.filter(c => c.group !== "settings").slice(0, 14);
        } else {
            ranked = cmds.map(c => ({ c: c, s: score(q, [c.label, c.detail || "", c.keywords || ""].join(" ")) }))
                         .filter(r => r.s > 0)
                         .sort((a, b) => b.s - a.s)
                         .slice(0, 12)
                         .map(r => r.c);
            // One entry per title: a series has many files but one page.
            var seen = {};
            var catalog = server.catalog || [];
            var titles = [];
            for (var i = 0; i < catalog.length && titles.length < 5; ++i) {
                var m = catalog[i];
                var name = m.displayTitle || m.title;
                var key = String(m.title).toLowerCase();
                if (seen[key] || score(q, name + " " + m.title) === 0)
                    continue;
                seen[key] = true;
                let media = m;
                titles.push({ group: "titles", label: name, detail: m.library || m.kind, run: () => root.openMedia(media) });
            }
            ranked = ranked.concat(titles);
        }
        var order = ["actions", "goTo", "settings", "titles"];
        return ranked.sort((a, b) => order.indexOf(a.group) - order.indexOf(b.group));
    }
    onResultsChanged: active = Math.min(active, Math.max(0, results.length - 1))

    function runActive() {
        var cmd = results[active];
        if (!cmd)
            return;
        close();
        cmd.run();
    }
    function groupLabel(g) {
        return g === "actions" ? qsTr("Actions") : g === "goTo" ? qsTr("Go to") : g === "settings" ? qsTr("Settings") : qsTr("Titles");
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha("#000000", 0.6)
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }
    Rectangle {
        id: card
        objectName: "paletteCard"
        width: Math.min(640, root.width - 48)
        height: Math.min(col.implicitHeight, root.height * 0.7)
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(48, root.height * 0.14)
        radius: Tokens.radiusLg
        color: Tokens.bgSecondary
        border.color: Tokens.borderSubtle
        clip: true
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.margins: 14
                spacing: 10
                Glyph { name: "search"; size: 16; color: Tokens.textTertiary }
                TextInput {
                    id: field
                    objectName: "paletteInput"
                    property bool acceptsText: true
                    Layout.fillWidth: true
                    color: Tokens.textPrimary
                    font.family: Tokens.fontSans
                    font.pixelSize: 15
                    selectionColor: Qt.alpha(Tokens.themeAccent, 0.32)
                    Accessible.role: Accessible.EditableText
                    Accessible.name: qsTr("Search commands, settings and titles")
                    Keys.onEscapePressed: root.close()
                    Keys.onReturnPressed: root.runActive()
                    Keys.onEnterPressed: root.runActive()
                    Keys.onDownPressed: root.active = Math.min(root.results.length - 1, root.active + 1)
                    Keys.onUpPressed: root.active = Math.max(0, root.active - 1)
                    Keys.onPressed: event => {
                        if (event.modifiers & Qt.ControlModifier) {
                            if (event.key === Qt.Key_N) { root.active = Math.min(root.results.length - 1, root.active + 1); event.accepted = true; }
                            else if (event.key === Qt.Key_P) { root.active = Math.max(0, root.active - 1); event.accepted = true; }
                        }
                    }
                    Text {
                        visible: field.text === ""
                        text: qsTr("Search commands, settings and titles…")
                        color: Tokens.textTertiary
                        font: field.font
                    }
                }
                Text { text: "ESC"; color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: 10 }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
            Text {
                Layout.margins: 16
                visible: root.results.length === 0
                text: qsTr("No matches.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 13
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 6
                spacing: 0
                Repeater {
                    model: root.results
                    delegate: ColumnLayout {
                        id: rowItem
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spacing: 0
                        Text {
                            visible: rowItem.index === 0 || root.results[rowItem.index - 1].group !== rowItem.modelData.group
                            Layout.leftMargin: 10
                            Layout.topMargin: rowItem.index === 0 ? 4 : 10
                            Layout.bottomMargin: 4
                            text: root.groupLabel(rowItem.modelData.group).toUpperCase()
                            color: Tokens.textTertiary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 2
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 36
                            radius: Math.max(4, Tokens.radiusSm + 2)
                            color: root.active === rowItem.index ? Tokens.selectedFill : "transparent"
                            HoverHandler { onHoveredChanged: if (hovered) root.active = rowItem.index }
                            TapHandler { onTapped: { root.active = rowItem.index; root.runActive(); } }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 10
                                Text {
                                    text: rowItem.modelData.label
                                    color: Tokens.textPrimary
                                    font.family: Tokens.fontSans
                                    font.pixelSize: 14
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: rowItem.modelData.detail || ""
                                    color: Tokens.textTertiary
                                    font.family: Tokens.fontSans
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    visible: !!rowItem.modelData.keys
                                    text: rowItem.modelData.keys || ""
                                    color: Tokens.textTertiary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
