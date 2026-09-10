import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Detail (§24): hero cinematográfico + relacionados + ficha técnica.
// Seções sem dados (cast/extras no servidor v0.1) simplesmente não aparecem.
ColumnLayout {
    property var media
    signal playMedia(var media)
    signal openMedia(var media)
    signal back()
    spacing: 0

    readonly property var related: media && media.related ? media.related : []
    readonly property var cast: media && media.cast ? media.cast : []
    readonly property var extras: media && media.extras ? media.extras : []

    readonly property var techRows: {
        var t = media && media.tech ? media.tech : ({});
        var labels = { container: "Container", size: "Size", library: "Library", identifier: "Identifier" };
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
            text: "‹  Back"
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
                text: "Cast"
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
            title: "More Like This"
            rowHeight: Tokens.posterWidth * 1.5 + 52
            model: related
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }

        MediaRow {
            Layout.fillWidth: true
            visible: extras.length > 0
            title: "Extras"
            rowHeight: Tokens.landscapeWidth * 9 / 16 + 34
            model: extras
            delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: techRows.length > 0
            spacing: 12
            Text {
                text: "Media Info"
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
    }
}
