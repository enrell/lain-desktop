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

    void logoutDropsInFlightLogin() {
        m_client->setServerUrl(m_stub->baseUrl());
        m_client->start();
        QTRY_COMPARE(m_client->state(), QStringLiteral("login"));
        m_client->login(QStringLiteral("admin"), QStringLiteral("password123"));
        m_client->logout(); // before the reply lands
        QTest::qWait(400);
        QCOMPARE(m_client->state(), QStringLiteral("login"));
        QVERIFY(m_client->username().isEmpty());
    }

    // ---- web parity (DD-037)

    void profileUpdatesMeAndDisplayName() {
        QVERIFY(startReadyClient());
        QCOMPARE(m_client->displayName(), QStringLiteral("admin"));
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->updateProfile({{"display_name", QStringLiteral("Lain Iwakura")}, {"bio", QStringLiteral("Present day.")}});
        QTRY_COMPARE(done.size(), 1);
        QCOMPARE(done.at(0).at(0).toString(), QStringLiteral("profile"));
        QVERIFY(done.at(0).at(1).toBool());
        QCOMPARE(m_client->displayName(), QStringLiteral("Lain Iwakura"));
        m_client->updateProfile({{"display_name", QString(41, QLatin1Char('x'))}});
        QTRY_COMPARE(done.size(), 2);
        QVERIFY(!done.at(1).at(1).toBool());
    }

    void avatarMascotUploadAndRemove() {
        QVERIFY(startReadyClient());
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->updateProfile({{"mascot", QStringLiteral("moth")}});
        QTRY_COMPARE(done.size(), 1);
        QCOMPARE(m_client->me().value("profile").toMap().value("avatar").toMap().value("mascot").toString(),
                 QStringLiteral("moth"));
        QVERIFY(m_client->avatarUrl().isEmpty());

        QTemporaryDir dir;
        const QString png = dir.filePath(QStringLiteral("a.png"));
        QFile f(png);
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write(QByteArray::fromHex("89504e470d0a1a0a0000000d49484452000000010000000108060000001f15c489"));
        f.close();
        m_client->uploadAvatar(QUrl::fromLocalFile(png));
        QTRY_COMPARE(done.size(), 2);
        QVERIFY(done.at(1).at(1).toBool());
        QVERIFY(m_client->avatarUrl().contains(QStringLiteral("/api/users/user-admin/avatar")));
        QVERIFY(m_client->avatarUrl().contains(QStringLiteral("token=")));

        m_client->removeAvatar();
        QTRY_COMPARE(done.size(), 3);
        QVERIFY(m_client->avatarUrl().isEmpty());
    }

    void changePasswordRotatesSession() {
        QVERIFY(startReadyClient());
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->changePassword(QStringLiteral("wrong"), QStringLiteral("newpassword1"));
        QTRY_COMPARE(done.size(), 1);
        QVERIFY(!done.at(0).at(1).toBool());
        m_client->changePassword(QStringLiteral("password123"), QStringLiteral("newpassword1"));
        QTRY_COMPARE(done.size(), 2);
        QVERIFY(done.at(1).at(1).toBool());
        QCOMPARE(m_stub->password, QStringLiteral("newpassword1"));
        QCOMPARE(m_client->state(), QStringLiteral("ready"));
    }

    void preferredLanguageValidates() {
        QVERIFY(startReadyClient());
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->setPreferredLanguage(QStringLiteral("pt"));
        QTRY_COMPARE(done.size(), 1);
        QVERIFY(!done.at(0).at(1).toBool());
        m_client->setPreferredLanguage(QStringLiteral("JPN"));
        QTRY_COMPARE(done.size(), 2);
        QCOMPARE(m_client->me().value("preferred_language").toString(), QStringLiteral("jpn"));
    }

    void linkCodeSyncAndList() {
        QVERIFY(startReadyClient());
        m_client->loadLinks();
        QTRY_VERIFY(m_client->linksLoaded());
        QVERIFY(m_client->links().isEmpty());
        QVERIFY(!m_client->linkPinUrl().isEmpty());

        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->submitLinkCode(QStringLiteral("anilist"), QStringLiteral("bad"));
        QTRY_COMPARE(done.size(), 1);
        QVERIFY(done.at(0).at(2).toString().contains(QStringLiteral("rejected")));
        m_client->submitLinkCode(QStringLiteral("anilist"), QStringLiteral("good-code"));
        QTRY_COMPARE(m_client->links().size(), 1);

        m_client->loadList(QString(), QString());
        QTRY_COMPARE(m_client->listEntries().size(), 2);
        m_client->loadList(QStringLiteral("manga"), QString());
        QTRY_COMPARE(m_client->listEntries().size(), 1);
        QVERIFY(!m_client->listLoading());

        m_client->setLinkScrobble(QStringLiteral("anilist"), true);
        QTRY_VERIFY(m_client->links().value(0).toMap().value("scrobble").toBool());
        m_client->unlink(QStringLiteral("anilist"));
        QTRY_VERIFY(m_client->links().isEmpty());
    }

    void integrationsKeepSecretWriteOnly() {
        QVERIFY(startReadyClient());
        m_client->loadIntegrations();
        QTRY_VERIFY(m_client->integrations().contains(QStringLiteral("anilist")));
        m_client->saveIntegrations(QStringLiteral("123"), QStringLiteral("s3cret"));
        QTRY_VERIFY(m_client->integrations().value("anilist").toMap().value("secret_set").toBool());
        QCOMPARE(m_client->integrations().value("anilist").toMap().value("client_id").toString(),
                 QStringLiteral("123"));
    }

    void transcodeSettingsRoundTrip() {
        QVERIFY(startReadyClient());
        m_client->loadTranscodeSettings();
        QTRY_COMPARE(m_client->transcodeSettings().value("crf").toInt(), 23);
        QVERIFY(m_client->transcodeCapabilities().value("hardware").toMap().value("vaapi").toBool());
        QVariantMap next = m_client->transcodeSettings();
        next.insert("crf", 20);
        m_client->saveTranscodeSettings(next);
        QTRY_COMPARE(m_client->transcodeSettings().value("crf").toInt(), 20);
        m_client->loadTranscodeSessions();
        QTRY_COMPARE(m_client->transcodeSessions().size(), 1);
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->cancelTranscodeSession(QStringLiteral("tx-1"));
        QTRY_COMPARE(done.size(), 1);
        QVERIFY(done.at(0).at(1).toBool());
    }

    void browseFoldersListsDirs() {
        QVERIFY(startReadyClient());
        m_client->browseFolders(QString());
        QTRY_COMPARE(m_client->browseResult().value("path").toString(), QStringLiteral("/media"));
        QCOMPARE(m_client->browseResult().value("dirs").toList().size(), 2);
        m_client->browseFolders(QStringLiteral("/media/Anime"));
        QTRY_COMPARE(m_client->browseResult().value("path").toString(), QStringLiteral("/media/Anime"));
        QCOMPARE(m_client->browseResult().value("parent").toString(), QStringLiteral("/media"));
    }

    void deleteFileAndResetProgress() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->catalog().size(), 3);
        QSignalSpy deleted(m_client, &ServerClient::itemDeleted);
        m_client->deleteItemFile(QStringLiteral("movie-1"));
        QTRY_COMPARE(deleted.size(), 1);
        QVERIFY(m_stub->deletedItems.contains(QStringLiteral("movie-1")));

        m_stub->progressPuts.clear();
        m_client->resetProgress(QStringLiteral("show-1"));
        QTRY_COMPARE(m_stub->progressPuts.size(), 1);
        QCOMPARE(m_stub->progressPuts.first().value("position_sec").toDouble(), 0.0);
        QTRY_COMPARE(m_client->progressFor(QStringLiteral("show-1")).value("position_sec").toDouble(), 0.0);
    }

    void readerPagesAndProgress() {
        QVERIFY(startReadyClient());
        m_client->loadReader(QStringLiteral("show-2"));
        QTRY_VERIFY(!m_client->readerLoading());
        QCOMPARE(m_client->readerView().value("pages").toList().size(), 3);
        QCOMPARE(m_client->readerView().value("direction").toString(), QStringLiteral("rtl"));
        QVERIFY(m_client->readerPageUrl(QStringLiteral("show-2"), 1).endsWith(QStringLiteral("/pages/1?token=test-token")));
        m_stub->progressPuts.clear();
        m_client->saveReaderProgress(QStringLiteral("show-2"), 2, 3);
        QTRY_COMPARE(m_stub->progressPuts.size(), 1);
        QCOMPARE(m_stub->progressPuts.first().value("position_sec").toDouble(), 3.0);
        QVERIFY(m_stub->progressPuts.first().value("completed").toBool());
        QVERIFY(m_client->isReadable(QStringLiteral("manga")));
        QVERIFY(!m_client->isReadable(QStringLiteral("video")));
    }

    void userPlaybackLimitsPatch() {
        QVERIFY(startReadyClient());
        QSignalSpy done(m_client, &ServerClient::actionFinished);
        m_client->setUserPlayback(QStringLiteral("user-guest"),
                                  {{"allow_video_transcode", false}, {"max_bitrate_kbps", 4000}});
        QTRY_COMPARE(done.size(), 1);
        QCOMPARE(done.at(0).at(0).toString(), QStringLiteral("user-playback"));
        QVERIFY(done.at(0).at(1).toBool());
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

    void swapProvidersUpdatesComposition() {
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->composition().size(), 2);
        const quint64 before = m_client->composition().first().toMap().value("generation").toULongLong();
        m_client->swapProviders(QStringLiteral("lain.metadata.search@1"),
                                QStringList{"lain-metadata-anilist", "lain-metadata-nfo"});
        QTRY_VERIFY(m_client->adminStatus().contains(QStringLiteral("updated")));
        QCOMPARE(m_client->composition().first().toMap().value("generation").toULongLong(), before + 1);
        QCOMPARE(m_client->composition().first().toMap().value("providers").toStringList(),
                 QStringList({QStringLiteral("lain-metadata-anilist"), QStringLiteral("lain-metadata-nfo")}));
    }

    void autoEnrichFillsMissingOverlays() {
        m_stub->skipEnrichmentFor = QStringLiteral("show-2");
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->shows().size(), 2);
        QTRY_VERIFY(findCard(m_client->shows(), QStringLiteral("show-2"))
                        .value("enriched")
                        .toBool());
        bool posted = false;
        for (const auto &req : m_stub->requests) {
            if (req.first == QLatin1String("POST")
                && req.second == QLatin1String("/api/catalog/show-2/enrich"))
                posted = true;
        }
        QVERIFY(posted);
    }

    void autoEnrichOffSkipsMissingOverlays() {
        m_stub->skipEnrichmentFor = QStringLiteral("show-2");
        m_client->setAutoEnrich(false);
        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->shows().size(), 2);
        QTest::qWait(500);
        QVERIFY(!findCard(m_client->shows(), QStringLiteral("show-2")).value("enriched").toBool());
        for (const auto &req : m_stub->requests)
            QVERIFY(!(req.first == QLatin1String("POST")
                      && req.second == QLatin1String("/api/catalog/show-2/enrich")));
    }

    void queuesFailedProgressAndFlushesClientWins() {        QVERIFY(startReadyClient());
        QTRY_COMPARE(m_client->movies().size(), 1);
        m_stub->progressPuts.clear();
        m_stub->failProgress = true;
        m_client->reportProgress(QStringLiteral("movie-1"), 50.0, 100.0, false);
        QTRY_COMPARE(m_client->pendingProgress(), 1);
        QCOMPARE(m_stub->progressPuts.size(), 0);
        m_stub->failProgress = false;
        m_client->flushProgress();
        QTRY_COMPARE(m_client->pendingProgress(), 0);
        QCOMPARE(m_stub->progressPuts.size(), 1);
        QCOMPARE(m_stub->progressPuts.first().value("position_sec").toDouble(), 50.0);
    }

    void validationRejectsBadInput() {
        QVERIFY(startReadyClient());
        m_client->createUser(QStringLiteral(""), QStringLiteral("short"), QStringLiteral("user"));
        QCOMPARE(m_client->errorMessage().contains(QStringLiteral("8 characters")), true);
        m_client->createLibrary(QStringLiteral(""), QStringLiteral("movie"), QStringLiteral(""));
        QCOMPARE(m_client->errorMessage().contains(QStringLiteral("required")), true);
    }

    void playbackDefaultsPersist() {        QVERIFY(startReadyClient());
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
