import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Lain
import "../../components"

// Web settings/backup (admin): download a consistent database snapshot.
SettingsPage {
    id: page
    function stamp() {
        return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmm");
    }
    SettingsGroup {
        first: true
        anchorId: "backup"
        title: qsTr("Backup")
        SettingRow {
            label: qsTr("Database snapshot")
            hint: qsTr("Users, progress, libraries and metadata overlays. Media files are never included.")
            UiButton {
                text: qsTr("Download backup")
                icon: "download"
                variant: "secondary"
                size: "sm"
                onClicked: backupDialog.open()
            }
        }
    }
    FileDialog {
        id: backupDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "db"
        currentFile: "lain-backup-" + page.stamp() + ".db"
        nameFilters: [qsTr("Database (*.db)"), qsTr("All files (*)")]
        onAccepted: {
            var path = String(backupDialog.selectedFile).replace(/^file:\/\//, "");
            server.downloadBackup(decodeURIComponent(path));
        }
    }
}
