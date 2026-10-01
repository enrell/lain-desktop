import QtQuick
import Lain

// Line icons in the lucide style the web uses (24×24 grid, 2px stroke),
// drawn from SVG path data so no icon font or image plugin is needed.
Canvas {
    id: root
    property string name: ""
    property color color: Tokens.textSecondary
    property real stroke: 2
    property bool filled: false
    property int size: 16
    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    antialiasing: true
    renderStrategy: Canvas.Cooperative

    function circle(cx, cy, r) {
        return "M" + (cx - r) + " " + cy + " A" + r + " " + r + " 0 1 0 " + (cx + r) + " " + cy
             + " A" + r + " " + r + " 0 1 0 " + (cx - r) + " " + cy;
    }

    readonly property var paths: ({
        "play": "M6 3 L20 12 L6 21 Z",
        "x": "M18 6 L6 18 M6 6 L18 18",
        "check": "M20 6 L9 17 L4 12",
        "plus": "M5 12 H19 M12 5 V19",
        "chevron-right": "M9 18 L15 12 L9 6",
        "chevron-left": "M15 18 L9 12 L15 6",
        "chevron-down": "M6 9 L12 15 L18 9",
        "arrow-up": "M12 19 V5 M5 12 L12 5 L19 12",
        "arrow-left": "M19 12 H5 M12 19 L5 12 L12 5",
        "trash": "M3 6 H21 M19 6 V20 A2 2 0 0 1 17 22 H7 A2 2 0 0 1 5 20 V6 M8 6 V4 A2 2 0 0 1 10 2 H14 A2 2 0 0 1 16 4 V6",
        "folder": "M20 20 A2 2 0 0 0 22 18 V8 A2 2 0 0 0 20 6 H12.1 A2 2 0 0 1 10.4 5.1 L9.6 3.9 A2 2 0 0 0 7.9 3 H4 A2 2 0 0 0 2 5 V18 A2 2 0 0 0 4 20 Z",
        "folder-plus": "M12 10 V16 M9 13 H15 M20 20 A2 2 0 0 0 22 18 V8 A2 2 0 0 0 20 6 H12.1 A2 2 0 0 1 10.4 5.1 L9.6 3.9 A2 2 0 0 0 7.9 3 H4 A2 2 0 0 0 2 5 V18 A2 2 0 0 0 4 20 Z",
        "refresh": "M3 12 A9 9 0 0 1 18 5.3 L21 8 M21 3 V8 H16 M21 12 A9 9 0 0 1 6 18.7 L3 16 M8 16 H3 V21",
        "search": circle(11, 11, 8) + " M21 21 L16.65 16.65",
        "log-out": "M9 21 H5 A2 2 0 0 1 3 19 V5 A2 2 0 0 1 5 3 H9 M16 17 L21 12 L16 7 M21 12 H9",
        "user": circle(12, 8, 5) + " M20 21 A8 8 0 0 0 4 21",
        "users": circle(9, 7, 4) + " M16 21 V19 A4 4 0 0 0 12 15 H6 A4 4 0 0 0 2 19 V21 M16 3.13 A4 4 0 0 1 16 10.87 M22 21 V19 A4 4 0 0 0 19 15.13",
        "sliders": "M4 21 V14 M4 10 V3 M12 21 V12 M12 8 V3 M20 21 V16 M20 12 V3 M1 14 H7 M9 8 H15 M17 16 H23",
        "info": circle(12, 12, 10) + " M12 16 V12 M12 8 H12.01",
        "alert": circle(12, 12, 10) + " M12 8 V12 M12 16 H12.01",
        "check-circle": circle(12, 12, 10) + " M9 12 L11 14 L15 10",
        "key": circle(7.5, 15.5, 5.5) + " M21 2 L11.4 11.6 M15.5 7.5 L18.5 10.5 M19 5 L21.5 7.5",
        "upload": "M21 15 V19 A2 2 0 0 1 19 21 H5 A2 2 0 0 1 3 19 V15 M17 8 L12 3 L7 8 M12 3 V15",
        "download": "M21 15 V19 A2 2 0 0 1 19 21 H5 A2 2 0 0 1 3 19 V15 M7 10 L12 15 L17 10 M12 15 V3",
        "clipboard": "M8 2 H16 V6 H8 Z M16 4 H18 A2 2 0 0 1 20 6 V20 A2 2 0 0 1 18 22 H6 A2 2 0 0 1 4 20 V6 A2 2 0 0 1 6 4 H8",
        "unlink": "M18.84 12.25 L20.56 10.54 A5 5 0 0 0 13.46 3.44 L11.75 5.16 M5.17 11.75 L3.46 13.46 A5 5 0 0 0 10.54 20.54 L12.25 18.83 M8 2 V5 M2 8 H5 M16 19 V22 M19 16 H22",
        "list": "M3 17 L5 19 L9 15 M3 7 L5 9 L9 5 M13 6 H21 M13 12 H21 M13 18 H21",
        "scan": "M3 7 V5 A2 2 0 0 1 5 3 H7 M17 3 H19 A2 2 0 0 1 21 5 V7 M21 17 V19 A2 2 0 0 1 19 21 H17 M7 21 H5 A2 2 0 0 1 3 19 V17 M7 12 H17",
        "book": "M12 7 V21 M3 18 A1 1 0 0 1 2 17 V4 A1 1 0 0 1 3 3 H8 A4 4 0 0 1 12 7 A4 4 0 0 1 16 3 H21 A1 1 0 0 1 22 4 V17 A1 1 0 0 1 21 18 H15 A3 3 0 0 0 12 21 A3 3 0 0 0 9 18 Z",
        "rotate-ccw": "M3 12 A9 9 0 1 0 12 3 A9.75 9.75 0 0 0 5.26 5.74 L3 8 M3 3 V8 H8",
        "sparkles": "M12 3 L13.9 8.1 L19 10 L13.9 11.9 L12 17 L10.1 11.9 L5 10 L10.1 8.1 Z M19 17 V21 M17 19 H21",
        "home": "M3 10 L12 3 L21 10 V20 A1 1 0 0 1 20 21 H15 V14 H9 V21 H4 A1 1 0 0 1 3 20 Z",
        "film": "M3 3 H21 V21 H3 Z M7 3 V21 M17 3 V21 M3 7.5 H7 M3 12 H21 M3 16.5 H7 M17 7.5 H21 M17 16.5 H21",
        "shield": "M20 13 C20 18 16.5 20.5 12.3 21.9 A1 1 0 0 1 11.7 21.9 C7.5 20.5 4 18 4 13 V6 A1 1 0 0 1 5 5 C7 5 9.5 3.8 11.2 2.3 A1.2 1.2 0 0 1 12.8 2.3 C14.5 3.8 17 5 19 5 A1 1 0 0 1 20 6 Z",
        "plug": "M12 22 V17 M9 8 V2 M15 8 V2 M18 8 V13 A4 4 0 0 1 14 17 H10 A4 4 0 0 1 6 13 V8 Z",
        "database": "M3 5 A9 3 0 0 0 21 5 A9 3 0 0 0 3 5 M3 5 V19 A9 3 0 0 0 21 19 V5 M3 12 A9 3 0 0 0 21 12",
        "cpu": "M6 6 H18 V18 H6 Z M9 9 H15 V15 H9 Z M9 2 V6 M15 2 V6 M9 18 V22 M15 18 V22 M2 9 H6 M2 15 H6 M18 9 H22 M18 15 H22",
        "link": "M10 13 A5 5 0 0 0 17.54 13.54 L20.54 10.54 A5 5 0 0 0 13.46 3.46 L11.75 5.16 M14 11 A5 5 0 0 0 6.46 10.46 L3.46 13.46 A5 5 0 0 0 10.54 20.54 L12.24 18.84",
        "monitor": "M2 3 H22 V17 H2 Z M8 21 H16 M12 17 V21",
        "external": "M15 3 H21 V9 M10 14 L21 3 M18 13 V19 A2 2 0 0 1 16 21 H5 A2 2 0 0 1 3 19 V8 A2 2 0 0 1 5 6 H11",
        "maximize": "M8 3 H5 A2 2 0 0 0 3 5 V8 M21 8 V5 A2 2 0 0 0 19 3 H16 M3 16 V19 A2 2 0 0 0 5 21 H8 M16 21 H19 A2 2 0 0 0 21 19 V16",
        "columns": "M3 3 H21 V21 H3 Z M12 3 V21",
        "rows": "M3 3 H21 V21 H3 Z M3 12 H21"
    })

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onFilledChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        var d = paths[name];
        if (!d)
            return;
        ctx.save();
        var s = width / 24;
        ctx.scale(s, s);
        ctx.lineWidth = stroke;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.strokeStyle = color;
        ctx.fillStyle = color;
        ctx.path = d;
        if (filled)
            ctx.fill();
        ctx.stroke();
        ctx.restore();
    }
}
