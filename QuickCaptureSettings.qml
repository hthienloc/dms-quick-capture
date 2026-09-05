import "./dms-common"
import "components/core/Constants.js" as Constants
import "components/core/Helpers.js" as Helpers
import "components/misc"
import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    property int radialMenuOpacityValue: 100

    readonly property var daemon: (pluginService && pluginService.pluginInstances && pluginService.pluginInstances[pluginId]) ? pluginService.pluginInstances[pluginId] : null
    property var audioInputsList: daemon && daemon.audioInputsList && daemon.audioInputsList.length > 0
        ? daemon.audioInputsList
        : [{"label": I18n.trFor("quickCapture", "Default Microphone"), "value": "default_input"}]
    property var audioOutputsList: daemon && daemon.audioOutputsList && daemon.audioOutputsList.length > 0
        ? daemon.audioOutputsList
        : [{"label": I18n.trFor("quickCapture", "Default Output"), "value": "default_output"}]

    function refreshAudioDevices() {
        if (daemon && typeof daemon.refreshAudioDevices === "function") {
            daemon.refreshAudioDevices();
        }
        Proc.runCommand("quickCapture.listAudioDevices", ["gpu-screen-recorder", "--list-audio-devices"], (stdout, exitCode) => {
            const inputs = [{"label": I18n.trFor("quickCapture", "Default Microphone"), "value": "default_input"}];
            const outputs = [{"label": I18n.trFor("quickCapture", "Default Output"), "value": "default_output"}];

            if (exitCode === 0 && stdout) {
                const lines = stdout.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    const parts = line.split("|");
                    if (parts.length >= 2) {
                        const name = parts[0];
                        const label = parts[1];
                        if (name.includes(".monitor") || name.includes("output") || name === "default_output") {
                            if (name !== "default_output") {
                                outputs.push({ "label": label, "value": name });
                            }
                        } else {
                            if (name !== "default_input") {
                                inputs.push({ "label": label, "value": name });
                            }
                        }
                    }
                }
            }
            root.audioInputsList = inputs;
            root.audioOutputsList = outputs;
        });
    }

    Component.onCompleted: {
        root.refreshAudioDevices();
    }

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
        readonly property bool isDirty: value.toString() !== defaultValue.toString() || colorModeSetting.isDirty

        readonly property color resolvedColor: {
            if (overrideColor !== null) return Qt.color(overrideColor);
            if (value === "primary") return Theme.primary;
            return Qt.color(value);
        }

        function resetToDefault() {
            value = defaultValue;
            colorModeSetting.resetToDefault();
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
                            : (swatchRoot.value === "primary" ? I18n.trFor("quickCapture", "Theme Primary Color") : swatchRoot.value.toString().toUpperCase());
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
                            Proc.runCommand("copy-color", ["dms", "cl", "copy", colorStr], function() {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.trFor("quickCapture", "Copied:") + " " + colorStr.toUpperCase());
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


    component BackgroundColorSetting : Column {
        id: bcsRoot
        required property string settingKey
        required property string label
        property var defaultValue: "primary"
        property var value: defaultValue
        
        property bool isInitialized: false
        readonly property bool isDirty: value.toString() !== defaultValue.toString()
        
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

        width: parent.width
        spacing: Theme.spacingS

        ButtonGroupSettingPlus {
            id: colorModeSetting
            settingKey: bcsRoot.settingKey + "Mode"
            label: bcsRoot.label
            options: [
                { label: I18n.trFor("quickCapture", "Custom"), value: "custom" },
                { label: I18n.trFor("quickCapture", "Adaptive"), value: "adaptive" }
            ]
            defaultValue: "custom"
        }

        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: colorModeSetting.value === "custom"

            ColorPalettePicker {
                id: colorPicker
                slotColors: [toolbar_primary.resolvedColor, c0.resolvedColor, c1.resolvedColor,
                    c2.resolvedColor, c3.resolvedColor, c4.resolvedColor, c5.resolvedColor, c6.resolvedColor]
                value: bcsRoot.value
                customColor: captureConfig.resolveColor(bcsRoot.value)
                customLabel: bcsRoot.value === "primary" ? I18n.trFor("quickCapture", "PRIMARY") : bcsRoot.value.toString().toUpperCase()
                onValueSelected: selectedValue => bcsRoot.value = selectedValue
                onCustomRequested: {
                    if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                        PopoutService.colorPickerModal.selectedColor = captureConfig.resolveColor(bcsRoot.value);
                        PopoutService.colorPickerModal.pickerTitle = bcsRoot.label;
                        PopoutService.colorPickerModal.onColorSelectedCallback = selectedColor => bcsRoot.value = selectedColor.toString();
                        PopoutService.colorPickerModal.show();
                    }
                }
            }
        }
    }


    // ── Tab Navigation ─────────────────────────────────────────────────────────
    Item {
        id: tabBar
        width: parent.width
        height: tabFlow.implicitHeight + Theme.spacingM * 2

        property int currentIndex: 0

        Flow {
            id: tabFlow
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                topMargin: Theme.spacingM
                leftMargin: Theme.spacingM
                rightMargin: Theme.spacingM
            }
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { label: I18n.trFor("quickCapture", "Capture"),       icon: "camera"             },
                    { label: I18n.trFor("quickCapture", "Recording"),     icon: "videocam"           },
                    { label: I18n.trFor("quickCapture", "Saving"),        icon: "save"               },
                    { label: I18n.trFor("quickCapture", "Notifications"), icon: "notifications"      },
                    { label: I18n.trFor("quickCapture", "Toolbar"),       icon: "dock"               },
                    { label: I18n.trFor("quickCapture", "Color Palette"),  icon: "palette"            },
                    { label: I18n.trFor("quickCapture", "Editor"),        icon: "aspect_ratio"       },
                    { label: I18n.trFor("quickCapture", "Tool Defaults"), icon: "tune"               },
                    { label: I18n.trFor("quickCapture", "Text"),          icon: "format_size"        },
                    { label: I18n.trFor("quickCapture", "Shapes"),        icon: "category"           },
                    { label: I18n.trFor("quickCapture", "Background"),      icon: "wallpaper"          },
                    { label: I18n.trFor("quickCapture", "Watermark"),     icon: "branding_watermark" },
                    { label: I18n.trFor("quickCapture", "Float Window"),  icon: "open_in_new"        },
                    { label: I18n.trFor("quickCapture", "Radial Menu"),   icon: "mouse"              },
                    { label: I18n.trFor("quickCapture", "Shortcuts"),     icon: "keyboard"           },
                    { label: I18n.trFor("quickCapture", "Help"),          icon: "menu_book"          }
                ]

                delegate: Rectangle {
                    id: chipDelegate
                    required property var modelData
                    required property int index
                    property bool active: tabBar.currentIndex === index

                    height: 32
                    width: chipRow.implicitWidth + 24
                    radius: 16
                    color: active
                        ? Theme.withAlpha(Theme.primary, 0.18)
                        : (chipMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : Theme.withAlpha(Theme.outline, 0.12))
                    border.color: active 
                        ? Theme.primary 
                        : (chipMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.6) : "transparent")
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                    Behavior on border.color { ColorAnimation { duration: Theme.shortDuration } }

                    Row {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6

                        DankIcon {
                            name: chipDelegate.modelData.icon
                            size: 15
                            color: chipDelegate.active ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                        }

                        StyledText {
                            text: chipDelegate.modelData.label
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: chipDelegate.active ? Font.Medium : Font.Normal
                            color: chipDelegate.active ? Theme.primary : Theme.surfaceVariantText
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: Theme.shortDuration } }
                        }
                    }

                    MouseArea {
                        id: chipMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tabBar.currentIndex = chipDelegate.index
                    }
                }
            }
        }
    }

    // ── Tab 0: Capture ─────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 0
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: captureTabCol.implicitHeight
        Column {
            id: captureTabCol
            width: parent.width
            spacing: Theme.spacingM
    SettingsCard {
        id: captureActionsCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Capture Actions")
            icon: "mouse"
            showReset: middleClickAction.isDirty || rightClickAction.isDirty || menuRightClickAction.isDirty
            onResetClicked: {
                middleClickAction.resetToDefault();
                rightClickAction.resetToDefault();
                menuRightClickAction.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: middleClickAction
            settingKey: "middleClickAction"
            label: I18n.trFor("quickCapture", "Middle Click Action")
            options: [
                { label: I18n.trFor("quickCapture", "Interactive Region"), value: "region" },
                { label: I18n.trFor("quickCapture", "Full Screen"), value: "full" },
                { label: I18n.trFor("quickCapture", "All Combined Outputs"), value: "all" },
                { label: I18n.trFor("quickCapture", "Specific Output"), value: "output" },
                { label: I18n.trFor("quickCapture", "Focused Window"), value: "window" },
                { label: I18n.trFor("quickCapture", "Last Selected Region"), value: "last" },
                { label: I18n.trFor("quickCapture", "Scrolling Capture"), value: "scroll" },
                { label: I18n.trFor("quickCapture", "From Clipboard"), value: "clipboard" },
                { label: I18n.trFor("quickCapture", "From File"), value: "selectFile" }
            ]
            defaultValue: "region"
        }

        SelectionSettingPlus {
            id: rightClickAction
            settingKey: "rightClickAction"
            label: I18n.trFor("quickCapture", "Right Click Action")
            options: [
                { label: I18n.trFor("quickCapture", "From Clipboard"), value: "clipboard" },
                { label: I18n.trFor("quickCapture", "From File"), value: "selectFile" },
                { label: I18n.trFor("quickCapture", "Interactive Region"), value: "region" },
                { label: I18n.trFor("quickCapture", "Full Screen"), value: "full" },
                { label: I18n.trFor("quickCapture", "All Combined Outputs"), value: "all" },
                { label: I18n.trFor("quickCapture", "Specific Output"), value: "output" },
                { label: I18n.trFor("quickCapture", "Focused Window"), value: "window" },
                { label: I18n.trFor("quickCapture", "Last Selected Region"), value: "last" },
                { label: I18n.trFor("quickCapture", "Scrolling Capture"), value: "scroll" }
            ]
            defaultValue: "clipboard"
        }

        SelectionSettingPlus {
            id: menuRightClickAction
            settingKey: "menuRightClickAction"
            label: I18n.trFor("quickCapture", "Menu Item Right Click")
            options: [
                { label: I18n.trFor("quickCapture", "Copy"), value: "copy" },
                { label: I18n.trFor("quickCapture", "Save"), value: "save" },
                { label: I18n.trFor("quickCapture", "Copy & Save"), value: "copyAndSave" },
                { label: I18n.trFor("quickCapture", "Float"), value: "float" }
            ]
            defaultValue: "copy"
        }
    }

    SettingsCard {
        id: captureOptionsCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Capture Options")
            icon: "settings"
            showReset: outputTargetName.isDirty || defaultHideControlCenter.isDirty || skipConfirm.isDirty || includeCursor.isDirty || resetLastRegion.isDirty
            onResetClicked: {
                outputTargetName.resetToDefault();
                defaultHideControlCenter.resetToDefault();
                skipConfirm.resetToDefault();
                includeCursor.resetToDefault();
                resetLastRegion.resetToDefault();
            }
        }

        StringSettingPlus {
            id: outputTargetName
            settingKey: "outputTargetName"
            label: I18n.trFor("quickCapture", "Target Output Name")
            placeholder: "e.g. eDP-1"
            defaultValue: ""
        }

        Separator {}

        ToggleSettingPlus {
            id: skipConfirm
            settingKey: "skipConfirm"
            label: I18n.trFor("quickCapture", "Skip Confirmation")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: includeCursor
            settingKey: "includeCursor"
            label: I18n.trFor("quickCapture", "Include Cursor")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: defaultHideControlCenter
            settingKey: "defaultHideControlCenter"
            label: I18n.trFor("quickCapture", "Hide Control Center by Default")
            description: I18n.trFor("quickCapture", "Initial state for the Control Center toggle.")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            id: resetLastRegion
            settingKey: "resetLastRegion"
            label: I18n.trFor("quickCapture", "Reset Last Region")
            description: I18n.trFor("quickCapture", "Clear saved region selection before each capture")
            defaultValue: false
        }

        Separator {}

        Item {
            width: parent.width
            height: warningScrollRow.implicitHeight + 4

            Row {
                id: warningScrollRow
                width: parent.width
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    id: scrollCaptureInfoIcon
                    name: "info"
                    size: 16
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - scrollCaptureInfoIcon.width - warningScrollRow.spacing
                    text: I18n.trFor("quickCapture", "Scroll capture: select a region, scroll content, then press Enter to finish.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    wrapMode: Text.Wrap
                }
            }
        }

        SliderSettingPlus {
            id: scrollInterval
            settingKey: "scrollInterval"
            label: I18n.trFor("quickCapture", "Scroll Interval")
            defaultValue: 500
            minimum: 200
            maximum: 2000
            unit: "ms"
            leftLabel: "200"
            rightLabel: "2000"
        }
    }

        }
    }

    // ── Tab 1: Recording ───────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 1
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: recordingTabCol.implicitHeight
        Column {
            id: recordingTabCol
            width: parent.width
            spacing: Theme.spacingM

            SettingsCard {
                id: recordingVideoCard
                SectionTitle {
                    text: I18n.trFor("quickCapture", "Video Settings")
                    icon: "videocam"
                    showReset: recordingDirectory.isDirty || recordingScreenTarget.isDirty || recordingFormat.isDirty || recordingGifFramerate.isDirty || recordingFramerate.isDirty || recordingQuality.isDirty || recordingCodec.isDirty || recordCursor.isDirty
                    onResetClicked: {
                        recordingDirectory.resetToDefault();
                        recordingScreenTarget.resetToDefault();
                        recordingFormat.resetToDefault();
                        recordingGifFramerate.resetToDefault();
                        recordingFramerate.resetToDefault();
                        recordingQuality.resetToDefault();
                        recordingCodec.resetToDefault();
                        recordCursor.resetToDefault();
                    }
                }

                StringSettingPlus {
                    id: recordingDirectory
                    settingKey: "recordingDirectory"
                    label: I18n.trFor("quickCapture", "Recordings Directory")
                    placeholder: "~/Videos/Recordings"
                    defaultValue: "~/Videos/Recordings"
                    isDirectory: true
                }

                Separator {}

                SelectionSettingPlus {
                    id: recordingScreenTarget
                    settingKey: "recordingScreenTarget"
                    label: I18n.trFor("quickCapture", "Full Screen Target")
                    description: I18n.trFor("quickCapture", "Choose which monitor to capture during full screen recording.")
                    options: {
                        const list = [
                            { label: I18n.trFor("quickCapture", "Primary Screen"), value: "screen" },
                            { label: I18n.trFor("quickCapture", "Focused Screen"), value: "focused" }
                        ];
                        if (Quickshell.screens) {
                            for (let i = 0; i < Quickshell.screens.length; i++) {
                                const scr = Quickshell.screens[i];
                                if (scr && scr.name) {
                                    list.push({
                                        label: I18n.trFor("quickCapture", "Screen: %1 (%2x%3)").arg(scr.name).arg(scr.width).arg(scr.height),
                                        value: scr.name
                                    });
                                }
                            }
                        }
                        return list;
                    }
                    defaultValue: "screen"
                }

                Separator {}

                ButtonGroupSettingPlus {
                    id: recordingFormat
                    settingKey: "recordingFormat"
                    label: I18n.trFor("quickCapture", "Container Format")
                    options: [
                        { label: "MP4", value: "mp4" },
                        { label: "MKV", value: "mkv" },
                        { label: "WebM", value: "webm" },
                        { label: "FLV", value: "flv" },
                        { label: "GIF", value: "gif" }
                    ]
                    defaultValue: "mp4"
                }

                Separator {
                    visible: recordingFormat.value === "gif"
                }

                ButtonGroupSettingPlus {
                    id: recordingGifFramerate
                    settingKey: "recordingGifFramerate"
                    label: I18n.trFor("quickCapture", "GIF Framerate")
                    visible: recordingFormat.value === "gif"
                    options: [
                        { label: "10 FPS", value: "10" },
                        { label: "15 FPS", value: "15" },
                        { label: "24 FPS", value: "24" },
                        { label: "30 FPS", value: "30" }
                    ]
                    defaultValue: "15"
                }

                Separator {}

                ButtonGroupSettingPlus {
                    id: recordingFramerate
                    settingKey: "recordingFramerate"
                    label: I18n.trFor("quickCapture", "Framerate")
                    options: [
                        { label: "30 FPS", value: "30" },
                        { label: "60 FPS", value: "60" },
                        { label: "120 FPS", value: "120" }
                    ]
                    defaultValue: "60"
                }

                Separator {}

                SelectionSettingPlus {
                    id: recordingQuality
                    settingKey: "recordingQuality"
                    label: I18n.trFor("quickCapture", "Video Quality")
                    options: [
                        { label: I18n.trFor("quickCapture", "Very High"), value: "very_high" },
                        { label: I18n.trFor("quickCapture", "High"), value: "high" },
                        { label: I18n.trFor("quickCapture", "Medium"), value: "medium" },
                        { label: I18n.trFor("quickCapture", "Low"), value: "low" }
                    ]
                    defaultValue: "medium"
                }

                Separator {}

                SelectionSettingPlus {
                    id: recordingCodec
                    settingKey: "recordingCodec"
                    label: I18n.trFor("quickCapture", "Video Codec")
                    options: [
                        { label: I18n.trFor("quickCapture", "Auto Detect"), value: "auto" },
                        { label: "H.264", value: "h264" },
                        { label: "HEVC (H.265)", value: "hevc" },
                        { label: "AV1", value: "av1" },
                        { label: "VP8", value: "vp8" },
                        { label: "VP9", value: "vp9" }
                    ]
                    defaultValue: "auto"
                }

                Separator {}

                ToggleSettingPlus {
                    id: recordCursor
                    settingKey: "recordCursor"
                    label: I18n.trFor("quickCapture", "Record Mouse Cursor")
                    defaultValue: true
                }
            }

            SettingsCard {
                id: recordingAudioCard
                SectionTitle {
                    text: I18n.trFor("quickCapture", "Audio & Overlay")
                    icon: "graphic_eq"
                    showReset: recordSystemAudio.isDirty || systemAudioDevice.isDirty || recordMic.isDirty || micDevice.isDirty || audioCodec.isDirty || showPillBorder.isDirty || blinkRecordDot.isDirty || showRegionBorder.isDirty
                    onResetClicked: {
                        recordSystemAudio.resetToDefault();
                        systemAudioDevice.resetToDefault();
                        recordMic.resetToDefault();
                        micDevice.resetToDefault();
                        audioCodec.resetToDefault();
                        showPillBorder.resetToDefault();
                        blinkRecordDot.resetToDefault();
                        showRegionBorder.resetToDefault();
                    }
                }

                ToggleSettingPlus {
                    id: recordSystemAudio
                    settingKey: "recordSystemAudio"
                    label: I18n.trFor("quickCapture", "Record System Audio")
                    defaultValue: true
                }

                SelectionSettingPlus {
                    id: systemAudioDevice
                    settingKey: "systemAudioDevice"
                    label: I18n.trFor("quickCapture", "System Audio Device")
                    options: root.audioOutputsList
                    defaultValue: "default_output"
                    visible: recordSystemAudio.value === true
                }

                Separator {
                    visible: recordSystemAudio.value === true
                }

                ToggleSettingPlus {
                    id: recordMic
                    settingKey: "recordMic"
                    label: I18n.trFor("quickCapture", "Record Microphone")
                    defaultValue: false
                }

                SelectionSettingPlus {
                    id: micDevice
                    settingKey: "micDevice"
                    label: I18n.trFor("quickCapture", "Microphone Device")
                    options: root.audioInputsList
                    defaultValue: "default_input"
                    visible: recordMic.value === true
                }

                Separator {
                    visible: recordMic.value === true
                }

                ButtonGroupSettingPlus {
                    id: audioCodec
                    settingKey: "audioCodec"
                    label: I18n.trFor("quickCapture", "Audio Codec")
                    options: [
                        { label: "Opus", value: "opus" },
                        { label: "AAC", value: "aac" },
                        { label: "FLAC", value: "flac" }
                    ]
                    defaultValue: "opus"
                }

                Separator {}

                ToggleSettingPlus {
                    id: showPillBorder
                    settingKey: "showPillBorder"
                    label: I18n.trFor("quickCapture", "Show Pill Border")
                    defaultValue: false
                }

                Separator {}

                ToggleSettingPlus {
                    id: blinkRecordDot
                    settingKey: "blinkRecordDot"
                    label: I18n.trFor("quickCapture", "Blink Recording Dot")
                    defaultValue: true
                }

                Separator {}

                ToggleSettingPlus {
                    id: showRegionBorder
                    settingKey: "showRegionBorder"
                    label: I18n.trFor("quickCapture", "Show Region Border")
                    defaultValue: true
                }

            }
        }
    }

    // ── Tab 2: Save ────────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 2
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: saveTabCol.implicitHeight
        Column {
            id: saveTabCol
            width: parent.width
            spacing: Theme.spacingM
    SettingsCard {
        id: saveOptionsCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Saving")
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
            label: I18n.trFor("quickCapture", "Action when Enter")
            options: [
                { label: I18n.trFor("quickCapture", "Copy"), value: "clipboard" },
                { label: I18n.trFor("quickCapture", "Save"), value: "file" },
                { label: I18n.trFor("quickCapture", "Copy & Save"), value: "both" }
            ]
            defaultValue: "both"
        }

        Separator {}

        StringSettingPlus {
            id: saveDirectory
            settingKey: "saveDirectory"
            label: I18n.trFor("quickCapture", "Save Directory")
            placeholder: "~/Pictures/Screenshots"
            defaultValue: "~/Pictures/Screenshots"
            isDirectory: true
        }

        Separator {}

        StringSettingPlus {
            id: saveFilenamePattern
            settingKey: "saveFilenamePattern"
            label: I18n.trFor("quickCapture", "Save Filename Pattern")
            placeholder: "Screenshot-%Y-%m-%d_%H-%M-%S"
            defaultValue: "Screenshot-%Y-%m-%d_%H-%M-%S"
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Format tokens: %Y (Year), %y (2-digit year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second), {zzz} (Ms)")
            opacity: 0.85
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: outputFormat
            settingKey: "outputFormat"
            label: I18n.trFor("quickCapture", "Output Format")
            options: [
                { label: "PNG", value: "png" },
                { label: "JPEG", value: "jpg" },
                { label: "WebP", value: "webp" },
                { label: "PDF", value: "pdf" },
                { label: "PPM", value: "ppm" }
            ]
            defaultValue: "png"
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Output format applies only to disk saves. Clipboard copies are always PNG.")
            opacity: 0.85
        }

        Separator {
            visible: outputFormat.value === "jpg" || outputFormat.value === "webp"
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: jpegQuality
            settingKey: "jpegQuality"
            label: I18n.trFor("quickCapture", "JPEG Quality")
            defaultValue: 90
            minimum: 1
            maximum: 100
            unit: "%"
            leftLabel: "1"
            rightLabel: "100"
            visible: outputFormat.value === "jpg"
            height: visible ? implicitHeight : 0
        }

        SliderSettingPlus {
            id: webpQuality
            settingKey: "webpQuality"
            label: I18n.trFor("quickCapture", "WebP Quality")
            defaultValue: 80
            minimum: 1
            maximum: 100
            unit: "%"
            leftLabel: "1"
            rightLabel: "100"
            visible: outputFormat.value === "webp"
            height: visible ? implicitHeight : 0
        }
    }
        }
    }

    // ── Tab 3: Notifications ─────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 3
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: notificationsTabCol.implicitHeight
        Column {
            id: notificationsTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: notificationsCard
                SectionTitle {
                    text: I18n.trFor("quickCapture", "Notifications")
                    icon: "notifications"
                    showReset: postNotification.isDirty
                    onResetClicked: {
                        postNotification.resetToDefault();
                    }
                }

                ButtonGroupSettingPlus {
                    id: postNotification
                    settingKey: "postNotification"
                    label: I18n.trFor("quickCapture", "Post-Capture Notification")
                    description: I18n.trFor("quickCapture", "Choose notifications shown after copy or save.")
                    defaultValue: "notification"
                    options: [
                        { label: I18n.trFor("quickCapture", "Notification"), value: "notification" },
                        { label: I18n.trFor("quickCapture", "Toast"), value: "toast" },
                        { label: I18n.trFor("quickCapture", "Both"), value: "both" },
                        { label: I18n.trFor("quickCapture", "None"), value: "none" }
                    ]
                }
            }
        }
    }

    // ── Tab 4: Toolbar ───────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 4
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: toolbarTabCol.implicitHeight
        Column {
            id: toolbarTabCol
            width: parent.width
            spacing: Theme.spacingM
    SettingsCard {
        id: toolbarCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Toolbar")
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
            label: I18n.trFor("quickCapture", "Show Toolbar")
            defaultValue: true
        }

        Separator {
            visible: showToolbar.value
            height: visible ? 1 : 0
        }

        ButtonGroupSettingPlus {
            id: toolbarPosition
            settingKey: "toolbarPosition"
            label: I18n.trFor("quickCapture", "Toolbar Position")
            options: [
                { label: I18n.trFor("quickCapture", "Top"), value: "top" },
                { label: I18n.trFor("quickCapture", "Bottom"), value: "bottom" },
                { label: I18n.trFor("quickCapture", "Left"), value: "left" },
                { label: I18n.trFor("quickCapture", "Right"), value: "right" }
            ]
            defaultValue: "bottom"
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
            label: I18n.trFor("quickCapture", "Show Toolbar Border")
            defaultValue: false
            visible: showToolbar.value
            height: visible ? 36 : 0
        }

        Separator {
            visible: showToolbar.value
            height: visible ? 1 : 0
        }

        ToggleSettingPlus {
            id: showShortcutHints
            settingKey: "show_shortcut_hints"
            label: I18n.trFor("quickCapture", "Show Keyboard Shortcut Hints")
            defaultValue: false
            visible: showToolbar.value
            height: visible ? 36 : 0
        }
    }
        }
    }

    // ── Tab 5: Palette ───────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 5
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: paletteTabCol.implicitHeight
        Column {
            id: paletteTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: toolbarPaletteSection
        SectionTitle {
            text: I18n.trFor("quickCapture", "Toolbar Palette")
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
            text: I18n.trFor("quickCapture", "Pick a palette preset or customize individual color slots.")
        }

        Item { width: 1; height: Theme.spacingS }

        Item {
            id: palettePresetContainer
            width: parent.width
            height: presetLayout.implicitHeight

            HoverHandler {
                id: containerHover
            }

            Rectangle {
                anchors.fill: parent
                anchors.leftMargin: -12
                anchors.rightMargin: -12
                anchors.topMargin: -6
                anchors.bottomMargin: -6
                radius: Theme.cornerRadius
                color: containerHover.hovered ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Column {
                id: presetLayout
                width: parent.width
                spacing: Theme.spacingXS

                SelectionSettingPlus {
                    id: palettePresetSetting
                    settingKey: "color_palette_preset"
                    label: I18n.trFor("quickCapture", "Palette Preset")
                    defaultValue: "adaptive"
                    options: [
                        { "label": I18n.trFor("quickCapture", "Adaptive (DMS Theme)"), "value": "adaptive" },
                        { "label": I18n.trFor("quickCapture", "Classic (Tailwind)"), "value": "classic" },
                        { "label": I18n.trFor("quickCapture", "Nord"), "value": "nord" },
                        { "label": I18n.trFor("quickCapture", "Dracula"), "value": "dracula" },
                        { "label": I18n.trFor("quickCapture", "Gruvbox Material"), "value": "gruvbox" },
                        { "label": I18n.trFor("quickCapture", "Catppuccin"), "value": "catppuccin" },
                        { "label": I18n.trFor("quickCapture", "Everforest"), "value": "everforest" },
                        { "label": I18n.trFor("quickCapture", "Rosé Pine"), "value": "rosePine" },
                        { "label": I18n.trFor("quickCapture", "Kanagawa"), "value": "kanagawaWl" },
                        { "label": I18n.trFor("quickCapture", "Tokyo Night"), "value": "tokyoNight" },
                        { "label": I18n.trFor("quickCapture", "Synthwave Electric"), "value": "synthwaveElectric" },
                        { "label": I18n.trFor("quickCapture", "Dank Violet"), "value": "dankViolet" },
                        { "label": I18n.trFor("quickCapture", "Custom Colors"), "value": "custom" }
                    ]
                    Component.onCompleted: {
                        for (var i = 0; i < children.length; i++) {
                            if (children[i].toString().indexOf("Rectangle") !== -1) {
                                children[i].visible = false;
                            }
                        }
                    }
                }

                ButtonGroupSettingPlus {
                    id: registryVariantSetting
                    settingKey: "registry_theme_variant"
                    label: ""
                    defaultValue: "dark"
                    options: [
                        { "label": I18n.trFor("quickCapture", "Dark"), "value": "dark" },
                        { "label": I18n.trFor("quickCapture", "Light"), "value": "light" }
                    ]
                    visible: {
                        const p = palettePresetSetting.value;
                        return p !== "adaptive" && p !== "classic" && p !== "custom" && p !== "catppuccin";
                    }
                    height: visible ? implicitHeight : 0
                    Component.onCompleted: {
                        for (var i = 0; i < children.length; i++) {
                            if (children[i].toString().indexOf("Rectangle") !== -1) {
                                children[i].visible = false;
                            }
                        }
                        if (children[1] && children[1].children[0]) {
                            children[1].children[0].height = 0;
                            children[1].children[0].visible = false;
                        }
                    }
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
                    Component.onCompleted: {
                        for (var i = 0; i < children.length; i++) {
                            if (children[i].toString().indexOf("Rectangle") !== -1) {
                                children[i].visible = false;
                            }
                        }
                        if (children[1] && children[1].children[0]) {
                            children[1].children[0].height = 0;
                            children[1].children[0].visible = false;
                        }
                    }
                }
            }
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
                label: I18n.trFor("quickCapture", "Slot 1")
                defaultValue: "primary"
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? Theme.primary : captureConfig.defaultAccentColors[0]) : null
            }

            CompactColorSetting {
                id: c0
                settingKey: "toolbar_color_0"
                label: I18n.trFor("quickCapture", "Slot 2")
                defaultValue: captureConfig.adaptiveColors[0]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[0] : captureConfig.defaultAccentColors[1]) : null
            }

            CompactColorSetting {
                id: c1
                settingKey: "toolbar_color_1"
                label: I18n.trFor("quickCapture", "Slot 3")
                defaultValue: captureConfig.adaptiveColors[1]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[1] : captureConfig.defaultAccentColors[2]) : null
            }

            CompactColorSetting {
                id: c2
                settingKey: "toolbar_color_2"
                label: I18n.trFor("quickCapture", "Slot 4")
                defaultValue: captureConfig.adaptiveColors[2]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[2] : captureConfig.defaultAccentColors[3]) : null
            }

            CompactColorSetting {
                id: c3
                settingKey: "toolbar_color_3"
                label: I18n.trFor("quickCapture", "Slot 5")
                defaultValue: captureConfig.adaptiveColors[3]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[3] : captureConfig.defaultAccentColors[4]) : null
            }

            CompactColorSetting {
                id: c4
                settingKey: "toolbar_color_4"
                label: I18n.trFor("quickCapture", "Slot 6")
                defaultValue: captureConfig.adaptiveColors[4]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[4] : captureConfig.defaultAccentColors[5]) : null
            }

            CompactColorSetting {
                id: c5
                settingKey: "toolbar_color_5"
                label: I18n.trFor("quickCapture", "Slot 7")
                defaultValue: captureConfig.adaptiveColors[5]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[5] : captureConfig.defaultAccentColors[6]) : null
            }

            CompactColorSetting {
                id: c6
                settingKey: "toolbar_color_6"
                label: I18n.trFor("quickCapture", "Slot 8")
                defaultValue: captureConfig.adaptiveColors[6]
                readOnly: palettePresetSetting.value !== "custom"
                overrideColor: palettePresetSetting.value !== "custom" ? (palettePresetSetting.value === "adaptive" ? captureConfig.adaptiveColors[6] : captureConfig.defaultAccentColors[7]) : null
            }
        }
    }
        }
    }

    // ── Tab 6: Editor ─────────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 6
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: stylesTabCol.implicitHeight
        Column {
            id: stylesTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: backgroundStylesCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Editor")
            icon: "aspect_ratio"
            showReset: overlayOpacity.isDirty || showCanvasBorder.isDirty || editQuality.isDirty || modalDisplayMode.isDirty || modalDisplayTarget.isDirty || modalAspectRatio.isDirty || scaleToContent.isDirty
            onResetClicked: {
                overlayOpacity.resetToDefault();
                showCanvasBorder.resetToDefault();
                editQuality.resetToDefault();
                modalDisplayMode.resetToDefault();
                modalDisplayTarget.resetToDefault();
                modalAspectRatio.resetToDefault();
                scaleToContent.resetToDefault();
            }
        }

        SelectionSettingPlus {
            id: modalDisplayTarget
            settingKey: "modalDisplayTarget"
            label: I18n.trFor("quickCapture", "Editor Display Screen")
            options: {
                const list = [
                    { label: I18n.trFor("quickCapture", "Focused Screen"), value: "focused" }
                ];
                if (Quickshell.screens) {
                    for (let i = 0; i < Quickshell.screens.length; i++) {
                        const scr = Quickshell.screens[i];
                        if (scr) {
                            list.push({
                                label: I18n.trFor("quickCapture", "Screen: %1 (%2x%3)").arg(scr.name).arg(scr.width).arg(scr.height),
                                value: scr.name
                            });
                        }
                    }
                }
                return list;
            }
            defaultValue: "focused"
        }

        ButtonGroupSettingPlus {
            id: modalDisplayMode
            settingKey: "modalDisplayMode"
            label: I18n.trFor("quickCapture", "Editor Display Mode")
            description: I18n.trFor("quickCapture", "Choose whether the editor opens as a modal overlay or a movable floating window.")
            options: [
                { label: I18n.trFor("quickCapture", "Modal"), value: "modal" },
                { label: I18n.trFor("quickCapture", "Floating"), value: "floating" }
            ]
            defaultValue: "floating"
        }

        ButtonGroupSettingPlus {
            id: modalAspectRatio
            settingKey: "modalAspectRatio"
            label: I18n.trFor("quickCapture", "Editor Aspect Ratio")
            description: I18n.trFor("quickCapture", "Choose the editor shape for portrait or landscape screens.")
            options: [
                { label: I18n.trFor("quickCapture", "Landscape"), value: "landscape" },
                { label: I18n.trFor("quickCapture", "Portrait"), value: "portrait" }
            ]
            defaultValue: "landscape"
        }

        Separator {}

        SliderSettingPlus {
            id: overlayOpacity
            settingKey: "overlayOpacity"
            label: I18n.trFor("quickCapture", "Overlay Opacity")
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
            label: I18n.trFor("quickCapture", "Show Screenshot Border")
            defaultValue: true
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: editQuality
            settingKey: "editQuality"
            label: I18n.trFor("quickCapture", "Editor Preview Quality")
            options: [
                { label: I18n.trFor("quickCapture", "Low"), value: "150000" },
                { label: I18n.trFor("quickCapture", "Balanced"), value: "300000" },
                { label: I18n.trFor("quickCapture", "High"), value: "450000" },
                { label: I18n.trFor("quickCapture", "Very High"), value: "600000" }
            ]
            defaultValue: "300000"
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Controls the preview pixel budget while editing. Lower it if you experience lag. Does not affect the final saved image quality.")
            opacity: 0.8
        }

        Separator {}

        ToggleSettingPlus {
            id: scaleToContent
            settingKey: "modalScaleToContent"
            label: I18n.trFor("quickCapture", "Scale Editor to Screenshot Size")
            description: I18n.trFor("quickCapture", "When enabled, the editor shrinks to match the captured region instead of filling 90% of the screen.")
            defaultValue: false
        }
    }

        }
    }

    // ── Tab 7: Tool Defaults ───────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 7
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: toolDefaultsTabCol.implicitHeight
        Column {
            id: toolDefaultsTabCol
            width: parent.width
            spacing: Theme.spacingM

            SettingsCard {
                id: toolDefaultsCard
                SectionTitle {
                    text: I18n.trFor("quickCapture", "Tool Defaults")
                    icon: "tune"
                    showReset: defaultToolMode.isDirty || defaultPresetIndex.isDirty || defaultTool.isDirty
                        || defaultPenThickness.isDirty || defaultPenColor.isDirty
                        || defaultLineThickness.isDirty || defaultLineColor.isDirty
                        || defaultArrowThickness.isDirty || defaultArrowColor.isDirty
                        || defaultRectThickness.isDirty || defaultRectColor.isDirty
                        || defaultEllipseThickness.isDirty || defaultEllipseColor.isDirty
                        || defaultHighlighterThickness.isDirty || defaultHighlighterColor.isDirty
                        || defaultStampSize.isDirty || defaultStampColor.isDirty
                        || defaultTextColor.isDirty
                        || defaultRedactThickness.isDirty || defaultPixelateIntensity.isDirty
                        || defaultSpotlightIntensity.isDirty || defaultCalloutZoom.isDirty
                    onResetClicked: {
                        defaultToolMode.resetToDefault();
                        defaultPresetIndex.resetToDefault();
                        defaultTool.resetToDefault();
                        defaultPenThickness.resetToDefault();
                        defaultPenColor.resetToDefault();
                        defaultLineThickness.resetToDefault();
                        defaultLineColor.resetToDefault();
                        defaultArrowThickness.resetToDefault();
                        defaultArrowColor.resetToDefault();
                        defaultRectThickness.resetToDefault();
                        defaultRectColor.resetToDefault();
                        defaultEllipseThickness.resetToDefault();
                        defaultEllipseColor.resetToDefault();
                        defaultHighlighterThickness.resetToDefault();
                        defaultHighlighterColor.resetToDefault();
                        defaultStampSize.resetToDefault();
                        defaultStampColor.resetToDefault();
                        defaultTextColor.resetToDefault();
                        defaultRedactThickness.resetToDefault();
                        defaultPixelateIntensity.resetToDefault();
                        defaultSpotlightIntensity.resetToDefault();
                        defaultCalloutZoom.resetToDefault();
                    }
                }

                ButtonGroupSettingPlus {
                    id: defaultToolMode
                    settingKey: "defaultToolMode"
                    label: I18n.trFor("quickCapture", "Starting Tool Mode")
                    options: [
                        { label: I18n.trFor("quickCapture", "Radial Preset"), value: "preset" },
                        { label: I18n.trFor("quickCapture", "Custom Tool"), value: "custom" }
                    ]
                    defaultValue: "preset"
                }

                InfoText {
                    text: I18n.trFor("quickCapture", "Note: Starting tool mode overrides tool thickness and color defaults if the starting tool matches it.")
                    opacity: 0.85
                }

                Separator {}

                SelectionSettingPlus {
                    id: defaultPresetIndex
                    settingKey: "defaultPresetIndex"
                    label: I18n.trFor("quickCapture", "Starting Preset")
                    options: [
                        { "label": I18n.trFor("quickCapture", "Preset 1"), "value": "0" },
                        { "label": I18n.trFor("quickCapture", "Preset 2"), "value": "1" },
                        { "label": I18n.trFor("quickCapture", "Preset 3"), "value": "2" },
                        { "label": I18n.trFor("quickCapture", "Preset 4"), "value": "3" },
                        { "label": I18n.trFor("quickCapture", "Preset 5"), "value": "4" },
                        { "label": I18n.trFor("quickCapture", "Preset 6"), "value": "5" },
                        { "label": I18n.trFor("quickCapture", "Preset 7"), "value": "6" },
                        { "label": I18n.trFor("quickCapture", "Preset 8"), "value": "7" }
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
                    label: I18n.trFor("quickCapture", "Starting Tool")
                    options: [{
                        "label": I18n.trFor("quickCapture", "Freehand Pen"),
                        "value": "pen"
                    }, {
                        "label": I18n.trFor("quickCapture", "Straight Line"),
                        "value": "line"
                    }, {
                        "label": I18n.trFor("quickCapture", "Arrow Vector"),
                        "value": "arrow"
                    }, {
                        "label": I18n.trFor("quickCapture", "Rectangle Outline"),
                        "value": "rect"
                    }, {
                        "label": I18n.trFor("quickCapture", "Ellipse / Circle"),
                        "value": "ellipse"
                    }, {
                        "label": I18n.trFor("quickCapture", "Text Note"),
                        "value": "text"
                    }, {
                        "label": I18n.trFor("quickCapture", "Pixelate"),
                        "value": "pixelate"
                    }, {
                        "label": I18n.trFor("quickCapture", "Redact"),
                        "value": "redact"
                    }, {
                        "label": I18n.trFor("quickCapture", "Number Stamp"),
                        "value": "stamp"
                    }, {
                        "label": I18n.trFor("quickCapture", "Highlighter"),
                        "value": "highlighter"
                    }, {
                        "label": I18n.trFor("quickCapture", "Eraser"),
                        "value": "eraser"
                    }, {
                        "label": I18n.trFor("quickCapture", "Crop / Resize"),
                        "value": "crop"
                    }]
                    defaultValue: "pen"
                    visible: defaultToolMode.value === "custom"
                }

                Separator {
                    visible: defaultToolMode.value === "custom"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultPenThickness
                    label: I18n.trFor("quickCapture", "Pen Thickness")
                    settingKey: "defaultPenThickness"
                    defaultValue: Constants.getToolMeta("pen").defaultValue
                    minimum: Constants.getToolMeta("pen").min
                    maximum: Constants.getToolMeta("pen").max
                    leftLabel: Constants.getToolMeta("pen").min.toString()
                    rightLabel: Constants.getToolMeta("pen").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultPenColor
                    label: I18n.trFor("quickCapture", "Pen Color")
                    settingKey: "defaultPenColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultLineThickness
                    label: I18n.trFor("quickCapture", "Line Thickness")
                    settingKey: "defaultLineThickness"
                    defaultValue: Constants.getToolMeta("line").defaultValue
                    minimum: Constants.getToolMeta("line").min
                    maximum: Constants.getToolMeta("line").max
                    leftLabel: Constants.getToolMeta("line").min.toString()
                    rightLabel: Constants.getToolMeta("line").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultLineColor
                    label: I18n.trFor("quickCapture", "Line Color")
                    settingKey: "defaultLineColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultArrowThickness
                    label: I18n.trFor("quickCapture", "Arrow Thickness")
                    settingKey: "defaultArrowThickness"
                    defaultValue: Constants.getToolMeta("arrow").defaultValue
                    minimum: Constants.getToolMeta("arrow").min
                    maximum: Constants.getToolMeta("arrow").max
                    leftLabel: Constants.getToolMeta("arrow").min.toString()
                    rightLabel: Constants.getToolMeta("arrow").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultArrowColor
                    label: I18n.trFor("quickCapture", "Arrow Color")
                    settingKey: "defaultArrowColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultRectThickness
                    label: I18n.trFor("quickCapture", "Rectangle Thickness")
                    settingKey: "defaultRectThickness"
                    defaultValue: Constants.getToolMeta("rect").defaultValue
                    minimum: Constants.getToolMeta("rect").min
                    maximum: Constants.getToolMeta("rect").max
                    leftLabel: Constants.getToolMeta("rect").min.toString()
                    rightLabel: Constants.getToolMeta("rect").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultRectColor
                    label: I18n.trFor("quickCapture", "Rectangle Color")
                    settingKey: "defaultRectColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultEllipseThickness
                    label: I18n.trFor("quickCapture", "Ellipse Thickness")
                    settingKey: "defaultEllipseThickness"
                    defaultValue: Constants.getToolMeta("ellipse").defaultValue
                    minimum: Constants.getToolMeta("ellipse").min
                    maximum: Constants.getToolMeta("ellipse").max
                    leftLabel: Constants.getToolMeta("ellipse").min.toString()
                    rightLabel: Constants.getToolMeta("ellipse").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultEllipseColor
                    label: I18n.trFor("quickCapture", "Ellipse Color")
                    settingKey: "defaultEllipseColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultHighlighterThickness
                    label: I18n.trFor("quickCapture", "Highlighter Thickness")
                    settingKey: "defaultHighlighterThickness"
                    defaultValue: Constants.getToolMeta("highlighter").defaultValue
                    minimum: Constants.getToolMeta("highlighter").min
                    maximum: Constants.getToolMeta("highlighter").max
                    leftLabel: Constants.getToolMeta("highlighter").min.toString()
                    rightLabel: Constants.getToolMeta("highlighter").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultHighlighterColor
                    label: I18n.trFor("quickCapture", "Highlighter Color")
                    settingKey: "defaultHighlighterColor"
                    defaultValue: "primary"
                }

                Separator {}

                ColorSettingPlus {
                    id: defaultTextColor
                    label: I18n.trFor("quickCapture", "Text Color")
                    settingKey: "defaultTextColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultStampSize
                    label: I18n.trFor("quickCapture", "Stamp Size")
                    settingKey: "defaultStampSize"
                    defaultValue: Constants.getToolMeta("stamp").defaultValue
                    minimum: Constants.getToolMeta("stamp").min
                    maximum: Constants.getToolMeta("stamp").max
                    leftLabel: Constants.getToolMeta("stamp").min.toString()
                    rightLabel: Constants.getToolMeta("stamp").max.toString()
                    previewType: "thickness"
                }

                ColorSettingPlus {
                    id: defaultStampColor
                    label: I18n.trFor("quickCapture", "Stamp Color")
                    settingKey: "defaultStampColor"
                    defaultValue: "primary"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultRedactThickness
                    label: I18n.trFor("quickCapture", "Redact Thickness")
                    settingKey: "defaultRedactThickness"
                    defaultValue: Constants.getToolMeta("redact").defaultValue
                    minimum: Constants.getToolMeta("redact").min
                    maximum: Constants.getToolMeta("redact").max
                    leftLabel: Constants.getToolMeta("redact").min.toString()
                    rightLabel: Constants.getToolMeta("redact").max.toString()
                    previewType: "thickness"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultPixelateIntensity
                    label: I18n.trFor("quickCapture", "Pixelate Intensity")
                    settingKey: "defaultPixelateIntensity"
                    defaultValue: Constants.getToolMeta("pixelate").defaultValue
                    minimum: Constants.getToolMeta("pixelate").min
                    maximum: Constants.getToolMeta("pixelate").max
                    leftLabel: Constants.getToolMeta("pixelate").min.toString()
                    rightLabel: Constants.getToolMeta("pixelate").max.toString()
                    previewType: "none"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultSpotlightIntensity
                    label: I18n.trFor("quickCapture", "Spotlight Opacity")
                    settingKey: "defaultSpotlightIntensity"
                    defaultValue: Constants.getToolMeta("spotlight").defaultValue
                    minimum: Constants.getToolMeta("spotlight").min
                    maximum: Constants.getToolMeta("spotlight").max
                    leftLabel: Constants.getToolMeta("spotlight").min.toString()
                    rightLabel: Constants.getToolMeta("spotlight").max.toString()
                    previewType: "none"
                }

                Separator {}

                SliderSettingPlus {
                    id: defaultCalloutZoom
                    label: I18n.trFor("quickCapture", "Callout Zoom")
                    settingKey: "defaultCalloutZoom"
                    defaultValue: Constants.getToolMeta("callout").defaultValue
                    minimum: Constants.getToolMeta("callout").min
                    maximum: Constants.getToolMeta("callout").max
                    leftLabel: Constants.getToolMeta("callout").min.toString()
                    rightLabel: Constants.getToolMeta("callout").max.toString()
                    previewType: "none"
                }
            }
        }
    }

    // ── Tab 8: Text ──────────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 8
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: textTabCol.implicitHeight
        Column {
            id: textTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: textSettingsCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Text")
            icon: "format_size"
            showReset: textFontSize.isDirty || textFontFamily.isDirty || stampFontFamily.isDirty || textBold.isDirty || textItalic.isDirty || textUnderline.isDirty || textBackground.isDirty || textInputMode.isDirty
            onResetClicked: {
                textFontSize.resetToDefault();
                textFontFamily.resetToDefault();
                stampFontFamily.resetToDefault();
                textBold.resetToDefault();
                textItalic.resetToDefault();
                textUnderline.resetToDefault();
                textBackground.resetToDefault();
                textInputMode.resetToDefault();
            }
        }

        SliderSettingPlus {
            id: textFontSize
            label: I18n.trFor("quickCapture", "Default Text Font Size")
            settingKey: "textFontSize"
            defaultValue: Constants.getToolMeta("text").defaultValue
            minimum: Constants.getToolMeta("text").min
            maximum: Constants.getToolMeta("text").max
            leftLabel: Constants.getToolMeta("text").min.toString()
            rightLabel: Constants.getToolMeta("text").max.toString()
            previewType: "fontSize"
        }

        Separator {}

        FontSelectionSettingPlus {
            id: textFontFamily
            settingKey: "textFontFamily"
            label: I18n.trFor("quickCapture", "Text Font")
            defaultValue: "system"
        }

        Separator {}

        FontSelectionSettingPlus {
            id: stampFontFamily
            settingKey: "stampFontFamily"
            label: I18n.trFor("quickCapture", "Stamp Number Font")
            description: I18n.trFor("quickCapture", "Font family used for number stamp labels")
            defaultValue: "system"
        }

        Separator {}

        ToggleSettingPlus {
            id: textBold
            settingKey: "textBold"
            label: I18n.trFor("quickCapture", "Default Bold Text")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: textItalic
            settingKey: "textItalic"
            label: I18n.trFor("quickCapture", "Default Italic Text")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: textUnderline
            settingKey: "textUnderline"
            label: I18n.trFor("quickCapture", "Default Underline Text")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: textBackground
            settingKey: "textBackground"
            label: I18n.trFor("quickCapture", "Default Text Background")
            defaultValue: false
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: textInputMode
            settingKey: "textInputMode"
            label: I18n.trFor("quickCapture", "Input Mode")
            options: [
                { label: I18n.trFor("quickCapture", "Direct"), value: "inline" },
                { label: I18n.trFor("quickCapture", "Popup Input"), value: "popup" }
            ]
            defaultValue: "inline"
        }

    }
        }
    }

    // ── Tab 9: Shapes ────────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 9
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: shapesTabCol.implicitHeight
        Column {
            id: shapesTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: shapesCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Shapes")
            icon: "category"
            showReset: roundRect.isDirty || textCornerRadius.isDirty || roundHighlighter.isDirty || stampOuterRing.isDirty || penAutoClose.isDirty
            onResetClicked: {
                roundRect.resetToDefault();
                textCornerRadius.resetToDefault();
                roundHighlighter.resetToDefault();
                stampOuterRing.resetToDefault();
                penAutoClose.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: roundRect
            settingKey: "roundRect"
            label: I18n.trFor("quickCapture", "Round Rectangle Corners")
            defaultValue: true
        }

        Separator {}

        SliderSettingPlus {
            id: textCornerRadius
            settingKey: "textCornerRadius"
            label: I18n.trFor("quickCapture", "Text Background Roundness")
            defaultValue: 12
            minimum: 0
            maximum: 20
            unit: "px"
            leftLabel: "0"
            rightLabel: "20"
        }

        Separator {}

        ToggleSettingPlus {
            id: roundHighlighter
            settingKey: "roundHighlighter"
            label: I18n.trFor("quickCapture", "Round Highlighter Tips")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: stampOuterRing
            settingKey: "stampOuterRing"
            label: I18n.trFor("quickCapture", "Stamp Contrast Ring")
            description: I18n.trFor("quickCapture", "Draw an outer ring using the stamp number color")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            id: penAutoClose
            settingKey: "penAutoClose"
            label: I18n.trFor("quickCapture", "Pen Auto-Close")
            description: I18n.trFor("quickCapture", "Auto-close the loop when ending near the start point.")
            defaultValue: true
        }
    }

        }
    }

    // ── Tab 10: Background ──────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 10
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: backgroundTabCol.implicitHeight
        Column {
            id: backgroundTabCol
            width: parent.width
            spacing: Theme.spacingM
    SettingsCard {
        SectionTitle {
            text: I18n.trFor("quickCapture", "Background Defaults")
            icon: "wallpaper"
            showReset: backgroundAutoApply.isDirty || backgroundDefaultMode.isDirty || backgroundImageFolderSetting.isDirty || backgroundDefaultImageSetting.isDirty || backgroundImageBlurSetting.isDirty || backgroundImageDimSetting.isDirty || backgroundImageDimStrengthSetting.isDirty || backgroundDefaultPadding.isDirty || backgroundDefaultRadius.isDirty || backgroundDefaultShadow.isDirty || backgroundDefaultAngle.isDirty || backgroundDefaultAspectRatio.isDirty || backgroundDefaultAlignment.isDirty || backgroundDefaultSolidColor.isDirty || backgroundDefaultGradientStart.isDirty || backgroundDefaultGradientEnd.isDirty
            onResetClicked: {
                backgroundAutoApply.resetToDefault();
                backgroundDefaultMode.resetToDefault();
                backgroundImageFolderSetting.resetToDefault();
                backgroundDefaultImageSetting.resetToDefault();
                backgroundImageBlurSetting.resetToDefault();
                backgroundImageDimSetting.resetToDefault();
                backgroundImageDimStrengthSetting.resetToDefault();
                backgroundDefaultSolidColor.resetToDefault();
                backgroundDefaultGradientStart.resetToDefault();
                backgroundDefaultGradientEnd.resetToDefault();
                backgroundDefaultPadding.resetToDefault();
                backgroundDefaultRadius.resetToDefault();
                backgroundDefaultShadow.resetToDefault();
                backgroundDefaultAngle.resetToDefault();
                backgroundDefaultAspectRatio.resetToDefault();
                backgroundDefaultAlignment.resetToDefault();
            }
        }

        ToggleSettingPlus {
            id: backgroundAutoApply
            settingKey: "backgroundAutoApply"
            label: I18n.trFor("quickCapture", "Auto-apply background defaults")
            description: I18n.trFor("quickCapture", "Enable background automatically when opening the editor")
            defaultValue: false
        }

        Separator {}

        SelectionSettingPlus {
            id: backgroundDefaultMode
            settingKey: "backgroundDefaultMode"
            label: I18n.trFor("quickCapture", "Default Background Mode")
            options: [
                { label: I18n.trFor("quickCapture", "Solid Color"), value: "solid" },
                { label: I18n.trFor("quickCapture", "Linear Gradient"), value: "gradient" },
                { label: I18n.trFor("quickCapture", "Radial Gradient"), value: "radial" },
                { label: I18n.trFor("quickCapture", "Conic Gradient"), value: "conic" },
                { label: I18n.trFor("quickCapture", "Image"), value: "image" }
            ]
            defaultValue: "solid"
        }

        Separator {
            visible: backgroundDefaultMode.value === "image"
        }

        StringSettingPlus {
            id: backgroundImageFolderSetting
            settingKey: "backgroundImageFolder"
            label: I18n.trFor("quickCapture", "Background Image Folder")
            placeholder: "~/Pictures/Wallpaper"
            defaultValue: "~/Pictures/Wallpaper"
            isDirectory: true
            visible: backgroundDefaultMode.value === "image"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: backgroundDefaultMode.value === "image"
        }

        StringSettingPlus {
            id: backgroundDefaultImageSetting
            settingKey: "backgroundDefaultImagePath"
            label: I18n.trFor("quickCapture", "Default Background Image")
            description: I18n.trFor("quickCapture", "Image selected automatically when using Image Background mode")
            placeholder: "~/Pictures/Wallpaper/image.jpg"
            defaultValue: ""
            isFile: true
            fileExtensions: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
            visible: backgroundDefaultMode.value === "image"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: backgroundDefaultMode.value === "image"
        }

        ToggleSettingPlus {
            id: backgroundImageBlurSetting
            settingKey: "backgroundImageBlur"
            label: I18n.trFor("quickCapture", "Blur Background Image")
            description: I18n.trFor("quickCapture", "Soften image details so screenshot content stands out")
            defaultValue: false
            visible: backgroundDefaultMode.value === "image"
            height: visible ? 36 : 0
        }

        Separator {
            visible: backgroundDefaultMode.value === "image"
        }

        ToggleSettingPlus {
            id: backgroundImageDimSetting
            settingKey: "backgroundImageDim"
            label: I18n.trFor("quickCapture", "Dim Background Image")
            description: I18n.trFor("quickCapture", "Darken the image to improve foreground contrast")
            defaultValue: false
            visible: backgroundDefaultMode.value === "image"
            height: visible ? 36 : 0
        }

        Separator {
            visible: backgroundDefaultMode.value === "image" && backgroundImageDimSetting.value
        }

        SliderSettingPlus {
            id: backgroundImageDimStrengthSetting
            settingKey: "backgroundImageDimStrength"
            label: I18n.trFor("quickCapture", "Dim Intensity")
            defaultValue: 28
            minimum: 0
            maximum: 80
            unit: "%"
            leftLabel: "0"
            rightLabel: "80"
            visible: backgroundDefaultMode.value === "image" && backgroundImageDimSetting.value
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: backgroundDefaultMode.value === "solid"
        }

        BackgroundColorSetting {
            id: backgroundDefaultSolidColor
            settingKey: "backgroundDefaultSolidColor"
            label: I18n.trFor("quickCapture", "Default Solid Color")
            defaultValue: "slot_1"
            visible: backgroundDefaultMode.value === "solid"
        }

        Separator {
            visible: backgroundDefaultMode.value === "gradient" || backgroundDefaultMode.value === "radial" || backgroundDefaultMode.value === "conic"
        }

        BackgroundColorSetting {
            id: backgroundDefaultGradientStart
            settingKey: "backgroundDefaultGradientStart"
            label: I18n.trFor("quickCapture", "Default Gradient Start")
            defaultValue: "slot_1"
            visible: backgroundDefaultMode.value === "gradient" || backgroundDefaultMode.value === "radial" || backgroundDefaultMode.value === "conic"
        }

        Separator {
            visible: backgroundDefaultMode.value === "gradient" || backgroundDefaultMode.value === "radial" || backgroundDefaultMode.value === "conic"
        }

        BackgroundColorSetting {
            id: backgroundDefaultGradientEnd
            settingKey: "backgroundDefaultGradientEnd"
            label: I18n.trFor("quickCapture", "Default Gradient End")
            defaultValue: "slot_2"
            visible: backgroundDefaultMode.value === "gradient" || backgroundDefaultMode.value === "radial" || backgroundDefaultMode.value === "conic"
        }

        Separator {}

        SliderSettingPlus {
            id: backgroundDefaultPadding
            settingKey: "backgroundDefaultPadding"
            label: I18n.trFor("quickCapture", "Default Padding")
            defaultValue: 40
            minimum: 0
            maximum: 150
            unit: "px"
            leftLabel: "0"
            rightLabel: "150"
        }

        Separator {}

        SliderSettingPlus {
            id: backgroundDefaultRadius
            settingKey: "backgroundDefaultRadius"
            label: I18n.trFor("quickCapture", "Default Corner Radius")
            defaultValue: 12
            minimum: 0
            maximum: 60
            unit: "px"
            leftLabel: "0"
            rightLabel: "60"
        }

        Separator {}

        SliderSettingPlus {
            id: backgroundDefaultShadow
            settingKey: "backgroundDefaultShadow"
            label: I18n.trFor("quickCapture", "Default Shadow Strength")
            defaultValue: 0
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0"
            rightLabel: "100"
        }

        Separator {}

        SliderSettingPlus {
            id: backgroundDefaultAngle
            settingKey: "backgroundDefaultAngle"
            label: I18n.trFor("quickCapture", "Default Gradient Angle")
            defaultValue: 45
            minimum: 0
            maximum: 360
            unit: "°"
            leftLabel: "0"
            rightLabel: "360"
        }

        Separator {}

            SelectionSettingPlus {
                id: backgroundDefaultAspectRatio
                settingKey: "backgroundDefaultAspectRatio"
                label: I18n.trFor("quickCapture", "Default Aspect Ratio")
                options: [
                    { label: I18n.trFor("quickCapture", "Auto"), value: "auto" },
                    { label: "1:1", value: "1:1" },
                    { label: "16:9", value: "16:9" },
                    { label: "9:16", value: "9:16" },
                    { label: "4:3", value: "4:3" },
                    { label: "3:2", value: "3:2" },
                    { label: "21:9", value: "21:9" }
                ]
                defaultValue: "auto"
            }

            Separator {}

            SelectionSettingPlus {
                id: backgroundDefaultAlignment
                settingKey: "backgroundDefaultAlignment"
                label: I18n.trFor("quickCapture", "Default Alignment")
                options: [
                    { label: I18n.trFor("quickCapture", "Top Left"), value: "top-left" },
                    { label: I18n.trFor("quickCapture", "Top Center"), value: "top-center" },
                    { label: I18n.trFor("quickCapture", "Top Right"), value: "top-right" },
                    { label: I18n.trFor("quickCapture", "Center Left"), value: "center-left" },
                    { label: I18n.trFor("quickCapture", "Center"), value: "center" },
                    { label: I18n.trFor("quickCapture", "Center Right"), value: "center-right" },
                    { label: I18n.trFor("quickCapture", "Bottom Left"), value: "bottom-left" },
                    { label: I18n.trFor("quickCapture", "Bottom Center"), value: "bottom-center" },
                    { label: I18n.trFor("quickCapture", "Bottom Right"), value: "bottom-right" }
                ]
                defaultValue: "center"
            }
        }
        }
    }

    // ── Tab 11: Watermark ────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 11
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: watermarkTabCol.implicitHeight
        Column {
            id: watermarkTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: watermarkCard
        SectionTitle {
            text: I18n.trFor("quickCapture", "Watermark")
            icon: "branding_watermark"
            showReset: defaultWatermark.isDirty || watermarkType.isDirty || watermarkText.isDirty || watermarkImage.isDirty || watermarkPosition.isDirty || watermarkOpacity.isDirty || watermarkSize.isDirty || watermarkTextSize.isDirty
            onResetClicked: {
                defaultWatermark.resetToDefault();
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
            id: defaultWatermark
            settingKey: "defaultWatermark"
            label: I18n.trFor("quickCapture", "Default Watermark")
            defaultValue: false
        }

        Separator {
            visible: true
            height: visible ? 1 : 0
        }

        ButtonGroupSettingPlus {
            id: watermarkType
            settingKey: "watermarkType"
            label: I18n.trFor("quickCapture", "Watermark Type")
            options: [
                { label: I18n.trFor("quickCapture", "Text"), value: "text" },
                { label: I18n.trFor("quickCapture", "Image"), value: "image" },
                { label: I18n.trFor("quickCapture", "Image + Text"), value: "hybrid" }
            ]
            defaultValue: "text"
            visible: true
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: true
            height: visible ? 1 : 0
        }

        SelectionSettingPlus {
            id: watermarkPosition
            settingKey: "watermarkPosition"
            label: I18n.trFor("quickCapture", "Position")
            options: [
                { label: I18n.trFor("quickCapture", "Top Left"), value: "top_left" },
                { label: I18n.trFor("quickCapture", "Top Right"), value: "top_right" },
                { label: I18n.trFor("quickCapture", "Bottom Left"), value: "bottom_left" },
                { label: I18n.trFor("quickCapture", "Bottom Right"), value: "bottom_right" },
                { label: I18n.trFor("quickCapture", "Center"), value: "center" },
                { label: I18n.trFor("quickCapture", "Top"), value: "top" },
                { label: I18n.trFor("quickCapture", "Bottom"), value: "bottom" },
                { label: I18n.trFor("quickCapture", "Left"), value: "left" },
                { label: I18n.trFor("quickCapture", "Right"), value: "right" }
            ]
            defaultValue: "bottom_right"
            visible: true
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: true
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkOpacity
            settingKey: "watermarkOpacity"
            label: I18n.trFor("quickCapture", "Opacity")
            defaultValue: 20
            minimum: 5
            maximum: 100
            unit: "%"
            leftLabel: "5"
            rightLabel: "100"
            visible: true
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: true
            height: visible ? 1 : 0
        }

        StringSettingPlus {
            id: watermarkText
            settingKey: "watermarkText"
            label: I18n.trFor("quickCapture", "Watermark Text")
            placeholder: "© {user}"
            defaultValue: "© {user}"
            visible: watermarkType.value === "text" || watermarkType.value === "hybrid"
            height: visible ? implicitHeight : 0
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Format tokens: {user} (Username), \\n (New Line), %Y (Year), %y (2-digit year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second)")
            opacity: 0.85
            visible: watermarkType.value === "text" || watermarkType.value === "hybrid"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: watermarkType.value === "text" || watermarkType.value === "hybrid"
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkTextSize
            settingKey: "watermarkTextSize"
            label: I18n.trFor("quickCapture", "Text Size")
            defaultValue: 5
            minimum: 1
            maximum: 50
            unit: "%"
            leftLabel: "1"
            rightLabel: "50"
            visible: watermarkType.value === "text" || watermarkType.value === "hybrid"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: watermarkType.value === "hybrid"
            height: visible ? 1 : 0
        }

        StringSettingPlus {
            id: watermarkImage
            settingKey: "watermarkImage"
            label: I18n.trFor("quickCapture", "Watermark Image")
            placeholder: "~/Pictures/watermark.png"
            defaultValue: ""
            isFile: true
            fileExtensions: ["Image files (*.png *.jpg *.jpeg *.svg *.webp)", "All files (*)"]
            visible: watermarkType.value === "image" || watermarkType.value === "hybrid"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: watermarkType.value === "image" || watermarkType.value === "hybrid"
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: watermarkSize
            settingKey: "watermarkSize"
            label: I18n.trFor("quickCapture", "Image Size")
            defaultValue: 5
            minimum: 5
            maximum: 50
            unit: "%"
            leftLabel: "5"
            rightLabel: "50"
            visible: watermarkType.value === "image" || watermarkType.value === "hybrid"
            height: visible ? implicitHeight : 0
        }

        Separator {
            visible: true
            height: visible ? 1 : 0
        }

        // Live Preview of the watermark overlay
        Column {
            width: parent.width
            spacing: Theme.spacingS
            visible: true
            height: visible ? implicitHeight : 0

            StyledText {
                text: I18n.trFor("quickCapture", "Live Preview")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                font.bold: true
            }

            StyledRect {
                id: watermarkPreviewArea
                width: parent.width
                height: 160
                radius: Theme.cornerRadius / 2
                color: Theme.surfaceContainer
                clip: true

                // A dark checkered/gradient background representing a mock captured screenshot
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
                            let p = Paths.expandTilde(rawPath.trim());
                            if (p.indexOf("/") === 0) {
                                p = Paths.toFileUrl(p);
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
                        const home = Paths.strip(Paths.home);
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
                            text: watermarkImage.value ? I18n.trFor("quickCapture", "Image Error") : I18n.trFor("quickCapture", "No Image Specified")
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

        }
    }

    // ── Tab 12: Float Window ─────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 12
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: floatTabCol.implicitHeight
        Column {
            id: floatTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                id: floatCard
                SectionTitle {
                    text: I18n.trFor("quickCapture", "Float Window")
                    icon: "open_in_new"
                    showReset: autoMinimize.isDirty || minimizeDelay.isDirty || initialWidth.isDirty || maxHeight.isDirty || borderWidth.isDirty || borderColor.isDirty || transparentBg.isDirty || spawnPosition.isDirty || edgeSpacing.isDirty || autoTiling.isDirty
                    onResetClicked: {
                        autoMinimize.resetToDefault();
                        minimizeDelay.resetToDefault();
                        initialWidth.resetToDefault();
                        maxHeight.resetToDefault();
                        borderWidth.resetToDefault();
                        borderColor.resetToDefault();
                        transparentBg.resetToDefault();
                        spawnPosition.resetToDefault();
                        edgeSpacing.resetToDefault();
                        autoTiling.resetToDefault();
                    }
                }

                ToggleSettingPlus {
                    id: autoMinimize
                    settingKey: "autoMinimize"
                    label: I18n.trFor("quickCapture", "Auto-minimize")
                    description: I18n.trFor("quickCapture", "Automatically minimize the float window after a delay")
                    defaultValue: false
                }

                SliderSettingPlus {
                    id: minimizeDelay
                    settingKey: "minimizeDelay"
                    label: I18n.trFor("quickCapture", "Minimize Delay")
                    defaultValue: 3000
                    minimum: 500
                    maximum: 10000
                    unit: "ms"
                    leftLabel: "500"
                    rightLabel: "10000"
                    visible: autoMinimize.value
                    height: visible ? implicitHeight : 0
                }

                Separator {}

                SliderSettingPlus {
                    id: initialWidth
                    settingKey: "initialWidth"
                    label: I18n.trFor("quickCapture", "Initial Width")
                    defaultValue: 400
                    minimum: 100
                    maximum: 2000
                    unit: "px"
                    leftLabel: "100"
                    rightLabel: "2000"
                }

                SliderSettingPlus {
                    id: maxHeight
                    settingKey: "maxHeight"
                    label: I18n.trFor("quickCapture", "Max Height (0 = no limit)")
                    defaultValue: 0
                    minimum: 0
                    maximum: 2000
                    unit: "px"
                    leftLabel: "0"
                    rightLabel: "2000"
                }

                Separator {}

                SliderSettingPlus {
                    id: borderWidth
                    settingKey: "borderWidth"
                    label: I18n.trFor("quickCapture", "Border Width")
                    defaultValue: 2
                    minimum: 0
                    maximum: 20
                    unit: "px"
                    leftLabel: "0"
                    rightLabel: "20"
                }

                SelectionSettingPlus {
                    id: borderColor
                    settingKey: "borderColor"
                    label: I18n.trFor("quickCapture", "Border Color")
                    options: [
                        { label: I18n.trFor("quickCapture", "Outline Variant"), value: "outlineVariant" },
                        { label: I18n.trFor("quickCapture", "Primary"), value: "primary" },
                        { label: I18n.trFor("quickCapture", "Surface Container Highest"), value: "surfaceContainerHighest" },
                        { label: I18n.trFor("quickCapture", "Transparent"), value: "transparent" }
                    ]
                    defaultValue: "outlineVariant"
                }

                Separator {}

                ToggleSettingPlus {
                    id: transparentBg
                    settingKey: "transparentBg"
                    label: I18n.trFor("quickCapture", "Transparent Background")
                    description: I18n.trFor("quickCapture", "Show only the image on a transparent background")
                    defaultValue: true
                }

                Separator {}

                SelectionSettingPlus {
                    id: spawnPosition
                    settingKey: "spawnPosition"
                    label: I18n.trFor("quickCapture", "Spawn Position")
                    options: [
                        { label: I18n.trFor("quickCapture", "Bottom Left"), value: "bottom-left" },
                        { label: I18n.trFor("quickCapture", "Bottom Right"), value: "bottom-right" },
                        { label: I18n.trFor("quickCapture", "Top Left"), value: "top-left" },
                        { label: I18n.trFor("quickCapture", "Top Right"), value: "top-right" },
                        { label: I18n.trFor("quickCapture", "Bottom"), value: "bottom" },
                        { label: I18n.trFor("quickCapture", "Top"), value: "top" },
                        { label: I18n.trFor("quickCapture", "Left"), value: "left" },
                        { label: I18n.trFor("quickCapture", "Right"), value: "right" },
                        { label: I18n.trFor("quickCapture", "Center"), value: "center" }
                    ]
                    defaultValue: "bottom-left"
                }

                SliderSettingPlus {
                    id: edgeSpacing
                    settingKey: "edgeSpacing"
                    label: I18n.trFor("quickCapture", "Edge Spacing")
                    defaultValue: 8
                    minimum: 0
                    maximum: 100
                    unit: "px"
                    leftLabel: "0"
                    rightLabel: "100"
                }

                Separator {}

                ToggleSettingPlus {
                    id: autoTiling
                    settingKey: "autoTiling"
                    label: I18n.trFor("quickCapture", "Auto-tiling")
                    description: I18n.trFor("quickCapture", "Automatically stack windows to avoid overlap")
                    defaultValue: true
                }
            }
        }
    }

    // ── Tab 13: Radial Menu ───────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 13
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: presetsTabCol.implicitHeight
        Column {
            id: presetsTabCol
            width: parent.width
            spacing: Theme.spacingM
    SettingsCard {
        id: radialMenuCard

        property int presetActiveIndex: 0

        property var activePresetTools: [...Constants.defaultRadialTools]
        property var activePresetColors: ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"]
        property var activePresetThicknesses: [6, 6, 6, 6, 6, 6, 6, 6]

        readonly property var currentPresets: {
            const list = [];
            for (let i = 0; i < 8; i++) {
                const tool = radialMenuCard.activePresetTools[i] || "none";
                const color = radialMenuCard.activePresetColors[i] || "primary";
                const thickness = radialMenuCard.activePresetThicknesses[i] ?? Constants.getToolMeta("pen").defaultValue;
                list.push({ tool: tool, color: color, thickness: thickness });
            }
            return list;
        }

        SectionTitle {
            text: I18n.trFor("quickCapture", "Radial Menu")
            icon: "settings"
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Configure up to 8 quick-access tool presets. Right-click during capture to open the radial menu.")
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
                                return captureConfig.getToolIcon(modelData.tool);
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
                                return captureConfig.getToolIcon(p.tool);
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
                        text: I18n.trFor("quickCapture", "Preset %1").arg(radialMenuCard.presetActiveIndex + 1)
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
                    id: presetToolSetting
                    settingKey: "preset_" + index + "_tool"
                    label: I18n.trFor("quickCapture", "Preset Tool")
                    options: [{
                        "label": I18n.trFor("quickCapture", "None / Disabled"),
                        "value": "none"
                    }, {
                        "label": I18n.trFor("quickCapture", "Freehand Pen"),
                        "value": "pen"
                    }, {
                        "label": I18n.trFor("quickCapture", "Straight Line"),
                        "value": "line"
                    }, {
                        "label": I18n.trFor("quickCapture", "Arrow Vector"),
                        "value": "arrow"
                    }, {
                        "label": I18n.trFor("quickCapture", "Rectangle Outline"),
                        "value": "rect"
                    }, {
                        "label": I18n.trFor("quickCapture", "Ellipse / Circle"),
                        "value": "ellipse"
                    }, {
                        "label": I18n.trFor("quickCapture", "Text Note"),
                        "value": "text"
                    }, {
                        "label": I18n.trFor("quickCapture", "Pixelate"),
                        "value": "pixelate"
                    }, {
                        "label": I18n.trFor("quickCapture", "Redact"),
                        "value": "redact"
                    }, {
                        "label": I18n.trFor("quickCapture", "Number Stamp"),
                        "value": "stamp"
                    }, {
                        "label": I18n.trFor("quickCapture", "Highlighter"),
                        "value": "highlighter"
                    }, {
                        "label": I18n.trFor("quickCapture", "Eraser"),
                        "value": "eraser"
                    }, {
                        "label": I18n.trFor("quickCapture", "Crop / Resize"),
                        "value": "crop"
                    }, {
                        "label": I18n.trFor("quickCapture", "Spotlight"),
                        "value": "spotlight"
                    }, {
                        "label": I18n.trFor("quickCapture", "Callout"),
                        "value": "callout"
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

                Connections {
                    target: presetToolSetting
                    function onValueChanged() {
                        radialMenuCard.activePresetTools[index] = presetToolSetting.value;
                        radialMenuCard.activePresetTools = [...radialMenuCard.activePresetTools];
                    }
                }

                Separator {}

                Column {
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        text: I18n.trFor("quickCapture", "Preset Color")
                        font.pixelSize: Theme.fontSizeLarge
                        font.weight: Font.Medium
                        color: Theme.surfaceText
                    }

                    ColorPalettePicker {
                        slotColors: [toolbar_primary.resolvedColor, c0.resolvedColor, c1.resolvedColor,
                            c2.resolvedColor, c3.resolvedColor, c4.resolvedColor, c5.resolvedColor, c6.resolvedColor]
                        value: presetColorSetting.value
                        customColor: captureConfig.resolveColor(presetColorSetting.value)
                        customLabel: presetColorSetting.value === "primary" ? I18n.trFor("quickCapture", "PRIMARY") : presetColorSetting.value.toString().toUpperCase()
                        onValueSelected: selectedValue => {
                            presetColorSetting.value = selectedValue;
                            radialMenuCard.activePresetColors[presetIndex] = selectedValue;
                            radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                        }
                        onCustomRequested: {
                            if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                                PopoutService.colorPickerModal.selectedColor = captureConfig.resolveColor(presetColorSetting.value);
                                PopoutService.colorPickerModal.pickerTitle = I18n.trFor("quickCapture", "Preset Color");
                                PopoutService.colorPickerModal.onColorSelectedCallback = selectedColor => {
                                    presetColorSetting.value = selectedColor.toString();
                                    radialMenuCard.activePresetColors[presetIndex] = presetColorSetting.value;
                                    radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                                };
                                PopoutService.colorPickerModal.show();
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
                            defaultValue: {
                                if (presetIndex === 6) return "#000000"; // Black
                                if (presetIndex === 7) return "#ffffff"; // White
                                return "primary";
                            }
                        }

                        Connections {
                            target: presetColorSetting
                            function onValueChanged() {
                                radialMenuCard.activePresetColors[presetIndex] = presetColorSetting.value;
                                radialMenuCard.activePresetColors = [...radialMenuCard.activePresetColors];
                            }
                        }
                    }
                }

                Separator {}

                SliderSettingPlus {
                    id: presetThicknessSetting
                    settingKey: "preset_" + index + "_thickness"
                    label: I18n.trFor("quickCapture", "Preset Thickness")
                    defaultValue: Constants.getToolMeta("pen").defaultValue
                    minimum: Constants.getToolMeta("pen").min
                    maximum: Constants.getToolMeta("pen").max
                    unit: "px"
                    leftLabel: String(minimum)
                    rightLabel: String(maximum)
                    previewType: "thickness"
                    previewColor: presetColorSetting.value
                }

                function refreshThicknessConstraints() {
                    const t = presetToolSetting.value;
                    const meta = Constants.getToolMeta(t);
                    // Localized labels map - required because I18n.trFor("quickCapture", ) needs string literals for extraction tools.
                    // Keys must match ToolMetadata.label values for consistency.
                    const toolLabels = {
                        pen: I18n.trFor("quickCapture", "Thickness"), line: I18n.trFor("quickCapture", "Thickness"),
                        arrow: I18n.trFor("quickCapture", "Thickness"), rect: I18n.trFor("quickCapture", "Thickness"),
                        ellipse: I18n.trFor("quickCapture", "Thickness"), highlighter: I18n.trFor("quickCapture", "Thickness"),
                        redact: I18n.trFor("quickCapture", "Thickness"), stamp: I18n.trFor("quickCapture", "Stamp Size"),
                        text: I18n.trFor("quickCapture", "Font Size"), pixelate: I18n.trFor("quickCapture", "Pixel Intensity"),
                        spotlight: I18n.trFor("quickCapture", "Dimming Opacity"), callout: I18n.trFor("quickCapture", "Zoom Level")
                    };
                    presetThicknessSetting.label = toolLabels[t] || I18n.trFor("quickCapture", "Preset Thickness");
                    presetThicknessSetting.minimum = meta.min;
                    presetThicknessSetting.maximum = meta.max;
                    presetThicknessSetting.unit = meta.unit;
                    presetThicknessSetting.previewType = meta.previewType;
                    const defVal = meta.defaultValue;
                    
                    const oldDefVal = presetThicknessSetting.defaultValue;
                    presetThicknessSetting.defaultValue = defVal;
                    
                    if (presetThicknessSetting.value === oldDefVal || 
                        presetThicknessSetting.value < presetThicknessSetting.minimum || 
                        presetThicknessSetting.value > presetThicknessSetting.maximum) {
                        presetThicknessSetting.value = defVal;
                    }
                    
                    presetThicknessSetting.leftLabel = String(presetThicknessSetting.minimum);
                    presetThicknessSetting.rightLabel = String(presetThicknessSetting.maximum);
                }

                Connections {
                    target: presetToolSetting
                    function onValueChanged() {
                        radialMenuCard.activePresetTools[index] = presetToolSetting.value;
                        radialMenuCard.activePresetTools = [...radialMenuCard.activePresetTools];
                        presetDelegate.refreshThicknessConstraints();
                    }
                }

                Connections {
                    target: presetThicknessSetting
                    function onValueChanged() {
                        radialMenuCard.activePresetThicknesses[index] = presetThicknessSetting.value;
                        radialMenuCard.activePresetThicknesses = [...radialMenuCard.activePresetThicknesses];
                    }
                }

                Component.onCompleted: {
                    Qt.callLater(() => {
                        presetDelegate.refreshThicknessConstraints();
                    });
                }
            }
        }

        // ── Radial Menu Behavior ──────────────────────────────────────────
        Separator {}

        SectionTitle {
            text: I18n.trFor("quickCapture", "Radial Menu Settings")
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
            label: I18n.trFor("quickCapture", "Trigger on Hover")
            description: I18n.trFor("quickCapture", "Auto-select a tool preset on hover, without releasing the mouse.")
            defaultValue: true
        }

        Separator {
            visible: radialHoverTrigger.value
            height: visible ? 1 : 0
        }

        SliderSettingPlus {
            id: radialHoverDelay
            settingKey: "radialHoverDelay"
            label: I18n.trFor("quickCapture", "Hover Trigger Delay")
            defaultValue: 200
            minimum: 100
            maximum: 500
            leftLabel: "100"
            rightLabel: "500"
            unit: "ms"
            visible: radialHoverTrigger.value
            height: visible ? implicitHeight : 0
        }

        Separator {}

        SliderSettingPlus {
            id: radialMenuOpacity
            settingKey: "radialMenuOpacity"
            label: I18n.trFor("quickCapture", "Radial Menu Opacity")
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
        }
    }

    // ── Tab 14: Shortcuts ────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 14
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: shortcutsTabCol.implicitHeight
        Column {
            id: shortcutsTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                SectionTitle { 
                    id: usageTitle
                    text: I18n.trFor("quickCapture", "Usage Guide")
                    icon: "menu_book" 
                    collapsible: true
                    settingKey: "usageGuideExpanded"
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: usageTitle.isExpanded

                    StyledText {
                        text: I18n.trFor("quickCapture", "Bar Interactions")
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.primary
                    }

                    Column {
                        width: parent.width
                        spacing: 2

                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Action"); actionText: I18n.trFor("quickCapture", "Interaction / Result"); isHeader: true }
                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Left Click"); actionText: I18n.trFor("quickCapture", "Open Quick Capture menu (Popout)") }
                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Middle Click"); actionText: I18n.trFor("quickCapture", "Trigger Middle-Click Action (Default: Interactive Region)") }
                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Right Click"); actionText: I18n.trFor("quickCapture", "Trigger Right-Click Action (Default: Clipboard Annotate)") }
                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Drag Image"); actionText: I18n.trFor("quickCapture", "Drop image onto bar icon to annotate it") }
                    }

                    Separator { opacity: 0.1 }

                    StyledText {
                        text: I18n.trFor("quickCapture", "Annotation Tools")
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.primary
                    }

                    Column {
                        width: parent.width
                        spacing: 2

                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Key"); actionText: I18n.trFor("quickCapture", "Selected Tool / Action"); isHeader: true }
                        ShortcutRow { keyText: "V"; actionText: I18n.trFor("quickCapture", "Select / Move stroke") }
                        ShortcutRow { keyText: "1 - 4"; actionText: I18n.trFor("quickCapture", "Pen, Line, Arrow, Rect") }
                        ShortcutRow { keyText: "Q - R"; actionText: I18n.trFor("quickCapture", "Ellipse, Text, Pixelate, Redact (Q, W, E, R)") }
                        ShortcutRow { keyText: "A - D"; actionText: I18n.trFor("quickCapture", "Stamp, Highlighter, Spotlight (A, S, D)") }
                        ShortcutRow { keyText: "Z / B"; actionText: I18n.trFor("quickCapture", "Callout, Background (Z, B)") }
                        ShortcutRow { keyText: "F / T"; actionText: I18n.trFor("quickCapture", "Color Picker, Eraser (F, T)") }
                    }

                    Separator { opacity: 0.1 }

                    StyledText {
                        text: I18n.trFor("quickCapture", "General Shortcuts")
                        font.pixelSize: Theme.fontSizeLarge
                        font.bold: true
                        color: Theme.primary
                    }

                    Column {
                        width: parent.width
                        spacing: 2

                        ShortcutRow { keyText: I18n.trFor("quickCapture", "Key"); actionText: I18n.trFor("quickCapture", "Shortcut Action"); isHeader: true }
                        ShortcutRow { keyText: "Enter"; actionText: I18n.trFor("quickCapture", "Done (Action based on settings)") }
                        ShortcutRow { keyText: "Esc"; actionText: I18n.trFor("quickCapture", "Discard & Close") }
                        ShortcutRow { keyText: "Tab"; actionText: I18n.trFor("quickCapture", "Toggle between 2 latest presets") }
                        ShortcutRow { keyText: "V"; actionText: I18n.trFor("quickCapture", "Switch to Select Tool") }
                        ShortcutRow { keyText: "C"; actionText: I18n.trFor("quickCapture", "Copy vector / Paste / Duplicate") }
                        ShortcutRow { keyText: "G (Hold)"; actionText: I18n.trFor("quickCapture", "Magnifier Loupe") }
                        ShortcutRow { keyText: "O"; actionText: I18n.trFor("quickCapture", "OCR Text Recognition") }
                        ShortcutRow { keyText: "X"; actionText: I18n.trFor("quickCapture", "Toggle Hide/Show Annotations") }
                        ShortcutRow { keyText: "Ctrl + Z"; actionText: I18n.trFor("quickCapture", "Undo last stroke") }
                        ShortcutRow { keyText: "Ctrl + Y"; actionText: I18n.trFor("quickCapture", "Redo last undone stroke") }
                        ShortcutRow { keyText: "Ctrl + Shift + Z"; actionText: I18n.trFor("quickCapture", "Redo last undone stroke") }
                        ShortcutRow { keyText: "Ctrl + S"; actionText: I18n.trFor("quickCapture", "Force Save to File") }
                        ShortcutRow { keyText: "Ctrl + C"; actionText: I18n.trFor("quickCapture", "Force Copy to Clipboard") }
                        ShortcutRow { keyText: "Ctrl + Shift + C"; actionText: I18n.trFor("quickCapture", "Anonymous Copy (stripped metadata)") }
                        ShortcutRow { keyText: "Ctrl + A"; actionText: I18n.trFor("quickCapture", "Force Copy & Save") }
                        ShortcutRow { keyText: "Ctrl + F"; actionText: I18n.trFor("quickCapture", "Float Image") }
                        ShortcutRow { keyText: "Ctrl + X"; actionText: I18n.trFor("quickCapture", "Crop / Resize Area") }
                        ShortcutRow { keyText: "Ctrl + 1..4"; actionText: I18n.trFor("quickCapture", "Select Color Slots 1 - 4") }
                        ShortcutRow { keyText: "Ctrl + Q..R"; actionText: I18n.trFor("quickCapture", "Select Color Slots 5 - 8 (Q, W, E, R)") }
                    }
                }
            }
        }
    }

    // ── Tab 15: Help ─────────────────────────────────────────────────────────────
    Item {
        visible: tabBar.currentIndex === 15
        width: parent.width
        height: visible ? implicitHeight : 0
        implicitHeight: helpTabCol.implicitHeight
        Column {
            id: helpTabCol
            width: parent.width
            spacing: Theme.spacingM
            SettingsCard {
                SectionTitle {
                    id: ipcTitle
                    text: I18n.trFor("quickCapture", "IPC Commands")
                    icon: "terminal"
                    collapsible: true
                    isExpanded: false
                    settingKey: "ipcCommandsExpanded"
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingM
                    visible: ipcTitle.isExpanded

                    StyledText {
                        width: parent.width
                        text: I18n.trFor("quickCapture", "Each command accepts action: <b>edit</b> (open editor) or <b>float</b> (always-on-top window).")
                        wrapMode: Text.WordWrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        textFormat: Text.RichText
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Interactive Region) — Edit")
                        text: "dms ipc call quickCapture screenshot region edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Interactive Region) — Float")
                        text: "dms ipc call quickCapture screenshot region float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Full Screen) — Edit")
                        text: "dms ipc call quickCapture screenshot full edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Full Screen) — Float")
                        text: "dms ipc call quickCapture screenshot full float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (All Combined Outputs) — Edit")
                        text: "dms ipc call quickCapture screenshot all edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (All Combined Outputs) — Float")
                        text: "dms ipc call quickCapture screenshot all float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Specific Output) — Edit")
                        text: "dms ipc call quickCapture screenshot output edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Specific Output) — Float")
                        text: "dms ipc call quickCapture screenshot output float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Focused Window) — Edit")
                        text: "dms ipc call quickCapture screenshot window edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Focused Window) — Float")
                        text: "dms ipc call quickCapture screenshot window float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Last Selected Region) — Edit")
                        text: "dms ipc call quickCapture screenshot last edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Last Selected Region) — Float")
                        text: "dms ipc call quickCapture screenshot last float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Scrolling Capture) — Edit")
                        text: "dms ipc call quickCapture screenshot scroll edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screenshot (Scrolling Capture) — Float")
                        text: "dms ipc call quickCapture screenshot scroll float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Select Image File — Edit")
                        text: "dms ipc call quickCapture selectFile edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Select Image File — Float")
                        text: "dms ipc call quickCapture selectFile float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Edit Image from Clipboard — Edit")
                        text: "dms ipc call quickCapture fromClipboard edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Edit Image from Clipboard — Float")
                        text: "dms ipc call quickCapture fromClipboard float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Open Specific Image Path — Edit")
                        text: "dms ipc call quickCapture openImage /path/to/image.png edit"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Open Specific Image Path — Float")
                        text: "dms ipc call quickCapture openImage /path/to/image.png float"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Close Annotator")
                        text: "dms ipc call quickCapture close"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Show Recent Edits History")
                        text: "dms ipc call quickCapture showHistory"
                    }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Interactive Region)")
                        text: "dms ipc call quickCapture recordStart region"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Full Screen)")
                        text: "dms ipc call quickCapture recordStart screen"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Window / Portal)")
                        text: "dms ipc call quickCapture recordStart portal"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Stop & Save)")
                        text: "dms ipc call quickCapture recordStop"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Pause / Resume)")
                        text: "dms ipc call quickCapture recordPause"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Cancel)")
                        text: "dms ipc call quickCapture recordCancel"
                    }
                    CopyBox {
                        label: I18n.trFor("quickCapture", "Screen Recording (Toggle Start / Stop)")
                        text: "dms ipc call quickCapture recordToggle"
                    }

                    Separator { opacity: 0.1 }

                    CopyBox {
                        label: I18n.trFor("quickCapture", "Niri Binding Example")
                        text: "binds {\n    Print { spawn \"dms\" \"ipc\" \"call\" \"quickCapture\" \"screenshot\" \"region\" \"edit\"; }\n}"
                    }
                }
            }

            PluginAbout {
                repoUrl: "https://github.com/hthienloc/dms-quick-capture"
            }
        }
    }

    CaptureConfig {
        id: captureConfig
        pluginData: {
            "color_palette_preset": palettePresetSetting.value,
            "catppuccin_variant": catppuccinVariantSetting.value,
            "registry_theme_variant": registryVariantSetting.value,
            "toolbar_color_primary": toolbar_primary.value,
            "toolbar_color_0": c0.value,
            "toolbar_color_1": c1.value,
            "toolbar_color_2": c2.value,
            "toolbar_color_3": c3.value,
            "toolbar_color_4": c4.value,
            "toolbar_color_5": c5.value,
            "toolbar_color_6": c6.value,
            "modalDisplayMode": modalDisplayMode.value,
            "modalScaleToContent": scaleToContent.value
        }
    }

}
