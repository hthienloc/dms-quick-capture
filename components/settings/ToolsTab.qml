import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Constants.js" as Constants
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property var toolRows: [
        {
            tool: "pen",
            thicknessKey: "defaultPenThickness",
            colorKey: "defaultPenColor"
        },
        {
            tool: "line",
            thicknessKey: "defaultLineThickness",
            colorKey: "defaultLineColor"
        },
        {
            tool: "arrow",
            thicknessKey: "defaultArrowThickness",
            colorKey: "defaultArrowColor"
        },
        {
            tool: "rect",
            thicknessKey: "defaultRectThickness",
            colorKey: "defaultRectColor"
        },
        {
            tool: "ellipse",
            thicknessKey: "defaultEllipseThickness",
            colorKey: "defaultEllipseColor"
        },
        {
            tool: "highlighter",
            thicknessKey: "defaultHighlighterThickness",
            colorKey: "defaultHighlighterColor"
        },
        {
            tool: "text",
            thicknessKey: "",
            colorKey: "defaultTextColor"
        },
        {
            tool: "stamp",
            thicknessKey: "defaultStampSize",
            colorKey: "defaultStampColor"
        },
        {
            tool: "redact",
            thicknessKey: "defaultRedactThickness",
            colorKey: ""
        },
        {
            tool: "pixelate",
            thicknessKey: "defaultPixelateIntensity",
            colorKey: ""
        },
        {
            tool: "spotlight",
            thicknessKey: "defaultSpotlightIntensity",
            colorKey: ""
        },
        {
            tool: "callout",
            thicknessKey: "defaultCalloutZoom",
            colorKey: ""
        }
    ]

    SettingsSection {
        title: I18n.trFor("quickCapture", "Tool Defaults")
        icon: "tune"

        ButtonGroupSettingPlus {
            id: defaultToolMode
            settingKey: "defaultToolMode"
            label: I18n.trFor("quickCapture", "Starting Tool Mode")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Preset"),
                    value: "preset"
                },
                {
                    label: I18n.trFor("quickCapture", "Custom"),
                    value: "custom"
                }
            ]
            defaultValue: Defaults.values.defaultToolMode
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Note: Starting tool mode overrides tool thickness and color defaults if the starting tool matches it.")
        }

        SettingsGroup {
            visible: defaultToolMode.value === "preset"

            Separator {}

            SelectionSettingPlus {
                settingKey: "defaultPresetIndex"
                label: I18n.trFor("quickCapture", "Starting Preset")
                options: [0, 1, 2, 3, 4, 5, 6, 7].map(i => ({
                            label: I18n.trFor("quickCapture", "Preset %1").arg(i + 1),
                            value: String(i)
                        }))
                defaultValue: Defaults.values.defaultPresetIndex
            }
        }

        SettingsGroup {
            visible: defaultToolMode.value === "custom"

            Separator {}

            SelectionSettingPlus {
                settingKey: "defaultTool"
                label: I18n.trFor("quickCapture", "Starting Tool")
                options: root.config.toolOptions(root.config.startingToolIds)
                defaultValue: Defaults.values.defaultTool
            }
        }

        Repeater {
            model: root.toolRows

            delegate: SettingsGroup {
                id: toolGroup
                required property var modelData
                readonly property var meta: Constants.getToolMeta(modelData.tool)
                title: root.config.getToolLabel(modelData.tool)
                divider: true

                SliderSettingPlus {
                    visible: toolGroup.modelData.thicknessKey !== ""
                    settingKey: toolGroup.modelData.thicknessKey
                    label: root.config.toolMetricLabel(toolGroup.modelData.tool)
                    defaultValue: toolGroup.meta.defaultValue
                    minimum: toolGroup.meta.min
                    maximum: toolGroup.meta.max
                    unit: toolGroup.meta.unit
                    leftLabel: String(toolGroup.meta.min)
                    rightLabel: String(toolGroup.meta.max)
                    previewType: toolGroup.meta.previewType
                }

                ColorSettingPlus {
                    visible: toolGroup.modelData.colorKey !== ""
                    settingKey: toolGroup.modelData.colorKey
                    label: I18n.trFor("quickCapture", "Color")
                    defaultValue: "primary"
                }
            }
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Text")
        icon: "format_size"

        SliderSettingPlus {
            settingKey: "textFontSize"
            label: I18n.trFor("quickCapture", "Font Size")
            defaultValue: Constants.getToolMeta("text").defaultValue
            minimum: Constants.getToolMeta("text").min
            maximum: Constants.getToolMeta("text").max
            leftLabel: String(Constants.getToolMeta("text").min)
            rightLabel: String(Constants.getToolMeta("text").max)
            previewType: "fontSize"
        }

        Separator {}

        FontSelectionSettingPlus {
            settingKey: "textFontFamily"
            label: I18n.trFor("quickCapture", "%1 Font").arg(I18n.trFor("quickCapture", "Text"))
            defaultValue: Defaults.values.textFontFamily
        }

        Separator {}

        FontSelectionSettingPlus {
            settingKey: "stampFontFamily"
            label: I18n.trFor("quickCapture", "%1 Font").arg(I18n.trFor("quickCapture", "Stamp"))
            description: I18n.trFor("quickCapture", "Font family used for number stamp labels")
            defaultValue: Defaults.values.stampFontFamily
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "textBold"
            label: I18n.trFor("quickCapture", "Bold")
            defaultValue: Defaults.values.textBold
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "textItalic"
            label: I18n.trFor("quickCapture", "Italic")
            defaultValue: Defaults.values.textItalic
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "textUnderline"
            label: I18n.trFor("quickCapture", "Underline")
            defaultValue: Defaults.values.textUnderline
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "textBackground"
            label: I18n.trFor("quickCapture", "Text Background")
            defaultValue: Defaults.values.textBackground
        }

        Separator {}

        ButtonGroupSettingPlus {
            settingKey: "textInputMode"
            label: I18n.trFor("quickCapture", "Input Mode")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Inline"),
                    value: "inline"
                },
                {
                    label: I18n.trFor("quickCapture", "Popup"),
                    value: "popup"
                }
            ]
            defaultValue: Defaults.values.textInputMode
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Shapes")
        icon: "category"

        ToggleSettingPlus {
            settingKey: "roundRect"
            label: I18n.trFor("quickCapture", "Round Rectangle Corners")
            defaultValue: Defaults.values.roundRect
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "textCornerRadius"
            label: I18n.trFor("quickCapture", "Text Background Roundness")
            defaultValue: Defaults.values.textCornerRadius
            minimum: 0
            maximum: 20
            unit: "px"
            leftLabel: "0"
            rightLabel: "20"
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "roundHighlighter"
            label: I18n.trFor("quickCapture", "Round Highlighter Tips")
            defaultValue: Defaults.values.roundHighlighter
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "stampOuterRing"
            label: I18n.trFor("quickCapture", "Stamp Contrast Ring")
            description: I18n.trFor("quickCapture", "Draw an outer ring using the stamp number color")
            defaultValue: Defaults.values.stampOuterRing
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "penAutoClose"
            label: I18n.trFor("quickCapture", "Pen Auto-Close")
            description: I18n.trFor("quickCapture", "Auto-close the loop when ending near the start point.")
            defaultValue: Defaults.values.penAutoClose
        }
    }
}
