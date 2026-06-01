import QtQuick
import qs.Common

QtObject {
    property var pluginData: ({})

    readonly property var toolButtons: [
        { id: "pen", icon: "edit", tooltip: qsTr("Freehand Pen (1)") },
        { id: "line", icon: "horizontal_rule", tooltip: qsTr("Straight Line (2)") },
        { id: "arrow", icon: "trending_flat", tooltip: qsTr("Arrow Vector (3)") },
        { id: "rect", icon: "crop_square", tooltip: qsTr("Rectangle Outline (4)") },
        { id: "ellipse", icon: "radio_button_unchecked", tooltip: qsTr("Ellipse / Circle (Q)") },
        { id: "text", icon: "text_fields", tooltip: qsTr("Text Note (W)") },
        { id: "pixelate", icon: "blur_on", tooltip: qsTr("Pixelate (E)") },
        { id: "redact", icon: "square", tooltip: qsTr("Redact / Blackout (R)") },
        { id: "stamp", icon: "looks_one", tooltip: qsTr("Number Stamp (A)") },
        { id: "highlighter", icon: "border_color", tooltip: qsTr("Highlighter (S)") },
        { id: "eraser", icon: "auto_fix_normal", tooltip: qsTr("Eraser (D)") }
    ]

    readonly property var defaultAccentColors: [
        Theme.info,
        Theme.error,
        Theme.success,
        Theme.warning,
        Theme.secondary,
        Theme.surfaceText,
        Theme.surface
    ]

    readonly property var accentColors: {
        const list = [];
        for (let i = 0; i < 7; i++) {
            list.push(pluginData["toolbar_color_" + i] || defaultAccentColors[i]);
        }
        return list;
    }

    readonly property var toolShortcuts: [
        { key: "V", tool: "select" },
        { key: "1", tool: "pen" },
        { key: "2", tool: "line" },
        { key: "3", tool: "arrow" },
        { key: "4", tool: "rect" },
        { key: "Q", tool: "ellipse" },
        { key: "W", tool: "text" },
        { key: "E", tool: "pixelate" },
        { key: "R", tool: "redact" },
        { key: "A", tool: "stamp" },
        { key: "S", tool: "highlighter" },
        { key: "D", tool: "eraser" },
        { key: "P", tool: "crop" }
    ]

    readonly property var colorShortcuts: [
        { key: "1", color: pluginData["toolbar_color_primary"] || "primary" },
        { key: "2", color: accentColors[0] },
        { key: "3", color: accentColors[1] },
        { key: "4", color: accentColors[2] },
        { key: "Q", color: accentColors[3] },
        { key: "W", color: accentColors[4] },
        { key: "E", color: accentColors[5] },
        { key: "R", color: accentColors[6] }
    ]

    function findByKey(items, key) {
        if (!items) return null;
        for (var i = 0; i < items.length; i++) {
            if (items[i].key === key) return items[i];
        }
        return null;
    }
}
