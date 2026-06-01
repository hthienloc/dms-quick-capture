import QtQuick
import qs.Common
import qs.Widgets

Item {
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
    implicitHeight: layout.implicitHeight
    
    // Dynamic Opacity for disabled state
    opacity: enabled ? 1 : 0.5

    property string previewType: "" // "", "thickness", "opacity", "fontSize"
    property var previewColor: Theme.primary

    readonly property color resolvedPreviewColor: {
        if (typeof previewColor === "string" && previewColor === "primary") return Theme.primary;
        return previewColor;
    }
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    property bool isInitialized: false
    readonly property bool isDirty: Math.round(value) !== Math.round(defaultValue)

    function resetToDefault() {
        console.log(`[SliderSettingPlus] Resetting ${settingKey}`);
        value = defaultValue;
        dankSlider.value = defaultValue;
    }

    function loadValue() {
        const settings = findSettings();
        if (settings && settings.pluginService) {
            const val = settings.loadValue(settingKey, defaultValue);
            value = val;
            dankSlider.value = val;
            isInitialized = true;
        }
    }

    Component.onCompleted: {
        Qt.callLater(loadValue);
    }

    onValueChanged: {
        if (!isInitialized) return;
        const settings = findSettings();
        if (settings) {
            settings.saveValue(settingKey, Math.round(value));
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

    HoverHandler {
        id: rootHoverHandler
    }

    Rectangle {
        id: highlightBg
        anchors.fill: parent
        anchors.leftMargin: -12
        anchors.rightMargin: -12
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        radius: Theme.cornerRadius
        color: rootHoverHandler.hovered ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Column {
        id: layout
        anchors.fill: parent
        spacing: 0

        // ── Label Row ─────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 36

            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: individualReset.visible ? individualReset.left : parent.right
                anchors.rightMargin: Theme.spacingS

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

            // Individual Reset Button
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

            DankTooltipV2 { id: sharedTooltip }
        }

        // ── Slider Row ────────────────────────────────────────────────────────
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

            DankSliderPlus {
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
                previewType: root.previewType
                previewColor: root.resolvedPreviewColor
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

        // Extra bottom padding
        Item { width: 1; height: Theme.spacingS }
    }
}
