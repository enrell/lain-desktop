import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Dense library grid with genre filters and sorting over the current model.
// For shows (DD-030), series hierarchy (series/season/episode plus Specials)
// renders above the flat grid from the series model.
ColumnLayout {
    id: root
    property string title: qsTr("Movies")
    property var items: []
    signal openMedia(var media)

    property var seriesModel: []
    property bool showSeries: false
    signal playMedia(var media)

    property string selectedGenre: "__all__"
    property string sortMode: "title" // title | year
    signal searchRequested(string text)
    signal account()

    readonly property string allLabel: qsTr("All")
    // Genres come from enrichment data rather than a fixed list.
    // The "All" entry uses a stable id so locale switches keep selection.
    readonly property var genres: {
        var seen = {};
        var names = [];
        var list = items || [];
        for (var i = 0; i < list.length; ++i) {
            var g = list[i].genre;
            if (g && g !== "" && !seen[g]) {
                seen[g] = true;
                names.push(g);
            }
        }
        names.sort();
        var out = [{ id: "__all__", label: allLabel }];
        for (var j = 0; j < names.length; ++j)
            out.push({ id: names[j], label: names[j] });
        return out;
    }

    function computeShown() {
        var list = (items || []).slice();
        if (selectedGenre !== "__all__")
            list = list.filter(m => m.genre === selectedGenre);
        if (sortMode === "title")
            list.sort((a, b) => String(a.title).localeCompare(String(b.title)));
        else if (sortMode === "year")
            list.sort((a, b) => Number(b.year) - Number(a.year));
        return list;
    }
    readonly property var shown: computeShown()

    spacing: 0

    PageHeader {
        Layout.topMargin: 8
        eyebrow: qsTr("LIBRARY")
        onSearchRequested: t => searchRequested(t)
        onOpenMedia: m => openMedia(m)
        onAccount: account()
    }

    // Title and item count.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        Layout.topMargin: 8
        spacing: 12
        Text {
            text: title
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.pageTitleSize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 4
            text: shown.length === 1 ? qsTr("1 title") : qsTr("%1 titles").arg(shown.length)
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
    }

    // Filters and sorting.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        Layout.topMargin: 18
        spacing: 8

        Repeater {
            model: genres
            delegate: Rectangle {
                Layout.preferredHeight: 32
                Layout.preferredWidth: chipLabel.implicitWidth + 28
                radius: Tokens.radiusPill
                color: selectedGenre === modelData.id ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16)) : Tokens.surface1
                border.color: selectedGenre === modelData.id ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle
                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: modelData.label
                    color: selectedGenre === modelData.id ? Tokens.themeAccent : Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: selectedGenre = modelData.id
                }
            }
        }

        Item { Layout.fillWidth: true }

        Text {
            text: qsTr("Sort")
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Repeater {
            model: [
                { key: "title", label: qsTr("Title") },
                { key: "year", label: qsTr("Year") }
            ]
            delegate: Text {
                text: modelData.label
                color: sortMode === modelData.key ? Tokens.themeAccent : Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                font.bold: sortMode === modelData.key
                MouseArea {
                    anchors.fill: parent
                    onClicked: sortMode = modelData.key
                }
            }
        }
    }

    // Series hierarchy for shows (DD-030): one block per series with
    // season rows and a Specials section. Episode rows open the episode.
    Repeater {
        objectName: "seriesRepeater"
        model: root.showSeries ? root.seriesModel : []
        delegate: ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.pageMargin
            Layout.rightMargin: Tokens.pageMargin
            Layout.topMargin: 20
            spacing: 6
            property string seriesId: modelData.id
            property bool expanded: false
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text {
                    Layout.fillWidth: true
                    text: modelData.title + "  ·  "
                        + (modelData.episodeCount === 1 ? qsTr("1 episode") : qsTr("%1 episodes").arg(modelData.episodeCount))
                        + (modelData.seasonCount > 0
                            ? "  ·  " + (modelData.seasonCount === 1 ? qsTr("1 season") : qsTr("%1 seasons").arg(modelData.seasonCount))
                            : "")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.sectionSize
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: expanded ? "▾" : "▸"
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.bodySize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: expanded = !expanded
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: expanded
                spacing: 2
                Repeater {
                    model: modelData.seasons || []
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: qsTr("Season %1").arg(modelData.season)
                            color: Tokens.textTertiary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.metaSize
                        }
                        Repeater {
                            model: modelData.episodes || []
                            delegate: Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 8
                                color: "transparent"
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    spacing: 10
                                    Text {
                                        Layout.preferredWidth: 90
                                        text: "E" + modelData.episode
                                        color: Tokens.textTertiary
                                        font.family: Tokens.fontFamily
                                        font.pixelSize: Tokens.metaSize
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.displayTitle || modelData.title
                                        color: Tokens.textPrimary
                                        font.family: Tokens.fontFamily
                                        font.pixelSize: Tokens.metaSize
                                        elide: Text.ElideRight
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { root.openMedia(modelData); }
                                }
                            }
                        }
                    }
                }
                Text {
                    visible: (modelData.specials || []).length > 0
                    text: qsTr("Specials")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                Repeater {
                    model: modelData.specials || []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 8
                        color: "transparent"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            Text {
                                Layout.fillWidth: true
                                text: modelData.displayTitle || modelData.title
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                elide: Text.ElideRight
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: { root.openMedia(modelData); }
                        }
                    }
                }
            }
        }
    }

    // Dense desktop grid.
    GridView {
        id: grid
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        Layout.topMargin: 20
        Layout.bottomMargin: Tokens.sectionGap
        Layout.preferredHeight: Math.max(320, contentHeight)
        visible: shown.length > 0
        cellWidth: Tokens.posterWidth + Tokens.cardGap
        cellHeight: Tokens.posterWidth * 1.5 + 56
        boundsBehavior: Flickable.StopAtBounds
        model: shown
        delegate: PosterCard {
            media: modelData
            highlighted: GridView.isCurrentItem
            onOpen: m => openMedia(m)
        }
    }

    Text {
        Layout.leftMargin: Tokens.pageMargin
        Layout.topMargin: 40
        Layout.bottomMargin: Tokens.sectionGap
        visible: shown.length === 0
        text: items && items.length === 0
            ? qsTr("No media in this library. Scan it from server settings.")
            : qsTr("No media matches this filter.")
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.bodySize
    }
}
