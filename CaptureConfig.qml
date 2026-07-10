import QtQuick
import qs.Common
import Quickshell
import "components/Helpers.js" as Helpers

QtObject {
    property var pluginData: ({})

    readonly property var toolButtons: [
        { id: "pen", icon: "edit", shortcut: "1", tooltip: qsTr("Freehand Pen (1)") },
        { id: "line", icon: "horizontal_rule", shortcut: "2", tooltip: qsTr("Straight Line (2)") },
        { id: "arrow", icon: "trending_flat", shortcut: "3", tooltip: qsTr("Arrow Vector (3)") },
        { id: "rect", icon: "crop_square", shortcut: "4", tooltip: qsTr("Rectangle Outline (4)") },
        { id: "ellipse", icon: "radio_button_unchecked", shortcut: "Q", tooltip: qsTr("Ellipse / Circle (Q)") },
        { id: "text", icon: "text_fields", shortcut: "W", tooltip: qsTr("Text Note (W)") },
        { id: "pixelate", icon: "blur_on", shortcut: "E", tooltip: qsTr("Pixelate (E)") },
        { id: "redact", icon: "ad_off", shortcut: "R", tooltip: qsTr("Redact (R)") },
        { id: "stamp", icon: "looks_one", shortcut: "A", tooltip: qsTr("Number Stamp (A)") },
        { id: "highlighter", icon: "border_color", shortcut: "S", tooltip: qsTr("Highlighter (S)") },
        { id: "spotlight", icon: "highlight", shortcut: "D", tooltip: qsTr("Focus Spotlight (D)") },
        { id: "callout", icon: "zoom_in", shortcut: "Z", tooltip: qsTr("Area Zoom (Z) | Hold G for Loupe") },
        { id: "backdrop", icon: "wallpaper", shortcut: "B", tooltip: qsTr("Image Backdrop (B)") }
    ]

    readonly property string selectedPreset: pluginData["color_palette_preset"] || "adaptive"

    readonly property var classicColors: [
        "#3b82f6", "#ef4444", "#f97316", "#3b82f6",
        "#a855f7", "#dbeafe", "#ffffff", "#000000"
    ]

    // ── Registry-sourced palettes ─────────────────────────────────────────────
    // Color order: [primary, error, warning, info, secondary, primaryContainer, surfaceText, surface]

    readonly property var nordDarkColors: [
        "#81a1c1", "#bf616a", "#d08770", "#88c0d0", "#b48ead", "#88c0d0", "#eceff4", "#3b4252"
    ]
    readonly property var nordLightColors: [
        "#3b6ea8", "#99324b", "#ac4426", "#398eac", "#97365b", "#398eac", "#2e3440", "#c2d0e7"
    ]

    readonly property var draculaDarkColors: [
        "#bd93f9", "#ff5555", "#f1fa8c", "#8be9fd", "#ff79c6", "#7c5ac7", "#f8f8f2", "#21222c"
    ]
    readonly property var draculaLightColors: [
        "#8332f4", "#ff5555", "#f1fa8c", "#8be9fd", "#ff79c6", "#c9a4ff", "#282a36", "#f8f8f2"
    ]

    readonly property var gruvboxMaterialDarkColors: [
        "#a8b665", "#e96962", "#e68a4e", "#d7a657", "#d7a657", "#555c34", "#ddc7a1", "#1b1b1b"
    ]
    readonly property var gruvboxMaterialLightColors: [
        "#6b782e", "#c04a4a", "#c25e0a", "#b37109", "#b37109", "#6f8352", "#4e3829", "#f2e5bc"
    ]

    // Catppuccin — from dms-plugin-registry, mauve accent, semantic mapping
    readonly property var catppuccinMochaColors: [
        "#cba6f7", "#f38ba8", "#fab387", "#89b4fa", "#b4befe", "#55307f", "#cdd6f4", "#181825"
    ]
    readonly property var catppuccinMacchiatoColors: [
        "#c6a0f6", "#ed8796", "#f5a97f", "#8aadf4", "#b7bdf8", "#532f7d", "#cad3f5", "#1e2030"
    ]
    readonly property var catppuccinFrappeColors: [
        "#ca9ee6", "#e78284", "#ef9f76", "#8caaee", "#babbf1", "#542f79", "#c6d0f5", "#292c3c"
    ]
    readonly property var catppuccinLatteColors: [
        "#8839ef", "#d20f39", "#fe640b", "#1e66f5", "#7287fd", "#eadcff", "#4c4f69", "#e6e9ef"
    ]

    readonly property var everforestDarkColors: [
        "#a7c080", "#e57e80", "#e59875", "#dabc7f", "#7fbbb3", "#6c8446", "#d3c6aa", "#232a2e"
    ]
    readonly property var everforestLightColors: [
        "#8ca101", "#f75552", "#f47d26", "#dea000", "#dea000", "#92b259", "#5c6a72", "#efebd4"
    ]

    readonly property var rosePineDarkColors: [
        "#c4a7e7", "#eb6f92", "#f6c177", "#9ccfd8", "#f6c177", "#26233a", "#e0def4", "#1f1d2e"
    ]
    readonly property var rosePineLightColors: [
        "#907aa9", "#b4637a", "#ea9d34", "#56949f", "#ea9d34", "#dfdad9", "#575279", "#f2e9de"
    ]

    readonly property var kanagawaWlDarkColors: [
        "#7fb4ca", "#e82424", "#ff9e3b", "#7fb4ca", "#938aa9", "#223249", "#dcd7ba", "#1f1f28"
    ]
    readonly property var kanagawaWlLightColors: [
        "#c84053", "#c84053", "#dca561", "#658594", "#6f894e", "#e98a9e", "#1f1f28", "#f2ecbc"
    ]

    readonly property var tokyoNightDarkColors: [
        "#7aa2f7", "#f7768e", "#ff9e64", "#7dcfff", "#bb9af7", "#7dcfff", "#73daca", "#1a1b26"
    ]
    readonly property var tokyoNightLightColors: [
        "#2e7de9", "#f52a65", "#b15c00", "#007197", "#9854f1", "#007197", "#387068", "#e1e2e7"
    ]

    readonly property var synthwaveElectricDarkColors: [
        "#FF6600", "#FF3366", "#FFCC00", "#0080FF", "#0080FF", "#CC5200", "#E6F0FF", "#0A0A15"
    ]
    readonly property var synthwaveElectricLightColors: [
        "#CC5200", "#CC1A40", "#CC9900", "#0066CC", "#0066CC", "#FF9966", "#1A1A33", "#FFF8F0"
    ]

    readonly property var dankVioletDarkColors: [
        "#c7b3f3", "#E53935", "#F57C00", "#c7b3f3", "#c7b3f3", "#2A243F", "#E6E1F7", "#1F1F28"
    ]
    readonly property var dankVioletLightColors: [
        "#c7b3f3", "#b00020", "#9c5300", "#7D57D2", "#c7b3f3", "#ece6ff", "#020007", "#f6f4ff"
    ]

    readonly property string registryThemeVariant: pluginData["registry_theme_variant"] || "dark"
    readonly property string selectedCatppuccinFlavor: pluginData["catppuccin_variant"] || "mocha"

    readonly property var adaptiveColors: [
        Theme.error,
        Theme.warning,
        Theme.info,
        Theme.secondary,
        Theme.surfaceContainerHighest,
        Theme.surfaceText,
        Theme.surface
    ]

    readonly property var defaultAccentColors: {
        switch (selectedPreset) {
            case "classic": return classicColors;
            case "nord": return registryThemeVariant === "light" ? nordLightColors : nordDarkColors;
            case "gruvbox": return registryThemeVariant === "light" ? gruvboxMaterialLightColors : gruvboxMaterialDarkColors;
            case "dracula": return registryThemeVariant === "light" ? draculaLightColors : draculaDarkColors;
            case "catppuccin": {
                switch (selectedCatppuccinFlavor) {
                    case "latte": return catppuccinLatteColors;
                    case "frappe": return catppuccinFrappeColors;
                    case "macchiato": return catppuccinMacchiatoColors;
                    case "mocha":
                    default: return catppuccinMochaColors;
                }
            }
            case "everforest": return registryThemeVariant === "light" ? everforestLightColors : everforestDarkColors;
            case "rosePine": return registryThemeVariant === "light" ? rosePineLightColors : rosePineDarkColors;
            case "kanagawaWl": return registryThemeVariant === "light" ? kanagawaWlLightColors : kanagawaWlDarkColors;
            case "tokyoNight": return registryThemeVariant === "light" ? tokyoNightLightColors : tokyoNightDarkColors;
            case "synthwaveElectric": return registryThemeVariant === "light" ? synthwaveElectricLightColors : synthwaveElectricDarkColors;
            case "dankViolet": return registryThemeVariant === "light" ? dankVioletLightColors : dankVioletDarkColors;
            case "adaptive":
            default:
                return adaptiveColors;
        }
    }

    readonly property var accentColors: {
        const list = [];
        const isCustom = selectedPreset === "custom";
        const isAdaptive = selectedPreset === "adaptive";
        for (let i = 0; i < 7; i++) {
            if (isCustom) {
                list.push(pluginData["toolbar_color_" + i] || adaptiveColors[i]);
            } else if (isAdaptive) {
                list.push(defaultAccentColors[i]);
            } else {
                list.push(defaultAccentColors[i + 1]);
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
        { key: "D", tool: "spotlight" },
        { key: "F", tool: "colorpicker" },
        { key: "T", tool: "eraser" },
        { key: "Z", tool: "callout" },
        { key: "B", tool: "backdrop" }
    ]

    readonly property var colorShortcuts: [
        { key: "1", color: selectedPreset === "custom" ? (pluginData["toolbar_color_primary"] || "primary") : (selectedPreset === "adaptive" ? "primary" : defaultAccentColors[0]) },
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
            return rawColor;
        }
        let resolved = rawColor;
        if (rawColor === "primary") {
            resolved = Theme.primary;
        } else if (rawColor.indexOf("slot_") === 0) {
            const parts = rawColor.split("_");
            const slotIdx = parseInt(parts[1]) - 1;
            if (slotIdx === 0) {
                if (selectedPreset === "custom") {
                    const primaryColor = pluginData["toolbar_color_primary"] || "primary";
                    resolved = primaryColor === "primary" ? Theme.primary : primaryColor;
                } else if (selectedPreset === "adaptive") {
                    resolved = Theme.primary;
                } else {
                    resolved = defaultAccentColors[0];
                }
            } else if (slotIdx >= 1 && slotIdx <= 7) {
                resolved = accentColors[slotIdx - 1];
            }
        }
        return typeof resolved === "string" ? Qt.color(resolved) : resolved;
    }

    function formatWatermarkText(pattern) { return Helpers.formatWatermarkText(pattern, Quickshell); }
    readonly property string modalDisplayTarget: pluginData["modalDisplayTarget"] || "focused"
}
