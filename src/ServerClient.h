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

// Cliente HTTP real do servidor Lain (gateway Go).
//
// O QML consome propriedades com NOTIFY (home, movies, shows, collections,
// currentMedia, searchResults) em vez dos antigos métodos mock síncronos.
// A sessão (URL do servidor, token, usuário) é persistida via QSettings.
//
// Fluxo de estados: offline -> setup | login -> ready.
//   offline  não foi possível alcançar o servidor
//   setup    primeiro acesso: criar conta admin (POST /api/setup)
//   login    servidor ok, sem sessão válida (POST /api/auth/login)
//   ready    sessão válida, dados carregados
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

    Q_PROPERTY(QVariantMap currentMedia READ currentMedia NOTIFY currentMediaChanged)
    Q_PROPERTY(bool loadingItem READ loadingItem NOTIFY currentMediaChanged)
    Q_PROPERTY(QString playbackError READ playbackError NOTIFY playbackErrorChanged)

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

    QVariantMap currentMedia() const { return m_currentMedia; }
    bool loadingItem() const { return m_loadingItem; }
    QString playbackError() const { return m_playbackError; }

    Q_INVOKABLE void start();
    Q_INVOKABLE void login(const QString &username, const QString &password);
    Q_INVOKABLE void setup(const QString &username, const QString &password);
    Q_INVOKABLE void logout();
    Q_INVOKABLE void retry();
    Q_INVOKABLE void refresh();

    Q_INVOKABLE void openMedia(const QString &id);
    Q_INVOKABLE void requestPlayback(const QString &id);
    Q_INVOKABLE void reportProgress(const QString &id, double position, double duration, bool completed);

    Q_INVOKABLE void search(const QString &query);
    Q_INVOKABLE void clearSearch();

    Q_INVOKABLE QString thumbnailUrl(const QString &id, double at, int width) const;
    Q_INVOKABLE void enrichItem(const QString &id, const QString &provider);
    Q_INVOKABLE void removeEnrichment(const QString &id);

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
    void currentMediaChanged();
    void playbackErrorChanged();

    void playbackReady(const QString &url, double positionSec, double durationSec);
    void playbackFailed(const QString &reason);

private:
    using JsonCallback = std::function<void(bool ok, int status, const QJsonDocument &doc, const QString &error)>;

    // HTTP
    void requestJson(const QString &method, const QString &path, const QJsonObject &body,
                     const QUrlQuery &query, bool auth, JsonCallback cb);
    QUrl apiUrl(const QString &path, const QUrlQuery &query = {}) const;
    QString streamUrlFor(const QString &id) const;

    // Estado / sessão
    void setState(const QString &state);
    void setBusy(bool busy);
    void setError(const QString &message);
    void clearError();
    void setSession(const QString &token, const QString &username, const QString &role);
    void clearSession();
    void checkServer();
    void fetchMe();
    void loadAfterLogin();

    // Dados
    void loadLibraries();
    void loadCatalog();
    void rebuildCatalog();
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

    // Helpers de apresentação
    static QString humanSize(qint64 bytes);
    static QString humanDuration(double seconds);
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

    QJsonArray m_raw;                          // catálogo carregado (ordenado)
    QHash<QString, QJsonObject> m_rawById;     // id -> item cru
    QHash<QString, QVariantMap> m_enrichment;  // id -> Enrichment
    QSet<QString> m_enrichKnown;               // ids já consultados (mesmo sem overlay)
    QHash<QString, QVariantMap> m_progress;    // id -> Progress
    QHash<QString, QString> m_libraryNames;    // id -> nome
    QHash<QString, QString> m_libraryTypes;    // id -> type

    QVariantMap m_home;
    QVariantList m_movies, m_shows, m_catalog, m_collections, m_libraries;
    QVariantList m_search;
    QJsonArray m_searchRaw;
    bool m_searching = false;
    QString m_pendingQuery;
    QString m_activeQuery;

    QVariantList m_metadataProviders;
    QString m_enrichStatus = QStringLiteral("idle");

    QVariantMap m_currentMedia;
    bool m_loadingItem = false;

    quint64 m_generation = 0;  // invalida respostas de sessões anteriores
};
