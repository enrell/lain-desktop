import QtQuick
import QtQml
import QtQuick.Layouts
import Lain
import "components"
import "views"

Window {
    id: root
    width: 1280
    height: 800
    visible: true
    title: "Lain"
    color: Tokens.bgPrimary

    property var homeData: server.home
    property var currentMedia: server.currentMedia
    property var currentSeries: null
    property string route: "home"
    property string returnRoute: "home"
    property var readerMedia: null

    // Find the series object a normalized card belongs to (if any).
    function seriesFor(media) {
        if (!media || !media.series_id)
            return null;
        var sl = server.series || [];
        for (var i = 0; i < sl.length; ++i)
            if (sl[i].id === media.series_id)
                return sl[i];
        return null;
    }

    // Web parity: opening an episode of a multi-episode title lands on the
    // series page; single files land on the item page.
    function openMedia(m) {
        server.openMedia(m.id);
        var s = seriesFor(m);
        var count = s ? (s.episodeCount || 0) + (s.specialsCount || 0) : 0;
        root.returnRoute = root.route;
        if (s && count > 1) {
            root.currentSeries = s;
            root.route = "series";
        } else {
            root.route = "detail";
        }
    }

    function navigate(r) {
        root.route = r;
        if (r === "search")
            searchView.focusInput();
        page.contentY = 0;
    }

    function openSettings(section, anchor) {
        root.navigate("settings");
        if (section)
            settingsView.open(section, anchor || "");
    }

    function playMedia(m) {
        // Comics and manga open in the reader, not the video player (D-085).
        if (server.isReadable(m.kind)) {
            server.openMedia(m.id);
            root.readerMedia = m;
            root.returnRoute = root.route === "reader" ? root.returnRoute : root.route;
            root.route = "reader";
            return;
        }
        server.openMedia(m.id);
        server.requestPlayback(m.id);
        root.returnRoute = root.route === "player" ? root.returnRoute : root.route;
        root.route = "player";
    }

    // Content scrolls under the fixed top header (web AppShell).
    Flickable {
        id: page
        anchors.fill: parent
        anchors.topMargin: topBar.visible ? Tokens.headerHeight : 0
        visible: server.ready
        contentWidth: width
        contentHeight: content.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: content
            width: parent.width
            spacing: 0
            HomeView {
                Layout.fillWidth: true
                visible: root.route === "home"
                home: root.homeData
                onOpenMedia: m => root.openMedia(m)
                onPlayMedia: m => root.playMedia(m)
                onOpenSettings: (section, anchor) => root.openSettings(section, anchor)
                onOpenLibrary: id => {
                    root.route = "library";
                    libraryView.selectedLibrary = id;
                }
            }
            LibraryView {
                id: libraryView
                Layout.fillWidth: true
                visible: root.route === "library"
                onOpenMedia: m => root.openMedia(m)
                onOpenSeries: s => { root.returnRoute = "library"; root.currentSeries = s; root.route = "series"; }
            }
            MyListView {
                id: myListView
                Layout.fillWidth: true
                visible: root.route === "list"
                onOpenConnections: root.openSettings("connections", "anilist")
            }
            SearchView {
                id: searchView
                Layout.fillWidth: true
                visible: root.route === "search"
                onOpenMedia: m => root.openMedia(m)
            }
            SeriesView {
                Layout.fillWidth: true
                visible: root.route === "series"
                series: root.currentSeries
                onPlayMedia: m => root.playMedia(m)
                onOpenMedia: m => root.openMedia(m)
                onBack: root.route = root.returnRoute === "series" ? "library" : root.returnRoute
            }
            DetailView {
                Layout.fillWidth: true
                visible: root.route === "detail"
                media: root.currentMedia
                onOpenMedia: m => root.openMedia(m)
                onPlayMedia: m => root.playMedia(m)
                onBack: root.route = root.returnRoute === "detail" ? "home" : root.returnRoute
            }
            PlayerView {
                id: playerView
                visible: root.route === "player"
                media: root.currentMedia
                series: root.currentMedia ? root.seriesFor(root.currentMedia) : null
                onPlayMedia: m => root.playMedia(m)
                onToggleFullscreen: root.visibility = root.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
                onBack: {
                    root.route = root.returnRoute === "player" ? "home" : root.returnRoute;
                    server.refresh();
                }
            }
            ReaderView {
                id: readerView
                visible: root.route === "reader"
                Layout.fillWidth: true
                Layout.preferredHeight: root.height
                media: root.readerMedia
                onBack: {
                    root.route = root.returnRoute === "reader" ? "home" : root.returnRoute;
                    server.refresh();
                }
                onOpenMedia: m => { root.readerMedia = m; server.openMedia(m.id); }
            }
            SettingsView {
                id: settingsView
                visible: root.route === "settings"
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                scrollY: page.contentY
                onLoggedOut: root.route = "home"
            }
        }
    }

    TopBar {
        id: topBar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        z: 10
        visible: server.ready && root.visibility !== Window.FullScreen && root.route !== "player" && root.route !== "reader"
        current: root.route
        onNavigate: r => root.navigate(r)
        onOpenSettings: s => root.openSettings(s, "")
        onLogout: server.logout()
        onHelpRequested: shortcutsOverlay.open()
        onPaletteRequested: palette.open()
    }

    // Text fields eat letters themselves; shortcut matches can shadow
    // them on window context, so gate plain-letter bindings on focus.
    function typing() {
        var f = root.contentItem.activeFocusItem;
        return !!(f && f["acceptsText"] === true);
    }

    // Ctrl+F / "/" jump straight to the search page (web parity).
    Shortcut {
        enabled: server.ready
        sequence: "Ctrl+F"
        onActivated: { root.route = "search"; searchView.focusInput(); }
    }
    Shortcut {
        enabled: server.ready && !root.typing()
        sequence: "/"
        onActivated: { root.route = "search"; searchView.focusInput(); }
    }
    Shortcut { enabled: server.ready; sequence: "Alt+Left"; onActivated: root.route = "home" }
    Shortcut {
        enabled: server.ready && !root.typing()
        sequence: "?"
        onActivated: {
            if (shortcutsOverlay.visible) shortcutsOverlay.close();
            else shortcutsOverlay.open();
        }
    }

    // Vim-style g-prefix navigation (DD-036). Disabled inside the player
    // where letters are the playback map — Esc is the way out there.
    property bool gArmed: false
    Timer { id: gTimer; interval: 700; onTriggered: root.gArmed = false }
    Shortcut {
        enabled: server.ready && !root.typing() && root.route !== "player" && root.route !== "reader" && !palette.visible
        sequence: "g"
        onActivated: { root.gArmed = true; gTimer.restart(); }
    }
    // Second key of a chord. Inside Settings the web's section letters win
    // (g p profile, g l libraries, g s security…); elsewhere DD-036 applies.
    function chord(key) {
        root.gArmed = false;
        gTimer.stop();
        if (root.route === "settings" && settingsView.chord(key))
            return;
        if (key === "h") root.navigate("home");
        else if (key === "l") root.navigate("library");
        else if (key === "m") root.navigate("list");
        else if (key === "s") root.navigate("search");
        else if (key === "e") root.navigate("settings");
    }
    Instantiator {
        model: ["h", "l", "m", "s", "e", "p", "y", "c", "d", "u", "t", "i", "x", "b"]
        delegate: Shortcut {
            required property string modelData
            enabled: root.gArmed
            sequence: modelData
            onActivated: root.chord(modelData)
        }
    }
    Shortcut {
        enabled: root.route === "settings" && !root.typing()
        sequence: "]"
        onActivated: settingsView.cycle(1)
    }
    Shortcut {
        enabled: root.route === "settings" && !root.typing()
        sequence: "["
        onActivated: settingsView.cycle(-1)
    }

    // Modals, selects and menus lift themselves to the window content item
    // and expose `opened` + close(); Esc closes the topmost one.
    function closeTopOverlay() {
        var kids = root.contentItem.children;
        for (var i = kids.length - 1; i >= 0; --i) {
            var k = kids[i];
            if (k.opened === true && typeof k.close === "function") {
                k.close();
                return true;
            }
        }
        return false;
    }

    // Esc tiers: shortcuts overlay → player popups → fullscreen → back.
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (palette.visible)
                palette.close();
            else if (root.closeTopOverlay())
                return;
            else if (root.route === "reader")
                readerView.close();
            else if (shortcutsOverlay.visible)
                shortcutsOverlay.close();
            else if (root.route === "player" && playerView.closeChrome())
                return;
            else if (root.visibility === Window.FullScreen)
                root.visibility = Window.Windowed;
            else if (root.route === "detail" || root.route === "player" || root.route === "series")
                root.route = root.returnRoute;
        }
    }

    // Player shortcuts (§31 + DD-036: YouTube/vim muscle memory).
    Shortcut { enabled: root.route === "player"; sequence: "Space"; onActivated: playerView.togglePause() }
    Shortcut { enabled: root.route === "player"; sequence: "K"; onActivated: playerView.togglePause() }
    Shortcut { enabled: root.route === "player"; sequence: "Left"; onActivated: playerView.seekBy(-10) }
    Shortcut { enabled: root.route === "player"; sequence: "J"; onActivated: playerView.seekBy(-10) }
    Shortcut { enabled: root.route === "player"; sequence: "H"; onActivated: playerView.seekBy(-10) }
    Shortcut { enabled: root.route === "player"; sequence: "Right"; onActivated: playerView.seekBy(10) }
    Shortcut { enabled: root.route === "player"; sequence: "L"; onActivated: playerView.seekBy(10) }
    Shortcut { enabled: root.route === "player"; sequence: "Up"; onActivated: playerView.adjustVolume(5) }
    Shortcut { enabled: root.route === "player"; sequence: "0"; onActivated: playerView.adjustVolume(5) }
    Shortcut { enabled: root.route === "player"; sequence: "Down"; onActivated: playerView.adjustVolume(-5) }
    Shortcut { enabled: root.route === "player"; sequence: "9"; onActivated: playerView.adjustVolume(-5) }
    Shortcut { enabled: root.route === "player"; sequence: "M"; onActivated: playerView.toggleMute() }
    Shortcut { enabled: root.route === "player"; sequence: "F"; onActivated: playerView.toggleFullscreen() }
    Shortcut { enabled: root.route === "player"; sequence: "A"; onActivated: playerView.cycleAudio() }
    Shortcut { enabled: root.route === "player"; sequence: "S"; onActivated: playerView.cycleSubtitle() }
    Shortcut { enabled: root.route === "player"; sequence: "N"; onActivated: playerView.stepEpisode(1) }
    Shortcut { enabled: root.route === "player"; sequence: "P"; onActivated: playerView.stepEpisode(-1) }

    ShortcutsOverlay { id: shortcutsOverlay }

    CommandPalette {
        id: palette
        onNavigate: r => root.navigate(r)
        onOpenSettings: (section, anchor) => root.openSettings(section, anchor)
        onOpenMedia: m => { root.openMedia(m); page.contentY = 0; }
    }
    Shortcut {
        enabled: server.ready && root.route !== "player"
        sequence: "Ctrl+K"
        onActivated: palette.visible ? palette.close() : palette.open()
    }

    Toaster {
        id: toaster
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 16
        z: 3000
        visible: server.ready
    }
    // Admin actions still report through adminStatus/errorMessage.
    Connections {
        target: server
        function onAdminChanged() {
            if (server.adminStatus !== "")
                toaster.show("success", server.adminStatus);
        }
        function onItemDeleted(id) {
            if (root.route === "detail")
                root.navigate("library");
        }
        function onErrorMessageChanged() {
            if (server.ready && server.errorMessage !== "")
                toaster.show("error", server.errorMessage);
        }
    }

    LoginView {
        anchors.fill: parent
        z: 100
        visible: !server.ready
    }
}
