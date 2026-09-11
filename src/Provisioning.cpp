#include "Provisioning.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSettings>
#include <QStandardPaths>
#include <QSysInfo>
#include <QTemporaryDir>
#include <QUrl>
#include <unistd.h>

namespace {
const char *kOwnedKey = "provisioning/owned";
const char *kMethodKey = "provisioning/method";
const char *kPathKey = "provisioning/path";
const char *kVersionKey = "provisioning/version";

bool runOk(const QString &program, const QStringList &args, int timeoutMs = 8000) {
    QProcess proc;
    proc.start(program, args);
    if (!proc.waitForStarted(3000))
        return false;
    if (!proc.waitForFinished(timeoutMs))
        return false;
    return proc.exitCode() == 0;
}
} // namespace

Provisioning::Provisioning(QObject *parent) : QObject(parent) {
    m_net = new QNetworkAccessManager(this);
    loadOwnership();
}

QVariantList Provisioning::methods() const {
    // DD-025: hide Docker when the daemon is missing; always offer
    // user-service and binary fallbacks.
    QVariantList out;
    if (m_dockerAvailable)
        out << QVariantMap{{"id", QStringLiteral("docker")}, {"label", QStringLiteral("Docker")}};
    out << QVariantMap{{"id", QStringLiteral("service")}, {"label", tr("User service")}};
    out << QVariantMap{{"id", QStringLiteral("binary")}, {"label", tr("Binary")}};
    return out;
}

bool Provisioning::updateAvailable() const {
    if (m_latestVersion.isEmpty() || m_serverVersion.isEmpty())
        return false;
    return m_latestVersion != m_serverVersion;
}

void Provisioning::probe(const QString &serverUrl) {
    setProbing(true);
    setStatus(tr("Checking for a local server and provisioning tools…"));
    checkTools();
    checkServer(serverUrl);
}

void Provisioning::checkForUpdates() {
    // DD-026: track latest GitHub release, notify only, never auto-apply.
    setStatus(tr("Checking for server updates…"));
    QNetworkRequest req(QUrl(QStringLiteral("https://api.github.com/repos/enrell/lain/releases/latest")));
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lain-desktop"));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setStatus(tr("Could not check for updates."));
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QString tag = obj.value("tag_name").toString().trimmed();
        if (!tag.isEmpty()) {
            m_latestVersion = tag.startsWith(QLatin1Char('v')) ? tag.mid(1) : tag;
            if (updateAvailable())
                setStatus(tr("Server update available: %1").arg(obj.value("tag_name").toString()));
            else
                setStatus(tr("Server is up to date."));
            emit changed();
        } else {
            setStatus(tr("Could not check for updates."));
        }
    });
}

void Provisioning::setOwned(const QString &method, const QString &path, const QString &version) {
    m_owned = true;
    m_ownedMethod = normalizeMethod(method);
    m_ownedPath = path;
    m_ownedVersion = version;
    QSettings settings;
    settings.setValue(kOwnedKey, true);
    settings.setValue(kMethodKey, m_ownedMethod);
    settings.setValue(kPathKey, path);
    settings.setValue(kVersionKey, version);
    const QString markerFile = markerPath();
    QDir().mkpath(QFileInfo(markerFile).absolutePath());
    QFile marker(markerFile);
    if (marker.open(QIODevice::WriteOnly | QIODevice::Text)) {
        const QJsonObject doc{{"owned", true},
                              {"method", m_ownedMethod},
                              {"path", path},
                              {"version", version}};
        marker.write(QJsonDocument(doc).toJson(QJsonDocument::Compact));
    }
    emit changed();
}

void Provisioning::clearOwned() {
    m_owned = false;
    m_ownedMethod.clear();
    m_ownedPath.clear();
    m_ownedVersion.clear();
    QSettings settings;
    settings.remove(kOwnedKey);
    settings.remove(kMethodKey);
    settings.remove(kPathKey);
    settings.remove(kVersionKey);
    QFile::remove(markerPath());
    emit changed();
}

void Provisioning::setProbing(bool probing) {
    if (m_probing == probing)
        return;
    m_probing = probing;
    emit changed();
}

void Provisioning::setStatus(const QString &status) {
    if (m_status == status)
        return;
    m_status = status;
    emit changed();
}

void Provisioning::checkServer(const QString &serverUrl) {
    QString base = serverUrl.trimmed();
    if (base.isEmpty())
        base = QStringLiteral("http://127.0.0.1:9360");
    while (base.endsWith(QLatin1Char('/')))
        base.chop(1);
    QNetworkRequest req(QUrl(base + QStringLiteral("/api/health")));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        m_serverReachable = reply->error() == QNetworkReply::NoError;
        m_serverVersion.clear();
        if (m_serverReachable) {
            const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
            m_serverVersion = obj.value("version").toString();
        }
        setProbing(false);
        if (m_serverReachable)
            setStatus(tr("Found a local server. Connect to avoid duplicates."));
        else
            setStatus(tr("No local server found. Provision a new one or retry."));
        emit changed();
    });
}

void Provisioning::checkTools() {
    // Docker is available only when the daemon answers compose version.
    m_dockerAvailable = runOk(QStringLiteral("docker"), {"compose", "version"});
    m_systemdAvailable = runOk(QStringLiteral("systemctl"), {"--user", "--version"});
    emit changed();
}

void Provisioning::loadOwnership() {
    QSettings settings;
    m_owned = settings.value(kOwnedKey, false).toBool();
    m_ownedMethod = normalizeMethod(settings.value(kMethodKey).toString());
    m_ownedPath = settings.value(kPathKey).toString();
    m_ownedVersion = settings.value(kVersionKey).toString();
    if (!m_owned)
        return;
    QFile marker(markerPath());
    if (marker.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonObject doc = QJsonDocument::fromJson(marker.readAll()).object();
        if (!doc.value("owned").toBool()) {
            m_owned = false;
            m_ownedMethod.clear();
        }
    }
}

QString Provisioning::markerPath() {
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation);
    return dir + QStringLiteral("/provisioning-owned.json");
}

QString Provisioning::normalizeMethod(const QString &method) {
    const QString v = method.trimmed().toLower();
    if (v == QStringLiteral("docker") || v == QStringLiteral("service") || v == QStringLiteral("binary"))
        return v;
    return {};
}

// ------------------------------------------------------- execution (DD-022)

void Provisioning::enableTestMode(const QString &base) {
    m_testBase = base;
}

QString Provisioning::homeBase() const {
    return m_testBase.isEmpty() ? QDir::homePath() : m_testBase;
}

QString Provisioning::composeDir() const {
    return homeBase() + QStringLiteral("/.lain");
}

QString Provisioning::dataDirDefault() const {
    return homeBase() + QStringLiteral("/.local/share/lain");
}

QString Provisioning::mediaDirDefault() const {
    const QString videos = homeBase() + QStringLiteral("/Videos");
    return QDir(videos).exists() ? videos : homeBase();
}

QString Provisioning::unitDir() const {
    return homeBase() + QStringLiteral("/.config/systemd/user");
}

QString Provisioning::unitFile() const {
    return unitDir() + QStringLiteral("/lain.service");
}

QString Provisioning::binDir() const {
    return homeBase() + QStringLiteral("/.local/bin");
}

QString Provisioning::serverBin() const {
    return binDir() + QStringLiteral("/lain");
}

QString Provisioning::hostArch() {
    const QString arch = QSysInfo::currentCpuArchitecture().toLower();
    if (arch.contains(QStringLiteral("arm") ) || arch.contains(QStringLiteral("aarch64")))
        return QStringLiteral("aarch64");
    return QStringLiteral("x86_64");
}

QString Provisioning::releaseAssetUrl(const QString &version, const QString &arch) {
    // Mirrors scripts/install.sh: lain_<ver-without-v>_linux_<arch>.tar.gz.
    // "latest" resolves through the redirecting download endpoint.
    const QString v = version.startsWith(QLatin1Char('v')) ? version.mid(1) : version;
    const QString asset = QStringLiteral("lain_%1_linux_%2.tar.gz").arg(v, arch);
    if (version == QLatin1String("latest") || version.isEmpty())
        return QStringLiteral("https://github.com/enrell/lain/releases/latest/download/") + asset;
    const QString tag = version.startsWith(QLatin1Char('v')) ? version : QStringLiteral("v") + version;
    return QStringLiteral("https://github.com/enrell/lain/releases/download/%1/%2").arg(tag, asset);
}

QString Provisioning::composeYaml(const QString &image, int port, const QString &dataDir,
                                  const QStringList &mediaDirs) {
    QString out;
    out += "# Generated by lain-desktop -- yours to audit and edit.\n";
    out += "# Apply edits: docker compose up -d\n";
    out += "# Volume syntax: HOST_DIRECTORY:CONTAINER_DIRECTORY:ro\n";
    out += "services:\n  lain:\n";
    out += QStringLiteral("    image: %1\n").arg(image);
    out += "    container_name: lain\n    restart: unless-stopped\n";
    out += "    user: \"${UID}:${GID}\"\n";
    out += QStringLiteral("    ports:\n      - \"%1:9360\"\n").arg(port);
    out += QStringLiteral("    volumes:\n      - \"%1:/data\"\n").arg(dataDir);
    for (const QString &media : mediaDirs)
        out += QStringLiteral("      - \"%1:/media/%2:ro\"\n").arg(media, QFileInfo(media).fileName());
    out += "    environment:\n      GOMEMLIMIT: 256MiB\n      GOGC: \"100\"\n";
    out += "    mem_limit: 384m\n";
    return out;
}

QString Provisioning::envFile() {
    return QStringLiteral("# Generated by lain-desktop -- host UID/GID.\nUID=%1\nGID=%2\n")
        .arg(QString::number(::getuid()), QString::number(::getgid()));
}

QString Provisioning::unitContent(const QString &exe, const QString &dataDir, int port) {
    QString out;
    out += "# Generated by lain-desktop -- do not edit; re-run setup to regenerate.\n";
    out += "[Unit]\nDescription=lain media server\nDocumentation=https://github.com/enrell/lain\n\n";
    out += "[Service]\n";
    out += QStringLiteral("ExecStart=%1 serve --data-dir %2 --port %3\n").arg(exe, dataDir).arg(port);
    out += "Restart=on-failure\nRestartSec=3\n\n[Install]\nWantedBy=default.target\n";
    return out;
}

bool Provisioning::writeFileAtomic(const QString &path, const QString &content) {
    QDir().mkpath(QFileInfo(path).absolutePath());
    const QString tmp = path + QStringLiteral(".tmp");
    QFile f(tmp);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate))
        return false;
    f.write(content.toUtf8());
    f.close();
    if (QFile::exists(path) && !QFile::remove(path))
        return false;
    return QFile::rename(tmp, path);
}

void Provisioning::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit changed();
}

void Provisioning::finishTask(bool ok, const QString &message) {
    setBusy(false);
    setStatus(message);
    emit taskFinished(ok, message);
}

bool Provisioning::refuseUnlessOwned(const char *what) {
    Q_UNUSED(what);
    if (m_owned)
        return false;
    // DD-018/DD-024: external installations are connection targets only.
    finishTask(false, tr("Only installations provisioned by this app can be managed."));
    return true;
}

void Provisioning::runStep(const QString &program, const QStringList &args, const QString &workDir,
                           Step next, const QString &failure) {
    const QString record = workDir.isEmpty()
                               ? program + QLatin1Char(' ') + args.join(QLatin1Char(' '))
                               : QStringLiteral("[%1] %2 %3").arg(workDir, program,
                                                                 args.join(QLatin1Char(' ')));
    if (!m_testBase.isEmpty()) {
        m_commands << record;
        emit changed();
        if (next)
            next();
        return;
    }
    QProcess *proc = new QProcess(this);
    if (!workDir.isEmpty())
        proc->setWorkingDirectory(workDir);
    connect(proc, qOverload<int, QProcess::ExitStatus>(&QProcess::finished), this,
            [this, proc, next, failure](int code, QProcess::ExitStatus status) {
                proc->deleteLater();
                if (status != QProcess::NormalExit || code != 0) {
                    const QString err = QString::fromUtf8(proc->readAllStandardError()).trimmed();
                    finishTask(false, err.isEmpty() ? failure : err.split(QLatin1Char('\n')).first());
                    return;
                }
                if (next)
                    next();
            });
    connect(proc, &QProcess::errorOccurred, this, [this, proc, failure](QProcess::ProcessError) {
        proc->deleteLater();
        finishTask(false, failure);
    });
    proc->start(program, args);
}

void Provisioning::runSteps(const QList<std::tuple<QString, QStringList, QString, QString>> &steps,
                            Step done) {
    if (steps.isEmpty()) {
        if (done)
            done();
        return;
    }
    const auto &[program, args, workDir, failure] = steps.first();
    runStep(program, args, workDir, [this, steps, done] {
        runSteps(steps.mid(1), done);
    }, failure);
}

static int paramPort(const QVariantMap &params) {
    bool ok = false;
    const int port = params.value(QStringLiteral("port"), 9360).toInt(&ok);
    if (!ok || port < 1 || port > 65535)
        return -1;
    return port;
}

void Provisioning::provision(const QString &method, const QVariantMap &params) {
    const QString kind = normalizeMethod(method);
    if (kind.isEmpty()) {
        finishTask(false, tr("Unknown provisioning method."));
        return;
    }
    if (kind == QLatin1String("docker") && !m_dockerAvailable && m_testBase.isEmpty()) {
        finishTask(false, tr("Docker needs a running daemon. Install Docker manually, then return."));
        return;
    }
    const int port = paramPort(params);
    if (port < 0) {
        finishTask(false, tr("Port must be an integer between 1 and 65535."));
        return;
    }
    const QString version = params.value(QStringLiteral("version"), QStringLiteral("latest")).toString();
    const QString dataDir = params.value(QStringLiteral("dataDir"), dataDirDefault()).toString();
    const QString mediaDir = params.value(QStringLiteral("mediaDir"), mediaDirDefault()).toString();
    setBusy(true);

    if (kind == QLatin1String("docker")) {
        const QString image = QStringLiteral("ghcr.io/enrell/lain:") +
                              (version.isEmpty() ? QStringLiteral("latest") : version);
        if (!QDir().mkpath(composeDir()) || !QDir().mkpath(dataDir)) {
            finishTask(false, tr("Could not create provisioning directories."));
            return;
        }
        if (!writeFileAtomic(composeDir() + QStringLiteral("/docker-compose.yml"),
                             composeYaml(image, port, dataDir, {mediaDir}))) {
            finishTask(false, tr("Could not write the compose file."));
            return;
        }
        if (!writeFileAtomic(composeDir() + QStringLiteral("/.env"), envFile())) {
            finishTask(false, tr("Could not write the compose environment."));
            return;
        }
        setStatus(tr("Starting the server container…"));
        runStep(QStringLiteral("docker"), {QStringLiteral("compose"), QStringLiteral("up"), QStringLiteral("-d")},
                composeDir(), [this, port, version] {
                    setOwned(QStringLiteral("docker"), composeDir(),
                             version.isEmpty() ? QStringLiteral("latest") : version);
                    finishTask(true, tr("Server container started on port %1.").arg(port));
                },
                tr("Could not start the server container."));
        return;
    }

    if (kind == QLatin1String("service") || kind == QLatin1String("binary")) {
        // Both methods need the server binary; the download is skipped in
        // test mode where no network side effects are wanted.
        const QString versionTag = version.isEmpty() ? QStringLiteral("latest") : version;
        const QString url = releaseAssetUrl(versionTag, hostArch());
        if (!m_testBase.isEmpty())
            m_commands << QStringLiteral("download %1").arg(url);
        const auto afterBinary = [this, kind, port, dataDir, versionTag] {
            if (kind == QLatin1String("binary")) {
                setOwned(QStringLiteral("binary"), serverBin(), versionTag);
                finishTask(true, tr("Server binary installed. Run it to start."));
                return;
            }
            if (!writeFileAtomic(unitFile(), unitContent(serverBin(), dataDir, port))) {
                finishTask(false, tr("Could not write the service unit."));
                return;
            }
            setStatus(tr("Enabling the user service…"));
            runSteps({
                         {QStringLiteral("systemctl"),
                          {QStringLiteral("--user"), QStringLiteral("daemon-reload")}, {},
                          tr("Service reload failed.")},
                         {QStringLiteral("systemctl"),
                          {QStringLiteral("--user"), QStringLiteral("enable"), QStringLiteral("--now"),
                           QStringLiteral("lain.service")},
                          {}, tr("Could not start the user service.")},
                     },
                     [this, port, versionTag] {
                         setOwned(QStringLiteral("service"), unitFile(), versionTag);
                         finishTask(true, tr("User service started on port %1.").arg(port));
                     });
        };
        if (!m_testBase.isEmpty()) {
            afterBinary();
            return;
        }
        if (!QDir().mkpath(binDir()) || !QDir().mkpath(dataDir)) {
            finishTask(false, tr("Could not create provisioning directories."));
            return;
        }
        setStatus(tr("Downloading the server release…"));
        fetchBinary(url, afterBinary);
        return;
    }
}

// Download a server release tarball and install the 'lain' binary it holds.
void Provisioning::fetchBinary(const QString &url, Step done) {
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lain-desktop"));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, done] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            finishTask(false, tr("Could not download the server release."));
            return;
        }
        const QString archive = QDir::tempPath() + QStringLiteral("/lain-server.tar.gz");
        QFile out(archive);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            finishTask(false, tr("Could not write the server download."));
            return;
        }
        out.write(reply->readAll());
        out.close();
        QProcess tar;
        tar.start(QStringLiteral("tar"),
                  {QStringLiteral("-xzf"), archive, QStringLiteral("-C"), QDir::tempPath()});
        if (!tar.waitForFinished(60000) || tar.exitCode() != 0) {
            finishTask(false, tr("Could not unpack the server release."));
            return;
        }
        // The tarball holds a single top-level 'lain' binary (install.sh).
        QString found;
        QDirIterator it(QDir::tempPath(), {"lain"}, QDir::Files, QDirIterator::Subdirectories);
        if (it.hasNext())
            found = it.next();
        if (found.isEmpty()) {
            finishTask(false, tr("Could not install the server binary."));
            return;
        }
        if (!QDir().mkpath(binDir())) {
            finishTask(false, tr("Could not create provisioning directories."));
            return;
        }
        if (QFile::exists(serverBin()) && !QFile::remove(serverBin())) {
            finishTask(false, tr("Could not install the server binary."));
            return;
        }
        if (!QFile::copy(found, serverBin())) {
            finishTask(false, tr("Could not install the server binary."));
            return;
        }
        QFile::setPermissions(serverBin(), QFile::permissions(serverBin()) | QFile::ExeOwner |
                                                 QFile::ExeGroup | QFile::ExeOther);
        if (done)
            done();
    });
}

void Provisioning::startOwned() {
    if (refuseUnlessOwned("start"))
        return;
    setBusy(true);
    if (m_ownedMethod == QLatin1String("docker")) {
        runStep(QStringLiteral("docker"), {QStringLiteral("compose"), QStringLiteral("up"), QStringLiteral("-d")},
                m_ownedPath, [this] { finishTask(true, tr("Server started.")); },
                tr("Could not start the server."));
    } else if (m_ownedMethod == QLatin1String("service")) {
        runStep(QStringLiteral("systemctl"),
                {QStringLiteral("--user"), QStringLiteral("start"), QStringLiteral("lain.service")}, {},
                [this] { finishTask(true, tr("Server started.")); }, tr("Could not start the server."));
    } else {
        finishTask(false, tr("Binary installations run manually."));
    }
}

void Provisioning::stopOwned() {
    if (refuseUnlessOwned("stop"))
        return;
    setBusy(true);
    if (m_ownedMethod == QLatin1String("docker")) {
        runStep(QStringLiteral("docker"), {QStringLiteral("compose"), QStringLiteral("down")}, m_ownedPath,
                [this] { finishTask(true, tr("Server stopped.")); }, tr("Could not stop the server."));
    } else if (m_ownedMethod == QLatin1String("service")) {
        runStep(QStringLiteral("systemctl"),
                {QStringLiteral("--user"), QStringLiteral("stop"), QStringLiteral("lain.service")}, {},
                [this] { finishTask(true, tr("Server stopped.")); }, tr("Could not stop the server."));
    } else {
        finishTask(false, tr("Binary installations run manually."));
    }
}

void Provisioning::updateOwned() {
    if (refuseUnlessOwned("update"))
        return;
    // DD-026: manual apply only; this entry point always comes from an
    // explicit user action, never from a timer.
    const QString target = m_latestVersion.isEmpty() ? QStringLiteral("latest") : m_latestVersion;
    if (m_ownedMethod == QLatin1String("docker")) {
        setBusy(true);
        runSteps({{QStringLiteral("docker"), {QStringLiteral("compose"), QStringLiteral("pull")}, m_ownedPath,
                   tr("Could not pull the server image.")},
                  {QStringLiteral("docker"),
                   {QStringLiteral("compose"), QStringLiteral("up"), QStringLiteral("-d")}, m_ownedPath,
                   tr("Could not restart the server.")}},
                 [this, target] {
                     QSettings().setValue("provisioning/version", target);
                     m_ownedVersion = target;
                     finishTask(true, tr("Server updated to %1.").arg(target));
                 });
    } else {
        // Service and binary installations update by replacing the binary
        // in place, keeping the current ownership record. Service units
        // restart to pick the new binary up.
        const QString url = releaseAssetUrl(target, hostArch());
        if (!m_testBase.isEmpty())
            m_commands << QStringLiteral("download %1").arg(url);
        setBusy(true);
        const auto afterFetch = [this, target] {
            QSettings().setValue("provisioning/version", target);
            m_ownedVersion = target;
            if (m_ownedMethod == QLatin1String("service")) {
                setStatus(tr("Restarting the user service…"));
                runStep(QStringLiteral("systemctl"),
                        {QStringLiteral("--user"), QStringLiteral("restart"),
                         QStringLiteral("lain.service")},
                        {}, [this, target] { finishTask(true, tr("Server updated to %1.").arg(target)); },
                        tr("Could not restart the service."));
                return;
            }
            finishTask(true, tr("Server updated to %1.").arg(target));
        };
        if (!m_testBase.isEmpty()) {
            afterFetch();
            return;
        }
        setStatus(tr("Downloading the server release…"));
        fetchBinary(url, afterFetch);
    }
}

void Provisioning::uninstallOwned() {
    if (refuseUnlessOwned("uninstall"))
        return;
    setBusy(true);
    if (m_ownedMethod == QLatin1String("docker")) {
        runStep(QStringLiteral("docker"), {QStringLiteral("compose"), QStringLiteral("down")}, m_ownedPath,
                [this] {
                    QFile::remove(m_ownedPath + QStringLiteral("/docker-compose.yml"));
                    QFile::remove(m_ownedPath + QStringLiteral("/.env"));
                    const QString path = m_ownedPath;
                    clearOwned();
                    finishTask(true, tr("Installation removed. Data kept at %1.").arg(path));
                },
                tr("Could not stop the server."));
    } else if (m_ownedMethod == QLatin1String("service")) {
        runSteps({{QStringLiteral("systemctl"),
                   {QStringLiteral("--user"), QStringLiteral("disable"), QStringLiteral("--now"),
                    QStringLiteral("lain.service")},
                   {}, tr("Could not stop the service.")},
                  {QStringLiteral("systemctl"), {QStringLiteral("--user"), QStringLiteral("daemon-reload")},
                   {}, tr("Service reload failed.")}},
                 [this] {
                     QFile::remove(unitFile());
                     clearOwned();
                     finishTask(true, tr("Service removed. Data and binary kept."));
                 });
    } else {
        const QString path = m_ownedPath;
        QFile::remove(serverBin());
        clearOwned();
        finishTask(true, tr("Binary removed from %1.").arg(path));
    }
}

void Provisioning::fixMediaPermissions(const QString &path) {
    // DD-022 extended allowlist: re-own a media directory through Polkit.
    // Hard guards: absolute directory paths only, never system locations.
    const QFileInfo info(path);
    if (path.isEmpty() || !info.isAbsolute() || !info.isDir()) {
        finishTask(false, tr("Choose an existing media directory first."));
        return;
    }
    const QString clean = QDir::cleanPath(info.absoluteFilePath());
    static const char *forbidden[] = {"/", "/bin", "/boot", "/dev", "/etc", "/home",
                                      "/opt", "/proc", "/root", "/run", "/srv", "/sys",
                                      "/tmp", "/usr", "/var"};
    for (const char *f : forbidden) {
        if (clean == QLatin1String(f)) {
            finishTask(false, tr("That location cannot be changed."));
            return;
        }
    }
    setBusy(true);
    runStep(QStringLiteral("pkexec"),
            {QStringLiteral("chown"), QStringLiteral("-R"),
             QStringLiteral("--reference=") + homeBase(), clean},
            {}, [this, clean] { finishTask(true, tr("Permissions fixed for %1.").arg(clean)); },
            tr("Permission change failed."));
}

// ------------------------------------------------- desktop self-update

QString Provisioning::desktopExecutable() const {
    return QCoreApplication::applicationFilePath();
}

int Provisioning::compareVersions(const QString &a, const QString &b) {
    // Numeric dotted comparison ignoring a leading 'v' and any suffix
    // after '-' or '+'. Missing segments read as zero.
    auto parts = [](const QString &v) {
        QString core = v.trimmed();
        if (core.startsWith(QLatin1Char('v')) || core.startsWith(QLatin1Char('V')))
            core = core.mid(1);
        const int cut = core.indexOf(QRegularExpression(QStringLiteral("[-+]")));
        if (cut >= 0)
            core = core.left(cut);
        QList<int> out;
        for (const QString &p : core.split(QLatin1Char('.'))) {
            bool ok = false;
            const int n = p.toInt(&ok);
            out << (ok ? n : 0);
        }
        return out;
    };
    const QList<int> pa = parts(a), pb = parts(b);
    for (int i = 0; i < qMax(pa.size(), pb.size()); ++i) {
        const int na = i < pa.size() ? pa[i] : 0;
        const int nb = i < pb.size() ? pb[i] : 0;
        if (na != nb)
            return na < nb ? -1 : 1;
    }
    return 0;
}

QString Provisioning::desktopAssetUrl(const QString &tag) {
    const QString clean = tag.trimmed().startsWith(QLatin1Char('v')) ? tag.trimmed() : QStringLiteral("v") + tag.trimmed();
    const QString ver = clean.mid(1);
    return QStringLiteral("https://github.com/enrell/lain-desktop/releases/download/%1/lain-desktop_%2_linux_x86_64.AppImage")
        .arg(clean, ver);
}

bool Provisioning::desktopUpdateAvailable() const {
    if (m_desktopLatest.isEmpty())
        return false;
    return compareVersions(QCoreApplication::applicationVersion(), m_desktopLatest) < 0;
}

void Provisioning::checkDesktopUpdates() {
    setStatus(tr("Checking for app updates…"));
    QNetworkRequest req{QUrl(QStringLiteral("https://api.github.com/repos/enrell/lain-desktop/releases/latest"))};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lain-desktop"));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setStatus(tr("Could not check for updates."));
            return;
        }
        const QJsonObject obj = QJsonDocument::fromJson(reply->readAll()).object();
        const QString tag = obj.value("tag_name").toString().trimmed();
        if (tag.isEmpty()) {
            setStatus(tr("Could not check for updates."));
            return;
        }
        m_desktopLatest = tag.startsWith(QLatin1Char('v')) ? tag.mid(1) : tag;
        if (desktopUpdateAvailable())
            setStatus(tr("App update available: %1").arg(tag));
        else
            setStatus(tr("App is up to date."));
        emit changed();
    });
}

bool Provisioning::installDesktopFile(const QString &sourcePath, const QString &targetPath) {
    const QFileInfo target(targetPath);
    if (sourcePath.isEmpty() || targetPath.isEmpty() || !target.isAbsolute())
        return false;
    if (!QDir().mkpath(target.absolutePath()))
        return false;
    QFile source(sourcePath);
    if (!source.open(QIODevice::ReadOnly))
        return false;
    source.close();
    if (!source.permissions().testFlag(QFile::ExeOwner) &&
        !QFile::setPermissions(sourcePath, source.permissions() | QFile::ExeOwner | QFile::ExeGroup |
                                                  QFile::ExeOther))
        return false;
    if (QFile::exists(targetPath)) {
        const QString backup = targetPath + QStringLiteral(".bak");
        QFile::remove(backup);
        if (!QFile::rename(targetPath, backup))
            return false;
    }
    if (!QFile::copy(sourcePath, targetPath))
        return false;
    // Refresh the launcher icon from the new bundle (same layout the
    // installer expects from every release asset).
    QTemporaryDir extract;
    if (extract.isValid()) {
        QProcess proc;
        proc.setWorkingDirectory(extract.path());
        proc.start(targetPath, {QStringLiteral("--appimage-extract"),
                                QStringLiteral("usr/share/icons/hicolor/256x256/apps/lain-desktop.png")});
        if (proc.waitForFinished(60000) && proc.exitCode() == 0) {
            const QString icon = extract.path() +
                                 QStringLiteral("/squashfs-root/usr/share/icons/hicolor/256x256/apps/lain-desktop.png");
            if (QFile::exists(icon)) {
                const QString dest = homeBase() +
                                     QStringLiteral("/.local/share/icons/hicolor/256x256/apps/lain-desktop.png");
                QDir().mkpath(QFileInfo(dest).absolutePath());
                QFile::remove(dest);
                QFile::copy(icon, dest);
            }
        }
    }
    return true;
}

void Provisioning::applyDesktopUpdate(const QString &targetPath) {
    if (targetPath.isEmpty() || m_desktopLatest.isEmpty()) {
        finishTask(false, tr("Check for app updates first."));
        return;
    }
    const QString tag = m_desktopLatest.startsWith(QLatin1Char('v')) ? m_desktopLatest
                                                                     : QStringLiteral("v") + m_desktopLatest;
    const QString url = desktopAssetUrl(tag);
    if (!m_testBase.isEmpty())
        m_commands << QStringLiteral("download %1").arg(url);
    setBusy(true);
    setStatus(tr("Downloading the app update…"));
    QNetworkRequest req{QUrl(url)};
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lain-desktop"));
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, url, targetPath, tag] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            finishTask(false, tr("Could not download the app update."));
            return;
        }
        const QByteArray bytes = reply->readAll();
        // Verify against the published sha256 sidecar before touching disk.
        QNetworkRequest sumReq(QUrl(url + QStringLiteral(".sha256")));
        sumReq.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("lain-desktop"));
        QNetworkReply *sumReply = m_net->get(sumReq);
        connect(sumReply, &QNetworkReply::finished, this, [this, sumReply, bytes, targetPath, tag] {
            sumReply->deleteLater();
            bool verified = false;
            if (sumReply->error() == QNetworkReply::NoError) {
                const QString expected =
                    QString::fromUtf8(sumReply->readAll()).split(QRegularExpression(QStringLiteral("\\s+"))).first();
                const QString actual = QString::fromLatin1(
                    QCryptographicHash::hash(bytes, QCryptographicHash::Sha256).toHex());
                verified = !expected.isEmpty() && expected.compare(actual, Qt::CaseInsensitive) == 0;
            }
            if (!verified) {
                finishTask(false, tr("App update failed checksum verification."));
                return;
            }
            const QString tmp = QDir::tempPath() + QStringLiteral("/lain-desktop-update.AppImage");
            QFile out(tmp);
            if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate) || out.write(bytes) != bytes.size()) {
                finishTask(false, tr("Could not write the app update."));
                return;
            }
            out.close();
            if (!installDesktopFile(tmp, targetPath)) {
                finishTask(false, tr("Could not install the app update."));
                return;
            }
            finishTask(true, tr("App updated to %1. Restart to use it.").arg(tag));
        });
    });
}
