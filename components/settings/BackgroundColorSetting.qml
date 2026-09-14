import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Column {
    id: root

    required property string settingKey
    required property string label
    required property QtObject config
    property var defaultValue: "slot_1"
    property var value: defaultValue

    property bool isInitialized: false
    readonly property bool isDirty: value.toString() !== defaultValue.toString()

    width: parent.width
    spacing: Theme.spacingS

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

    StyledText {
        text: root.label
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    ColorPalettePicker {
        slotColors: root.config.slotColors
        value: root.value
        customColor: root.config.resolveColor(root.value)
        customLabel: root.value === "primary" ? I18n.trFor("quickCapture", "Primary").toUpperCase() : root.value.toString().toUpperCase()
        onValueSelected: selectedValue => root.value = selectedValue
        onCustomRequested: {
            const picker = PopoutService.colorPickerModal;
            if (!picker)
                return;
            picker.selectedColor = root.config.resolveColor(root.value);
            picker.pickerTitle = root.label;
            picker.onColorSelectedCallback = selectedColor => root.value = selectedColor.toString();
            picker.show();
        }
    }
}
