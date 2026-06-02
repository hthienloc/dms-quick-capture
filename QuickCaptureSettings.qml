import "./dms-common"
import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    property int radialMenuOpacityValue: 100

    component ShortcutRow : Item {
        id: rowRoot
        width: parent.width
        height: 32
        
        required property string keyText
        required property string actionText
        property bool isHeader: false

        Rectangle {
            anchors.fill: parent
            color: rowRoot.isHeader ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
            radius: Theme.cornerRadius
        }

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingM
            
            // Key Badge Column
            Item {
                width: 110
                height: parent.height
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.max(90, keyLabel.implicitWidth + 12)
                    height: 22
                    radius: 6
                    color: rowRoot.isHeader ? "transparent" : Theme.surfaceContainerHighest
                    border.color: rowRoot.isHeader ? "transparent" : Theme.outline
                    border.width: rowRoot.isHeader ? 0 : 1
                    visible: rowRoot.keyText !== ""

                    StyledText {
                        id: keyLabel
                        text: rowRoot.keyText
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        isMonospace: true
                        color: rowRoot.isHeader ? Theme.primary : Theme.surfaceText
                        anchors.centerIn: parent
                    }
                }
            }

            // Action Text Column
            StyledText {
                text: rowRoot.actionText
                font.pixelSize: Theme.fontSizeMedium
                font.weight: rowRoot.isHeader ? Font.Bold : Font.Normal
                color: rowRoot.isHeader ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                width: parent.width - 130
            }
        }
    }

    component CompactColorSetting : Item {
        id: swatchRoot

        required property string settingKey
        required property string label
        property var defaultValue: Theme.primary
        property var value: defaultValue
        property bool readOnly: false
        property var overrideColor: null

        property bool isInitialized: false
        readonly property bool isDirty: value.toString() !== defaultValue.toString()

        readonly property color resolvedColor: {
            if (overrideColor !== null) return Qt.color(overrideColor);
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
                        visible: swatchRoot.isDirty && !swatchRoot.readOnly
                        
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
                        let tooltipText = swatchRoot.overrideColor !== null
                            ? swatchRoot.overrideColor.toString().toUpperCase()
                            : (swatchRoot.value === "primary" ? I18n.tr("Theme Primary Color") : swatchRoot.value.toString().toUpperCase());
                        sharedTooltip.show(tooltipText, parent);
                    }
                    onExited: {
                        sharedTooltip.hide();
                    }
                    onClicked: {
                        if (swatchRoot.readOnly) {
                            let colorStr = swatchRoot.overrideColor !== null
                                ? swatchRoot.overrideColor.toString()
                                : swatchRoot.value.toString();
                            Proc.runCommand("copy-color", ["wl-copy", "--", colorStr], function() {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("Copied:") + " " + colorStr.toUpperCase());
                                }
                            });
                            return;
                        }
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
        id: captureModeCard
        SectionTitle {
            text: I18n.tr("Capture Mode")
            icon: "camera"
            showReset: captureMode.isDirty || outputTargetName.isDirty || skipConfirm.isDirty || includeCursor.isDirty
            onResetClicked: {
                captureMode.resetToDefault();
                outputTargetName.resetToDefault();
                skipConfirm.resetToDefault();
                includeCursor.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: captureMode
            settingKey: "captureMode"
            label: I18n.tr("Capture Mode")
            options: [
                { label: I18n.tr("Interactive Region"), value: "region" },
                { label: I18n.tr("Full Screen"), value: "full" },
                { label: I18n.tr("All Combined Outputs"), value: "all" },
                { label: I18n.tr("Specific Output"), value: "output" },
                { label: I18n.tr("Focused Window"), value: "window" },
                { label: I18n.tr("Last Selected Region"), value: "last" }
            ]
            defaultValue: "region"
        }

        Separator {
            visible: captureMode.value === "output"
            height: visible ? 1 : 0
        }

        StringSettingPlus {
            id: outputTargetName
            settingKey: "outputTargetName"
            label: I18n.tr("Target Output Name")
            placeholder: "e.g. DP-1"
            defaultValue: "DP-1"
            visible: captureMode.value === "output"
            height: visible ? implicitHeight : 0
        }

        Item {
            width: parent.width
            height: visible ? warningRow.implicitHeight + 4 : 0
            visible: captureMode.value === "window"

            Row {
                id: warningRow
                width: parent.width
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "warning"
                    size: 16
                    color: Theme.warning
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - 24
                    text: I18n.tr("Note: Window capture mode requires Hyprland or DWL compositors.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.warning
                    wrapMode: Text.Wrap
                }
            }
        }

        Separator {
            visible: captureMode.value === "region"
            height: visible ? 1 : 0
        }

        ToggleSettingPlus {
            id: skipConfirm
            settingKey: "skipConfirm"
            label: I18n.tr("Skip Confirmation")
            defaultValue: true
            visible: captureMode.value === "region"
            height: visible ? 36 : 0
        }

        Separator {}

        ToggleSettingPlus {
            id: includeCursor
            settingKey: "includeCursor"
            label: I18n.tr("Include Cursor")
            defaultValue: false
        }
    }

    SettingsCard {
        id: saveOptionsCard
        SectionTitle {
            text: I18n.tr("Saving")
            icon: "save"
            showReset: doneAction.isDirty || saveDirectory.isDirty || saveFilenamePattern.isDirty || outputFormat.isDirty || jpegQuality.isDirty
            onResetClicked: {
                doneAction.resetToDefault();
                saveDirectory.resetToDefault();
                saveFilenamePattern.resetToDefault();
                outputFormat.resetToDefault();
                jpegQuality.resetToDefault();
            }
        }

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

        Separator {}

        StringSettingPlus {
            id: saveFilenamePattern
            settingKey: "saveFilenamePattern"
            label: I18n.tr("Save Filename Pattern")
            placeholder: "Screenshot_%Y-%m-%d_%H-%M-%S"
            defaultValue: "Screenshot_%Y-%m-%d_%H-%M-%S"
        }

        InfoText {
            text: I18n.tr("Supports formatting: %Y (Year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second), {zzz} (Ms)")
            opacity: 0.85
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: outputFormat
            settingKey: "outputFormat"
            label: I18n.tr("Output Format")
            options: [
                { label: "PNG", value: "png" },
                { label: "JPEG", value: "jpg" },
                { label: "PPM", value: "ppm" }
            ]
            defaultValue: "png"
        }

        Separator {
            visible: outputFormat.value === "jpg"
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: jpegQuality
            settingKey: "jpegQuality"
            label: I18n.tr("JPEG Quality")
            defaultValue: 90
            minimum: 1
            maximum: 100
            unit: "%"
            leftLabel: "1"
            rightLabel: "100"
            visible: outputFormat.value === "jpg"
            height: visible ? implicitHeight : 0
        }
    }

    SettingsCard {
        id: notificationsCard
        SectionTitle {
            text: I18n.tr("Notifications")
            icon: "notifications"
            showReset: showToasts.isDirty || showSystemNotification.isDirty
            onResetClicked: {
                showToasts.resetToDefault();
                showSystemNotification.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: showToasts
            settingKey: "showToasts"
            label: I18n.tr("Show Toast Notifications")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            id: showSystemNotification
            settingKey: "showSystemNotification"
            label: I18n.tr("Show System Notification")
            defaultValue: false
        }
    }

    SettingsCard {
        id: toolbarCard
        SectionTitle {
            text: I18n.tr("Toolbar")
            icon: "dock"
            showReset: showToolbar.isDirty || toolbarPosition.isDirty || showToolbarBorder.isDirty
            onResetClicked: {
                showToolbar.resetToDefault();
                toolbarPosition.resetToDefault();
                showToolbarBorder.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: showToolbar
            settingKey: "showToolbar"
            label: I18n.tr("Show Toolbar")
            defaultValue: true
        }

        Separator {
            visible: showToolbar.value
            height: visible ? 1 : 0
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
            visible: showToolbar.value
            height: visible ? 72 : 0
        }

        Separator {
            visible: showToolbar.value
            height: visible ? 1 : 0
        }

        ToggleSettingPlus {
            id: showToolbarBorder
            settingKey: "showToolbarBorder"
            label: I18n.tr("Show Toolbar Border")
            defaultValue: false
            visible: showToolbar.value
            height: visible ? 36 : 0
        }
    }

    SettingsCard {
        id: backdropStylesCard
        SectionTitle {
            text: I18n.tr("Styles")
            icon: "aspect_ratio"
            showReset: modalOpacity.isDirty || showCanvasBorder.isDirty
            onResetClicked: {
                modalOpacity.resetToDefault();
                showCanvasBorder.resetToDefault();
            }
        }

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
            previewType: "opacity"
        }

        Separator {}

        ToggleSettingPlus {
            id: showCanvasBorder
            settingKey: "showCanvasBorder"
            label: I18n.tr("Show Screenshot Border")
            defaultValue: true
        }
    }

    SettingsCard {
        id: drawingCard
        SectionTitle {
            text: I18n.tr("Drawing")
            icon: "brush"
            showReset: defaultToolMode.isDirty || defaultPresetIndex.isDirty || defaultTool.isDirty || defaultThickness.isDirty || enableMagnifier.isDirty
            onResetClicked: {
                defaultToolMode.resetToDefault();
                defaultPresetIndex.resetToDefault();
                defaultTool.resetToDefault();
                defaultThickness.resetToDefault();
                enableMagnifier.resetToDefault();
            }
        }

        ButtonGroupSettingPlus {
            id: defaultToolMode
            settingKey: "defaultToolMode"
            label: I18n.tr("Starting Tool Mode")
            options: [
                { label: I18n.tr("Radial Preset"), value: "preset" },
                { label: I18n.tr("Custom Tool"), value: "custom" }
            ]
            defaultValue: "custom"
        }

        Separator {}

        SelectionSettingPlus {
            id: defaultPresetIndex
            settingKey: "defaultPresetIndex"
            label: I18n.tr("Starting Preset")
            options: [
                { "label": I18n.tr("Preset 1"), "value": "0" },
                { "label": I18n.tr("Preset 2"), "value": "1" },
                { "label": I18n.tr("Preset 3"), "value": "2" },
                { "label": I18n.tr("Preset 4"), "value": "3" },
                { "label": I18n.tr("Preset 5"), "value": "4" },
                { "label": I18n.tr("Preset 6"), "value": "5" },
                { "label": I18n.tr("Preset 7"), "value": "6" },
                { "label": I18n.tr("Preset 8"), "value": "7" }
            ]
            defaultValue: "0"
            visible: defaultToolMode.value === "preset"
        }

        Separator {
            visible: defaultToolMode.value === "preset"
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
            visible: defaultToolMode.value === "custom"
        }

        Separator {
            visible: defaultToolMode.value === "custom"
        }

        SliderSettingPlus {
            id: defaultThickness
            label: I18n.tr("Default Stroke Thickness")
            settingKey: "defaultThickness"
            defaultValue: 6
            minimum: 1
            maximum: 20
            leftLabel: "1"
            rightLabel: "20"
            previewType: "thickness"
            visible: defaultToolMode.value === "custom"
        }

        Separator {}



        ButtonGroupSettingPlus {
            id: tabBehavior
            settingKey: "tabBehavior"
            label: I18n.tr("Tab Key Behavior (Select)")
            defaultValue: "toggle"
            options: [
                { "label": I18n.tr("Toggle Select"), "value": "toggle" },
                { "label": I18n.tr("Hold Select"), "value": "hold" }
            ]
        }
    }

    SettingsCard {
        id: textSettingsCard
        SectionTitle {
            text: I18n.tr("Text")
            icon: "format_size"
            showReset: textFontSize.isDirty || textFontFamily.isDirty || textBold.isDirty || textItalic.isDirty || textUnderline.isDirty || textInputMode.isDirty
            onResetClicked: {
                textFontSize.resetToDefault();
                textFontFamily.resetToDefault();
                textBold.resetToDefault();
                textItalic.resetToDefault();
                textUnderline.resetToDefault();
                textInputMode.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: textFontSize
            label: I18n.tr("Default Text Font Size")
            settingKey: "textFontSize"
            defaultValue: 36
            minimum: 8
            maximum: 72
            leftLabel: "8"
            rightLabel: "72"
            previewType: "fontSize"
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: textFontFamily
            settingKey: "textFontFamily"
            label: I18n.tr("Default Font Family")
            options: [
                { label: I18n.tr("Sans-Serif"), value: "sans-serif" },
                { label: I18n.tr("Monospace"), value: "monospace" },
                { label: I18n.tr("Serif"), value: "serif" }
            ]
            defaultValue: "sans-serif"
        }

        Separator {}

        ToggleSettingPlus {
            id: textBold
            settingKey: "textBold"
            label: I18n.tr("Default Bold Text")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: textItalic
            settingKey: "textItalic"
            label: I18n.tr("Default Italic Text")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: textUnderline
            settingKey: "textUnderline"
            label: I18n.tr("Default Underline Text")
            defaultValue: false
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: textInputMode
            settingKey: "textInputMode"
            label: I18n.tr("Input Mode")
            options: [
                { label: I18n.tr("Direct"), value: "inline" },
                { label: I18n.tr("Popup Input"), value: "popup" }
            ]
            defaultValue: "inline"
        }

        InfoText {
            text: I18n.tr("This mode does not support IME. If you use CJK or Vietnamese languages, please switch to Popup Input.")
            visible: textInputMode.value === "inline"
            opacity: 0.85
        }
    }

    SettingsCard {
        id: shapesCard
        SectionTitle {
            text: I18n.tr("Shapes")
            icon: "category"
            showReset: roundRect.isDirty || roundHighlighter.isDirty
            onResetClicked: {
                roundRect.resetToDefault();
                roundHighlighter.resetToDefault();
            }
        }

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
        id: watermarkCard
        SectionTitle {
            text: I18n.tr("Watermark")
            icon: "branding_watermark"
            showReset: enableWatermark.isDirty || watermarkType.isDirty || watermarkText.isDirty || watermarkImage.isDirty || watermarkPosition.isDirty || watermarkOpacity.isDirty || watermarkSize.isDirty || watermarkTextSize.isDirty
            onResetClicked: {
                enableWatermark.resetToDefault();
                watermarkType.resetToDefault();
                watermarkText.resetToDefault();
                watermarkImage.resetToDefault();
                watermarkPosition.resetToDefault();
                watermarkOpacity.resetToDefault();
                watermarkSize.resetToDefault();
                watermarkTextSize.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: enableWatermark
            settingKey: "enableWatermark"
            label: I18n.tr("Enable Watermark")
            defaultValue: false
        }

        Separator {
            visible: enableWatermark.value
            height: visible ? 1 : 0
        }

        ButtonGroupSettingPlus {
            id: watermarkType
            settingKey: "watermarkType"
            label: I18n.tr("Watermark Type")
            options: [
                { label: I18n.tr("Text"), value: "text" },
                { label: I18n.tr("Image"), value: "image" },
                { label: I18n.tr("Hybrid"), value: "hybrid" }
            ]
            defaultValue: "text"
            visible: enableWatermark.value
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value
            height: visible ? 1 : 0
        }

        SelectionSettingPlus {
            id: watermarkPosition
            settingKey: "watermarkPosition"
            label: I18n.tr("Position")
            options: [
                { label: I18n.tr("Top Left"), value: "top_left" },
                { label: I18n.tr("Top Right"), value: "top_right" },
                { label: I18n.tr("Bottom Left"), value: "bottom_left" },
                { label: I18n.tr("Bottom Right"), value: "bottom_right" },
                { label: I18n.tr("Center"), value: "center" },
                { label: I18n.tr("Top"), value: "top" },
                { label: I18n.tr("Bottom"), value: "bottom" },
                { label: I18n.tr("Left"), value: "left" },
                { label: I18n.tr("Right"), value: "right" }
            ]
            defaultValue: "bottom_right"
            visible: enableWatermark.value
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkOpacity
            settingKey: "watermarkOpacity"
            label: I18n.tr("Opacity")
            defaultValue: 20
            minimum: 5
            maximum: 100
            unit: "%"
            leftLabel: "5"
            rightLabel: "100"
            visible: enableWatermark.value
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value
            height: visible ? 1 : 0
        }

        StringSettingPlus {
            id: watermarkText
            settingKey: "watermarkText"
            label: I18n.tr("Watermark Text")
            placeholder: "© {user}"
            defaultValue: "© {user}"
            visible: enableWatermark.value && (watermarkType.value === "text" || watermarkType.value === "hybrid")
            height: visible ? implicitHeight : 0
        }

        InfoText {
            text: I18n.tr("Supports formatting: {user} (Username), \\n (New Line), %Y (Year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second)")
            opacity: 0.85
            visible: enableWatermark.value && (watermarkType.value === "text" || watermarkType.value === "hybrid")
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value && (watermarkType.value === "text" || watermarkType.value === "hybrid")
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkTextSize
            settingKey: "watermarkTextSize"
            label: I18n.tr("Text Size")
            defaultValue: 5
            minimum: 1
            maximum: 50
            unit: "%"
            leftLabel: "1"
            rightLabel: "50"
            visible: enableWatermark.value && (watermarkType.value === "text" || watermarkType.value === "hybrid")
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value && (watermarkType.value === "hybrid")
            height: visible ? 1 : 0
        }

        StringSettingPlus {
            id: watermarkImage
            settingKey: "watermarkImage"
            label: I18n.tr("Watermark Image")
            placeholder: "~/Pictures/watermark.png"
            defaultValue: ""
            isFile: true
            fileExtensions: ["Image files (*.png *.jpg *.jpeg *.svg *.webp)", "All files (*)"]
            visible: enableWatermark.value && (watermarkType.value === "image" || watermarkType.value === "hybrid")
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value && (watermarkType.value === "image" || watermarkType.value === "hybrid")
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkSize
            settingKey: "watermarkSize"
            label: I18n.tr("Image Size")
            defaultValue: 5
            minimum: 5
            maximum: 50
            unit: "%"
            leftLabel: "5"
            rightLabel: "50"
            visible: enableWatermark.value && (watermarkType.value === "image" || watermarkType.value === "hybrid")
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: enableWatermark.value
            height: visible ? 1 : 0
        }

        // Live Preview of the watermark overlay
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: enableWatermark.value
            height: visible ? implicitHeight : 0

            StyledText {
                text: I18n.tr("Live Preview")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                font.bold: true
            }

            StyledRect {
                id: watermarkPreviewArea
                width: parent.width
                height: 160
                radius: Theme.cornerRadiusSmall
                color: Theme.surfaceContainerLow
                clip: true

                // A dark checkered/gradient backdrop representing a mock captured screenshot
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#2E3440" }
                        GradientStop { position: 1.0; color: "#1A1C23" }
                    }
                }

                // Grid pattern to help visualize transparent opacity
                Grid {
                    anchors.fill: parent
                    columns: 8
                    rows: 4
                    spacing: 0
                    opacity: 0.1
                    Repeater {
                        model: 32
                        Rectangle {
                            width: watermarkPreviewArea.width / 8
                            height: 40
                            color: index % 2 === 0 ? "transparent" : "#ffffff"
                        }
                    }
                }

                // Offscreen image loader to resolve the watermark image path
                Image {
                    id: previewWatermarkImageLoader
                    
                    property int pathIndex: 0
                    property var fallbackPaths: []
                    
                    source: {
                        const rawPath = watermarkImage.value || "";
                        if (rawPath) {
                            let p = rawPath.trim();
                            if (p.indexOf("~/") === 0) {
                                const home = Quickshell.env("HOME") || "";
                                p = home + p.substring(1);
                            }
                            if (p.indexOf("/") === 0) {
                                p = "file://" + p;
                            }
                            return p;
                        }
                        
                        if (fallbackPaths.length > 0 && pathIndex < fallbackPaths.length) {
                            return fallbackPaths[pathIndex];
                        }
                        return "";
                    }
                    
                    onStatusChanged: {
                        if (status === Image.Error && (!watermarkImage.value)) {
                            if (pathIndex < fallbackPaths.length - 1) {
                                pathIndex++;
                            }
                        }
                    }
                    
                    Component.onCompleted: {
                        const username = Quickshell.env("USER") || Quickshell.env("USERNAME") || "";
                        const home = Quickshell.env("HOME") || "";
                        const list = [];
                        if (home) {
                            list.push("file://" + home + "/.face");
                            list.push("file://" + home + "/.face.icon");
                        }
                        if (username) {
                            list.push("file:///var/lib/AccountsService/icons/" + username);
                        }
                        list.push("image://icon/user-info");
                        list.push("image://icon/avatar-default");
                        fallbackPaths = list;
                    }
                    
                    visible: false
                    cache: true
                }

                // Watermark container layout with QML States for anchor alignment
                Item {
                    id: previewWatermarkContainer
                    anchors.margins: 16

                    width: previewHybridLayout.implicitWidth
                    height: previewHybridLayout.implicitHeight

                    opacity: watermarkOpacity.value / 100.0

                    states: [
                        State {
                            name: "top_left"
                            when: watermarkPosition.value === "top_left"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.left: watermarkPreviewArea.left
                                anchors.top: watermarkPreviewArea.top
                                anchors.right: undefined
                                anchors.bottom: undefined
                                anchors.horizontalCenter: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "top_right"
                            when: watermarkPosition.value === "top_right"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.right: watermarkPreviewArea.right
                                anchors.top: watermarkPreviewArea.top
                                anchors.left: undefined
                                anchors.bottom: undefined
                                anchors.horizontalCenter: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "bottom_left"
                            when: watermarkPosition.value === "bottom_left"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.left: watermarkPreviewArea.left
                                anchors.bottom: watermarkPreviewArea.bottom
                                anchors.right: undefined
                                anchors.top: undefined
                                anchors.horizontalCenter: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "bottom_right"
                            when: watermarkPosition.value === "bottom_right" || !watermarkPosition.value
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.right: watermarkPreviewArea.right
                                anchors.bottom: watermarkPreviewArea.bottom
                                anchors.left: undefined
                                anchors.top: undefined
                                anchors.horizontalCenter: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "center"
                            when: watermarkPosition.value === "center"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.horizontalCenter: watermarkPreviewArea.horizontalCenter
                                anchors.verticalCenter: watermarkPreviewArea.verticalCenter
                                anchors.left: undefined
                                anchors.right: undefined
                                anchors.top: undefined
                                anchors.bottom: undefined
                            }
                        },
                        State {
                            name: "top"
                            when: watermarkPosition.value === "top"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.horizontalCenter: watermarkPreviewArea.horizontalCenter
                                anchors.top: watermarkPreviewArea.top
                                anchors.left: undefined
                                anchors.right: undefined
                                anchors.bottom: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "bottom"
                            when: watermarkPosition.value === "bottom"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.horizontalCenter: watermarkPreviewArea.horizontalCenter
                                anchors.bottom: watermarkPreviewArea.bottom
                                anchors.left: undefined
                                anchors.right: undefined
                                anchors.top: undefined
                                anchors.verticalCenter: undefined
                            }
                        },
                        State {
                            name: "left"
                            when: watermarkPosition.value === "left"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.left: watermarkPreviewArea.left
                                anchors.verticalCenter: watermarkPreviewArea.verticalCenter
                                anchors.right: undefined
                                anchors.top: undefined
                                anchors.bottom: undefined
                                anchors.horizontalCenter: undefined
                            }
                        },
                        State {
                            name: "right"
                            when: watermarkPosition.value === "right"
                            AnchorChanges {
                                target: previewWatermarkContainer
                                anchors.right: watermarkPreviewArea.right
                                anchors.verticalCenter: watermarkPreviewArea.verticalCenter
                                anchors.left: undefined
                                anchors.top: undefined
                                anchors.bottom: undefined
                                anchors.horizontalCenter: undefined
                            }
                        }
                    ]

                    Row {
                        id: previewHybridLayout
                        spacing: Math.round(previewTextItem.font.pixelSize * 0.4)
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: previewImageItem
                            visible: (watermarkType.value === "image" || watermarkType.value === "hybrid") && previewWatermarkImageLoader.status === Image.Ready
                            source: previewWatermarkImageLoader.source
                            
                            height: {
                                if (previewWatermarkImageLoader.status !== Image.Ready) return 0;
                                const w = previewWatermarkImageLoader.sourceSize.width;
                                const h = previewWatermarkImageLoader.sourceSize.height;
                                const maxW = watermarkPreviewArea.width * (watermarkSize.value / 100.0);
                                const maxH = watermarkPreviewArea.height * (watermarkSize.value / 100.0);
                                const scale = Math.min(maxW / w, maxH / h, 1.0);
                                return h * scale;
                            }
                            
                            width: {
                                if (previewWatermarkImageLoader.status !== Image.Ready) return 0;
                                const w = previewWatermarkImageLoader.sourceSize.width;
                                const h = previewWatermarkImageLoader.sourceSize.height;
                                return (w / h) * height;
                            }
                            
                            fillMode: Image.PreserveAspectFit
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            visible: (watermarkType.value === "image" || watermarkType.value === "hybrid") && previewWatermarkImageLoader.status !== Image.Ready
                            text: watermarkImage.value ? I18n.tr("Image Error") : I18n.tr("No Image Specified")
                            font.pixelSize: Theme.fontSizeSmall
                            color: "#ff6b6b"
                            font.italic: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        StyledText {
                            id: previewTextItem
                            visible: watermarkType.value === "text" || watermarkType.value === "hybrid"
                            text: captureConfig.formatWatermarkText(watermarkText.value || "© {user}")
                            font.pixelSize: Math.max(10, Math.round(watermarkPreviewArea.height * (watermarkTextSize.value / 100.0)))
                            font.bold: true
                            color: "#ffffff"
                            style: Text.Outline
                            styleColor: "#000000"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
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
            text: I18n.tr("Select a color palette preset or customize the color slots individually.")
        }

        Item { width: 1; height: Theme.spacingS }

        SelectionSettingPlus {
            id: palettePresetSetting
            settingKey: "color_palette_preset"
            label: I18n.tr("Palette Preset")
            defaultValue: "adaptive"
            options: [
                { "label": I18n.tr("Adaptive (DMS Theme)"), "value": "adaptive" },
                { "label": I18n.tr("Classic (Tailwind)"), "value": "classic" },
                { "label": I18n.tr("Nord (Pastel Cold)"), "value": "nord" },
                { "label": I18n.tr("Gruvbox (Warm Retro)"), "value": "gruvbox" },
                { "label": I18n.tr("Dracula (High Contrast Dark)"), "value": "dracula" },
                { "label": I18n.tr("Catppuccin"), "value": "catppuccin" },
                { "label": I18n.tr("Custom Colors"), "value": "custom" }
            ]
        }

        ButtonGroupSettingPlus {
            id: catppuccinVariantSetting
            settingKey: "catppuccin_variant"
            label: ""
            defaultValue: "mocha"
            options: [
                { "label": "Latte", "value": "latte" },
                { "label": "Frappé", "value": "frappe" },
                { "label": "Macchiato", "value": "macchiato" },
                { "label": "Mocha", "value": "mocha" }
            ]
            visible: palettePresetSetting.value === "catppuccin"
            height: visible ? implicitHeight : 0
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
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? Theme.primary : null
            }

            CompactColorSetting {
                id: c0
                settingKey: "toolbar_color_0"
                label: I18n.tr("Slot 2")
                defaultValue: captureConfig.defaultAccentColors[0]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[0] : null
            }

            CompactColorSetting {
                id: c1
                settingKey: "toolbar_color_1"
                label: I18n.tr("Slot 3")
                defaultValue: captureConfig.defaultAccentColors[1]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[1] : null
            }

            CompactColorSetting {
                id: c2
                settingKey: "toolbar_color_2"
                label: I18n.tr("Slot 4")
                defaultValue: captureConfig.defaultAccentColors[2]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[2] : null
            }

            CompactColorSetting {
                id: c3
                settingKey: "toolbar_color_3"
                label: I18n.tr("Slot 5")
                defaultValue: captureConfig.defaultAccentColors[3]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[3] : null
            }

            CompactColorSetting {
                id: c4
                settingKey: "toolbar_color_4"
                label: I18n.tr("Slot 6")
                defaultValue: captureConfig.defaultAccentColors[4]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[4] : null
            }

            CompactColorSetting {
                id: c5
                settingKey: "toolbar_color_5"
                label: I18n.tr("Slot 7")
                defaultValue: captureConfig.defaultAccentColors[5]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[5] : null
            }

            CompactColorSetting {
                id: c6
                settingKey: "toolbar_color_6"
                label: I18n.tr("Slot 8")
                defaultValue: captureConfig.defaultAccentColors[6]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? captureConfig.defaultAccentColors[6] : null
            }
        }
    }

    SettingsCard {
        id: radialMenuCard

        property int presetActiveIndex: 0

        property var activePresetTools: ["pen", "arrow", "rect", "highlighter", "ellipse", "stamp", "redact", "pixelate"]
        property var activePresetColors: ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"]
        property var activePresetThicknesses: [6, 6, 6, 6, 6, 6, 6, 6]

        readonly property var currentPresets: {
            const list = [];
            for (let i = 0; i < 8; i++) {
                const tool = radialMenuCard.activePresetTools[i] || "none";
                const color = radialMenuCard.activePresetColors[i] || "primary";
                const thickness = radialMenuCard.activePresetThicknesses[i] ?? 6;
                list.push({ tool: tool, color: color, thickness: thickness });
            }
            return list;
        }

        SectionTitle {
            text: I18n.tr("Radial Menu")
            icon: "settings"
        }

        InfoText {
            text: I18n.tr("Configure up to 8 quick-access tool presets. Right-click anywhere during capture to open the radial menu.")
        }

        Item { width: 1; height: Theme.spacingXS }

        Item { width: 1; height: Theme.spacingXS }

        // Interactive Radial Menu Simulation
        Item {
            id: simulatedRadialMenu
            width: 240
            height: 240
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: root.radialMenuOpacityValue / 100

            readonly property real outerRadius: 110
            readonly property real innerRadius: 40
            readonly property real midRadius: (innerRadius + outerRadius) / 2
            readonly property real itemRadius: 22
            readonly property real centerRadius: 34

            // Segmented Background Canvas
            Canvas {
                id: simulatedCanvas
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);

                    var centerX = width / 2;
                    var centerY = height / 2;
                    var numSectors = 8;
                    var sectorAngle = 2 * Math.PI / numSectors;

                    for (var i = 0; i < numSectors; i++) {
                        var startAngle = i * sectorAngle - Math.PI / 2 - sectorAngle / 2;
                        var endAngle = startAngle + sectorAngle;

                        ctx.beginPath();
                        ctx.arc(centerX, centerY, simulatedRadialMenu.outerRadius, startAngle, endAngle);
                        ctx.arc(centerX, centerY, simulatedRadialMenu.innerRadius, endAngle, startAngle, true);
                        ctx.closePath();

                        // Highlight active segment
                        if (radialMenuCard.presetActiveIndex === i) {
                            ctx.fillStyle = Theme.primary;
                        } else {
                            ctx.fillStyle = Theme.withAlpha(Theme.surfaceContainerHigh, 0.88);
                        }
                        ctx.fill();

                        ctx.strokeStyle = radialMenuCard.presetActiveIndex === i ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15);
                        ctx.lineWidth = radialMenuCard.presetActiveIndex === i ? 2 : 1;
                        ctx.stroke();
                    }
                }

                // Redraw on active index changes
                Connections {
                    target: radialMenuCard
                    function onPresetActiveIndexChanged() { simulatedCanvas.requestPaint(); }
                }
                
                // Redraw on preset changes (color or tool changed in settings)
                Connections {
                    target: radialMenuCard
                    function onCurrentPresetsChanged() { simulatedCanvas.requestPaint(); }
                }
                
                Component.onCompleted: simulatedCanvas.requestPaint()
            }

            // Outer circle outline
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: "transparent"
                border.color: Theme.withAlpha(Theme.outline, 0.25)
                border.width: 1.5
            }

            // Outer icons overlay
            Repeater {
                model: radialMenuCard.currentPresets

                delegate: Item {
                    width: simulatedRadialMenu.itemRadius * 2
                    height: width
                    
                    property real angle: (index * 360 / 8) - 90
                    property real rad: angle * Math.PI / 180
                    
                    x: (simulatedRadialMenu.width / 2) + simulatedRadialMenu.midRadius * Math.cos(rad) - simulatedRadialMenu.itemRadius
                    y: (simulatedRadialMenu.height / 2) + simulatedRadialMenu.midRadius * Math.sin(rad) - simulatedRadialMenu.itemRadius

                    Column {
                        anchors.centerIn: parent
                        spacing: 1

                        StyledText {
                            text: (index + 1)
                            font.pixelSize: 8
                            font.bold: true
                            color: radialMenuCard.presetActiveIndex === index ? Theme.onPrimary : Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.6
                        }

                        DankIcon {
                            name: {
                                const tool = captureConfig.toolButtons.find(t => t.id === modelData.tool);
                                return tool ? tool.icon : "help";
                            }
                            size: 18
                            color: {
                                if (radialMenuCard.presetActiveIndex === index) return Theme.onPrimary;
                                if (modelData.tool === "none") return Theme.withAlpha(Theme.surfaceVariantText, 0.3);
                                return captureConfig.resolveColor(modelData.color);
                            }
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }

            // Center Info Button
            Rectangle {
                id: simulatedCenterButton
                width: simulatedRadialMenu.centerRadius * 2
                height: width
                radius: simulatedRadialMenu.centerRadius
                anchors.centerIn: parent
                color: Theme.surfaceContainerHighest
                border.color: Theme.withAlpha(Theme.outline, 0.4)
                border.width: 1

                Column {
                    anchors.centerIn: parent
                    spacing: 1
                    
                    DankIcon {
                        name: {
                            const p = radialMenuCard.currentPresets[radialMenuCard.presetActiveIndex];
                            if (p && p.tool !== "none") {
                                const tool = captureConfig.toolButtons.find(t => t.id === p.tool);
                                return tool ? tool.icon : "check";
                            }
                            return "block";
                        }
                        size: 20
                        color: {
                            const p = radialMenuCard.currentPresets[radialMenuCard.presetActiveIndex];
                            if (!p || p.tool === "none") return Theme.surfaceVariantText;
                            return captureConfig.resolveColor(p.color);
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: I18n.tr("Preset %1").arg(radialMenuCard.presetActiveIndex + 1)
                        font.pixelSize: 8
                        font.bold: true
                        color: Theme.surfaceVariantText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            // Mouse Area to click segments
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true

                onPositionChanged: (mouse) => {
                    const dx = mouse.x - width / 2;
                    const dy = mouse.y - height / 2;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    
                    if (dist < simulatedRadialMenu.innerRadius || dist > simulatedRadialMenu.outerRadius) {
                        return;
                    }

                    let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
                    if (angle < 0) angle += 360;
                    
                    const numSectors = 8;
                    const sectorSize = 360 / numSectors;
                    const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);
                    
                    if (idx >= 0 && idx < numSectors && radialMenuCard.presetActiveIndex !== idx) {
                        radialMenuCard.presetActiveIndex = idx;
                    }
                }

                onClicked: (mouse) => {
                    const dx = mouse.x - width / 2;
                    const dy = mouse.y - height / 2;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    
                    if (dist < simulatedRadialMenu.innerRadius || dist > simulatedRadialMenu.outerRadius) {
                        return;
                    }

                    let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
                    if (angle < 0) angle += 360;
                    
                    const numSectors = 8;
                    const sectorSize = 360 / numSectors;
                    const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);
                    
                    if (idx >= 0 && idx < numSectors) {
                        radialMenuCard.presetActiveIndex = idx;
                    }
                }
            }
        }



        Repeater {
            model: 8

            Column {
                id: presetDelegate
                width: parent.width
                spacing: Theme.spacingM
                visible: radialMenuCard.presetActiveIndex === index
                readonly property int presetIndex: index

                Item { width: 1; height: Theme.spacingXS }

                SelectionSettingPlus {
                    settingKey: "preset_" + index + "_tool"
                    label: I18n.tr("Preset Tool")
                    onValueChanged: {
                        radialMenuCard.activePresetTools[index] = value;
                        radialMenuCard.activePresetTools = [...radialMenuCard.activePresetTools];
                    }
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
                    defaultValue: {
                        if (index === 0) return "pen";
                        if (index === 1) return "arrow";
                        if (index === 2) return "rect";
                        if (index === 3) return "highlighter";
                        if (index === 4) return "ellipse";
                        if (index === 5) return "stamp";
                        if (index === 6) return "redact";
                        if (index === 7) return "pixelate";
                        return "none";
                    }
                }

                Separator {}

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.tr("Preset Color")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    // Row containing 8 Slots + Separator + Custom Swatch & Optional Color Bar
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        // 1. 8 Slots
                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: 8
                                delegate: Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: {
                                        if (index === 0) return toolbar_primary.resolvedColor;
                                        if (index === 1) return c0.resolvedColor;
                                        if (index === 2) return c1.resolvedColor;
                                        if (index === 3) return c2.resolvedColor;
                                        if (index === 4) return c3.resolvedColor;
                                        if (index === 5) return c4.resolvedColor;
                                        if (index === 6) return c5.resolvedColor;
                                        if (index === 7) return c6.resolvedColor;
                                        return "transparent";
                                    }

                                    property bool isSelected: presetColorSetting.value === "slot_" + (index + 1)
                                    border.width: isSelected ? 2 : 1
                                    border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.4)
                                    scale: hoverArea.containsMouse ? 1.1 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 100 } }

                                    DankIcon {
                                        anchors.centerIn: parent
                                        name: "check"
                                        size: 14
                                        color: (parent.color.r * 0.299 + parent.color.g * 0.587 + parent.color.b * 0.114) > 0.6 ? "#000000" : "#ffffff"
                                        visible: parent.isSelected
                                    }

                                    MouseArea {
                                        id: hoverArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            presetColorSetting.value = "slot_" + (index + 1);
                                            radialMenuCard.activePresetColors[presetIndex] = presetColorSetting.value;
                                            radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                                        }
                                    }
                                }
                            }
                        }

                        // Small separator bar
                        Rectangle {
                            width: 1
                            height: 20
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // 2. Custom Option and Bar Row
                        Row {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            // Custom button swatch
                            Rectangle {
                                id: customSwatch
                                width: 28
                                height: 28
                                radius: 14
                                property bool isSelected: !presetColorSetting.value.startsWith("slot_")
                                color: isSelected ? captureConfig.resolveColor(presetColorSetting.value) : Theme.surfaceContainerHighest
                                border.width: isSelected ? 2 : 1
                                border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.4)
                                scale: customHover.containsMouse ? 1.1 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100 } }

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: "palette"
                                    size: 14
                                    color: {
                                        if (!parent.isSelected) return Theme.surfaceText;
                                        return (parent.color.r * 0.299 + parent.color.g * 0.587 + parent.color.b * 0.114) > 0.6 ? "#000000" : "#ffffff";
                                    }
                                }

                                MouseArea {
                                    id: customHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!parent.isSelected) {
                                            presetColorSetting.value = "primary";
                                            radialMenuCard.activePresetColors[presetIndex] = presetColorSetting.value;
                                            radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                                        }
                                    }
                                }
                            }

                            // Dynamic Custom Color Bar directly to the right
                            Rectangle {
                                id: customColorBar
                                width: 110
                                height: 28
                                radius: 14
                                visible: !presetColorSetting.value.startsWith("slot_")
                                color: captureConfig.resolveColor(presetColorSetting.value)
                                border.color: Theme.withAlpha(Theme.surfaceText, 0.15)
                                border.width: 1

                                StyledText {
                                    anchors.centerIn: parent
                                    text: presetColorSetting.value === "primary" ? I18n.tr("PRIMARY") : presetColorSetting.value.toString().toUpperCase()
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: Font.Bold
                                    isMonospace: true
                                    color: (parent.color.r * 0.299 + parent.color.g * 0.587 + parent.color.b * 0.114) > 0.6 ? "#000000" : "#ffffff"
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                                            PopoutService.colorPickerModal.selectedColor = captureConfig.resolveColor(presetColorSetting.value);
                                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Preset Color");
                                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                                presetColorSetting.value = selectedColor.toString();
                                                radialMenuCard.activePresetColors[presetIndex] = presetColorSetting.value;
                                                radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                                            };
                                            PopoutService.colorPickerModal.show();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hidden headless ColorSettingPlus to load/save settings automatically
                    Item {
                        width: 0; height: 0
                        visible: false

                        ColorSettingPlus {
                            id: presetColorSetting
                            settingKey: "preset_" + presetIndex + "_color"
                            label: ""
                            onValueChanged: {
                                radialMenuCard.activePresetColors[presetIndex] = value;
                                radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                            }
                            defaultValue: {
                                if (presetIndex === 6) return "#000000"; // Black
                                if (presetIndex === 7) return "#ffffff"; // White
                                return "primary";
                            }
                        }
                    }
                }

                Separator {}

                SliderSettingPlus {
                    settingKey: "preset_" + index + "_thickness"
                    label: I18n.tr("Preset Thickness")
                    onValueChanged: {
                        radialMenuCard.activePresetThicknesses[index] = value;
                        radialMenuCard.activePresetThicknesses = [...radialMenuCard.activePresetThicknesses];
                    }
                    defaultValue: 6
                    minimum: 1
                    maximum: 20
                    leftLabel: "1"
                    rightLabel: "20"
                    previewType: "thickness"
                    previewColor: presetColorSetting.value
                }
            }
        }
    }
 
    SettingsCard {
        id: radialBehaviorsCard
        SectionTitle {
            text: I18n.tr("Radial Menu Settings")
            icon: "mouse"
            showReset: radialHoverTrigger.isDirty || radialHoverDelay.isDirty || radialMenuOpacity.isDirty
            onResetClicked: {
                radialHoverTrigger.resetToDefault();
                radialHoverDelay.resetToDefault();
                radialMenuOpacity.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: radialHoverTrigger
            settingKey: "radialHoverTrigger"
            label: I18n.tr("Trigger on Hover")
            description: I18n.tr("Select a tool preset automatically by hovering over it, without needing to release the mouse click.")
            defaultValue: false
        }

        Separator {
            visible: radialHoverTrigger.value
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: radialHoverDelay
            settingKey: "radialHoverDelay"
            label: I18n.tr("Hover Trigger Delay")
            defaultValue: 300
            minimum: 100
            maximum: 1000
            leftLabel: "100"
            rightLabel: "1000"
            unit: "ms"
            visible: radialHoverTrigger.value
            height: visible ? implicitHeight : 0
        }

        Separator {}

        SliderSettingPlus {
            id: radialMenuOpacity
            settingKey: "radialMenuOpacity"
            label: I18n.tr("Radial Menu Opacity")
            defaultValue: 100
            minimum: 0
            maximum: 100
            leftLabel: "0"
            rightLabel: "100"
            unit: "%"

            Binding {
                target: root
                property: "radialMenuOpacityValue"
                value: radialMenuOpacity.value
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

        Column {
            width: parent.width
            spacing: Theme.spacingM
            visible: usageTitle.isExpanded

            StyledText {
                text: I18n.tr("Bar Interactions")
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.primary
            }

            Column {
                width: parent.width
                spacing: 2

                ShortcutRow { keyText: I18n.tr("Action"); actionText: I18n.tr("Interaction / Result"); isHeader: true }
                ShortcutRow { keyText: I18n.tr("Left Click"); actionText: I18n.tr("Start interactive screenshot capture") }
                ShortcutRow { keyText: I18n.tr("Right Click"); actionText: I18n.tr("Open file browser to select image") }
                ShortcutRow { keyText: I18n.tr("Drag Image"); actionText: I18n.tr("Drop image onto icon to annotate") }
            }

            Separator { opacity: 0.1 }

            StyledText {
                text: I18n.tr("Annotation Tools")
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.primary
            }

            Column {
                width: parent.width
                spacing: 2

                ShortcutRow { keyText: I18n.tr("Key"); actionText: I18n.tr("Selected Tool / Action"); isHeader: true }
                ShortcutRow { keyText: "V"; actionText: I18n.tr("Select / Move stroke") }
                ShortcutRow { keyText: "1 - 4"; actionText: I18n.tr("Pen, Line, Arrow, Rect") }
                ShortcutRow { keyText: "Q - R"; actionText: I18n.tr("Ellipse, Text, Pixelate, Redact (Q, W, E, R)") }
                ShortcutRow { keyText: "A - D"; actionText: I18n.tr("Stamp, Highlighter, Eraser (A, S, D)") }
            }

            Separator { opacity: 0.1 }

            StyledText {
                text: I18n.tr("General Shortcuts")
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.primary
            }

            Column {
                width: parent.width
                spacing: 2

                ShortcutRow { keyText: I18n.tr("Key"); actionText: I18n.tr("Shortcut Action"); isHeader: true }
                ShortcutRow { keyText: "Enter"; actionText: I18n.tr("Done (Action based on settings)") }
                ShortcutRow { keyText: "Esc"; actionText: I18n.tr("Discard & Close") }
                ShortcutRow { keyText: "Ctrl + Z"; actionText: I18n.tr("Undo last stroke") }
                ShortcutRow { keyText: "Ctrl + S"; actionText: I18n.tr("Force Save to File") }
                ShortcutRow { keyText: "Ctrl + C"; actionText: I18n.tr("Force Copy to Clipboard") }
                ShortcutRow { keyText: "Ctrl + A"; actionText: I18n.tr("Force Copy & Save") }
                ShortcutRow { keyText: "Ctrl + F"; actionText: I18n.tr("Float Image") }
                ShortcutRow { keyText: "Ctrl + X"; actionText: I18n.tr("Crop / Resize Area") }
                ShortcutRow { keyText: "Ctrl + 1..4"; actionText: I18n.tr("Select Color Slots 1 - 4") }
                ShortcutRow { keyText: "Ctrl + Q..R"; actionText: I18n.tr("Select Color Slots 5 - 8 (Q, W, E, R)") }
            }
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
                label: I18n.tr("Trigger Screenshot (Default)")
                text: "dms ipc call quickCapture screenshot default"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (Interactive Region)")
                text: "dms ipc call quickCapture screenshot region"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (Full Screen)")
                text: "dms ipc call quickCapture screenshot full"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (All Combined Outputs)")
                text: "dms ipc call quickCapture screenshot all"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (Specific Output)")
                text: "dms ipc call quickCapture screenshot output"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (Focused Window)")
                text: "dms ipc call quickCapture screenshot window"
            }

            CopyBox {
                label: I18n.tr("Trigger Screenshot (Last Selected Region)")
                text: "dms ipc call quickCapture screenshot last"
            }

            CopyBox {
                label: I18n.tr("Select Image File")
                text: "dms ipc call quickCapture selectFile"
            }

            CopyBox {
                label: I18n.tr("Edit Image from Clipboard")
                text: "dms ipc call quickCapture fromClipboard"
            }

            CopyBox {
                label: I18n.tr("Open Specific Image Path")
                text: "dms ipc call quickCapture openImage /path/to/image.png"
            }

            CopyBox {
                label: I18n.tr("Close Annotator")
                text: "dms ipc call quickCapture close"
            }

            Separator { opacity: 0.1 }

            CopyBox {
                label: I18n.tr("Niri Binding Example")
                text: "binds {\n    Print { spawn \"dms\" \"ipc\" \"call\" \"quickCapture\" \"screenshot\" \"default\"; }\n}"
            }
        }
    }

    CaptureConfig {
        id: captureConfig
        pluginData: {
            "color_palette_preset": palettePresetSetting.value,
            "catppuccin_variant": catppuccinVariantSetting.value,
            "tabBehavior": tabBehavior.value,
            "toolbar_color_primary": toolbar_primary.value,
            "toolbar_color_0": c0.value,
            "toolbar_color_1": c1.value,
            "toolbar_color_2": c2.value,
            "toolbar_color_3": c3.value,
            "toolbar_color_4": c4.value,
            "toolbar_color_5": c5.value,
            "toolbar_color_6": c6.value
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-quick-capture"
    }

}
