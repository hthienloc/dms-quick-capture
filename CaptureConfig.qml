import QtQuick
import qs.Common
import Quickshell
import "components/core/Constants.js" as Constants
import "components/core/Helpers.js" as Helpers

QtObject {
    id: root

    property var pluginData: ({})

    readonly property var tools: [
        {
            id: "pen",
            icon: "edit",
            shortcut: "1",
            label: I18n.trFor("quickCapture", "Pen")
        },
        {
            id: "line",
            icon: "horizontal_rule",
            shortcut: "2",
            label: I18n.trFor("quickCapture", "Line")
        },
        {
            id: "arrow",
            icon: "trending_flat",
            shortcut: "3",
            label: I18n.trFor("quickCapture", "Arrow")
        },
        {
            id: "rect",
            icon: "crop_square",
            shortcut: "4",
            label: I18n.trFor("quickCapture", "Rectangle")
        },
        {
            id: "ellipse",
            icon: "radio_button_unchecked",
            shortcut: "Q",
            label: I18n.trFor("quickCapture", "Ellipse")
        },
        {
            id: "text",
            icon: "text_fields",
            shortcut: "W",
            label: I18n.trFor("quickCapture", "Text")
        },
        {
            id: "pixelate",
            icon: "blur_on",
            shortcut: "E",
            label: I18n.trFor("quickCapture", "Pixelate")
        },
        {
            id: "redact",
            icon: "ad_off",
            shortcut: "R",
            label: I18n.trFor("quickCapture", "Redact")
        },
        {
            id: "stamp",
            icon: "looks_one",
            shortcut: "A",
            label: I18n.trFor("quickCapture", "Stamp")
        },
        {
            id: "highlighter",
            icon: "border_color",
            shortcut: "S",
            label: I18n.trFor("quickCapture", "Highlighter")
        },
        {
            id: "spotlight",
            icon: "highlight",
            shortcut: "D",
            label: I18n.trFor("quickCapture", "Spotlight")
        },
        {
            id: "callout",
            icon: "zoom_in",
            shortcut: "Z",
            label: I18n.trFor("quickCapture", "Callout"),
            hint: I18n.trFor("quickCapture", "Hold %1 for Loupe").arg("G")
        },
        {
            id: "background",
            icon: "wallpaper",
            shortcut: "B",
            label: I18n.trFor("quickCapture", "Background")
        },
        {
            id: "colorpicker",
            icon: "colorize",
            shortcut: "F",
            label: I18n.trFor("quickCapture", "Color Picker"),
            toolbar: false
        },
        {
            id: "eraser",
            icon: "auto_fix_normal",
            shortcut: "T",
            label: I18n.trFor("quickCapture", "Eraser"),
            toolbar: false
        },
        {
            id: "select",
            icon: "near_me",
            shortcut: "V",
            label: I18n.trFor("quickCapture", "Select"),
            toolbar: false
        },
        {
            id: "crop",
            icon: "crop",
            shortcut: "",
            label: I18n.trFor("quickCapture", "Crop / Resize"),
            toolbar: false
        }
    ]

    readonly property var toolButtons: tools.filter(t => t.toolbar !== false).map(t => Object.assign({
            tooltip: toolTooltip(t)
        }, t))

    readonly property var startingToolIds: ["pen", "line", "arrow", "rect", "ellipse", "text", "pixelate", "redact", "stamp", "highlighter", "eraser", "crop"]
    readonly property var presetToolIds: ["pen", "line", "arrow", "rect", "ellipse", "text", "pixelate", "redact", "stamp", "highlighter", "eraser", "crop", "spotlight", "callout"]

    readonly property var captureModes: [
        {
            value: "region",
            icon: "screenshot_region",
            label: I18n.trFor("quickCapture", "Region")
        },
        {
            value: "full",
            icon: "fullscreen",
            label: I18n.trFor("quickCapture", "Fullscreen")
        },
        {
            value: "window",
            icon: "crop_square",
            label: I18n.trFor("quickCapture", "Window")
        },
        {
            value: "last",
            icon: "restart_alt",
            label: I18n.trFor("quickCapture", "Last Region")
        },
        {
            value: "scroll",
            icon: "unfold_more",
            label: I18n.trFor("quickCapture", "Scrolling")
        },
        {
            value: "all",
            icon: "grid_view",
            label: I18n.trFor("quickCapture", "All Outputs")
        },
        {
            value: "output",
            icon: "display_settings",
            label: I18n.trFor("quickCapture", "Specific Output")
        },
        {
            value: "clipboard",
            icon: "content_paste",
            label: I18n.trFor("quickCapture", "Clipboard")
        },
        {
            value: "selectFile",
            icon: "folder_open",
            label: I18n.trFor("quickCapture", "File")
        }
    ]

    readonly property var recordModes: [
        {
            value: "region",
            icon: "screenshot_region",
            label: I18n.trFor("quickCapture", "Region")
        },
        {
            value: "screen",
            icon: "fullscreen",
            label: I18n.trFor("quickCapture", "Fullscreen")
        },
        {
            value: "portal",
            icon: "crop_square",
            label: I18n.trFor("quickCapture", "Window")
        }
    ]

    function screenOptions(leading) {
        const list = leading.slice();
        for (const scr of Quickshell.screens ?? []) {
            if (!scr?.name)
                continue;
            list.push({
                label: scr.name + " (" + scr.width + "×" + scr.height + ")",
                value: scr.name
            });
        }
        return list;
    }

    function modesFor(values) {
        return captureModes.filter(m => values.includes(m.value));
    }

    function captureModeLabel(value) {
        return captureModes.find(m => m.value === value)?.label ?? value;
    }

    function toolById(toolId) {
        return tools.find(t => t.id === toolId) ?? null;
    }

    function toolTooltip(tool) {
        const key = tool.shortcut ? tool.label + " (" + tool.shortcut + ")" : tool.label;
        return tool.hint ? key + " · " + tool.hint : key;
    }

    function getToolIcon(toolId) {
        return toolById(toolId)?.icon ?? "help";
    }

    function getToolLabel(toolId) {
        return toolById(toolId)?.label ?? "";
    }

    function toolOptions(ids) {
        return ids.map(id => ({
                    label: getToolLabel(id),
                    value: id
                }));
    }

    function toolMetricLabel(toolId) {
        switch (toolId) {
        case "stamp":
            return I18n.trFor("quickCapture", "Stamp Size");
        case "text":
            return I18n.trFor("quickCapture", "Font Size");
        case "pixelate":
            return I18n.trFor("quickCapture", "Pixelate Intensity");
        case "spotlight":
            return I18n.trFor("quickCapture", "Spotlight Opacity");
        case "callout":
            return I18n.trFor("quickCapture", "Callout Zoom");
        default:
            return I18n.trFor("quickCapture", "Thickness");
        }
    }

    readonly property var toolShortcuts: tools.filter(t => t.shortcut !== "").map(t => ({
                key: t.shortcut,
                tool: t.id
            })).concat([
        {
            key: "I",
            tool: "insert_image"
        },
        {
            key: "M",
            tool: "watermark"
        }
    ])

    function presetTool(index) {
        return pluginData["preset_" + index + "_tool"] ?? Constants.defaultRadialTools[index] ?? "none";
    }

    function presetColor(index) {
        return pluginData["preset_" + index + "_color"] ?? Constants.defaultRadialColors[index];
    }

    function presetThickness(index) {
        return pluginData["preset_" + index + "_thickness"] ?? Constants.getToolMeta(presetTool(index)).defaultValue;
    }

    readonly property string selectedPreset: pluginData["color_palette_preset"] || "adaptive"
    readonly property string registryThemeVariant: pluginData["registry_theme_variant"] || "dark"
    readonly property string selectedCatppuccinFlavor: pluginData["catppuccin_variant"] || "mocha"

    readonly property var classicColors: ["#3b82f6", "#ef4444", "#f97316", "#3b82f6", "#a855f7", "#dbeafe", "#ffffff", "#000000"]

    // Registry palettes, color order: primary, error, warning, info, secondary, primaryContainer, surfaceText, surface
    readonly property var registryPalettes: ({
            nord: {
                dark: ["#81a1c1", "#bf616a", "#d08770", "#88c0d0", "#b48ead", "#88c0d0", "#eceff4", "#3b4252"],
                light: ["#3b6ea8", "#99324b", "#ac4426", "#398eac", "#97365b", "#398eac", "#2e3440", "#c2d0e7"]
            },
            dracula: {
                dark: ["#bd93f9", "#ff5555", "#f1fa8c", "#8be9fd", "#ff79c6", "#7c5ac7", "#f8f8f2", "#21222c"],
                light: ["#8332f4", "#ff5555", "#f1fa8c", "#8be9fd", "#ff79c6", "#c9a4ff", "#282a36", "#f8f8f2"]
            },
            gruvbox: {
                dark: ["#a8b665", "#e96962", "#e68a4e", "#d7a657", "#d7a657", "#555c34", "#ddc7a1", "#1b1b1b"],
                light: ["#6b782e", "#c04a4a", "#c25e0a", "#b37109", "#b37109", "#6f8352", "#4e3829", "#f2e5bc"]
            },
            everforest: {
                dark: ["#a7c080", "#e57e80", "#e59875", "#dabc7f", "#7fbbb3", "#6c8446", "#d3c6aa", "#232a2e"],
                light: ["#8ca101", "#f75552", "#f47d26", "#dea000", "#dea000", "#92b259", "#5c6a72", "#efebd4"]
            },
            rosePine: {
                dark: ["#c4a7e7", "#eb6f92", "#f6c177", "#9ccfd8", "#f6c177", "#26233a", "#e0def4", "#1f1d2e"],
                light: ["#907aa9", "#b4637a", "#ea9d34", "#56949f", "#ea9d34", "#dfdad9", "#575279", "#f2e9de"]
            },
            kanagawaWl: {
                dark: ["#7fb4ca", "#e82424", "#ff9e3b", "#7fb4ca", "#938aa9", "#223249", "#dcd7ba", "#1f1f28"],
                light: ["#c84053", "#c84053", "#dca561", "#658594", "#6f894e", "#e98a9e", "#1f1f28", "#f2ecbc"]
            },
            tokyoNight: {
                dark: ["#7aa2f7", "#f7768e", "#ff9e64", "#7dcfff", "#bb9af7", "#7dcfff", "#73daca", "#1a1b26"],
                light: ["#2e7de9", "#f52a65", "#b15c00", "#007197", "#9854f1", "#007197", "#387068", "#e1e2e7"]
            },
            synthwaveElectric: {
                dark: ["#FF6600", "#FF3366", "#FFCC00", "#0080FF", "#0080FF", "#CC5200", "#E6F0FF", "#0A0A15"],
                light: ["#CC5200", "#CC1A40", "#CC9900", "#0066CC", "#0066CC", "#FF9966", "#1A1A33", "#FFF8F0"]
            },
            dankViolet: {
                dark: ["#c7b3f3", "#E53935", "#F57C00", "#c7b3f3", "#c7b3f3", "#2A243F", "#E6E1F7", "#1F1F28"],
                light: ["#c7b3f3", "#b00020", "#9c5300", "#7D57D2", "#c7b3f3", "#ece6ff", "#020007", "#f6f4ff"]
            }
        })

    readonly property var catppuccinFlavors: ({
            mocha: ["#cba6f7", "#f38ba8", "#fab387", "#89b4fa", "#b4befe", "#55307f", "#cdd6f4", "#181825"],
            macchiato: ["#c6a0f6", "#ed8796", "#f5a97f", "#8aadf4", "#b7bdf8", "#532f7d", "#cad3f5", "#1e2030"],
            frappe: ["#ca9ee6", "#e78284", "#ef9f76", "#8caaee", "#babbf1", "#542f79", "#c6d0f5", "#292c3c"],
            latte: ["#8839ef", "#d20f39", "#fe640b", "#1e66f5", "#7287fd", "#eadcff", "#4c4f69", "#e6e9ef"]
        })

    readonly property var adaptiveColors: [Theme.error, Theme.warning, Theme.info, Theme.secondary, Theme.surfaceContainerHighest, Theme.surfaceText, Theme.surface]

    readonly property var defaultAccentColors: {
        if (selectedPreset === "classic")
            return classicColors;
        if (selectedPreset === "catppuccin")
            return catppuccinFlavors[selectedCatppuccinFlavor] ?? catppuccinFlavors.mocha;
        const palette = registryPalettes[selectedPreset];
        if (!palette)
            return adaptiveColors;
        return registryThemeVariant === "light" ? palette.light : palette.dark;
    }

    readonly property var accentColors: {
        const list = [];
        for (let i = 0; i < 7; i++) {
            if (selectedPreset === "custom")
                list.push(pluginData["toolbar_color_" + i] || adaptiveColors[i]);
            else if (selectedPreset === "adaptive")
                list.push(defaultAccentColors[i]);
            else
                list.push(defaultAccentColors[i + 1]);
        }
        return list;
    }

    readonly property var primarySlotColor: {
        if (selectedPreset === "custom")
            return pluginData["toolbar_color_primary"] || "primary";
        if (selectedPreset === "adaptive")
            return "primary";
        return defaultAccentColors[0];
    }

    readonly property var slotColors: [resolveColor(primarySlotColor)].concat(accentColors.map(c => resolveColor(c)))

    readonly property var colorShortcuts: ["1", "2", "3", "4", "Q", "W", "E", "R"].map((key, i) => ({
                key: key,
                color: i === 0 ? primarySlotColor : accentColors[i - 1]
            }))

    function resolveColor(rawColor) {
        if (!rawColor)
            return Theme.primary;
        if (typeof rawColor !== "string")
            return rawColor;
        if (rawColor === "primary")
            return Theme.primary;
        if (rawColor.indexOf("slot_") !== 0)
            return Qt.color(rawColor);
        const slotIdx = parseInt(rawColor.split("_")[1]) - 1;
        if (slotIdx === 0)
            return resolveColor(primarySlotColor);
        if (slotIdx >= 1 && slotIdx <= 7)
            return resolveColor(accentColors[slotIdx - 1]);
        return Theme.primary;
    }

    function formatWatermarkText(pattern) {
        return Helpers.formatWatermarkText(pattern, Quickshell);
    }

    readonly property string modalDisplayMode: pluginData["modalDisplayMode"] || "floating"
    readonly property string modalDisplayTarget: pluginData["modalDisplayTarget"] || "focused"
    readonly property string modalAspectRatio: pluginData["modalAspectRatio"] || "landscape"
}
