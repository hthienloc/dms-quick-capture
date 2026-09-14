import QtQuick
import qs.Common
import "../../dms-common"
import "../core/Defaults.js" as Defaults

SettingsGroup {
    id: root

    property QtObject config: null

    SettingsSection {
        title: I18n.trFor("quickCapture", "Toolbar")
        icon: "dock"

        ToggleSettingPlus {
            id: showToolbar
            settingKey: "showToolbar"
            label: I18n.trFor("quickCapture", "Show Toolbar")
            defaultValue: Defaults.values.showToolbar
        }

        SettingsGroup {
            visible: showToolbar.value

            Separator {}

            ButtonGroupSettingPlus {
                settingKey: "toolbarPosition"
                label: I18n.trFor("quickCapture", "Toolbar Position")
                options: [
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
                defaultValue: Defaults.values.toolbarPosition
            }

            Separator {}

            ToggleSettingPlus {
                settingKey: "showToolbarBorder"
                label: I18n.trFor("quickCapture", "Show Toolbar Border")
                defaultValue: Defaults.values.showToolbarBorder
            }

            Separator {}

            ToggleSettingPlus {
                settingKey: "show_shortcut_hints"
                label: I18n.trFor("quickCapture", "Show Keyboard Shortcut Hints")
                defaultValue: Defaults.values.show_shortcut_hints
            }
        }
    }
}
