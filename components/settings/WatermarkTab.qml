import QtQuick
import qs.Common
import qs.Widgets
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property bool hasText: watermarkType.value === "text" || watermarkType.value === "hybrid"
    readonly property bool hasImage: watermarkType.value === "image" || watermarkType.value === "hybrid"

    SettingsSection {
        title: I18n.trFor("quickCapture", "Watermark")
        icon: "branding_watermark"

        ToggleSettingPlus {
            settingKey: "defaultWatermark"
            label: I18n.trFor("quickCapture", "Default Watermark")
            defaultValue: Defaults.values.defaultWatermark
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: watermarkType
            settingKey: "watermarkType"
            label: I18n.trFor("quickCapture", "Watermark Type")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Text"),
                    value: "text"
                },
                {
                    label: I18n.trFor("quickCapture", "Image"),
                    value: "image"
                },
                {
                    label: I18n.trFor("quickCapture", "Image + Text"),
                    value: "hybrid"
                }
            ]
            defaultValue: Defaults.values.watermarkType
        }

        Separator {}

        SelectionSettingPlus {
            id: watermarkPosition
            settingKey: "watermarkPosition"
            label: I18n.trFor("quickCapture", "Position")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Top Left"),
                    value: "top_left"
                },
                {
                    label: I18n.trFor("quickCapture", "Top Right"),
                    value: "top_right"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Left"),
                    value: "bottom_left"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Right"),
                    value: "bottom_right"
                },
                {
                    label: I18n.trFor("quickCapture", "Center"),
                    value: "center"
                },
                {
                    label: I18n.trFor("quickCapture", "Top"),
                    value: "top"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom"),
                    value: "bottom"
                },
                {
                    label: I18n.trFor("quickCapture", "Left"),
                    value: "left"
                },
                {
                    label: I18n.trFor("quickCapture", "Right"),
                    value: "right"
                }
            ]
            defaultValue: Defaults.values.watermarkPosition
        }

        Separator {}

        SliderSettingPlus {
            id: watermarkOpacity
            settingKey: "watermarkOpacity"
            label: I18n.trFor("quickCapture", "Opacity")
            defaultValue: Defaults.values.watermarkOpacity
            minimum: 5
            maximum: 100
            unit: "%"
            leftLabel: "5"
            rightLabel: "100"
        }

        SettingsGroup {
            visible: root.hasText

            Separator {}

            StringSettingPlus {
                id: watermarkText
                settingKey: "watermarkText"
                label: I18n.trFor("quickCapture", "Text")
                placeholder: Defaults.values.watermarkText
                defaultValue: Defaults.values.watermarkText
            }

            InfoText {
                text: I18n.trFor("quickCapture", "Format tokens: {user} (Username), \\n (New Line), %Y (Year), %y (2-digit year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second)")
            }

            Separator {}

            SliderSettingPlus {
                id: watermarkTextSize
                settingKey: "watermarkTextSize"
                label: I18n.trFor("quickCapture", "Text Size")
                defaultValue: Defaults.values.watermarkTextSize
                minimum: 1
                maximum: 50
                unit: "%"
                leftLabel: "1"
                rightLabel: "50"
            }
        }

        SettingsGroup {
            visible: root.hasImage

            Separator {}

            StringSettingPlus {
                id: watermarkImage
                settingKey: "watermarkImage"
                label: I18n.trFor("quickCapture", "Image")
                placeholder: "~/Pictures/watermark.png"
                defaultValue: Defaults.values.watermarkImage
                isFile: true
                fileExtensions: ["Image files (*.png *.jpg *.jpeg *.svg *.webp)", "All files (*)"]
            }

            Separator {}

            SliderSettingPlus {
                id: watermarkSize
                settingKey: "watermarkSize"
                label: I18n.trFor("quickCapture", "Image Size")
                defaultValue: Defaults.values.watermarkSize
                minimum: 5
                maximum: 50
                unit: "%"
                leftLabel: "5"
                rightLabel: "50"
            }
        }

        Separator {}

        StyledText {
            text: I18n.trFor("quickCapture", "Live Preview")
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Bold
            color: Theme.surfaceVariantText
        }

        WatermarkPreview {
            config: root.config
            watermarkType: watermarkType.value
            position: watermarkPosition.value
            opacityPercent: watermarkOpacity.value
            text: watermarkText.value
            textSizePercent: watermarkTextSize.value
            imagePath: watermarkImage.value
            imageSizePercent: watermarkSize.value
        }
    }
}
