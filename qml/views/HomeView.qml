import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Web-parity home: full-width monolith hero, then horizontal rows —
// continue watching, recently added, and one row per library (when the
// server has more than one).
ColumnLayout {
    id: root
    property var home
    property var libraries: server.libraries || []
    property var catalog: server.catalog || []
    signal openMedia(var media)
    signal playMedia(var media)
    signal openLibrary(string libraryId)
    signal openSettings(string section, string anchor)
    spacing: Tokens.sectionGap

    readonly property var continueRow: home && home.continueWatching ? home.continueWatching : []
    readonly property var recentRow: home && home.recentlyAdded ? home.recentlyAdded : []
    readonly property var readingRow: home && home.continueReading ? home.continueReading : []
    readonly property var nextUpRow: home && home.nextUp ? home.nextUp : []
    readonly property var readNextRow: home && home.readNext ? home.readNext : []
    readonly property bool empty: continueRow.length === 0 && recentRow.length === 0
    readonly property bool admin: server.ready && server.role === "admin"
    readonly property bool scanning: server.scanState && server.scanState.state === "running"
    // Web home empty states: no library configured, or configured but unscanned.
    readonly property string emptyKind: !empty ? "" : (libraries.length === 0 ? "nolibrary" : "unscanned")
    readonly property var heroMedia: continueRow.length > 0 ? continueRow[0] : (recentRow.length > 0 ? recentRow[0] : null)
    readonly property var upNextMedia: {
        if (!heroMedia)
            return null;
        for (var i = 0; i < continueRow.length; ++i)
            if (continueRow[i].id !== heroMedia.id)
                return continueRow[i];
        return null;
    }

    // One row per library (max 4), first 12 catalog items each — same rule
    // as the web home, computed client-side from the already-loaded catalog.
    readonly property var libraryRows: {
        var libs = libraries || [];
        if (libs.length <= 1)
            return [];
        var out = [];
        for (var i = 0; i < libs.length && out.length < 4; ++i) {
            var lib = libs[i];
            var items = [];
            for (var j = 0; j < catalog.length && items.length < 12; ++j) {
                var it = catalog[j];
                if (it.library_id === lib.id)
                    items.push(it);
            }
            if (items.length > 0)
                out.push({ id: lib.id, name: lib.name, type: lib.type, items: items });
        }
        return out;
    }

    function libraryTypeIsMovie(t) {
        var s = String(t || "").toLowerCase();
        return s.indexOf("movie") >= 0 || s.indexOf("film") >= 0;
    }

    Hero {
        Layout.fillWidth: true
        visible: heroMedia !== null
        media: heroMedia
        resume: continueRow.length > 0 && heroMedia
            && heroMedia.id === continueRow[0].id && heroMedia.progress > 0
        upNext: upNextMedia
        onPlay: m => playMedia(m)
        onMoreInfo: m => openMedia(m)
        onPlayUpNext: m => playMedia(m)
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        Layout.rightMargin: Layout.leftMargin
        spacing: Tokens.sectionGap - 4

        MediaRow {
            Layout.fillWidth: true
            visible: continueRow.length > 0
            objectName: "continueRow"
            title: qsTr("Continue watching")
            actionLabel: qsTr("Open library")
            onAction: openLibrary("")
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 46
            model: continueRow
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }
        Row {
            visible: root.scanning || (server.scanState && server.scanState.state === "error")
            spacing: 8
            UiBadge {
                text: root.scanning ? qsTr("Scanning…") : qsTr("Last scan failed")
                tone: root.scanning ? "accent" : "danger"
            }
        }
        MediaRow {
            Layout.fillWidth: true
            visible: readingRow.length > 0
            objectName: "readingRow"
            title: qsTr("Continue reading")
            actionLabel: qsTr("Open library")
            onAction: openLibrary("")
            rowHeight: Tokens.posterWidth * 1.5 + 46
            model: readingRow
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }
        MediaRow {
            Layout.fillWidth: true
            visible: nextUpRow.length > 0
            objectName: "nextUpRow"
            title: qsTr("Next up")
            actionLabel: qsTr("Open library")
            onAction: openLibrary("")
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 46
            model: nextUpRow
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }
        MediaRow {
            Layout.fillWidth: true
            visible: readNextRow.length > 0
            objectName: "readNextRow"
            title: qsTr("Read next")
            actionLabel: qsTr("Open library")
            onAction: openLibrary("")
            rowHeight: Tokens.posterWidth * 1.5 + 46
            model: readNextRow
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }
        MediaRow {
            Layout.fillWidth: true
            visible: recentRow.length > 0
            objectName: "recentRow"
            title: qsTr("Recently added")
            actionLabel: qsTr("View all")
            onAction: openLibrary("")
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 46
            model: recentRow
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }
        Repeater {
            model: libraryRows
            delegate: MediaRow {
                Layout.fillWidth: true
                title: modelData.name
                actionLabel: qsTr("View all")
                onAction: openLibrary(modelData.id)
                rowHeight: libraryTypeIsMovie(modelData.type)
                    ? Tokens.posterWidth * 1.5 + 46
                    : Tokens.landscapeWidth * 9 / 16 + 46
                model: modelData.items
                delegate: libraryTypeIsMovie(modelData.type) ? posterDelegate : landscapeDelegate
            }
        }
    }

    Component {
        id: posterDelegate
        PosterCard { media: modelData; onOpen: m => openMedia(m) }
    }
    Component {
        id: landscapeDelegate
        LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
    }

    ColumnLayout {
        objectName: "homeEmpty"
        Layout.fillWidth: true
        Layout.topMargin: 96
        Layout.bottomMargin: Tokens.sectionGap
        visible: empty
        spacing: 10
        Glyph {
            Layout.alignment: Qt.AlignHCenter
            name: root.emptyKind === "nolibrary" ? "film" : "scan"
            size: 28
            color: Tokens.textTertiary
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.emptyKind === "nolibrary" ? qsTr("No media yet") : qsTr("Library hasn't been scanned")
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 520
            horizontalAlignment: Text.AlignHCenter
            text: root.emptyKind === "nolibrary"
                  ? (root.admin ? qsTr("Point Lain at a directory on this server and run a scan. Files stay where they are.")
                                : qsTr("An administrator has not configured a library yet."))
                  : qsTr("Libraries are configured, but no media has been indexed yet.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.bodySize
            wrapMode: Text.WordWrap
        }
        UiButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 8
            visible: root.admin
            text: root.emptyKind === "nolibrary" ? qsTr("Add a library") : qsTr("Scan now")
            icon: root.emptyKind === "nolibrary" ? "folder-plus" : "scan"
            loading: root.scanning
            onClicked: {
                if (root.emptyKind === "nolibrary")
                    root.openSettings("libraries", "add");
                else
                    server.triggerScan();
            }
        }
    }

    Item { Layout.fillWidth: true; height: 24 }
}
