import QtQuick
import QtQuick.Layouts
import Lain

// Web Toaster: polite bottom-right stack of short notices. Listens to the
// client's actionFinished signal; views can also call show() directly.
Item {
    id: root
    width: 384
    height: stack.implicitHeight
    property int timeout: 4200

    ListModel { id: toasts }
    property int nextId: 1

    function show(kind, message) {
        if (!message)
            return;
        toasts.append({ tid: nextId++, kind: kind, message: message });
        while (toasts.count > 4)
            toasts.remove(0);
    }
    function dismiss(tid) {
        for (var i = 0; i < toasts.count; ++i)
            if (toasts.get(i).tid === tid) {
                toasts.remove(i);
                return;
            }
    }

    Connections {
        target: server
        function onActionFinished(action, ok, message) {
            root.show(ok ? "success" : "error", message);
        }
    }

    ColumnLayout {
        id: stack
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 8
        Repeater {
            model: toasts
            delegate: Rectangle {
                id: toast
                required property int tid
                required property string kind
                required property string message
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + 24
                radius: Tokens.radiusMd
                color: Qt.alpha(Tokens.bgElevated, 0.97)
                border.color: Tokens.borderSubtle
                Accessible.role: Accessible.AlertMessage
                Accessible.name: message
                RowLayout {
                    id: row
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    Glyph {
                        Layout.alignment: Qt.AlignTop
                        name: toast.kind === "error" ? "alert" : toast.kind === "success" ? "check-circle" : "info"
                        color: toast.kind === "error" ? Tokens.danger : toast.kind === "success" ? Tokens.success : Tokens.themeAccent
                        size: 16
                    }
                    Text {
                        Layout.fillWidth: true
                        text: toast.message
                        color: Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    Glyph {
                        Layout.alignment: Qt.AlignTop
                        name: "x"
                        size: 14
                        color: Tokens.textTertiary
                        TapHandler { onTapped: root.dismiss(toast.tid) }
                    }
                }
                Timer {
                    running: true
                    interval: root.timeout
                    onTriggered: root.dismiss(toast.tid)
                }
            }
        }
    }
}
