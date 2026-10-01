import QtQuick
import QtQuick.Layouts
import Lain

// Web SettingsGroup: a mono micro-label heading over a hairline, then rows.
ColumnLayout {
    id: root
    property string title: ""
    property string anchorId: ""
    function pulse() { pulseAnim.restart(); }
    property alias aside: asideRow.data
    default property alias rows: body.data
    spacing: 0
    Layout.fillWidth: true
    property bool first: false
    Layout.topMargin: first ? 0 : 32

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 8
        Text {
            id: heading
            Layout.fillWidth: true
            text: root.title.toUpperCase()
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 2.6
        }
        RowLayout { id: asideRow; spacing: 8 }
    }
    SequentialAnimation {
        id: pulseAnim
        ColorAnimation { target: heading; property: "color"; to: Tokens.themeAccent; duration: 1 }
        PauseAnimation { duration: 700 }
        ColorAnimation { target: heading; property: "color"; to: Tokens.textTertiary; duration: 1100 }
    }
    Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
    ColumnLayout {
        id: body
        Layout.fillWidth: true
        spacing: 0
    }
}
