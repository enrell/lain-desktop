import QtQuick
import QtQuick.Layouts
import Lain
import "../../components"

// Web settings/playback: everything applies on change (the YOU save
// model). Resume/autoplay are DD-031; language follows the account; the
// video effect default and per-type overrides stay on this machine.
SettingsPage {
    id: page

    readonly property var effects: [
        { id: "off", label: qsTr("Off") },
        { id: "anime4k-lite", label: qsTr("Anime4K Lite (no upscale)") },
        { id: "anime4k-a", label: qsTr("Anime4K Mode A") },
        { id: "anime4k-aa", label: qsTr("Anime4K Mode A+A") },
        { id: "anime4k-dog-x2", label: qsTr("Anime4K DoG ×2") }
    ]
    readonly property var typeEffects: [{ id: "default", label: qsTr("Use default") }].concat(effects)
    property int prefsTick: 0
    Connections { target: server; function onPrefsChanged() { page.prefsTick++; } }
    function prefOf(key, fallback) { void prefsTick; return String(server.pref(key, fallback)); }

    Connections {
        target: server
        function onActionFinished(action, ok, message) {
            if (action === "language") {
                if (ok) {
                    languageRow.flash();
                    languageField.error = "";
                } else {
                    languageField.error = message;
                }
            }
        }
    }

    SettingsGroup {
        first: true
        anchorId: "playing"
        title: qsTr("Playing")
        SettingRow {
            id: resumeRow
            label: qsTr("Resume automatically")
            hint: qsTr("Start where you stopped instead of from the beginning.")
            UiSwitch {
                objectName: "autoResumeSwitch"
                label: qsTr("Resume automatically")
                checked: server.autoResume
                onToggled: c => { server.setAutoResume(c); resumeRow.flash(); }
            }
        }
        SettingRow {
            id: autoplayRow
            label: qsTr("Autoplay next episode")
            hint: qsTr("Series can override this from their page.")
            UiSwitch {
                label: qsTr("Autoplay next episode")
                checked: server.autoplayNext
                onToggled: c => { server.setAutoplayNext(c); autoplayRow.flash(); }
            }
        }
        SettingRow {
            id: languageRow
            anchorId: "language"
            label: qsTr("Audio & subtitle language")
            hint: qsTr("Audio in this language keeps subtitles off; otherwise subtitles in it. Follows your account.")
            UiField {
                id: languageField
                fieldWidth: 112
                mono: true
                maximumLength: 3
                placeholder: "auto"
                text: server.me && server.me.preferred_language ? server.me.preferred_language : ""
                onAccepted: server.setPreferredLanguage(text)
                onEditingFinished: {
                    var current = server.me && server.me.preferred_language ? server.me.preferred_language : "";
                    if (text.trim().toLowerCase() !== current)
                        server.setPreferredLanguage(text);
                }
            }
            below: [
                Text {
                    text: qsTr("por · eng · jpn · spa · fra · deu · ita · kor · zho")
                    color: Tokens.textTertiary
                    font.family: Tokens.fontFamily
                    font.pixelSize: 11
                }
            ]
        }
    }

    SettingsGroup {
        anchorId: "effects"
        title: qsTr("Video effects · this computer")
        SettingRow {
            id: effectRow
            label: qsTr("Default effect")
            hint: qsTr("Anime4K through mpv shaders. The player can override it per session.")
            UiSelect {
                implicitWidth: 240
                model: page.effects
                current: page.prefOf("effects/default", "off")
                onPicked: id => { server.setPref("effects/default", id); effectRow.flash(); }
            }
        }
        Repeater {
            model: [
                { type: "anime", label: qsTr("Anime libraries") },
                { type: "movie", label: qsTr("Movie libraries") },
                { type: "series", label: qsTr("Series libraries") }
            ]
            delegate: SettingRow {
                id: typeRow
                required property var modelData
                label: modelData.label
                hint: qsTr("Overrides the default for this library type.")
                UiSelect {
                    implicitWidth: 240
                    model: page.typeEffects
                    current: page.prefOf("effects/type/" + typeRow.modelData.type, "default")
                    onPicked: id => { server.setPref("effects/type/" + typeRow.modelData.type, id); typeRow.flash(); }
                }
            }
        }
    }

    SettingsGroup {
        title: qsTr("Per-series autoplay")
        visible: (server.series || []).length > 0
        Repeater {
            model: server.series || []
            delegate: SettingRow {
                id: seriesRow
                required property var modelData
                label: modelData.displayTitle || modelData.title
                readonly property int files: (modelData.episodeCount || 0) + (modelData.specialsCount || 0)
                hint: files === 1 ? qsTr("1 episode") : qsTr("%1 episodes").arg(files)
                UiSelect {
                    implicitWidth: 160
                    model: [
                        { id: "default", label: qsTr("Default") },
                        { id: "on", label: qsTr("On") },
                        { id: "off", label: qsTr("Off") }
                    ]
                    current: { void server.autoplayNext; return server.seriesAutoplayMode(seriesRow.modelData.id); }
                    onPicked: id => { server.setSeriesAutoplay(seriesRow.modelData.id, id); seriesRow.flash(); }
                }
            }
        }
    }
}
