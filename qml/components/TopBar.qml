import QtQuick
import QtQuick.Layouts
import Lain

// Top header matching the web AppShell: logo left, centered nav links,
// operational state + Ctrl K + account menu on the right.
Rectangle {
    id: bar
    height: Tokens.headerHeight
    color: Qt.alpha(Tokens.bgPrimary, 0.88)

    property string current: "home"
    signal navigate(string route)
    signal openSettings(string section)
    signal logout()
    signal helpRequested()
    signal paletteRequested()

    readonly property var links: [
        { route: "home", label: qsTr("Home") },
        { route: "library", label: qsTr("Library") },
        { route: "list", label: qsTr("My list") },
        { route: "search", label: qsTr("Search") },
        { route: "settings", label: qsTr("Settings") }
    ]
    readonly property bool scanning: server.scanState && server.scanState.state === "running"

    // Detail/series/reader pages light up "Library" like the web nav does
    // for /item/* routes.
    function navActive(route) {
        if (route === "library")
            return current === "library" || current === "series" || current === "detail" || current === "reader";
        return current === route;
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Qt.alpha(Tokens.themeFg, 0.05)
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Math.max(Tokens.pageMargin, (bar.width - Tokens.contentWidth) / 2)
        anchors.rightMargin: anchors.leftMargin

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Item {
                implicitWidth: 20
                implicitHeight: 20
                // Signal mark: three rising bars, the web SignalMark.
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: [8, 13, 18]
                        Rectangle {
                            required property int modelData
                            width: 4
                            height: modelData
                            radius: 1
                            anchors.bottom: parent.bottom
                            color: Tokens.themeAccent
                        }
                    }
                }
            }
            Text {
                text: "lain"
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 3.8
            }
            TapHandler { onTapped: bar.navigate("home") }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 16
            Repeater {
                model: bar.links
                delegate: Rectangle {
                    id: link
                    required property var modelData
                    objectName: "nav-" + modelData.route
                    radius: 6
                    color: "transparent"
                    implicitWidth: label.implicitWidth + 16
                    implicitHeight: 30
                    activeFocusOnTab: true
                    border.width: activeFocus ? 2 : 0
                    border.color: Tokens.themeAccent
                    Accessible.role: Accessible.Link
                    Accessible.name: modelData.label
                    Keys.onSpacePressed: bar.navigate(modelData.route)
                    Keys.onReturnPressed: bar.navigate(modelData.route)
                    Keys.onEnterPressed: bar.navigate(modelData.route)
                    HoverHandler { id: linkHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: bar.navigate(link.modelData.route) }
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: link.modelData.label
                        color: bar.navActive(link.modelData.route) || linkHover.hovered ? Tokens.textPrimary : Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                        font.letterSpacing: 0.4
                    }
                }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            // Operational state earns the header only while it is happening.
            RowLayout {
                visible: bar.scanning
                spacing: 8
                Rectangle {
                    implicitWidth: 6; implicitHeight: 6; radius: 3
                    color: Tokens.themeAccent
                    SequentialAnimation on opacity {
                        running: bar.scanning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1; duration: 600 }
                    }
                }
                Text {
                    text: qsTr("SCANNING")
                    color: Tokens.themeAccent
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.8
                    TapHandler { onTapped: bar.openSettings("libraries") }
                }
            }
            RowLayout {
                visible: !server.ready
                spacing: 8
                Rectangle { implicitWidth: 6; implicitHeight: 6; radius: 3; color: Tokens.danger }
                Text {
                    text: server.state.toUpperCase()
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.letterSpacing: 1.4
                }
            }

            // Ctrl K launcher and the DD-036 keybindings overlay.
            Repeater {
                model: [
                    { key: "Ctrl K", name: qsTr("Command palette"), act: "palette" },
                    { key: "?", name: qsTr("Keyboard shortcuts"), act: "help" }
                ]
                delegate: Rectangle {
                    id: kbd
                    required property var modelData
                    implicitWidth: kbdText.implicitWidth + 14
                    implicitHeight: 24
                    radius: 5
                    color: kbdHover.hovered ? Tokens.hoverFill : "transparent"
                    border.width: activeFocus ? 2 : 0
                    border.color: Tokens.themeAccent
                    activeFocusOnTab: true
                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.name
                    function run() { if (modelData.act === "palette") bar.paletteRequested(); else bar.helpRequested(); }
                    Keys.onSpacePressed: run()
                    Keys.onReturnPressed: run()
                    HoverHandler { id: kbdHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: kbd.run() }
                    Text {
                        id: kbdText
                        anchors.centerIn: parent
                        text: kbd.modelData.key
                        color: kbdHover.hovered ? Tokens.textPrimary : Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: 10
                    }
                }
            }

            Rectangle {
                id: avatarButton
                objectName: "accountButton"
                implicitWidth: 40
                implicitHeight: 40
                radius: 20
                color: avatarHover.hovered || menu.visible ? Tokens.hoverFill : "transparent"
                border.width: activeFocus ? 2 : 0
                border.color: Tokens.themeAccent
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Account menu")
                Keys.onSpacePressed: menu.toggle()
                Keys.onReturnPressed: menu.toggle()
                Keys.onEnterPressed: menu.toggle()
                HoverHandler { id: avatarHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: menu.toggle() }
                Avatar { anchors.centerIn: parent; size: 32 }
            }
        }
    }

    // Web UserMenu: identity header, Profile / Playback / All settings,
    // then Sign out. Lifted to the window so it paints over the page.
    Item {
        id: menu
        objectName: "accountMenu"
        readonly property bool opened: visible
        function close() { visible = false; }
        visible: false
        z: 1500
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        function toggle() {
            if (visible) {
                visible = false;
                return;
            }
            var host = bar.Window.window ? bar.Window.window.contentItem : null;
            if (host) {
                parent = host;
                var p = avatarButton.mapToItem(host, avatarButton.width, avatarButton.height + 6);
                card.x = p.x - card.width;
                card.y = p.y;
            }
            visible = true;
        }
        function run(fn) { visible = false; fn(); }
        MouseArea { anchors.fill: parent; onClicked: menu.visible = false }
        Rectangle {
            id: card
            width: 248
            height: menuCol.implicitHeight + 8
            radius: Tokens.radiusMd
            color: Tokens.bgElevated
            border.color: Tokens.borderSubtle
            MouseArea { anchors.fill: parent }
            ColumnLayout {
                id: menuCol
                anchors.fill: parent
                anchors.margins: 4
                spacing: 0
                RowLayout {
                    Layout.margins: 8
                    spacing: 12
                    Avatar { size: 40 }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: server.displayName
                            color: Tokens.textPrimary
                            font.family: Tokens.fontSans
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: ("@" + server.username + " · " + server.role).toUpperCase()
                            color: Tokens.textTertiary
                            font.family: Tokens.fontFamily
                            font.pixelSize: 10
                            font.letterSpacing: 1.4
                            elide: Text.ElideRight
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; height: 1; color: Tokens.hairline }
                Repeater {
                    model: [
                        { icon: "user", label: qsTr("Profile"), keys: "g p", section: "profile" },
                        { icon: "play", label: qsTr("Playback"), keys: "g y", section: "playback" },
                        { icon: "sliders", label: qsTr("All settings"), keys: "g e", section: "" }
                    ]
                    delegate: Rectangle {
                        id: item
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 36
                        radius: 4
                        color: itemHover.hovered ? Tokens.hoverFill : "transparent"
                        HoverHandler { id: itemHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: menu.run(() => bar.openSettings(item.modelData.section)) }
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 10
                            Glyph { name: item.modelData.icon; size: 16; color: Tokens.textTertiary }
                            Text {
                                Layout.fillWidth: true
                                text: item.modelData.label
                                color: Tokens.textPrimary
                                font.family: Tokens.fontSans
                                font.pixelSize: 13
                            }
                            Text { text: item.modelData.keys; color: Tokens.textTertiary; font.family: Tokens.fontFamily; font.pixelSize: 10 }
                        }
                    }
                }
                Rectangle { Layout.fillWidth: true; Layout.topMargin: 4; Layout.bottomMargin: 4; height: 1; color: Tokens.hairline }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 36
                    radius: 4
                    color: outHover.hovered ? Qt.alpha(Tokens.danger, 0.1) : "transparent"
                    HoverHandler { id: outHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: menu.run(() => bar.logout()) }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        spacing: 10
                        Glyph { name: "log-out"; size: 16; color: Tokens.danger }
                        Text { text: qsTr("Sign out"); color: Tokens.danger; font.family: Tokens.fontSans; font.pixelSize: 13 }
                    }
                }
            }
        }
    }
}
