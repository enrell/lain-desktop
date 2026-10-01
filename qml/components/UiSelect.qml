import QtQuick
import QtQuick.Layouts
import Lain

// Web Select: a field-colored trigger that opens an option list. The list
// is re-parented to the window overlay so it never clips inside a pane.
// Keyboard: Enter/Space/Down open, arrows move, Enter picks, Esc closes.
Rectangle {
    id: root
    // [{ id, label }] — ids may be strings, booleans or numbers.
    property var model: []
    property var current: ""
    property string label: ""
    signal picked(var id)

    implicitWidth: 176
    implicitHeight: Tokens.controlHeight
    radius: Math.max(4, Tokens.radiusSm + 2)
    opacity: enabled ? 1 : 0.5
    color: mouse.containsMouse ? Tokens.fieldHover : Tokens.field
    border.width: activeFocus || popup.visible ? 1 : 0
    border.color: Qt.alpha(Tokens.themeAccent, 0.7)
    activeFocusOnTab: enabled
    Accessible.role: Accessible.ComboBox
    Accessible.name: label !== "" ? label : currentLabel()

    property int highlighted: -1

    function indexOfCurrent() {
        for (var i = 0; i < model.length; ++i)
            if (model[i].id === current)
                return i;
        return -1;
    }
    function currentLabel() {
        var i = indexOfCurrent();
        return i >= 0 ? model[i].label : (model.length > 0 ? model[0].label : "");
    }
    function open() {
        if (!enabled)
            return;
        var host = root.Window.window ? root.Window.window.contentItem : null;
        if (host) {
            popup.parent = host;
            var p = root.mapToItem(host, 0, root.height + 4);
            if (p.y + list.height > host.height - 8)
                p = root.mapToItem(host, 0, -list.height - 4);
            list.x = Math.max(8, Math.min(p.x, host.width - list.width - 8));
            list.y = p.y;
        }
        highlighted = Math.max(0, indexOfCurrent());
        popup.visible = true;
        root.forceActiveFocus();
    }
    function close() { popup.visible = false; }
    function choose(i) {
        if (i < 0 || i >= model.length)
            return;
        close();
        picked(model[i].id);
    }

    Keys.onPressed: event => {
        if (!popup.visible) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space
                || event.key === Qt.Key_Down) {
                open();
                event.accepted = true;
            }
            return;
        }
        if (event.key === Qt.Key_Down) { highlighted = Math.min(model.length - 1, highlighted + 1); event.accepted = true; }
        else if (event.key === Qt.Key_Up) { highlighted = Math.max(0, highlighted - 1); event.accepted = true; }
        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) { choose(highlighted); event.accepted = true; }
        else if (event.key === Qt.Key_Escape || event.key === Qt.Key_Tab) { close(); event.accepted = event.key === Qt.Key_Escape; }
    }
    onActiveFocusChanged: if (!activeFocus) close()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 8
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: root.currentLabel()
            color: Tokens.textPrimary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            elide: Text.ElideRight
        }
        Glyph { name: "chevron-down"; size: 14; color: Tokens.textTertiary }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible ? root.close() : root.open()
    }

    // Full-window layer: a click outside the list closes it.
    Item {
        id: popup
        readonly property bool opened: visible
        function close() { root.close(); }
        visible: false
        z: 1000
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
        Rectangle {
            id: list
            width: Math.max(root.width, popupCol.implicitWidth + 12)
            height: Math.min(popupCol.implicitHeight + 12, 320)
            radius: Tokens.radiusMd
            color: Tokens.bgElevated
            border.color: Tokens.borderSubtle
            clip: true
            MouseArea { anchors.fill: parent }
            Flickable {
                anchors.fill: parent
                anchors.margins: 6
                contentHeight: popupCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ColumnLayout {
                    id: popupCol
                    width: parent.width
                    spacing: 1
                    Repeater {
                        model: root.model
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 32
                            Layout.preferredWidth: optText.implicitWidth + 44
                            radius: Math.max(3, Tokens.radiusSm)
                            color: root.highlighted === index ? Tokens.hoverFill : "transparent"
                            Text {
                                id: optText
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData.label
                                color: root.current === modelData.id ? Tokens.themeAccent : Tokens.textPrimary
                                font.family: Tokens.fontSans
                                font.pixelSize: 13
                            }
                            Glyph {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.current === modelData.id
                                name: "check"
                                size: 14
                                color: Tokens.themeAccent
                            }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.highlighted = index
                                onClicked: root.choose(index)
                            }
                        }
                    }
                }
            }
        }
    }
}
