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
            outputList = list;
        });
    }

    // ── Popout (left-click menu) ──────────────────────────────────────────────
    popoutWidth: 250
    popoutHeight: outputExpanded ? 400 + Math.min(outputList.length, 5) * 32 : 400

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: I18n.tr("Quick Capture")
            detailsText: I18n.tr("Select capture mode")
            showCloseButton: false
            closePopout: () => root.closePopout()

            headerActions: Component {
                Row {
                    spacing: 4

                    Rectangle {
                        id: folderBtn
                        width: 32
                        height: 32
                        radius: 16
                        color: folderArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        property bool pressed: false

                        DankIcon {
                            id: folderIcon
                            anchors.centerIn: parent
                            name: "open_in_new"
                            size: Theme.iconSize - 4
                            color: folderArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            scale: folderBtn.pressed ? 0.6 : 1.0
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                        }

                        MouseArea {
                            id: folderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: folderBtn.pressed = true
                            onReleased: folderBtn.pressed = false
                            onCanceled: folderBtn.pressed = false
                            onClicked: {
                                folderBtn.pressed = false
                                const dir = root.pluginData.saveDirectory || "~/Pictures/Screenshots";
                                Proc.runCommand("open-screenshot-dir", ["sh", "-c", "xdg-open " + dir], null);
                            }
                        }
                    }

                    Rectangle {
                        id: historyBtn
                        width: 32
                        height: 32
                        radius: 16
                        color: historyArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        property bool pressed: false

                        DankIcon {
                            anchors.centerIn: parent
                            name: "history"
                            size: Theme.iconSize - 4
                            color: historyArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            scale: historyBtn.pressed ? 0.6 : 1.0
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                        }

                        MouseArea {
                            id: historyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: historyBtn.pressed = true
                            onReleased: historyBtn.pressed = false
                            onCanceled: historyBtn.pressed = false
                            onClicked: {
                                historyBtn.pressed = false
                                root.closePopout()
                                if (root.daemon) root.daemon.showHistoryCarousel()
                            }
                        }
                    }
                }
            }

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
                        { icon: "restart_alt", text: I18n.tr("Last Region"), modeKey: "last" },
                        { icon: "grid_view", text: I18n.tr("All Outputs"), modeKey: "all" },
                    ]
                    delegate: menuItemComp
                }

                Rectangle {
                    id: outputHeader
                    width: parent.width; height: 36
                    color: outputMouse.containsMouse ? Theme.primaryHoverLight : "transparent"
                    radius: Theme.cornerRadius
                    Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                    // ── Tree root branch ────────────────────────
                    Rectangle {
                        x: Theme.spacingM + 8
                        y: parent.height / 2
                        width: 2
                        height: parent.height / 2 + (parent.height % 2) + 2
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

                    DankRipple {
                        id: outputRipple
                        anchors.fill: parent
                        rippleColor: Theme.primary
                        cornerRadius: outputHeader.radius
                        clip: true
                    }

                    MouseArea {
                        id: outputMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => outputRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (!root.daemon) return;
                            root.outputExpanded = !root.outputExpanded;
                            if (root.outputExpanded) root.refreshOutputList();
                        }
                    }
                }

                Repeater {
                    model: root.outputExpanded ? root.outputList : []

                    delegate: Rectangle {
                        width: parent.width; height: root.outputExpanded ? 32 : 0
                        visible: root.outputExpanded
                        color: subMouse.containsMouse || pinArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                        radius: Theme.cornerRadius
                        Behavior on height { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        // ── Tree connector ─────────────────────
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height + 2
                            color: Theme.outlineVariant
                            visible: index < root.outputList.length - 1
                        }
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height / 2 + 2
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

                        DankRipple {
                            id: subRipple
                            anchors.fill: parent
                            rippleColor: Theme.primary
                            cornerRadius: parent.radius
                            clip: true
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent; anchors.rightMargin: 28
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => subRipple.trigger(mouse.x, mouse.y)
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
                            onPressed: mouse => subRipple.trigger(mouse.x + parent.width - 28, mouse.y)
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

                StyledText {
                    width: parent.width
                    height: root.outputExpanded && root.outputList.length === 0 ? 32 : 0
                    visible: root.outputExpanded && root.outputList.length === 0
                    padding: Theme.spacingM + 20
                    text: I18n.tr("No output available")
                    font.pixelSize: Theme.fontSizeNormal - 2
                    font.italic: true
                    color: Theme.surfaceVariantText
                    verticalAlignment: Text.AlignVCenter
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
            color: itemMouse.containsMouse || pinArea.containsMouse ? Theme.primaryHoverLight : "transparent"
            radius: Theme.cornerRadius
            scale: (itemMouse.pressed || pinArea.pressed) && !itemMouse.drag.active ? 0.98 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

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

            DankRipple {
                id: itemRipple
                anchors.fill: parent
                rippleColor: Theme.primary
                cornerRadius: itemRect.radius
                clip: true
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
                onPressed: mouse => itemRipple.trigger(mouse.x, mouse.y)
                onClicked: execMode("edit")
            }

            MouseArea {
                id: pinArea
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => itemRipple.trigger(mouse.x + parent.width - 28, mouse.y)
                onClicked: execMode("float")
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
