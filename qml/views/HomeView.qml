import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Home uses a full-bleed hero and rows aligned to one content gutter.
ColumnLayout {
    property var home
    signal openMedia(var media)
    signal playMedia(var media)
    signal searchRequested(string text)
    signal account()
    spacing: Tokens.sectionGap

    readonly property var continueRow: home && home.continueWatching ? home.continueWatching : []
    readonly property var recentRow: home && home.recentlyAdded ? home.recentlyAdded : []
    readonly property bool empty: continueRow.length === 0 && recentRow.length === 0

    PageHeader {
        Layout.topMargin: 8
        eyebrow: qsTr("HOME")
        onSearchRequested: t => searchRequested(t)
        onOpenMedia: m => openMedia(m)
        onAccount: account()
    }
    Hero {
        Layout.fillWidth: true
        media: home && home.hero ? home.hero : null
        onPlay: m => playMedia(m)
        onMoreInfo: m => openMedia(m)
    }
    MediaRow {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        visible: continueRow.length > 0
        objectName: "continueRow"
        title: qsTr("Continue Watching")
        rowHeight: Tokens.landscapeWidth * 9 / 16 + 34
        model: continueRow
        delegate: LandscapeCard { media: modelData; onOpen: m => openMedia(m) }
    }
    MediaRow {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        Layout.bottomMargin: Tokens.sectionGap
        visible: recentRow.length > 0
        objectName: "recentRow"
        title: qsTr("Recently Added")
        rowHeight: Tokens.posterWidth * 1.5 + 52
        model: recentRow
        delegate: PosterCard { media: modelData; onOpen: m => openMedia(m) }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Tokens.pageMargin
        Layout.rightMargin: Tokens.pageMargin
        Layout.bottomMargin: Tokens.sectionGap
        visible: empty
        spacing: 8
        Text {
            text: qsTr("Your library is empty")
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.maximumWidth: 560
            text: qsTr("Create a library and scan it to make your media appear here.")
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.bodySize
            wrapMode: Text.WordWrap
        }
    }
}
