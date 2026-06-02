import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property bool defaultValue: false
    property bool value: defaultValue

    width: parent.width
    height: 36 // Giảm chiều cao
    spacing: Theme.spacingM

    property bool isInitialized: false
    readonly property bool isDirty: value !== defaultValue

    function resetToDefault() {
        console.log(`[ToggleSettingPlus] Resetting ${settingKey} to ${defaultValue}`);
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

    Component.onCompleted: {
        Qt.callLater(loadValue);
    }

    onValueChanged: {
        if (!isInitialized)
            return;
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

    Column {
        width: parent.width - toggle.width - parent.spacing
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        Row {
            spacing: Theme.spacingXS
            width: parent.width

            StyledText {
                text: root.label
                font.pixelSize: Theme.fontSizeLarge
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
    }

    DankTooltipV2 {
        id: sharedTooltip
    }

    DankToggle {
        id: toggle
        anchors.verticalCenter: parent.verticalCenter
        checked: root.value
        onToggled: isChecked => {
            root.value = isChecked;
        }
    }
}
