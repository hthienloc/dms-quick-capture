import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property var defaultValue: Theme.primary
    property var value: defaultValue

    width: parent.width
    spacing: Theme.spacingXS
    
    // Dynamic Opacity for disabled state
    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    property bool isInitialized: false
    readonly property bool isDirty: value.toString() !== defaultValue.toString()

    readonly property color resolvedColor: {
        if (value === "primary") return Theme.primary;
        return Qt.color(value);
    }

    function resetToDefault() {
        console.log(`[ColorSettingPlus] Resetting ${settingKey}`);
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

    // ── Label Row ─────────────────────────────────────────────────────────
    Item {
        width: parent.width
        height: 32

        Row {
            anchors.left: parent.left
            anchors.right: individualReset.visible ? individualReset.left : parent.right
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            StyledText {
                text: root.label
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, parent.width - (infoIcon.visible ? 20 : 0))
            }

            DankIcon {
                id: infoIcon
                name: "info"
                size: 16
                color: Theme.primary
                visible: root.description !== ""
                anchors.verticalCenter: parent.verticalCenter
                opacity: 0.6
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: sharedTooltip.show(root.description, infoIcon)
                    onExited: sharedTooltip.hide()
                }
            }
        }

        Item {
            id: individualReset
            width: 28; height: 28
            visible: root.isDirty
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                anchors.fill: parent
                radius: 14
                color: resetArea.containsMouse ? Theme.primaryHoverLight : "transparent"
            }
            DankIcon {
                name: "restart_alt"
                size: 16
                color: Theme.primary
                anchors.centerIn: parent
                opacity: 0.8
            }
            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefault()
            }
        }
    }

    // ── Color Preview (Full Width + Hex Label) ────────────────────────────
    Rectangle {
        id: colorPreview
        width: parent.width
        height: 32
        radius: Theme.cornerRadius
        color: root.resolvedColor
        border.color: Theme.outlineStrong
        border.width: 2
        
        Behavior on color { ColorAnimation { duration: Theme.shortDuration } }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            
            DankIcon {
                name: "palette"
                size: 14
                color: root.resolvedColor.hslLightness > 0.6 ? "#000000" : "#ffffff"
                opacity: 0.7
            }

            StyledText {
                text: root.value === "primary" ? I18n.tr("PRIMARY") : root.value.toString().toUpperCase()
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                isMonospace: true
                color: root.resolvedColor.hslLightness > 0.6 ? "#000000" : "#ffffff"
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                    PopoutService.colorPickerModal.selectedColor = root.resolvedColor;
                    PopoutService.colorPickerModal.pickerTitle = root.label;
                    PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                        root.value = selectedColor.toString();
                    };
                    PopoutService.colorPickerModal.show();
                }
            }
        }
    }

    DankTooltipV2 { id: sharedTooltip }
}
