#include "stubserver.h"

#include <algorithm>

#include <QJsonArray>
#include <QJsonDocument>
#include <QTcpSocket>
#include <QUrl>
#include <QUrlQuery>

namespace {

QByteArray respond(int status, const QByteArray &body, const char *reason) {
    QByteArray out;
    out += "HTTP/1.1 " + QByteArray::number(status) + ' ' + reason + "\r\n";
    out += "Content-Type: application/json\r\n";
    out += "Content-Length: " + QByteArray::number(body.size()) + "\r\n";
    out += "Connection: close\r\n\r\n";
    out += body;
    return out;
}

QByteArray json(int status, const QJsonObject &object, const char *reason = "OK") {
    return respond(status, QJsonDocument(object).toJson(QJsonDocument::Compact), reason);
}

QByteArray json(int status, const QJsonArray &array, const char *reason = "OK") {
    return respond(status, QJsonDocument(array).toJson(QJsonDocument::Compact), reason);
}

QJsonObject movieItem() {
    return QJsonObject{
        {"id", "movie-1"},
        {"library_id", "lib-movies"},
        {"kind", "video"},
        {"title", "Some Movie"},
        {"season", 0},
        {"episode", 0},
        {"year", 0},
        {"file_path", "/media/Movies/Some Movie (2019).mp4"},
        {"size", 6766429},
        {"confidence", 0.9},
        {"origin", "lain-identify-generic"},
        {"provenance", "identify:stub"},
        {"updated_at", 1700000003},
    };
}

QJsonObject showItem(int number, qint64 updatedAt) {
    return QJsonObject{
        {"id", QStringLiteral("show-%1").arg(number)},
        {"library_id", "lib-shows"},
        {"kind", "video"},
        // The real catalog title is the show name only — episode numbers
        // never leak into it, and the web groups shows by this field.
        {"title", "Frieren"},
        {"season", 0},
        {"episode", 0},
        {"year", 0},
        {"file_path", QStringLiteral("/media/Anime/Frieren - %1.webm").arg(number, 2, 10, QLatin1Char('0'))},
        {"size", 1891214},
        {"confidence", 0.4},
        {"origin", "lain-identify-generic"},
        {"provenance", "identify:stub"},
        {"updated_at", updatedAt},
    };
}

QJsonArray allItems() {
    return QJsonArray{movieItem(), showItem(1, 1700000002), showItem(2, 1700000001)};
}

QJsonObject findItem(const QString &id) {
    for (const QJsonValue &value : allItems()) {
        const QJsonObject item = value.toObject();
        if (item.value("id").toString() == id)
            return item;
    }
    return {};
}

QJsonObject enrichmentFor(const QString &id) {
    if (id == QLatin1String("movie-1")) {
        return QJsonObject{
            {"item_id", id},
            {"provider", "lain-metadata-nfo"},
            {"remote_id", "remote-movie"},
            {"title", "Some Movie"},
            {"year", 2019},
            {"genres", QJsonArray{"Drama", "Thriller"}},
            {"synopsis", "A synthetic movie used by the desktop tests."},
            {"poster", "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='240' height='360'%3E%3Crect width='240' height='360' fill='%23264f5e'/%3E%3C/svg%3E"},
            {"fetched_at", 1700000100},
        };
    }
    if (id.startsWith(QLatin1String("show-"))) {
        return QJsonObject{
            {"item_id", id},
            {"provider", "lain-metadata-nfo"},
            {"remote_id", "remote-show"},
            {"title", "Frieren: Beyond Journey's End"},
            {"year", 2023},
            {"genres", QJsonArray{"Adventure", "Fantasy"}},
            {"synopsis", "An elf mage revisits old friends after the hero's party saves the world."},
            {"fetched_at", 1700000100},
        };
    }
    return {};
}

QJsonObject progressFor(const QString &id) {
    if (id == QLatin1String("show-1")) {
        return QJsonObject{
            {"item_id", id},
            {"user_id", "user-admin"},
            {"position_sec", 15.0},
            {"duration_sec", 30.0},
            {"completed", false},
            {"updated_at", 1700000200},
        };
    }
    return QJsonObject{
        {"item_id", id},
        {"user_id", "user-admin"},
        {"position_sec", 0.0},
        {"duration_sec", 0.0},
        {"completed", false},
        {"updated_at", 0},
    };
}

QJsonArray libraries() {
    return QJsonArray{
        QJsonObject{{"id", "lib-movies"}, {"name", "Movies"}, {"type", "movie"},
                    {"path", "/media/Movies"}, {"source", "stub"}, {"created_at", 1}},
        QJsonObject{{"id", "lib-shows"}, {"name", "Anime"}, {"type", "anime"},
                    {"path", "/media/Anime"}, {"source", "stub"}, {"created_at", 2}},
    };
}

QJsonArray composition(quint64 generation, const QStringList &metadataOrder) {
    QJsonArray order;
    for (const QString &id : metadataOrder)
        order.append(id);
    return QJsonArray{
        QJsonObject{{"capability", "lain.metadata.search@1"},
                    {"mode", "merge-many"},
                    {"providers", order},
                    {"generation", static_cast<qint64>(generation)}},
        QJsonObject{{"capability", "lain.catalog.read@1"},
                    {"mode", "exactly-one"},
                    {"providers", QJsonArray{"lain-catalog-bolt"}},
                    {"generation", static_cast<qint64>(generation)}},
    };
}

QJsonArray users() {    return QJsonArray{
        QJsonObject{{"id", "user-admin"}, {"username", "admin"}, {"role", "admin"},
                    {"disabled", false}, {"pwd_ver", 1}, {"created_at", 1}},
        QJsonObject{{"id", "user-guest"}, {"username", "guest"}, {"role", "user"},
                    {"disabled", false}, {"pwd_ver", 1}, {"created_at", 2}},
    };
}

} // namespace

StubServer::StubServer(QObject *parent) : QObject(parent) {
    connect(&m_server, &QTcpServer::newConnection, this, [this] {
        while (QTcpSocket *socket = m_server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] { handleConnection(socket); });
            connect(socket, &QTcpSocket::disconnected, this, [this, socket] {
                m_buffers.remove(socket);
                socket->deleteLater();
            });
        }
    });
}

bool StubServer::listen() {
    return m_server.listen(QHostAddress::LocalHost, 0);
}

QString StubServer::baseUrl() const {
    return QStringLiteral("http://127.0.0.1:%1").arg(m_server.serverPort());
}

StubServer::~StubServer() {
    // Tear down accepted sockets while m_buffers is still alive. Without
    // this, member destruction order kills the buffer map first and the
    // sockets' disconnected() handlers then touch it mid-teardown
    // (intermittent exit segfault in every suite using the stub).
    m_server.close();
    const QList<QTcpSocket *> sockets = m_buffers.keys();
    for (QTcpSocket *socket : sockets) {
        QObject::disconnect(socket, nullptr, this, nullptr);
        delete socket;
    }
    m_buffers.clear();
}

void StubServer::reset() {
    requests.clear();
    progressPuts.clear();
}

void StubServer::handleConnection(QTcpSocket *socket) {
    QByteArray &buffer = m_buffers[socket];
    buffer += socket->readAll();

    const int headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd < 0)
        return;

    int contentLength = 0;
    const QList<QByteArray> lines = buffer.left(headerEnd).split('\n');
    for (const QByteArray &rawLine : lines) {
        const QByteArray line = rawLine.trimmed();
        const int colon = line.indexOf(':');
        if (colon > 0 && line.left(colon).trimmed().toLower() == "content-length")
            contentLength = line.mid(colon + 1).trimmed().toInt();
    }
    if (buffer.size() < headerEnd + 4 + contentLength)
        return;

    const QByteArray request = buffer.left(headerEnd + 4 + contentLength);
    m_buffers.remove(socket);
    dispatch(socket, request);
}

void StubServer::dispatch(QTcpSocket *socket, const QByteArray &request) {
    const int headerEnd = request.indexOf("\r\n\r\n");
    const QList<QByteArray> lines = request.left(headerEnd).split('\n');
    const QList<QByteArray> requestLine = lines.value(0).trimmed().split(' ');
    const QString method = QString::fromLatin1(requestLine.value(0));
    const QUrl url = QUrl::fromEncoded(requestLine.value(1));
    const QString path = url.path();

    QJsonObject headers;
    for (int i = 1; i < lines.size(); ++i) {
        const QByteArray line = lines.at(i).trimmed();
        const int colon = line.indexOf(':');
        if (colon > 0)
            headers.insert(QString::fromLatin1(line.left(colon).trimmed().toLower()),
                           QString::fromLatin1(line.mid(colon + 1).trimmed()));
    }

    const QByteArray body = request.mid(headerEnd + 4);
    requests.append({method, path});

    int status = 200;
    const QByteArray response = route(method, path, QUrlQuery(url), body, headers, status);
    Q_UNUSED(status);
    socket->write(response);
    socket->flush();
    socket->disconnectFromHost();
}

QByteArray StubServer::route(const QString &method, const QString &path, const QUrlQuery &query,
                             const QByteArray &body, const QJsonObject &headers, int &status) {
    const auto authorized = [this, &headers] {
        return headers.value("authorization").toString()
               == QStringLiteral("Bearer ") + token;
    };

    if (method == QLatin1String("GET") && path == QLatin1String("/api/setup/status")) {
        status = 200;
        return json(200, QJsonObject{{"setup_required", setupRequired}});
    }

    if (method == QLatin1String("GET")
        && (path == QLatin1String("/health") || path == QLatin1String("/api/health"))) {
        status = 200;
        return json(200, QJsonObject{{"status", "ok"}, {"version", "test-1.0"}});
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/setup")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        status = 201;
        return json(201, QJsonObject{{"id", "user-admin"},
                                     {"username", in.value("username").toString()},
                                     {"role", "admin"},
                                     {"disabled", false},
                                     {"pwd_ver", 1},
                                     {"created_at", 1}},
                    "Created");
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/auth/login")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        if (failLogin || in.value("password").toString() != password) {
            status = 401;
            return json(401, QJsonObject{{"error", "invalid credentials"}}, "Unauthorized");
        }
        status = 200;
        return json(200, QJsonObject{{"token", token}});
    }

    // Every route below requires a valid bearer token.
    if (!authorized()) {
        status = 401;
        return json(401, QJsonObject{{"error", "unauthorized"}}, "Unauthorized");
    }

    const auto me = [this] {
        QJsonObject avatar;
        if (!avatarKind.isEmpty())
            avatar.insert("kind", avatarKind);
        if (!mascot.isEmpty())
            avatar.insert("mascot", mascot);
        if (avatarVersion > 0)
            avatar.insert("version", avatarVersion);
        QJsonObject profile{{"avatar", avatar}};
        if (!displayName.isEmpty())
            profile.insert("display_name", displayName);
        if (!bio.isEmpty())
            profile.insert("bio", bio);
        QJsonObject user{{"id", "user-admin"}, {"username", "admin"}, {"role", "admin"},
                         {"disabled", false}, {"pwd_ver", 1}, {"created_at", 1},
                         {"profile", profile}};
        if (!preferredLanguage.isEmpty())
            user.insert("preferred_language", preferredLanguage);
        return user;
    };

    if (method == QLatin1String("GET") && path == QLatin1String("/api/me")) {
        status = 200;
        return json(200, me());
    }

    if (method == QLatin1String("PATCH") && path == QLatin1String("/api/me/profile")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        if (in.contains("display_name"))
            displayName = in.value("display_name").toString();
        if (in.contains("bio"))
            bio = in.value("bio").toString();
        if (in.contains("mascot")) {
            mascot = in.value("mascot").toString();
            avatarKind = mascot.isEmpty() ? QString() : QStringLiteral("mascot");
        }
        status = 200;
        return json(200, me());
    }

    if (path == QLatin1String("/api/me/avatar")) {
        if (method == QLatin1String("PUT")) {
            if (body.isEmpty()) {
                status = 400;
                return json(400, QJsonObject{{"error", "empty image"}}, "Bad Request");
            }
            avatarKind = QStringLiteral("upload");
            mascot.clear();
            avatarVersion++;
        } else if (method == QLatin1String("DELETE")) {
            avatarKind.clear();
            mascot.clear();
        }
        status = 200;
        return json(200, me());
    }

    if (method == QLatin1String("PATCH") && path == QLatin1String("/api/me/password")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        if (in.value("old").toString() != password) {
            status = 403;
            return json(403, QJsonObject{{"error", "wrong password"}}, "Forbidden");
        }
        password = in.value("new").toString();
        status = 200;
        return json(200, QJsonObject{{"status", "ok"}});
    }

    if (method == QLatin1String("PATCH") && path == QLatin1String("/api/me/preferences")) {
        preferredLanguage = QJsonDocument::fromJson(body).object().value("preferred_language").toString();
        status = 200;
        return json(200, me());
    }

    const auto linkView = [this] {
        return QJsonObject{{"platform", "anilist"}, {"remote_user_id", "42"},
                           {"remote_username", "lainfan"}, {"linked_at", 1700000000},
                           {"last_sync_at", 1700000500}, {"entry_count", 2},
                           {"scrobble", anilistScrobble}};
    };

    if (method == QLatin1String("GET") && path == QLatin1String("/api/me/links")) {
        status = 200;
        return json(200, QJsonObject{{"links", anilistLinked ? QJsonArray{linkView()} : QJsonArray{}}});
    }
    if (method == QLatin1String("GET") && path == QLatin1String("/api/me/links/anilist/pin")) {
        status = 200;
        return json(200, QJsonObject{{"url", "https://anilist.co/api/v2/oauth/pin"}});
    }
    if (method == QLatin1String("GET") && path == QLatin1String("/api/me/links/anilist/authorize")) {
        status = 409;
        return json(409, QJsonObject{{"error", "not configured"}, {"code", "not-configured"}}, "Conflict");
    }
    if (method == QLatin1String("POST") && path == QLatin1String("/api/me/links/anilist/code")) {
        if (QJsonDocument::fromJson(body).object().value("code").toString() != QLatin1String("good-code")) {
            status = 400;
            return json(400, QJsonObject{{"error", "invalid grant"}, {"code", "invalid-grant"}}, "Bad Request");
        }
        anilistLinked = true;
        status = 200;
        return json(200, QJsonObject{{"link", linkView()}});
    }
    if (method == QLatin1String("POST") && path == QLatin1String("/api/me/links/anilist/sync")) {
        status = 200;
        return json(200, QJsonObject{{"status", "ok"},
                                     {"stats", QJsonObject{{"upserted", 2}, {"removed", 0}}}});
    }
    if (path == QLatin1String("/api/me/links/anilist")) {
        if (method == QLatin1String("PATCH")) {
            anilistScrobble = QJsonDocument::fromJson(body).object().value("scrobble").toBool();
            status = 200;
            return json(200, linkView());
        }
        if (method == QLatin1String("DELETE")) {
            anilistLinked = false;
            status = 200;
            return json(200, QJsonObject{{"status", "ok"}, {"removed", 2}});
        }
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/list")) {
        QJsonArray entries;
        if (anilistLinked) {
            const QJsonArray all{
                QJsonObject{{"id", "le-1"}, {"user_id", "user-admin"}, {"platform", "anilist"},
                            {"remote_id", "154587"}, {"media_type", "anime"}, {"title", "Frieren"},
                            {"status", "current"}, {"progress", 12}, {"progress_total", 28},
                            {"score", 9}, {"updated_at", 1700000500}},
                QJsonObject{{"id", "le-2"}, {"user_id", "user-admin"}, {"platform", "anilist"},
                            {"remote_id", "30002"}, {"media_type", "manga"}, {"title", "Berserk"},
                            {"status", "planning"}, {"progress", 0}, {"updated_at", 1700000400}},
            };
            const QString type = query.queryItemValue("type");
            const QString st = query.queryItemValue("status");
            for (const QJsonValue &v : all) {
                const QJsonObject e = v.toObject();
                if (!type.isEmpty() && e.value("media_type").toString() != type)
                    continue;
                if (!st.isEmpty() && e.value("status").toString() != st)
                    continue;
                entries.append(e);
            }
        }
        status = 200;
        return json(200, QJsonObject{{"entries", entries}});
    }

    const auto integrationsBody = [this] {
        return QJsonObject{{"platforms", QJsonObject{{"anilist", QJsonObject{
            {"client_id", integrationClientId}, {"secret_set", integrationSecretSet},
            {"callback_url", "http://127.0.0.1:9360/api/links/anilist/callback"}}}}}};
    };
    if (path == QLatin1String("/api/admin/settings/integrations")) {
        if (method == QLatin1String("PUT")) {
            const QJsonObject in = QJsonDocument::fromJson(body).object();
            integrationClientId = in.value("anilist_client_id").toString();
            if (!in.value("anilist_client_secret").toString().isEmpty())
                integrationSecretSet = true;
        }
        status = 200;
        return json(200, integrationsBody());
    }

    const auto transcodeBody = [this] {
        return QJsonObject{
            {"settings", QJsonObject{{"default_delivery", "hls"}, {"hls_segment_seconds", 6},
                                     {"hls_segment_container", "fmp4"}, {"throttle", true},
                                     {"crf", transcodeCrf}, {"encoder_preset", "veryfast"},
                                     {"hardware_acceleration", "none"}, {"tone_mapping", false},
                                     {"subtitle_mode", "auto"}, {"audio_bitrate_kbps", 192},
                                     {"max_concurrent", 2}, {"qualities", QJsonArray{}}}},
            {"capabilities", QJsonObject{{"ffmpeg", "7.1"}, {"encoders", QJsonArray{"libx264"}},
                                         {"tone_mapping", false}, {"tone_mapping_bt2390", false},
                                         {"hardware", QJsonObject{{"vaapi", true}}}}}};
    };
    if (path == QLatin1String("/api/admin/settings/transcode")) {
        if (method == QLatin1String("PUT"))
            transcodeCrf = QJsonDocument::fromJson(body).object().value("crf").toInt();
        status = 200;
        return json(200, transcodeBody());
    }
    if (method == QLatin1String("GET") && path == QLatin1String("/api/admin/transcodes")) {
        status = 200;
        return json(200, QJsonObject{{"sessions", QJsonArray{QJsonObject{
            {"session", "tx-1"}, {"state", "running"}, {"profile", "720p"}, {"user_id", "user-admin"},
            {"progress", 0.4}, {"method", "transcode"}}}}});
    }
    if (method == QLatin1String("DELETE") && path.startsWith(QLatin1String("/api/admin/transcodes/"))) {
        status = 200;
        return json(200, QJsonObject{{"session", "tx-1"}, {"state", "failed"}, {"profile", "720p"}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/browse")) {
        const QString at = query.queryItemValue("path").isEmpty() ? QStringLiteral("/media")
                                                                    : query.queryItemValue("path");
        QJsonArray dirs;
        if (at == QLatin1String("/media")) {
            dirs.append(QJsonObject{{"name", "Anime"}, {"path", "/media/Anime"}});
            dirs.append(QJsonObject{{"name", "Movies"}, {"path", "/media/Movies"}});
        }
        status = 200;
        return json(200, QJsonObject{{"path", at}, {"parent", at == QLatin1String("/media") ? "/" : "/media"},
                                     {"detected", true}, {"dirs", dirs}});
    }

    if (path.startsWith(QLatin1String("/api/items/")) && path.endsWith(QLatin1String("/pages"))) {
        status = 200;
        return json(200, QJsonObject{{"kind", "manga"}, {"format", "cbz"}, {"direction", "rtl"},
                                     {"pages", QJsonArray{
                                         QJsonObject{{"index", 0}, {"mime", "image/png"}, {"size", 10}, {"width", 800}, {"height", 1200}},
                                         QJsonObject{{"index", 1}, {"mime", "image/png"}, {"size", 10}, {"width", 800}, {"height", 1200}},
                                         QJsonObject{{"index", 2}, {"mime", "image/png"}, {"size", 10}, {"width", 800}, {"height", 1200}}}}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/libraries")) {
        status = 200;
        return json(200, libraries());
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/libraries")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        status = 201;
        return json(201, QJsonObject{{"id", "lib-new"}, {"name", in.value("name").toString()},
                                     {"type", in.value("type").toString()},
                                     {"path", in.value("path").toString()},
                                     {"source", "stub"}, {"created_at", 3}},
                    "Created");
    }

    if (method == QLatin1String("DELETE") && path.startsWith(QLatin1String("/api/libraries/"))) {
        status = 200;
        return json(200, QJsonObject{{"status", "ok"}});
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/library/scan")) {
        status = 202;
        return json(202, QJsonObject{{"state", "running"}}, "Accepted");
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/library/scan")) {
        status = 200;
        return json(200, QJsonObject{{"state", "done"}, {"started_at", 1}, {"finished_at", 2}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/users")) {
        status = 200;
        return json(200, users());
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/users")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        status = 201;
        return json(201, QJsonObject{{"id", "user-new"}, {"username", in.value("username").toString()},
                                     {"role", "user"}, {"disabled", false},
                                     {"pwd_ver", 1}, {"created_at", 3}},
                    "Created");
    }

    if (method == QLatin1String("PATCH") && path.startsWith(QLatin1String("/api/users/"))) {
        status = 200;
        return json(200, QJsonObject{{"id", "user-guest"}, {"username", "guest"},
                                     {"role", "user"}, {"disabled", false},
                                     {"pwd_ver", 1}, {"created_at", 2}});
    }

    if (method == QLatin1String("POST") && path == QLatin1String("/api/plugins/swap")) {
        const QJsonObject in = QJsonDocument::fromJson(body).object();
        const quint64 generation = static_cast<quint64>(in.value("generation").toDouble());
        if (generation != compositionGeneration) {
            status = 409;
            return json(409, QJsonObject{{"error", "stale generation"},
                                         {"code", "stale-generation"},
                                         {"generation", static_cast<qint64>(compositionGeneration)}},
                        "Conflict");
        }
        compositionGeneration++;
        if (in.value("capability").toString() == QLatin1String("lain.metadata.search@1")) {
            metadataOrder.clear();
            for (const QJsonValue &v : in.value("providers").toArray())
                metadataOrder << v.toString();
        }
        status = 200;
        return json(200, QJsonObject{{"generation", static_cast<qint64>(compositionGeneration)},
                                     {"composition", composition(compositionGeneration, metadataOrder)}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/admin/backup")) {
        status = 200;
        return respond(200, QByteArray("test-backup-bytes"), "OK");
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/catalog")) {
        QJsonArray items = allItems();
        if (query.queryItemValue("sort") == QLatin1String("recent")) {
            QList<QJsonObject> objects;
            for (const QJsonValue &value : items)
                objects.append(value.toObject());
            std::sort(objects.begin(), objects.end(), [](const QJsonObject &a, const QJsonObject &b) {
                return a.value("updated_at").toDouble() > b.value("updated_at").toDouble();
            });
            items = QJsonArray();
            for (const QJsonObject &object : objects)
                items.append(object);
        }
        const QString libraryId = query.queryItemValue("library_id");
        if (!libraryId.isEmpty()) {
            QJsonArray filtered;
            for (const QJsonValue &value : items) {
                if (value.toObject().value("library_id").toString() == libraryId)
                    filtered.append(value);
            }
            items = filtered;
        }
        const int requested = query.queryItemValue("limit").isEmpty()
                              ? 50
                              : query.queryItemValue("limit").toInt();
        const int limit = paginateOneByOne ? qMin(requested, 1) : requested;
        const int offset = query.queryItemValue("offset").toInt();
        QJsonArray page;
        for (int i = offset; i < items.size() && page.size() < limit; ++i)
            page.append(items.at(i));
        status = 200;
        return json(200, QJsonObject{{"items", page},
                                     {"total", items.size()},
                                     {"limit", limit},
                                     {"offset", offset}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/plugins")) {
        const QJsonArray metadataCaps{"lain.metadata.search@1", "lain.metadata.resolve@1"};
        status = 200;
        return json(200, QJsonObject{
                             {"composition", composition(compositionGeneration, metadataOrder)},
                             {"providers", QJsonArray{"lain-metadata-anilist", "lain-metadata-nfo"}},
                             {"provider_info", QJsonArray{
                                 QJsonObject{{"id", "lain-metadata-anilist"}, {"capabilities", metadataCaps}, {"healthy", true}},
                                 QJsonObject{{"id", "lain-metadata-nfo"}, {"capabilities", metadataCaps}, {"healthy", true}},
                                 QJsonObject{{"id", "lain-playback-default"}, {"capabilities", QJsonArray{"lain.playback.plan@1"}}, {"healthy", true}},
                             }},
                             {"events", QJsonArray{}},
                         });
    }

    if (path.startsWith(QLatin1String("/api/catalog/")) && path.endsWith(QLatin1String("/enrich"))) {
        const int prefix = int(qstrlen("/api/catalog/"));
        const QString id = path.mid(prefix, path.size() - prefix - int(qstrlen("/enrich")));
        if (findItem(id).isEmpty()) {
            status = 404;
            return json(404, QJsonObject{{"error", "unknown item"}}, "Not Found");
        }
        if (method == QLatin1String("DELETE")) {
            status = 200;
            return json(200, QJsonObject{{"status", "ok"}});
        }
        if (method == QLatin1String("POST")) {
            QJsonObject overlay = enrichmentFor(id);
            const QString provider = query.queryItemValue("provider");
            if (!provider.isEmpty())
                overlay.insert("provider", provider);
            overlay.insert("synopsis", "Refreshed by stub.");
            overlay.insert("fetched_at", 1700000900);
            status = 200;
            return json(200, overlay);
        }
    }

    if (method == QLatin1String("GET") && path.startsWith(QLatin1String("/api/catalog/"))) {
        const QString id = path.mid(int(qstrlen("/api/catalog/")));
        const QJsonObject item = findItem(id);
        if (item.isEmpty()) {
            status = 404;
            return json(404, QJsonObject{{"error", "unknown item"}}, "Not Found");
        }
        status = 200;
        return json(200, item);
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/enrichments")) {
        QJsonArray items;
        for (const QString &id : query.queryItemValue("ids").split(QLatin1Char(','))) {
            if (id == skipEnrichmentFor)
                continue;
            const QJsonObject overlay = enrichmentFor(id);
            if (!overlay.isEmpty())
                items.append(overlay);
        }
        status = 200;
        return json(200, QJsonObject{{"items", items}});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/me/continue")) {
        status = 200;
        return json(200, QJsonArray{progressFor(QStringLiteral("show-1"))});
    }

    if (method == QLatin1String("GET") && path == QLatin1String("/api/search")) {
        const QString q = query.queryItemValue("q").toLower();
        QJsonArray hits;
        for (const QJsonValue &value : allItems()) {
            const QJsonObject item = value.toObject();
            const QJsonObject overlay = enrichmentFor(item.value("id").toString());
            const QString haystack = (item.value("title").toString() + QLatin1Char(' ')
                                      + overlay.value("title").toString())
                                         .toLower();
            if (q.isEmpty() || haystack.contains(q))
                hits.append(item);
        }
        const int limit = query.queryItemValue("limit").isEmpty()
                              ? 50
                              : query.queryItemValue("limit").toInt();
        QJsonArray page;
        for (int i = 0; i < hits.size() && page.size() < limit; ++i)
            page.append(hits.at(i));
        status = 200;
        return json(200, QJsonObject{{"items", page},
                                     {"total", hits.size()},
                                     {"limit", limit},
                                     {"offset", 0}});
    }

    if (method == QLatin1String("DELETE") && path.startsWith(QLatin1String("/api/items/"))
        && path.count(QLatin1Char('/')) == 3) {
        const QString id = path.mid(int(qstrlen("/api/items/")));
        QJsonObject item = findItem(id);
        if (item.isEmpty()) {
            status = 404;
            return json(404, QJsonObject{{"error", "unknown item"}}, "Not Found");
        }
        deletedItems << id;
        item.insert("missing", true);
        status = 200;
        return json(200, item);
    }

    if (path.startsWith(QLatin1String("/api/items/")) && path.endsWith(QLatin1String("/playback"))) {
        const QString id = path.mid(int(qstrlen("/api/items/")),
                                    path.size() - int(qstrlen("/api/items/")) - int(qstrlen("/playback")));
        if (findItem(id).isEmpty()) {
            status = 404;
            return json(404, QJsonObject{{"error", "unknown item"}}, "Not Found");
        }
        status = 200;
        return json(200, QJsonObject{{"mode", "direct"},
                                     {"asset", QStringLiteral("asset:") + id},
                                     {"available", true}});
    }

    if (path.startsWith(QLatin1String("/api/items/")) && path.endsWith(QLatin1String("/progress"))) {
        const QString id = path.mid(int(qstrlen("/api/items/")),
                                    path.size() - int(qstrlen("/api/items/")) - int(qstrlen("/progress")));
        if (method == QLatin1String("PUT")) {
            if (failProgress) {
                status = 500;
                return json(500, QJsonObject{{"error", "injected progress failure"}}, "Server Error");
            }
            QJsonObject in = QJsonDocument::fromJson(body).object();
            in.insert("item_id", id);
            in.insert("user_id", "user-admin");
            in.insert("updated_at", 1700000300);
            progressPuts.append(in);
            status = 200;
            return json(200, in);
        }
        if (method == QLatin1String("GET")) {
            status = 200;
            return json(200, progressFor(id));
        }
    }

    status = 404;
    return json(404, QJsonObject{{"error", "no stub route for " + path}}, "Not Found");
}
