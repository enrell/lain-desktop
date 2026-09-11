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
    property string route: "home"
    property string returnRoute: "home"

    // Fixed content margin for the collapsed rail; the rail floats above
    // (z), so expanding never shifts layout and avoids hitbox jitter.
    Flickable {
        id: page
        anchors.fill: parent
        anchors.leftMargin: Tokens.navRailWidth
        visible: server.ready
        contentWidth: width
        contentHeight: content.height
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: content
            width: parent.width
            HomeView {
                Layout.fillWidth: true
                visible: root.route === "home"
                home: root.homeData
                onOpenMedia: m => { root.returnRoute = "home"; root.route = "detail"; server.openMedia(m.id); }
                onPlayMedia: m => { root.returnRoute = "home"; server.openMedia(m.id); server.requestPlayback(m.id); root.route = "player"; }
                onSearchRequested: t => searchOverlay.openWith(t)
                onAccount: root.route = "settings"
            }
            LibraryView {
                Layout.fillWidth: true
                visible: root.route === "movies" || root.route === "shows"
                title: root.route === "shows" ? qsTr("Shows") : qsTr("Movies")
                items: root.route === "shows" ? server.shows : server.movies
                seriesModel: server.series
                showSeries: root.route === "shows"
                onOpenMedia: m => { root.returnRoute = root.route; root.route = "detail"; server.openMedia(m.id); }
                onSearchRequested: t => searchOverlay.openWith(t)
                onAccount: root.route = "settings"
            }
            DetailView {
                Layout.fillWidth: true
                visible: root.route === "detail"
                media: root.currentMedia
                onOpenMedia: m => { server.openMedia(m.id); }
                onPlayMedia: m => { server.openMedia(m.id); server.requestPlayback(m.id); root.route = "player"; }
                onBack: root.route = root.returnRoute
            }
            CollectionsView {
                Layout.fillWidth: true
                visible: root.route === "collections"
                collections: server.collections
                onOpenMedia: m => { root.returnRoute = "collections"; root.route = "detail"; server.openMedia(m.id); }
                onSearchRequested: t => searchOverlay.openWith(t)
                onAccount: root.route = "settings"
            }
            PlayerView {
                id: playerView
                visible: root.route === "player"
                media: root.currentMedia
                onToggleFullscreen: root.visibility = root.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
                onBack: {
                    root.route = root.returnRoute;
                    server.refresh();
                }
            }
            SettingsView {
                visible: root.route === "settings"
                Layout.fillWidth: true
                Layout.leftMargin: Tokens.pageMargin
                Layout.rightMargin: Tokens.pageMargin
                Layout.topMargin: 8
                onSearchRequested: t => searchOverlay.openWith(t)
                onAccount: root.route = "settings"
                onLoggedOut: root.route = "home"
            }
        }
    }

    NavRail {
        id: navRail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 10
        visible: server.ready && root.visibility !== Window.FullScreen
        current: root.route
        onNavigate: r => { root.route = r; }
    }

    // Position-based hover tracking (not edge events): an invisible zone
    // that never intercepts clicks. Hysteresis 96/230 removes flicker
    // so rail buttons stay simple buttons.
    MouseArea {
        anchors.fill: parent
        z: 5
        enabled: server.ready
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onPositionChanged: mouse => {
            if (mouse.x < 96) navRail.expanded = true;
            else if (mouse.x > 230) navRail.expanded = false;
        }
    }

    // Functional search: Ctrl+F is primary, / is a shortcut.
    SearchOverlay {
        id: searchOverlay
        visible: false
        onOpenMedia: m => {
            visible = false;
            server.clearSearch();
            root.returnRoute = root.route;
            root.route = "detail";
            server.openMedia(m.id);
        }
        onClosed: server.clearSearch()
    }

    Shortcut { enabled: server.ready; sequence: "Ctrl+F"; onActivated: searchOverlay.openWith("") }
    Shortcut { enabled: server.ready; sequence: "/"; onActivated: searchOverlay.openWith("") }
    Shortcut { enabled: server.ready; sequence: "Alt+Left"; onActivated: root.route = "home" }
    Shortcut {
        sequence: "Esc"
        onActivated: {
            if (root.visibility === Window.FullScreen)
                root.visibility = Window.Windowed;
            else if (searchOverlay.visible)
                searchOverlay.visible = false;
            else if (root.route === "detail" || root.route === "player")
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
