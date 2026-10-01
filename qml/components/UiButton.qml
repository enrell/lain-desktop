import QtQuick
import QtQuick.Layouts
import Lain

// Web Button primitive (button-styles.ts): primary, secondary, ghost and
// danger variants in sm/md sizes, with an optional leading glyph and a
// loading state. Keyboard: Tab focus ring, Enter/Space activate.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property string variant: "primary"
    property string size: "md"
    property bool loading: false
    signal clicked()

    readonly property bool hovered: mouse.containsMouse
    readonly property bool active: enabled && !loading

    implicitHeight: size === "sm" ? Tokens.controlHeightSm : Tokens.controlHeight + 4
    implicitWidth: Math.max(implicitHeight, row.implicitWidth + (size === "sm" ? 24 : 32))
    radius: Math.max(4, Tokens.radiusSm + 2)
    opacity: enabled ? 1 : 0.5
    activeFocusOnTab: enabled
    Accessible.role: Accessible.Button
    Accessible.name: text
    Keys.onReturnPressed: if (active) clicked()
    Keys.onEnterPressed: if (active) clicked()
    Keys.onSpacePressed: if (active) clicked()

    color: {
        switch (variant) {
        case "primary": return hovered ? Qt.lighter(Tokens.themeAccent, 1.12) : Tokens.themeAccent;
        case "secondary": return hovered ? Tokens.fieldHover : Tokens.surface2;
        case "danger": return Qt.alpha(Tokens.danger, hovered ? 0.25 : 0.15);
        default: return hovered ? Tokens.hoverFill : "transparent";
        }
    }
    border.width: activeFocus ? 2 : (variant === "secondary" || variant === "danger" ? 1 : 0)
    border.color: activeFocus ? Tokens.themeAccent
                 : variant === "danger" ? Qt.alpha(Tokens.danger, 0.3) : Tokens.hairline
    readonly property color ink: variant === "primary" ? Tokens.accentFg
                               : variant === "danger" ? Tokens.danger
                               : variant === "ghost" && !hovered ? Tokens.textSecondary : Tokens.textPrimary
    Behavior on color { ColorAnimation { duration: 120 } }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 8
        UiSpinner {
            visible: root.loading
            size: 14
            color: root.ink
        }
        Glyph {
            visible: root.icon !== "" && !root.loading
            name: root.icon
            size: root.size === "sm" ? 14 : 16
            color: root.ink
        }
        Text {
            visible: root.text !== ""
            text: root.text
            color: root.ink
            font.family: Tokens.fontSans
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.active ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.active) root.clicked()
    }
}
