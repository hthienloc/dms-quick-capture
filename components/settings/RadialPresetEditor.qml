import QtQuick
import qs.Common
import qs.Services
import qs.Widgets
import "../../dms-common"
import "../core/Constants.js" as Constants

SettingsGroup {
    id: root

    required property QtObject config
    required property int presetIndex

    readonly property var meta: Constants.getToolMeta(presetTool.value)

    SelectionSettingPlus {
        id: presetTool
        settingKey: "preset_" + root.presetIndex + "_tool"
        label: I18n.trFor("quickCapture", "Tool")
        options: [
            {
                label: I18n.trFor("quickCapture", "None"),
                value: "none"
            }
        ].concat(root.config.toolOptions(root.config.presetToolIds))
        defaultValue: Constants.defaultRadialTools[root.presetIndex] ?? "none"
        onValueChanged: {
            if (!isInitialized)
                return;
            const inRange = presetThickness.value >= root.meta.min && presetThickness.value <= root.meta.max;
            if (!inRange || presetThickness.value === presetThickness.defaultValue)
                presetThickness.value = root.meta.defaultValue;
        }
    }

    Separator {}

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: I18n.trFor("quickCapture", "Color")
            font.pixelSize: Theme.fontSizeLarge
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        ColorPalettePicker {
            slotColors: root.config.slotColors
            value: presetColor.value
            customColor: root.config.resolveColor(presetColor.value)
            customLabel: presetColor.value === "primary" ? I18n.trFor("quickCapture", "Primary").toUpperCase() : presetColor.value.toString().toUpperCase()
            onValueSelected: selectedValue => presetColor.value = selectedValue
            onCustomRequested: {
                const picker = PopoutService.colorPickerModal;
                if (!picker)
                    return;
                picker.selectedColor = root.config.resolveColor(presetColor.value);
                picker.pickerTitle = I18n.trFor("quickCapture", "Color");
                picker.onColorSelectedCallback = selectedColor => presetColor.value = selectedColor.toString();
                picker.show();
            }
        }

        ColorSettingPlus {
            id: presetColor
            visible: false
            settingKey: "preset_" + root.presetIndex + "_color"
            label: ""
            defaultValue: Constants.defaultRadialColors[root.presetIndex]
        }
    }

    Separator {}

    SliderSettingPlus {
        id: presetThickness
        settingKey: "preset_" + root.presetIndex + "_thickness"
        label: root.config.toolMetricLabel(presetTool.value)
        defaultValue: root.meta.defaultValue
        minimum: root.meta.min
        maximum: root.meta.max
        unit: root.meta.unit
        leftLabel: String(root.meta.min)
        rightLabel: String(root.meta.max)
        previewType: root.meta.previewType
        previewColor: presetColor.value
    }
}
