#include <QtTest>
#include <QFile>
#include <QSettings>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTemporaryDir>

#include "ServerClient.h"
#include "stubserver.h"

// Real ServerClient HTTP tests against the gateway stub,
// without a display or external network. It runs offscreen through ctest.
class TestServerClient : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("lain-test"));
        QCoreApplication::setApplicationName(QStringLiteral("lain-test"));
    }

    void init() {
        QSettings settings;
        settings.clear();
        settings.sync();

        m_stub = new StubServer(this);
        QVERIFY(m_stub->listen());
        m_client = new ServerClient(this);
    }

    void cleanup() {
        delete m_client;
        m_client = nullptr;
        delete m_stub;
        m_stub = nullptr;
        QSettings settings;
        settings.clear();
        settings.sync();
    }

    void requiresLoginWithoutToken() {
        m_client->setServerUrl(m_stub->baseUrl());
        m_client->start();
        QTRY_COMPARE(m_client->state(), QStringLiteral("login"));
    }

    void detectsFirstRunSetup() {
        m_stub->setupRequired = true;
        m_client->setServerUrl(m_stub->baseUrl());
        m_client->start();
        QTRY_COMPARE(m_client->state(), QStringLiteral("setup"));
    }

    void loginLoadsSessionAndCatalog() {
        QVERIFY(startReadyClient());
        QCOMPARE(m_client->username(), QStringLiteral("admin"));
        QCOMPARE(m_client->role(), QStringLiteral("admin"));

        QTRY_COMPARE(m_client->movies().size(), 1);
        QTRY_COMPARE(m_client->shows().size(), 2);
        QCOMPARE(m_client->libraries().size(), 2);
    }

    void paginatedCatalogLoadsAllItems() {
        m_stub->paginateOneByOne = true;
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->movies().size(), 1);
        QTRY_COMPARE(m_client->shows().size(), 2);
        QTRY_COMPARE(m_client->catalog().size(), 3);
        int catalogGets = 0;
        for (const auto &req : m_stub->requests) {
            if (req.first == QLatin1String("GET") && req.second == QLatin1String("/api/catalog"))
                ++catalogGets;
        }
        QVERIFY(catalogGets >= 3);
    }

    void normalizesEnrichmentAndProgress() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->shows().size(), 2);

        QVariantMap movie = m_client->movies().first().toMap();
        QCOMPARE(movie.value("id").toString(), QStringLiteral("movie-1"));
        QCOMPARE(movie.value("title").toString(), QStringLiteral("Some Movie"));
        QCOMPARE(movie.value("displayTitle").toString(), QStringLiteral("Some Movie"));
        QCOMPARE(movie.value("year").toInt(), 2019);
        QCOMPARE(movie.value("genre").toString(), QStringLiteral("Drama"));
        QCOMPARE(movie.value("genres").toString(), QStringLiteral("Drama · Thriller"));
        QVERIFY(!movie.value("overview").toString().isEmpty());
        QVERIFY(!movie.value("size_human").toString().isEmpty());
        QVERIFY(movie.value("tech").toMap().value("container").toString() == QLatin1String("MP4"));
        QVERIFY(movie.value("poster").toString().startsWith(QLatin1String("data:image/svg+xml")));
        // Accent is always deterministic.
        QVERIFY(movie.value("accent").toString().startsWith(QLatin1Char('#')));

        // Continue-watching progress becomes the card fraction.
        QVariantMap show = findCard(m_client->shows(), QStringLiteral("show-1"));
        QCOMPARE(show.value("progress").toDouble(), 0.5);
        QCOMPARE(show.value("runtime").toString(), QStringLiteral("30s"));
        QVERIFY(qAbs(show.value("position_sec").toDouble() - 15.0) < 0.001);
    }

    void buildsHomeWithContinueAndRecent() {
        QVERIFY(startReadyClient());
        QTRY_VERIFY(!m_client->home().isEmpty());
        QTRY_COMPARE(m_client->home().value("continueWatching").toList().size(), 1);
        // The hero prioritizes continue-watching media.
        QCOMPARE(m_client->home().value("hero").toMap().value("id").toString(),
                 QStringLiteral("show-1"));
        QTRY_COMPARE(m_client->home().value("recentlyAdded").toList().size(), 3);
    }

    void searchReturnsMatches() {
        QVERIFY(startReadyClient());
        QTRY_VERIFY(m_client->movies().size() > 0);

        m_client->search(QStringLiteral("frieren"));
        QTRY_COMPARE(m_client->searchResults().size(), 2);
        QVERIFY(!m_client->searching());

        m_client->clearSearch();
        QCOMPARE(m_client->searchResults().size(), 0);
    }

    void playbackPlanYieldsStreamUrlAndResume() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->movies().size(), 1);

        QSignalSpy spy(m_client, &ServerClient::playbackReady);
        QSignalSpy failures(m_client, &ServerClient::playbackFailed);
        m_client->requestPlayback(QStringLiteral("show-1"));
        QTRY_COMPARE(spy.count(), 1);
        QCOMPARE(failures.count(), 0);

        const QList<QVariant> args = spy.takeFirst();
        const QString url = args.at(0).toString();
        QVERIFY(url.contains(QStringLiteral("/api/items/show-1/stream")));
        QVERIFY(url.contains(QStringLiteral("token=test-token")));
        QCOMPARE(args.at(1).toDouble(), 15.0);
        QCOMPARE(args.at(2).toDouble(), 30.0);
    }

    void reportProgressWritesToServer() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->movies().size(), 1);

        m_client->reportProgress(QStringLiteral("movie-1"), 42.5, 100.0, false);
        QTRY_COMPARE(m_stub->progressPuts.size(), 1);
        const QJsonObject put = m_stub->progressPuts.first();
        QCOMPARE(put.value("item_id").toString(), QStringLiteral("movie-1"));
        QCOMPARE(put.value("position_sec").toDouble(), 42.5);
        QCOMPARE(put.value("duration_sec").toDouble(), 100.0);
        QCOMPARE(put.value("completed").toBool(), false);
    }

    void expiredTokenReturnsToLogin() {
        QSettings settings;
        settings.setValue(QStringLiteral("server/url"), m_stub->baseUrl());
        settings.setValue(QStringLiteral("auth/token"), QStringLiteral("expired"));
        settings.sync();

        m_client->start();
        QTRY_COMPARE(m_client->state(), QStringLiteral("login"));
        QVERIFY(QSettings().value(QStringLiteral("auth/token")).toString().isEmpty());
        QVERIFY(m_client->errorMessage().contains(QStringLiteral("Session")));
    }

    void loadsMetadataProvidersForAdmins() {        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->metadataProviders().size(), 2);
        const QVariantMap first = m_client->metadataProviders().first().toMap();
        QCOMPARE(first.value("id").toString(), QStringLiteral("lain-metadata-anilist"));
        QCOMPARE(first.value("name").toString(), QStringLiteral("AniList"));
        QVERIFY(first.value("healthy").toBool());
    }

    void enrichItemRefreshesOverlay() {
        QVERIFY(startReadyClient());
        m_client->openMedia(QStringLiteral("show-1"));
        QTRY_COMPARE(m_client->currentMedia().value("enrichProviderLabel").toString(), QStringLiteral("NFO"));
        QVERIFY(!m_client->currentMedia().value("overview").toString().contains("Refreshed"));

        m_client->enrichItem(QStringLiteral("show-1"), QStringLiteral("lain-metadata-anilist"));
        QTRY_COMPARE(m_client->enrichStatus(), QStringLiteral("idle"));
        QTRY_COMPARE(m_client->currentMedia().value("enrichProviderLabel").toString(), QStringLiteral("AniList"));
        QVERIFY(m_client->currentMedia().value("overview").toString().contains(QStringLiteral("Refreshed")));
        QVERIFY(m_client->currentMedia().value("enriched").toBool());
    }

    void removeEnrichmentClearsOverlay() {
        QVERIFY(startReadyClient());
        m_client->openMedia(QStringLiteral("show-1"));
        QTRY_VERIFY(m_client->currentMedia().value("enriched").toBool());

        m_client->removeEnrichment(QStringLiteral("show-1"));
        QTRY_COMPARE(m_client->enrichStatus(), QStringLiteral("idle"));
        QTRY_VERIFY(!m_client->currentMedia().value("enriched").toBool());
        QVERIFY(m_client->currentMedia().value("poster").toString().isEmpty());
    }

    void thumbnailUrlCarriesTokenAndParams() {
        QVERIFY(startReadyClient());
        const QString url = m_client->thumbnailUrl(QStringLiteral("show-1"), 8.0, 320);
        QVERIFY(url.contains(QStringLiteral("/api/items/show-1/thumbnail")));
        QVERIFY(url.contains(QStringLiteral("t=8.0")));
        QVERIFY(url.contains(QStringLiteral("w=320")));
        QVERIFY(url.contains(QStringLiteral("token=test-token")));
    }

    void loadsUsersForAdmin() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->users().size(), 2);
        QCOMPARE(m_client->users().first().toMap().value("username").toString(),
                 QStringLiteral("admin"));
    }

    void createAndDisableUser() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->users().size(), 2);
        m_client->createUser(QStringLiteral("bob"), QStringLiteral("pw123456"),
                             QStringLiteral("user"));
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("created")));
        m_client->setUserDisabled(QStringLiteral("user-guest"), true);
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("disabled")));
        m_client->setUserDisabled(QStringLiteral("user-guest"), false);
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("enabled")));
    }

    void createAndDeleteLibrary() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->libraries().size(), 2);
        m_client->createLibrary(QStringLiteral("Docs"), QStringLiteral("movie"),
                                QStringLiteral("/tmp/docs"));
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("created")));
        m_client->deleteLibrary(QStringLiteral("lib-new"));
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("deleted")));
    }

    void scanFinishesAndReloads() {
        QVERIFY(startReadyClient());
        m_client->triggerScan();
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("finished")));
        QCOMPARE(m_client->scanState().value("state").toString(), QStringLiteral("done"));
    }

    void backupDownloadsBytes() {
        QVERIFY(startReadyClient());
        QTemporaryDir dir;
        QVERIFY(dir.isValid());
        const QString path = dir.filePath(QStringLiteral("lain.db"));
        m_client->downloadBackup(path);
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("saved")));
        QFile out(path);
        QVERIFY(out.open(QIODevice::ReadOnly));
        QCOMPARE(out.readAll(), QByteArray("test-backup-bytes"));
    }

    void seriesGroupsUnnumberedEpisodesAsSpecials() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->shows().size(), 2);
        QTRY_COMPARE(m_client->series().size(), 1);
        const QVariantMap info = m_client->series().first().toMap();
        QCOMPARE(info.value("specialsCount").toInt(), 2);
        QVERIFY(!m_client->seriesIdFor(QStringLiteral("show-1")).isEmpty());
        QVERIFY(m_client->nextEpisodeId(QStringLiteral("show-1")).isEmpty());
    }

    void playbackDefaultsPersist() {
        QVERIFY(startReadyClient());
        QVERIFY(m_client->autoResume());
        QVERIFY(m_client->autoplayNext());
        m_client->setAutoResume(false);
        QVERIFY(!m_client->autoResume());
        m_client->setAutoResume(true);
        m_client->setSeriesAutoplay(QStringLiteral("series:test"), QStringLiteral("on"));
        QCOMPARE(m_client->seriesAutoplayMode(QStringLiteral("series:test")),
                 QStringLiteral("on"));
        m_client->setSeriesAutoplay(QStringLiteral("series:test"), QStringLiteral("bogus"));
        QCOMPARE(m_client->seriesAutoplayMode(QStringLiteral("series:test")),
                 QStringLiteral("default"));
    }

private:
    bool startReadyClient() {
        m_client->setServerUrl(m_stub->baseUrl());
        m_client->start();
        if (!QTest::qWaitFor([this] { return m_client->state() == QLatin1String("login"); }, 5000))
            return false;
        m_client->login(QStringLiteral("admin"), QStringLiteral("password123"));
        return QTest::qWaitFor([this] { return m_client->state() == QLatin1String("ready"); }, 5000);
    }

    static QVariantMap findCard(const QVariantList &list, const QString &id) {
        for (const QVariant &value : list) {
            const QVariantMap card = value.toMap();
            if (card.value("id").toString() == id)
                return card;
        }
        return {};
    }

    StubServer *m_stub = nullptr;
    ServerClient *m_client = nullptr;
};

QTEST_GUILESS_MAIN(TestServerClient)
#include "tst_serverclient.moc"
