.pragma library

// Metadata lines tolerate missing fields and never leave orphan separators.
function parts(list) {
    var out = [];
    for (var i = 0; i < list.length; ++i) {
        var p = list[i];
        if (p === undefined || p === null)
            continue;
        var s = String(p).trim();
        if (s !== "")
            out.push(s);
    }
    return out;
}

function join(list) {
    return parts(list).join("  ·  ");
}

function cardMeta(m) {
    if (!m)
        return "";
    return join([m.year > 0 ? m.year : "", m.tech ? m.tech.container : "", m.size_human]);
}

function heroMeta(m) {
    if (!m)
        return "";
    // Web mediaSubtitle: SxxEyy | EP n, then year, then kind.
    var detail = "";
    if (m.season > 0 && m.episode > 0)
        detail = "S" + (m.season < 10 ? "0" : "") + m.season + "E" + (m.episode < 10 ? "0" : "") + m.episode;
    else if (m.episode > 0)
        detail = "EP " + m.episode;
    if (m.year > 0)
        detail = join([detail, String(m.year)]);
    if (detail === "" && m.kind)
        detail = m.kind;
    return detail;
}

function searchMeta(m) {
    if (!m)
        return "";
    return join([m.year > 0 ? m.year : "", m.genre, m.library]);
}

function remaining(m) {
    if (!m || m.completed || !m.duration_sec || m.duration_sec <= 0 || m.progress <= 0)
        return "";
    var minutes = Math.max(1, Math.round(m.duration_sec * (1 - m.progress) / 60));
    return minutes + " min restantes";
}
