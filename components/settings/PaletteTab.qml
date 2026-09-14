import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property bool customPalette: palettePreset.value === "custom"
    readonly property bool registryPalette: !["adaptive", "classic", "custom", "catppuccin"].includes(palettePreset.value)

    function slotOverride(index) {
        if (root.customPalette)
            return null;
        if (palettePreset.value !== "adaptive")
            return root.config.defaultAccentColors[index];
        return index === 0 ? Theme.primary : root.config.adaptiveColors[index - 1];
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Toolbar Palette")
        icon: "palette"

        InfoText {
            text: I18n.trFor("quickCapture", "Pick a palette preset or customize individual color slots.")
        }

        SelectionSettingPlus {
            id: palettePreset
            settingKey: "color_palette_preset"
            label: I18n.trFor("quickCapture", "Palette Preset")
            defaultValue: Defaults.values.color_palette_preset
            options: [
                {
                    label: I18n.trFor("quickCapture", "Adaptive"),
                    value: "adaptive"
                },
                {
                    label: "Classic (Tailwind)",
                    value: "classic"
                },
                {
                    label: "Nord",
                    value: "nord"
                },
                {
                    label: "Dracula",
                    value: "dracula"
                },
                {
                    label: "Gruvbox Material",
                    value: "gruvbox"
                },
                {
                    label: "Catppuccin",
                    value: "catppuccin"
                },
                {
                    label: "Everforest",
                    value: "everforest"
                },
                {
                    label: "Rosé Pine",
                    value: "rosePine"
                },
                {
                    label: "Kanagawa",
                    value: "kanagawaWl"
                },
                {
                    label: "Tokyo Night",
                    value: "tokyoNight"
                },
                {
                    label: "Synthwave Electric",
                    value: "synthwaveElectric"
                },
                {
                    label: "Dank Violet",
                    value: "dankViolet"
                },
                {
                    label: I18n.trFor("quickCapture", "Custom"),
                    value: "custom"
                }
            ]
        }

        ButtonGroupSettingPlus {
            visible: root.registryPalette
            settingKey: "registry_theme_variant"
            label: I18n.trFor("quickCapture", "Variant")
            defaultValue: Defaults.values.registry_theme_variant
            options: [
                {
                    label: I18n.trFor("quickCapture", "Dark"),
                    value: "dark"
                },
                {
                    label: I18n.trFor("quickCapture", "Light"),
                    value: "light"
                }
            ]
        }

        ButtonGroupSettingPlus {
            visible: palettePreset.value === "catppuccin"
            settingKey: "catppuccin_variant"
            label: I18n.trFor("quickCapture", "Variant")
            defaultValue: Defaults.values.catppuccin_variant
            options: [
                {
                    label: "Latte",
                    value: "latte"
                },
                {
                    label: "Frappé",
                    value: "frappe"
                },
                {
                    label: "Macchiato",
                    value: "macchiato"
                },
                {
                    label: "Mocha",
                    value: "mocha"
                }
            ]
        }

        Separator {}

        Grid {
            width: parent.width
            columns: 4
            rowSpacing: Theme.spacingM
            columnSpacing: Theme.spacingM

            Repeater {
                model: 8

                delegate: CompactColorSetting {
                    required property int index
                    settingKey: index === 0 ? "toolbar_color_primary" : "toolbar_color_" + (index - 1)
                    label: I18n.trFor("quickCapture", "Slot %1").arg(index + 1)
                    defaultValue: index === 0 ? "primary" : root.config.adaptiveColors[index - 1]
                    readOnly: !root.customPalette
                    overrideColor: root.slotOverride(index)
                }
            }
        }
    }
}
