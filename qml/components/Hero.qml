import QtQuick
import QtQuick.Layouts
import Lain
import "../theme/Color.js" as Color
import "../theme/Format.js" as Format

// Web-monolith hero: artwork fills the right ~70%, gradient shade keeps the
// left copy readable. Eyebrow + meta stay monospace like the web labels.
Rectangle {
    id: hero
    // Web hero: min(56rem, 100svh) — nearly a full viewport tall. Inside a
    // ColumnLayout the height must come from implicitHeight, not parent.
    implicitHeight: Math.min(896, Math.max(560, hero.Window.height || 860))
    color: Tokens.bgPrimary
    clip: true

    property var media
    property var upNext: null
    property bool resume: false
    property string accent: media && media.accent ? media.accent : "#8A93A3"
    // clamp(2.5rem, 6.5vw, 6.5rem) ≈ 40–104px at 6.5% of viewport width.
    readonly property int titleSize: Math.max(40, Math.min(104, Math.round(hero.width * 0.065)))
    readonly property string artwork: media && (media.cover || media.poster || media.thumb)
                                       ? (media.cover || media.poster || media.thumb) : ""
    readonly property string displayTitle: media ? (media.displayTitle && media.displayTitle !== "" ? media.displayTitle : media.title) : ""
    signal play(var media)
    signal moreInfo(var media)
    signal playUpNext(var media)


    // Artwork anchored right, ~70% of width on wide screens.
    Item {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: hero.width >= 900 ? hero.width * 0.7 : hero.width
        clip: true
        // Procedural wash when there is no artwork; shaded like the art.
        Rectangle {
            anchors.fill: parent
            color: Color.shade(hero.accent, 0.16)
            Behavior on color { ColorAnimation { duration: 400 } }
        }
        Image {
            anchors.fill: parent
            source: hero.artwork
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: source !== ""
        }
        // Web hero-monolith-shade: horizontal fade into the page background.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Tokens.bgPrimary }
                GradientStop { position: 0.22; color: Qt.alpha(Tokens.bgPrimary, 0.96) }
                GradientStop { position: 0.55; color: Qt.alpha(Tokens.bgPrimary, 0.58) }
                GradientStop { position: 0.82; color: Qt.alpha(Tokens.bgPrimary, 0.08) }
                GradientStop { position: 1.0; color: Qt.alpha(Tokens.bgPrimary, 0.08) }
            }
        }
        // Second web layer: bottom-heavy vertical fade over the whole hero.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.28) }
                GradientStop { position: 0.58; color: Qt.alpha(Tokens.bgPrimary, 0.12) }
                GradientStop { position: 1.0; color: Tokens.bgPrimary }
            }
        }
    }

    // Bottom fade into page background.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * 0.45
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.0) }
            GradientStop { position: 1.0; color: Tokens.bgPrimary }
        }
    }

    // Copy block vertically centered like the web justify-center column.
    ColumnLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 28
        anchors.leftMargin: Math.max(Tokens.pageMargin, (hero.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
        width: Math.min(hero.width - anchors.leftMargin - Tokens.pageMargin, 900)
        spacing: 0

        Text {
            text: (hero.resume ? qsTr("Continue your story") : qsTr("Now in your library"))
                + (hero.media && hero.media.year > 0 ? "  /  " + hero.media.year : "")
            color: Tokens.themeAccent
            font.family: Tokens.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 2.9
        }
        Text {
            Layout.topMargin: 14
            Layout.fillWidth: true
            // Web: clamp(2.5rem, 6.5vw, 6.5rem), uppercase, max 12ch.
            Layout.maximumWidth: Math.max(420, Math.floor(hero.titleSize * 6.2))
            objectName: "heroTitle"
            text: hero.displayTitle
            color: "#FFFFFF"
            font.family: Tokens.fontSans
            font.pixelSize: hero.titleSize
            font.weight: Font.Black
            font.letterSpacing: -1.8
            font.capitalization: Font.AllUppercase
            lineHeight: 0.95
            elide: Text.ElideRight
            maximumLineCount: 3
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.topMargin: 20
            text: {
                var meta = Format.heroMeta(hero.media);
                var genres = hero.media && hero.media.genres ? String(hero.media.genres).split("·").slice(0, 2).map(function (g) { return g.trim(); }).join(" · ") : "";
                return [meta, genres].filter(function (s) { return s !== ""; }).join("  /  ");
            }
            color: Qt.alpha("#FFFFFF", 0.6)
            font.family: Tokens.fontFamily
            font.pixelSize: 11
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.3
        }
        Text {
            Layout.topMargin: 16
            Layout.maximumWidth: 580
            visible: text !== ""
            text: hero.media ? hero.media.overview : ""
            color: Qt.alpha("#FFFFFF", 0.68)
            font.family: Tokens.fontSans
            font.pixelSize: 15
            lineHeight: 1.5
            wrapMode: Text.WordWrap
            maximumLineCount: 3
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.topMargin: 26
            spacing: 12
            Rectangle {
                Layout.preferredWidth: playText.implicitWidth + 48
                Layout.preferredHeight: Tokens.buttonHeight
                radius: Tokens.radiusPill
                color: "#FFFFFF"
                Text {
                    id: playText
                    anchors.centerIn: parent
                    text: hero.resume ? qsTr("▶  Continue watching") : qsTr("▶  Play")
                    color: "#000000"
                    font.family: Tokens.fontSans
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.alpha("#FFFFFF", 0.88)
                    onExited: parent.color = "#FFFFFF"
                    onClicked: hero.play(hero.media)
                }
            }
            Rectangle {
                Layout.preferredWidth: infoText.implicitWidth + 40
                Layout.preferredHeight: Tokens.buttonHeight
                radius: Tokens.radiusPill
                color: Qt.alpha("#000000", 0.2)
                border.color: Qt.alpha("#FFFFFF", 0.16)
                Text {
                    id: infoText
                    anchors.centerIn: parent
                    text: qsTr("ⓘ  More details")
                    color: "#FFFFFF"
                    font.family: Tokens.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.alpha("#FFFFFF", 0.1)
                    onExited: parent.color = Qt.alpha("#000000", 0.2)
                    onClicked: hero.moreInfo(hero.media)
                }
            }
        }
    }

    // "Continue next" card bottom-right, like the web hero's upNext block.
    Rectangle {
        visible: hero.upNext !== null && hero.width >= 1000
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 32
        anchors.bottomMargin: 32
        width: Math.min(416, hero.width * 0.32)
        height: 96
        radius: 0
        color: Qt.alpha("#000000", 0.75)
        border.color: Qt.alpha("#FFFFFF", 0.1)
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Rectangle {
                Layout.preferredWidth: 112
                Layout.preferredHeight: 96
                Layout.alignment: Qt.AlignTop
                clip: true
                color: Tokens.surface1
                Image {
                    anchors.fill: parent
                    source: hero.upNext ? (hero.upNext.cover || hero.upNext.poster || hero.upNext.thumb || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: source !== ""
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 16
                spacing: 6
                Text {
                    text: qsTr("Continue next")
                    color: Tokens.themeAccent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: 2.6
                }
                Text {
                    Layout.fillWidth: true
                    text: hero.upNext ? (hero.upNext.displayTitle && hero.upNext.displayTitle !== "" ? hero.upNext.displayTitle : hero.upNext.title) : ""
                    color: "#FFFFFF"
                    font.family: Tokens.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 3
                    visible: hero.upNext && hero.upNext.progress > 0
                    color: Tokens.track
                    radius: 1.5
                    Rectangle {
                        width: parent.width * (hero.upNext ? hero.upNext.progress : 0)
                        height: parent.height
                        radius: 1.5
                        color: Tokens.themeAccent
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; onClicked: hero.playUpNext(hero.upNext) }
    }
}
