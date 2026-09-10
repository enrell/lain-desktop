import QtQuick
import QtQuick.Layouts
import Lain
import "../components"

// Settings: conexão/conta reais + bibliotecas do servidor + prova de que
// o tema do Omarchy é ao vivo (swatches).
ColumnLayout {
    id: root
    spacing: 16

    signal searchRequested(string text)
    signal account()
    signal loggedOut()

    readonly property var libraries: server.libraries || []

    function stateLabel() {
        switch (server.state) {
        case "ready": return "Conectado";
        case "login": return "Aguardando login";
        case "setup": return "Primeiro acesso";
        default: return "Offline";
        }
    }

    PageHeader {
        eyebrow: "SYSTEM"
        onSearchRequested: t => searchRequested(t)
        onAccount: account()
    }
    Text {
        text: "Settings"
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.pageTitleSize
        font.weight: Font.DemiBold
    }

    // ------------------------------------------------------------- conexão
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: connection.implicitHeight + 40
        radius: Tokens.radiusMd
        color: Tokens.surface1
        border.color: Tokens.borderSubtle
        ColumnLayout {
            id: connection
            anchors.fill: parent
            anchors.margins: 20
            spacing: 10
            RowLayout {
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    color: server.ready ? Tokens.themeAccent : Tokens.themeUrgent
                }
                Text {
                    text: "Servidor"
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    font.letterSpacing: 1
                }
                Text {
                    text: root.stateLabel()
                    color: Tokens.textSecondary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
            }
            Text {
                Layout.fillWidth: true
                text: server.serverUrl
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.bodySize
                elide: Text.ElideRight
            }
            Text {
                visible: server.username !== ""
                text: server.username + (server.role !== "" ? "  ·  " + server.role : "")
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
            Text {
                visible: server.errorMessage !== ""
                Layout.fillWidth: true
                text: server.errorMessage
                color: Tokens.themeUrgent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                wrapMode: Text.WordWrap
            }
            RowLayout {
                spacing: 10
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 36
                    radius: Tokens.radiusMd
                    color: Tokens.surface2
                    Text {
                        anchors.centerIn: parent
                        text: "Reconectar"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea { anchors.fill: parent; onClicked: server.refresh() }
                }
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 36
                    radius: Tokens.radiusMd
                    color: Tokens.surface2
                    Text {
                        anchors.centerIn: parent
                        text: "Sair"
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { server.logout(); loggedOut(); }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------- bibliotecas
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: "Bibliotecas"
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            visible: root.libraries.length === 0
            text: "Nenhuma biblioteca configurada no servidor."
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Repeater {
            model: root.libraries
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 14
                    Text {
                        Layout.preferredWidth: 160
                        text: modelData.name
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.bodySize
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.type
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.path
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        horizontalAlignment: Text.AlignRight
                        elide: Text.ElideMiddle
                    }
                }
            }
        }
    }

    // ----------------------------------------------------------- aparência
    Text {
        Layout.topMargin: 8
        text: "Appearance follows the Omarchy theme — live, no restart."
        color: Tokens.textSecondary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.bodySize
    }
    RowLayout {
        spacing: 12
        Repeater {
            model: [
                { name: "background", c: omarchy.background },
                { name: "foreground", c: omarchy.foreground },
                { name: "accent", c: omarchy.accent },
                { name: "urgent", c: omarchy.urgent },
                { name: "muted", c: omarchy.muted }
            ]
            delegate: ColumnLayout {
                spacing: 6
                Rectangle {
                    Layout.preferredWidth: 72
                    Layout.preferredHeight: 72
                    radius: Tokens.radiusMd
                    color: modelData.c
                    border.color: Tokens.borderSubtle
                }
                Text {
                    text: modelData.name
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize - 1
                }
            }
        }
    }
    Text {
        text: "Font: monospace  ·  Corners mirror Hyprland rounding (" + omarchy.cornerRadius + ")"
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize
    }
    Text {
        text: "Build " + buildTs
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize - 1
    }
}
