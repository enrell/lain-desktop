import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Cinematic detail page with related media and technical information.
// Sections without data are not rendered.
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

    Hero {
        Layout.fillWidth: true
        media: parent.media
        onPlay: m => playMedia(m)
        onMoreInfo: m => openMedia(m)
    }

    // Voltar: sobre o hero, discreto
    Rectangle {
        x: Tokens.pageMargin
        y: 20
        z: 5
        width: 104
        height: 36
        radius: Tokens.radiusPill
        color: Qt.alpha(Tokens.bgPrimary, 0.55)
        border.color: Tokens.borderSubtle
        Text {
            anchors.centerIn: parent
            text: qsTr("‹  Back")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        MouseArea { anchors.fill: parent; onClicked: back() }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
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
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
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
            title: qsTr("More Like This")
            rowHeight: Tokens.posterWidth * 1.5 + 52
            model: related
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }

        MediaRow {
            Layout.fillWidth: true
            visible: extras.length > 0
            title: qsTr("Extras")
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 34
            model: extras
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: techRows.length > 0
            spacing: 12
            Text {
                text: qsTr("Media Info")
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: techColumn.implicitHeight + 40
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                ColumnLayout {
                    id: techColumn
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 8
                    Repeater {
                        model: techRows
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 24
                            Text {
                                Layout.preferredWidth: 120
                                text: modelData.label
                                color: Tokens.textTertiary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData.value
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
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
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: metaColumn.implicitHeight + 40
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                ColumnLayout {
                    id: metaColumn
                    anchors.fill: parent
                    anchors.margins: 20
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
                        font.family: Tokens.fontFamily
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
                                    font.family: Tokens.fontFamily
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
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 36
                            radius: Tokens.radiusMd
                            color: Tokens.themeAccent
                            opacity: server.enrichStatus === "running" ? 0.6 : 1
                            Text {
                                anchors.centerIn: parent
                                text: media && media.enriched ? qsTr("Refresh metadata") : qsTr("Enrich")
                                color: "black"
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                font.bold: true
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
                            Layout.preferredWidth: 110
                            Layout.preferredHeight: 36
                            radius: Tokens.radiusMd
                            color: Tokens.surface2
                            Text {
                                anchors.centerIn: parent
                                text: qsTr("Remove")
                                color: Tokens.textPrimary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
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
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.metaSize
                        }
                    }
                }
            }
        }
    }
}
