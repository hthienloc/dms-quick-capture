import QtQuick
import qs.Common
import "../../dms-common"

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property var captureModes: [
        {
            label: I18n.trFor("quickCapture", "Region"),
            value: "region"
        },
        {
            label: I18n.trFor("quickCapture", "Fullscreen"),
            value: "full"
        },
        {
            label: I18n.trFor("quickCapture", "All Outputs"),
            value: "all"
        },
        {
            label: I18n.trFor("quickCapture", "Specific Output"),
            value: "output"
        },
        {
            label: I18n.trFor("quickCapture", "Window"),
            value: "window"
        },
        {
            label: I18n.trFor("quickCapture", "Last Region"),
            value: "last"
        },
        {
            label: I18n.trFor("quickCapture", "Scrolling"),
            value: "scroll"
        },
        {
            label: I18n.trFor("quickCapture", "Clipboard"),
            value: "clipboard"
        },
        {
            label: I18n.trFor("quickCapture", "File"),
            value: "selectFile"
        }
    ]

    SettingsSection {
        title: I18n.trFor("quickCapture", "Capture Actions")
        icon: "mouse"

        SelectionSettingPlus {
            settingKey: "middleClickAction"
            label: I18n.trFor("quickCapture", "Middle Click Action")
            options: root.captureModes
            defaultValue: "region"
        }

        SelectionSettingPlus {
            settingKey: "rightClickAction"
            label: I18n.trFor("quickCapture", "Right Click Action")
            options: root.captureModes
            defaultValue: "clipboard"
        }

        SelectionSettingPlus {
            settingKey: "menuRightClickAction"
            label: I18n.trFor("quickCapture", "Menu Item Right Click")
            options: [
                {
                    label: I18n.trFor("quickCapture", "Copy"),
                    value: "copy"
                },
                {
                    label: I18n.trFor("quickCapture", "Save"),
                    value: "save"
                },
                {
                    label: I18n.trFor("quickCapture", "Copy & Save"),
                    value: "copyAndSave"
                },
                {
                    label: I18n.trFor("quickCapture", "Float"),
                    value: "float"
                }
            ]
            defaultValue: "copy"
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Capture Options")
        icon: "settings"

        StringSettingPlus {
            settingKey: "outputTargetName"
            label: I18n.trFor("quickCapture", "Target Output Name")
            placeholder: "e.g. eDP-1"
            defaultValue: ""
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "skipConfirm"
            label: I18n.trFor("quickCapture", "Skip confirmation")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "includeCursor"
            label: I18n.trFor("quickCapture", "Include Cursor")
            defaultValue: false
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "defaultHideControlCenter"
            label: I18n.trFor("quickCapture", "Hide Control Center by Default")
            description: I18n.trFor("quickCapture", "Initial state for the Control Center toggle.")
            defaultValue: true
        }

        Separator {}

        ToggleSettingPlus {
            settingKey: "resetLastRegion"
            label: I18n.trFor("quickCapture", "Reset Last Region")
            description: I18n.trFor("quickCapture", "Clear saved region selection before each capture")
            defaultValue: false
        }

        Separator {}

        InfoText {
            text: I18n.trFor("quickCapture", "Scroll capture: select a region, scroll content, then press %1 to finish.").arg("Enter")
        }

        SliderSettingPlus {
            settingKey: "scrollInterval"
            label: I18n.trFor("quickCapture", "Scroll Interval")
            defaultValue: 500
            minimum: 200
            maximum: 2000
            unit: "ms"
            leftLabel: "200"
            rightLabel: "2000"
        }
    }
}
