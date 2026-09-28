import QtQuick
import QtQuick.Layouts
import Lain

// Top header matching the web AppShell: logo left, centered nav links,
// server status + account menu on the right.
Rectangle {
    id: bar
    height: Tokens.headerHeight
    color: Qt.alpha(Tokens.bgPrimary, 0.88)
    border.color: Qt.alpha(Tokens.themeFg, 0.05)

    property string current: "home"
    signal navigate(string route)
    signal logout()
    signal account()
    signal helpRequested()

    readonly property var links: [
        { route: "home", label: qsTr("Home") },
        { route: "library", label: qsTr("Library") },
        { route: "search", label: qsTr("Search") },
        { route: "settings", label: qsTr("Settings") }
    ]

    // Detail/series pages light up "Library" like the web nav does for
    // /item/* routes.
    function navActive(route) {
        if (route === "library")
            return current === "library" || current === "series" || current === "detail";
        return current === route;
    }

    // Three-column grid: brand | centered nav | status+account.
    Item {
        anchors.fill: parent
        anchors.leftMargin: Math.max(Tokens.pageMargin, (bar.width - Tokens.contentWidth) / 2)
        anchors.rightMargin: anchors.leftMargin

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Rectangle {
                width: 18; height: 18; radius: 5
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: 4; height: 14; radius: 2
                    color: Tokens.themeAccent
                    rotation: -20
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 14; height: 4; radius: 2
                    color: Tokens.themeAccent
                    rotation: -20
                }
            }
            Text {
                text: "lain"
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 4
            }
            TapHandler {
                onTapped: bar.navigate("home")
            }
        }

        RowLayout {
            anchors.centerIn: parent
            spacing: 12
            Repeater {
                model: bar.links
                delegate: Rectangle {
                    radius: 8
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
                    Text {
                        id: label
                        anchors.centerIn: parent
                        text: modelData.label
                        color: bar.navActive(modelData.route) ? Tokens.textPrimary : Tokens.textTertiary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                        font.letterSpacing: 0.4
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: if (!bar.navActive(modelData.route)) label.color = Tokens.textSecondary
                        onExited: label.color = bar.navActive(modelData.route) ? Tokens.textPrimary : Tokens.textTertiary
                        onClicked: bar.navigate(modelData.route)
                    }
                }
            }
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            // Server status indicator.
            RowLayout {
                spacing: 8
                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: server.ready ? Tokens.themeAccent : Tokens.themeUrgent
                }
                Text {
                    text: server.state === "ready" ? qsTr("online") : server.state
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.4
                    font.capitalization: Font.AllUppercase
                }
            }

            // Keybindings help affordance — the DD-036 overlay must be
            // reachable by mouse and keyboard focus, not only `?`.
            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 14
                color: "transparent"
                activeFocusOnTab: true
                border.width: activeFocus ? 2 : 0
                border.color: Tokens.themeAccent
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Keyboard shortcuts")
                Keys.onSpacePressed: bar.helpRequested()
                Keys.onReturnPressed: bar.helpRequested()
                Keys.onEnterPressed: bar.helpRequested()
                Text {
                    anchors.centerIn: parent
                    text: "?"
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: bar.helpRequested()
                }
            }

            // Account avatar opens the dropdown menu.
            Rectangle {
                id: avatar
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.15))
                border.color: activeFocus ? Tokens.themeAccent : Qt.alpha(Tokens.themeAccent, 0.4)
                border.width: activeFocus ? 2 : 1
                activeFocusOnTab: true
                Accessible.role: Accessible.Button
                Accessible.name: qsTr("Account menu")
                Keys.onSpacePressed: menu.visible = !menu.visible
                Keys.onReturnPressed: menu.visible = !menu.visible
                Keys.onEnterPressed: menu.visible = !menu.visible
                Text {
                    anchors.centerIn: parent
                    text: String(server.username || "?").charAt(0).toUpperCase()
                    color: Tokens.themeAccent
                    font.family: Tokens.fontSans
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: menu.visible = !menu.visible
                }
            }
        }
    }

    // Account dropdown (avatar, username, account, sign out).
    Rectangle {
        id: menu
        visible: false
        x: parent.width - width - Math.max(Tokens.pageMargin, (bar.width - Tokens.contentWidth) / 2)
        y: bar.height + 6
        width: 220
        height: menuCol.implicitHeight + 12
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Tokens.borderSubtle
        z: 60

        ColumnLayout {
            id: menuCol
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2

            Text {
                Layout.leftMargin: 10
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                text: server.username || ""
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 12
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.borderSubtle }

            Repeater {
                model: [
                    { label: qsTr("Account"), route: "settings" }
                ]
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: 8
                    color: "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.label
                        color: Tokens.textPrimary
                        font.family: Tokens.fontSans
                        font.pixelSize: 13
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.color = Tokens.hoverFill
                        onExited: parent.color = "transparent"
                        onClicked: { menu.visible = false; bar.navigate(modelData.route); }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.borderSubtle }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 8
                color: "transparent"
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Sign out")
                    color: Tokens.themeUrgent
                    font.family: Tokens.fontSans
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: parent.color = Qt.alpha(Tokens.themeUrgent, 0.1)
                    onExited: parent.color = "transparent"
                    onClicked: { menu.visible = false; bar.logout(); }
                }
            }
        }
    }
}
