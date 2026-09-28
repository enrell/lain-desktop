import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Dedicated search page matching the web /search route: heading, large
// input, result count, poster grid, idle/empty states. Debounce lives in
// the C++ client like before.
ColumnLayout {
    id: root
    signal openMedia(var media)
    signal account()

    property string query: ""
    property string searchedFor: ""

    readonly property var results: server.searchResults || []
    readonly property int resultCount: results ? results.length : 0

    function openWith(q) {
        query = q;
        searchInput.text = q;
        searchedFor = q.trim();
        if (q.trim() !== "")
            server.search(q.trim());
        searchInput.forceActiveFocus();
    }

    function focusInput() {
        searchInput.forceActiveFocus();
    }

    spacing: 0

    ColumnLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        Layout.rightMargin: Layout.leftMargin
        Layout.topMargin: 16
        Layout.bottomMargin: Tokens.sectionGap
        spacing: 20

        ColumnLayout {
            spacing: 10
            Text {
                text: qsTr("Search")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.pageTitleSize - 6
                font.weight: Font.DemiBold
                font.letterSpacing: -0.4
            }
            Rectangle {
                Layout.preferredWidth: Math.min(640, root.width - 80)
                Layout.preferredHeight: 48
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: searchInput.activeFocus ? Qt.alpha(Tokens.themeAccent, 0.6) : Tokens.borderSubtle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    Text {
                        text: "\uf002"
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 15
                    }
                    TextInput {
                        id: searchInput
                        objectName: "searchInput"
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: 14
                        selectByMouse: true
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: qsTr("Titles, not filenames")
                            color: Qt.alpha(Tokens.textTertiary, 0.6)
                            font: searchInput.font
                            visible: searchInput.text === ""
                        }
                        onTextChanged: {
                            root.query = text;
                            if (text.trim() !== "")
                                root.searchedFor = text.trim();
                            server.search(text.trim());
                        }
                        onAccepted: { if (root.resultCount > 0) root.openMedia(root.results[0]); }
                        Keys.onEscapePressed: {
                            if (text !== "")
                                text = "";
                            else
                                focus = false;
                        }
                    }
                }
            }
            Text {
                visible: root.searchedFor !== "" && !server.searching
                text: root.resultCount === 1
                    ? qsTr("1 result for “%1”").arg(root.searchedFor)
                    : qsTr("%1 results for “%2”").arg(root.resultCount).arg(root.searchedFor)
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
            }
        }

        // Idle state.
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 60
            visible: root.searchedFor === ""
            spacing: 10
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Search your library")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 440
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Type a title. Matching is case-insensitive and covers what the catalog knows, not raw filenames.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
                wrapMode: Text.WordWrap
            }
        }

        // Searching / empty states.
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 60
            visible: root.searchedFor !== "" && server.searching
            text: qsTr("Searching…")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize + 1
        }
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 60
            visible: root.searchedFor !== "" && !server.searching && root.resultCount === 0
            spacing: 10
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No matches for “%1”").arg(root.searchedFor)
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 440
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Try a shorter title, or check whether a scan has indexed the library.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: Tokens.metaSize + 1
                wrapMode: Text.WordWrap
            }
        }

        Grid {
            Layout.fillWidth: true
            visible: root.resultCount > 0
            columns: Math.max(2, Math.floor((width + 12) / (Tokens.posterWidth + 12)))
            columnSpacing: 12
            rowSpacing: 20
            Repeater {
                model: root.results
                delegate: PosterCard {
                    media: modelData
                    onOpen: m => root.openMedia(m)
                }
            }
        }
    }
}
