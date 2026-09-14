import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    SettingsSection {
        title: I18n.trFor("quickCapture", "Float Window")
        icon: "open_in_new"

        ToggleSettingPlus {
            id: autoMinimize
            settingKey: "autoMinimize"
            label: I18n.trFor("quickCapture", "Auto-minimize")
            description: I18n.trFor("quickCapture", "Automatically minimize the float window after a delay")
            defaultValue: Defaults.values.autoMinimize
        }

        SettingsGroup {
            visible: autoMinimize.value

            SliderSettingPlus {
                settingKey: "minimizeDelay"
                label: I18n.trFor("quickCapture", "Minimize Delay")
                defaultValue: Defaults.values.minimizeDelay
                minimum: 500
                maximum: 10000
                unit: "ms"
                leftLabel: "500"
                rightLabel: "10000"
            }
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "initialWidth"
            label: I18n.trFor("quickCapture", "Initial Width")
            defaultValue: Defaults.values.initialWidth
            minimum: 100
            maximum: 2000
            unit: "px"
            leftLabel: "100"
            rightLabel: "2000"
        }

        SliderSettingPlus {
            settingKey: "maxHeight"
            label: I18n.trFor("quickCapture", "Max Height (%1 = no limit)").arg(0)
            defaultValue: Defaults.values.maxHeight
            minimum: 0
            maximum: 2000
            unit: "px"
            leftLabel: "0"
            rightLabel: "2000"
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "borderWidth"
            label: I18n.trFor("quickCapture", "Border Width")
            defaultValue: Defaults.values.borderWidth
            minimum: 0
            maximum: 20
            unit: "px"
            leftLabel: "0"
            rightLabel: "20"
        }

        SelectionSettingPlus {
            settingKey: "borderColor"
            label: I18n.trFor("quickCapture", "Border Color")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Outline Variant"),
                    value: "outlineVariant"
                },
                {
                    label: I18n.trFor("quickCapture", "Primary"),
                    value: "primary"
                },
                {
                    label: I18n.trFor("quickCapture", "Surface Container Highest"),
                    value: "surfaceContainerHighest"
                },
                {
                    label: I18n.trFor("quickCapture", "Transparent"),
                    value: "transparent"
                }
            ]
            defaultValue: Defaults.values.borderColor
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "transparentBg"
            label: I18n.trFor("quickCapture", "Transparent Background")
            description: I18n.trFor("quickCapture", "Show only the image on a transparent background")
            defaultValue: Defaults.values.transparentBg
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "spawnPosition"
            label: I18n.trFor("quickCapture", "Spawn Position")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Bottom Left"),
                    value: "bottom-left"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Right"),
                    value: "bottom-right"
                },
                {
                    label: I18n.trFor("quickCapture", "Top Left"),
                    value: "top-left"
                },
                {
                    label: I18n.trFor("quickCapture", "Top Right"),
                    value: "top-right"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom"),
                    value: "bottom"
                },
                {
                    label: I18n.trFor("quickCapture", "Top"),
                    value: "top"
                },
                {
                    label: I18n.trFor("quickCapture", "Left"),
                    value: "left"
                },
                {
                    label: I18n.trFor("quickCapture", "Right"),
                    value: "right"
                },
                {
                    label: I18n.trFor("quickCapture", "Center"),
                    value: "center"
                }
            ]
            defaultValue: Defaults.values.spawnPosition
        }

        SliderSettingPlus {
            settingKey: "edgeSpacing"
            label: I18n.trFor("quickCapture", "Edge Spacing")
            defaultValue: Defaults.values.edgeSpacing
            minimum: 0
            maximum: 100
            unit: "px"
            leftLabel: "0"
            rightLabel: "100"
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "autoTiling"
            label: I18n.trFor("quickCapture", "Auto-tiling")
            description: I18n.trFor("quickCapture", "Automatically stack windows to avoid overlap")
            defaultValue: Defaults.values.autoTiling
        }
    }
}
