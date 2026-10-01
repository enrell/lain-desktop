import QtQuick
import QtQuick.Layouts
import Lain

// Base for one Settings section: a column of groups. focusAnchor() is the
// Ctrl+K landing: find the row or group with that anchorId and pulse it.
ColumnLayout {
    id: page
    spacing: 0

    function findAnchor(item, anchor) {
        if (!item)
            return null;
        if (item.anchorId !== undefined && item.anchorId === anchor)
            return item;
        var kids = item.children || [];
        for (var i = 0; i < kids.length; ++i) {
            var hit = findAnchor(kids[i], anchor);
            if (hit)
                return hit;
        }
        return null;
    }
    function focusAnchor(anchor) {
        var hit = findAnchor(page, anchor);
        if (hit && hit.pulse)
            hit.pulse();
    }
}
