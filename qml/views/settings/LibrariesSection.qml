import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"
import "../../theme/Format.js" as Format

// Web settings/libraries: scan status with per-root diagnostics, the
// library list, and "Add a media library" with the server folder picker
// (GET /api/browse) so a typo'd path cannot be submitted by clicking.
SettingsPage {
    id: page
    readonly property var libraries: server.libraries || []
    readonly property var scan: server.scanState || ({})
    readonly property bool scanning: scan.state === "running"
    readonly property var stats: scan.stats || null
    property var removeTarget: null
    property string formError: ""
    property string newType: "anime"

    readonly property var typeOptions: [
        { id: "anime", label: qsTr("Anime") },
        { id: "series", label: qsTr("Series") },
        { id: "movie", label: qsTr("Movies") },
        { id: "manga", label: qsTr("Manga") },
        { id: "comic", label: qsTr("Comics") }
    ]

    function relative(ts) { return Format.relative(ts); }
    function unreadable(libId) {
        var list = stats && stats.unreadable ? stats.unreadable : [];
        for (var i = 0; i < list.length; ++i)
            if (list[i].library_id === libId)
                return true;
        return false;
    }
    function openAdd() {
        formError = "";
        nameField.text = "";
        pathField.text = "";
        newType = "anime";
        server.browseFolders("");
        addModal.open();
        nameField.focusField();
    }
    function useFolder(dir) {
        var picked = dir ? dir.path : (server.browseResult.path || "");
        if (!picked)
            return;
        pathField.text = picked;
        if (nameField.text.trim() === "") {
            var parts = picked.split("/").filter(p => p !== "");
            nameField.text = dir ? dir.name : (parts.length ? parts[parts.length - 1] : "");
        }
    }
    function create() {
        if (nameField.text.trim() === "" || pathField.text.trim() === "") {
            formError = qsTr("Library name and path are required.");
            return;
        }
        pendingCreate = true;
        server.createLibrary(nameField.text.trim(), newType, pathField.text.trim());
    }
    property bool pendingCreate: false
    function focusAnchor(anchor) {
        if (anchor === "add")
            openAdd();
        else {
            var hit = findAnchor(page, anchor);
            if (hit && hit.pulse)
                hit.pulse();
        }
    }

    Component.onCompleted: server.refreshScanStatus()
    Connections {
        target: server
        function onErrorMessageChanged() {
            if (page.pendingCreate && server.errorMessage !== "") {
                page.pendingCreate = false;
                page.formError = server.errorMessage;
            }
        }
        function onAdminStatusChanged() {
            if (page.pendingCreate && server.adminStatus.indexOf(nameField.text.trim()) >= 0) {
                page.pendingCreate = false;
                addModal.close();
                server.triggerScan();
            }
        }
    }

    // ------------------------------------------------------------- scan
    ColumnLayout {
        property string anchorId: "scan"
        function pulse() { scanHeading.color = Tokens.themeAccent; scanReset.restart(); }
        Timer { id: scanReset; interval: 1400; onTriggered: scanHeading.color = Tokens.textPrimary }
        Layout.fillWidth: true
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    id: scanHeading
                    text: qsTr("Scan")
                    color: Tokens.textPrimary
                    font.family: Tokens.fontSans
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: qsTr("Walks every library root and updates the catalog. Safe to run while watching.")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }
            UiButton {
                text: qsTr("Scan now")
                icon: "scan"
                loading: page.scanning
                enabled: !page.scanning
                onClicked: server.triggerScan()
            }
        }
        RowLayout {
            visible: page.scanning
            spacing: 8
            UiSpinner { size: 14; color: Tokens.themeAccent }
            Text { text: qsTr("Scanning libraries…"); color: Tokens.themeAccent; font.family: Tokens.fontSans; font.pixelSize: 13 }
        }
        Text {
            Layout.fillWidth: true
            visible: page.scan.state === "error"
            text: qsTr("Scan failed: %1").arg(page.scan.error || "")
            color: Tokens.danger
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        Text {
            Layout.fillWidth: true
            visible: page.scan.state === "done"
            textFormat: Text.StyledText
            wrapMode: Text.WordWrap
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            text: {
                var s = page.stats;
                var when = page.scan.finished_at ? page.relative(page.scan.finished_at) : qsTr("finished");
                var by = page.scan.trigger === "watch" ? " " + qsTr("by the filesystem watcher") : "";
                if (!s)
                    return qsTr("Last scan %1%2.").arg(when).arg(by);
                var fg = Tokens.textPrimary;
                function n(v, c) { return "<font color='" + (c || fg) + "'>" + v + "</font>"; }
                var out = qsTr("Last scan %1%2:").arg(when).arg(by) + " "
                    + qsTr("%1 identified").arg(n(s.identified || 0)) + " · "
                    + qsTr("%1 unidentified").arg(n(s.unidentified || 0)) + " · "
                    + qsTr("%1 enriched").arg(n(s.enriched || 0));
                if (s.missing > 0) out += " · " + n(qsTr("%1 missing").arg(s.missing), Tokens.warning);
                if (s.restored > 0) out += " · " + qsTr("%1 restored").arg(n(s.restored));
                if (s.walk_errors > 0) out += " · " + n(qsTr("%1 unreadable").arg(s.walk_errors), Tokens.warning);
                if (s.errors > 0) out += " · " + n(qsTr("%1 errors").arg(s.errors), Tokens.danger);
                return out;
            }
        }
        Repeater {
            model: page.stats && page.stats.unreadable ? page.stats.unreadable : []
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                color: Tokens.warning
                font.family: Tokens.fontSans
                font.pixelSize: 13
                text: qsTr("%1 (%2) — %3. Check that the drive is mounted and readable by the server, then scan again. Nothing was marked missing for it.")
                      .arg(modelData.name).arg(modelData.path).arg(modelData.reason)
            }
        }
        Text {
            visible: !page.scan.state || page.scan.state === "idle"
            text: qsTr("No scan recorded yet.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
    }

    // --------------------------------------------------------- libraries
    ColumnLayout {
        property string anchorId: "libraries"
        function pulse() { libHeading.color = Tokens.themeAccent; libReset.restart(); }
        Timer { id: libReset; interval: 1400; onTriggered: libHeading.color = Tokens.textPrimary }
        Layout.fillWidth: true
        Layout.topMargin: 40
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Text {
                id: libHeading
                Layout.fillWidth: true
                text: qsTr("Media libraries")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            UiButton {
                objectName: "addLibraryButton"
                text: qsTr("Add library")
                icon: "folder-plus"
                variant: "secondary"
                size: "sm"
                onClicked: page.openAdd()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: 16
            Layout.bottomMargin: 16
            visible: page.libraries.length === 0
            spacing: 8
            Glyph { Layout.alignment: Qt.AlignHCenter; name: "folder-plus"; size: 24; color: Tokens.textTertiary }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No libraries configured")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 420
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("A library is a directory on the server Lain is allowed to read. Nothing is copied or moved.")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 13
                wrapMode: Text.WordWrap
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            visible: page.libraries.length > 0
            Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
            Repeater {
                model: page.libraries
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 0
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 64
                        color: Qt.alpha(Tokens.surface1, 0.4)
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 8
                            spacing: 12
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                RowLayout {
                                    spacing: 8
                                    Text {
                                        text: modelData.name
                                        color: Tokens.textPrimary
                                        font.family: Tokens.fontSans
                                        font.pixelSize: 14
                                        font.weight: Font.Medium
                                    }
                                    UiBadge { text: modelData.type }
                                    UiBadge { visible: page.unreadable(modelData.id); text: qsTr("unreadable"); tone: "warning" }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.path
                                    color: Tokens.textTertiary
                                    font.family: Tokens.fontFamily
                                    font.pixelSize: 12
                                    elide: Text.ElideMiddle
                                }
                            }
                            UiButton {
                                text: qsTr("Remove")
                                icon: "trash"
                                variant: "ghost"
                                size: "sm"
                                Accessible.name: qsTr("Remove %1").arg(modelData.name)
                                onClicked: { page.removeTarget = modelData; removeModal.open(); }
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: Tokens.hairline }
                }
            }
        }
    }

    // ------------------------------------------------------------- modals
    UiModal {
        id: addModal
        objectName: "addLibraryModal"
        title: qsTr("Add a media library")
        description: qsTr("Lain indexes files in place. Nothing is copied, moved or modified.")
        Text {
            Layout.fillWidth: true
            visible: page.formError !== ""
            text: page.formError
            color: Tokens.danger
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WordWrap
        }
        UiField { id: nameField; Layout.fillWidth: true; label: qsTr("Name"); placeholder: qsTr("Anime") }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: qsTr("Type"); color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
            UiSelect {
                Layout.fillWidth: true
                model: page.typeOptions
                current: page.newType
                onPicked: id => page.newType = id
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            Text { text: qsTr("Server folders"); color: Tokens.textPrimary; font.family: Tokens.fontSans; font.pixelSize: 13; font.weight: Font.Medium }
            Text {
                visible: server.browsing
                text: qsTr("Listing server folders…")
                color: Tokens.textTertiary
                font.family: Tokens.fontSans
                font.pixelSize: 13
            }
            RowLayout {
                visible: !server.browsing && server.browseError !== ""
                Text { Layout.fillWidth: true; text: server.browseError; color: Tokens.danger; font.family: Tokens.fontSans; font.pixelSize: 13; wrapMode: Text.WordWrap }
                UiButton { text: qsTr("Retry"); variant: "ghost"; size: "sm"; onClicked: server.browseFolders("") }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: !server.browsing && server.browseError === ""
                spacing: 6
                Text {
                    Layout.fillWidth: true
                    text: server.browseResult.path || ""
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
                RowLayout {
                    spacing: 8
                    UiButton {
                        text: qsTr("Up")
                        icon: "arrow-up"
                        variant: "ghost"
                        size: "sm"
                        enabled: !!server.browseResult.parent
                        onClicked: server.browseFolders(server.browseResult.parent)
                    }
                    UiButton {
                        objectName: "useThisFolder"
                        text: qsTr("Use this folder")
                        variant: "secondary"
                        size: "sm"
                        onClicked: page.useFolder(null)
                    }
                }
                Text {
                    visible: (server.browseResult.dirs || []).length === 0
                    text: qsTr("No subfolders here.")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontSans
                    font.pixelSize: 13
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: (server.browseResult.dirs || []).length > 0
                    implicitHeight: Math.min(176, dirCol.implicitHeight + 2)
                    color: "transparent"
                    border.color: Tokens.hairline
                    clip: true
                    Flickable {
                        anchors.fill: parent
                        anchors.margins: 1
                        contentHeight: dirCol.implicitHeight
                        boundsBehavior: Flickable.StopAtBounds
                        ColumnLayout {
                            id: dirCol
                            width: parent.width
                            spacing: 0
                            Repeater {
                                model: server.browseResult.dirs || []
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: 40
                                    color: dirHover.hovered ? Tokens.hoverFill : Qt.alpha(Tokens.surface1, 0.4)
                                    HoverHandler { id: dirHover }
                                    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Tokens.hairline; visible: index > 0 }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 4
                                        spacing: 8
                                        Glyph { name: "folder"; size: 16; color: Tokens.textTertiary }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: Tokens.textPrimary
                                            font.family: Tokens.fontSans
                                            font.pixelSize: 13
                                            elide: Text.ElideRight
                                            TapHandler { onTapped: server.browseFolders(modelData.path) }
                                        }
                                        UiButton { text: qsTr("Use"); variant: "ghost"; size: "sm"; onClicked: page.useFolder(modelData) }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        UiField {
            id: pathField
            Layout.fillWidth: true
            label: qsTr("Server directory path")
            placeholder: "/media/anime"
            mono: true
            hint: qsTr("Filled in by the folder picker above; type only for paths outside it. In Docker, use the container path.")
            onAccepted: page.create()
        }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: addModal.close() },
            UiButton { text: qsTr("Add and scan"); loading: page.pendingCreate; onClicked: page.create() }
        ]
    }

    UiModal {
        id: removeModal
        title: qsTr("Remove library?")
        description: qsTr("The files on disk stay untouched. Its catalog entries are removed with it.")
        Text {
            Layout.fillWidth: true
            textFormat: Text.StyledText
            text: page.removeTarget ? "<b>" + page.removeTarget.name + "</b> — " + page.removeTarget.path : ""
            color: Tokens.textSecondary
            font.family: Tokens.fontSans
            font.pixelSize: 13
            wrapMode: Text.WrapAnywhere
        }
        footer: [
            UiButton { text: qsTr("Cancel"); variant: "ghost"; onClicked: removeModal.close() },
            UiButton {
                text: qsTr("Remove library")
                variant: "danger"
                onClicked: {
                    if (page.removeTarget)
                        server.deleteLibrary(page.removeTarget.id);
                    removeModal.close();
                    page.removeTarget = null;
                }
            }
        ]
    }
}
