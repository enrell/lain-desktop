#pragma once
#include <QHash>
#include <QTranslator>
#include <QVariantList>

// Application locale: English source with PT-BR dictionary fallback.
// QML keeps English qsTr() sources; PT-BR is served by overriding
// QTranslator::translate(), so no .qm build step is required.
// A handwritten translations/lain_pt_BR.ts mirrors this dictionary
// for external translators and future lrelease use.
class LocaleManager : public QTranslator {
    Q_OBJECT
    Q_PROPERTY(QString selected READ selected WRITE setSelected NOTIFY localeChanged)
    Q_PROPERTY(QString effective READ effective NOTIFY localeChanged)
    Q_PROPERTY(QVariantList available READ available NOTIFY localeChanged)
public:
    explicit LocaleManager(QObject *parent = nullptr);

    QString selected() const { return m_selected; }
    QString effective() const { return m_effective; }
    QVariantList available() const;

    Q_INVOKABLE void setSelected(const QString &locale);

    QString translate(const char *context, const char *sourceText,
                      const char *disambiguation, int n) const override;
    bool isEmpty() const override { return false; }

signals:
    void localeChanged();

private:
    void resolve();
    void loadPt();

    QString m_selected = QStringLiteral("system");
    QString m_effective = QStringLiteral("en");
    QHash<QString, QString> m_dict;
};
