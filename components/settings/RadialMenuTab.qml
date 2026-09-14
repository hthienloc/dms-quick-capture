import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null
    property int activePreset: 0

    readonly property var presets: [0, 1, 2, 3, 4, 5, 6, 7].map(i => ({
                tool: config.presetTool(i),
                color: config.presetColor(i),
                thickness: config.presetThickness(i)
            }))

    SettingsSection {
        title: I18n.trFor("quickCapture", "Presets")
        icon: "settings"

        InfoText {
            text: I18n.trFor("quickCapture", "Configure up to %1 quick-access tool presets. Right-click during capture to open the radial menu.").arg(8)
        }

        RadialMenuPreview {
            config: root.config
            presets: root.presets
            activeIndex: root.activePreset
            menuOpacity: Defaults.get(root.config.pluginData, "radialMenuOpacity") / 100
            anchors.horizontalCenter: parent.horizontalCenter
            onActiveIndexChanged: root.activePreset = activeIndex
        }

        Repeater {
            model: 8

            delegate: RadialPresetEditor {
                required property int index
                visible: root.activePreset === index
                config: root.config
                presetIndex: index
            }
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Radial Menu")
        icon: "mouse"

        ToggleSettingPlus {
            id: hoverTrigger
            settingKey: "radialHoverTrigger"
            label: I18n.trFor("quickCapture", "Trigger on Hover")
            description: I18n.trFor("quickCapture", "Auto-select a tool preset on hover, without releasing the mouse.")
            defaultValue: Defaults.values.radialHoverTrigger
        }

        SettingsGroup {
            visible: hoverTrigger.value

            Separator {}

            SliderSettingPlus {
                settingKey: "radialHoverDelay"
                label: I18n.trFor("quickCapture", "Hover Trigger Delay")
                defaultValue: Defaults.values.radialHoverDelay
                minimum: 100
                maximum: 500
                leftLabel: "100"
                rightLabel: "500"
                unit: "ms"
            }
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "radialMenuOpacity"
            label: I18n.trFor("quickCapture", "Opacity")
            defaultValue: Defaults.values.radialMenuOpacity
            minimum: 0
            maximum: 100
            leftLabel: "0"
            rightLabel: "100"
            unit: "%"
        }
    }
}
