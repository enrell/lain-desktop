import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Web /list (server D-078): everything linked accounts track, filtered by
// media type and status. The server applies the filters.
ColumnLayout {
    id: root
    signal openConnections()
    spacing: 24

    property string typeFilter: String(server.pref("list/type", ""))
    property string statusFilter: String(server.pref("list/status", ""))
    readonly property var entries: server.listEntries || []
    property bool loadedOnce: false

    function reload() {
        loadedOnce = true;
        server.loadList(typeFilter, statusFilter);
    }
    onVisibleChanged: if (visible && server.ready) reload()
    Connections {
        target: server
        function onStateChanged() { if (root.visible && server.ready) root.reload(); }
    }

    readonly property int margin: Math.max(Tokens.pageMargin, (width - Tokens.contentWidth) / 2 + Tokens.pageMargin)

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: root.margin
        Layout.rightMargin: root.margin
        Layout.topMargin: 40
        spacing: 4
        Text {
            objectName: "listTitle"
            text: qsTr("My list")
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: 22
            font.weight: Font.DemiBold
            font.letterSpacing: -0.4
        }
        Text {
            Layout.fillWidth: true
            text: qsTr("Everything your connected accounts track — manga, comics, anime, movies and series in one place.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
    }

    Flow {
        Layout.fillWidth: true
        Layout.leftMargin: root.margin
        Layout.rightMargin: root.margin
        spacing: 8
        Repeater {
            model: [
                { id: "", label: qsTr("All") }, { id: "anime", label: qsTr("Anime") },
                { id: "manga", label: qsTr("Manga") }, { id: "movie", label: qsTr("Movies") },
                { id: "series", label: qsTr("Series") }, { id: "comic", label: qsTr("Comics") }
            ]
            delegate: Rectangle {
                id: chip
                required property var modelData
                readonly property bool on: root.typeFilter === modelData.id
                objectName: "listType-" + (modelData.id || "all")
                implicitWidth: chipText.implicitWidth + 26
                implicitHeight: 30
                radius: 15
                color: on ? Tokens.accentSoft : Qt.alpha(Tokens.surface1, 0.6)
                border.color: on ? Tokens.themeAccent : Tokens.hairline
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.checked: on
                function pick() {
                    root.typeFilter = modelData.id;
                    server.setPref("list/type", modelData.id);
                    root.reload();
                }
                Keys.onSpacePressed: pick()
                Keys.onReturnPressed: pick()
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: chip.pick() }
                Text {
                    id: chipText
                    anchors.centerIn: parent
                    text: chip.modelData.label
                    color: chip.on ? Tokens.textPrimary : Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }
        Item {
            width: 9
            height: 30
            Rectangle { anchors.centerIn: parent; width: 1; height: 16; color: Tokens.hairline }
        }
        UiSelect {
            implicitWidth: 150
            implicitHeight: 30
            label: qsTr("Status")
            model: [
                { id: "", label: qsTr("Any status") }, { id: "current", label: qsTr("Current") },
                { id: "planning", label: qsTr("Planning") }, { id: "completed", label: qsTr("Completed") },
                { id: "paused", label: qsTr("Paused") }, { id: "dropped", label: qsTr("Dropped") },
                { id: "repeating", label: qsTr("Repeating") }
            ]
            current: root.statusFilter
            onPicked: id => {
                root.statusFilter = id;
                server.setPref("list/status", id);
                root.reload();
            }
        }
    }

    // Error, loading, empty, grid — only one renders.
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: root.margin
        Layout.rightMargin: root.margin
        visible: server.listError !== ""
        spacing: 10
        Text { Layout.fillWidth: true; text: server.listError; color: Tokens.danger; font.family: Tokens.fontSans; font.pixelSize: 14; wrapMode: Text.WordWrap }
        UiButton { text: qsTr("Try again"); variant: "secondary"; size: "sm"; onClicked: root.reload() }
    }
    UiSpinner {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: 40
        visible: server.listLoading && root.entries.length === 0
        size: 22
    }
    ColumnLayout {
        objectName: "listEmpty"
        Layout.fillWidth: true
        Layout.topMargin: 48
        visible: !server.listLoading && server.listError === "" && root.entries.length === 0 && root.loadedOnce
        spacing: 10
        Glyph { Layout.alignment: Qt.AlignHCenter; name: "list"; size: 28; color: Tokens.textTertiary }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: qsTr("Nothing on your list yet")
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: 17
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 460
            horizontalAlignment: Text.AlignHCenter
            text: qsTr("Connect an account in Settings › Connections to import what you track. AniList is supported today.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 14
            wrapMode: Text.WordWrap
        }
        UiButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            text: qsTr("Open connections")
            variant: "secondary"
            size: "sm"
            onClicked: root.openConnections()
        }
    }
    GridLayout {
        id: grid
        objectName: "listGrid"
        Layout.fillWidth: true
        Layout.leftMargin: root.margin
        Layout.rightMargin: root.margin
        visible: root.entries.length > 0
        readonly property int cell: Tokens.posterWidth + Tokens.cardGap
        columns: Math.max(2, Math.floor((root.width - 2 * root.margin + Tokens.cardGap) / cell))
        columnSpacing: Tokens.cardGap
        rowSpacing: 24
        Repeater {
            model: root.entries
            delegate: ListEntryCard {
                required property var modelData
                entry: modelData
                Layout.preferredWidth: Tokens.posterWidth
            }
        }
    }
    Item { Layout.preferredHeight: 48 }
}
