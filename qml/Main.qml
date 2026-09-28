import QtQuick
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

    function playMedia(m) {
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
            SettingsView {
                visible: root.route === "settings"
                Layout.fillWidth: true
                Layout.leftMargin: Math.max(Tokens.pageMargin, (root.width - Tokens.contentWidth) / 2 + Tokens.pageMargin)
                Layout.rightMargin: Layout.leftMargin
                Layout.topMargin: 16
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
        visible: server.ready && root.visibility !== Window.FullScreen && root.route !== "player"
        current: root.route
        onNavigate: r => {
            root.route = r;
            if (r === "search")
                searchView.focusInput();
            page.contentY = 0;
        }
        onLogout: server.logout()
    }

    // Ctrl+F / "/" jump straight to the search page (web parity).
    Shortcut {
        enabled: server.ready
        sequence: "Ctrl+F"
        onActivated: { root.route = "search"; searchView.focusInput(); }
    }
    Shortcut {
        enabled: server.ready
        sequence: "/"
        onActivated: { root.route = "search"; searchView.focusInput(); }
    }
    Shortcut { enabled: server.ready; sequence: "Alt+Left"; onActivated: root.route = "home" }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (root.visibility === Window.FullScreen)
                root.visibility = Window.Windowed;
            else if (root.route === "detail" || root.route === "player" || root.route === "series")
                root.route = root.returnRoute;
        }
    }

    // Player shortcuts (§31)
    Shortcut { enabled: root.route === "player"; sequence: "Space"; onActivated: playerView.togglePause() }
    Shortcut { enabled: root.route === "player"; sequence: "Left"; onActivated: playerView.seekBy(-10) }
    Shortcut { enabled: root.route === "player"; sequence: "Right"; onActivated: playerView.seekBy(10) }
    Shortcut { enabled: root.route === "player"; sequence: "Up"; onActivated: playerView.adjustVolume(5) }
    Shortcut { enabled: root.route === "player"; sequence: "Down"; onActivated: playerView.adjustVolume(-5) }
    Shortcut { enabled: root.route === "player"; sequence: "M"; onActivated: playerView.toggleMute() }
    Shortcut { enabled: root.route === "player"; sequence: "F"; onActivated: playerView.toggleFullscreen() }
    Shortcut { enabled: root.route === "player"; sequence: "A"; onActivated: playerView.cycleAudio() }
    Shortcut { enabled: root.route === "player"; sequence: "S"; onActivated: playerView.cycleSubtitle() }

    LoginView {
        anchors.fill: parent
        z: 100
        visible: !server.ready
    }
}
