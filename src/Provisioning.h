#pragma once
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QObject>
#include <QProcess>
#include <QVariantList>
#include <functional>

// First-run provisioning model (DD-022..DD-026).
// Detects an existing server plus local Docker/systemd tooling, provisions
// new local servers (Docker compose, systemd user service, or binary),
// records desktop-provisioned ownership (QSettings plus a marker file),
// controls lifecycle only for owned installations (DD-018/DD-024), and
// tracks server updates (notify/manual-apply, never automatic).
// Privileged media fixes go through Polkit (pkexec). External servers are
// connection targets only and are never managed here.
class Provisioning : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool probing READ probing NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool serverReachable READ serverReachable NOTIFY changed)
    Q_PROPERTY(QString serverVersion READ serverVersion NOTIFY changed)
    Q_PROPERTY(bool dockerAvailable READ dockerAvailable NOTIFY changed)
    Q_PROPERTY(bool systemdAvailable READ systemdAvailable NOTIFY changed)
    Q_PROPERTY(QVariantList methods READ methods NOTIFY changed)
    Q_PROPERTY(bool owned READ owned NOTIFY changed)
    Q_PROPERTY(QString ownedMethod READ ownedMethod NOTIFY changed)
    Q_PROPERTY(QString ownedPath READ ownedPath NOTIFY changed)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    Q_PROPERTY(bool updateAvailable READ updateAvailable NOTIFY changed)
    Q_PROPERTY(QString statusMessage READ statusMessage NOTIFY changed)
    Q_PROPERTY(QString desktopExecutable READ desktopExecutable CONSTANT)
    Q_PROPERTY(QString desktopLatest READ desktopLatest NOTIFY changed)
    Q_PROPERTY(bool desktopUpdateAvailable READ desktopUpdateAvailable NOTIFY changed)
public:
    explicit Provisioning(QObject *parent = nullptr);

    bool probing() const { return m_probing; }
    bool busy() const { return m_busy; }
    bool serverReachable() const { return m_serverReachable; }
    QString serverVersion() const { return m_serverVersion; }
    bool dockerAvailable() const { return m_dockerAvailable; }
    bool systemdAvailable() const { return m_systemdAvailable; }
    QVariantList methods() const;
    bool owned() const { return m_owned; }
    QString ownedMethod() const { return m_ownedMethod; }
    QString ownedPath() const { return m_ownedPath; }
    QString latestVersion() const { return m_latestVersion; }
    bool updateAvailable() const;
    QString statusMessage() const { return m_status; }
    QString desktopExecutable() const;
    QString desktopLatest() const { return m_desktopLatest; }
    bool desktopUpdateAvailable() const;

    Q_INVOKABLE void probe(const QString &serverUrl);
    Q_INVOKABLE void checkForUpdates();
    Q_INVOKABLE void setOwned(const QString &method, const QString &path, const QString &version);
    Q_INVOKABLE void clearOwned();

    // Provisioning execution and owned-only lifecycle (DD-022..DD-026).
    // params: port, dataDir, mediaDir, version (all optional, sane defaults).
    Q_INVOKABLE void provision(const QString &method, const QVariantMap &params);
    Q_INVOKABLE void startOwned();
    Q_INVOKABLE void stopOwned();
    Q_INVOKABLE void updateOwned();
    Q_INVOKABLE void uninstallOwned();
    Q_INVOKABLE void fixMediaPermissions(const QString &path);

    // Desktop self-update (manual apply only, never automatic). The check
    // reads the latest lain-desktop tag; apply downloads the AppImage for
    // this arch, verifies its sha256 sidecar, swaps it over targetPath,
    // and refreshes the launcher icon. The running process keeps its own
    // inode, so the update takes effect on next launch.
    Q_INVOKABLE void checkDesktopUpdates();
    Q_INVOKABLE void applyDesktopUpdate(const QString &targetPath);
    static int compareVersions(const QString &a, const QString &b);
    static QString desktopAssetUrl(const QString &tag);

    // Test seam: redirect HOME-based paths under base and record external
    // commands instead of executing them. Never called by production UI.
    void enableTestMode(const QString &base);
    QStringList executedCommands() const { return m_commands; }
    void clearExecuted() { m_commands.clear(); }
    // Visible for tests: install an already-verified AppImage file.
    bool installDesktopFile(const QString &sourcePath, const QString &targetPath);

signals:
    void changed();
    void taskFinished(bool ok, const QString &message);

private:
    using Step = std::function<void()>;

    void setProbing(bool probing);
    void setBusy(bool busy);
    void setStatus(const QString &status);
    void finishTask(bool ok, const QString &message);
    void checkServer(const QString &serverUrl);
    void checkTools();
    void loadOwnership();
    static QString markerPath();
    static QString normalizeMethod(const QString &method);

    // Home-relative locations (redirected under the test base in tests).
    QString homeBase() const;
    QString composeDir() const;
    QString dataDirDefault() const;
    QString mediaDirDefault() const;
    QString unitDir() const;
    QString unitFile() const;
    QString binDir() const;
    QString serverBin() const;

    // File generators mirroring scripts/install.sh (same marker semantics).
    static QString composeYaml(const QString &image, int port, const QString &dataDir,
                               const QStringList &mediaDirs);
    static QString envFile();
    static QString unitContent(const QString &exe, const QString &dataDir, int port);
    static bool writeFileAtomic(const QString &path, const QString &content);
    static QString releaseAssetUrl(const QString &version, const QString &arch);
    static QString hostArch();

    // Async process runner. In test mode records instead of executing.
    void runStep(const QString &program, const QStringList &args, const QString &workDir,
                 Step next, const QString &failure);
    void runSteps(const QList<std::tuple<QString, QStringList, QString, QString>> &steps, Step done);
    void fetchBinary(const QString &url, Step done);
    bool refuseUnlessOwned(const char *what);

    QNetworkAccessManager *m_net = nullptr;
    bool m_probing = false;
    bool m_busy = false;
    bool m_serverReachable = false;
    QString m_serverVersion;
    bool m_dockerAvailable = false;
    bool m_systemdAvailable = false;
    bool m_owned = false;
    QString m_ownedMethod;
    QString m_ownedPath;
    QString m_ownedVersion;
    QString m_latestVersion;
    QString m_status;
    QString m_desktopLatest;

    QString m_testBase;
    QStringList m_commands;
};
