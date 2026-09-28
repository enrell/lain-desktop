#include "MpvItem.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QMetaObject>
#include <QOpenGLFramebufferObject>
#include <QOpenGLFunctions>
#include <QStandardPaths>

class MpvRenderer : public QQuickFramebufferObject::Renderer,
                    protected QOpenGLFunctions {
public:
    MpvRenderer(MpvItem *item) : m_item(item) {}
    ~MpvRenderer() override {
        if (m_item->m_ctx)
            mpv_render_context_free(m_item->m_ctx);
    }

    QOpenGLFramebufferObject *createFramebufferObject(
        const QSize &size) override {
        QOpenGLFramebufferObjectFormat fmt;
        fmt.setAttachment(QOpenGLFramebufferObject::Depth);
        return new QOpenGLFramebufferObject(size, fmt);
    }

    void synchronize(QQuickFramebufferObject *) override {
        if (!m_init) {
            initializeOpenGLFunctions();
            mpv_opengl_init_params gl{};
            gl.get_proc_address = [](void *, const char *n) -> void * {
                return reinterpret_cast<void *>(
                    QOpenGLContext::currentContext()->getProcAddress(n));
            };
            mpv_render_param params[] = {
                {MPV_RENDER_PARAM_API_TYPE, (void *)MPV_RENDER_API_TYPE_OPENGL},
                {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl},
                {MPV_RENDER_PARAM_INVALID, nullptr},
            };
            if (m_item->m_mpv
                && mpv_render_context_create(&m_item->m_ctx, m_item->m_mpv,
                                             params) >= 0) {
                mpv_render_context_set_update_callback(
                    m_item->m_ctx,
                    [](void *u) {
                        QMetaObject::invokeMethod(
                            static_cast<MpvRenderer *>(u)->m_item, "update",
                            Qt::QueuedConnection);
                    },
                    this);
            }
            m_init = true;
        }
    }

    void render() override {
        if (!m_item->m_ctx)
            return;
        auto *fbo = framebufferObject();
        mpv_opengl_fbo mpfbo{(int)fbo->handle(), fbo->width(), fbo->height(),
                             0};
        // No flip: Qt Quick samples the FBO as a texture (normal orientation).
        // FLIP_Y is only for the OpenGL default framebuffer. A 1 here shows
        // every video upside down.
        int flip = 0;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_OPENGL_FBO, &mpfbo},
            {MPV_RENDER_PARAM_FLIP_Y, &flip},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        mpv_render_context_render(m_item->m_ctx, params);
    }

private:
    MpvItem *m_item;
    bool m_init = false;
};

MpvItem::MpvItem(QQuickItem *parent) : QQuickFramebufferObject(parent) {
    m_shaderInfo = tr("Anime4K off");
    m_mpv = mpv_create();
    if (!m_mpv) {
        qWarning() << "mpv_create returned null (LC_NUMERIC"
                   << setlocale(LC_NUMERIC, nullptr) << ")";
        m_errorText = tr("mpv could not be created");
        emit errorTextChanged();
        return;
    }
    // Bad options make mpv_initialize fail and leave a dead handle —
    // report each one instead of silently disabling playback.
    for (const auto &opt : {std::pair{"vo", "libmpv"}, std::pair{"hwdec", "auto"},
                            std::pair{"profile", "gpu-hq"}}) {
        const int st = mpv_set_option_string(m_mpv, opt.first, opt.second);
        if (st < 0)
            qWarning() << "mpv option" << opt.first << "rejected:" << mpv_error_string(st);
    }
    const int initStatus = mpv_initialize(m_mpv);
    if (initStatus < 0) {
        qWarning() << "mpv_initialize failed:" << mpv_error_string(initStatus);
        m_errorText = tr("mpv failed to initialize");
        emit errorTextChanged();
        // Keep the handle so commands are safe no-ops; the event thread
        // still exits cleanly via m_running.
    }

    mpv_observe_property(m_mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "duration", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "pause", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "volume", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "speed", MPV_FORMAT_DOUBLE);
    mpv_observe_property(m_mpv, 0, "mute", MPV_FORMAT_FLAG);
    mpv_observe_property(m_mpv, 0, "aid", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, 0, "sid", MPV_FORMAT_INT64);
    mpv_observe_property(m_mpv, 0, "track-list", MPV_FORMAT_NODE);

    m_running = true;
    m_thread = std::thread(&MpvItem::eventLoop, this);
}

MpvItem::~MpvItem() {
    m_running = false;
    if (m_mpv)
        mpv_wakeup(m_mpv);
    if (m_thread.joinable())
        m_thread.join();
    // The renderer owns m_ctx and releases it on the render thread.
    if (m_mpv)
        mpv_terminate_destroy(m_mpv);
    m_mpv = nullptr;
}

QQuickFramebufferObject::Renderer *MpvItem::createRenderer() const {
    return new MpvRenderer(const_cast<MpvItem *>(this));
}

void MpvItem::runCmd(const QStringList &args) {
    if (!m_mpv)
        return;
    std::vector<QByteArray> held;
    std::vector<const char *> ptrs;
    held.reserve(args.size());
    ptrs.reserve(args.size() + 1);
    for (const QString &a : args) {
        held.push_back(a.toUtf8());
        ptrs.push_back(held.back().constData());
    }
    ptrs.push_back(nullptr);
    mpv_command(m_mpv, ptrs.data());
}

void MpvItem::setProp(const QString &name, const QString &value) {
    if (!m_mpv)
        return;
    mpv_set_property_string(m_mpv, name.toUtf8().constData(),
                            value.toUtf8().constData());
}

QVariant MpvItem::nodeToVariant(const mpv_node *node) {
    switch (node->format) {
    case MPV_FORMAT_STRING:
        return QString::fromUtf8(node->u.string);
    case MPV_FORMAT_FLAG:
        return bool(node->u.flag);
    case MPV_FORMAT_INT64:
        return qlonglong(node->u.int64);
    case MPV_FORMAT_DOUBLE:
        return node->u.double_;
    case MPV_FORMAT_NODE_ARRAY: {
        QVariantList list;
        const mpv_node_list *l = node->u.list;
        for (int i = 0; i < l->num; ++i)
            list << nodeToVariant(&l->values[i]);
        return list;
    }
    case MPV_FORMAT_NODE_MAP: {
        QVariantMap map;
        const mpv_node_list *l = node->u.list;
        for (int i = 0; i < l->num; ++i)
            map[QString::fromUtf8(l->keys[i])] = nodeToVariant(&l->values[i]);
        return map;
    }
    default:
        return QVariant();
    }
}

void MpvItem::eventLoop() {
    mpv_handle *mpv = m_mpv;
    while (m_running.load()) {
        mpv_event *ev = mpv_wait_event(mpv, 0.25);
        if (!m_running.load() || !ev || ev->event_id == MPV_EVENT_NONE)
            continue;
        handleEvent(ev);
    }
}

void MpvItem::handleEvent(mpv_event *ev) {
    switch (ev->event_id) {
    case MPV_EVENT_PROPERTY_CHANGE: {
        auto *prop = static_cast<mpv_event_property *>(ev->data);
        const QString name = QString::fromUtf8(prop->name);
        if (prop->format == MPV_FORMAT_DOUBLE) {
            const double v = *static_cast<double *>(prop->data);
            if (name == "time-pos") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_position = v; emit positionChanged(); },
                    Qt::QueuedConnection);
            } else if (name == "duration") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_duration = v; emit durationChanged(); },
                    Qt::QueuedConnection);
            } else if (name == "volume") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_volume = v; emit volumeChanged(); },
                    Qt::QueuedConnection);
            } else if (name == "speed") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_speed = v; emit speedChanged(); },
                    Qt::QueuedConnection);
            }
        } else if (prop->format == MPV_FORMAT_FLAG) {
            const bool v = *static_cast<int *>(prop->data) != 0;
            if (name == "pause") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_paused = v; emit pausedChanged(); },
                    Qt::QueuedConnection);
            } else if (name == "mute") {
                QMetaObject::invokeMethod(
                    this, [this, v] { m_muted = v; emit mutedChanged(); },
                    Qt::QueuedConnection);
            }
        } else if (prop->format == MPV_FORMAT_INT64) {
            const int v = int(*static_cast<int64_t *>(prop->data));
            if (name == "aid" || name == "sid") {
                QMetaObject::invokeMethod(
                    this, [this, v, name] {
                        if (name == "aid")
                            m_audioId = v;
                        else
                            m_subtitleId = v;
                        emit tracksChanged();
                    },
                    Qt::QueuedConnection);
            }
        } else if (prop->format == MPV_FORMAT_NODE
                   && name == "track-list") {
            QVariantList audio, subs;
            const QVariant root =
                nodeToVariant(static_cast<mpv_node *>(prop->data));
            for (const QVariant &e : root.toList()) {
                const QVariantMap t = e.toMap();
                const QString type = t.value("type").toString();
                QVariantMap track{{"id", t.value("id").toInt()},
                                  {"title", t.value("title").toString()},
                                  {"lang", t.value("lang").toString()}};
                if (type == "audio")
                    audio << track;
                else if (type == "sub")
                    subs << track;
            }
            mpv_free_node_contents(static_cast<mpv_node *>(prop->data));
            QMetaObject::invokeMethod(
                this,
                [this, audio, subs] {
                    m_audioTracks = audio;
                    m_subtitleTracks = subs;
                    emit tracksChanged();
                },
                Qt::QueuedConnection);
        }
        break;
    }
    case MPV_EVENT_START_FILE:
    case MPV_EVENT_FILE_LOADED:
        QMetaObject::invokeMethod(
            this,
            [this] {
                m_position = 0.0;
                m_errorText.clear();
                emit positionChanged();
                emit errorTextChanged();
            },
            Qt::QueuedConnection);
        break;
    case MPV_EVENT_END_FILE: {
        auto *ef = static_cast<mpv_event_end_file *>(ev->data);
        const int err = ef ? ef->error : 0;
        const bool failed =
            (ef && ef->reason == MPV_END_FILE_REASON_ERROR) || err != 0;
        const bool eof = ef && ef->reason == MPV_END_FILE_REASON_EOF;
        QMetaObject::invokeMethod(
            this,
            [this, failed, eof, err] {
                m_errorText = failed ? tr("Playback error (%1)").arg(err)
                                     : QString();
                emit errorTextChanged();
                emit endFile(eof);
            },
            Qt::QueuedConnection);
        break;
    }
    case MPV_EVENT_SHUTDOWN:
        m_running = false;
        break;
    default:
        break;
    }
}

void MpvItem::play(const QString &url) {
    if (url.isEmpty())
        return;
    runCmd({"loadfile", url});
}

void MpvItem::playTestPattern() {
    runCmd({"loadfile", "lavfi://testsrc=size=1280x720:rate=30:duration=300"});
}

void MpvItem::stop() {
    runCmd({"stop"});
}

void MpvItem::togglePause() {
    runCmd({"cycle", "pause"});
}

void MpvItem::setPaused(bool p) {
    setProp("pause", p ? "yes" : "no");
}

void MpvItem::seek(double seconds) {
    runCmd({"seek", QString::number(qMax(0.0, seconds), 'f', 2), "absolute"});
}

void MpvItem::seekBy(double delta) {
    runCmd({"seek", QString::number(delta, 'f', 1), "relative"});
}

void MpvItem::setVolume(double v) {
    setProp("volume", QString::number(qBound(0.0, v, 100.0), 'f', 0));
}

void MpvItem::setMuted(bool m) {
    setProp("mute", m ? "yes" : "no");
}

void MpvItem::setSpeed(double v) {
    setProp("speed", QString::number(qBound(0.1, v, 10.0), 'f', 2));
}

void MpvItem::setAudioTrack(int id) {
    setProp("aid", QString::number(id));
}

void MpvItem::setSubtitleTrack(int id) {
    setProp("sid", id < 0 ? "no" : QString::number(id));
}

void MpvItem::cycleAudio() {
    runCmd({"cycle", "audio"});
}

void MpvItem::cycleSubtitle() {
    runCmd({"cycle", "sub"});
}

// Shader resolution order: user-installed pack dir, system install dir,
// then the pack bundled in the QML module resources. mpv reads real
// filesystem paths, so bundled GLSL is materialized into the cache once.
QString MpvItem::findShaderDir() {
    const QString home =
        QStandardPaths::writableLocation(QStandardPaths::HomeLocation);
    const QString user = home + "/.config/lain/shaders";
    if (QDir(user).exists())
        return user;
    if (QDir("/usr/share/lain/shaders").exists())
        return "/usr/share/lain/shaders";
    QDir res(QStringLiteral(":/qt/qml/Lain/shaders"));
    const QStringList packed = res.entryList({"*.glsl"}, QDir::Files);
    if (packed.isEmpty())
        return {};
    const QString cache =
        QStandardPaths::writableLocation(QStandardPaths::CacheLocation)
        + QStringLiteral("/shaders");
    QDir().mkpath(cache);
    for (const QString &f : packed) {
        const QString dest = cache + QLatin1Char('/') + f;
        if (!QFile::exists(dest)
            || QFileInfo(dest).size() != QFileInfo(res.absoluteFilePath(f)).size())
            QFile::copy(res.absoluteFilePath(f), dest);
    }
    return cache;
}

// Preset ids and chain order mirror the web player's effects policy
// (effects-policy.ts + webgl/packs/anime4k.ts): off, Mode A, Mode A+A,
// Lite, and the DoG x2 pipeline. AutoDownscalePre hooks carry WHEN
// clauses, so appending both stays conditional like upstream Ctrl+1/2.
void MpvItem::applyShaderPreset(const QString &name) {
    runCmd({"change-list", "glsl-shaders", "clr", ""});
    static const QMap<QString, QString> labels{
        {"off", QStringLiteral("Off")},
        {"anime4k-a", QStringLiteral("Anime4K Mode A")},
        {"anime4k-aa", QStringLiteral("Anime4K Mode A+A")},
        {"anime4k-lite", QStringLiteral("Anime4K Lite")},
        {"anime4k-dog-x2", QStringLiteral("Anime4K DoG ×2")},
    };
    if (name == "off" || name.isEmpty()) {
        m_shaderInfo = labels.value("off");
        emit shaderChanged();
        return;
    }
    static const QMap<QString, QStringList> chains{
        {"anime4k-a",
         {"Clamp_Highlights", "Restore_CNN_M", "Upscale_CNN_x2_M",
          "AutoDownscalePre_x2", "AutoDownscalePre_x4", "Upscale_CNN_x2_S"}},
        {"anime4k-aa",
         {"Clamp_Highlights", "Restore_CNN_M", "Upscale_CNN_x2_M",
          "Restore_CNN_S", "AutoDownscalePre_x2", "AutoDownscalePre_x4",
          "Upscale_CNN_x2_S"}},
        {"anime4k-lite",
         {"Clamp_Highlights", "Restore_CNN_S", "Deblur_DoG",
          "Darken_VeryFast"}},
        {"anime4k-dog-x2", {"Lain_DoG_x2"}},
    };
    const QString dir = findShaderDir();
    if (dir.isEmpty()) {
        m_shaderInfo = tr("shader directory is missing");
        emit shaderChanged();
        return;
    }
    const QStringList files =
        QDir(dir).entryList({"*.glsl"}, QDir::Files, QDir::Name);
    int applied = 0;
    const int wanted = chains.value(name).size();
    for (const QString &pat : chains.value(name)) {
        for (const QString &f : files) {
            if (f.contains(pat, Qt::CaseInsensitive)) {
                runCmd({"change-list", "glsl-shaders", "append",
                        QDir(dir).absoluteFilePath(f)});
                ++applied;
                break;
            }
        }
    }
    m_shaderInfo = applied > 0
                       ? tr("%1 · %2/%3 shaders")
                             .arg(labels.value(name, name))
                             .arg(applied)
                             .arg(wanted)
                       : tr("no matching shaders in %1").arg(dir);
    emit shaderChanged();
}

void MpvItem::setShaderPreset(const QString &name) {
    // Legacy preset names from the pre-web-parity map still resolve.
    static const QMap<QString, QString> legacy{
        {"fast", "anime4k-lite"},
        {"balanced", "anime4k-a"},
        {"quality", "anime4k-aa"},
    };
    const QString resolved =
        shaderModes().contains(name) ? name : legacy.value(name, "off");
    m_shaderPreset = resolved;
    applyShaderPreset(resolved);
}

void MpvItem::cycleShaderPreset() {
    const QStringList modes = shaderModes();
    const int next = (modes.indexOf(m_shaderPreset) + 1) % modes.size();
    setShaderPreset(modes[next]);
}
