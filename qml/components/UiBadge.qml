import QtQuick
import Lain

// Web Badge: a small rounded pill in a tone (neutral/accent/danger/success/warning).
Rectangle {
    id: root
    property string text: ""
    property string tone: "neutral"
    readonly property color toneColor: tone === "accent" ? Tokens.themeAccent
                                     : tone === "danger" ? Tokens.danger
                                     : tone === "success" ? Tokens.success
                                     : tone === "warning" ? Tokens.warning : Tokens.textTertiary
    implicitWidth: label.implicitWidth + 16
    implicitHeight: 20
    radius: height / 2
    color: tone === "neutral" ? Tokens.surface2 : Qt.alpha(toneColor, 0.10)
    border.color: tone === "neutral" ? Tokens.hairline : Qt.alpha(toneColor, 0.30)
    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.tone === "neutral" ? Tokens.textSecondary : root.toneColor
        font.family: Tokens.fontSans
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 0.3
    }
}
