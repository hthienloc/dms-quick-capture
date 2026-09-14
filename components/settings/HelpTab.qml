import QtQuick
import qs.Common
import qs.Widgets
import "../../dms-common"

SettingsGroup {
    id: root

    property QtObject config: null

    readonly property var barRows: [
        {
            key: I18n.trFor("quickCapture", "Left Click"),
            action: I18n.trFor("quickCapture", "Open %1 menu (Popout)").arg(I18n.trFor("quickCapture", "Quick Capture"))
        },
        {
            key: I18n.trFor("quickCapture", "Middle Click"),
            action: I18n.trFor("quickCapture", "Middle Click Action")
        },
        {
            key: I18n.trFor("quickCapture", "Right Click"),
            action: I18n.trFor("quickCapture", "Right Click Action")
        },
        {
            key: I18n.trFor("quickCapture", "Drag Image"),
            action: I18n.trFor("quickCapture", "Drop image onto bar icon to annotate it")
        }
    ]

    readonly property var toolRows: config.tools.filter(t => t.shortcut !== "").map(t => ({
                key: t.shortcut,
                action: t.label
            }))

    readonly property var generalRows: [
        {
            key: "Enter",
            action: I18n.trFor("quickCapture", "Done")
        },
        {
            key: "Esc",
            action: I18n.trFor("quickCapture", "Discard & Close")
        },
        {
            key: "Tab",
            action: I18n.trFor("quickCapture", "Toggle between %1 latest presets").arg(2)
        },
        {
            key: "C",
            action: I18n.trFor("quickCapture", "Copy vector / Paste / Duplicate")
        },
        {
            key: "G (Hold)",
            action: I18n.trFor("quickCapture", "Magnifier Loupe")
        },
        {
            key: "O",
            action: I18n.trFor("quickCapture", "OCR")
        },
        {
            key: "X",
            action: I18n.trFor("quickCapture", "Toggle Annotations")
        },
        {
            key: "Ctrl + Z",
            action: I18n.trFor("quickCapture", "Undo")
        },
        {
            key: "Ctrl + Y",
            action: I18n.trFor("quickCapture", "Redo")
        },
        {
            key: "Ctrl + Shift + Z",
            action: I18n.trFor("quickCapture", "Redo")
        },
        {
            key: "Ctrl + S",
            action: I18n.trFor("quickCapture", "Save")
        },
        {
            key: "Ctrl + Shift + S",
            action: I18n.trFor("quickCapture", "Save As")
        },
        {
            key: "Ctrl + C",
            action: I18n.trFor("quickCapture", "Copy")
        },
        {
            key: "Ctrl + Shift + C",
            action: I18n.trFor("quickCapture", "Anonymous Copy")
        },
        {
            key: "Ctrl + A",
            action: I18n.trFor("quickCapture", "Copy & Save")
        },
        {
            key: "Ctrl + F",
            action: I18n.trFor("quickCapture", "Float")
        },
        {
            key: "Ctrl + X",
            action: I18n.trFor("quickCapture", "Crop / Resize")
        },
        {
            key: "Ctrl + 1..4",
            action: I18n.trFor("quickCapture", "Select Color Slots %1").arg("1 - 4")
        },
        {
            key: "Ctrl + Q..R",
            action: I18n.trFor("quickCapture", "Select Color Slots %1").arg("5 - 8")
        }
    ]

    readonly property var screenshotCommands: ["region", "full", "all", "output", "window", "last", "scroll"].map(mode => ({
                label: I18n.trFor("quickCapture", "Screenshot") + " · " + root.config.captureModeLabel(mode),
                command: "screenshot " + mode
            })).concat([
        {
            label: I18n.trFor("quickCapture", "File"),
            command: "selectFile"
        },
        {
            label: I18n.trFor("quickCapture", "Clipboard"),
            command: "fromClipboard"
        },
        {
            label: I18n.trFor("quickCapture", "Open Image"),
            command: "openImage /path/to/image.png"
        }
    ])

    readonly property var otherCommands: [
        {
            label: I18n.trFor("quickCapture", "Close"),
            command: "close"
        },
        {
            label: I18n.trFor("quickCapture", "Recent Edits"),
            command: "showHistory"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Region"),
            command: "recordStart region"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Fullscreen"),
            command: "recordStart screen"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Window / Portal"),
            command: "recordStart portal"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Stop & Save"),
            command: "recordStop"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Pause / Resume"),
            command: "recordPause"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Cancel"),
            command: "recordCancel"
        },
        {
            label: I18n.trFor("quickCapture", "Screen Recording") + " · " + I18n.trFor("quickCapture", "Toggle Start / Stop"),
            command: "recordToggle"
        }
    ]

    component GuideHeading: StyledText {
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    component ShortcutTable: Column {
        property string keyHeader: ""
        property string actionHeader: ""
        property var rows: []

        width: parent.width
        spacing: 2

        ShortcutRow {
            keyText: parent.keyHeader
            actionText: parent.actionHeader
            isHeader: true
        }

        Repeater {
            model: parent.rows

            delegate: ShortcutRow {
                required property var modelData
                keyText: modelData.key
                actionText: modelData.action
            }
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "Usage Guide")
        icon: "menu_book"
        resettable: false
        collapsible: true
        stateKey: "usageGuideExpanded"

        GuideHeading {
            text: I18n.trFor("quickCapture", "Bar Interactions")
        }

        ShortcutTable {
            keyHeader: I18n.trFor("quickCapture", "Action")
            actionHeader: I18n.trFor("quickCapture", "Interaction / Result")
            rows: root.barRows
        }

        Separator {}

        GuideHeading {
            text: I18n.trFor("quickCapture", "Annotation Tools")
        }

        ShortcutTable {
            keyHeader: I18n.trFor("quickCapture", "Key")
            actionHeader: I18n.trFor("quickCapture", "Selected Tool / Action")
            rows: root.toolRows
        }

        Separator {}

        GuideHeading {
            text: I18n.trFor("quickCapture", "General Shortcuts")
        }

        ShortcutTable {
            keyHeader: I18n.trFor("quickCapture", "Key")
            actionHeader: I18n.trFor("quickCapture", "Shortcut Action")
            rows: root.generalRows
        }
    }

    SettingsSection {
        title: I18n.trFor("quickCapture", "IPC Commands")
        icon: "terminal"
        resettable: false
        collapsible: true
        expanded: false
        stateKey: "ipcCommandsExpanded"

        StyledText {
            width: parent.width
            text: I18n.trFor("quickCapture", "Each command accepts action: %1 (open editor) or %2 (always-on-top window).").arg("<b>edit</b>").arg("<b>float</b>")
            wrapMode: Text.WordWrap
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            textFormat: Text.RichText
        }

        Repeater {
            model: root.screenshotCommands

            delegate: Column {
                required property var modelData
                width: parent.width
                spacing: Theme.spacingS

                CopyBox {
                    label: modelData.label + " · " + I18n.trFor("quickCapture", "Edit")
                    text: "dms ipc call quickCapture " + modelData.command + " edit"
                }

                CopyBox {
                    label: modelData.label + " · " + I18n.trFor("quickCapture", "Float")
                    text: "dms ipc call quickCapture " + modelData.command + " float"
                }
            }
        }

        Repeater {
            model: root.otherCommands

            delegate: CopyBox {
                required property var modelData
                label: modelData.label
                text: "dms ipc call quickCapture " + modelData.command
            }
        }

        Separator {}

        CopyBox {
            label: I18n.trFor("quickCapture", "Niri Binding Example")
            text: "binds {\n    Print { spawn \"dms\" \"ipc\" \"call\" \"quickCapture\" \"screenshot\" \"region\" \"edit\"; }\n}"
        }
    }

    PluginAbout {
        repoUrl: "https://github.com/hthienloc/dms-quick-capture"
    }
}
