import QtQuick
import Lain

// The pre-made avatars (server D-086): flat geometric faces, one hue each
// over a dark field. Ids and art match web lib/components/profile/Mascot.
Canvas {
    id: root
    property string mascotId: "wired"
    // Clip to a circle (avatars); the profile grid shows the square art.
    property bool round: false
    implicitWidth: 48
    implicitHeight: 48
    antialiasing: true

    readonly property var hues: ({
        "wired": "#00bfb8", "moth": "#dbb155", "static": "#979fab", "orbit": "#8d90ff",
        "glyph": "#df86d7", "shell": "#f28058", "neon": "#6fda75", "void": "#9867e1"
    })
    readonly property color hue: hues[mascotId] || Tokens.themeAccent
    readonly property color ink: "#07080b"

    onMascotIdChanged: requestPaint()
    onRoundChanged: requestPaint()
    onWidthChanged: requestPaint()

    function circle(cx, cy, r) {
        return "M" + (cx - r) + " " + cy + " A" + r + " " + r + " 0 1 0 " + (cx + r) + " " + cy
             + " A" + r + " " + r + " 0 1 0 " + (cx - r) + " " + cy + " Z";
    }
    function ellipse(cx, cy, rx, ry) {
        return "M" + (cx - rx) + " " + cy + " A" + rx + " " + ry + " 0 1 0 " + (cx + rx) + " " + cy
             + " A" + rx + " " + ry + " 0 1 0 " + (cx - rx) + " " + cy + " Z";
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.save();
        ctx.scale(width / 64, height / 64);
        if (round) {
            ctx.path = circle(32, 32, 32);
            ctx.clip();
        }
        var h = String(hue);
        function fill(d, c, a) {
            ctx.globalAlpha = a === undefined ? 1 : a;
            ctx.fillStyle = c;
            ctx.path = d;
            ctx.fill();
            ctx.globalAlpha = 1;
        }
        function line(d, c, w, a) {
            ctx.globalAlpha = a === undefined ? 1 : a;
            ctx.strokeStyle = c;
            ctx.lineWidth = w;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.path = d;
            ctx.stroke();
            ctx.globalAlpha = 1;
        }
        fill("M0 0 H64 V64 H0 Z", "#0d0f15");
        fill("M0 0 H64 V64 H0 Z", h, 0.14);
        switch (mascotId) {
        case "wired":
            line("M20 14 C18 6 10 6 8 0 M44 14 C46 6 54 6 56 0", h, 2);
            fill(circle(32, 34, 20), h);
            fill("M21 30 h7 v7 h-7 Z M36 30 h7 v7 h-7 Z", ink);
            line("M26 45 h12", ink, 2.5);
            line("M0 58 H20 L26 52 H64", h, 1.5, 0.6);
            break;
        case "moth":
            fill("M32 22 L6 10 L12 40 L32 34 Z M32 22 L58 10 L52 40 L32 34 Z", h);
            fill("M32 34 L16 54 L32 46 L48 54 Z", h, 0.65);
            fill("M29 21 A3 3 0 0 1 35 21 V45 A3 3 0 0 1 29 45 Z", ink);
            fill(circle(20, 24, 3.5) + " " + circle(44, 24, 3.5), ink);
            line("M30 18 L24 8 M34 18 L40 8", h, 1.8);
            break;
        case "static":
            fill("M16 14 H48 A6 6 0 0 1 54 20 V44 A6 6 0 0 1 48 50 H16 A6 6 0 0 1 10 44 V20 A6 6 0 0 1 16 14 Z", h);
            line("M14 20 H50 M14 26 H50 M14 32 H50 M14 38 H50 M14 44 H50", ink, 1, 0.25);
            fill("M20 26 h8 v4 h-8 Z M36 26 h8 v4 h-8 Z", ink);
            line("M24 40 h4 v-3 h8 v3 h4", ink, 2);
            line("M24 50 L20 58 M40 50 L44 58", h, 2.5);
            break;
        case "orbit":
            ctx.save();
            ctx.translate(32, 34);
            ctx.rotate(-18 * Math.PI / 180);
            line(ellipse(0, 0, 28, 8), h, 2, 0.5);
            ctx.restore();
            fill(circle(32, 32, 16), h);
            line("M5 42 A28 8 -18 0 0 59 26", h, 2.5);
            fill(circle(26, 30, 2.6) + " " + circle(38, 30, 2.6), ink);
            line("M28 37 Q32 40 36 37", ink, 2);
            fill(circle(54, 12, 2.5), h);
            break;
        case "glyph":
            fill("M14 56 V30 A18 18 0 0 1 50 30 V56 L44 50 L38 56 L32 50 L26 56 L20 50 Z", h);
            fill(ellipse(32, 31, 10, 6.5), ink);
            fill(circle(32, 31, 3.2), h);
            line("M20 20 L24 23 M44 20 L40 23", ink, 2);
            break;
        case "shell":
            fill(circle(36, 30, 18), h);
            line("M36 26 A4 4 0 1 1 32 30 A8 8 0 1 1 40 38 A12 12 0 1 1 28 26", ink, 2.2, 0.7);
            line("M6 52 H48 Q54 52 54 46", h, 6);
            line("M12 52 V40 M18 52 V42", h, 2);
            fill(circle(12, 38, 2.2) + " " + circle(18, 40, 2.2), h);
            break;
        case "neon":
            line("M14 22 L16 8 L26 17 H38 L48 8 L50 22 V38 A18 18 0 0 1 14 38 Z", h, 3);
            line("M22 32 L28 29 M42 32 L36 29", h, 3);
            line("M29 41 L32 44 L35 41", h, 2.5);
            line("M4 40 H12 M52 40 H60 M4 46 H11 M53 46 H60", h, 1.5, 0.6);
            break;
        case "void":
            line(circle(32, 32, 24), h, 1.5, 0.35);
            // Dashed ring: 9-unit dashes, 5-unit gaps along r=19.
            for (var i = 0; i < 9; ++i) {
                var a0 = i * 2 * Math.PI / 8.5;
                var a1 = a0 + 9 / 19;
                ctx.beginPath();
                ctx.strokeStyle = h;
                ctx.lineWidth = 3;
                ctx.lineCap = "butt";
                ctx.arc(32, 32, 19, a0, Math.min(a1, 2 * Math.PI), false);
                ctx.stroke();
            }
            fill(circle(32, 32, 13), ink);
            fill(ellipse(32, 32, 7, 4.5), h);
            fill(circle(32, 32, 2.2), ink);
            break;
        }
        ctx.restore();
    }
}
