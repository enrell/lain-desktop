import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Comic/manga reader (web /read/[id], server D-085). Pages come from
// GET /api/items/{id}/pages; progress uses the web encoding (1-based page
// as position, page count as duration) so Continue reading resumes here.
// Keys: ←/→ turn pages (flipped for right-to-left), Space next, r flips
// direction, d toggles two-page spreads, h hides the chrome, n/p next or
// previous chapter, Esc goes back.
Rectangle {
    id: root
    color: "#000000"
    focus: visible

    property var media
    signal back()
    signal openMedia(var media)

    readonly property var view: server.readerView || ({})
    readonly property var pages: view.pages || []
    readonly property string itemId: media ? media.id : ""
    readonly property bool ready: view.item_id === itemId && pages.length > 0
    property int page: 0
    property bool ui: true
    property string direction: "ltr"
    property bool dual: false
    readonly property bool rtl: direction === "rtl"
    readonly property int step: dual ? 2 : 1

    function close() { saveTimer.flush(); back(); }
    function prefKey(k) { return "reader/" + (media ? media.series_id || media.id : "") + "/" + k; }
    function load() {
        if (!itemId)
            return;
        page = 0;
        server.loadReader(itemId);
    }
    onItemIdChanged: if (visible) load()
    onVisibleChanged: if (visible) { load(); forceActiveFocus(); } else saveTimer.flush()
    onReadyChanged: {
        if (!ready)
            return;
        var saved = String(server.pref(prefKey("direction"), ""));
        direction = saved === "rtl" || saved === "ltr" ? saved : (view.direction || "ltr");
        dual = server.pref(prefKey("dual"), false) === true || server.pref(prefKey("dual"), "false") === "true";
        page = server.readerStartPage(itemId, pages.length);
    }

    function go(delta) {
        if (!ready)
            return;
        var next = Math.max(0, Math.min(pages.length - 1, page + delta * step));
        if (next === page)
            return;
        page = next;
        saveTimer.restart();
    }
    function forward() { go(1); }
    function backward() { go(-1); }
    // Physical arrow keys follow the reading direction.
    function turnLeft() { rtl ? forward() : backward(); }
    function turnRight() { rtl ? backward() : forward(); }
    function toggleDirection() {
        direction = rtl ? "ltr" : "rtl";
        server.setPref(prefKey("direction"), direction);
    }
    function toggleDual() {
        dual = !dual;
        server.setPref(prefKey("dual"), dual);
    }
    function chapter(delta) {
        var id = "";
        if (delta > 0) {
            id = server.followingEpisodeIdFor(itemId);
        } else {
            var s = server.series || [];
            for (var i = 0; i < s.length; ++i) {
                if (s[i].id !== media.series_id)
                    continue;
                var flat = [];
                (s[i].seasons || []).forEach(se => flat = flat.concat(se.episodes || []));
                for (var j = 0; j < flat.length; ++j)
                    if (flat[j].id === itemId && j > 0)
                        id = flat[j - 1].id;
            }
        }
        if (!id)
            return;
        saveTimer.flush();
        var cat = server.catalog || [];
        for (var k = 0; k < cat.length; ++k)
            if (cat[k].id === id) {
                root.openMedia(cat[k]);
                return;
            }
    }

    Timer {
        id: saveTimer
        interval: 1500
        function flush() {
            if (running) {
                stop();
                triggered();
            }
        }
        onTriggered: if (root.ready) server.saveReaderProgress(root.itemId, root.page + (root.dual ? 1 : 0), root.pages.length)
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier))
            return;
        var k = event.key;
        if (k === Qt.Key_Left) turnLeft();
        else if (k === Qt.Key_Right) turnRight();
        else if (k === Qt.Key_Space || k === Qt.Key_PageDown) forward();
        else if (k === Qt.Key_Backspace || k === Qt.Key_PageUp) backward();
        else if (k === Qt.Key_Home) { page = 0; saveTimer.restart(); }
        else if (k === Qt.Key_End) { page = Math.max(0, pages.length - 1); saveTimer.restart(); }
        else if (k === Qt.Key_R) toggleDirection();
        else if (k === Qt.Key_D) toggleDual();
        else if (k === Qt.Key_H) ui = !ui;
        else if (k === Qt.Key_N || k === Qt.Key_BracketRight) chapter(1);
        else if (k === Qt.Key_P || k === Qt.Key_BracketLeft) chapter(-1);
        else if (k === Qt.Key_Escape) { saveTimer.flush(); back(); }
        else return;
        event.accepted = true;
    }

    // --------------------------------------------------------------- pages
    Row {
        id: spread
        anchors.centerIn: parent
        layoutDirection: root.rtl ? Qt.RightToLeft : Qt.LeftToRight
        spacing: 0
        visible: root.ready
        Repeater {
            model: root.ready ? (root.dual && root.page + 1 < root.pages.length ? 2 : 1) : 0
            delegate: Image {
                required property int index
                readonly property var info: root.pages[root.page + index] || {}
                readonly property real aspect: info.width > 0 && info.height > 0 ? info.width / info.height : 0.68
                readonly property int slots: root.dual && root.page + 1 < root.pages.length ? 2 : 1
                height: Math.min(root.height, root.width / slots / aspect)
                width: height * aspect
                source: server.readerPageUrl(root.itemId, root.page + index)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                smooth: true
            }
        }
    }
    // Preload the next spread so turning a page is instant.
    Repeater {
        model: root.ready ? 2 : 0
        delegate: Image {
            required property int index
            visible: false
            asynchronous: true
            source: root.page + root.step + index < root.pages.length
                    ? server.readerPageUrl(root.itemId, root.page + root.step + index) : ""
        }
    }

    // Click halves turn pages like the web reader; the middle toggles UI.
    MouseArea {
        anchors.fill: parent
        onClicked: mouse => {
            var third = width / 3;
            if (mouse.x < third) root.turnLeft();
            else if (mouse.x > width - third) root.turnRight();
            else root.ui = !root.ui;
            root.forceActiveFocus();
        }
        onWheel: wheel => { if (wheel.angleDelta.y < 0) root.forward(); else root.backward(); }
    }

    ColumnLayout {
        anchors.centerIn: parent
        visible: !root.ready
        spacing: 12
        UiSpinner { Layout.alignment: Qt.AlignHCenter; visible: server.readerLoading; size: 22; color: "#ffffff" }
        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: server.readerError !== ""
            text: server.readerError
            color: "#ffffff"
            font.family: Tokens.fontSans
            font.pixelSize: 14
        }
        UiButton { Layout.alignment: Qt.AlignHCenter; visible: server.readerError !== ""; text: qsTr("Try again"); variant: "secondary"; onClicked: root.load() }
    }

    // --------------------------------------------------------------- chrome
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 64
        visible: root.ui
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha("#000000", 0.85) }
            GradientStop { position: 1; color: "transparent" }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            UiButton {
                objectName: "readerBack"
                text: qsTr("Back")
                icon: "arrow-left"
                variant: "ghost"
                size: "sm"
                onClicked: { saveTimer.flush(); root.back(); }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    Layout.fillWidth: true
                    text: root.media ? (root.media.displayTitle || root.media.title) : ""
                    color: "#ffffff"
                    font.family: Tokens.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: String(root.view.kind || "").toUpperCase() + (root.view.format ? " · " + String(root.view.format).toUpperCase() : "")
                    color: Qt.alpha("#ffffff", 0.55)
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                }
            }
            UiButton {
                text: root.rtl ? qsTr("Right to left") : qsTr("Left to right")
                icon: "rotate-ccw"
                variant: "ghost"
                size: "sm"
                Accessible.name: qsTr("Reading direction (r)")
                onClicked: root.toggleDirection()
            }
            UiButton {
                text: root.dual ? qsTr("Two pages") : qsTr("One page")
                icon: root.dual ? "columns" : "book"
                variant: "ghost"
                size: "sm"
                Accessible.name: qsTr("Page layout (d)")
                onClicked: root.toggleDual()
            }
        }
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 56
        visible: root.ui && root.ready
        gradient: Gradient {
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 1; color: Qt.alpha("#000000", 0.85) }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            spacing: 16
            // Scrubber: fills in reading direction.
            Rectangle {
                id: track
                Layout.fillWidth: true
                implicitHeight: 4
                radius: 2
                color: Qt.alpha("#ffffff", 0.2)
                readonly property real ratio: root.pages.length > 1 ? root.page / (root.pages.length - 1) : 1
                Rectangle {
                    x: root.rtl ? parent.width - width : 0
                    width: parent.width * track.ratio
                    height: parent.height
                    radius: 2
                    color: Tokens.themeAccent
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    onClicked: mouse => {
                        var r = Math.max(0, Math.min(1, (mouse.x - 8) / track.width));
                        if (root.rtl)
                            r = 1 - r;
                        root.page = Math.round(r * (root.pages.length - 1));
                        saveTimer.restart();
                    }
                }
            }
            Text {
                objectName: "readerCounter"
                text: (root.page + 1) + (root.dual && root.page + 1 < root.pages.length ? "–" + (root.page + 2) : "") + " / " + root.pages.length
                color: "#ffffff"
                font.family: Tokens.fontFamily
                font.pixelSize: 12
            }
        }
    }
}
