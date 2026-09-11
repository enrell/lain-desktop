import QtQuick
import QtQuick.Layouts
import Lain
import "../theme/Color.js" as Color
import "../theme/Format.js" as Format

// Hero uses artwork when available and a media-color wash otherwise.
Rectangle {
    id: hero
    height: 480
    color: Tokens.bgPrimary
    property var media
    property string accent: media && media.accent ? media.accent : "#8A93A3"
    readonly property string artwork: media && (media.cover || media.poster || media.thumb)
                                       ? (media.cover || media.poster || media.thumb) : ""
    readonly property string displayTitle: media ? (media.displayTitle && media.displayTitle !== "" ? media.displayTitle : media.title) : ""
    signal play(var media)
    signal moreInfo(var media)

    // Procedural media wash below artwork.
    Rectangle {
        anchors.fill: parent
        color: Color.shade(hero.accent, 0.24)
        Behavior on color { ColorAnimation { duration: 400 } }
    }
    Image {
        anchors.fill: parent
        source: hero.artwork
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        opacity: 0.55
        visible: source !== ""
    }
    // Horizontal text-legibility gradient.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.95) }
            GradientStop { position: 0.45; color: Qt.alpha(Tokens.bgPrimary, 0.45) }
            GradientStop { position: 0.75; color: Qt.alpha(Tokens.bgPrimary, 0.0) }
        }
    }
    // Vertical transition into the page background.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.45; color: Qt.alpha(Tokens.bgPrimary, 0.0) }
            GradientStop { position: 1.0; color: Tokens.bgPrimary }
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.pageMargin
        anchors.rightMargin: Tokens.pageMargin
        anchors.bottomMargin: 36
        spacing: 0

        // Accent mark shared with the progress-bar visual language.
        Rectangle {
            width: 28; height: 3; radius: 2
            color: hero.accent
        }
        Text {
            Layout.topMargin: 14
            Layout.fillWidth: true
            objectName: "heroTitle"
            text: hero.displayTitle
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.heroSize
            font.bold: true
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 2
            lineHeight: 0.95
            elide: Text.ElideRight
        }
        Text {
            Layout.topMargin: 10
            text: Format.heroMeta(hero.media)
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize + 1
            font.letterSpacing: 0.4
        }
        Text {
            Layout.topMargin: 10
            Layout.maximumWidth: 640
            visible: text !== ""
            text: media ? media.overview : ""
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.bodySize
            lineHeight: 1.5
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        RowLayout {
            Layout.topMargin: 18
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 136
                Layout.preferredHeight: Tokens.buttonHeight
                radius: Tokens.radiusMd
                color: hero.accent
                Text {
                    anchors.centerIn: parent
                    text: qsTr("▶  Play")
                    color: "black"
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.bodySize
                    font.bold: true
                }
                MouseArea { anchors.fill: parent; onClicked: hero.play(hero.media) }
            }
            Rectangle {
                Layout.preferredWidth: 136
                Layout.preferredHeight: Tokens.buttonHeight
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("More Info")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.bodySize
                }
                MouseArea { anchors.fill: parent; onClicked: hero.moreInfo(hero.media) }
            }
        }
    }
}
