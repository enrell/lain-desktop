#include <QGuiApplication>
#include <QDebug>
#include <QIcon>
#include <QLocale>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTranslator>
#include <clocale>
#include "LocaleManager.h"
#include "OmarchyTheme.h"
#include "Provisioning.h"
#include "ServerClient.h"

int main(int argc, char *argv[]) {
    std::setlocale(LC_NUMERIC, "C");
    QGuiApplication app(argc, argv);
    std::setlocale(LC_NUMERIC, "C"); // Qt may restore the environment locale
    qInfo() << "lain build" << LAIN_BUILD_TS;
    app.setApplicationName("lain-desktop");
    app.setApplicationDisplayName("Lain");
    app.setOrganizationName("lain");
    app.setApplicationVersion(QStringLiteral(LAIN_VERSION));
    app.setDesktopFileName("lain-desktop");
    app.setWindowIcon(QIcon(QStringLiteral(":/icons/lain-desktop.png")));

    ServerClient server;
    OmarchyTheme theme;
    LocaleManager localeManager;
    QGuiApplication::installTranslator(&localeManager);
    Provisioning provisioning;
    QQmlApplicationEngine engine;
    QObject::connect(&localeManager, &LocaleManager::localeChanged,
                     &engine, [&engine]() { engine.retranslate(); });
    engine.rootContext()->setContextProperty("server", &server);
    engine.rootContext()->setContextProperty("omarchy", &theme);
    engine.rootContext()->setContextProperty("localeManager", &localeManager);
    engine.rootContext()->setContextProperty("provisioning", &provisioning);
    engine.rootContext()->setContextProperty("buildTs", QStringLiteral(LAIN_BUILD_TS));
    engine.rootContext()->setContextProperty("appVersion", QStringLiteral(LAIN_VERSION));
    server.start();
    engine.loadFromModule("Lain", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}
