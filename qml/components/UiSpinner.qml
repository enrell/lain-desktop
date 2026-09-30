import QtQuick
import Lain

// Small activity ring for loading buttons and panes.
Item {
    id: root
    property int size: 16
    property color color: Tokens.textTertiary
    implicitWidth: size
    implicitHeight: size
    Canvas {
        id: ring
        anchors.fill: parent
        antialiasing: true
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.lineWidth = Math.max(1.5, root.size / 9);
            ctx.lineCap = "round";
            ctx.strokeStyle = Qt.alpha(root.color, 0.25);
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, width / 2 - ctx.lineWidth, 0, 2 * Math.PI);
            ctx.stroke();
            ctx.strokeStyle = root.color;
            ctx.beginPath();
            ctx.arc(width / 2, height / 2, width / 2 - ctx.lineWidth, 0, Math.PI / 2);
            ctx.stroke();
        }
        RotationAnimator on rotation {
            running: root.visible
            from: 0; to: 360
            duration: 800
            loops: Animation.Infinite
        }
    }
    onColorChanged: ring.requestPaint()
}
