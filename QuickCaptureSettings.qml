import "./dms-common"
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    component CompactColorSetting : Item {
        id: swatchRoot

        required property string settingKey
        required property string label
        property var defaultValue: Theme.primary
        property var value: defaultValue

        property bool isInitialized: false
        readonly property bool isDirty: value.toString() !== defaultValue.toString()

        readonly property color resolvedColor: {
            if (value === "primary") return Theme.primary;
            return Qt.color(value);
        }

        function resetToDefault() {
            value = defaultValue;
        }

        function loadValue() {
            const settings = findSettings();
            if (settings && settings.pluginService) {
                const loadedValue = settings.loadValue(settingKey, defaultValue);
                value = loadedValue;
                isInitialized = true;
            }
        }

        Component.onCompleted: Qt.callLater(loadValue);

        onValueChanged: {
            if (!isInitialized) return;
            const settings = findSettings();
            if (settings) settings.saveValue(settingKey, value);
        }

        function findSettings() {
            let item = parent;
            while (item) {
                if (item.saveValue !== undefined && item.loadValue !== undefined) return item;
                item = item.parent;
            }
            return null;
        }

        // Layout sizing
        width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
        height: 76

        Column {
            anchors.fill: parent
            spacing: Theme.spacingXS
            
            // Swatch Container
            Item {
                id: swatchContainer
                width: 44
                height: 44
                anchors.horizontalCenter: parent.horizontalCenter

                HoverHandler {
                    id: hoverHandler
                }

                // Outer glowing/highlighting ring
                Rectangle {
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    radius: 26
                    color: hoverHandler.hovered ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                    border.color: Theme.primary
                    border.width: hoverHandler.hovered ? 1.5 : 0
                    opacity: hoverHandler.hovered ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                // Main color circle
                Rectangle {
                    anchors.fill: parent
                    radius: 22
                    color: swatchRoot.resolvedColor
                    border.color: Theme.outlineStrong
                    border.width: 1.5
                    scale: hoverHandler.hovered ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

                    // Tiny reset dot if dirty
                    Rectangle {
                        width: 14
                        height: 14
                        radius: 7
                        color: Theme.surface
                        border.color: Theme.outline
                        border.width: 1
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.topMargin: -2
                        anchors.rightMargin: -2
                        visible: swatchRoot.isDirty
                        
                        DankIcon {
                            name: "restart_alt"
                            size: 10
                            color: Theme.primary
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: swatchRoot.resetToDefault()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onEntered: {
                        let tooltipText = swatchRoot.value === "primary" ? I18n.tr("Theme Primary Color") : swatchRoot.value.toString().toUpperCase();
                        sharedTooltip.show(tooltipText, parent);
                    }
                    onExited: {
                        sharedTooltip.hide();
                    }
                    onClicked: {
                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                            PopoutService.colorPickerModal.selectedColor = swatchRoot.resolvedColor;
                            PopoutService.colorPickerModal.pickerTitle = swatchRoot.label;
                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                swatchRoot.value = selectedColor.toString();
                            };
                            PopoutService.colorPickerModal.show();
                        }
                    }
                }
            }

            StyledText {
                text: swatchRoot.label
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceText
                opacity: hoverHandler.hovered ? 1.0 : 0.7
                anchors.horizontalCenter: parent.horizontalCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
            }
        }

        DankTooltipV2 { id: sharedTooltip }
    }

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

        ButtonGroupSettingPlus {
            id: captureMode
            settingKey: "captureMode"
            label: I18n.tr("Capture Mode")
            options: [
                { label: I18n.tr("Interactive Region"), value: "region" },
                { label: I18n.tr("Full Screen"), value: "full" }
            ]
            defaultValue: "region"
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: doneAction
            settingKey: "doneAction"
            label: I18n.tr("Action when Enter")
            options: [
                { label: I18n.tr("Copy"), value: "clipboard" },
                { label: I18n.tr("Save"), value: "file" },
                { label: I18n.tr("Copy & Save"), value: "both" }
            ]
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

        ButtonGroupSettingPlus {
            id: toolbarPosition
            settingKey: "toolbarPosition"
            label: I18n.tr("Toolbar Position")
            options: [
                { label: I18n.tr("Top"), value: "top" },
                { label: I18n.tr("Bottom"), value: "bottom" },
                { label: I18n.tr("Left"), value: "left" },
                { label: I18n.tr("Right"), value: "right" }
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
        id: toolbarPaletteSection
        SectionTitle {
            text: I18n.tr("Toolbar Palette")
            icon: "palette"
            showReset: toolbar_primary.isDirty || c0.isDirty || c1.isDirty || c2.isDirty || c3.isDirty || c4.isDirty || c5.isDirty || c6.isDirty
            onResetClicked: {
                toolbar_primary.resetToDefault();
                c0.resetToDefault(); c1.resetToDefault(); c2.resetToDefault();
                c3.resetToDefault(); c4.resetToDefault(); c5.resetToDefault();
                c6.resetToDefault();
            }
        }

        InfoText {
            text: I18n.tr("Customize the 8 color slots available in the annotation toolbar.")
        }

        Item { width: 1; height: Theme.spacingS }

        Grid {
            width: parent.width
            columns: 4
            rowSpacing: Theme.spacingM
            columnSpacing: Theme.spacingM

            CompactColorSetting {
                id: toolbar_primary
                settingKey: "toolbar_color_primary"
                label: I18n.tr("Slot 1")
                defaultValue: "primary"
            }

            CompactColorSetting { id: c0; settingKey: "toolbar_color_0"; label: I18n.tr("Slot 2"); defaultValue: "#3b82f6" }
            CompactColorSetting { id: c1; settingKey: "toolbar_color_1"; label: I18n.tr("Slot 3"); defaultValue: "#ef4444" }
            CompactColorSetting { id: c2; settingKey: "toolbar_color_2"; label: I18n.tr("Slot 4"); defaultValue: "#22c55e" }
            CompactColorSetting { id: c3; settingKey: "toolbar_color_3"; label: I18n.tr("Slot 5"); defaultValue: "#eab308" }
            CompactColorSetting { id: c4; settingKey: "toolbar_color_4"; label: I18n.tr("Slot 6"); defaultValue: "#a855f7" }
            CompactColorSetting { id: c5; settingKey: "toolbar_color_5"; label: I18n.tr("Slot 7"); defaultValue: "#ffffff" }
            CompactColorSetting { id: c6; settingKey: "toolbar_color_6"; label: I18n.tr("Slot 8"); defaultValue: "#000000" }
        }
    }

    SettingsCard {
        id: radialMenuCard

        property int presetActiveIndex: 0

        SectionTitle {
            text: I18n.tr("Radial Menu")
            icon: "settings"
        }

        InfoText {
            text: I18n.tr("Configure up to 8 quick-access tool presets. Right-click anywhere during capture to open the radial menu.")
        }

        Item { width: 1; height: Theme.spacingXS }

        Column {
            width: parent.width
            spacing: Theme.spacingS

            DankButtonGroup {
                id: presetSelector1
                width: parent.width
                buttonHeight: 32
                selectionMode: "single"
                model: [I18n.tr("Preset 1"), I18n.tr("Preset 2"), I18n.tr("Preset 3"), I18n.tr("Preset 4")]
                currentIndex: radialMenuCard.presetActiveIndex < 4 ? radialMenuCard.presetActiveIndex : -1
                onSelectionChanged: (index, selected) => {
                    if (selected) {
                        radialMenuCard.presetActiveIndex = index
                    }
                }
            }

            DankButtonGroup {
                id: presetSelector2
                width: parent.width
                buttonHeight: 32
                selectionMode: "single"
                model: [I18n.tr("Preset 5"), I18n.tr("Preset 6"), I18n.tr("Preset 7"), I18n.tr("Preset 8")]
                currentIndex: radialMenuCard.presetActiveIndex >= 4 ? (radialMenuCard.presetActiveIndex - 4) : -1
                onSelectionChanged: (index, selected) => {
                    if (selected) {
                        radialMenuCard.presetActiveIndex = index + 4
                    }
                }
            }
        }

        Repeater {
            model: 8

            Column {
                width: parent.width
                spacing: Theme.spacingM
                visible: radialMenuCard.presetActiveIndex === index

                Item { width: 1; height: Theme.spacingXS }

                SelectionSettingPlus {
                    settingKey: "preset_" + index + "_tool"
                    label: I18n.tr("Preset Tool")
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
                    label: I18n.tr("Preset Color")
                    defaultValue: index === 0 ? "#ef4444" : "#3b82f6"
                }

                Separator {}

                SliderSettingPlus {
                    settingKey: "preset_" + index + "_thickness"
                    label: I18n.tr("Preset Thickness")
                    defaultValue: 6
                    minimum: 1
                    maximum: 20
                    leftLabel: "1"
                    rightLabel: "20"
                }
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
                I18n.tr("<b>Left-click</b> the bar icon to start a new screenshot."),
                I18n.tr("<b>Right-click</b> the bar icon to select an existing image for annotation."),
                I18n.tr("<b>Drop an image</b> onto the bar icon to open it instantly."),
                I18n.tr("During capture: <b>Right-click</b> to open the custom <b>Radial Menu</b>."),
                I18n.tr("Use <b>Mouse Wheel</b> to dynamically adjust stroke thickness."),
                I18n.tr("<b>Middle-click</b> any drawn element to instantly erase it.")
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
