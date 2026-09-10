import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Collections: fileiras derivadas dos dados reais — uma por gênero do
// enrichment (o servidor v0.1 não tem coleções manuais). Clique abre Detail.
ColumnLayout {
    property var collections: []
    signal openMedia(var media)
    signal searchRequested(string text)
    signal account()
    spacing: Tokens.sectionGap

    PageHeader {
        Layout.topMargin: 8
        eyebrow: "COLLECTIONS"
        onSearchRequested: t => searchRequested(t)
        onOpenMedia: m => openMedia(m)
        onAccount: account()
    }

    Repeater {
        model: collections
        delegate: MediaRow {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.pageMargin
            Layout.rightMargin: Tokens.pageMargin
            title: modelData.title
            rowHeight: Tokens.posterWidth * 1.5 + 52
            model: modelData.items
            delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
        }
    }

    ColumnLayout {
        Layout.leftMargin: Tokens.pageMargin
        Layout.topMargin: 20
        visible: (collections || []).length === 0
        spacing: 8
        Text {
            text: "Sem coleções por enquanto"
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.maximumWidth: 560
            text: "As coleções são agrupadas por gênero assim que os itens tiverem metadados (enrichment)."
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.bodySize
            wrapMode: Text.WordWrap
        }
    }

    Item {
        Layout.fillWidth: true
        Layout.bottomMargin: Tokens.sectionGap
        height: 1
    }
}
