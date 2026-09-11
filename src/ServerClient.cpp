#include "ServerClient.h"

#include <QCryptographicHash>
#include <QFile>
#include <QFileInfo>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSettings>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>
#include <QtMath>

namespace {
const char *kServerKey = "server/url";
const char *kTokenKey = "auth/token";
const char *kUserKey = "auth/username";
const char *kRoleKey = "auth/role";

QString errorFrom(const QJsonDocument &doc, const QString &fallback) {
    if (doc.isObject()) {
        const QString msg = doc.object().value("error").toString();
        if (!msg.isEmpty())
            return msg;
    }
    return fallback;
}

QString encodeId(const QString &id) {
    return QString::fromLatin1(QUrl::toPercentEncoding(id));
}
} // namespace

ServerClient::ServerClient(QObject *parent) : QObject(parent) {
    m_net = new QNetworkAccessManager(this);
    m_searchDebounce = new QTimer(this);
    m_searchDebounce->setSingleShot(true);
    m_searchDebounce->setInterval(180);
    connect(m_searchDebounce, &QTimer::timeout, this, [this] { issueSearch(m_pendingQuery); });
    QSettings settings;
    m_autoResume = settings.value(QStringLiteral("playback/auto_resume"), true).toBool();
    m_autoplayNext = settings.value(QStringLiteral("playback/autoplay_next"), true).toBool();
    m_seriesAutoplay = settings.value(QStringLiteral("playback/series_autoplay")).toMap();
}

// --------------------------------------------------------------- session/state

void ServerClient::start() {
    QSettings settings;
    m_serverUrl = settings.value(kServerKey).toString();
    if (m_serverUrl.isEmpty())
        m_serverUrl = QStringLiteral("http://127.0.0.1:9360");
    m_token = settings.value(kTokenKey).toString();
    m_username = settings.value(kUserKey).toString();
    m_role = settings.value(kRoleKey).toString();
    emit serverUrlChanged();
    emit userChanged();
    checkServer();
}

void ServerClient::setServerUrl(const QString &url) {
    QString u = url.trimmed();
    if (u.isEmpty())
        u = QStringLiteral("http://127.0.0.1:9360");
    if (!u.startsWith(QLatin1String("http://")) && !u.startsWith(QLatin1String("https://")))
        u.prepend(QLatin1String("http://"));
    while (u.endsWith(QLatin1Char('/')))
        u.chop(1);
    if (u == m_serverUrl)
        return;
    m_serverUrl = u;
    QSettings().setValue(kServerKey, u);
    emit serverUrlChanged();
    clearError();
    checkServer();
}

void ServerClient::setState(const QString &state) {
    if (m_state == state)
        return;
    m_state = state;
    emit stateChanged();
}

void ServerClient::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

void ServerClient::setError(const QString &message) {
    if (m_error == message)
        return;
    m_error = message;
    emit errorMessageChanged();
}

void ServerClient::clearError() {
    setError(QString());
}

void ServerClient::setSession(const QString &token, const QString &username, const QString &role) {
    m_token = token;
    m_username = username;
    m_role = role;
    QSettings settings;
    settings.setValue(kTokenKey, m_token);
    settings.setValue(kUserKey, m_username);
    settings.setValue(kRoleKey, m_role);
    emit userChanged();
}

void ServerClient::clearSession() {
    m_token.clear();
    m_username.clear();
    m_role.clear();
    QSettings settings;
    settings.remove(kTokenKey);
    settings.remove(kUserKey);
    settings.remove(kRoleKey);
    emit userChanged();
}

void ServerClient::checkServer() {
    const quint64 gen = ++m_generation;
    requestJson("GET", QStringLiteral("/api/setup/status"), {}, {}, false,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation)
                        return;
                    if (!ok) {
                        setState(QStringLiteral("offline"));
                        setError(err);
                        return;
                    }
                    if (doc.object().value("setup_required").toBool()) {
                        setState(QStringLiteral("setup"));
                        return;
                    }
                    if (m_token.isEmpty()) {
                        setState(QStringLiteral("login"));
                        return;
                    }
                    fetchMe();
                });
}

void ServerClient::fetchMe() {
    requestJson("GET", QStringLiteral("/api/me"), {}, {}, true,
                [this](bool ok, int status, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        if (status != 401) {
                            setState(QStringLiteral("offline"));
                            setError(err);
                        }
                        return;
                    }
                    const QJsonObject user = doc.object();
                    setSession(m_token, user.value("username").toString(), user.value("role").toString());
                    clearError();
                    setState(QStringLiteral("ready"));
                    loadAfterLogin();
                });
}

void ServerClient::login(const QString &username, const QString &password) {
    setBusy(true);
    clearError();
    const QJsonObject body{{"username", username}, {"password", password}};
    requestJson("POST", QStringLiteral("/api/auth/login"), body, {}, false,
                [this, username](bool ok, int status, const QJsonDocument &doc, const QString &err) {
                    setBusy(false);
                    if (!ok) {
                        setError(status == 401 ? tr("Invalid username or password.")
                                               : errorFrom(doc, err));
                        return;
                    }
                    setSession(doc.object().value("token").toString(), username, QString());
                    fetchMe();
                });
}

void ServerClient::setup(const QString &username, const QString &password) {
    setBusy(true);
    clearError();
    const QJsonObject body{{"username", username}, {"password", password}};
    requestJson("POST", QStringLiteral("/api/setup"), body, {}, false,
                [this, username, password](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    setBusy(false);
                    if (!ok) {
                        setError(errorFrom(doc, err));
                        return;
                    }
                    login(username, password);
                });
}

void ServerClient::logout() {
    m_generation++;
    clearSession();
    clearSearch();
    m_raw = QJsonArray();
    m_rawById.clear();
    m_enrichment.clear();
    m_enrichKnown.clear();
    m_progress.clear();
    m_libraryNames.clear();
    m_libraryTypes.clear();
    m_home = QVariantMap();
    m_movies.clear();
    m_shows.clear();
    m_catalog.clear();
    m_collections.clear();
    m_libraries.clear();
    m_currentMedia = QVariantMap();
    m_playbackError.clear();
    m_metadataProviders.clear();
    m_enrichStatus = QStringLiteral("idle");
    emit homeChanged();
    emit catalogChanged();
    emit collectionsChanged();
    emit librariesChanged();
    emit metadataProvidersChanged();
    emit enrichStatusChanged();
    emit currentMediaChanged();
    emit playbackErrorChanged();
    clearError();
    setState(QStringLiteral("login"));
}

void ServerClient::retry() {
    clearError();
    checkServer();
}

void ServerClient::refresh() {
    if (!ready()) {
        checkServer();
        return;
    }
    loadLibraries();
    loadHome();
}

// -------------------------------------------------------------------- requests

QUrl ServerClient::apiUrl(const QString &path, const QUrlQuery &query) const {
    QString base = m_serverUrl;
    while (base.endsWith(QLatin1Char('/')))
        base.chop(1);
    QUrl url(base + path);
    if (!query.isEmpty())
        url.setQuery(query);
    return url;
}

QString ServerClient::streamUrlFor(const QString &id) const {
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("token"), m_token);
    return apiUrl(QStringLiteral("/api/items/%1/stream").arg(encodeId(id)), query).toString();
}

void ServerClient::requestJson(const QString &method, const QString &path, const QJsonObject &body,
                               const QUrlQuery &query, bool auth, JsonCallback cb) {
    QNetworkRequest request(apiUrl(path, query));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(20000);
    if (auth && !m_token.isEmpty())
        request.setRawHeader("Authorization", "Bearer " + m_token.toUtf8());

    const QByteArray payload = body.isEmpty() ? QByteArray()
                                              : QJsonDocument(body).toJson(QJsonDocument::Compact);
    QNetworkReply *reply = nullptr;
    if (method == QLatin1String("POST"))
        reply = m_net->post(request, payload);
    else if (method == QLatin1String("PUT"))
        reply = m_net->put(request, payload);
    else if (method == QLatin1String("PATCH"))
        reply = m_net->sendCustomRequest(request, "PATCH", payload);
    else if (method == QLatin1String("DELETE"))
        reply = m_net->deleteResource(request);
    else
        reply = m_net->get(request);

    connect(reply, &QNetworkReply::finished, this, [this, reply, auth, cb] {
        reply->deleteLater();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray data = reply->readAll();
        const bool networkError = reply->error() != QNetworkReply::NoError;
        QJsonDocument doc;
        if (!data.isEmpty())
            doc = QJsonDocument::fromJson(data);

        if (status == 401 && auth) {
            clearSession();
            setState(QStringLiteral("login"));
            setError(tr("Session expired. Sign in again."));
            if (cb)
                cb(false, status, doc, QStringLiteral("unauthorized"));
            return;
        }

        if (networkError || status >= 400) {
            const QString fallback = networkError && !reply->errorString().isEmpty()
                                         ? reply->errorString()
                                         : tr("Request failed (%1)").arg(status);
            if (cb)
                cb(false, status, doc, errorFrom(doc, fallback));
            return;
        }
        if (cb)
            cb(true, status, doc, QString());
    });
}

// --------------------------------------------------------------------- catalog

void ServerClient::loadAfterLogin() {
    m_users.clear();
    m_pluginInfo.clear();
    m_composition.clear();
    emit usersChanged();
    emit pluginsChanged();
    loadLibraries();
    loadHome();
    loadPlugins();
    loadUsers();
    refreshScanStatus();
}

void ServerClient::loadPlugins() {
    // Operator-only surface: a 403 is expected for regular users.
    requestJson("GET", QStringLiteral("/api/plugins"), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (!ok)
                        return;
                    const QJsonObject root = doc.object();
                    QVariantList providers;
                    QVariantList infos;
                    const QJsonArray arr = root.value("provider_info").toArray();
                    for (const QJsonValue &v : arr) {
                        const QJsonObject info = v.toObject();
                        infos << info.toVariantMap();
                        bool servesMetadata = false;
                        const QJsonArray caps = info.value("capabilities").toArray();
                        for (const QJsonValue &c : caps) {
                            if (c.toString() == QLatin1String("lain.metadata.search@1"))
                                servesMetadata = true;
                        }
                        if (!servesMetadata)
                            continue;
                        const QString provider = info.value("id").toString();
                        providers << QVariantMap{{"id", provider},
                                                 {"name", providerLabel(provider)},
                                                 {"healthy", info.value("healthy").toBool()}};
                    }
                    m_metadataProviders = providers;
                    m_pluginInfo = infos;
                    m_composition = root.value("composition").toObject().toVariantMap();
                    emit metadataProvidersChanged();
                    emit pluginsChanged();
                });
}

void ServerClient::setAdminStatus(const QString &status) {
    if (m_adminStatus == status)
        return;
    m_adminStatus = status;
    emit adminChanged();
}

void ServerClient::loadLibraries() {
    const quint64 gen = m_generation;
    requestJson("GET", QStringLiteral("/api/libraries"), {}, {}, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (gen != m_generation || !ok)
                        return;
                    const QJsonArray arr = doc.array();
                    m_libraryNames.clear();
                    m_libraryTypes.clear();
                    for (const QJsonValue &v : arr) {
                        const QJsonObject lib = v.toObject();
                        const QString id = lib.value("id").toString();
                        m_libraryNames.insert(id, lib.value("name").toString());
                        m_libraryTypes.insert(id, lib.value("type").toString());
                    }
                    m_libraries = arr.toVariantList();
                    emit librariesChanged();
                    loadCatalog();
                });
}

void ServerClient::loadCatalog() {
    loadCatalogPage(0, {});
}

void ServerClient::loadCatalogPage(int offset, const QJsonArray &accumulated) {
    const quint64 gen = m_generation;
    static const int kPageLimit = 500;
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("limit"), QString::number(kPageLimit));
    query.addQueryItem(QStringLiteral("sort"), QStringLiteral("title"));
    if (offset > 0)
        query.addQueryItem(QStringLiteral("offset"), QString::number(offset));
    requestJson("GET", QStringLiteral("/api/catalog"), {}, query, true,
                [this, gen, accumulated](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (gen != m_generation || !ok)
                        return;
                    QJsonArray next = accumulated;
                    const QJsonArray page = doc.object().value("items").toArray();
                    for (const QJsonValue &v : page)
                        next.append(v);
                    const int total = doc.object().value("total").toInt(-1);
                    const bool lastPage = page.size() < kPageLimit;
                    const bool reachedTotal = total >= 0 && next.size() >= total;
                    const bool done = total >= 0 ? reachedTotal : lastPage;
                    if (!done) {
                        loadCatalogPage(next.size(), next);
                        return;
                    }
                    m_raw = next;
                    m_rawById.clear();
                    QStringList ids;
                    for (const QJsonValue &v : m_raw) {
                        const QJsonObject item = v.toObject();
                        const QString id = item.value("id").toString();
                        m_rawById.insert(id, item);
                        ids << id;
                    }
                    loadEnrichments(ids, [this, gen] {
                        if (gen == m_generation)
                            rebuildCatalog();
                    });
                });
}

void ServerClient::rebuildCatalog() {
    QVariantList all, movies, shows;
    for (const QJsonValue &v : m_raw) {
        const QJsonObject item = v.toObject();
        const QVariantMap card = normalize(item);
        all << card;
        const QString type = m_libraryTypes.value(item.value("library_id").toString()).toLower();
        const bool isShow = type.contains(QLatin1String("show")) || type.contains(QLatin1String("serie"))
                            || type.contains(QLatin1String("anime")) || type.contains(QLatin1String("tv"));
        if (isShow)
            shows << card;
        else
            movies << card;
    }
    m_catalog = all;
    m_movies = movies;
    m_shows = shows;
    buildSeries();
    emit catalogChanged();
    rebuildCollections();
}

QString ServerClient::seriesTitleFor(const QVariantMap &card) {
    const QString display = card.value("displayTitle").toString().trimmed();
    return display.isEmpty() ? card.value("title").toString().trimmed() : display;
}

QString ServerClient::seriesKey(const QString &libraryId, const QString &seriesTitle) {
    const QByteArray hash = QCryptographicHash::hash(
        (libraryId + QLatin1String("\x00") + seriesTitle).toUtf8(), QCryptographicHash::Sha1);
    return QStringLiteral("series:") + QString::fromLatin1(hash.toHex().left(16));
}

// Series hierarchy (DD-030): episodes group by library plus series title.
// Season and episode numbers come from the identifier; season <= 0 or
// episode <= 0 lands in Specials so strict numbering never misfiles extras.
void ServerClient::buildSeries() {
    QHash<QString, QVariantList> bySeries;
    QHash<QString, QVariantMap> meta;
    QStringList order;
    for (const QVariant &v : m_shows) {
        const QVariantMap card = v.toMap();
        const QString title = seriesTitleFor(card);
        if (title.isEmpty())
            continue;
        const QString lib = card.value("library_id").toString();
        const QString key = seriesKey(lib, title);
        if (!bySeries.contains(key)) {
            bySeries.insert(key, {});
            order << key;
            meta.insert(key, QVariantMap{{"id", key},
                                         {"title", title},
                                         {"library_id", lib},
                                         {"library", card.value("library").toString()},
                                         {"poster", card.value("poster").toString()},
                                         {"cover", card.value("cover").toString()},
                                         {"year", card.value("year").toInt()},
                                         {"accent", card.value("accent").toString()}});
        }
        QVariantList episodes = bySeries.value(key);
        // Keep the first enriched artwork/year found for the series row.
        QVariantMap info = meta.value(key);
        if (info.value("poster").toString().isEmpty() && !card.value("poster").toString().isEmpty()) {
            info["poster"] = card.value("poster");
            info["cover"] = card.value("cover");
            meta[key] = info;
        }
        episodes << card;
        bySeries[key] = episodes;
    }
    std::sort(order.begin(), order.end(), [&meta](const QString &a, const QString &b) {
        return meta.value(a).value("title").toString().localeAwareCompare(
                   meta.value(b).value("title").toString())
               < 0;
    });
    QVariantList series;
    for (const QString &key : order) {
        QVariantList cards = bySeries.value(key);
        std::sort(cards.begin(), cards.end(), [](const QVariant &a, const QVariant &b) {
            const QVariantMap ca = a.toMap(), cb = b.toMap();
            if (ca.value("season").toInt() != cb.value("season").toInt())
                return ca.value("season").toInt() < cb.value("season").toInt();
            if (ca.value("episode").toInt() != cb.value("episode").toInt())
                return ca.value("episode").toInt() < cb.value("episode").toInt();
            return ca.value("displayTitle").toString().localeAwareCompare(
                       cb.value("displayTitle").toString())
                   < 0;
        });
        QHash<int, QVariantList> seasons;
        QList<int> seasonOrder;
        QVariantList specials;
        for (const QVariant &v : cards) {
            const QVariantMap card = v.toMap();
            const int season = card.value("season").toInt();
            const int episode = card.value("episode").toInt();
            if (season > 0 && episode > 0) {
                if (!seasons.contains(season))
                    seasonOrder << season;
                seasons[season] << card;
            } else {
                specials << card;
            }
        }
        std::sort(seasonOrder.begin(), seasonOrder.end());
        QVariantList seasonRows;
        int mainCount = 0;
        for (int s : seasonOrder) {
            mainCount += seasons.value(s).size();
            seasonRows << QVariantMap{{"season", s}, {"episodes", seasons.value(s)}};
        }
        QVariantMap info = meta.value(key);
        info["seasons"] = seasonRows;
        info["specials"] = specials;
        info["episodeCount"] = mainCount;
        info["seasonCount"] = seasonOrder.size();
        info["specialsCount"] = specials.size();
        series << info;
    }
    m_series = series;
}

QString ServerClient::seriesIdFor(const QString &id) const {
    if (id.isEmpty())
        return {};
    for (const QVariant &v : m_catalog) {
        const QVariantMap card = v.toMap();
        if (card.value("id").toString() == id)
            return seriesKey(card.value("library_id").toString(), seriesTitleFor(card));
    }
    return {};
}

QString ServerClient::seriesAutoplayMode(const QString &seriesId) const {
    const QString mode = m_seriesAutoplay.value(seriesId).toString();
    if (mode == QLatin1String("on") || mode == QLatin1String("off"))
        return mode;
    return QStringLiteral("default");
}

void ServerClient::setSeriesAutoplay(const QString &seriesId, const QString &mode) {
    if (seriesId.isEmpty())
        return;
    const QString v = mode.trimmed().toLower();
    const QString normalized = (v == QLatin1String("on") || v == QLatin1String("off"))
                                   ? v
                                   : QStringLiteral("default");
    if (normalized == QLatin1String("default"))
        m_seriesAutoplay.remove(seriesId);
    else
        m_seriesAutoplay.insert(seriesId, normalized);
    QSettings().setValue(QStringLiteral("playback/series_autoplay"), m_seriesAutoplay);
    emit playbackSettingsChanged();
}

QString ServerClient::nextEpisodeId(const QString &id) const {
    if (id.isEmpty() || !m_autoplayNext)
        return {};
    const QString seriesId = seriesIdFor(id);
    if (!seriesId.isEmpty() && seriesAutoplayMode(seriesId) == QLatin1String("off"))
        return {};
    for (const QVariant &s : m_series) {
        const QVariantMap info = s.toMap();
        if (info.value("id").toString() != seriesId)
            continue;
        const QVariantList seasons = info.value("seasons").toList();
        for (int i = 0; i < seasons.size(); ++i) {
            const QVariantList episodes = seasons.at(i).toMap().value("episodes").toList();
            for (int j = 0; j < episodes.size(); ++j) {
                if (episodes.at(j).toMap().value("id").toString() != id)
                    continue;
                if (j + 1 < episodes.size())
                    return episodes.at(j + 1).toMap().value("id").toString();
                if (i + 1 < seasons.size()) {
                    const QVariantList next = seasons.at(i + 1).toMap().value("episodes").toList();
                    if (!next.isEmpty())
                        return next.first().toMap().value("id").toString();
                }
                return {};
            }
        }
    }
    return {};
}

void ServerClient::setAutoResume(bool resume) {
    if (m_autoResume == resume)
        return;
    m_autoResume = resume;
    QSettings().setValue(QStringLiteral("playback/auto_resume"), resume);
    emit playbackSettingsChanged();
}

void ServerClient::setAutoplayNext(bool next) {
    if (m_autoplayNext == next)
        return;
    m_autoplayNext = next;
    QSettings().setValue(QStringLiteral("playback/autoplay_next"), next);
    emit playbackSettingsChanged();
}

void ServerClient::rebuildCollections() {
    QHash<QString, QVariantList> byGenre;
    QStringList order;
    for (const QVariant &v : m_catalog) {
        const QVariantMap card = v.toMap();
        const QString genre = card.value("genre").toString().trimmed();
        if (genre.isEmpty())
            continue;
        if (!byGenre.contains(genre)) {
            byGenre.insert(genre, {});
            order << genre;
        }
        QVariantList &row = byGenre[genre];
        if (row.size() < 30)
            row << card;
    }
    std::sort(order.begin(), order.end(), [&byGenre](const QString &a, const QString &b) {
        const int bySize = byGenre.value(b).size() - byGenre.value(a).size();
        return bySize != 0 ? bySize < 0 : a.localeAwareCompare(b) < 0;
    });
    QVariantList collections;
    for (const QString &genre : order) {
        collections << QVariantMap{{"id", QStringLiteral("genre:") + genre},
                                   {"title", genre},
                                   {"subtitle", tr("Genre")},
                                   {"items", byGenre.value(genre)}};
    }
    m_collections = collections;
    emit collectionsChanged();
}

void ServerClient::loadEnrichments(const QStringList &ids, std::function<void()> done) {
    QStringList missing;
    missing.reserve(ids.size());
    for (const QString &id : ids) {
        if (!id.isEmpty() && !m_enrichKnown.contains(id) && !missing.contains(id))
            missing << id;
    }
    if (missing.isEmpty()) {
        if (done)
            done();
        return;
    }
    loadEnrichChunks(missing, 0, std::move(done));
}

void ServerClient::loadEnrichChunks(const QStringList &ids, int offset, std::function<void()> done) {
    if (offset >= ids.size()) {
        if (done)
            done();
        return;
    }
    const int end = qMin(offset + 150, ids.size());
    const QStringList chunk = ids.mid(offset, end - offset);
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("ids"), chunk.join(QLatin1Char(',')));
    requestJson("GET", QStringLiteral("/api/enrichments"), {}, query, true,
                [this, ids, chunk, end, done](bool ok, int, const QJsonDocument &doc, const QString &) {
                    for (const QString &id : chunk)
                        m_enrichKnown.insert(id);
                    if (ok) {
                        const QJsonArray arr = doc.object().value("items").toArray();
                        for (const QJsonValue &v : arr) {
                            const QJsonObject overlay = v.toObject();
                            m_enrichment.insert(overlay.value("item_id").toString(), overlay.toVariantMap());
                        }
                    }
                    loadEnrichChunks(ids, end, done);
                });
}

// ------------------------------------------------------------------------ home

void ServerClient::loadHome() {
    const quint64 gen = m_generation;
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("limit"), QStringLiteral("24"));
    query.addQueryItem(QStringLiteral("sort"), QStringLiteral("recent"));
    requestJson("GET", QStringLiteral("/api/catalog"), {}, query, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (gen != m_generation)
                        return;
                    const QJsonArray recent = ok ? doc.object().value("items").toArray() : QJsonArray();
                    requestJson("GET", QStringLiteral("/api/me/continue"), {}, {}, true,
                                [this, gen, recent](bool ok2, int, const QJsonDocument &doc2, const QString &) {
                                    if (gen != m_generation)
                                        return;
                                    const QJsonArray cont = ok2 ? doc2.array() : QJsonArray();
                                    for (const QJsonValue &v : cont) {
                                        const QJsonObject p = v.toObject();
                                        m_progress.insert(p.value("item_id").toString(), p.toVariantMap());
                                    }
                                    for (const QJsonValue &v : recent) {
                                        const QJsonObject item = v.toObject();
                                        m_rawById.insert(item.value("id").toString(), item);
                                    }
                                    QStringList ids;
                                    for (const QJsonValue &v : recent)
                                        ids << v.toObject().value("id").toString();
                                    for (const QJsonValue &v : cont)
                                        ids << v.toObject().value("item_id").toString();
                                    loadEnrichments(ids, [this, gen, recent, cont] {
                                        if (gen == m_generation)
                                            buildHome(recent, cont);
                                    });
                                });
                });
}

void ServerClient::buildHome(const QJsonArray &recent, const QJsonArray &cont) {
    QVariantList recentCards, contCards;
    for (const QJsonValue &v : recent)
        recentCards << normalize(v.toObject());
    for (const QJsonValue &v : cont) {
        const QString id = v.toObject().value("item_id").toString();
        const QJsonObject item = m_rawById.value(id);
        if (!item.isEmpty())
            contCards << normalize(item);
    }
    QVariantMap hero;
    if (!contCards.isEmpty())
        hero = contCards.first().toMap();
    else if (!recentCards.isEmpty())
        hero = recentCards.first().toMap();
    m_home = QVariantMap{{"hero", hero},
                         {"continueWatching", contCards},
                         {"recentlyAdded", recentCards}};
    emit homeChanged();
}

// --------------------------------------------------------------- detail/playback

QJsonObject ServerClient::rawItem(const QString &id) const {
    return m_rawById.value(id);
}

void ServerClient::openMedia(const QString &id) {
    if (id.isEmpty())
        return;
    m_loadingItem = true;
    m_playbackError.clear();
    emit playbackErrorChanged();

    const QJsonObject cached = rawItem(id);
    if (!cached.isEmpty()) {
        m_currentMedia = normalize(cached);
        emit currentMediaChanged();
    }

    const quint64 gen = m_generation;
    auto finish = [this, id, gen](const QJsonObject &item) {
        if (gen != m_generation)
            return;
        QVariantMap detail = normalize(item);

        const QString genre = detail.value("genre").toString();
        const QString library = item.value("library_id").toString();
        QVariantList related;
        for (const QJsonValue &v : m_raw) {
            const QJsonObject other = v.toObject();
            if (other.value("id").toString() == id)
                continue;
            const QVariantMap card = normalize(other);
            const bool sameGenre = !genre.isEmpty() && card.value("genre").toString() == genre;
            const bool sameLibrary = genre.isEmpty() && card.value("library_id").toString() == library;
            if (sameGenre || sameLibrary)
                related << card;
            if (related.size() >= 12)
                break;
        }
        if (related.isEmpty()) {
            for (const QVariant &v : m_catalog) {
                const QVariantMap card = v.toMap();
                if (card.value("id").toString() == id)
                    continue;
                related << card;
                if (related.size() >= 12)
                    break;
            }
        }

        detail["related"] = related;
        detail["cast"] = QVariantList();
        detail["extras"] = QVariantList();
        m_currentMedia = detail;
        m_loadingItem = false;
        emit currentMediaChanged();
    };

    if (!cached.isEmpty()) {
        loadEnrichments({id}, [this, id, gen, finish] {
            if (gen == m_generation)
                finish(rawItem(id));
        });
        return;
    }

    requestJson("GET", QStringLiteral("/api/catalog/%1").arg(encodeId(id)), {}, {}, true,
                [this, id, gen, finish](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation)
                        return;
                    if (!ok) {
                        m_loadingItem = false;
                        emit currentMediaChanged();
                        setError(err);
                        return;
                    }
                    const QJsonObject item = doc.object();
                    m_rawById.insert(id, item);
                    loadEnrichments({id}, [this, id, gen, finish] {
                        if (gen == m_generation)
                            finish(rawItem(id));
                    });
                });
}

void ServerClient::requestPlayback(const QString &id) {
    if (id.isEmpty() || !ready())
        return;
    m_playbackError.clear();
    emit playbackErrorChanged();

    const quint64 gen = m_generation;
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("client"), QStringLiteral("desktop"));
    requestJson("GET", QStringLiteral("/api/items/%1/playback").arg(encodeId(id)), {}, query, true,
                [this, id, gen](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation)
                        return;
                    if (!ok) {
                        m_playbackError = err;
                        emit playbackErrorChanged();
                        emit playbackFailed(err);
                        return;
                    }
                    const QJsonObject plan = doc.object();
                    if (!plan.value("available").toBool()
                        || plan.value("mode").toString() != QLatin1String("direct")) {
                        const QString reason = plan.value("reason").toString();
                        m_playbackError = reason.isEmpty()
                                              ? tr("Item is not available for direct playback.")
                                              : reason;
                        emit playbackErrorChanged();
                        emit playbackFailed(m_playbackError);
                        return;
                    }
                    requestJson("GET", QStringLiteral("/api/items/%1/progress").arg(encodeId(id)),
                                {}, {}, true,
                                [this, id, gen](bool ok2, int, const QJsonDocument &doc2, const QString &) {
                                    if (gen != m_generation)
                                        return;
                                    double position = 0.0;
                                    double duration = 0.0;
                                    if (ok2) {
                                        const QJsonObject progress = doc2.object();
                                        position = progress.value("position_sec").toDouble();
                                        duration = progress.value("duration_sec").toDouble();
                                        m_progress.insert(id, progress.toVariantMap());
                                    }
                                    emit playbackReady(streamUrlFor(id), position, duration);
                                });
                });
}

void ServerClient::reportProgress(const QString &id, double position, double duration, bool completed) {
    if (!ready() || id.isEmpty())
        return;
    const QJsonObject body{{"position_sec", qMax(0.0, position)},
                           {"duration_sec", qMax(0.0, duration)},
                           {"completed", completed}};
    requestJson("PUT", QStringLiteral("/api/items/%1/progress").arg(encodeId(id)), body, {}, true,
                [this, id](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (ok)
                        m_progress.insert(id, doc.object().toVariantMap());
                });
}

// ------------------------------------------------------------------ thumbnail/enrich

QString ServerClient::thumbnailUrlFor(const QString &id, double at, int width) const {
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("t"), QString::number(at, 'f', 1));
    query.addQueryItem(QStringLiteral("w"), QString::number(width));
    if (!m_token.isEmpty())
        query.addQueryItem(QStringLiteral("token"), m_token);
    return apiUrl(QStringLiteral("/api/items/%1/thumbnail").arg(encodeId(id)), query).toString();
}

QString ServerClient::thumbnailUrl(const QString &id, double at, int width) const {
    if (id.isEmpty())
        return {};
    return thumbnailUrlFor(id, at > 0 ? at : 10.0, width > 0 ? width : 480);
}

void ServerClient::enrichItem(const QString &id, const QString &provider) {
    if (!ready() || id.isEmpty())
        return;
    m_enrichStatus = QStringLiteral("running");
    emit enrichStatusChanged();
    QUrlQuery query;
    if (!provider.isEmpty())
        query.addQueryItem(QStringLiteral("provider"), provider);
    requestJson("POST", QStringLiteral("/api/catalog/%1/enrich").arg(encodeId(id)), {}, query, true,
                [this, id](bool ok, int status, const QJsonDocument &doc, const QString &err) {
                    m_enrichStatus = QStringLiteral("idle");
                    emit enrichStatusChanged();
                    if (!ok) {
                        setError(status == 403 ? tr("Only administrators can enrich metadata.")
                                               : err);
                        return;
                    }
                    applyEnrichment(id, doc.object());
                });
}

void ServerClient::removeEnrichment(const QString &id) {
    if (!ready() || id.isEmpty())
        return;
    m_enrichStatus = QStringLiteral("running");
    emit enrichStatusChanged();
    requestJson("DELETE", QStringLiteral("/api/catalog/%1/enrich").arg(encodeId(id)), {}, {}, true,
                [this, id](bool ok, int status, const QJsonDocument &, const QString &err) {
                    m_enrichStatus = QStringLiteral("idle");
                    emit enrichStatusChanged();
                    if (!ok) {
                        setError(status == 403 ? tr("Only administrators can remove metadata.")
                                               : err);
                        return;
                    }
                    m_enrichment.remove(id);
                    m_enrichKnown.insert(id);
                    rebuildItemViews(id);
                });
}

void ServerClient::applyEnrichment(const QString &id, const QJsonObject &overlay) {
    m_enrichment.insert(id, overlay.toVariantMap());
    m_enrichKnown.insert(id);
    rebuildItemViews(id);
}

// Re-normalize cards and detail after an overlay change. The newly fetched
// enrichment is already cached, so no extra fetch is required.
void ServerClient::rebuildItemViews(const QString &id) {
    rebuildCatalog();
    if (!m_currentMedia.isEmpty() && m_currentMedia.value("id").toString() == id)
        openMedia(id);
    else if (!m_home.isEmpty())
        loadHome();
}

// ------------------------------------------------------- administration (admin)

// User and library mutations report through adminStatus; failures also land
// in errorMessage so offline/timeout states stay visible in one place.
void ServerClient::loadUsers() {
    if (!ready())
        return;
    const quint64 gen = m_generation;
    requestJson("GET", QStringLiteral("/api/users"), {}, {}, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (gen != m_generation || !ok)
                        return;
                    m_users = doc.array().toVariantList();
                    emit usersChanged();
                });
}

void ServerClient::createUser(const QString &username, const QString &password, const QString &role) {
    if (!ready())
        return;
    QJsonObject body{{"username", username}, {"password", password}, {"role", role}};
    requestJson("POST", QStringLiteral("/api/users"), body, {}, true,
                [this, username](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("User %1 created.").arg(username));
                    loadUsers();
                });
}

void ServerClient::setUserDisabled(const QString &id, bool disabled) {
    if (!ready() || id.isEmpty())
        return;
    QJsonObject body{{"disabled", disabled}};
    requestJson("PATCH", QStringLiteral("/api/users/%1").arg(encodeId(id)), body, {}, true,
                [this, id, disabled](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(disabled ? tr("User disabled.") : tr("User enabled."));
                    Q_UNUSED(id);
                    loadUsers();
                });
}

void ServerClient::setUserRole(const QString &id, const QString &role) {
    if (!ready() || id.isEmpty())
        return;
    QJsonObject body{{"role", role}};
    requestJson("PATCH", QStringLiteral("/api/users/%1").arg(encodeId(id)), body, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("User role updated."));
                    loadUsers();
                });
}

void ServerClient::resetUserPassword(const QString &id, const QString &password) {
    if (!ready() || id.isEmpty())
        return;
    QJsonObject body{{"password", password}};
    requestJson("PATCH", QStringLiteral("/api/users/%1").arg(encodeId(id)), body, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("Password reset."));
                });
}

void ServerClient::createLibrary(const QString &name, const QString &type, const QString &path) {
    if (!ready())
        return;
    QJsonObject body{{"name", name}, {"type", type}, {"path", path}};
    requestJson("POST", QStringLiteral("/api/libraries"), body, {}, true,
                [this, name](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("Library %1 created.").arg(name));
                    loadLibraries();
                });
}

void ServerClient::deleteLibrary(const QString &id) {
    if (!ready() || id.isEmpty())
        return;
    requestJson("DELETE", QStringLiteral("/api/libraries/%1").arg(encodeId(id)), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("Library deleted."));
                    loadLibraries();
                });
}

void ServerClient::triggerScan() {
    if (!ready())
        return;
    const quint64 gen = m_generation;
    requestJson("POST", QStringLiteral("/api/library/scan"), {}, {}, true,
                [this, gen](bool ok, int status, const QJsonDocument &, const QString &err) {
                    if (!ok && status != 409) {
                        setError(err);
                        return;
                    }
                    setAdminStatus(tr("Scan running…"));
                    QTimer::singleShot(2000, this, [this, gen] {
                        if (gen == m_generation)
                            refreshScanStatus();
                    });
                });
}

void ServerClient::refreshScanStatus() {
    if (!ready())
        return;
    const quint64 gen = m_generation;
    requestJson("GET", QStringLiteral("/api/library/scan"), {}, {}, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (gen != m_generation || !ok)
                        return;
                    m_scan = doc.object().toVariantMap();
                    emit scanChanged();
                    const QString state = m_scan.value("state").toString();
                    if (state == QLatin1String("running")) {
                        setAdminStatus(tr("Scan running…"));
                        QTimer::singleShot(2000, this, [this, gen] {
                            if (gen == m_generation)
                                refreshScanStatus();
                        });
                    } else if (state == QLatin1String("done")) {
                        setAdminStatus(tr("Scan finished."));
                        loadLibraries();
                        loadHome();
                    } else if (state == QLatin1String("error")) {
                        setAdminStatus(tr("Scan failed: %1").arg(m_scan.value("error").toString()));
                    }
                });
}

void ServerClient::downloadBackup(const QString &filePath) {
    if (!ready() || filePath.isEmpty() || m_token.isEmpty())
        return;
    QUrl url = apiUrl(QStringLiteral("/api/admin/backup"));
    QNetworkRequest req(url);
    req.setRawHeader("Authorization", ("Bearer " + m_token).toUtf8());
    QNetworkReply *reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, filePath] {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            setError(tr("Backup failed."));
            return;
        }
        QFile out(filePath);
        if (!out.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            setError(tr("Could not write backup file."));
            return;
        }
        out.write(reply->readAll());
        setAdminStatus(tr("Backup saved to %1.").arg(filePath));
    });
}

// ---------------------------------------------------------------------- search

void ServerClient::search(const QString &query) {
    const QString trimmed = query.trimmed();
    if (trimmed == m_pendingQuery)
        return;
    m_pendingQuery = trimmed;
    if (trimmed.isEmpty()) {
        m_searchDebounce->stop();
        m_searching = false;
        m_searchRaw = QJsonArray();
        m_search.clear();
        emit searchChanged();
        return;
    }
    m_searching = true;
    emit searchChanged();
    m_searchDebounce->start();
}

void ServerClient::clearSearch() {
    m_searchDebounce->stop();
    m_pendingQuery.clear();
    m_activeQuery.clear();
    m_searchRaw = QJsonArray();
    m_search.clear();
    if (m_searching) {
        m_searching = false;
        emit searchChanged();
    } else {
        emit searchChanged();
    }
}

void ServerClient::issueSearch(const QString &query) {
    if (query.isEmpty() || !ready())
        return;
    m_activeQuery = query;
    const quint64 gen = m_generation;
    QUrlQuery params;
    params.addQueryItem(QStringLiteral("q"), query);
    params.addQueryItem(QStringLiteral("limit"), QStringLiteral("60"));
    requestJson("GET", QStringLiteral("/api/search"), {}, params, true,
                [this, query, gen](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation || m_activeQuery != query)
                        return;
                    m_searching = false;
                    if (!ok) {
                        m_searchRaw = QJsonArray();
                        m_search.clear();
                        setError(err);
                        emit searchChanged();
                        return;
                    }
                    m_searchRaw = doc.object().value("items").toArray();
                    m_search = normalizeAll(m_searchRaw);
                    emit searchChanged();

                    QStringList ids;
                    for (const QJsonValue &v : m_searchRaw)
                        ids << v.toObject().value("id").toString();
                    loadEnrichments(ids, [this, query, gen] {
                        if (gen != m_generation || m_activeQuery != query)
                            return;
                        m_search = normalizeAll(m_searchRaw);
                        emit searchChanged();
                    });
                });
}

// --------------------------------------------------------------- normalization

QVariantMap ServerClient::normalize(const QJsonObject &item) const {
    const QString id = item.value("id").toString();
    const QVariantMap enrichment = m_enrichment.value(id);
    const QVariantMap progress = m_progress.value(id);

    const QString catalogTitle = item.value("title").toString();
    const QString enrichedTitle = enrichment.value("title").toString();
    const QString displayTitle = enrichedTitle.isEmpty() ? catalogTitle : enrichedTitle;

    int year = enrichment.value("year").toInt();
    if (year <= 0)
        year = item.value("year").toInt();

    const QStringList genres = enrichment.value("genres").toStringList();
    const QString synopsis = enrichment.value("synopsis").toString();

    const double position = progress.value("position_sec").toDouble();
    const double duration = progress.value("duration_sec").toDouble();
    const bool completed = progress.value("completed").toBool();
    const double fraction = (!completed && duration > 0.0) ? qBound(0.0, position / duration, 1.0) : 0.0;

    const QString path = item.value("file_path").toString();
    const QString libraryId = item.value("library_id").toString();
    const qint64 size = static_cast<qint64>(item.value("size").toDouble());

    QVariantMap tech;
    const QString container = fileExtension(path).toUpper();
    if (!container.isEmpty())
        tech.insert(QStringLiteral("container"), container);
    if (size > 0)
        tech.insert(QStringLiteral("size"), humanSize(size));
    const QString library = m_libraryNames.value(libraryId);
    if (!library.isEmpty())
        tech.insert(QStringLiteral("library"), library);
    const QString origin = item.value("origin").toString();
    if (!origin.isEmpty())
        tech.insert(QStringLiteral("identifier"), origin);

    return QVariantMap{
        {"id", id},
        {"title", catalogTitle},
        {"displayTitle", displayTitle},
        {"indexedTitle", enrichedTitle.isEmpty() || enrichedTitle == catalogTitle ? QString()
                                                                                  : catalogTitle},
        {"year", year},
        {"kind", item.value("kind").toString()},
        {"season", item.value("season").toInt()},
        {"episode", item.value("episode").toInt()},
        {"library_id", libraryId},
        {"library", library},
        {"genre", genres.isEmpty() ? QString() : genres.first()},
        {"genres", joinGenres(genres)},
        {"overview", synopsis},
        {"poster", enrichment.value("poster").toString()},
        {"cover", enrichment.value("cover").toString()},
        {"thumb", m_token.isEmpty() ? QString() : thumbnailUrlFor(id, 10.0, 480)},
        {"enriched", !enrichment.isEmpty()},
        {"enrichProvider", enrichment.value("provider").toString()},
        {"enrichProviderLabel", providerLabel(enrichment.value("provider").toString())},
        {"enrichFetchedAt", enrichment.value("fetched_at").toDouble()},
        {"runtime", duration > 0.0 ? humanDuration(duration) : QString()},
        {"rating", 0.0},
        {"progress", fraction},
        {"position_sec", position},
        {"duration_sec", duration},
        {"completed", completed},
        {"accent", accentFor(id + catalogTitle)},
        {"size", static_cast<double>(size)},
        {"size_human", size > 0 ? humanSize(size) : QString()},
        {"file_name", QFileInfo(path).fileName()},
        {"tech", tech},
    };
}

QVariantList ServerClient::normalizeAll(const QJsonArray &items) const {
    QVariantList list;
    list.reserve(items.size());
    for (const QJsonValue &v : items)
        list << normalize(v.toObject());
    return list;
}

// ------------------------------------------------------------------- helpers

QString ServerClient::humanSize(qint64 bytes) {
    static const char *units[] = {"B", "KB", "MB", "GB", "TB"};
    double value = static_cast<double>(bytes);
    int unit = 0;
    while (value >= 1024.0 && unit < 4) {
        value /= 1024.0;
        ++unit;
    }
    if (unit == 0)
        return QStringLiteral("%1 B").arg(bytes);
    return QStringLiteral("%1 %2").arg(value, 0, 'f', value < 10.0 ? 1 : 0).arg(QLatin1String(units[unit]));
}

QString ServerClient::humanDuration(double seconds) {
    const int total = qRound(seconds);
    if (total <= 0)
        return QString();
    const int hours = total / 3600;
    const int minutes = (total % 3600) / 60;
    if (hours > 0)
        return QStringLiteral("%1h %2m").arg(hours).arg(minutes);
    if (minutes > 0)
        return QStringLiteral("%1m").arg(minutes);
    return QStringLiteral("%1s").arg(total);
}

QString ServerClient::fileExtension(const QString &path) {
    return QFileInfo(path).suffix().toLower();
}

QString ServerClient::accentFor(const QString &seed) {
    static const QStringList palette = {
        QStringLiteral("#E8641F"), QStringLiteral("#5B8DD9"), QStringLiteral("#4FA3A3"),
        QStringLiteral("#B33A3A"), QStringLiteral("#D94F70"), QStringLiteral("#4F7FA3"),
        QStringLiteral("#8A7A5B"), QStringLiteral("#7FA88B"), QStringLiteral("#C9A227"),
        QStringLiteral("#7A3B4F"), QStringLiteral("#3FA34D"), QStringLiteral("#6B5B95"),
    };
    const QByteArray hash = QCryptographicHash::hash(seed.toUtf8(), QCryptographicHash::Sha1);
    int sum = 0;
    for (const char c : hash)
        sum = (sum * 31 + static_cast<unsigned char>(c)) & 0x7fffffff;
    return palette.at(sum % palette.size());
}

QString ServerClient::joinGenres(const QStringList &genres) {
    return genres.join(QStringLiteral(" · "));
}

QString ServerClient::providerLabel(const QString &provider) {
    static const QHash<QString, QString> known{
        {QStringLiteral("lain-metadata-nfo"), QStringLiteral("NFO")},
        {QStringLiteral("lain-metadata-kitsu"), QStringLiteral("Kitsu")},
        {QStringLiteral("lain-metadata-anilist"), QStringLiteral("AniList")},
        {QStringLiteral("lain-metadata-jikan"), QStringLiteral("Jikan")},
    };
    const auto it = known.constFind(provider);
    if (it != known.constEnd())
        return it.value();
    QString label = provider;
    const QString prefix = QStringLiteral("lain-metadata-");
    if (label.startsWith(prefix))
        label = label.mid(prefix.size());
    if (!label.isEmpty())
        label[0] = label[0].toUpper();
    return label;
}
