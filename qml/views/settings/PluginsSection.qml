import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/plugins (admin, DD-028): each server job and the plugin
// doing it, with a Replace dialog (order, add, remove) that confirms and
// sends the cached generation so a concurrent change is never overwritten.
SettingsPage {
    id: page
    readonly property var purposes: ({
        "lain.source.enumerate": qsTr("Reads the library folders and lists the video files it finds."),
        "lain.media.identify": qsTr("Turns a filename and path into a title, season and episode."),
        "lain.ingest.scan": qsTr("Walks every library root and updates the catalog."),
        "lain.search.query": qsTr("Answers searches over this server’s catalog."),
        "lain.catalog.read": qsTr("Serves the catalog to the app: lists, rails and item pages."),
        "lain.catalog.write": qsTr("Stores items in the catalog and retires the ones that are gone."),
        "lain.userstate.progress": qsTr("Remembers where you stopped watching each item."),
        "lain.media.probe": qsTr("Reads technical stream details: codecs, tracks, dimensions."),
        "lain.playback.plan": qsTr("Decides whether a file plays directly or has to be converted."),
        "lain.playback.transcode": qsTr("Converts a file a client cannot play and serves the stream."),
        "lain.metadata.search": qsTr("Searches an external metadata source for a matching title."),
        "lain.metadata.resolve": qsTr("Fetches the posters, synopsis and year shown on item pages."),
        "lain.transform.thumbnail": qsTr("Extracts the still frames used as thumbnails and placeholders.")
    })
    property var target: null
    property var draft: []
    readonly property bool exactlyOne: target && target.mode === "exactly-one"

    function shortCap(cap) { var at = String(cap).indexOf("@"); return at < 0 ? cap : cap.substring(0, at); }
    function purposeOf(cap) { return purposes[shortCap(cap)] || ""; }
    function info(id) {
        var infos = server.pluginInfo || [];
        for (var i = 0; i < infos.length; ++i)
            if (infos[i].id === id)
                return infos[i];
        return null;
    }
    function healthy(id) { var i = info(id); return !i || i.healthy !== false; }
    function available() {
        if (!target)
            return [];
        var infos = server.pluginInfo || [];
        return infos.filter(i => (i.capabilities || []).indexOf(target.capability) >= 0 && draft.indexOf(i.id) < 0);
    }
    function move(i, d) {
        var next = draft.slice();
        var j = i + d;
        if (j < 0 || j >= next.length)
            return;
        var t = next[i]; next[i] = next[j]; next[j] = t;
        draft = next;
    }
    function openSwap(binding) {
        target = binding;
        draft = (binding.providers || []).slice();
        swapModal.open();
    }

    Text {
        Layout.fillWidth: true
        Layout.maximumWidth: 720
        text: qsTr("Each row is one job this server does — reading folders, identifying files, storing items, serving playback — and the plugin currently doing it. Replacing is safe: the change is refused if the new plugin is unhealthy, and a plugin that fails later falls back to the one that worked.")
        color: Tokens.textTertiary
        font.family: Tokens.fontSans
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }

    SettingsGroup {
        anchorId: "capabilities"
        title: qsTr("Capabilities")
        Text {
            Layout.topMargin: 12
            visible: (server.composition || []).length === 0
            text: qsTr("No plugins reported.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        Repeater {
            model: server.composition || []
            delegate: ColumnLayout {
                id: binding
                required property var modelData
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    spacing: 12
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            text: page.purposeOf(binding.modelData.capability)
                            color: Tokens.textPrimary
                            font.family: Tokens.fontSans
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            text: binding.modelData.capability
                            color: Tokens.textTertiary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 12
                        }
                        RowLayout {
                            Layout.topMargin: 4
                            spacing: 8
                            UiBadge {
                                text: binding.modelData.mode
                                tone: binding.modelData.mode === "exactly-one" ? "neutral" : binding.modelData.mode === "fan-out" ? "warning" : "accent"
                            }
                            Text {
                                text: qsTr("generation %1").arg(binding.modelData.generation)
                                color: Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                            }
                        }
                    }
                    UiButton {
                        text: qsTr("Replace")
                        variant: "secondary"
                        size: "sm"
                        Accessible.name: qsTr("Replace providers for %1").arg(binding.modelData.capability)
                        onClicked: page.openSwap(binding.modelData)
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    Layout.bottomMargin: 16
                    spacing: 6
                    Repeater {
                        model: binding.modelData.providers || []
                        delegate: Rectangle {
                            required property string modelData
                            required property int index
                            implicitHeight: 26
                            implicitWidth: chip.implicitWidth + 24
                            radius: 13
                            color: Tokens.surface1
                            border.color: Tokens.hairline
                            RowLayout {
                                id: chip
                                anchors.centerIn: parent
                                spacing: 6
                                Text {
                                    visible: binding.modelData.mode !== "exactly-one" && (binding.modelData.providers || []).length > 1
                                    text: String(index + 1)
                                    color: Tokens.textTertiary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 11
                                }
                                Text { text: modelData; color: Tokens.textPrimary; font.family: Tokens.fontFamily; font.pixelSize: 11 }
                                Rectangle {
                                    implicitWidth: 6; implicitHeight: 6; radius: 3
                                    color: page.healthy(modelData) ? Tokens.success : Tokens.danger
                                }
                            }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
            }
        }
    }

    UiModal {
        id: swapModal
        title: qsTr("Replace providers")
        description: page.target ? page.target.capability + " · " + page.target.mode + " · " + qsTr("generation %1").arg(page.target.generation) : ""
        Text {
            text: page.exactlyOne ? qsTr("Choose the single provider") : qsTr("Serving order")
            color: Tokens.textSecondary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Text {
            visible: page.draft.length === 0
            text: qsTr("Pick at least one provider below.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        Repeater {
            model: page.draft
            delegate: Rectangle {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Math.max(4, Tokens.radiusSm + 2)
                color: Tokens.surface1
                border.color: Tokens.hairline
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4
                    spacing: 8
                    Text { text: String(index + 1); color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: 12 }
                    Text { Layout.fillWidth: true; text: modelData; color: Tokens.textPrimary; font.family: Tokens.fontFamily; font.pixelSize: 13; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: page.healthy(modelData) ? Tokens.success : Tokens.danger }
                    UiButton { visible: !page.exactlyOne; icon: "arrow-up"; variant: "ghost"; size: "sm"; implicitWidth: 32; enabled: index > 0; Accessible.name: qsTr("Move %1 up").arg(modelData); onClicked: page.move(index, -1) }
                    UiButton { visible: !page.exactlyOne; icon: "chevron-down"; variant: "ghost"; size: "sm"; implicitWidth: 32; enabled: index < page.draft.length - 1; Accessible.name: qsTr("Move %1 down").arg(modelData); onClicked: page.move(index, 1) }
                    UiButton {
                        icon: "x"; variant: "ghost"; size: "sm"; implicitWidth: 32
                        Accessible.name: qsTr("Remove %1").arg(modelData)
                        onClicked: { var n = page.draft.slice(); n.splice(index, 1); page.draft = n; }
                    }
                }
            }
        }
        Text {
            Layout.topMargin: 6
            text: qsTr("Available for this capability")
            color: Tokens.textSecondary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            font.weight: Font.Medium
        }
        Text {
            visible: page.available().length === 0
            text: qsTr("Every registered candidate is already selected.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        Repeater {
            model: page.available()
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 40
                radius: Math.max(4, Tokens.radiusSm + 2)
                color: "transparent"
                border.color: Tokens.hairline
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 4
                    spacing: 8
                    Text { Layout.fillWidth: true; text: modelData.id; color: Tokens.textPrimary; font.family: Tokens.fontFamily; font.pixelSize: 13; elide: Text.ElideRight }
                    Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: modelData.healthy !== false ? Tokens.success : Tokens.danger }
                    UiButton {
                        text: page.exactlyOne ? qsTr("Select") : qsTr("Add")
                        icon: page.exactlyOne ? "" : "plus"
                        variant: "ghost"
                        size: "sm"
                        onClicked: {
                            if (page.exactlyOne)
                                page.draft = [modelData.id];
                            else
                                page.draft = page.draft.concat([modelData.id]);
                        }
                    }
                }
            }
        }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: swapModal.close() },
            UiButton {
                text: qsTr("Apply generation %1").arg(page.target ? page.target.generation + 1 : "")
                enabled: page.draft.length > 0 && page.target
                         && JSON.stringify(page.draft) !== JSON.stringify(page.target.providers || [])
                onClicked: {
                    server.swapProviders(page.target.capability, page.draft);
                    swapModal.close();
                }
            }
        ]
    }
}
