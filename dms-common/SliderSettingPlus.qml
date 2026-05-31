import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property int defaultValue: 0
    property int value: defaultValue
    property int minimum: 0
    property int maximum: 100
    property string leftIcon: ""
    property string rightIcon: ""
    property string leftLabel: ""
    property string rightLabel: ""
    property string unit: ""

    width: parent.width
    spacing: 0

    readonly property bool isDirty: Math.round(value) !== Math.round(defaultValue)

    function resetToDefault() {
        console.log(`[SliderSettingPlus] Resetting ${settingKey} to ${defaultValue}`);
        value = defaultValue;
        dankSlider.value = defaultValue; // Force update because DankSlider breaks bindings on interaction
    }

    function loadValue() {
        const settings = findSettings();
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue);
        }
    }

    Component.onCompleted: {
        loadValue();
    }

    onValueChanged: {
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, value);
        }
    }

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) {
                return item;
            }
            item = item.parent;
        }
        return null;
    }

    // Label Row (matches standard height)
    Item {
        width: parent.width
        height: 36 // Giảm chiều cao tiêu đề

        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width

            StyledText {
                text: root.label
                font.pixelSize: Theme.fontSizeLarge // Tăng cỡ chữ
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
                width: Math.min(implicitWidth, parent.width - (infoIcon.visible ? infoIcon.width + parent.spacing : 0))
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

        // Individual Reset Button
        Item {
            id: individualReset
            width: 28
            height: 28
            visible: root.isDirty
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: resetArea.containsMouse ? Theme.primaryHoverLight : "transparent"
            }

            DankIcon {
                name: "restart_alt"
                size: 16
                color: Theme.primary
                anchors.centerIn: parent
                opacity: parent.visible ? 0.8 : 0
                
                Behavior on opacity { NumberAnimation { duration: Appearance.anim.durations.quick } }
            }

            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetToDefault()
            }
        }

        DankTooltipV2 {
            id: sharedTooltip
        }
    }

    // Slider Row
    Row {
        width: parent.width
        height: 32
        spacing: Theme.spacingS

        StyledText {
            text: root.leftLabel
            visible: text !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        DankSlider {
            id: dankSlider
            width: parent.width - (leftLbl.implicitWidth + rightLbl.implicitWidth + (root.leftLabel !== "" ? parent.spacing : 0) + (root.rightLabel !== "" ? parent.spacing : 0))
            height: 32
            value: root.value
            minimum: root.minimum
            maximum: root.maximum
            leftIcon: root.leftIcon
            rightIcon: root.rightIcon
            unit: root.unit
            wheelEnabled: false
            thumbOutlineColor: Theme.withAlpha(Theme.surfaceContainerHighest, Theme.popupTransparency)
            onSliderValueChanged: newValue => {
                root.value = newValue;
            }

            // Hidden metrics for width calculation
            StyledText { id: leftLbl; text: root.leftLabel; visible: false; font.pixelSize: Theme.fontSizeSmall }
            StyledText { id: rightLbl; text: root.rightLabel; visible: false; font.pixelSize: Theme.fontSizeSmall }
        }

        StyledText {
            text: root.rightLabel
            visible: text !== ""
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // Extra bottom padding for sliders to separate from next item/line
    Item { width: 1; height: Theme.spacingS }
}
