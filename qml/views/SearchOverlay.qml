import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Busca funcional: input grande + resultados ao vivo do servidor
// (GET /api/search com debounce no client C++).
Rectangle {
    id: root
    anchors.fill: parent
    color: "#000000B8"
    z: 20

    signal openMedia(var media)
    signal closed()

    function openWith(q) {
        visible = true;
        query = q;
        searchInput.text = q;
        searchInput.forceActiveFocus();
        server.search(q);
    }

    property string query: ""

    readonly property var results: query.trim() === "" ? (server.catalog || []).slice(0, 12)
                                                       : server.searchResults
    readonly property int resultCount: results ? results.length : 0

    MouseArea {
        anchors.fill: parent
        onClicked: { root.visible = false; root.closed(); }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(900, parent.width - 120)
        height: Math.min(620, parent.height - 120)
        radius: Tokens.radiusLg
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        MouseArea { anchors.fill: parent } // consome cliques dentro do painel

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 14

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: "\uf002"
                    color: Tokens.themeAccent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 20
                }
                TextInput {
                    id: searchInput
                    objectName: "searchInput"
                    Layout.fillWidth: true
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 20
                    selectByMouse: true
                    onTextChanged: {
                        root.query = text;
                        server.search(text);
                    }
                    onAccepted: { if (root.resultCount > 0) root.openMedia(root.results[0]); }
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: "Buscar na biblioteca…"
                        color: Tokens.textTertiary
                        font: searchInput.font
                        visible: searchInput.text === ""
                    }
                }
            }

            Text {
                text: root.query.trim() === ""
                    ? "Sugestões"
                    : server.searching ? "Buscando…"
                    : root.resultCount + (root.resultCount === 1 ? " resultado" : " resultados")
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }

            GridView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                cellWidth: Tokens.posterWidth + Tokens.cardGap
                cellHeight: Tokens.posterWidth * 1.5 + 52
                boundsBehavior: Flickable.StopAtBounds
                model: root.results
                delegate: PosterCard {
                    media: modelData
                    onOpen: m => root.openMedia(m)
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.query.trim() !== "" && !server.searching && root.resultCount === 0
                text: "Nenhum resultado para '" + root.query.trim() + "'"
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
        }
    }
}
