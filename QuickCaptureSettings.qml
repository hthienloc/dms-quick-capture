import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
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
                { "label": "Interactive Region", "value": "region" },
                { "label": "Full Screen", "value": "full" }
            ]
            defaultValue: "region"
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
            label: "Action on Done"
            description: "Default action when clicking the Done button."
            options: [
                { "label": "Copy to Clipboard only", "value": "clipboard" },
                { "label": "Save to File only", "value": "file" },
                { "label": "Both Copy and Save", "value": "both" }
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
                { "label": "Freehand Pen", "value": "pen" },
                { "label": "Highlighter", "value": "highlighter" },
                { "label": "Rectangle Outline", "value": "rect" },
                { "label": "Arrow Vector", "value": "arrow" }
            ]
            defaultValue: "pen"
        }

        IntSetting {
            settingKey: "defaultThickness"
            label: "Starting Stroke Width"
            description: "Starting line thickness for drawing tools."
            defaultValue: 8
            minValue: 1
            maxValue: 20
        }
    }
}
