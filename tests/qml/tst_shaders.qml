import QtQuick
import QtTest
import Lain

// DD-035/web parity: the mpv hook presets resolve bundled Anime4K packs.
TestCase {
    name: "ShaderPresets"
    when: windowShown
    width: 800
    height: 600
    visible: true

    Component {
        id: comp
        MpvItem { width: 800; height: 600 }
    }

    function test_bundled_presets_apply() {
        var item = createTemporaryObject(comp, this);
        verify(item);
        verify(item.shaderModes.indexOf("anime4k-dog-x2") >= 0);
        item.setShaderPreset("anime4k-a");
        verify(item.shaderInfo.indexOf("Mode A") >= 0 && item.shaderInfo.indexOf("6/6") >= 0,
               "Mode A applies the full 6-shader chain, got: " + item.shaderInfo);
        item.setShaderPreset("anime4k-lite");
        verify(item.shaderInfo.indexOf("Lite") >= 0 && item.shaderInfo.indexOf("4/4") >= 0,
               "Lite applies 4 shaders, got: " + item.shaderInfo);
        item.setShaderPreset("anime4k-dog-x2");
        verify(item.shaderInfo.indexOf("DoG") >= 0 && item.shaderInfo.indexOf("1/1") >= 0,
               "DoG x2 applies its combined hook file, got: " + item.shaderInfo);
        // Legacy names still resolve (stored settings from older builds).
        item.setShaderPreset("balanced");
        compare(item.shaderPreset, "anime4k-a");
        item.setShaderPreset("off");
        compare(item.shaderPreset, "off");
        compare(item.shaderInfo, "Off");
        item.destroy();
    }
}
