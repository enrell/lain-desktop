import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// libmpv player with timeline, volume, tracks, Anime4K, and OSD.
// The source comes from the direct-play plan, and progress uses bounded writes.
Item {
    id: playerRoot
    Layout.fillWidth: true
    // Full viewport height like the web player. `page` is an id in
    // Main.qml — invisible from this file — so bind to the window.
    Layout.preferredHeight: Math.max(620, (playerRoot.Window ? playerRoot.Window.height : 0) - Tokens.headerHeight)

    property var media
    property var series: null
    // Exposed for tests; the player internals otherwise stay private.
    readonly property alias mpvItem: mpv
    property bool hasStream: false
    property bool controlsVisible: true
    property string osdText: ""
    property real scrubValue: 0
    property real pendingResume: 0
    property bool resumePending: false
    property string playError: ""

    signal toggleFullscreen()
    signal back()
    signal playMedia(var media)

    // Web parity: series playback keeps an episode rail on the right when
    // the window is wide enough (hidden in fullscreen).
    readonly property var seriesEpisodes: {
        if (!series)
            return [];
        var out = [];
        var seasons = series.seasons || [];
        for (var i = 0; i < seasons.length; ++i) {
            var eps = seasons[i].episodes || [];
            for (var j = 0; j < eps.length; ++j)
                out.push(eps[j]);
        }
        var sp = series.specials || [];
        for (var k = 0; k < sp.length; ++k)
            out.push(sp[k]);
        return out;
    }
    readonly property int sidebarWidth: seriesEpisodes.length > 1 && width >= 1000 ? 320 : 0

    function episodeLabel(it) {
        if (!it)
            return "";
        if (it.season > 0 && it.episode > 0)
            return "S" + (it.season < 10 ? "0" : "") + it.season + "E" + (it.episode < 10 ? "0" : "") + it.episode;
        if (it.episode > 0)
            return qsTr("Episode %1").arg(it.episode);
        return qsTr("Special");
    }

    function episodeStatus(it) {
        if (!it)
            return "";
        if (it.missing)
            return qsTr("Missing from disk");
        if (it.completed)
            return qsTr("Watched");
        if (it.duration_sec > 0 && it.position_sec > 0)
            return qsTr("Resume at %1%").arg(Math.min(100, Math.round(100 * it.position_sec / it.duration_sec)));
        return qsTr("Not watched");
    }

    function fmt(s) {
        if (!isFinite(s) || s < 0 || s === null)
            return "--:--";
        s = Math.floor(s);
        var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        var mm = (h > 0 && m < 10 ? "0" : "") + m;
        var ss = (sec < 10 ? "0" : "") + sec;
        return (h > 0 ? h + ":" : "") + mm + ":" + ss;
    }
    // Effects picker labels mirror the web player's EFFECT_PRESETS.
    function shaderLabel(mode) {
        switch (mode) {
        case "anime4k-a": return qsTr("Anime4K Mode A (Ctrl+1)");
        case "anime4k-aa": return qsTr("Anime4K Mode A+A (Ctrl+2)");
        case "anime4k-lite": return qsTr("Anime4K Lite (no upscale)");
        case "anime4k-dog-x2": return qsTr("Anime4K DoG ×2");
        default: return qsTr("Off");
        }
    }
    function trackLabel(t) {
        var s = t.lang ? t.lang : "";
        if (t.title)
            s = s ? s + " · " + t.title : t.title;
        return s === "" ? qsTr("Track %1").arg(t.id) : s;
    }
    function wake() {
        controlsVisible = true;
        hideTimer.restart();
    }
    function osd(t) {
        osdText = t;
        osdTimer.restart();
    }
    function togglePause() {
        mpv.togglePause();
        report(false);
        wake();
    }
    function seekBy(d) { mpv.seekBy(d); wake(); }
    function adjustVolume(d) { mpv.setVolume(mpv.volume + d); osd(qsTr("Volume %1").arg(Math.round(mpv.volume + d))); wake(); }
    function toggleMute() { mpv.setMuted(!mpv.muted); wake(); }
    function cycleAudio() { mpv.cycleAudio(); osd(qsTr("Audio")); wake(); }
    function cycleSubtitle() { mpv.cycleSubtitle(); osd(qsTr("Subtitles")); wake(); }
    function cycleShader() { mpv.cycleShaderPreset(); osd(mpv.shaderInfo); wake(); }

    // Episode rail navigation (n/p keys, DD-036). Skips missing files.
    function episodeIndex() {
        if (!playerRoot.media || !playerRoot.media.id)
            return -1;
        for (var i = 0; i < seriesEpisodes.length; ++i)
            if (seriesEpisodes[i].id === playerRoot.media.id)
                return i;
        return -1;
    }
    function stepEpisode(delta) {
        var i = episodeIndex();
        if (i < 0)
            return;
        for (var n = i + delta; n >= 0 && n < seriesEpisodes.length; n += delta) {
            var it = seriesEpisodes[n];
            if (!it.missing) {
                playMedia(it);
                wake();
                return;
            }
        }
        osd(delta > 0 ? qsTr("No next episode") : qsTr("No previous episode"));
    }
    // Esc tier 0: close open chrome (track pickers) before the route's
    // fullscreen/back handling. Returns true when it closed something.
    function closeChrome() {
        if (audioPopup.visible || subPopup.visible || shaderPopup.visible) {
            audioPopup.visible = false;
            subPopup.visible = false;
            shaderPopup.visible = false;
            return true;
        }
        return false;
    }

    // Report only meaningful positions; completion is reported at EOF.
    function report(completed) {
        if (!media || !media.id || !hasStream || mpv.duration <= 0)
            return;
        if (!completed && mpv.position < 1)
            return;
        server.reportProgress(media.id, mpv.position, mpv.duration, completed === true);
    }
    function teardown() {
        report(false);
        mpv.stop();
        hasStream = false;
        resumePending = false;
        pendingResume = 0;
        playError = "";
    }

    MpvItem {
        id: mpv
        anchors.fill: parent
        anchors.rightMargin: playerRoot.sidebarWidth
    }

    Connections {
        target: server
        function onPlaybackReady(url, positionSec, durationSec) {
            if (!playerRoot.visible)
                return;
            playerRoot.playError = "";
            playerRoot.hasStream = true;
            mpv.play(url);
            // DD-031: auto-resume is a user default, not forced behavior.
            if (server.autoResume && positionSec > 5 && (durationSec <= 0 || positionSec < durationSec - 5)) {
                playerRoot.pendingResume = positionSec;
                playerRoot.resumePending = true;
                playerRoot.osd(qsTr("Resuming…"));
            } else {
                playerRoot.resumePending = false;
                playerRoot.pendingResume = 0;
            }
            playerRoot.wake();
        }
        function onPlaybackFailed(reason) {
            playerRoot.playError = reason;
            playerRoot.hasStream = false;
        }
    }
    Connections {
        target: mpv
        // Duration arrives after loadfile and marks the safe resume point.
        function onDurationChanged() {
            if (playerRoot.resumePending && mpv.duration > 0) {
                mpv.seek(playerRoot.pendingResume);
                playerRoot.resumePending = false;
                playerRoot.pendingResume = 0;
            }
        }
        function onEndFile(eof) {
            if (eof && playerRoot.media && playerRoot.media.id && mpv.duration > 0) {
                server.reportProgress(playerRoot.media.id, mpv.duration, mpv.duration, true);
                // DD-031: autoplay the next episode when enabled (global
                // default plus per-series override, both resolved server-side).
                var next = server.nextEpisodeId(playerRoot.media.id);
                if (next !== "") {
                    playerRoot.osd(qsTr("Playing next episode…"));
                    server.openMedia(next);
                    server.requestPlayback(next);
                    return;
                }
            }
            playerRoot.controlsVisible = true;
        }
    }

    Timer {
        id: progressTimer
        interval: 10000
        repeat: true
        running: playerRoot.visible && playerRoot.hasStream && !mpv.paused
        onTriggered: playerRoot.report(false)
    }

    onVisibleChanged: {
        if (!visible)
            teardown();
        else
            wake();
    }

    // Any movement wakes controls; clicking the video toggles pause.
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: playerRoot.sidebarWidth
        z: 1
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: wake()
    }
    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: playerRoot.sidebarWidth
        z: 2
        onClicked: {
            audioPopup.visible = false;
            subPopup.visible = false;
            shaderPopup.visible = false;
            togglePause();
        }
    }

    Timer {
        id: hideTimer
        interval: 2800
        repeat: false
        // Hover over the chrome itself must not count as idle — otherwise
        // controls vanish under the cursor and the click lands on video.
        onTriggered: {
            if (!mpv.paused && hasStream && !topBarHover.containsMouse
                    && !bottomBarHover.containsMouse
                    && !audioPopup.visible && !subPopup.visible)
                controlsVisible = false;
        }
    }
    Timer {
        id: osdTimer
        interval: 1300
        repeat: false
        onTriggered: osdText = ""
    }
    Component.onCompleted: wake()

    // OSD central
    Text {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: -playerRoot.sidebarWidth / 2
        z: 3
        text: osdText
        color: "white"
        font.family: Tokens.fontFamily
        font.pixelSize: 17
        font.bold: true
        opacity: osdText === "" ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }

    // No source: loading, plan error, or diagnostic test pattern.
    Rectangle {
        anchors.fill: parent
        anchors.rightMargin: playerRoot.sidebarWidth
        z: 4
        color: Qt.alpha(Tokens.bgPrimary, 0.85)
        visible: !hasStream
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 12
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: playerRoot.media
                    ? (playerRoot.media.displayTitle && playerRoot.media.displayTitle !== ""
                        ? playerRoot.media.displayTitle : playerRoot.media.title)
                    : qsTr("Player")
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.sectionSize
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: playerRoot.playError === ""
                text: qsTr("Preparing playback…")
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 520
                visible: playerRoot.playError !== ""
                text: playerRoot.playError
                color: Tokens.themeUrgent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: Tokens.buttonHeight
                visible: playerRoot.playError !== ""
                radius: Tokens.radiusMd
                color: Tokens.themeAccent
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Try again")
                    color: "black"
                    font.family: Tokens.fontFamily
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        playerRoot.playError = "";
                        if (playerRoot.media && playerRoot.media.id)
                            server.requestPlayback(playerRoot.media.id);
                    }
                }
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 220
                Layout.preferredHeight: Tokens.buttonHeight
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Test pattern")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.bold: true
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: { mpv.playTestPattern(); playerRoot.hasStream = true; playerRoot.wake(); }
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: mpv.errorText !== ""
                text: mpv.errorText
                color: Tokens.themeUrgent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
        }
    }

    // Barra superior
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: playerRoot.sidebarWidth
        anchors.top: parent.top
        height: 64
        z: 5
        color: "transparent"
        visible: controlsVisible
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.75) }
            GradientStop { position: 1.0; color: Qt.alpha(Tokens.bgPrimary, 0.0) }
        }
        MouseArea {
            id: topBarHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 12
            PlayerButton {
                glyph: "\uf053"
                glyphSize: 15
                label: qsTr("Back")
                onPressed: back()
            }
            Text {
                Layout.fillWidth: true
                text: playerRoot.media
                    ? (playerRoot.media.displayTitle && playerRoot.media.displayTitle !== ""
                        ? playerRoot.media.displayTitle : playerRoot.media.title)
                    : qsTr("Test Pattern")
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 16
                elide: Text.ElideRight
            }
            Text {
                text: mpv.shaderInfo
                color: Tokens.textTertiary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize - 1
            }
        }
    }

    // Controles inferiores
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: playerRoot.sidebarWidth
        anchors.bottom: parent.bottom
        height: 108
        z: 5
        color: "transparent"
        visible: controlsVisible
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Tokens.bgPrimary, 0.0) }
            GradientStop { position: 1.0; color: Qt.alpha(Tokens.bgPrimary, 0.85) }
        }
        MouseArea {
            id: bottomBarHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 20
            anchors.rightMargin: 20
            anchors.bottomMargin: 10
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Text {
                    text: fmt(timelineBar.scrubbing ? playerRoot.scrubValue : mpv.position)
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                SeekBar {
                    id: timelineBar
                    Layout.fillWidth: true
                    from: 0
                    to: mpv.duration > 0 ? mpv.duration : 1
                    value: scrubbing ? playerRoot.scrubValue : mpv.position
                    fillColor: media && media.accent ? media.accent : Tokens.themeAccent
                    onScrubbed: v => { playerRoot.scrubValue = v; }
                    onReleased: v => {
                        mpv.seek(v);
                        playerRoot.scrubValue = v;
                        if (playerRoot.media && playerRoot.media.id && mpv.duration > 0)
                            server.reportProgress(playerRoot.media.id, v, mpv.duration, false);
                    }
                }
                Text {
                    text: fmt(mpv.duration)
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                PlayerButton { glyph: "-10s"; glyphSize: 12; bold: true; label: qsTr("Rewind 10 seconds"); onPressed: seekBy(-10) }
                PlayerButton { glyph: mpv.paused ? "\uf04b" : "\uf04c"; glyphSize: 18; label: mpv.paused ? qsTr("Play") : qsTr("Pause"); onPressed: togglePause() }
                PlayerButton { glyph: "+10s"; glyphSize: 12; bold: true; label: qsTr("Forward 10 seconds"); onPressed: seekBy(10) }
                Item { Layout.fillWidth: true }
                PlayerButton { glyph: mpv.muted ? "\uf026" : "\uf028"; glyphSize: 16; label: mpv.muted ? qsTr("Unmute") : qsTr("Mute"); onPressed: toggleMute() }
                SeekBar {
                    Layout.preferredWidth: 90
                    from: 0
                    to: 100
                    value: mpv.volume
                    fillColor: Tokens.textPrimary
                    onScrubbed: v => mpv.setVolume(v)
                    onReleased: v => mpv.setVolume(v)
                }
                PlayerButton { glyph: "\uf001"; glyphSize: 15; label: qsTr("Audio track"); onPressed: { audioPopup.visible = !audioPopup.visible; subPopup.visible = false; } }
                PlayerButton { glyph: "\uf20a"; glyphSize: 15; label: qsTr("Subtitles"); onPressed: { subPopup.visible = !subPopup.visible; audioPopup.visible = false; } }
                PlayerButton { glyph: "\uf0d0"; glyphSize: 15; label: qsTr("Video effects"); onPressed: { shaderPopup.visible = !shaderPopup.visible; audioPopup.visible = false; subPopup.visible = false; } }
                PlayerButton { glyph: "\uf065"; glyphSize: 14; label: qsTr("Toggle fullscreen"); onPressed: toggleFullscreen() }
            }
        }
    }

    // Audio-track popup.
    Rectangle {
        id: audioPopup
        visible: false
        z: 6
        anchors.right: parent.right
        anchors.rightMargin: playerRoot.sidebarWidth + 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 118
        width: 280
        height: Math.min(300, trackList.implicitHeight + 28)
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        Column {
            id: trackList
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            Text { text: qsTr("Audio"); color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: Tokens.metaSize }
            Repeater {
                model: mpv.audioTracks
                delegate: Text {
                    width: trackList.width
                    text: (mpv.audioId === modelData.id ? "● " : "○ ") + trackLabel(modelData)
                    color: mpv.audioId === modelData.id ? Tokens.themeAccent : Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { mpv.setAudioTrack(modelData.id); audioPopup.visible = false; }
                    }
                }
            }
        }
    }

    // Subtitle-track popup.
    Rectangle {
        id: subPopup
        visible: false
        z: 6
        anchors.right: parent.right
        anchors.rightMargin: playerRoot.sidebarWidth + 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 118
        width: 280
        height: Math.min(300, subList.implicitHeight + 28)
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        Column {
            id: subList
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            Text { text: qsTr("Subtitles"); color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: Tokens.metaSize }
            Text {
                width: subList.width
                text: (mpv.subtitleId < 0 ? "● " : "○ ") + qsTr("Off")
                color: mpv.subtitleId < 0 ? Tokens.themeAccent : Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                MouseArea {
                    anchors.fill: parent
                    onClicked: { mpv.setSubtitleTrack(-1); subPopup.visible = false; }
                }
            }
            Repeater {
                model: mpv.subtitleTracks
                delegate: Text {
                    width: subList.width
                    text: (mpv.subtitleId === modelData.id ? "● " : "○ ") + trackLabel(modelData)
                    color: mpv.subtitleId === modelData.id ? Tokens.themeAccent : Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    elide: Text.ElideRight
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { mpv.setSubtitleTrack(modelData.id); subPopup.visible = false; }
                    }
                }
            }
        }
    }

    // Video-effects picker — the web player's Effects selector (DD-035):
    // the bundled Anime4K presets, chosen by name instead of blind-cycled.
    Rectangle {
        id: shaderPopup
        visible: false
        z: 6
        anchors.right: parent.right
        anchors.rightMargin: playerRoot.sidebarWidth + 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 118
        width: 280
        height: Math.min(300, shaderList.implicitHeight + 28)
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        Column {
            id: shaderList
            anchors.fill: parent
            anchors.margins: 14
            spacing: 4
            Text { text: qsTr("Effects"); color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: Tokens.metaSize }
            Repeater {
                model: mpv.shaderModes
                delegate: Rectangle {
                    required property var modelData
                    width: shaderList.width
                    height: 30
                    radius: 6
                    color: "transparent"
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 0
                    border.color: Tokens.themeAccent
                    Accessible.role: Accessible.Button
                    Accessible.name: playerRoot.shaderLabel(modelData)
                    Keys.onSpacePressed: { mpv.setShaderPreset(modelData); osd(mpv.shaderInfo); shaderPopup.visible = false; }
                    Keys.onReturnPressed: { mpv.setShaderPreset(modelData); osd(mpv.shaderInfo); shaderPopup.visible = false; }
                    Keys.onEnterPressed: { mpv.setShaderPreset(modelData); osd(mpv.shaderInfo); shaderPopup.visible = false; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (mpv.shaderPreset === modelData ? "● " : "○ ") + playerRoot.shaderLabel(modelData)
                        color: mpv.shaderPreset === modelData ? Tokens.themeAccent : Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: Tokens.metaSize
                        elide: Text.ElideRight
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { mpv.setShaderPreset(modelData); osd(mpv.shaderInfo); shaderPopup.visible = false; }
                    }
                }
            }
        }
    }

    // Episode rail for series playback (web player sidebar): still, SxxExx
    // label, per-episode status. Clicking switches episodes in place.
    Rectangle {
        visible: playerRoot.sidebarWidth > 0
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: playerRoot.sidebarWidth
        z: 7
        color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeFg, 0.04))
        border.color: Qt.alpha(Tokens.themeFg, 0.06)
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            ColumnLayout {
                Layout.fillWidth: true
                Layout.margins: 16
                Layout.bottomMargin: 12
                spacing: 2
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 0 }
                Text {
                    Layout.fillWidth: true
                    text: series ? series.title : ""
                    color: Tokens.textPrimary
                    font.family: Tokens.fontSans
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    text: seriesEpisodes.length === 1
                        ? qsTr("1 episode") : qsTr("%1 episodes").arg(seriesEpisodes.length)
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Qt.alpha(Tokens.themeFg, 0.06) }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: seriesEpisodes
                spacing: 2
                topMargin: 8
                bottomMargin: 8
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 300
                    height: 60
                    color: modelData.id === (playerRoot.media ? playerRoot.media.id : "")
                        ? Qt.alpha(Tokens.themeFg, 0.05)
                        : "transparent"
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 12
                        Rectangle {
                            Layout.preferredWidth: 80
                            Layout.preferredHeight: 48
                            radius: 0
                            clip: true
                            color: Tokens.surface1
                            border.color: Qt.alpha(Tokens.themeFg, 0.06)
                            opacity: modelData.missing ? 0.5 : 1
                            Image {
                                anchors.fill: parent
                                source: modelData.thumb || modelData.cover || ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                visible: source !== ""
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: playerRoot.episodeLabel(modelData)
                                color: modelData.id === (playerRoot.media ? playerRoot.media.id : "")
                                    ? Tokens.themeAccent : Tokens.textTertiary
                                font.family: Tokens.fontFamily
                                font.pixelSize: 10
                                font.capitalization: Font.AllUppercase
                                font.letterSpacing: 1.4
                            }
                            Text {
                                Layout.fillWidth: true
                                text: playerRoot.episodeStatus(modelData)
                                color: modelData.missing ? Tokens.themeUrgent : Tokens.textTertiary
                                font.family: Tokens.fontSans
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !modelData.missing && modelData.id !== (playerRoot.media ? playerRoot.media.id : "")
                        hoverEnabled: true
                        onEntered: if (modelData.id !== (playerRoot.media ? playerRoot.media.id : "")) parent.color = Qt.alpha(Tokens.themeFg, 0.08)
                        onExited: parent.color = modelData.id === (playerRoot.media ? playerRoot.media.id : "")
                            ? Qt.alpha(Tokens.themeFg, 0.05) : "transparent"
                        onClicked: playerRoot.playMedia(modelData)
                    }
                }
            }
        }
    }
}
