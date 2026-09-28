import QtQuick
import QtQuick.Layouts
import Lain
import "../components"
import "../theme/Color.js" as Color

// Series title page (web TitleView): backdrop header, poster rail with
// Play/Resume + per-series autoplay toggle + Information panel, then the
// season-filtered episodes grid and an explicit Specials section (DD-030).
ColumnLayout {
    id: root
    property var series
    signal playMedia(var media)
    signal openMedia(var media)
    signal back()
    spacing: 28

    readonly property var seasons: series && series.seasons ? series.seasons : []
    readonly property var specials: series && series.specials ? series.specials : []
    readonly property var allItems: {
        var out = [];
        var sl = seasons;
        for (var i = 0; i < sl.length; ++i) {
            var eps = sl[i].episodes || [];
            for (var j = 0; j < eps.length; ++j)
                out.push(eps[j]);
        }
        var sp = specials;
        for (var k = 0; k < sp.length; ++k)
            out.push(sp[k]);
        return out;
    }
    readonly property var artItem: {
        var items = allItems;
        for (var i = 0; i < items.length; ++i)
            if (items[i].episode > 0)
                return items[i];
        return items.length > 0 ? items[0] : null;
    }
    readonly property string backdrop: {
        if (series && series.cover)
            return series.cover;
        var items = allItems;
        for (var i = 0; i < items.length; ++i)
            if (items[i].cover)
                return items[i].cover;
        return artItem ? (artItem.poster || "") : "";
    }
    readonly property string posterArt: series && series.poster ? series.poster
        : (artItem ? (artItem.poster || artItem.cover || artItem.thumb || "") : "")
    readonly property string synopsis: {
        var items = allItems;
        for (var i = 0; i < items.length; ++i)
            if (items[i].overview)
                return items[i].overview;
        return "";
    }
    readonly property var genreList: {
        var items = allItems;
        for (var i = 0; i < items.length; ++i) {
            if (items[i].genres)
                return String(items[i].genres).split("·").map(function (g) { return g.trim(); }).filter(function (g) { return g !== ""; }).slice(0, 3);
        }
        return [];
    }
    readonly property int totalCount: (series ? (series.episodeCount || 0) : 0) + (series ? (series.specialsCount || 0) : 0)
    readonly property int watchedCount: {
        var items = allItems, n = 0;
        for (var i = 0; i < items.length; ++i)
            if (items[i].completed)
                ++n;
        return n;
    }
    // Resume the first in-progress episode; otherwise play from the top.
    readonly property var resumeTarget: {
        var items = allItems;
        for (var i = 0; i < items.length; ++i) {
            var it = items[i];
            if (!it.missing && !it.completed && it.position_sec >= 5)
                return it;
        }
        for (var j = 0; j < items.length; ++j)
            if (!items[j].missing)
                return items[j];
        return null;
    }
    readonly property bool resuming: resumeTarget && !resumeTarget.completed && resumeTarget.position_sec >= 5
    readonly property string watchedLine: {
        if (resuming) {
            var pct = resumeTarget.duration_sec > 0 ? Math.round(100 * resumeTarget.position_sec / resumeTarget.duration_sec) : 0;
            return qsTr("Up next · %1 · %2% watched").arg(episodeLabel(resumeTarget)).arg(pct);
        }
        var items = allItems, avail = 0;
        for (var i = 0; i < items.length; ++i)
            if (!items[i].missing)
                ++avail;
        if (avail === 0)
            return qsTr("All files missing");
        if (watchedCount > 0)
            return qsTr("%1 of %2 watched").arg(watchedCount).arg(totalCount);
        return qsTr("Not started");
    }
    readonly property string autoplayMode: series ? server.seriesAutoplayMode(series.id) : "default"

    property string seasonFilter: "all"

    function episodeLabel(it) {
        if (!it)
            return "";
        if (it.season > 0 && it.episode > 0)
            return "S" + (it.season < 10 ? "0" : "") + it.season + "E" + (it.episode < 10 ? "0" : "") + it.episode;
        if (it.episode > 0)
            return qsTr("Episode %1").arg(it.episode);
        return qsTr("Special");
    }

    function fmtTime(sec) {
        var s = Math.floor(sec || 0);
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        return (h > 0 ? h + ":" : "") + (h > 0 && m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    function seasonEpisodesVisible(seasonRow) {
        return seasonFilter === "all" || String(seasonRow.season) === seasonFilter;
    }

    // Backdrop header card.
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 300
        radius: Tokens.radiusLg
        clip: true
        color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.03))
        border.color: Qt.alpha(Tokens.themeFg, 0.07)
        Image {
            anchors.fill: parent
            source: root.backdrop
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.1) }
                GradientStop { position: 0.4; color: Qt.alpha(Tokens.bgPrimary, 0.6) }
                GradientStop { position: 1.0; color: Tokens.bgPrimary }
            }
        }
        // Back affordance.
        Rectangle {
            x: 20; y: 16; z: 5
            width: 96; height: 34; radius: Tokens.radiusPill
            color: Qt.alpha(Tokens.bgPrimary, 0.55)
            border.color: Tokens.borderSubtle
            Text {
                anchors.centerIn: parent
                text: qsTr("‹  Back")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize
            }
            MouseArea { anchors.fill: parent; onClicked: back() }
        }
        ColumnLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 28
            spacing: 8
            Text {
                text: {
                    var seg = [];
                    if (series && series.year > 0)
                        seg.push(String(series.year));
                    seg.push(qsTr("Series"));
                    seg.push(totalCount === 1 ? qsTr("1 episode") : qsTr("%1 episodes").arg(totalCount));
                    return seg.join("  ·  ");
                }
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.8
            }
            Text {
                Layout.fillWidth: true
                text: series ? series.title : ""
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 44
                font.weight: Font.Bold
                font.letterSpacing: -1.3
                elide: Text.ElideRight
            }
            Row {
                visible: genreList.length > 0
                spacing: 8
                Repeater {
                    model: genreList
                    delegate: Rectangle {
                        height: 24
                        width: genreText.implicitWidth + 22
                        radius: 12
                        color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.06))
                        border.color: Qt.alpha(Tokens.themeFg, 0.06)
                        Text {
                            id: genreText
                            anchors.centerIn: parent
                            text: modelData
                            color: Qt.alpha(Tokens.themeFg, 0.9)
                            font.family: Tokens.fontSans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 760
                visible: root.synopsis !== ""
                text: root.synopsis
                color: Tokens.textSecondary
                font.family: Tokens.fontSans
                font.pixelSize: 14
                lineHeight: 1.45
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(0, (root.width - Tokens.contentWidth) / 2)
        Layout.rightMargin: Layout.leftMargin
        Layout.alignment: Qt.AlignTop
        spacing: 32

        // Poster rail.
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.alignment: Qt.AlignTop
            spacing: 16

            Rectangle {
                Layout.preferredWidth: 220
                Layout.preferredHeight: 330
                radius: Tokens.radiusMd
                clip: true
                color: Tokens.surface1
                border.color: Qt.alpha(Tokens.themeFg, 0.1)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Color.shade(series ? series.accent : "#8A93A3", 0.38) }
                    GradientStop { position: 1.0; color: Color.shade(series ? series.accent : "#8A93A3", 0.15) }
                }
                Image {
                    id: railImage
                    anchors.fill: parent
                    source: root.posterArt
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source !== ""
                }
                Text {
                    anchors.centerIn: parent
                    visible: railImage.status !== Image.Ready
                    text: series ? String(series.title).charAt(0) : ""
                    color: "white"
                    opacity: 0.1
                    font.family: Tokens.fontSans
                    font.pixelSize: 72
                    font.bold: true
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 220
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Tokens.radiusPill
                    color: resumeTarget ? Tokens.textPrimary : Tokens.surface2
                    Text {
                        anchors.centerIn: parent
                        text: resuming ? qsTr("▶  Resume from %1").arg(fmtTime(resumeTarget.position_sec)) : qsTr("▶  Play")
                        color: resumeTarget ? Tokens.bgPrimary : Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: resumeTarget
                        onClicked: playMedia(resumeTarget)
                    }
                }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: watchedLine
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                }
                // Per-series autoplay override (DD-031).
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("Autoplay next")
                        color: Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: [
                            { id: "default", label: qsTr("Auto") },
                            { id: "on", label: qsTr("On") },
                            { id: "off", label: qsTr("Off") }
                        ]
                        delegate: Rectangle {
                            width: autoText.implicitWidth + 14
                            height: 24
                            radius: 12
                            color: root.autoplayMode === modelData.id
                                ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                                : Tokens.surface1
                            border.color: root.autoplayMode === modelData.id
                                ? Qt.alpha(Tokens.themeAccent, 0.5)
                                : Tokens.borderSubtle
                            Text {
                                id: autoText
                                anchors.centerIn: parent
                                text: modelData.label
                                color: root.autoplayMode === modelData.id ? Tokens.themeAccent : Tokens.textSecondary
                                font.family: Tokens.fontSans
                                font.pixelSize: 11
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: if (root.series) server.setSeriesAutoplay(root.series.id, modelData.id)
                            }
                        }
                    }
                }
            }

            // Information panel.
            Rectangle {
                Layout.preferredWidth: 220
                Layout.preferredHeight: infoCol.implicitHeight + 32
                radius: Tokens.radiusMd
                color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.03))
                border.color: Qt.alpha(Tokens.themeFg, 0.07)
                ColumnLayout {
                    id: infoCol
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 0
                    Text {
                        Layout.bottomMargin: 8
                        text: qsTr("Information")
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 10
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.8
                    }
                    Repeater {
                        model: {
                            var rows = [
                                { label: qsTr("Format"), value: qsTr("Series") }
                            ];
                            if (series && series.year > 0)
                                rows.push({ label: qsTr("Year"), value: String(series.year) });
                            if (seasons.length > 0)
                                rows.push({ label: qsTr("Seasons"), value: String(seasons.length) });
                            rows.push({ label: qsTr("Episodes"), value: String(totalCount) });
                            if (series && series.library)
                                rows.push({ label: qsTr("Library"), value: series.library });
                            rows.push({ label: qsTr("Watched"), value: qsTr("%1 of %2").arg(watchedCount).arg(totalCount) });
                            return rows;
                        }
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34
                            spacing: 12
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 1
                                Layout.alignment: Qt.AlignTop
                                color: Qt.alpha(Tokens.themeFg, 0.06)
                            }
                            Text {
                                text: modelData.label
                                color: Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.8
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: modelData.value
                                color: Tokens.textPrimary
                                font.family: Tokens.fontSans
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }

        // Episodes column: season chips + grid + Specials.
        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 16

            Row {
                visible: seasons.length > 1
                spacing: 8
                Repeater {
                    model: [{ id: "all", label: qsTr("All") }].concat(
                        seasons.map(function (s) { return { id: String(s.season), label: qsTr("Season %1").arg(s.season) }; }))
                    delegate: Rectangle {
                        height: 30
                        width: chipText.implicitWidth + 26
                        radius: 15
                        color: root.seasonFilter === modelData.id ? Tokens.textPrimary : Tokens.surface1
                        Text {
                            id: chipText
                            anchors.centerIn: parent
                            text: modelData.label
                            color: root.seasonFilter === modelData.id ? Tokens.bgPrimary : Tokens.textSecondary
                            font.family: Tokens.fontSans
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.seasonFilter = modelData.id
                        }
                    }
                }
            }

            Text {
                text: qsTr("Episodes")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }

            Repeater {
                model: seasons
                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    visible: root.seasonEpisodesVisible(modelData)
                    spacing: 10
                    Text {
                        visible: seasons.length > 1
                        text: qsTr("Season %1").arg(modelData.season)
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 10
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 1.6
                    }
                    Grid {
                        Layout.fillWidth: true
                        columns: Math.max(1, Math.floor((width + 16) / 260))
                        columnSpacing: 16
                        rowSpacing: 16
                        Repeater {
                            model: modelData.episodes
                            delegate: EpisodeCard {
                                item: modelData
                                onPlay: m => playMedia(m)
                                onOpen: m => openMedia(m)
                            }
                        }
                    }
                }
            }

            // Explicit Specials section (DD-030): unnumbered extras never
            // hide inside "All" the way the web folds them.
            ColumnLayout {
                Layout.fillWidth: true
                visible: specials.length > 0
                spacing: 10
                Text {
                    text: qsTr("Specials")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 1.6
                }
                Grid {
                    Layout.fillWidth: true
                    columns: Math.max(1, Math.floor((width + 16) / 260))
                    columnSpacing: 16
                    rowSpacing: 16
                    Repeater {
                        model: specials
                        delegate: EpisodeCard {
                            item: modelData
                            onPlay: m => playMedia(m)
                            onOpen: m => openMedia(m)
                        }
                    }
                }
            }
        }
    }
}
