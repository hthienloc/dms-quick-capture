import QtQuick
import qs.Common
import qs.Widgets
import "../popovers"
import "../core/Constants.js" as Constants

PopoverSurface {
    id: root

    property bool watermarkEnabled: false
    property bool floatingMode: false

    signal actionTriggered(string action)
    signal watermarkToggled(bool enabled)

    readonly property var quickActions: [
        {
            action: "rotateLeft",
            icon: "rotate_left",
            label: I18n.trFor("quickCapture", "Rotate Left")
        },
        {
            action: "rotateRight",
            icon: "rotate_right",
            label: I18n.trFor("quickCapture", "Rotate Right")
        },
        {
            action: "flipHorizontal",
            icon: "flip",
            label: I18n.trFor("quickCapture", "Flip Horizontal")
        },
        {
            action: "flipVertical",
            icon: "swap_vert",
            label: I18n.trFor("quickCapture", "Flip Vertical")
        }
    ]

    readonly property var menuActions: [
        {
            action: "insertImage",
            icon: "add_photo_alternate",
            label: I18n.trFor("quickCapture", "Insert Image"),
            shortcut: "I"
        },
        {
            action: "ocr",
            icon: "document_scanner",
            label: I18n.trFor("quickCapture", "OCR"),
            shortcut: "O"
        },
        {
            action: "qr",
            icon: "qr_code",
            label: I18n.trFor("quickCapture", "Scan QR"),
            shortcut: ""
        },
        {
            action: "eraser",
            icon: "auto_fix_normal",
            label: I18n.trFor("quickCapture", "Eraser"),
            shortcut: "T"
        },
        {
            action: "copyColor",
            icon: "colorize",
            label: I18n.trFor("quickCapture", "Copy Color"),
            shortcut: ""
        }
    ]

    width: 160
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    z: 10000

    function trigger(action) {
        root.close();
        root.actionTriggered(action);
    }

    component MenuDivider: Rectangle {
        width: parent.width
        height: 1
        color: Theme.withAlpha(Theme.outline, 0.15)
    }

    Column {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Constants.spacingCompact

        Grid {
            width: parent.width
            columns: 2
            spacing: Constants.spacingCompact

            Repeater {
                model: root.quickActions

                delegate: Rectangle {
                    id: quickAction
                    required property var modelData
                    width: (parent.width - Constants.spacingCompact) / 2
                    height: 44
                    radius: Theme.cornerRadius - 2
                    color: quickArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: quickAction.modelData.icon
                            size: Theme.iconSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: quickAction.modelData.label
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: quickArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionTriggered(quickAction.modelData.action)
                    }
                }
            }
        }

        MenuDivider {}

        MenuActionItem {
            iconName: "branding_watermark"
            text: I18n.trFor("quickCapture", "Watermark")
            shortcut: "M"
            checked: root.watermarkEnabled
            onActivated: root.watermarkToggled(!root.watermarkEnabled)
        }

        MenuDivider {}

        MenuActionItem {
            iconName: root.floatingMode ? "picture_in_picture_alt" : "open_in_new"
            text: root.floatingMode ? I18n.trFor("quickCapture", "Use Modal Editor") : I18n.trFor("quickCapture", "Use Floating Editor")
            onActivated: root.trigger("presentation")
        }

        MenuDivider {}

        Repeater {
            model: root.menuActions

            delegate: MenuActionItem {
                required property var modelData
                iconName: modelData.icon
                text: modelData.label
                shortcut: modelData.shortcut
                onActivated: root.trigger(modelData.action)
            }
        }
    }
}
