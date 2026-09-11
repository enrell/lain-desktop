#pragma once
#include <QByteArray>
#include <QHash>
#include <QJsonObject>
#include <QList>
#include <QObject>
#include <QPair>
#include <QString>
#include <QTcpServer>

class QTcpSocket;
class QUrlQuery;

// Minimal Lain gateway stub. It serves the routes used by the desktop client,
// exposes configurable setup/login/session scenarios, and records requests.
class StubServer : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool setupRequired MEMBER setupRequired)
    Q_PROPERTY(bool failLogin MEMBER failLogin)
    Q_PROPERTY(QString token MEMBER token)
public:
    explicit StubServer(QObject *parent = nullptr);

    bool listen();
    QString baseUrl() const;

    // Scenarios
    bool setupRequired = false;
    bool failLogin = false;
    QString token = QStringLiteral("test-token");
    QString password = QStringLiteral("password123");
    bool paginateOneByOne = false;
    bool failProgress = false;
    quint64 compositionGeneration = 1;
    QStringList metadataOrder = {QStringLiteral("lain-metadata-nfo"),
                                 QStringLiteral("lain-metadata-anilist")};

    // Observations
    QList<QPair<QString, QString>> requests; // method and path without query
    QList<QJsonObject> progressPuts;

    void reset();

private:
    void handleConnection(QTcpSocket *socket);
    void dispatch(QTcpSocket *socket, const QByteArray &request);
    QByteArray route(const QString &method, const QString &path, const QUrlQuery &query,
                     const QByteArray &body, const QJsonObject &headers, int &status);

    QTcpServer m_server;
    QHash<QTcpSocket *, QByteArray> m_buffers;
};
