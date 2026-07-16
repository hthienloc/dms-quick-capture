import "./dms-common"
import QtQuick
import Quickshell
import Quickshell.Io
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

    property bool outputExpanded: false
    property var outputList: []
    function refreshOutputList() {
        Proc.runCommand("list-outputs", ["dms", "screenshot", "list"], (stdout) => {
            const list = [];
            for (const line of stdout.trim().split("\n")) {
                const m = line.match(/^(\S+):\s*(\d+x\d+)/);
                if (m) list.push({ label: m[1] + "  (" + m[2] + ")", value: m[1] });
            }
            if (list.length === 0) {
                list.push({ label: "DP-1", value: "DP-1" });
                list.push({ label: "eDP-1", value: "eDP-1" });
                list.push({ label: "HDMI-A-1", value: "HDMI-A-1" });
            }
            outputList = list;
        });
    }

    // ── Popout (left-click menu) ──────────────────────────────────────────────
    popoutWidth: 240
    popoutHeight: outputExpanded ? 400 + Math.min(outputList.length, 5) * 32 : 400

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

                Rectangle {
                    width: parent.width
                    height: 36
                    color: itemMouse1.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    radius: Theme.cornerRadiusSmall

                    function exec(action) {
                        if (!root.daemon) return;
                        root.daemon.triggerCaptureWithAction("all", action);
                        root.closePopout();
                    }

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 28
                        anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                        DankIcon { name: "grid_view"; size: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceText }
                        StyledText { text: I18n.tr("All Outputs"); font.pixelSize: Theme.fontSizeNormal; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMouse1
                        anchors.fill: parent; anchors.rightMargin: 28
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: exec("edit")
                    }
                    MouseArea {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.bottom: parent.bottom; width: 28
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: exec("float")
                    }
                }

                Rectangle {
                    id: outputHeader
                    width: parent.width; height: 36
                    color: outputMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    radius: Theme.cornerRadiusSmall

                    function exec(action) {
                        if (!root.daemon) return;
                        root.outputExpanded = !root.outputExpanded;
                        if (root.outputExpanded) root.refreshOutputList();
                    }

                    // ── Tree root branch ────────────────────────
                    Rectangle {
                        x: Theme.spacingM + 8
                        y: parent.height / 2
                        width: 2
                        height: parent.height / 2 + (parent.height % 2)
                        color: Theme.outlineVariant
                        visible: root.outputExpanded && root.outputList.length > 0
                    }

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 24
                        anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                        DankIcon { name: "display_settings"; size: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceText }
                        StyledText { text: I18n.tr("Specific Output"); font.pixelSize: Theme.fontSizeNormal; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    DankIcon {
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.outputExpanded ? "expand_more" : "expand_less"
                        size: 16; color: Theme.surfaceText
                    }

                    MouseArea {
                        id: outputMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: outputHeader.exec("edit")
                    }
                }

                Repeater {
                    model: root.outputExpanded ? root.outputList : []

                    delegate: Rectangle {
                        width: parent.width; height: root.outputExpanded ? 32 : 0
                        visible: root.outputExpanded
                        color: subMouse.containsMouse || pinArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                        radius: Theme.cornerRadiusSmall
                        clip: true

                        Behavior on height { NumberAnimation { duration: 100 } }

                        // ── Tree connector ─────────────────────
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height
                            color: Theme.outlineVariant
                            visible: index < root.outputList.length - 1
                        }
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height / 2
                            color: Theme.outlineVariant
                            visible: index === root.outputList.length - 1
                        }
                        Rectangle {
                            x: Theme.spacingM + 6
                            y: parent.height / 2 - 3
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.outlineVariant
                        }

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: Theme.spacingM + 20
                            anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 28
                            anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeNormal - 1
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankIcon {
                            id: pinIcon
                            anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "push_pin"
                            size: 14
                            opacity: subMouse.containsMouse || pinArea.containsMouse ? 1 : 0
                            color: pinArea.containsMouse ? Theme.primary : Theme.surfaceText
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent; anchors.rightMargin: 28
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.daemon) {
                                    root.daemon.captureOutputName = modelData.value;
                                    root.daemon.triggerCaptureWithAction("output", "edit");
                                }
                                root.closePopout();
                                root.outputExpanded = false;
                            }
                        }

                        MouseArea {
                            id: pinArea
                            anchors.right: parent.right
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 28
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.daemon) {
                                    root.daemon.captureOutputName = modelData.value;
                                    root.daemon.triggerCaptureWithAction("output", "float");
                                }
                                root.closePopout();
                                root.outputExpanded = false;
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 36
                    color: itemMouse3.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    radius: Theme.cornerRadiusSmall

                    function exec(action) {
                        if (!root.daemon) return;
                        root.daemon.triggerCaptureWithAction("last", action);
                        root.closePopout();
                    }

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 28
                        anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                        DankIcon { name: "restart_alt"; size: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceText }
                        StyledText { text: I18n.tr("Last Region"); font.pixelSize: Theme.fontSizeNormal; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }

                    MouseArea {
                        id: itemMouse3
                        anchors.fill: parent; anchors.rightMargin: 28
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: exec("edit")
                    }
                    MouseArea {
                        anchors.right: parent.right; anchors.top: parent.top
                        anchors.bottom: parent.bottom; width: 28
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: exec("float")
                    }
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
                if (!root.daemon) return;
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
