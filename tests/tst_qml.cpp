#include <QtQuickTest/quicktest.h>
#include <QSettings>
#include <QStandardPaths>
#include <QQmlContext>
#include <QQmlEngine>

#include "LocaleManager.h"
#include "OmarchyTheme.h"
#include "Provisioning.h"
#include "ServerClient.h"
#include "stubserver.h"

// QML test harness: register the Lain module and inject the real ServerClient
// configured against the gateway HTTP stub.
class TestSetup : public QObject {
    Q_OBJECT
public:
    TestSetup() {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("lain-test"));
        QCoreApplication::setApplicationName(QStringLiteral("lain-test"));
        QSettings().clear();
    }

    ~TestSetup() override {
        if (m_locale)
            QCoreApplication::removeTranslator(m_locale);
    }

public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        if (!m_stub) {
            m_stub = new StubServer(this);
            if (!m_stub->listen())
                qWarning("stub server failed to listen");
        }
        if (!m_server) {
            m_server = new ServerClient(this);
            m_server->setServerUrl(m_stub->baseUrl());
        }
        if (!m_theme)
            m_theme = new OmarchyTheme(this);
        if (!m_locale) {
            m_locale = new LocaleManager(this);
            QCoreApplication::installTranslator(m_locale);
        }
        if (!m_provisioning)
            m_provisioning = new Provisioning(this);
        connect(m_locale, &LocaleManager::localeChanged, engine, [engine]() { engine->retranslate(); });

        engine->rootContext()->setContextProperty("server", m_server);
        engine->rootContext()->setContextProperty("omarchy", m_theme);
        engine->rootContext()->setContextProperty("localeManager", m_locale);
        engine->rootContext()->setContextProperty("provisioning", m_provisioning);
        engine->rootContext()->setContextProperty("stub", m_stub);
        engine->rootContext()->setContextProperty("buildTs", QStringLiteral("test"));
        engine->rootContext()->setContextProperty("appVersion", QStringLiteral("test"));

        m_server->start();
    }

private:
    StubServer *m_stub = nullptr;
    ServerClient *m_server = nullptr;
    OmarchyTheme *m_theme = nullptr;
    LocaleManager *m_locale = nullptr;
    Provisioning *m_provisioning = nullptr;
};

QUICK_TEST_MAIN_WITH_SETUP(qmltests, TestSetup)
#include "tst_qml.moc"
