import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    id: root
    pluginId: "quickCapture"

    PluginHeader {
        title: "Quick Capture Settings"
    }

    SettingsCard {
        SectionTitle { text: "Screenshot Mode" }

        SelectionSetting {
            settingKey: "captureMode"
            label: "Capture Mode"
            description: "Choose whether to capture a selected region or the full screen."
            options: [
                { label: "Interactive Region (WIP)", value: "region" },
                { label: "Full Screen", value: "full" }
            ]
            defaultValue: "full"
        }
    }

    SettingsCard {
        SectionTitle { text: "File Export" }

        StringSetting {
            settingKey: "saveDirectory"
            label: "Save Directory"
            description: "Directory path where screen captures are saved."
            placeholder: "~/Pictures/Screenshots"
            defaultValue: "~/Pictures/Screenshots"
        }

        SelectionSetting {
            settingKey: "doneAction"
            label: "Action when Enter"
            description: "Default action when pressing Enter to finish."
            options: [
                { label: "Copy to Clipboard only", value: "clipboard" },
                { label: "Save to File only", value: "file" },
                { label: "Both Copy and Save", value: "both" }
            ]
            defaultValue: "both"
        }
    }

    SettingsCard {
        SectionTitle { text: "Default Tools" }

        SelectionSetting {
            settingKey: "defaultTool"
            label: "Starting Tool"
            description: "Default tool selected when launching the annotation overlay."
            options: [
                { label: "Freehand Pen", value: "pen" },
                { label: "Straight Line", value: "line" },
                { label: "Arrow Vector", value: "arrow" },
                { label: "Rectangle Outline", value: "rect" },
                { label: "Ellipse / Circle", value: "ellipse" },
                { label: "Text Note", value: "text" },
                { label: "Pixelate", value: "pixelate" },
                { label: "Redact / Blackout", value: "redact" },
                { label: "Number Stamp", value: "stamp" },
                { label: "Highlighter", value: "highlighter" },
                { label: "Eraser", value: "eraser" },
                { label: "Crop / Resize", value: "crop" }
            ]
            defaultValue: "pen"
        }

        SliderSetting {
            label: "Starting Thickness"
            description: "Default line thickness for drawing tools."
            settingKey: "defaultThickness"
            defaultValue: 6
            minimum: 1
            maximum: 20
        }
    }

    SettingsCard {
        SectionTitle { text: "Radial Menu Presets" }
        
        InfoText {
            text: "Configure up to 8 quick-access tool presets. Right-click anywhere during capture to open the radial menu."
        }

        Repeater {
            model: 8
            
            Column {
                width: parent.width
                spacing: Theme.spacingS
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: index > 0 ? 0.15 : 0
                }

                StyledText {
                    text: "Preset Slot " + (index + 1)
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    color: Theme.primary
                    topPadding: index > 0 ? Theme.spacingM : 0
                }

                SelectionSetting {
                    settingKey: "preset_" + index + "_tool"
                    label: "Tool"
                    options: [
                        { label: "None / Disabled", value: "none" },
                        { label: "Freehand Pen", value: "pen" },
                        { label: "Straight Line", value: "line" },
                        { label: "Arrow Vector", value: "arrow" },
                        { label: "Rectangle Outline", value: "rect" },
                        { label: "Ellipse / Circle", value: "ellipse" },
                        { label: "Text Note", value: "text" },
                        { label: "Pixelate", value: "pixelate" },
                        { label: "Redact / Blackout", value: "redact" },
                        { label: "Number Stamp", value: "stamp" },
                        { label: "Highlighter", value: "highlighter" },
                        { label: "Eraser", value: "eraser" },
                        { label: "Crop / Resize", value: "crop" }
                    ]
                    defaultValue: index === 0 ? "pen" : "none"
                }

                ColorSetting {
                    settingKey: "preset_" + index + "_color"
                    label: "Color"
                    defaultValue: index === 0 ? "#ef4444" : "#3b82f6"
                }

                SliderSetting {
                    settingKey: "preset_" + index + "_thickness"
                    label: "Thickness"
                    defaultValue: 6
                    minimum: 1
                    maximum: 20
                }
            }
        }
    }
}
