import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property bool imageMode: backgroundMode.value === "image"
    readonly property bool gradientMode: ["gradient", "radial", "conic"].includes(backgroundMode.value)

    SettingsSection {
        title: I18n.trFor("quickCapture", "Background Defaults")
        icon: "wallpaper"

        ToggleSettingPlus {
            settingKey: "backgroundAutoApply"
            label: I18n.trFor("quickCapture", "Auto-apply background defaults")
            description: I18n.trFor("quickCapture", "Enable background automatically when opening the editor")
            defaultValue: Defaults.values.backgroundAutoApply
        }

        Separator {}

        SelectionSettingPlus {
            id: backgroundMode
            settingKey: "backgroundDefaultMode"
            label: I18n.trFor("quickCapture", "Background Mode")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Solid Color"),
                    value: "solid"
                },
                {
                    label: I18n.trFor("quickCapture", "Linear Gradient"),
                    value: "gradient"
                },
                {
                    label: I18n.trFor("quickCapture", "Radial Gradient"),
                    value: "radial"
                },
                {
                    label: I18n.trFor("quickCapture", "Conic Gradient"),
                    value: "conic"
                },
                {
                    label: I18n.trFor("quickCapture", "Image"),
                    value: "image"
                }
            ]
            defaultValue: Defaults.values.backgroundDefaultMode
        }

        SettingsGroup {
            visible: root.imageMode

            Separator {}

            StringSettingPlus {
                settingKey: "backgroundImageFolder"
                label: I18n.trFor("quickCapture", "Image Folder")
                placeholder: Defaults.values.backgroundImageFolder
                defaultValue: Defaults.values.backgroundImageFolder
                isDirectory: true
            }

            Separator {}

            StringSettingPlus {
                settingKey: "backgroundDefaultImagePath"
                label: I18n.trFor("quickCapture", "Background image")
                description: I18n.trFor("quickCapture", "Image selected automatically when using Image Background mode")
                placeholder: "~/Pictures/Wallpaper/image.jpg"
                defaultValue: Defaults.values.backgroundDefaultImagePath
                isFile: true
                fileExtensions: ["Image files (*.png *.jpg *.jpeg *.webp *.bmp)", "All files (*)"]
            }

            Separator {}

            ToggleSettingPlus {
                settingKey: "backgroundImageBlur"
                label: I18n.trFor("quickCapture", "Blur Background Image")
                description: I18n.trFor("quickCapture", "Soften image details so screenshot content stands out")
                defaultValue: Defaults.values.backgroundImageBlur
            }

            Separator {}

            ToggleSettingPlus {
                id: imageDim
                settingKey: "backgroundImageDim"
                label: I18n.trFor("quickCapture", "Dim Background Image")
                description: I18n.trFor("quickCapture", "Darken the image to improve foreground contrast")
                defaultValue: Defaults.values.backgroundImageDim
            }

            SettingsGroup {
                visible: imageDim.value

                Separator {}

                SliderSettingPlus {
                    settingKey: "backgroundImageDimStrength"
                    label: I18n.trFor("quickCapture", "Dim Intensity")
                    defaultValue: Defaults.values.backgroundImageDimStrength
                    minimum: 0
                    maximum: 80
                    unit: "%"
                    leftLabel: "0"
                    rightLabel: "80"
                }
            }
        }

        SettingsGroup {
            visible: backgroundMode.value === "solid"

            Separator {}

            BackgroundColorSetting {
                settingKey: "backgroundDefaultSolidColor"
                label: I18n.trFor("quickCapture", "Solid Color")
                defaultValue: Defaults.values.backgroundDefaultSolidColor
                config: root.config
            }
        }

        SettingsGroup {
            visible: root.gradientMode

            Separator {}

            BackgroundColorSetting {
                settingKey: "backgroundDefaultGradientStart"
                label: I18n.trFor("quickCapture", "Gradient Start")
                defaultValue: Defaults.values.backgroundDefaultGradientStart
                config: root.config
            }

            Separator {}

            BackgroundColorSetting {
                settingKey: "backgroundDefaultGradientEnd"
                label: I18n.trFor("quickCapture", "Gradient End")
                defaultValue: Defaults.values.backgroundDefaultGradientEnd
                config: root.config
            }
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "backgroundDefaultPadding"
            label: I18n.trFor("quickCapture", "Padding")
            defaultValue: Defaults.values.backgroundDefaultPadding
            minimum: 0
            maximum: 150
            unit: "px"
            leftLabel: "0"
            rightLabel: "150"
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "backgroundDefaultRadius"
            label: I18n.trFor("quickCapture", "Corner Radius")
            defaultValue: Defaults.values.backgroundDefaultRadius
            minimum: 0
            maximum: 60
            unit: "px"
            leftLabel: "0"
            rightLabel: "60"
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "backgroundDefaultShadow"
            label: I18n.trFor("quickCapture", "Shadow Strength")
            defaultValue: Defaults.values.backgroundDefaultShadow
            minimum: 0
            maximum: 100
            unit: "%"
            leftLabel: "0"
            rightLabel: "100"
        }

        Separator {}

        SliderSettingPlus {
            settingKey: "backgroundDefaultAngle"
            label: I18n.trFor("quickCapture", "Gradient Angle")
            defaultValue: Defaults.values.backgroundDefaultAngle
            minimum: 0
            maximum: 360
            unit: "°"
            leftLabel: "0"
            rightLabel: "360"
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "backgroundDefaultAspectRatio"
            label: I18n.trFor("quickCapture", "Aspect Ratio")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Auto"),
                    value: "auto"
                },
                {
                    label: "1:1",
                    value: "1:1"
                },
                {
                    label: "16:9",
                    value: "16:9"
                },
                {
                    label: "9:16",
                    value: "9:16"
                },
                {
                    label: "4:3",
                    value: "4:3"
                },
                {
                    label: "3:2",
                    value: "3:2"
                },
                {
                    label: "21:9",
                    value: "21:9"
                }
            ]
            defaultValue: Defaults.values.backgroundDefaultAspectRatio
        }

        Separator {}

        SelectionSettingPlus {
            settingKey: "backgroundDefaultAlignment"
            label: I18n.trFor("quickCapture", "Alignment")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Top Left"),
                    value: "top-left"
                },
                {
                    label: I18n.trFor("quickCapture", "Top Center"),
                    value: "top-center"
                },
                {
                    label: I18n.trFor("quickCapture", "Top Right"),
                    value: "top-right"
                },
                {
                    label: I18n.trFor("quickCapture", "Left Center"),
                    value: "center-left"
                },
                {
                    label: I18n.trFor("quickCapture", "Center"),
                    value: "center"
                },
                {
                    label: I18n.trFor("quickCapture", "Right Center"),
                    value: "center-right"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Left"),
                    value: "bottom-left"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Center"),
                    value: "bottom-center"
                },
                {
                    label: I18n.trFor("quickCapture", "Bottom Right"),
                    value: "bottom-right"
                }
            ]
            defaultValue: Defaults.values.backgroundDefaultAlignment
        }
    }
}
