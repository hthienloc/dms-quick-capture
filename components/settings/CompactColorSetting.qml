import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: root

    required property string settingKey
    required property string label
    property var defaultValue: "primary"
    property var value: defaultValue
    property bool readOnly: false
    property var overrideColor: null

    property bool isInitialized: false
    readonly property bool isDirty: value.toString() !== defaultValue.toString()

    readonly property color resolvedColor: {
        if (overrideColor !== null)
            return Qt.color(overrideColor);
        if (value === "primary")
            return Theme.primary;
        return Qt.color(value);
    }

    readonly property string colorLabel: {
        if (overrideColor !== null)
            return overrideColor.toString().toUpperCase();
        return value === "primary" ? I18n.trFor("quickCapture", "Primary") : value.toString().toUpperCase();
    }

    width: (parent.width - (parent.columns - 1) * parent.columnSpacing) / parent.columns
    height: 76

    function resetToDefault() {
        value = defaultValue;
    }

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined)
                return item;
            item = item.parent;
        }
        return null;
    }

    function loadValue() {
        const settings = findSettings();
        if (!settings?.pluginService)
            return;
        value = settings.loadValue(settingKey, defaultValue);
        isInitialized = true;
    }

    Component.onCompleted: Qt.callLater(loadValue)

    onValueChanged: {
        if (!isInitialized)
            return;
        findSettings()?.saveValue(settingKey, value);
    }

    function pickColor() {
        if (root.readOnly) {
            const colorStr = root.overrideColor !== null ? root.overrideColor.toString() : root.value.toString();
            Proc.runCommand("quickCapture.copyColor", [Proc.dmsBin, "cl", "copy", colorStr], () => {
                ToastService.showInfo(I18n.trFor("quickCapture", "Color %1 copied").arg(colorStr.toUpperCase()));
            });
            return;
        }
        const picker = PopoutService.colorPickerModal;
        if (!picker)
            return;
        picker.selectedColor = root.resolvedColor;
        picker.pickerTitle = root.label;
        picker.onColorSelectedCallback = selectedColor => root.value = selectedColor.toString();
        picker.show();
    }

    Column {
        anchors.fill: parent
        spacing: Theme.spacingXS

        Item {
            width: 44
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter

            HoverHandler {
                id: hoverHandler
            }

            Rectangle {
                anchors.centerIn: parent
                width: 52
                height: 52
                radius: 26
                color: hoverHandler.hovered ? Theme.withAlpha(Theme.primary, 0.12) : "transparent"
                border.color: Theme.primary
                border.width: hoverHandler.hovered ? 1.5 : 0
                opacity: hoverHandler.hovered ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.shorterDuration
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: 22
                color: root.resolvedColor
                border.color: Theme.outlineStrong
                border.width: 1.5
                scale: hoverHandler.hovered ? 1.08 : 1.0
                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.shorterDuration
                        easing.type: Theme.standardEasing
                    }
                }

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
                    visible: root.isDirty && !root.readOnly

                    DankIcon {
                        name: "restart_alt"
                        size: 10
                        color: Theme.primary
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.resetToDefault()
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onEntered: tooltip.show(root.colorLabel, parent)
                onExited: tooltip.hide()
                onClicked: root.pickColor()
            }
        }

        StyledText {
            text: root.label
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

    DankTooltipV2 {
        id: tooltip
    }
}
