import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Lain
import "../components"

// Dense single-scrolling administration (DD-027..DD-028, DD-031):
// Connection, Libraries, Users, Plugins, Maintenance, Playback,
// Language, Appearance, About. Destructive actions confirm first.
ColumnLayout {
    id: root
    spacing: 16

    signal searchRequested(string text)
    signal account()
    signal loggedOut()

    readonly property var libraries: server.libraries || []
    readonly property bool isAdmin: server.ready && server.role === "admin"
    property var pendingConfirm: null

    function stateLabel() {
        switch (server.state) {
        case "ready": return qsTr("Connected");
        case "login": return qsTr("Waiting for sign-in");
        case "setup": return qsTr("First access");
        default: return qsTr("Offline");
        }
    }

    function askConfirm(action) {
        pendingConfirm = action;
        confirmDialog.open(action.message);
    }

    function providerHealthy(id) {
        var infos = server.pluginInfo || [];
        for (var i = 0; i < infos.length; ++i) {
            if (infos[i].id === id)
                return infos[i].healthy !== false;
        }
        return true;
    }

    function capableProviders(capability, current) {
        var infos = server.pluginInfo || [];
        var out = [];
        for (var i = 0; i < infos.length; ++i) {
            var caps = infos[i].capabilities || [];
            if (caps.indexOf(capability) < 0 || current.indexOf(infos[i].id) >= 0)
                continue;
            out.push(infos[i].id);
        }
        return out;
    }

    function scanLabel() {
        var s = server.scanState || {};
        var state = s.state || "idle";
        if (state === "running")
            return qsTr("Scan running…");
        if (state === "done")
            return qsTr("Scan finished.");
        if (state === "error")
            return qsTr("Scan failed: %1").arg(s.error || "");
        return qsTr("Scan idle.");
    }

    PageHeader {
        eyebrow: qsTr("SYSTEM")
        onSearchRequested: t => searchRequested(t)
        onAccount: account()
    }
    Text {
        objectName: "settingsTitle"
        text: qsTr("Settings")
        color: Tokens.textPrimary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.pageTitleSize
        font.weight: Font.DemiBold
    }

    // ---------------------------------------------------------------- connection
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
                    text: qsTr("Server")
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
            Text {
                visible: server.pendingProgress > 0
                Layout.fillWidth: true
                text: server.pendingProgress === 1 ? qsTr("1 queued update")
                                                   : qsTr("%1 queued updates").arg(server.pendingProgress)
                color: Tokens.themeAccent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
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
                        text: qsTr("Reconnect")
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { server.refresh(); server.flushProgress(); }
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 120
                    Layout.preferredHeight: 36
                    radius: Tokens.radiusMd
                    color: Tokens.surface2
                    Text {
                        anchors.centerIn: parent
                        text: qsTr("Sign out")
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

    // ---------------------------------------------------------------- libraries
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: qsTr("Libraries")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            visible: root.libraries.length === 0
            text: qsTr("No libraries are configured on this server.")
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
                    Text {
                        visible: root.isAdmin
                        text: qsTr("Delete")
                        color: Tokens.themeUrgent
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.askConfirm({
                                kind: "deleteLibrary",
                                id: modelData.id,
                                message: qsTr("Delete library %1? Its items will leave the catalog.").arg(modelData.name)
                            })
                        }
                    }
                }
            }
        }
        // Admin library creation (name, type, filesystem path).
        property string newLibType: "movie"
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: root.isAdmin
            TextInput {
                id: libName
                Layout.fillWidth: true
                Layout.preferredWidth: 160
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                Text {
                    anchors.fill: parent
                    text: qsTr("Library name")
                    color: Tokens.textTertiary
                    font: libName.font
                    visible: libName.text === ""
                }
            }
            Text {
                Layout.preferredWidth: 70
                text: root.newLibType
                color: Tokens.themeAccent
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                MouseArea {
                    anchors.fill: parent
                    onClicked: root.newLibType = root.newLibType === "movie" ? "series"
                        : root.newLibType === "series" ? "anime" : "movie"
                }
            }
            TextInput {
                id: libPath
                Layout.fillWidth: true
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                Text {
                    anchors.fill: parent
                    text: qsTr("Filesystem path")
                    color: Tokens.textTertiary
                    font: libPath.font
                    visible: libPath.text === ""
                }
            }
            Rectangle {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 32
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Create library")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        server.createLibrary(libName.text, root.newLibType, libPath.text);
                        libName.text = "";
                        libPath.text = "";
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------- users
    ColumnLayout {
        objectName: "usersSection"
        Layout.fillWidth: true
        spacing: 10
        visible: root.isAdmin
        Text {
            text: qsTr("Users")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Repeater {
            model: server.users || []
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 12
                    Text {
                        Layout.preferredWidth: 160
                        text: modelData.username
                        color: modelData.disabled ? Tokens.textTertiary : Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.bodySize
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.role
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: modelData.role === "admin" ? qsTr("Make user") : qsTr("Make admin")
                        color: Tokens.themeAccent
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.askConfirm({
                                kind: "setRole",
                                id: modelData.id,
                                extra: modelData.role === "admin" ? "user" : "admin",
                                message: qsTr("Change role of %1 to %2?").arg(modelData.username).arg(modelData.role === "admin" ? "user" : "admin")
                            })
                        }
                    }
                    Text {
                        text: modelData.disabled ? qsTr("Enable") : qsTr("Disable")
                        color: modelData.disabled ? Tokens.themeAccent : Tokens.themeUrgent
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        MouseArea {
                            anchors.fill: parent
                            onClicked: modelData.disabled
                                ? server.setUserDisabled(modelData.id, false)
                                : root.askConfirm({
                                    kind: "disableUser",
                                    id: modelData.id,
                                    message: qsTr("Disable user %1? They will not be able to sign in.").arg(modelData.username)
                                })
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            TextInput {
                id: newUserName
                Layout.preferredWidth: 150
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                Text {
                    anchors.fill: parent
                    text: qsTr("Username")
                    color: Tokens.textTertiary
                    font: newUserName.font
                    visible: newUserName.text === ""
                }
            }
            TextInput {
                id: newUserPass
                Layout.preferredWidth: 150
                echoMode: TextInput.Password
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
                Text {
                    anchors.fill: parent
                    text: qsTr("Password")
                    color: Tokens.textTertiary
                    font: newUserPass.font
                    visible: newUserPass.text === ""
                }
            }
            Rectangle {
                Layout.preferredWidth: 120
                Layout.preferredHeight: 32
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Create user")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        server.createUser(newUserName.text, newUserPass.text, "user");
                        newUserName.text = "";
                        newUserPass.text = "";
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ plugins
    // Composition bindings with provider reorder/swap (DD-028). Applies
    // confirm first; stale generations reload for review instead of
    // overwriting another operator's change.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: root.isAdmin
        Text {
            text: qsTr("Plugins")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            visible: (server.composition || []).length === 0
            text: qsTr("No plugins reported.")
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Repeater {
            model: server.composition || []
            delegate: Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: bindingCol.implicitHeight + 28
                radius: Tokens.radiusMd
                color: Tokens.surface1
                border.color: Tokens.borderSubtle
                property string capability: modelData.capability
                property string mode: modelData.mode
                property var draft: (modelData.providers || []).slice()
                property bool dirty: JSON.stringify(draft) !== JSON.stringify(modelData.providers || [])
                ColumnLayout {
                    id: bindingCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 6
                    Text {
                        Layout.fillWidth: true
                        text: capability + "  ·  " + mode
                        color: Tokens.textPrimary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                        font.weight: Font.DemiBold
                        elide: Text.ElideMiddle
                    }
                    Repeater {
                        model: draft
                        delegate: RowLayout {
                            property int slot: index
                            spacing: 8
                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: root.providerHealthy(modelData) ? Tokens.themeAccent : Tokens.themeUrgent
                            }
                            Text {
                                Layout.fillWidth: true
                                text: modelData
                                color: Tokens.textSecondary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: mode !== "exactly-one"
                                text: "▲"
                                color: Tokens.textTertiary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: slot > 0
                                    onClicked: {
                                        var next = draft.slice();
                                        var tmp = next[slot - 1];
                                        next[slot - 1] = next[slot];
                                        next[slot] = tmp;
                                        draft = next;
                                    }
                                }
                            }
                            Text {
                                visible: mode !== "exactly-one"
                                text: "▼"
                                color: Tokens.textTertiary
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: slot < draft.length - 1
                                    onClicked: {
                                        var next = draft.slice();
                                        var tmp = next[slot + 1];
                                        next[slot + 1] = next[slot];
                                        next[slot] = tmp;
                                        draft = next;
                                    }
                                }
                            }
                            Text {
                                visible: mode !== "exactly-one" && draft.length > 1
                                text: "✕"
                                color: Tokens.themeUrgent
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        var next = draft.slice();
                                        next.splice(slot, 1);
                                        draft = next;
                                    }
                                }
                            }
                            Text {
                                visible: mode === "exactly-one"
                                text: "●"
                                color: Tokens.themeAccent
                                font.family: Tokens.fontFamily
                                font.pixelSize: Tokens.metaSize
                            }
                        }
                    }
                    Text {
                        visible: mode === "exactly-one"
                        text: qsTr("Tap a provider to select it:")
                        color: Tokens.textTertiary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize - 1
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: root.capableProviders(capability, draft)
                            delegate: Rectangle {
                                width: addLabel.implicitWidth + 20
                                height: 28
                                radius: Tokens.radiusPill
                                color: "transparent"
                                border.color: Tokens.themeAccent
                                Text {
                                    id: addLabel
                                    anchors.centerIn: parent
                                    text: "+ " + modelData
                                    color: Tokens.themeAccent
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: Tokens.metaSize - 1
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (mode === "exactly-one")
                                            draft = [modelData];
                                        else {
                                            var next = draft.slice();
                                            next.push(modelData);
                                            draft = next;
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 32
                        radius: Tokens.radiusMd
                        visible: dirty && !provisioning.busy
                        color: Tokens.themeAccent
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("Apply")
                            color: "black"
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.metaSize
                            font.bold: true
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.askConfirm({
                                kind: "swapProviders",
                                id: capability,
                                extra: draft.slice(),
                                message: qsTr("Change providers for %1? Playback, search, or metadata may be affected.").arg(capability)
                            })
                        }
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- maintenance
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        visible: root.isAdmin
        Text {
            text: qsTr("Maintenance")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            text: root.scanLabel()
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Text {
            Layout.fillWidth: true
            visible: server.adminStatus !== ""
            text: server.adminStatus
            color: Tokens.themeAccent
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
            wrapMode: Text.WordWrap
        }
        RowLayout {
            spacing: 10
            Rectangle {
                Layout.preferredWidth: 130
                Layout.preferredHeight: 34
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Scan now")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                MouseArea { anchors.fill: parent; onClicked: server.triggerScan() }
            }
            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 34
                radius: Tokens.radiusMd
                color: Tokens.surface2
                Text {
                    anchors.centerIn: parent
                    text: qsTr("Download backup")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                }
                MouseArea { anchors.fill: parent; onClicked: backupDialog.open() }
            }
        }
    }

    // ----------------------------------------------------------------- playback
    ColumnLayout {
        objectName: "playbackSection"
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: qsTr("Playback")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        RowLayout {
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: qsTr("Resume playback automatically")
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
            Repeater {
                model: [
                    { id: true, label: qsTr("On") },
                    { id: false, label: qsTr("Off") }
                ]
                delegate: Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 30
                    radius: Tokens.radiusPill
                    color: server.autoResume === modelData.id
                        ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                        : Tokens.surface1
                    border.color: server.autoResume === modelData.id
                        ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: server.autoResume === modelData.id ? Tokens.themeAccent : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea { anchors.fill: parent; onClicked: server.setAutoResume(modelData.id) }
                }
            }
        }
        RowLayout {
            spacing: 8
            Text {
                Layout.fillWidth: true
                text: qsTr("Autoplay next episode")
                color: Tokens.textSecondary
                font.family: Tokens.fontFamily
                font.pixelSize: Tokens.metaSize
            }
            Repeater {
                model: [
                    { id: true, label: qsTr("On") },
                    { id: false, label: qsTr("Off") }
                ]
                delegate: Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 30
                    radius: Tokens.radiusPill
                    color: server.autoplayNext === modelData.id
                        ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                        : Tokens.surface1
                    border.color: server.autoplayNext === modelData.id
                        ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle
                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: server.autoplayNext === modelData.id ? Tokens.themeAccent : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea { anchors.fill: parent; onClicked: server.setAutoplayNext(modelData.id) }
                }
            }
        }
        Text {
            visible: (server.series || []).length > 0
            text: qsTr("Per-series autoplay")
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Repeater {
            model: server.series || []
            delegate: RowLayout {
                property string seriesId: modelData.id
                Layout.fillWidth: true
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: modelData.title + " (" + modelData.episodeCount + ")"
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: Tokens.metaSize
                    elide: Text.ElideRight
                }
                Repeater {
                    model: [
                        { id: "default", label: qsTr("Default") },
                        { id: "on", label: qsTr("On") },
                        { id: "off", label: qsTr("Off") }
                    ]
                    delegate: Rectangle {
                        Layout.preferredWidth: 70
                        Layout.preferredHeight: 28
                        radius: Tokens.radiusPill
                        color: server.seriesAutoplayMode(seriesId) === modelData.id
                            ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                            : Tokens.surface1
                        border.color: server.seriesAutoplayMode(seriesId) === modelData.id
                            ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: server.seriesAutoplayMode(seriesId) === modelData.id
                                ? Tokens.themeAccent : Tokens.textSecondary
                            font.family: Tokens.fontFamily
                            font.pixelSize: Tokens.metaSize - 1
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: server.setSeriesAutoplay(seriesId, modelData.id)
                        }
                    }
                }
            }
        }
    }

    // ---------------------------------------------------------------- language
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 10
        Text {
            text: qsTr("Language")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        RowLayout {
            spacing: 8
            Repeater {
                objectName: "languageRepeater"
                model: localeManager.available
                delegate: Rectangle {
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: langLabel.implicitWidth + 28
                    radius: Tokens.radiusPill
                    color: localeManager.selected === modelData.id
                        ? Qt.tint(Tokens.bgPrimary, Qt.alpha(Tokens.themeAccent, 0.16))
                        : Tokens.surface1
                    border.color: localeManager.selected === modelData.id
                        ? Qt.alpha(Tokens.themeAccent, 0.5) : Tokens.borderSubtle
                    Text {
                        id: langLabel
                        anchors.centerIn: parent
                        text: modelData.label
                        color: localeManager.selected === modelData.id
                            ? Tokens.themeAccent : Tokens.textSecondary
                        font.family: Tokens.fontFamily
                        font.pixelSize: Tokens.metaSize
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: localeManager.setSelected(modelData.id)
                    }
                }
            }
        }
    }

    // --------------------------------------------------------------- appearance
    Text {
        Layout.topMargin: 8
        text: qsTr("Appearance follows the Omarchy theme live, without restarting.")
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
        text: qsTr("Font: monospace · Corners mirror Hyprland rounding (%1)").arg(omarchy.cornerRadius)
        color: Tokens.textTertiary
        font.family: Tokens.fontFamily
        font.pixelSize: Tokens.metaSize
    }
    // --------------------------------------------------------------------- about
    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        spacing: 4
        Text {
            text: qsTr("About")
            color: Tokens.textPrimary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.sectionSize
            font.weight: Font.DemiBold
        }
        Text {
            text: qsTr("Lain desktop %1").arg(appVersion)
            color: Tokens.textSecondary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize
        }
        Text {
            text: qsTr("Build %1").arg(buildTs)
            color: Tokens.textTertiary
            font.family: Tokens.fontFamily
            font.pixelSize: Tokens.metaSize - 1
        }
    }

    FileDialog {
        id: backupDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "db"
        nameFilters: ["Database (*.db)", "All files (*)"]
        onAccepted: {
            var path = String(backupDialog.selectedFile).replace(/^file:\/\//, "");
            server.downloadBackup(path);
        }
    }

    ConfirmDialog {
        id: confirmDialog
        onAccepted: {
            var action = root.pendingConfirm;
            root.pendingConfirm = null;
            if (!action)
                return;
            if (action.kind === "deleteLibrary")
                server.deleteLibrary(action.id);
            else if (action.kind === "disableUser")
                server.setUserDisabled(action.id, true);
            else if (action.kind === "setRole")
                server.setUserRole(action.id, action.extra);
            else if (action.kind === "swapProviders")
                server.swapProviders(action.id, action.extra);
        }
        onRejected: root.pendingConfirm = null
    }
}
