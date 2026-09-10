#include <QtQuickTest/quicktest.h>
#include <QSettings>
#include <QStandardPaths>
#include <QQmlContext>
#include <QQmlEngine>

#include "OmarchyTheme.h"
#include "ServerClient.h"
#include "stubserver.h"

// Harness dos testes de QML: registra o módulo "Lain" e injeta o
// ServerClient real apontando para o stub HTTP do gateway.
class TestSetup : public QObject {
    Q_OBJECT
public:
    TestSetup() {
        QStandardPaths::setTestModeEnabled(true);
        QCoreApplication::setOrganizationName(QStringLiteral("lain-test"));
        QCoreApplication::setApplicationName(QStringLiteral("lain-test"));
        QSettings().clear();
    }

public slots:
    void qmlEngineAvailable(QQmlEngine *engine) {
        m_stub = new StubServer(this);
        if (!m_stub->listen())
            qWarning("stub server failed to listen");
        m_server = new ServerClient(this);
        m_server->setServerUrl(m_stub->baseUrl());
        m_theme = new OmarchyTheme(this);

        engine->rootContext()->setContextProperty("server", m_server);
        engine->rootContext()->setContextProperty("omarchy", m_theme);
        engine->rootContext()->setContextProperty("stub", m_stub);
        engine->rootContext()->setContextProperty("buildTs", QStringLiteral("test"));

        m_server->start();
    }

private:
    StubServer *m_stub = nullptr;
    ServerClient *m_server = nullptr;
    OmarchyTheme *m_theme = nullptr;
};

QUICK_TEST_MAIN_WITH_SETUP(qmltests, TestSetup)
#include "tst_qml.moc"
