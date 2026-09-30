// Web-parity surfaces (DD-037): account profile, linked list accounts,
// the unified list, admin integrations/transcoding, the server folder
// picker, file deletion, progress reset, per-user playback limits and the
// comic/manga reader. Every route here is one the web client already uses.
#include "ServerClient.h"

#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QMimeDatabase>
#include <QRegularExpression>
#include <QSettings>
#include <QUrl>
#include <QUrlQuery>

namespace {
QString encodePart(const QString &id) {
    return QString::fromLatin1(QUrl::toPercentEncoding(id));
}

constexpr qint64 kMaxAvatarBytes = 2 * 1024 * 1024;
} // namespace

// --------------------------------------------------------------------- account

void ServerClient::finish(const QString &action, bool ok, const QString &message) {
    emit actionFinished(action, ok, message);
}

void ServerClient::setMe(const QJsonObject &user) {
    m_me = user.toVariantMap();
    emit userChanged();
}

QString ServerClient::displayName() const {
    return displayNameFor(m_me);
}

QString ServerClient::displayNameFor(const QVariantMap &user) const {
    const QString name = user.value("profile").toMap().value("display_name").toString().trimmed();
    if (!name.isEmpty())
        return name;
    const QString username = user.value("username").toString();
    return username.isEmpty() ? m_username : username;
}

QString ServerClient::avatarUrlFor(const QVariantMap &user) const {
    const QVariantMap avatar = user.value("profile").toMap().value("avatar").toMap();
    const QString id = user.value("id").toString();
    if (avatar.value("kind").toString() != QLatin1String("upload") || id.isEmpty() || m_token.isEmpty())
        return {};
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("v"), QString::number(avatar.value("version").toLongLong()));
    query.addQueryItem(QStringLiteral("token"), m_token);
    return apiUrl(QStringLiteral("/api/users/%1/avatar").arg(encodePart(id)), query).toString();
}

void ServerClient::updateProfile(const QVariantMap &patch) {
    if (!ready())
        return;
    QJsonObject body;
    if (patch.contains("display_name")) {
        const QString name = patch.value("display_name").toString().trimmed();
        if (name.size() > 40) {
            finish(QStringLiteral("profile"), false, tr("Display name is limited to 40 characters."));
            return;
        }
        body.insert("display_name", name);
    }
    if (patch.contains("bio")) {
        const QString bio = patch.value("bio").toString().trimmed();
        if (bio.size() > 160) {
            finish(QStringLiteral("profile"), false, tr("Bio is limited to 160 characters."));
            return;
        }
        body.insert("bio", bio);
    }
    if (patch.contains("mascot"))
        body.insert("mascot", patch.value("mascot").toString());
    if (body.isEmpty())
        return;
    const QString action = body.contains("mascot") ? QStringLiteral("avatar") : QStringLiteral("profile");
    requestJson("PATCH", QStringLiteral("/api/me/profile"), body, {}, true,
                [this, action](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(action, false, action == QLatin1String("avatar")
                                                  ? tr("Could not change the avatar: %1").arg(err)
                                                  : tr("Could not save the profile: %1").arg(err));
                        return;
                    }
                    setMe(doc.object());
                    loadUsers();
                    finish(action, true, action == QLatin1String("avatar") ? tr("Avatar updated.")
                                                                           : tr("Profile saved."));
                });
}

void ServerClient::uploadAvatar(const QUrl &file) {
    if (!ready())
        return;
    const QString path = file.isLocalFile() ? file.toLocalFile() : file.toString();
    QFile in(path);
    if (!in.open(QIODevice::ReadOnly)) {
        finish(QStringLiteral("avatar"), false, tr("Could not read the picture."));
        return;
    }
    if (in.size() > kMaxAvatarBytes) {
        finish(QStringLiteral("avatar"), false, tr("The image must be 2 MB or smaller."));
        return;
    }
    const QByteArray bytes = in.readAll();
    const QString mime = QMimeDatabase().mimeTypeForFileNameAndData(path, bytes).name();
    static const QStringList accepted{QStringLiteral("image/png"), QStringLiteral("image/jpeg"),
                                      QStringLiteral("image/gif"), QStringLiteral("image/webp")};
    if (!accepted.contains(mime)) {
        finish(QStringLiteral("avatar"), false, tr("Use a PNG, JPEG, GIF or WebP image."));
        return;
    }
    requestBytes("PUT", QStringLiteral("/api/me/avatar"), bytes, mime.toLatin1(), {}, true,
                 [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                     if (!ok) {
                         finish(QStringLiteral("avatar"), false, tr("Could not upload the picture: %1").arg(err));
                         return;
                     }
                     setMe(doc.object());
                     loadUsers();
                     finish(QStringLiteral("avatar"), true, tr("Avatar updated."));
                 });
}

void ServerClient::removeAvatar() {
    if (!ready())
        return;
    requestJson("DELETE", QStringLiteral("/api/me/avatar"), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("avatar"), false, tr("Could not remove the avatar: %1").arg(err));
                        return;
                    }
                    setMe(doc.object());
                    loadUsers();
                    finish(QStringLiteral("avatar"), true, tr("Avatar reset to initials."));
                });
}

void ServerClient::changePassword(const QString &oldPassword, const QString &newPassword) {
    if (!ready())
        return;
    if (newPassword.size() < 8) {
        finish(QStringLiteral("password"), false, tr("At least 8 characters."));
        return;
    }
    const QString username = m_username;
    requestJson("PATCH", QStringLiteral("/api/me/password"),
                QJsonObject{{"old", oldPassword}, {"new", newPassword}}, {}, true,
                [this, username, newPassword](bool ok, int status, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("password"), false,
                               status == 403 || status == 400 ? tr("The current password is wrong.")
                                                              : tr("Could not change the password: %1").arg(err));
                        return;
                    }
                    // Rotating the password bumps the token version: mint a
                    // fresh session instead of getting 401'd on the next call.
                    requestJson("POST", QStringLiteral("/api/auth/login"),
                                QJsonObject{{"username", username}, {"password", newPassword}}, {}, false,
                                [this](bool ok2, int, const QJsonDocument &doc, const QString &) {
                                    if (ok2)
                                        setSession(doc.object().value("token").toString(), m_username, m_role);
                                    finish(QStringLiteral("password"), true,
                                           tr("Password changed. Other sessions were signed out."));
                                });
                });
}

void ServerClient::setPreferredLanguage(const QString &code) {
    if (!ready())
        return;
    const QString next = code.trimmed().toLower();
    static const QRegularExpression iso(QStringLiteral("^[a-z]{3}$"));
    if (!next.isEmpty() && !iso.match(next).hasMatch()) {
        finish(QStringLiteral("language"), false, tr("Three letters, ISO 639-2 (por, eng, jpn)."));
        return;
    }
    requestJson("PATCH", QStringLiteral("/api/me/preferences"), QJsonObject{{"preferred_language", next}},
                {}, true, [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("language"), false, tr("Could not save the language: %1").arg(err));
                        return;
                    }
                    setMe(doc.object());
                    finish(QStringLiteral("language"), true, tr("Language saved."));
                });
}

// ----------------------------------------------------------- links and lists

void ServerClient::loadLinks() {
    if (!ready())
        return;
    const quint64 gen = m_generation;
    requestJson("GET", QStringLiteral("/api/me/links"), {}, {}, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation)
                        return;
                    if (!ok) {
                        m_linksLoaded = true;
                        emit linksChanged();
                        finish(QStringLiteral("links"), false, tr("Could not load connected accounts: %1").arg(err));
                        return;
                    }
                    m_links = doc.object().value("links").toArray().toVariantList();
                    // The pin flow works without admin setup; the server only
                    // answers when its public client is configured.
                    requestJson("GET", QStringLiteral("/api/me/links/anilist/pin"), {}, {}, true,
                                [this, gen](bool ok2, int, const QJsonDocument &doc2, const QString &) {
                                    if (gen != m_generation)
                                        return;
                                    m_linkPinUrl = ok2 ? doc2.object().value("url").toString() : QString();
                                    m_linksLoaded = true;
                                    emit linksChanged();
                                });
                });
}

void ServerClient::connectLink(const QString &platform) {
    if (!ready() || platform.isEmpty())
        return;
    requestJson("GET", QStringLiteral("/api/me/links/%1/authorize").arg(encodePart(platform)), {}, {}, true,
                [this, platform](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        const QString code = doc.object().value("code").toString();
                        if (code == QLatin1String("not-configured")) {
                            finish(QStringLiteral("link"), false,
                                   m_linkPinUrl.isEmpty()
                                       ? tr("%1 is not configured on this server — ask the administrator.").arg(platform)
                                       : tr("Redirect sign-in needs the administrator app — use a code instead."));
                        } else {
                            finish(QStringLiteral("link"), false,
                                   tr("Could not start the %1 connection: %2").arg(platform, err));
                        }
                        return;
                    }
                    // The consent screen is remote: hand it to the browser.
                    QDesktopServices::openUrl(QUrl(doc.object().value("url").toString()));
                    finish(QStringLiteral("link-opened"), true,
                           tr("Finish connecting in your browser, then sync here."));
                });
}

void ServerClient::submitLinkCode(const QString &platform, const QString &code) {
    if (!ready() || platform.isEmpty())
        return;
    const QString trimmed = code.trimmed();
    if (trimmed.isEmpty()) {
        finish(QStringLiteral("link-code"), false, tr("Paste the code the AniList page shows."));
        return;
    }
    requestJson("POST", QStringLiteral("/api/me/links/%1/code").arg(encodePart(platform)),
                QJsonObject{{"code", trimmed}}, {}, true,
                [this, platform](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("link-code"), false,
                               doc.object().value("code").toString() == QLatin1String("invalid-grant")
                                   ? tr("AniList rejected that code — authorize again and copy the whole code.")
                                   : tr("Could not link the account: %1").arg(err));
                        return;
                    }
                    finish(QStringLiteral("link-code"), true, tr("%1 connected — importing your list.").arg(platform));
                    loadLinks();
                });
}

void ServerClient::syncLink(const QString &platform) {
    if (!ready() || platform.isEmpty())
        return;
    requestJson("POST", QStringLiteral("/api/me/links/%1/sync").arg(encodePart(platform)), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("link-sync"), false, tr("Sync failed: %1").arg(err));
                        return;
                    }
                    const QJsonObject stats = doc.object().value("stats").toObject();
                    finish(QStringLiteral("link-sync"), true,
                           tr("Synced: %1 entries, %2 removed.")
                               .arg(stats.value("upserted").toInt())
                               .arg(stats.value("removed").toInt()));
                    loadLinks();
                });
}

void ServerClient::setLinkScrobble(const QString &platform, bool scrobble) {
    if (!ready() || platform.isEmpty())
        return;
    requestJson("PATCH", QStringLiteral("/api/me/links/%1").arg(encodePart(platform)),
                QJsonObject{{"scrobble", scrobble}}, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok)
                        finish(QStringLiteral("link-scrobble"), false, tr("Could not change the setting: %1").arg(err));
                    loadLinks();
                });
}

void ServerClient::unlink(const QString &platform) {
    if (!ready() || platform.isEmpty())
        return;
    requestJson("DELETE", QStringLiteral("/api/me/links/%1").arg(encodePart(platform)), {}, {}, true,
                [this, platform](bool ok, int, const QJsonDocument &, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("unlink"), false, tr("Could not disconnect: %1").arg(err));
                        return;
                    }
                    finish(QStringLiteral("unlink"), true,
                           tr("%1 disconnected; imported entries removed.").arg(platform));
                    loadLinks();
                });
}

void ServerClient::loadList(const QString &type, const QString &status) {
    if (!ready())
        return;
    QUrlQuery query;
    if (!type.isEmpty())
        query.addQueryItem(QStringLiteral("type"), type);
    if (!status.isEmpty())
        query.addQueryItem(QStringLiteral("status"), status);
    m_listLoading = true;
    m_listError.clear();
    emit listChanged();
    const quint64 gen = m_generation;
    requestJson("GET", QStringLiteral("/api/list"), {}, query, true,
                [this, gen](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (gen != m_generation)
                        return;
                    m_listLoading = false;
                    if (!ok)
                        m_listError = tr("Could not load your list: %1").arg(err);
                    else
                        m_listEntries = doc.object().value("entries").toArray().toVariantList();
                    emit listChanged();
                });
}

// ----------------------------------------------------------------------- admin

void ServerClient::loadIntegrations() {
    if (!ready())
        return;
    requestJson("GET", QStringLiteral("/api/admin/settings/integrations"), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("integrations"), false,
                               tr("Could not load integration settings: %1").arg(err));
                        return;
                    }
                    m_integrations = doc.object().value("platforms").toObject().toVariantMap();
                    emit integrationsChanged();
                });
}

void ServerClient::saveIntegrations(const QString &clientId, const QString &clientSecret) {
    if (!ready())
        return;
    QJsonObject body{{"anilist_client_id", clientId.trimmed()}};
    if (!clientSecret.trimmed().isEmpty())
        body.insert("anilist_client_secret", clientSecret.trimmed());
    requestJson("PUT", QStringLiteral("/api/admin/settings/integrations"), body, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("integrations"), false,
                               tr("Could not save the integration settings: %1").arg(err));
                        return;
                    }
                    m_integrations = doc.object().value("platforms").toObject().toVariantMap();
                    emit integrationsChanged();
                    finish(QStringLiteral("integrations"), true, tr("Integration settings saved."));
                });
}

void ServerClient::loadTranscodeSettings() {
    if (!ready())
        return;
    requestJson("GET", QStringLiteral("/api/admin/settings/transcode"), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("transcode"), false,
                               tr("Could not load transcoding settings: %1").arg(err));
                        return;
                    }
                    const QJsonObject root = doc.object();
                    m_transcodeSettings = root.value("settings").toObject().toVariantMap();
                    m_transcodeCapabilities = root.value("capabilities").toObject().toVariantMap();
                    emit transcodeChanged();
                });
}

void ServerClient::saveTranscodeSettings(const QVariantMap &settings) {
    if (!ready() || settings.isEmpty())
        return;
    requestJson("PUT", QStringLiteral("/api/admin/settings/transcode"), QJsonObject::fromVariantMap(settings),
                {}, true, [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("transcode"), false,
                               tr("Could not save transcoding settings: %1").arg(err));
                        return;
                    }
                    const QJsonObject root = doc.object();
                    m_transcodeSettings = root.value("settings").toObject().toVariantMap();
                    m_transcodeCapabilities = root.value("capabilities").toObject().toVariantMap();
                    emit transcodeChanged();
                    finish(QStringLiteral("transcode"), true, tr("Transcoding settings saved. New sessions use them."));
                });
}

void ServerClient::loadTranscodeSessions() {
    if (!ready())
        return;
    requestJson("GET", QStringLiteral("/api/admin/transcodes"), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &) {
                    if (!ok)
                        return;
                    m_transcodeSessions = doc.object().value("sessions").toArray().toVariantList();
                    emit transcodeSessionsChanged();
                });
}

void ServerClient::cancelTranscodeSession(const QString &session) {
    if (!ready() || session.isEmpty())
        return;
    requestJson("DELETE", QStringLiteral("/api/admin/transcodes/%1").arg(encodePart(session)), {}, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    finish(QStringLiteral("transcode-cancel"), ok,
                           ok ? tr("Session cancelled.") : tr("Could not cancel the session: %1").arg(err));
                    loadTranscodeSessions();
                });
}

void ServerClient::browseFolders(const QString &path) {
    if (!ready())
        return;
    QUrlQuery query;
    if (!path.isEmpty())
        query.addQueryItem(QStringLiteral("path"), path);
    m_browsing = true;
    m_browseError.clear();
    emit browseChanged();
    requestJson("GET", QStringLiteral("/api/browse"), {}, query, true,
                [this](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    m_browsing = false;
                    if (!ok)
                        m_browseError = tr("Could not list server folders: %1").arg(err);
                    else
                        m_browse = doc.object().toVariantMap();
                    emit browseChanged();
                });
}

void ServerClient::deleteItemFile(const QString &id) {
    if (!ready() || id.isEmpty())
        return;
    requestJson("DELETE", QStringLiteral("/api/items/%1").arg(encodePart(id)), {}, {}, true,
                [this, id](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("delete-file"), false, tr("Could not delete the file: %1").arg(err));
                        return;
                    }
                    // The row survives as `missing` (server D-073).
                    const QJsonObject item = doc.object();
                    if (!item.isEmpty())
                        m_rawById.insert(id, item);
                    finish(QStringLiteral("delete-file"), true, tr("File deleted."));
                    emit itemDeleted(id);
                    loadLibraries();
                });
}

QVariantMap ServerClient::progressFor(const QString &id) const {
    return m_progress.value(id);
}

void ServerClient::resetProgress(const QString &id) {
    if (!ready() || id.isEmpty())
        return;
    const double duration = m_progress.value(id).value("duration_sec").toDouble();
    requestJson("PUT", QStringLiteral("/api/items/%1/progress").arg(encodePart(id)),
                QJsonObject{{"position_sec", 0.0}, {"duration_sec", duration}, {"completed", false}}, {}, true,
                [this, id](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    if (!ok) {
                        finish(QStringLiteral("reset-progress"), false, tr("Could not reset progress: %1").arg(err));
                        return;
                    }
                    m_progress.insert(id, doc.object().toVariantMap());
                    dequeueProgress(id);
                    rebuildItemViews(id);
                    finish(QStringLiteral("reset-progress"), true, tr("Progress reset."));
                    loadHome();
                });
}

void ServerClient::setUserPlayback(const QString &id, const QVariantMap &policy) {
    if (!ready() || id.isEmpty())
        return;
    QJsonObject playback{
        {"allow_video_transcode", policy.value("allow_video_transcode", true).toBool()},
        {"allow_audio_transcode", policy.value("allow_audio_transcode", true).toBool()},
        {"allow_remux", policy.value("allow_remux", true).toBool()},
        {"max_bitrate_kbps", qMax(0, policy.value("max_bitrate_kbps").toInt())},
        {"max_streams", qMax(0, policy.value("max_streams").toInt())},
    };
    const QString subtitle = policy.value("subtitle_mode").toString();
    if (!subtitle.isEmpty())
        playback.insert("subtitle_mode", subtitle);
    requestJson("PATCH", QStringLiteral("/api/users/%1").arg(encodePart(id)),
                QJsonObject{{"playback", playback}}, {}, true,
                [this](bool ok, int, const QJsonDocument &, const QString &err) {
                    finish(QStringLiteral("user-playback"), ok,
                           ok ? tr("Playback limits updated.") : tr("Could not update the playback limits: %1").arg(err));
                    if (ok)
                        loadUsers();
                });
}

// ---------------------------------------------------------------------- reader

bool ServerClient::isReadable(const QString &kind) const {
    return kind == QLatin1String("comic") || kind == QLatin1String("manga");
}

void ServerClient::loadReader(const QString &id) {
    if (!ready() || id.isEmpty())
        return;
    m_readerLoading = true;
    m_readerError.clear();
    m_readerView.clear();
    emit readerChanged();
    requestJson("GET", QStringLiteral("/api/items/%1/pages").arg(encodePart(id)), {}, {}, true,
                [this, id](bool ok, int, const QJsonDocument &doc, const QString &err) {
                    m_readerLoading = false;
                    if (!ok) {
                        m_readerError = tr("Could not open this file: %1").arg(err);
                    } else {
                        m_readerView = doc.object().toVariantMap();
                        m_readerView.insert(QStringLiteral("item_id"), id);
                    }
                    emit readerChanged();
                });
}

QString ServerClient::readerPageUrl(const QString &id, int index) const {
    if (id.isEmpty() || index < 0)
        return {};
    QUrlQuery query;
    if (!m_token.isEmpty())
        query.addQueryItem(QStringLiteral("token"), m_token);
    return apiUrl(QStringLiteral("/api/items/%1/pages/%2").arg(encodePart(id)).arg(index), query).toString();
}

// Web reader encoding (lib/reader/layout.ts): the 1-based page is the
// position and the page count the duration, so Continue reading resumes.
void ServerClient::saveReaderProgress(const QString &id, int page, int total) {
    if (id.isEmpty() || total <= 0)
        return;
    const int at = qBound(0, page, total - 1);
    reportProgress(id, at + 1, total, at + 1 >= total);
}

int ServerClient::readerStartPage(const QString &id, int total) const {
    const QVariantMap p = m_progress.value(id);
    const double pos = p.value("position_sec").toDouble();
    if (p.isEmpty() || p.value("completed").toBool() || pos < 1 || total <= 0)
        return 0;
    return qBound(0, int(pos) - 1, total - 1);
}

// ------------------------------------------------------------------ prefs

QVariant ServerClient::pref(const QString &key, const QVariant &fallback) const {
    if (key.isEmpty())
        return fallback;
    return QSettings().value(QStringLiteral("prefs/") + key, fallback);
}

void ServerClient::setPref(const QString &key, const QVariant &value) {
    if (key.isEmpty())
        return;
    QSettings().setValue(QStringLiteral("prefs/") + key, value);
    emit prefsChanged();
}

// Web effects-policy order, reduced to what the desktop can know before
// playback starts: a per-library-type override wins over the default.
QString ServerClient::effectFor(const QString &libraryId) const {
    const QString type = m_libraryTypes.value(libraryId).toLower();
    if (!type.isEmpty()) {
        const QString typed = pref(QStringLiteral("effects/type/") + type).toString();
        if (!typed.isEmpty() && typed != QLatin1String("default"))
            return typed;
    }
    return pref(QStringLiteral("effects/default"), QStringLiteral("off")).toString();
}
