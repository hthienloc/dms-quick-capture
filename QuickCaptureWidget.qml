import "./dms-common"
import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    // ── Resolve the daemon instance ───────────────────────────────────────────
    readonly property var daemon: PluginService.pluginInstances["quickCapture"] ?? null

    // ── Bar Pill appearance ───────────────────────────────────────────────────
    readonly property bool isActive: daemon ? (daemon.isCapturing || daemon.isAnnotating) : false
    readonly property bool isDownloading: daemon ? daemon.isDownloading : false

    pluginId: "quickCapture"
    pluginService: PluginService

    // ── Popout (left-click menu) ──────────────────────────────────────────────
    popoutWidth: 240
    popoutHeight: 400

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: I18n.tr("Quick Capture")
            detailsText: I18n.tr("Select capture mode")
            showCloseButton: true
            closePopout: () => root.closePopout()

            Column {
                width: parent.width
                spacing: 2
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS

                Repeater {
                    model: [
                        { icon: "screenshot_region", text: I18n.tr("Region"), modeKey: "region", isDefault: true },
                        { icon: "fullscreen", text: I18n.tr("Full Screen"), modeKey: "full", isDefault: false },
                        { icon: "crop_square", text: I18n.tr("Active Window"), modeKey: "window", isDefault: false },
                    ]

                    delegate: menuItemComp
                }

                Rectangle {
                    width: parent.width - Theme.spacingL
                    height: 6
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        { icon: "grid_view", text: I18n.tr("All Outputs"), modeKey: "all" },
                        { icon: "display_settings", text: I18n.tr("Specific Output"), modeKey: "output" },
                        { icon: "restart_alt", text: I18n.tr("Last Region"), modeKey: "last" },
                    ]

                    delegate: menuItemComp
                }

                Rectangle {
                    width: parent.width - Theme.spacingL
                    height: 6
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        { icon: "content_paste", text: I18n.tr("From Clipboard"), modeKey: "clipboard" },
                        { icon: "folder_open", text: I18n.tr("From File"), modeKey: "selectFile" },
                    ]

                    delegate: menuItemComp
                }
            }
        }
    }

    Component {
        id: menuItemComp

        Rectangle {
            id: itemRect
            width: parent.width
            height: 36
            color: itemMouse.containsMouse || pinArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            radius: Theme.cornerRadiusSmall

            function execMode(action) {
                const mk = modelData.modeKey;
                if (mk === "clipboard") root.daemon.fromClipboardWithAction(action);
                else if (mk === "selectFile") root.daemon.selectImageAndAnnotateWithAction(action);
                else root.daemon.triggerCaptureWithAction(mk, action);
                root.closePopout();
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS + 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: modelData.icon
                    size: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                }

                StyledText {
                    text: modelData.text
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: modelData.isDefault === true
                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankIcon {
                id: pinIcon
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: "push_pin"
                size: 16
                opacity: itemMouse.containsMouse || pinArea.containsMouse ? 1 : 0
                color: pinArea.containsMouse ? Theme.primary : Theme.surfaceText
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                anchors.rightMargin: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    execMode("edit");
                }
            }

            MouseArea {
                id: pinArea
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    execMode("float");
                }
            }
        }
    }

    // ── Horizontal bar pill ───────────────────────────────────────────────────
    horizontalBarPill: Component {
        Item {
            implicitWidth: horizontalRow.implicitWidth
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter
            property bool draggingOver: false

            Row {
                id: horizontalRow
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                DankIcon {
                    name: root.isDownloading ? "download" : "screenshot_region"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isActive || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (root.daemon) root.daemon.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        if (root.daemon) root.daemon.triggerCaptureWithAction("default", "edit");
                    }
                }
            }
        }
    }

    // ── Vertical bar pill ─────────────────────────────────────────────────────
    verticalBarPill: Component {
        Item {
            implicitWidth: Theme.iconSize
            implicitHeight: verticalCol.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter
            property bool draggingOver: false

            Column {
                id: verticalCol
                spacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                DankIcon {
                    name: root.isDownloading ? "download" : "screenshot_region"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isActive || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (root.daemon) root.daemon.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        if (root.daemon) root.daemon.triggerCaptureWithAction("default", "edit");
                    }
                }
            }
        }
    }

    // ── Bar Pill interactions ─────────────────────────────────────────────────
    // popout auto-opens on left click when pillClickAction is not set and popoutContent is defined
    pillRightClickAction: function() {
        if (root.daemon) root.daemon.fromClipboardWithAction("edit");
    }

    // ── Control Center integration ────────────────────────────────────────────
    ccWidgetIcon: "screenshot_region"
    ccWidgetPrimaryText: "Quick Capture"
    ccWidgetSecondaryText: root.isActive ? (daemon.isCapturing ? "Capturing..." : "Annotating") : "Ready"
    ccWidgetIsActive: root.isActive
    onCcWidgetToggled: {
        if (root.daemon) root.daemon.triggerCaptureWithAction("default", "edit");
    }
}
