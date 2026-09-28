import QtQuick
import QtQuick.Layouts
import Lain
import "../components"
import "../theme/Color.js" as Color

// Single-item page matching the web item route: backdrop band, poster left,
// meta column (title, meta segments, Play/Resume, genres, synopsis,
// progress, file path). Desktop extras (cast/related/extras/media info/
// admin metadata) stay as dense sections below.
ColumnLayout {
    id: root
    property var media
    property string selectedProvider: ""
    signal playMedia(var media)
    signal openMedia(var media)
    signal back()
    spacing: 0

    readonly property var related: media && media.related ? media.related : []
    readonly property var cast: media && media.cast ? media.cast : []
    readonly property var extras: media && media.extras ? media.extras : []
    readonly property string backdropArt: media && (media.cover || media.poster || media.thumb)
        ? (media.cover || media.poster || media.thumb) : ""
    readonly property string posterArt: media && (media.poster || media.cover || media.thumb)
        ? (media.poster || media.cover || media.thumb) : ""
    readonly property string displayTitle: media
        ? (media.displayTitle && media.displayTitle !== "" ? media.displayTitle : media.title) : ""
    readonly property var metaSegments: {
        if (!media)
            return [];
        var seg = [];
        if (media.year > 0)
            seg.push(String(media.year));
        if (media.runtime)
            seg.push(media.runtime);
        if (media.library)
            seg.push(media.library);
        if (media.size > 0 && media.size_human)
            seg.push(media.size_human);
        return seg;
    }
    readonly property var genreList: media && media.genres
        ? String(media.genres).split("·").map(function (g) { return g.trim(); }).filter(function (g) { return g !== ""; })
        : []
    readonly property bool resuming: media && !media.completed && media.position_sec >= 5

    function fmtTime(sec) {
        var s = Math.floor(sec || 0);
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), r = s % 60;
        return (h > 0 ? h + ":" : "") + (h > 0 && m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
    }

    readonly property var techRows: {
        var t = media && media.tech ? media.tech : ({});
        var labels = { container: qsTr("Container"), size: qsTr("Size"), library: qsTr("Library"), identifier: qsTr("Identifier") };
        var order = ["container", "size", "library", "identifier"];
        var rows = [];
        for (var i = 0; i < order.length; ++i) {
            var v = t[order[i]];
            if (v && String(v) !== "")
                rows.push({ label: labels[order[i]], value: String(v) });
        }
        return rows;
    }

    // Backdrop band.
    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 240
        Image {
            anchors.fill: parent
            source: root.backdropArt
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            opacity: 0.4
            visible: source !== ""
        }
        Rectangle {
            anchors.fill: parent
            color: root.backdropArt === "" ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.04)) : "transparent"
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.3) }
                GradientStop { position: 0.55; color: Qt.alpha(Tokens.bgPrimary, 0.7) }
                GradientStop { position: 1.0; color: Tokens.bgPrimary }
            }
        }
    }

    // Poster + meta column.
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        Layout.rightMargin: Layout.leftMargin
        Layout.topMargin: -100
        spacing: 32

        Rectangle {
            Layout.preferredWidth: 208
            Layout.preferredHeight: 312
            Layout.alignment: Qt.AlignTop
            radius: Tokens.radiusMd
            clip: true
            color: Tokens.surface1
            border.color: Tokens.borderSubtle
            gradient: Gradient {
                GradientStop { position: 0.0; color: Color.shade(media && media.accent ? media.accent : "#8A93A3", 0.38) }
                GradientStop { position: 1.0; color: Color.shade(media && media.accent ? media.accent : "#8A93A3", 0.15) }
            }
            Image {
                id: posterImage
                anchors.fill: parent
                source: root.posterArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: source !== ""
            }
            Text {
                anchors.centerIn: parent
                visible: posterImage.status !== Image.Ready
                text: media ? String(media.title).charAt(0) : ""
                color: "white"
                opacity: 0.1
                font.family: Tokens.fontSans
                font.pixelSize: 64
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 116
            spacing: 12

            ColumnLayout {
                spacing: 2
                Text {
                    Layout.fillWidth: true
                    objectName: "detailTitle"
                    text: displayTitle
                    color: Tokens.textPrimary
                    font.family: Tokens.fontSans
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                    font.letterSpacing: -0.6
                    elide: Text.ElideRight
                }
                Text {
                    visible: media && media.indexedTitle && media.indexedTitle !== ""
                    text: qsTr("Indexed as “%1”").arg(media ? media.indexedTitle : "")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: Tokens.metaSize + 1
                }
            }

            Text {
                text: metaSegments.join("  ·  ")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
            }

            // Primary action + secondary actions.
            RowLayout {
                spacing: 12
                Rectangle {
                    Layout.preferredWidth: playLabel.implicitWidth + 48
                    Layout.preferredHeight: Tokens.buttonHeight
                    radius: Tokens.radiusPill
                    color: Tokens.textPrimary
                    opacity: media && media.missing ? 0.45 : 1
                    Text {
                        id: playLabel
                        anchors.centerIn: parent
                        text: resuming ? qsTr("▶  Resume from %1").arg(fmtTime(media ? media.position_sec : 0)) : qsTr("▶  Play")
                        color: Tokens.bgPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: 14
                        font.weight: Font.Bold
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !(media && media.missing)
                        onClicked: playMedia(media)
                    }
                }
                Rectangle {
                    visible: media && (media.position_sec > 0 || media.completed)
                    Layout.preferredWidth: startLabel.implicitWidth + 28
                    Layout.preferredHeight: 32
                    radius: Tokens.radiusPill
                    color: "transparent"
                    border.color: Tokens.borderSubtle
                    Text {
                        id: startLabel
                        anchors.centerIn: parent
                        text: qsTr("↺  Start over")
                        color: Tokens.textSecondary
                        font.family: Tokens.fontSans
                        font.pixelSize: 12
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: if (media && media.id && media.duration_sec > 0)
                            server.reportProgress(media.id, 0, media.duration_sec, false)
                    }
                }
            }

            // Missing file notice (web item page).
            Rectangle {
                visible: media && media.missing
                Layout.fillWidth: true
                Layout.maximumWidth: 620
                Layout.preferredHeight: missingCol.implicitHeight + 24
                radius: Tokens.radiusMd
                color: Qt.alpha(Tokens.themeUrgent, 0.05)
                border.color: Qt.alpha(Tokens.themeUrgent, 0.25)
                ColumnLayout {
                    id: missingCol
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 4
                    Text {
                        text: qsTr("The file is no longer on disk.")
                        color: Tokens.themeUrgent
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.metaSize + 1
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: qsTr("It stays in the catalog so progress and metadata are preserved. If the file comes back under %1, it becomes playable again on its own.").arg(media && media.library ? media.library : qsTr("its library"))
                        color: Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.metaSize
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Row {
                visible: genreList.length > 0
                spacing: 6
                Repeater {
                    model: genreList
                    delegate: Rectangle {
                        height: 26
                        width: gText.implicitWidth + 22
                        radius: 13
                        color: Tokens.surface1
                        border.color: Tokens.borderSubtle
                        Text {
                            id: gText
                            anchors.centerIn: parent
                            text: modelData
                            color: Tokens.textPrimary
                            font.family: Tokens.fontSans
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 760
                visible: media && media.overview
                text: media ? media.overview : ""
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 14
                lineHeight: 1.5
                wrapMode: Text.WordWrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }

            ColumnLayout {
                visible: media && !media.completed && media.progress > 0
                Layout.maximumWidth: 420
                spacing: 6
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 4
                    radius: 2
                    color: Tokens.surface2
                    Rectangle {
                        width: parent.width * (media ? media.progress : 0)
                        height: parent.height
                        radius: 2
                        color: Tokens.themeAccent
                    }
                }
                Text {
                    text: media ? qsTr("%1 watched").arg(fmtTime(media.position_sec)) : ""
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                }
            }

            Text {
                visible: media && media.enriched
                text: {
                    if (!media || !media.enriched)
                        return "";
                    var by = media.enrichProviderLabel ? media.enrichProviderLabel : media.enrichProvider;
                    var s = qsTr("Metadata from %1").arg(by);
                    if (media.enrichFetchedAt > 0) {
                        var d = new Date(media.enrichFetchedAt * 1000);
                        s += "  ·  " + Qt.formatDate(d, Qt.ISODate);
                    }
                    return s;
                }
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 12
            }
            Text {
                Layout.fillWidth: true
                Layout.maximumWidth: 760
                visible: media && media.file_path
                text: media ? media.file_path : ""
                color: Qt.alpha(Tokens.textTertiary, 0.7)
                font.family: Tokens.fontFamily
                font.pixelSize: 11
                wrapMode: Text.WrapAnywhere
            }
        }
    }

    // Sections below (cast / related / extras / media info / admin metadata).
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        Layout.rightMargin: Layout.leftMargin
        Layout.topMargin: Tokens.sectionGap
        Layout.bottomMargin: Tokens.sectionGap
        spacing: Tokens.sectionGap

        ColumnLayout {
            Layout.fillWidth: true
            visible: cast.length > 0
            spacing: 12
            Text {
                text: qsTr("Cast")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                orientation: ListView.Horizontal
                spacing: Tokens.cardGap
                boundsBehavior: Flickable.StopAtBounds
                model: cast
                delegate: PersonCard { person: modelData }
            }
        }

        MediaRow {
            Layout.fillWidth: true
            visible: related.length > 0
            title: qsTr("More like this")
            rowHeight: Tokens.posterWidth * 1.5 + 46
            model: related
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }

        MediaRow {
            Layout.fillWidth: true
            visible: extras.length > 0
            title: qsTr("Extras")
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 46
            model: extras
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: techRows.length > 0
            spacing: 12
            Text {
                text: qsTr("Media info")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: techColumn.implicitHeight + 32
                radius: Tokens.radiusMd
                color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.03))
                border.color: Qt.alpha(Tokens.themeFg, 0.07)
                ColumnLayout {
                    id: techColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 0
                    Repeater {
                        model: techRows
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            spacing: 16
                            Text {
                                Layout.preferredWidth: 130
                                text: modelData.label
                                color: Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 0.8
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                color: Tokens.textPrimary
                                font.family: Tokens.fontSans
                                font.pixelSize: Tokens.metaSize
                                font.weight: Font.DemiBold
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }
        }

        // Administrator enrichment controls.
        ColumnLayout {
            id: metadataSection
            objectName: "metadataSection"
            Layout.fillWidth: true
            visible: server.ready && server.role === "admin"
            spacing: 12
            Text {
                text: qsTr("Metadata")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 18
                font.weight: Font.DemiBold
                font.letterSpacing: -0.3
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: metaColumn.implicitHeight + 32
                radius: Tokens.radiusMd
                color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.03))
                border.color: Qt.alpha(Tokens.themeFg, 0.07)
                ColumnLayout {
                    id: metaColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    Text {
                        Layout.fillWidth: true
                        text: {
                            if (media && media.enriched) {
                                var by = media.enrichProviderLabel ? media.enrichProviderLabel : media.enrichProvider;
                                if (media.indexedTitle)
                                    return qsTr("Overlay from %1 · indexed as “%2”").arg(by).arg(media.indexedTitle);
                                return qsTr("Overlay from %1").arg(by);
                            }
                            return qsTr("This item has no enriched metadata.");
                        }
                        color: Tokens.textSecondary
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.metaSize
                        wrapMode: Text.WordWrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Repeater {
                            model: [{ id: "", name: qsTr("Auto") }].concat(server.metadataProviders)
                            delegate: Rectangle {
                                Layout.preferredHeight: 30
                                Layout.preferredWidth: providerText.implicitWidth + 24
                                radius: Tokens.radiusPill
                                color: root.selectedProvider === modelData.id
                                    ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                                    : Tokens.surface2
                                border.color: root.selectedProvider === modelData.id
                                    ? Qt.alpha(Tokens.themeAccent, 0.5)
                                    : Tokens.borderSubtle
                                Text {
                                    id: providerText
                                    anchors.centerIn: parent
                                    text: modelData.name
                                    color: root.selectedProvider === modelData.id ? Tokens.themeAccent : Tokens.textSecondary
                                    font.family: Tokens.fontSans
                                    font.pixelSize: Tokens.metaSize
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.selectedProvider = modelData.id
                                }
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    RowLayout {
                        spacing: 10
                        Rectangle {
                            objectName: "enrichButton"
                            Layout.preferredWidth: 170
                            Layout.preferredHeight: 34
                            radius: Tokens.radiusPill
                            color: Tokens.surface2
                            opacity: server.enrichStatus === "running" ? 0.6 : 1
                            Text {
                                anchors.centerIn: parent
                                text: media && media.enriched ? qsTr("Refetch metadata") : qsTr("Fetch metadata")
                                color: Tokens.textPrimary
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: server.enrichStatus !== "running" && media && media.id
                                onClicked: server.enrichItem(media.id, root.selectedProvider)
                            }
                        }
                        Rectangle {
                            objectName: "removeEnrichButton"
                            visible: media && media.enriched
                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 34
                            radius: Tokens.radiusPill
                            color: Qt.alpha(Tokens.themeUrgent, 0.1)
                            border.color: Qt.alpha(Tokens.themeUrgent, 0.3)
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Remove")
                                color: Tokens.themeUrgent
                                font.family: Tokens.fontSans
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                enabled: server.enrichStatus !== "running"
                                onClicked: server.removeEnrichment(media.id)
                            }
                        }
                        Text {
                            visible: server.enrichStatus === "running"
                            text: qsTr("Fetching metadata…")
                            color: Tokens.textTertiary
                            font.family: Tokens.fontSans
                            font.pixelSize: Tokens.metaSize
                        }
                    }
                }
            }
        }
    }
}
