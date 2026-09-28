import QtQuick
import Lain

// Custom slider without QtQuick.Controls: drag interaction and hover thumb.
Rectangle {
    id: bar
    color: "transparent"
    height: 28

    property real from: 0
    property real to: 100
    property real value: 0
    property color fillColor: "white"
    property bool scrubbing: false
    signal scrubbed(real v)
    signal released(real v)

    function ratio() {
        if (to <= from)
            return 0;
        return Math.max(0, Math.min(1, (value - from) / (to - from)));
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Tokens.track
        Rectangle {
            width: parent.width * ratio()
            height: parent.height
            radius: 2
            color: fillColor
        }
    }
    Rectangle {
        x: parent.width * ratio() - 6
        anchors.verticalCenter: parent.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: fillColor
        visible: scrubbing || hover.containsMouse
    }
    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        onPressed: mouse => {
            bar.scrubbing = true;
            bar.scrubbed(bar.from + (bar.to - bar.from) * Math.max(0, Math.min(1, mouse.x / width)));
        }
        onPositionChanged: mouse => {
            if (pressed)
                bar.scrubbed(bar.from + (bar.to - bar.from) * Math.max(0, Math.min(1, mouse.x / width)));
        }
        onReleased: mouse => {
            bar.scrubbing = false;
            // MouseArea has its own `released` signal — qualify the SeekBar
            // signal or it recurses into this same handler.
            bar.released(bar.from + (bar.to - bar.from) * Math.max(0, Math.min(1, mouse.x / width)));
        }
    }
}
