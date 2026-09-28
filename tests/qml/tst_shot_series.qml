import QtQuick
import QtTest
import Lain
import "../helpers"

// Visual QA: series title page (first multi-episode series) with real data.
TestCase {
    id: testCase
    name: "ShotSeries"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    property var pickedSeries: {
        var sl = server.series || [];
        for (var i = 0; i < sl.length; ++i)
            if ((sl[i].episodeCount || 0) + (sl[i].specialsCount || 0) > 1)
                return sl[i];
        return sl.length > 0 ? sl[0] : null;
    }

    ShotHost {
        id: host
        content: viewContent
    }
    Component {
        id: viewContent
        SeriesView {
            width: host.captureWidth
            series: testCase.pickedSeries
        }
    }

    function ensureReady() {
        if (!server.ready)
            tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.series.length > 0, 10000);
    }

    function test_series() {
        ensureReady();
        wait(800);
        grabImage(host).save(shotsDir + "/series.png");
    }
}
