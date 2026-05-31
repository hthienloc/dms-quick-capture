import "./dms-common"
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    SettingsCard {
        id: captureSection
        SectionTitle {
            text: I18n.tr("Capture")
            icon: "screenshot"
            showReset: captureMode.isDirty || doneAction.isDirty || saveDirectory.isDirty
            onResetClicked: {
                captureMode.resetToDefault();
                doneAction.resetToDefault();
                saveDirectory.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: captureMode
            settingKey: "captureMode"
            label: I18n.tr("Capture Mode")
            options: [{
                "label": I18n.tr("Interactive Region"),
                "value": "region"
            }, {
                "label": I18n.tr("Full Screen"),
                "value": "full"
            }]
            defaultValue: "region"
        }

        Separator {}

        SelectionSettingPlus {
            id: doneAction
            settingKey: "doneAction"
            label: I18n.tr("Action when Enter")
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

        Separator {}

        StringSettingPlus {
            id: saveDirectory
            settingKey: "saveDirectory"
            label: I18n.tr("Save Directory")
            placeholder: "~/Pictures/Screenshots"
            defaultValue: "~/Pictures/Screenshots"
            isDirectory: true
        }
    }

    SettingsCard {
        id: interfaceSection
        SectionTitle {
            text: I18n.tr("Interface")
            icon: "visibility"
            showReset: toolbarPosition.isDirty || modalOpacity.isDirty
            onResetClicked: {
                toolbarPosition.resetToDefault();
                modalOpacity.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: toolbarPosition
            settingKey: "toolbarPosition"
            label: I18n.tr("Toolbar Position")
            options: [
                { "label": I18n.tr("Top"), "value": "top" },
                { "label": I18n.tr("Bottom"), "value": "bottom" },
                { "label": I18n.tr("Left"), "value": "left" },
                { "label": I18n.tr("Right"), "value": "right" }
            ]
            defaultValue: "top"
        }

        Separator {}

        SliderSettingPlus {
            id: modalOpacity
            settingKey: "modalOpacity"
            label: I18n.tr("Backdrop Opacity")
            defaultValue: 60
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0"
            rightLabel: "100"
        }
    }

    SettingsCard {
        id: toolsSection
        SectionTitle {
            text: I18n.tr("Tools")
            icon: "edit"
            showReset: defaultTool.isDirty || defaultThickness.isDirty || textFontSize.isDirty || textMonospace.isDirty || roundRect.isDirty || roundHighlighter.isDirty
            onResetClicked: {
                defaultTool.resetToDefault();
                defaultThickness.resetToDefault();
                textFontSize.resetToDefault();
                textMonospace.resetToDefault();
                roundRect.resetToDefault();
                roundHighlighter.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: defaultTool
            settingKey: "defaultTool"
            label: I18n.tr("Starting Tool")
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

        Separator {}

        SliderSettingPlus {
            id: defaultThickness
            label: I18n.tr("Default Stroke Thickness")
            settingKey: "defaultThickness"
            defaultValue: 6
            minimum: 1
            maximum: 20
            leftLabel: "1"
            rightLabel: "20"
        }

        Separator {}

        SliderSettingPlus {
            id: textFontSize
            label: I18n.tr("Text Font Size")
            settingKey: "textFontSize"
            defaultValue: 24
            minimum: 8
            maximum: 72
            leftLabel: "8"
            rightLabel: "72"
        }

        Separator {}

        ToggleSettingPlus {
            id: textMonospace
            settingKey: "textMonospace"
            label: I18n.tr("Use Monospace Font")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: roundRect
            settingKey: "roundRect"
            label: I18n.tr("Round Rectangle Corners")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            id: roundHighlighter
            settingKey: "roundHighlighter"
            label: I18n.tr("Round Highlighter Tips")
            defaultValue: false
        }
    }

    SettingsCard {
        SectionTitle {
            text: I18n.tr("Radial Menu")
            icon: "settings"
        }

        InfoText {
            text: I18n.tr("Configure up to 8 quick-access tool presets. Right-click anywhere during capture to open the radial menu.")
        }

        Repeater {
            model: 8

            Column {
                width: parent.width
                spacing: 0

                Separator { opacity: 0.1 }

                Item { width: 1; height: Theme.spacingM }

                StyledText {
                    text: I18n.tr("Preset Slot ") + (index + 1)
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                    color: Theme.primary
                }

                Item { width: 1; height: Theme.spacingS }

                SelectionSettingPlus {
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

                Separator {}

                ColorSettingPlus {
                    settingKey: "preset_" + index + "_color"
                    label: I18n.tr("Color")
                    defaultValue: index === 0 ? "#ef4444" : "#3b82f6"
                }

                Separator {}

                SliderSettingPlus {
                    settingKey: "preset_" + index + "_thickness"
                    label: I18n.tr("Thickness")
                    defaultValue: 6
                    minimum: 1
                    maximum: 20
                    leftLabel: "1"
                    rightLabel: "20"
                }
                
                Item { width: 1; height: Theme.spacingM }

            }

        }

    }

    SettingsCard {
        SectionTitle { 
            id: usageTitle
            text: I18n.tr("Usage Guide")
            icon: "menu_book" 
            collapsible: true
            settingKey: "usageGuideExpanded"
        }

        UsageGuide {
            expanded: usageTitle.isExpanded
            items: [
                I18n.tr("Start capture via <b>Control Center</b> or your configured <b>Print</b> key."),
                I18n.tr("During capture: <b>Right-click</b> to open the custom <b>Radial Menu</b>."),
                I18n.tr("Use <b>Mouse Wheel</b> to dynamically adjust stroke thickness."),
                I18n.tr("<b>Middle-click</b> any drawn element to instantly erase it."),
                I18n.tr("Press <b>Enter</b> to finish and save/copy, or <b>Esc</b> to discard.")
            ]
        }
    }

    SettingsCard {
        SectionTitle {
            id: ipcTitle
            text: I18n.tr("IPC Commands")
            icon: "terminal"
            collapsible: true
            isExpanded: false
            settingKey: "ipcCommandsExpanded"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: ipcTitle.isExpanded

            CopyBox {
                label: I18n.tr("Trigger Screenshot")
                text: "dms ipc call quickCapture screenshot"
            }

            CopyBox {
                label: I18n.tr("Select Image File")
                text: "dms ipc call quickCapture selectFile"
            }

            CopyBox {
                label: I18n.tr("Toggle Annotator")
                text: "dms ipc call quickCapture toggle"
            }

            CopyBox {
                label: I18n.tr("Close Annotator")
                text: "dms ipc call quickCapture close"
            }

            Separator { opacity: 0.1 }

            CopyBox {
                label: I18n.tr("Niri Binding Example")
                text: "binds {\n    Print { spawn \"dms\" \"ipc\" \"call\" \"quickCapture\" \"screenshot\"; }\n}"
            }
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-quick-capture"
    }

}
