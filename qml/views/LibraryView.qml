import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Web-parity library: single page with library filter + sort, a Shows
// section of series cards, a singles poster grid, and collections as an
// in-page section. Series hierarchy (DD-030) opens on the series route.
ColumnLayout {
    id: root
    property var items: server.catalog || []
    property var seriesModel: server.series || []
    property var collections: server.collections || []
    property var libraries: server.libraries || []
    signal openMedia(var media)
    signal openSeries(var series)

    property string selectedLibrary: ""
    property string sortMode: "title" // title | recent

    // A show card only exists when several files share a title; a lone
    // episode stays a single like the web's group.count === 1 rule.
    function seriesItemCount(s) {
        return (s.episodeCount || 0) + (s.specialsCount || 0);
    }

    function seriesFirstItem(s) {
        if (s.seasons && s.seasons.length > 0 && s.seasons[0].episodes.length > 0)
            return s.seasons[0].episodes[0];
        if (s.specials && s.specials.length > 0)
            return s.specials[0];
        return null;
    }

    readonly property var showsList: {
        var out = [];
        var list = seriesModel || [];
        for (var i = 0; i < list.length; ++i) {
            var s = list[i];
            if (selectedLibrary !== "" && s.library_id !== selectedLibrary)
                continue;
            if (seriesItemCount(s) > 1)
                out.push(s);
        }
        if (sortMode === "title")
            out.sort(function (a, b) { return String(a.title).localeCompare(String(b.title)); });
        else
            out.sort(function (a, b) {
                var fa = seriesFirstItem(a), fb = seriesFirstItem(b);
                return Number(fb ? fb.updated_at : 0) - Number(fa ? fa.updated_at : 0);
            });
        return out;
    }

    readonly property var singlesList: {
        var seriesIds = {};
        var sl = showsList;
        for (var i = 0; i < sl.length; ++i)
            seriesIds[sl[i].id] = true;
        var out = [];
        var list = items || [];
        for (var j = 0; j < list.length; ++j) {
            var it = list[j];
            if (selectedLibrary !== "" && it.library_id !== selectedLibrary)
                continue;
            var sid = it.series_id;
            if (sid && seriesIds[sid])
                continue; // member of a multi-episode show card
            out.push(it);
        }
        if (sortMode === "title")
            out.sort(function (a, b) {
                var ta = a.displayTitle && a.displayTitle !== "" ? a.displayTitle : a.title;
                var tb = b.displayTitle && b.displayTitle !== "" ? b.displayTitle : b.title;
                return String(ta).localeCompare(String(tb));
            });
        else
            out.sort(function (a, b) { return Number(b.updated_at) - Number(a.updated_at); });
        return out;
    }

    readonly property var libraryOptions: {
        var out = [{ id: "", label: qsTr("All libraries") }];
        var libs = libraries || [];
        for (var i = 0; i < libs.length; ++i)
            out.push({ id: libs[i].id, label: libs[i].name });
        return out;
    }

    readonly property string countsLine: {
        var total = items ? items.length : 0;
        var seg = [total === 1 ? qsTr("1 item") : qsTr("%1 items").arg(total)];
        if (showsList.length > 0)
            seg.push(showsList.length === 1 ? qsTr("1 show") : qsTr("%1 shows").arg(showsList.length));
        if (singlesList.length > 0)
            seg.push(singlesList.length === 1 ? qsTr("1 title") : qsTr("%1 titles").arg(singlesList.length));
        return seg.join("  ·  ");
    }

    readonly property var filteredCollections: {
        if (selectedLibrary === "")
            return collections || [];
        var out = [];
        var cols = collections || [];
        for (var i = 0; i < cols.length; ++i) {
            var row = { title: cols[i].title, items: [] };
            var its = cols[i].items || [];
            for (var j = 0; j < its.length; ++j)
                if (its[j].library_id === selectedLibrary)
                    row.items.push(its[j]);
            if (row.items.length > 0)
                out.push(row);
        }
        return out;
    }

    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        Layout.rightMargin: Layout.leftMargin
        Layout.topMargin: 16
        Layout.bottomMargin: Tokens.sectionGap
        spacing: 20

        // Header: title + muted subheading like the web library page.
        ColumnLayout {
            spacing: 4
            Text {
                text: qsTr("Library")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.pageTitleSize - 6
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
            }
            Text {
                text: qsTr("Shows open their own page with every episode; single files play from their item page.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
            }
        }

        // Filter row: counts left, library + sort selects right.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: countsLine
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
            }
            LibrarySelect {
                model: libraryOptions
                current: selectedLibrary
                onPicked: id => selectedLibrary = id
            }
            LibrarySelect {
                model: [
                    { id: "title", label: qsTr("Title A–Z") },
                    { id: "recent", label: qsTr("Recently indexed") }
                ]
                current: sortMode
                onPicked: id => sortMode = id
            }
        }

        // Shows section: one poster card per multi-episode series.
        ColumnLayout {
            Layout.fillWidth: true
            visible: showsList.length > 0
            spacing: 14
            Text {
                text: qsTr("Shows")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Grid {
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor((width + 12) / (Tokens.posterWidth + 12)))
                columnSpacing: 12
                rowSpacing: 20
                Repeater {
                    objectName: "showsRepeater"
                    model: showsList
                    delegate: ShowCard {
                        series: modelData
                        onOpen: s => openSeries(s)
                    }
                }
            }
        }

        // Singles section: movies, lone episodes, and specials.
        ColumnLayout {
            Layout.fillWidth: true
            visible: singlesList.length > 0
            spacing: 14
            Text {
                visible: showsList.length > 0
                text: qsTr("Movies & specials")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Grid {
                Layout.fillWidth: true
                columns: Math.max(2, Math.floor((width + 12) / (Tokens.posterWidth + 12)))
                columnSpacing: 12
                rowSpacing: 20
                Repeater {
                    model: singlesList
                    delegate: PosterCard {
                        media: modelData
                        onOpen: m => openMedia(m)
                    }
                }
            }
        }

        // Collections demoted to an in-library section (advisor: no nav item).
        ColumnLayout {
            Layout.fillWidth: true
            visible: filteredCollections.length > 0
            spacing: 14
            Text {
                text: qsTr("Collections")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Repeater {
                model: filteredCollections
                delegate: MediaRow {
                    Layout.fillWidth: true
                    title: modelData.title
                    rowHeight: Tokens.posterWidth * 1.5 + 46
                    model: modelData.items
                    delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
                }
            }
        }

        Text {
            Layout.topMargin: 16
            visible: showsList.length === 0 && singlesList.length === 0
            text: items && items.length === 0
                ? qsTr("Nothing indexed here yet. Run a scan from server settings.")
                : qsTr("Nothing matches this filter.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.bodySize
        }
    }
}
