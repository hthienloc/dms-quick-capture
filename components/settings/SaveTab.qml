import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    SettingsSection {
        title: I18n.trFor("quickCapture", "Save")
        icon: "save"

        ButtonGroupSettingPlus {
            settingKey: "doneAction"
            label: I18n.trFor("quickCapture", "Action on %1").arg("Enter")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Copy"),
                    value: "clipboard"
                },
                {
                    label: I18n.trFor("quickCapture", "Save"),
                    value: "file"
                },
                {
                    label: I18n.trFor("quickCapture", "Copy & Save"),
                    value: "both"
                }
            ]
            defaultValue: Defaults.values.doneAction
        }

        Separator {}

        StringSettingPlus {
            settingKey: "saveDirectory"
            label: I18n.trFor("quickCapture", "Screenshot Folder")
            placeholder: Defaults.values.saveDirectory
            defaultValue: Defaults.values.saveDirectory
            isDirectory: true
        }

        Separator {}

        StringSettingPlus {
            settingKey: "saveFilenamePattern"
            label: I18n.trFor("quickCapture", "Filename Pattern")
            placeholder: Defaults.values.saveFilenamePattern
            defaultValue: Defaults.values.saveFilenamePattern
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Format tokens: %Y (Year), %y (2-digit year), %m (Month), %d (Day), %H (Hour), %M (Minute), %S (Second), {zzz} (Ms)")
        }

        Separator {}

        ButtonGroupSettingPlus {
            id: outputFormat
            settingKey: "outputFormat"
            label: I18n.trFor("quickCapture", "Output Format")
            options: [
                {
                    label: "PNG",
                    value: "png"
                },
                {
                    label: "JPEG",
                    value: "jpg"
                },
                {
                    label: "WebP",
                    value: "webp"
                },
                {
                    label: "PDF",
                    value: "pdf"
                },
                {
                    label: "PPM",
                    value: "ppm"
                }
            ]
            defaultValue: Defaults.values.outputFormat
        }

        InfoText {
            text: I18n.trFor("quickCapture", "Output format applies only to disk saves. Clipboard copies are always PNG.")
        }

        SettingsGroup {
            visible: outputFormat.value === "jpg"

            Separator {}

            SliderSettingPlus {
                settingKey: "jpegQuality"
                label: I18n.trFor("quickCapture", "JPEG Quality")
                defaultValue: Defaults.values.jpegQuality
                minimum: 1
                maximum: 100
                unit: "%"
                leftLabel: "1"
                rightLabel: "100"
            }
        }

        SettingsGroup {
            visible: outputFormat.value === "webp"

            Separator {}

            SliderSettingPlus {
                settingKey: "webpQuality"
                label: I18n.trFor("quickCapture", "WebP Quality")
                defaultValue: Defaults.values.webpQuality
                minimum: 1
                maximum: 100
                unit: "%"
                leftLabel: "1"
                rightLabel: "100"
            }
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Notifications")
        icon: "notifications"

        ButtonGroupSettingPlus {
            settingKey: "postNotification"
            label: I18n.trFor("quickCapture", "Post-Capture Notification")
            description: I18n.trFor("quickCapture", "Choose notifications shown after copy or save.")
            defaultValue: Defaults.values.postNotification
            options: [
                {
                    label: I18n.trFor("quickCapture", "Notification"),
                    value: "notification"
                },
                {
                    label: I18n.trFor("quickCapture", "Toast"),
                    value: "toast"
                },
                {
                    label: I18n.trFor("quickCapture", "Both"),
                    value: "both"
                },
                {
                    label: I18n.trFor("quickCapture", "None"),
                    value: "none"
                }
            ]
        }
    }
}
