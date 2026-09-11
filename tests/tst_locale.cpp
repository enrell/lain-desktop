#include <QtTest>
#include <QSettings>
#include <QStandardPaths>

#include "LocaleManager.h"

// Locale selection, persistence, and PT-BR dictionary coverage.
// Runs offscreen through ctest without any translators installed.
// PT-BR literals below are intentional localization expectations.

// Locale selection, persistence, and PT-BR dictionary coverage.
// Runs offscreen through ctest without any translators installed.
class TestLocale : public QObject {
    Q_OBJECT
private slots:
    void initTestCase() {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("lain-test"));
        QCoreApplication::setApplicationName(QStringLiteral("lain-test"));
    }

    void init() {
        QSettings().clear();
        QSettings().sync();
    }

    void cleanup() {
        QSettings().clear();
        QSettings().sync();
    }

    void offersSystemEnglishAndBrazilianPortuguese() {
        LocaleManager locale;
        const QVariantList options = locale.available();
        QCOMPARE(options.size(), 3);
        QCOMPARE(options.at(0).toMap().value("id").toString(), QStringLiteral("system"));
        QCOMPARE(options.at(1).toMap().value("id").toString(), QStringLiteral("en"));
        QCOMPARE(options.at(2).toMap().value("id").toString(), QStringLiteral("pt_BR"));
    }

    void englishReturnsSources() {
        LocaleManager locale;
        locale.setSelected(QStringLiteral("en"));
        QCOMPARE(locale.effective(), QStringLiteral("en"));
        QVERIFY(locale.translate(nullptr, "Settings", nullptr, -1).isEmpty());
        QVERIFY(locale.translate(nullptr, "Movies", nullptr, -1).isEmpty());
    }

    void brazilianPortugueseTranslatesCoreStrings() {
        LocaleManager locale;
        locale.setSelected(QStringLiteral("pt_BR"));
        QCOMPARE(locale.effective(), QStringLiteral("pt_BR"));
        QCOMPARE(locale.translate(nullptr, "Settings", nullptr, -1), QStringLiteral("Configurações"));
        QCOMPARE(locale.translate(nullptr, "Movies", nullptr, -1), QStringLiteral("Filmes"));
        QCOMPARE(locale.translate(nullptr, "Shows", nullptr, -1), QStringLiteral("Séries"));
        QCOMPARE(locale.translate(nullptr, "Server", nullptr, -1), QStringLiteral("Servidor"));
        QCOMPARE(locale.translate(nullptr, "Sign in", nullptr, -1), QStringLiteral("Entrar"));
        QCOMPARE(locale.translate(nullptr, "Invalid username or password.", nullptr, -1),
                 QStringLiteral("Usuário ou senha inválidos."));
        QCOMPARE(locale.translate(nullptr, "1 title", nullptr, -1), QStringLiteral("1 título"));
        QCOMPARE(locale.translate(nullptr, "%1 titles", nullptr, -1), QStringLiteral("%1 títulos"));
    }

    void normalizesVariantSpellings() {
        LocaleManager locale;
        locale.setSelected(QStringLiteral("pt-BR"));
        QCOMPARE(locale.effective(), QStringLiteral("pt_BR"));
        locale.setSelected(QStringLiteral("pt"));
        QCOMPARE(locale.effective(), QStringLiteral("pt_BR"));
    }

    void persistsSelection() {
        {
            LocaleManager locale;
            locale.setSelected(QStringLiteral("pt_BR"));
        }
        LocaleManager reloaded;
        QCOMPARE(reloaded.selected(), QStringLiteral("pt_BR"));
        QCOMPARE(reloaded.effective(), QStringLiteral("pt_BR"));
    }
};

QTEST_GUILESS_MAIN(TestLocale)
#include "tst_locale.moc"
