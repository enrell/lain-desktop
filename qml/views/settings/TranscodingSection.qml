import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/transcoding (admin): the server-side conversion policy for
// clients that cannot direct-play (this app always direct-plays through
// mpv). Changes stage locally and apply to new sessions on Save; "Safe
// automatic" stages the web's conservative policy from the real probe.
SettingsPage {
    id: page
    property var draft: ({})
    readonly property var saved: server.transcodeSettings || ({})
    readonly property var caps: server.transcodeCapabilities || ({})
    readonly property bool loaded: Object.keys(saved).length > 0
    readonly property bool dirty: loaded && JSON.stringify(draft) !== JSON.stringify(saved)
    property bool saving: false

    readonly property var presets: ["ultrafast", "superfast", "veryfast", "faster", "fast", "medium", "slow", "slower", "veryslow"]
        .map(p => ({ id: p, label: p }))
    readonly property var codecPresets: [{ id: "", label: qsTr("Use encoder preset") }].concat(presets)
    readonly property var hardwareOrder: ["nvenc", "qsv", "vaapi", "videotoolbox", "amf", "rkmpp", "v4l2m2m"]
    readonly property var readyHardware: hardwareOrder.filter(b => caps.hardware && caps.hardware[b] === true)

    function opts(list) { return list.map(o => ({ id: o[0], label: o[1] })); }
    readonly property var groups: [
        { id: "delivery", title: qsTr("Delivery"), fields: [
            { key: "default_delivery", label: qsTr("Default delivery"), type: "select", options: opts([["hls", qsTr("HLS — playable while preparing")], ["progressive", qsTr("Progressive MP4 — waits for the full file")]]) },
            { key: "hls_segment_container", label: qsTr("HLS segment container"), type: "select", options: opts([["fmp4", qsTr("fMP4 (CMAF) — default")], ["mpegts", qsTr("MPEG-TS — legacy players")]]) },
            { key: "hls_segment_seconds", label: qsTr("HLS segment length (seconds)"), type: "int" },
            { key: "idle_timeout_sec", label: qsTr("Idle timeout (seconds)"), type: "int" },
            { key: "throttle", label: qsTr("Throttle transcodes"), hint: qsTr("Pause ffmpeg once enough is produced ahead of the viewer."), type: "bool" },
            { key: "throttle_ahead_sec", label: qsTr("Produced-ahead budget (seconds)"), type: "int", when: "throttle" },
            { key: "segment_deletion", label: qsTr("Enable segment deletion"), type: "bool" },
            { key: "segment_keep_sec", label: qsTr("Segment keep window (seconds)"), type: "int", when: "segment_deletion" }
        ] },
        { id: "encoding", title: qsTr("Encoding"), fields: [
            { key: "encoder_preset", label: qsTr("Encoder preset"), type: "select", options: presets },
            { key: "crf", label: qsTr("Quality (CRF, lower is better)"), type: "int" },
            { key: "h264_preset", label: qsTr("H.264 preset"), type: "select", options: codecPresets },
            { key: "h264_crf", label: qsTr("H.264 CRF (0 = shared)"), type: "int" },
            { key: "h265_preset", label: qsTr("H.265 preset"), type: "select", options: codecPresets },
            { key: "h265_crf", label: qsTr("H.265 CRF (0 = shared)"), type: "int" },
            { key: "av1_preset", label: qsTr("AV1 preset"), type: "select", options: codecPresets },
            { key: "av1_crf", label: qsTr("AV1 CRF (0 = shared)"), type: "int" },
            { key: "allow_hevc", label: qsTr("Allow HEVC (H.265) output"), type: "bool" },
            { key: "allow_av1", label: qsTr("Allow AV1 output"), type: "bool" },
            { key: "deinterlace", label: qsTr("Deinterlace"), type: "select", options: opts([["auto", qsTr("Auto — deinterlace when detected")], ["off", qsTr("Off")]]) },
            { key: "deinterlace_method", label: qsTr("Deinterlace method"), type: "select", options: opts([["yadif", "yadif"], ["bwdif", qsTr("bwdif — better, when the build has it")]]), when: "deinterlace", equals: "auto" },
            { key: "deinterlace_double_rate", label: qsTr("Deinterlace double rate"), type: "bool", when: "deinterlace", equals: "auto" }
        ] },
        { id: "hardware", title: qsTr("Hardware acceleration"), fields: [
            { key: "hardware_acceleration", label: qsTr("Backend"), hint: qsTr("Only backends that passed the server's encode probe are usable."), type: "select", options: opts([["none", qsTr("None (software)")], ["vaapi", "VAAPI"], ["nvenc", "NVIDIA NVENC"], ["qsv", "Intel Quick Sync"], ["amf", "AMD AMF"], ["v4l2m2m", "V4L2 mem2mem"], ["videotoolbox", "VideoToolbox"], ["rkmpp", "Rockchip RKMPP"]]) },
            { key: "hardware_device", label: qsTr("VA-API device"), type: "text", when: "hardware_acceleration", equals: "vaapi" },
            { key: "hardware_encode", label: qsTr("Use hardware encoding"), type: "bool" },
            { key: "hardware_low_power", label: qsTr("Intel low-power encoder"), type: "bool" },
            { key: "hardware_decode_10bit_hevc", label: qsTr("Decode 10-bit HEVC in hardware"), type: "bool" },
            { key: "hardware_decode_10bit_vp9", label: qsTr("Decode 10-bit VP9 in hardware"), type: "bool" }
        ] },
        { id: "processing", title: qsTr("HDR processing"), fields: [
            { key: "tone_mapping", label: qsTr("Enable tone mapping"), type: "bool" },
            { key: "tone_mapping_algorithm", label: qsTr("Algorithm"), type: "select", when: "tone_mapping", options: opts([["bt2390", qsTr("BT.2390 (needs libplacebo/Vulkan)")], ["hable", "Hable"], ["reinhard", "Reinhard"], ["mobius", "Mobius"], ["clip", "Clip"], ["linear", "Linear"]]) },
            { key: "tone_mapping_mode", label: qsTr("When to apply"), type: "select", when: "tone_mapping", options: opts([["auto", qsTr("Auto — only HDR sources")], ["always", qsTr("Always")], ["never", qsTr("Never (HDR playback stays unavailable)")]]) },
            { key: "tone_mapping_peak_nits", label: qsTr("Nominal peak luminance (nits)"), type: "int", when: "tone_mapping" }
        ] },
        { id: "audio", title: qsTr("Audio & subtitles"), fields: [
            { key: "audio_bitrate_kbps", label: qsTr("Audio bitrate (kbps)"), type: "int" },
            { key: "audio_vbr", label: qsTr("Variable-bitrate audio (AAC VBR)"), type: "bool" },
            { key: "downmix_audio", label: qsTr("Downmix multichannel audio"), type: "bool" },
            { key: "downmix_stereo_algorithm", label: qsTr("Stereo downmix algorithm"), type: "select", when: "downmix_audio", options: opts([["none", qsTr("None — ffmpeg default downmix")], ["nightmode", qsTr("lain nightmode — dialogue lift")]]) },
            { key: "downmix_audio_boost", label: qsTr("Downmix gain (linear)"), type: "number", when: "downmix_audio" },
            { key: "subtitle_mode", label: qsTr("Subtitle handling"), type: "select", options: opts([["auto", qsTr("Auto — extract text, burn image tracks")], ["extract", qsTr("Extract only (reject image tracks)")], ["burn", qsTr("Always burn in")], ["off", qsTr("Off")]]) },
            { key: "allow_subtitle_extraction", label: qsTr("Allow subtitle extraction on the fly"), type: "bool" },
            { key: "fallback_font_enabled", label: qsTr("Enable fallback fonts"), type: "bool" },
            { key: "fallback_font_path", label: qsTr("Burn-in font directory"), type: "text", when: "fallback_font_enabled" },
            { key: "fallback_font_name", label: qsTr("Forced font family"), type: "text", when: "fallback_font_enabled" }
        ] },
        { id: "resources", title: qsTr("Resources"), fields: [
            { key: "thread_count", label: qsTr("Transcoding thread count (0 = auto)"), type: "int" },
            { key: "max_muxing_queue_size", label: qsTr("Max muxing queue size (packets)"), type: "int" },
            { key: "transcode_temp_path", label: qsTr("Transcoding temporary path"), type: "text" },
            { key: "remote_bitrate_limit_kbps", label: qsTr("Remote client bitrate limit (kbps, 0 = unlimited)"), type: "int" },
            { key: "cache_bytes", label: qsTr("Cache budget (bytes)"), type: "int" },
            { key: "queue_size", label: qsTr("Queue size"), type: "int" },
            { key: "max_concurrent", label: qsTr("Max concurrent sessions"), type: "int" },
            { key: "ffmpeg_path", label: qsTr("ffmpeg path"), type: "text" },
            { key: "ffprobe_path", label: qsTr("ffprobe path"), type: "text" }
        ] }
    ]

    function clone(o) { return JSON.parse(JSON.stringify(o || {})); }
    function set(key, value) {
        var next = clone(draft);
        next[key] = value;
        draft = next;
    }
    function shown(f) {
        if (!(f.key in saved) && !(f.key in draft))
            return false;
        if (!f.when)
            return true;
        return f.equals !== undefined ? draft[f.when] === f.equals : draft[f.when] === true;
    }
    // Web applySafeAutomaticPolicy (lib/settings/playback-policy.ts).
    function stageSafeAutomatic() {
        var next = clone(draft);
        next.default_delivery = "hls";
        next.hls_segment_container = "fmp4";
        next.hls_segment_seconds = 6;
        next.throttle = true;
        next.throttle_ahead_sec = 30;
        next.segment_deletion = false;
        next.idle_timeout_sec = 120;
        next.encoder_preset = "veryfast";
        next.crf = 23;
        next.h264_preset = "";
        next.h265_preset = "";
        next.av1_preset = "";
        next.allow_hevc = false;
        next.allow_av1 = false;
        next.thread_count = 0;
        next.subtitle_mode = "auto";
        next.allow_subtitle_extraction = true;
        if (caps.tone_mapping !== undefined)
            next.tone_mapping = caps.tone_mapping;
        next.tone_mapping_mode = "auto";
        next.tone_mapping_algorithm = caps.tone_mapping_bt2390 ? "bt2390" : "hable";
        next.deinterlace = "auto";
        next.deinterlace_method = "yadif";
        next.deinterlace_double_rate = false;
        var hw = readyHardware.length > 0 ? readyHardware[0] : "none";
        next.hardware_acceleration = hw;
        next.hardware_encode = hw !== "none";
        next.hardware_low_power = false;
        next.hardware_decode_10bit_hevc = false;
        next.hardware_decode_10bit_vp9 = false;
        draft = next;
    }

    onSavedChanged: { draft = clone(saved); saving = false; }
    Component.onCompleted: {
        server.loadTranscodeSettings();
        server.loadTranscodeSessions();
    }
    Connections {
        target: server
        function onActionFinished(action) { if (action === "transcode") page.saving = false; }
    }
    Timer {
        interval: 3000
        running: page.visible
        repeat: true
        onTriggered: server.loadTranscodeSessions()
    }

    Text {
        Layout.fillWidth: true
        Layout.maximumWidth: 720
        text: qsTr("How the server converts media for clients that cannot play a file directly. This app always direct-plays through mpv; these settings serve the web and other clients. Changes apply to new sessions.")
        color: Tokens.textTertiary
        font.family: Tokens.fontSans
        font.pixelSize: 13
        wrapMode: Text.WordWrap
    }
    UiSpinner { Layout.topMargin: 24; Layout.alignment: Qt.AlignHCenter; visible: !page.loaded; size: 20 }

    SettingsGroup {
        anchorId: "mode"
        title: qsTr("Mode")
        visible: page.loaded
        SettingRow {
            label: qsTr("Policy")
            hint: qsTr("Stage the conservative automatic policy from the server probe, then review and save.")
            UiButton { text: qsTr("Safe automatic"); icon: "sparkles"; variant: "secondary"; size: "sm"; onClicked: page.stageSafeAutomatic() }
        }
        SettingRow {
            label: qsTr("Video engine")
            hint: qsTr("The first backend that passed the probe is used; failures fall back to software visibly.")
            Text {
                text: String(page.draft.hardware_acceleration && page.draft.hardware_acceleration !== "none" ? page.draft.hardware_acceleration : "software").toUpperCase()
                color: Tokens.textPrimary
                font.family: Tokens.fontFamily
                font.pixelSize: 12
                font.letterSpacing: 1.2
            }
            Repeater {
                model: page.readyHardware.filter(b => b !== page.draft.hardware_acceleration)
                delegate: UiButton {
                    required property string modelData
                    text: qsTr("Use %1").arg(modelData.toUpperCase())
                    variant: "ghost"
                    size: "sm"
                    onClicked: { page.set("hardware_acceleration", modelData); page.set("hardware_encode", true); }
                }
            }
        }
        SettingRow {
            label: qsTr("Probed capabilities")
            hint: qsTr("ffmpeg %1").arg(page.caps.ffmpeg || qsTr("from the system PATH"))
            stack: true
            Flow {
                Layout.fillWidth: true
                spacing: 6
                UiBadge {
                    text: page.caps.tone_mapping ? qsTr("tone mapping available") : qsTr("tone mapping unavailable")
                    tone: page.caps.tone_mapping ? "success" : "danger"
                }
                UiBadge {
                    text: page.caps.tone_mapping_bt2390 ? qsTr("BT.2390 available") : qsTr("BT.2390 falls back to hable")
                    tone: page.caps.tone_mapping_bt2390 ? "success" : "neutral"
                }
                Repeater {
                    model: page.caps.hardware ? Object.keys(page.caps.hardware) : []
                    delegate: UiBadge {
                        required property string modelData
                        text: modelData + " " + (page.caps.hardware[modelData] ? qsTr("ready") : qsTr("not available"))
                        tone: page.caps.hardware[modelData] ? "success" : "neutral"
                    }
                }
                Repeater {
                    model: page.caps.encoders || []
                    delegate: UiBadge { required property string modelData; text: modelData }
                }
            }
        }
    }

    Repeater {
        model: page.loaded ? page.groups : []
        delegate: SettingsGroup {
            id: group
            required property var modelData
            anchorId: modelData.id
            title: modelData.title
            Repeater {
                model: group.modelData.fields
                delegate: SettingRow {
                    id: row
                    required property var modelData
                    visible: page.shown(modelData)
                    label: modelData.label
                    hint: modelData.hint || ""
                    UiSwitch {
                        visible: row.modelData.type === "bool"
                        label: row.modelData.label
                        checked: page.draft[row.modelData.key] === true
                        onToggled: c => page.set(row.modelData.key, c)
                    }
                    UiSelect {
                        visible: row.modelData.type === "select"
                        implicitWidth: 300
                        model: row.modelData.options || []
                        current: page.draft[row.modelData.key] !== undefined ? page.draft[row.modelData.key] : ""
                        onPicked: id => page.set(row.modelData.key, id)
                    }
                    UiField {
                        visible: row.modelData.type === "int" || row.modelData.type === "number" || row.modelData.type === "text"
                        fieldWidth: row.modelData.type === "text" ? 300 : 140
                        mono: true
                        text: page.draft[row.modelData.key] !== undefined ? String(page.draft[row.modelData.key]) : ""
                        onEditingFinished: {
                            var t = row.modelData.type;
                            var v = t === "int" ? (parseInt(text) || 0) : t === "number" ? (parseFloat(text) || 0) : text;
                            if (v !== page.draft[row.modelData.key])
                                page.set(row.modelData.key, v);
                        }
                    }
                }
            }
        }
    }

    SettingsGroup {
        anchorId: "sessions"
        title: qsTr("Active sessions")
        visible: page.loaded
        Text {
            Layout.topMargin: 12
            visible: (server.transcodeSessions || []).length === 0
            text: qsTr("Nothing is being prepared right now.")
            color: Tokens.textTertiary
            font.family: Tokens.fontSans
            font.pixelSize: 13
        }
        Repeater {
            model: server.transcodeSessions || []
            delegate: SettingRow {
                required property var modelData
                label: (modelData.profile || modelData.session) + " · " + (modelData.method || modelData.state)
                hint: [modelData.state,
                       modelData.progress > 0 ? Math.round(modelData.progress * 100) + "%" : "",
                       modelData.fps ? modelData.fps.toFixed(0) + " fps" : "",
                       modelData.encoder || "",
                       modelData.user_id || ""].filter(s => s !== "").join(" · ")
                UiButton {
                    visible: modelData.state === "running" || modelData.state === "queued"
                    text: qsTr("Cancel")
                    variant: "ghost"
                    size: "sm"
                    onClicked: server.cancelTranscodeSession(modelData.session)
                }
            }
        }
    }

    // Staged bar: shown while the draft differs from the server.
    Rectangle {
        Layout.fillWidth: true
        Layout.topMargin: 24
        visible: page.dirty
        implicitHeight: 56
        radius: Tokens.radiusMd
        color: Tokens.bgElevated
        border.color: Qt.alpha(Tokens.themeAccent, 0.4)
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 10
            Text {
                Layout.fillWidth: true
                text: qsTr("Unsaved transcoding changes.")
                color: Tokens.textPrimary
                font.family: Tokens.fontSans
                font.pixelSize: 13
            }
            UiButton { text: qsTr("Discard"); variant: "ghost"; size: "sm"; onClicked: page.draft = page.clone(page.saved) }
            UiButton {
                objectName: "saveTranscode"
                text: qsTr("Save")
                size: "sm"
                loading: page.saving
                onClicked: { page.saving = true; server.saveTranscodeSettings(page.draft); }
            }
        }
    }
}
