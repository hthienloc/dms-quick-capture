import QtQuick
import qs.Common
import Quickshell
import "components/Helpers.js" as Helpers

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
        { id: "redact", icon: "ad_off", tooltip: qsTr("Redact (R)") },
        { id: "stamp", icon: "looks_one", tooltip: qsTr("Number Stamp (A)") },
        { id: "highlighter", icon: "border_color", tooltip: qsTr("Highlighter (S)") },
        { id: "eraser", icon: "auto_fix_normal", tooltip: qsTr("Eraser (D)") },
        { id: "colorpicker", icon: "colorize", tooltip: qsTr("Color Picker (I)") },
        { id: "spotlight", icon: "highlight", tooltip: qsTr("Focus Spotlight (F)") },
        { id: "callout", icon: "zoom_in", tooltip: qsTr("Area Zoom (Z) | Hold G for Loupe") },
        { id: "backdrop", icon: "wallpaper", tooltip: qsTr("Image Backdrop (B)") }
    ]

    readonly property string selectedPreset: pluginData["color_palette_preset"] || "adaptive"

    readonly property var classicColors: [
        "#3b82f6",
        "#ef4444",
        "#22c55e",
        "#eab308",
        "#a855f7",
        "#ffffff",
        "#000000"
    ]

    readonly property var nordColors: [
        "#88c0d0",
        "#bf616a",
        "#a3be8c",
        "#ebcb8b",
        "#b48ead",
        "#e5e9f0",
        "#2e3440"
    ]

    readonly property var gruvboxColors: [
        "#458588",
        "#cc241d",
        "#98971a",
        "#d79921",
        "#b16286",
        "#ebdbb2",
        "#282828"
    ]

    readonly property var draculaColors: [
        "#8be9fd",
        "#ff5555",
        "#50fa7b",
        "#f1fa8c",
        "#ff79c6",
        "#f8f8f2",
        "#282a36"
    ]

    readonly property var catppuccinMochaColors: [
        "#89b4fa",
        "#f38ba8",
        "#a6e3a1",
        "#f9e2af",
        "#cba6f7",
        "#cdd6f4",
        "#1e1e2e"
    ]

    readonly property var catppuccinMacchiatoColors: [
        "#8aadf4",
        "#ed8796",
        "#a6da95",
        "#eed49f",
        "#c6a0f6",
        "#cad3f5",
        "#24273a"
    ]

    readonly property var catppuccinFrappeColors: [
        "#8caaee",
        "#e78284",
        "#a6d189",
        "#e5c890",
        "#ca9ee6",
        "#c6d0f5",
        "#303446"
    ]

    readonly property var catppuccinLatteColors: [
        "#1e66f5",
        "#d20f39",
        "#40a02b",
        "#df8e1d",
        "#8839ef",
        "#4c4f69",
        "#eff1f5"
    ]

    readonly property string selectedCatppuccinVariant: pluginData["catppuccin_variant"] || "mocha"

    readonly property var adaptiveColors: [
        Theme.info,
        Theme.error,
        Theme.success,
        Theme.warning,
        Theme.secondary,
        Theme.surfaceText,
        Theme.surface
    ]

    readonly property var defaultAccentColors: {
        switch (selectedPreset) {
            case "classic": return classicColors;
            case "nord": return nordColors;
            case "gruvbox": return gruvboxColors;
            case "dracula": return draculaColors;
            case "catppuccin": {
                switch (selectedCatppuccinVariant) {
                    case "latte": return catppuccinLatteColors;
                    case "frappe": return catppuccinFrappeColors;
                    case "macchiato": return catppuccinMacchiatoColors;
                    case "mocha":
                    default:
                        return catppuccinMochaColors;
                }
            }
            case "adaptive":
            default:
                return adaptiveColors;
        }
    }

    readonly property var accentColors: {
        const list = [];
        const isCustom = selectedPreset === "custom";
        for (let i = 0; i < 7; i++) {
            if (isCustom) {
                list.push(pluginData["toolbar_color_" + i] || adaptiveColors[i]);
            } else {
                list.push(defaultAccentColors[i]);
            }
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
        { key: "I", tool: "colorpicker" },
        { key: "F", tool: "spotlight" },
        { key: "Z", tool: "callout" },
        { key: "B", tool: "backdrop" }
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

    function findByKey(items, key) { return Helpers.findByKey(items, key); }

    function resolveColor(rawColor) {
        if (!rawColor) return Theme.primary;
        if (typeof rawColor !== "string") {
            return Qt.color(rawColor);
        }
        let resolved = rawColor;
        if (rawColor === "primary") {
            resolved = Theme.primary;
        } else if (rawColor.indexOf("slot_") === 0) {
            const parts = rawColor.split("_");
            const slotIdx = parseInt(parts[1]) - 1;
            if (slotIdx === 0) {
                const primaryColor = pluginData["toolbar_color_primary"] || "primary";
                resolved = primaryColor === "primary" ? Theme.primary : primaryColor;
            } else if (slotIdx >= 1 && slotIdx <= 7) {
                resolved = accentColors[slotIdx - 1];
            }
        }
        return Qt.color(resolved);
    }

    function formatWatermarkText(pattern) { return Helpers.formatWatermarkText(pattern, Quickshell); }
    readonly property string modalDisplayTarget: pluginData["modalDisplayTarget"] || "focused"
}
