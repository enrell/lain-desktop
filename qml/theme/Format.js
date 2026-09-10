.pragma library

// Linhas de metadados tolerantes a dados ausentes: o servidor v0.1 não
// fornece runtime/rating/diretor, então nada de separadores órfãos.
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
    return join([
        m.year > 0 ? m.year : "",
        m.runtime,
        m.rating > 0 ? "★ " + Number(m.rating).toFixed(1) : "",
        m.genre
    ]);
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
