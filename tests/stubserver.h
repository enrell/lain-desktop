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

// Stub mínimo do gateway Lain para os testes: responde as rotas que o
// cliente desktop usa, com cenas configuráveis (setup pendente, login
// inválido, token expirado) e registra o que chegou.
class StubServer : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool setupRequired MEMBER setupRequired)
    Q_PROPERTY(bool failLogin MEMBER failLogin)
    Q_PROPERTY(QString token MEMBER token)
public:
    explicit StubServer(QObject *parent = nullptr);

    bool listen();
    QString baseUrl() const;

    // Cenas
    bool setupRequired = false;
    bool failLogin = false;
    QString token = QStringLiteral("test-token");
    QString password = QStringLiteral("password123");

    // Observações
    QList<QPair<QString, QString>> requests; // method, path (sem query)
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
