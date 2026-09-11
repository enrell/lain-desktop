#pragma once
#include <QObject>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSet>
#include <QStringList>
#include <QUrl>
#include <QUrlQuery>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

// HTTP client for the real Lain server (Go gateway).
//
// QML consumes NOTIFY-backed properties (home, movies, shows, collections,
// currentMedia, and searchResults). The server URL and session are persisted
// through QSettings.
//
// State flow: offline -> setup | login -> ready.
//   offline  the server could not be reached
//   setup    first access: create the admin account (POST /api/setup)
//   login    server reachable, but no valid session (POST /api/auth/login)
//   ready    valid session and loaded data
class ServerClient : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString serverUrl READ serverUrl WRITE setServerUrl NOTIFY serverUrlChanged)
    Q_PROPERTY(QString state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY stateChanged)
    Q_PROPERTY(bool authenticated READ authenticated NOTIFY stateChanged)
    Q_PROPERTY(QString username READ username NOTIFY userChanged)
    Q_PROPERTY(QString role READ role NOTIFY userChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

    Q_PROPERTY(QVariantMap home READ home NOTIFY homeChanged)
    Q_PROPERTY(QVariantList movies READ movies NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList shows READ shows NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList catalog READ catalog NOTIFY catalogChanged)
    Q_PROPERTY(QVariantList collections READ collections NOTIFY collectionsChanged)
    Q_PROPERTY(QVariantList libraries READ libraries NOTIFY librariesChanged)

    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchChanged)
    Q_PROPERTY(bool searching READ searching NOTIFY searchChanged)

    Q_PROPERTY(QVariantList metadataProviders READ metadataProviders NOTIFY metadataProvidersChanged)
    Q_PROPERTY(QString enrichStatus READ enrichStatus NOTIFY enrichStatusChanged)
    Q_PROPERTY(QVariantList users READ users NOTIFY usersChanged)
    Q_PROPERTY(QVariantMap scanState READ scanState NOTIFY scanChanged)
    Q_PROPERTY(QVariantList pluginInfo READ pluginInfo NOTIFY pluginsChanged)
    Q_PROPERTY(QVariantList composition READ composition NOTIFY pluginsChanged)
    Q_PROPERTY(QString adminStatus READ adminStatus NOTIFY adminChanged)
    Q_PROPERTY(QVariantList series READ series NOTIFY catalogChanged)
    Q_PROPERTY(bool autoResume READ autoResume WRITE setAutoResume NOTIFY playbackSettingsChanged)
    Q_PROPERTY(bool autoplayNext READ autoplayNext WRITE setAutoplayNext NOTIFY playbackSettingsChanged)

    Q_PROPERTY(QVariantMap currentMedia READ currentMedia NOTIFY currentMediaChanged)
    Q_PROPERTY(bool loadingItem READ loadingItem NOTIFY currentMediaChanged)
    Q_PROPERTY(QString playbackError READ playbackError NOTIFY playbackErrorChanged)
    Q_PROPERTY(int pendingProgress READ pendingProgress NOTIFY progressQueueChanged)

public:
    explicit ServerClient(QObject *parent = nullptr);

    QString serverUrl() const { return m_serverUrl; }
    void setServerUrl(const QString &url);

    QString state() const { return m_state; }
    bool ready() const { return m_state == QLatin1String("ready"); }
    bool authenticated() const { return m_state == QLatin1String("ready"); }
    QString username() const { return m_username; }
    QString role() const { return m_role; }
    QString errorMessage() const { return m_error; }
    bool busy() const { return m_busy; }

    QVariantMap home() const { return m_home; }
    QVariantList movies() const { return m_movies; }
    QVariantList shows() const { return m_shows; }
    QVariantList catalog() const { return m_catalog; }
    QVariantList collections() const { return m_collections; }
    QVariantList libraries() const { return m_libraries; }

    QVariantList searchResults() const { return m_search; }
    bool searching() const { return m_searching; }

    QVariantList metadataProviders() const { return m_metadataProviders; }
    QString enrichStatus() const { return m_enrichStatus; }

    QVariantList users() const { return m_users; }
    QVariantMap scanState() const { return m_scan; }
    QVariantList pluginInfo() const { return m_pluginInfo; }
    QVariantList composition() const { return m_composition; }
    QString adminStatus() const { return m_adminStatus; }
    QVariantList series() const { return m_series; }
    bool autoResume() const { return m_autoResume; }
    void setAutoResume(bool resume);
    bool autoplayNext() const { return m_autoplayNext; }
    void setAutoplayNext(bool next);

    QVariantMap currentMedia() const { return m_currentMedia; }
    bool loadingItem() const { return m_loadingItem; }
    QString playbackError() const { return m_playbackError; }
    int pendingProgress() const { return m_queued.size(); }

    Q_INVOKABLE void start();
    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void setup(const QString &username, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void retry();
    Q_INVOKABLE void refresh();

    Q_INVOKABLE void openMedia(const QString &id);
    Q_INVOKABLE void requestPlayback(const QString &id);
    Q_INVOKABLE void reportProgress(const QString &id, double position, double duration, bool completed);
    Q_INVOKABLE void flushProgress();

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void clearSearch();

    Q_INVOKABLE QString thumbnailUrl(const QString &id, double at, int width) const;
    Q_INVOKABLE void enrichItem(const QString &id, const QString &provider);
    Q_INVOKABLE void removeEnrichment(const QString &id);

    // Server administration (admin role; destructive callers confirm in UI).
    Q_INVOKABLE void loadUsers();
    Q_INVOKABLE void createUser(const QString &username, const QString &password, const QString &role);
    Q_INVOKABLE void setUserDisabled(const QString &id, bool disabled);
    Q_INVOKABLE void setUserRole(const QString &id, const QString &role);
    Q_INVOKABLE void resetUserPassword(const QString &id, const QString &password);
    Q_INVOKABLE void createLibrary(const QString &name, const QString &type, const QString &path);
    Q_INVOKABLE void deleteLibrary(const QString &id);
    Q_INVOKABLE void triggerScan();
    Q_INVOKABLE void refreshScanStatus();
    Q_INVOKABLE void downloadBackup(const QString &filePath);
    Q_INVOKABLE void swapProviders(const QString &capability, const QStringList &providers);

    // Series navigation (DD-030) and playback defaults (DD-031).
    Q_INVOKABLE QString seriesIdFor(const QString &id) const;
    Q_INVOKABLE QString seriesAutoplayMode(const QString &seriesId) const; // default|on|off
    Q_INVOKABLE void setSeriesAutoplay(const QString &seriesId, const QString &mode);
    Q_INVOKABLE QString nextEpisodeId(const QString &id) const;

signals:
    void serverUrlChanged();
    void stateChanged();
    void userChanged();
    void errorMessageChanged();
    void busyChanged();
    void homeChanged();
    void catalogChanged();
    void collectionsChanged();
    void librariesChanged();
    void searchChanged();
    void metadataProvidersChanged();
    void enrichStatusChanged();
    void usersChanged();
    void scanChanged();
    void pluginsChanged();
    void adminChanged();
    void playbackSettingsChanged();
    void currentMediaChanged();
    void playbackErrorChanged();
    void progressQueueChanged();

    void playbackReady(const QString &url, double positionSec, double durationSec);
    void playbackFailed(const QString &reason);

private:
    using JsonCallback = std::function<void(bool ok, int status, const QJsonDocument &doc, const QString &error)>;

    // HTTP
    void requestJson(const QString &method, const QString &path, const QJsonObject &body,
                     const QUrlQuery &query, bool auth, JsonCallback cb);
    QUrl apiUrl(const QString &path, const QUrlQuery &query = {}) const;
    QString streamUrlFor(const QString &id) const;

    // State and session
    void setState(const QString &state);
    void setBusy(bool busy);
    void setError(const QString &message);
    void clearError();
    void setAdminStatus(const QString &status);
    void setSession(const QString &token, const QString &username, const QString &role);
    void clearSession();
    void checkServer();
    void fetchMe();
    void loadAfterLogin();

    // Catalog data
    void loadLibraries();
    void loadCatalog();
    void loadCatalogPage(int offset, const QJsonArray &accumulated);
    void rebuildCatalog();
    void buildSeries();
    void loadEnrichments(const QStringList &ids, std::function<void()> done);
    void loadEnrichChunks(const QStringList &ids, int offset, std::function<void()> done);
    void loadHome();
    void buildHome(const QJsonArray &recent, const QJsonArray &cont);
    void rebuildCollections();
    void loadPlugins();
    void applyEnrichment(const QString &id, const QJsonObject &overlay);
    void rebuildItemViews(const QString &id);

    QJsonObject rawItem(const QString &id) const;
    QVariantMap normalize(const QJsonObject &item) const;
    QVariantList normalizeAll(const QJsonArray &items) const;
    void issueSearch(const QString &query);

    // Presentation helpers
    static QString humanSize(qint64 bytes);
    static QString humanDuration(double seconds);
    static QString seriesKey(const QString &libraryId, const QString &seriesTitle);
    static QString seriesTitleFor(const QVariantMap &card);
    static QString fileExtension(const QString &path);
    static QString accentFor(const QString &seed);
    static QString joinGenres(const QStringList &genres);
    static QString providerLabel(const QString &provider);
    QString thumbnailUrlFor(const QString &id, double at, int width) const;

    QNetworkAccessManager *m_net = nullptr;
    QTimer *m_searchDebounce = nullptr;

    QString m_serverUrl;
    QString m_token;
    QString m_username;
    QString m_role;
    QString m_state = QStringLiteral("offline");
    QString m_error;
    QString m_playbackError;
    bool m_busy = false;

    QJsonArray m_raw;                          // loaded, sorted catalog
    QHash<QString, QJsonObject> m_rawById;     // id -> raw item
    QHash<QString, QVariantMap> m_enrichment;  // id -> enrichment overlay
    QSet<QString> m_enrichKnown;               // queried IDs, including misses
    QHash<QString, QVariantMap> m_progress;    // id -> watch progress
    QHash<QString, QString> m_libraryNames;    // id -> display name
    QHash<QString, QString> m_libraryTypes;    // id -> library type

    QVariantMap m_home;
    QVariantList m_movies, m_shows, m_catalog, m_collections, m_libraries;
    QVariantList m_search;
    QJsonArray m_searchRaw;
    bool m_searching = false;
    QString m_pendingQuery;
    QString m_activeQuery;

    QVariantList m_metadataProviders;
    QString m_enrichStatus = QStringLiteral("idle");

    QVariantList m_users;
    QVariantMap m_scan;
    QVariantList m_pluginInfo;
    QVariantList m_composition;
    QString m_adminStatus;

    QVariantList m_series;
    bool m_autoResume = true;
    bool m_autoplayNext = true;
    QVariantMap m_seriesAutoplay; // series id -> default|on|off

    QVariantMap m_currentMedia;
    bool m_loadingItem = false;

    // Offline progress queue (DD-032): last position per item, persisted
    // and bounded, flushed with queued-client-wins on reconnect.
    QHash<QString, QVariantMap> m_queued;
    QStringList m_queueOrder;
    bool m_flushing = false;
    void enqueueProgress(const QString &id, double position, double duration, bool completed);
    void dequeueProgress(const QString &id);
    void persistQueue();
    void loadQueue();

    quint64 m_generation = 0;  // invalidates replies from previous sessions
};
