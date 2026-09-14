import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    SettingsSection {
        title: I18n.trFor("quickCapture", "Editor")
        icon: "aspect_ratio"

        SelectionSettingPlus {
            settingKey: "modalDisplayTarget"
            label: I18n.trFor("quickCapture", "Display")
            options: root.config.screenOptions([
                {
                    label: I18n.trFor("quickCapture", "Focused Screen"),
                    value: "focused"
                }
            ])
            defaultValue: Defaults.values.modalDisplayTarget
        }

        ButtonGroupSettingPlus {
            settingKey: "modalDisplayMode"
            label: I18n.trFor("quickCapture", "Display Mode")
            description: I18n.trFor("quickCapture", "Choose whether the editor opens as a modal overlay or a movable floating window.")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Modal"),
                    value: "modal"
                },
                {
                    label: I18n.trFor("quickCapture", "Floating"),
                    value: "floating"
                }
            ]
            defaultValue: Defaults.values.modalDisplayMode
        }

        ButtonGroupSettingPlus {
            settingKey: "modalAspectRatio"
            label: I18n.trFor("quickCapture", "Aspect Ratio")
            description: I18n.trFor("quickCapture", "Choose the editor shape for portrait or landscape screens.")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Landscape"),
                    value: "landscape"
                },
                {
                    label: I18n.trFor("quickCapture", "Portrait"),
                    value: "portrait"
                }
            ]
            defaultValue: Defaults.values.modalAspectRatio
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "overlayOpacity"
            label: I18n.trFor("quickCapture", "Overlay Opacity")
            defaultValue: Defaults.values.overlayOpacity
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0"
            rightLabel: "100"
            previewType: "opacity"
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "showCanvasBorder"
            label: I18n.trFor("quickCapture", "Show Screenshot Border")
            defaultValue: Defaults.values.showCanvasBorder
        }

        Separator {}

        ButtonGroupSettingPlus {
            settingKey: "editQuality"
            label: I18n.trFor("quickCapture", "Preview Quality")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Low"),
                    value: "150000"
                },
                {
                    label: I18n.trFor("quickCapture", "Balanced"),
                    value: "300000"
                },
                {
                    label: I18n.trFor("quickCapture", "High"),
                    value: "450000"
                },
                {
                    label: I18n.trFor("quickCapture", "Very High"),
                    value: "600000"
                }
            ]
            defaultValue: Defaults.values.editQuality
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Controls the preview pixel budget while editing. Lower it if you experience lag. Does not affect the final saved image quality.")
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "modalScaleToContent"
            label: I18n.trFor("quickCapture", "Scale Editor to Screenshot Size")
            description: I18n.trFor("quickCapture", "When enabled, the editor shrinks to match the captured region instead of filling %1% of the screen.").arg(90)
            defaultValue: Defaults.values.modalScaleToContent
        }
    }
}
