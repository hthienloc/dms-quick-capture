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
                        { icon: "screenshot_region", text: I18n.tr("Capture Region"), action: () => root.daemon.triggerCaptureWithAction("region", "edit"), isDefault: true },
                        { icon: "fullscreen", text: I18n.tr("Capture Full Screen"), action: () => root.daemon.triggerCaptureWithAction("full", "edit"), isDefault: false },
                        { icon: "crop_square", text: I18n.tr("Capture Active Window"), action: () => root.daemon.triggerCaptureWithAction("window", "edit"), isDefault: false },
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
                        { icon: "grid_view", text: I18n.tr("Capture All Outputs"), action: () => root.daemon.triggerCaptureWithAction("all", "edit") },
                        { icon: "display_settings", text: I18n.tr("Capture Specific Output"), action: () => root.daemon.triggerCaptureWithAction("output", "edit") },
                        { icon: "restart_alt", text: I18n.tr("Capture Last Region"), action: () => root.daemon.triggerCaptureWithAction("last", "edit") },
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
                        { icon: "content_paste", text: I18n.tr("Import from Clipboard"), action: () => root.daemon.fromClipboardWithAction("edit") },
                        { icon: "folder_open", text: I18n.tr("Import from File"), action: () => root.daemon.selectImageAndAnnotateWithAction("edit") },
                    ]

                    delegate: menuItemComp
                }
            }
        }
    }

    Component {
        id: menuItemComp

        Rectangle {
            width: parent.width
            height: 36
            color: mouseArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
            radius: Theme.cornerRadiusSmall

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
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

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    modelData.action();
                    root.closePopout();
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
    pillClickAction: function() {
        root.triggerPopout();
    }
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
