import QtQuick
import Lain
import "../theme/Color.js" as Color

// Plex-style series card (web ShowCard): one poster per show, opens the
// series page. The representative artwork is the series poster/cover kept
// by the catalog grouping.
Item {
    id: card
    width: Tokens.posterWidth
    height: width * 1.5 + 46
    property var series
    property string accent: series && series.accent ? series.accent : "#8A93A3"
    readonly property string artwork: series && (series.poster || series.cover)
                                      ? (series.poster || series.cover) : ""
    signal open(var series)

    Rectangle {
        id: art
        width: parent.width
        height: parent.width * 1.5
        radius: Tokens.radiusMd
        clip: true
        y: hover.containsMouse ? -4 : 0
        border.color: hover.containsMouse
            ? Qt.alpha(Tokens.themeFg, 0.15) : Qt.alpha(Tokens.themeFg, 0.05)
        Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Color.shade(card.accent, 0.38) }
            GradientStop { position: 1.0; color: Color.shade(card.accent, 0.15) }
        }
        Image {
            id: artImage
            anchors.fill: parent
            source: card.artwork
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
            scale: hover.containsMouse ? 1.035 : 1.0
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        Text {
            anchors.centerIn: parent
            visible: artImage.status !== Image.Ready
            text: card.series ? String(card.series.title).charAt(0) : ""
            color: "white"
            opacity: 0.08
            font.family: Tokens.fontSans
            font.pixelSize: 84
            font.bold: true
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.55; color: "transparent" }
                GradientStop { position: 1.0; color: Qt.alpha("black", 0.8) }
            }
            opacity: hover.containsMouse ? 1.0 : 0.15
            Behavior on opacity { NumberAnimation { duration: 300 } }
        }
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            width: 36; height: 36; radius: 18
            color: Qt.alpha("black", 0.65)
            visible: hover.containsMouse
            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: 1
                text: "▶"
                font.pixelSize: 14
                color: "white"
            }
        }
    }
    MouseArea { id: hover; anchors.fill: parent; hoverEnabled: true; onClicked: card.open(card.series) }
    Column {
        anchors.top: art.bottom
        anchors.topMargin: 10
        width: card.width
        spacing: 3
        Text {
            width: parent.width
            text: card.series ? card.series.title : ""
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.cardTitleSize
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            width: parent.width
            text: {
                if (!card.series)
                    return "";
                var s = card.series;
                var parts = [];
                var count = (s.episodeCount || 0) + (s.specialsCount || 0);
                parts.push(count === 1 ? qsTr("1 episode") : qsTr("%1 episodes").arg(count));
                if (s.seasonCount === 1)
                    parts.push(qsTr("Season %1").arg(s.seasons[0].season));
                else if (s.seasonCount > 1) {
                    var lo = s.seasons[0].season, hi = lo;
                    for (var i = 0; i < s.seasons.length; ++i) {
                        lo = Math.min(lo, s.seasons[i].season);
                        hi = Math.max(hi, s.seasons[i].season);
                    }
                    parts.push(qsTr("Seasons %1–%2").arg(lo).arg(hi));
                }
                if (s.year > 0)
                    parts.push(String(s.year));
                return parts.join("  ·  ");
            }
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: Tokens.metaSize - 1
            elide: Text.ElideRight
        }
    }
}
