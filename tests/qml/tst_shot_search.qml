import QtQuick
import QtTest
import Lain
import "../helpers"

TestCase {
    id: testCase
    name: "ShotSearch"
    visible: true
    width: 1440
    height: 900
    when: windowShown

    ShotHost {
        id: host
        content: viewContent
    }
    Component {
        id: viewContent
        SearchView { width: host.captureWidth }
    }

    function test_search() {
        tryCompare(server, "ready", true, 10000);
        tryVerify(() => server.catalog.length > 0, 10000);
        // Query a title that exists in whichever backend is running —
        // the stub fixture and the real server differ on purpose.
        var term = String(server.catalog[0].title).split(" ")[0];
        host.view.openWith(term);
        tryVerify(() => server.searchResults.length > 0, 10000);
        wait(600);
        grabImage(host).save(shotsDir + "/search.png");
    }
}
