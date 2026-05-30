import "./dms-common"
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Screenshot Mode")
            icon: "screenshot"
        }

        SelectionSetting {
            settingKey: "captureMode"
            label: I18n.tr("Capture Mode")
            description: I18n.tr("Choose whether to capture a selected region or the full screen.")
            options: [{
                "label": I18n.tr("Interactive Region"),
                "value": "region"
            }, {
                "label": I18n.tr("Full Screen"),
                "value": "full"
            }]
            defaultValue: "region"
        }

    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("File Export")
            icon: "folder"
        }

        StringSetting {
            settingKey: "saveDirectory"
            label: I18n.tr("Save Directory")
            description: I18n.tr("Directory path where screen captures are saved.")
            placeholder: "~/Pictures/Screenshots"
            defaultValue: "~/Pictures/Screenshots"
        }

        SelectionSetting {
            settingKey: "doneAction"
            label: I18n.tr("Action when Enter")
            description: I18n.tr("Default action when pressing Enter to finish.")
            options: [{
                "label": I18n.tr("Copy to Clipboard only"),
                "value": "clipboard"
            }, {
                "label": I18n.tr("Save to File only"),
                "value": "file"
            }, {
                "label": I18n.tr("Both Copy and Save"),
                "value": "both"
            }]
            defaultValue: "both"
        }

    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Interface & Visuals")
            icon: "visibility"
        }

        SliderSetting {
            settingKey: "modalOpacity"
            label: I18n.tr("Backdrop Opacity")
            description: I18n.tr("Adjust the transparency of the background during capture.")
            defaultValue: 60
            minimum: 0
            maximum: 100
            unit: "%"
        }

        SelectionSetting {
            settingKey: "toolbarPosition"
            label: I18n.tr("Toolbar Position")
            description: I18n.tr("Where to place the annotation toolbar on the screen.")
            options: [
                { "label": I18n.tr("Top"), "value": "top" },
                { "label": I18n.tr("Bottom"), "value": "bottom" },
                { "label": I18n.tr("Left"), "value": "left" },
                { "label": I18n.tr("Right"), "value": "right" }
            ]
            defaultValue: "top"
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Default Tools")
            icon: "edit"
        }

        SelectionSetting {
            settingKey: "defaultTool"
            label: I18n.tr("Starting Tool")
            description: I18n.tr("Default tool selected when launching the annotation overlay.")
            options: [{
                "label": I18n.tr("Freehand Pen"),
                "value": "pen"
            }, {
                "label": I18n.tr("Straight Line"),
                "value": "line"
            }, {
                "label": I18n.tr("Arrow Vector"),
                "value": "arrow"
            }, {
                "label": I18n.tr("Rectangle Outline"),
                "value": "rect"
            }, {
                "label": I18n.tr("Ellipse / Circle"),
                "value": "ellipse"
            }, {
                "label": I18n.tr("Text Note"),
                "value": "text"
            }, {
                "label": I18n.tr("Pixelate"),
                "value": "pixelate"
            }, {
                "label": I18n.tr("Redact / Blackout"),
                "value": "redact"
            }, {
                "label": I18n.tr("Number Stamp"),
                "value": "stamp"
            }, {
                "label": I18n.tr("Highlighter"),
                "value": "highlighter"
            }, {
                "label": I18n.tr("Eraser"),
                "value": "eraser"
            }, {
                "label": I18n.tr("Crop / Resize"),
                "value": "crop"
            }]
            defaultValue: "pen"
        }

        SliderSetting {
            label: I18n.tr("Default Stroke Thickness")
            description: I18n.tr("Initial thickness for pen, line, arrow, and shape tools.")
            settingKey: "defaultThickness"
            defaultValue: 6
            minimum: 1
            maximum: 20
        }

        SliderSetting {
            label: I18n.tr("Text Font Size")
            description: I18n.tr("Default size for text annotations.")
            settingKey: "textFontSize"
            defaultValue: 24
            minimum: 8
            maximum: 72
        }

        ToggleSetting {
            settingKey: "textMonospace"
            label: I18n.tr("Use Monospace Font")
            description: I18n.tr("Use a fixed-width font for the text tool.")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Drawing Styles")
            icon: "palette"
        }

        ToggleSetting {
            settingKey: "roundRect"
            label: I18n.tr("Round Rectangle Corners")
            description: I18n.tr("Use rounded corners for the rectangle and redact tools.")
            defaultValue: true
        }

        ToggleSetting {
            settingKey: "roundHighlighter"
            label: I18n.tr("Round Highlighter Tips")
            description: I18n.tr("Use rounded tips and joints for the highlighter tool.")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Radial Menu Presets")
            icon: "settings"
        }

        InfoText {
            text: I18n.tr("Configure up to 8 quick-access tool presets. Right-click anywhere during capture to open the radial menu.")
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
                    text: I18n.tr("Preset Slot ") + (index + 1)
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    color: Theme.primary
                    topPadding: index > 0 ? Theme.spacingM : 0
                }

                SelectionSetting {
                    settingKey: "preset_" + index + "_tool"
                    label: I18n.tr("Tool")
                    options: [{
                        "label": I18n.tr("None / Disabled"),
                        "value": "none"
                    }, {
                        "label": I18n.tr("Freehand Pen"),
                        "value": "pen"
                    }, {
                        "label": I18n.tr("Straight Line"),
                        "value": "line"
                    }, {
                        "label": I18n.tr("Arrow Vector"),
                        "value": "arrow"
                    }, {
                        "label": I18n.tr("Rectangle Outline"),
                        "value": "rect"
                    }, {
                        "label": I18n.tr("Ellipse / Circle"),
                        "value": "ellipse"
                    }, {
                        "label": I18n.tr("Text Note"),
                        "value": "text"
                    }, {
                        "label": I18n.tr("Pixelate"),
                        "value": "pixelate"
                    }, {
                        "label": I18n.tr("Redact / Blackout"),
                        "value": "redact"
                    }, {
                        "label": I18n.tr("Number Stamp"),
                        "value": "stamp"
                    }, {
                        "label": I18n.tr("Highlighter"),
                        "value": "highlighter"
                    }, {
                        "label": I18n.tr("Eraser"),
                        "value": "eraser"
                    }, {
                        "label": I18n.tr("Crop / Resize"),
                        "value": "crop"
                    }]
                    defaultValue: index === 0 ? "pen" : "none"
                }

                ColorSetting {
                    settingKey: "preset_" + index + "_color"
                    label: I18n.tr("Color")
                    defaultValue: index === 0 ? "#ef4444" : "#3b82f6"
                }

                SliderSetting {
                    settingKey: "preset_" + index + "_thickness"
                    label: I18n.tr("Thickness")
                    defaultValue: 6
                    minimum: 1
                    maximum: 20
                }

            }

        }

    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-quick-capture"
    }

}
