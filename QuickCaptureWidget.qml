import "./dms-common"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import qs.Modals.FileBrowser

PluginComponent {
    id: root

    readonly property bool isDaemonInstance: root.parent !== null
    property bool isCapturing: false
    readonly property string captureMode: (pluginData.captureMode || "region")
    property string activeIpcMode: ""

    function triggerCapture(mode) {
        if (root.isDaemonInstance) {
            root.activeIpcMode = mode || "";
            root.startCaptureAfterDelay();
        } else {
            const daemon = PluginService.pluginInstances["quickCapture"];
            if (daemon) {
                root.closeControlCenter();
                daemon.triggerCapture(mode);
            } else {
                // Fallback if daemon is somehow missing
                root.activeIpcMode = mode || "";
                root.startCaptureAfterDelay();
            }
        }
    }

    function closeControlCenter() {
        if (typeof PopoutService !== "undefined" && PopoutService)
            PopoutService.closeControlCenter();

    }

    function startCaptureAfterDelay() {
        if (root.isCapturing || modal.shouldBeVisible)
            return ;

        root.isCapturing = true;
        root.closeControlCenter();
        captureDelayTimer.start();
    }

    function screenshotArgs() {
        const mode = root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
        const format = (pluginData.outputFormat || "png");
        const cursorVal = pluginData.includeCursor ? "on" : "off";
        const args = ["dms", "screenshot", mode, "--no-clipboard", "--dir", "/tmp", "--filename", "dms_capture_bg.png", "--format", format, "--cursor", cursorVal];

        if (!pluginData.showSystemNotification) {
            args.push("--no-notify");
        }

        if (mode === "region" && pluginData.skipConfirm !== false) {
            args.push("--no-confirm");
        }

        if (format === "jpg") {
            const quality = pluginData.jpegQuality ?? 90;
            args.push("--quality", String(quality));
        }

        return args;
    }

    function startActualCapture() {
        // 0ms debounce (execute instantly)
        // 60 seconds timeout

        Proc.runCommand("dms-screenshot", root.screenshotArgs(), (stdout, exitCode) => {
            root.isCapturing = false;
            root.activeIpcMode = "";
            if (exitCode === 0) {
                modal.shouldBeVisible = true;
                modal.openCentered();
            } else {
                if (typeof ToastService !== "undefined" && ToastService)
                    ToastService.showError("Screenshot canceled or failed.");

            }
        }, 0, 60000);
    }

    function closeOverlay() {
        modal.shouldBeVisible = false;
        modal.close();
    }

    function selectImageAndAnnotate() {
        if (root.isDaemonInstance) {
            root.closeControlCenter();
            fileBrowserModal.open();
        } else {
            const daemon = PluginService.pluginInstances["quickCapture"];
            if (daemon) {
                root.closeControlCenter();
                daemon.selectImageAndAnnotate();
            }
        }
    }

    function registerDaemonAsWidget() {
        // Register self so Control Center widget instances can delegate capture to the daemon.
        if (!pluginService.pluginInstances[pluginId]) {
            const newInstances = Object.assign({
            }, pluginService.pluginInstances);
            newInstances[pluginId] = root;
            pluginService.pluginInstances = newInstances;
        }
        // Expose this daemon component to widget placement without changing plugin.json.
        if (pluginService.pluginWidgetComponents && !pluginService.pluginWidgetComponents[pluginId]) {
            const newWidgets = Object.assign({
            }, pluginService.pluginWidgetComponents);
            newWidgets[pluginId] = pluginService.pluginDaemonComponents[pluginId];
            pluginService.pluginWidgetComponents = newWidgets;
        }
        const plugins = pluginService.getLoadedPlugins ? pluginService.getLoadedPlugins() : [];
        const pluginInfo = plugins.find((p) => {
            return p.id === pluginId;
        });
        if (pluginInfo)
            pluginInfo.type = "widget";

    }

    function unregisterDaemonInstance() {
        if (pluginService.pluginInstances[pluginId] === root) {
            const newInstances = Object.assign({
            }, pluginService.pluginInstances);
            delete newInstances[pluginId];
            pluginService.pluginInstances = newInstances;
        }
    }

    pluginId: "quickCapture"
    pluginService: PluginService

    // Bar Pill Integration
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
                    name: "photo_camera"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isCapturing || modal.shouldBeVisible ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (drop.hasUrls && drop.urls.length > 0) {
                        const path = drop.urls[0].toString().replace("file://", "");
                        Proc.runCommand("copy-image", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                            if (exitCode === 0) {
                                modal.shouldBeVisible = true;
                                modal.openCentered();
                            }
                        });
                    }
                }
            }
        }
    }

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
                    name: "photo_camera"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isCapturing || modal.shouldBeVisible ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (drop.hasUrls && drop.urls.length > 0) {
                        const path = drop.urls[0].toString().replace("file://", "");
                        Proc.runCommand("copy-image", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                            if (exitCode === 0) {
                                modal.shouldBeVisible = true;
                                modal.openCentered();
                            }
                        });
                    }
                }
            }
        }
    }

    // Bar Pill Interactions
    pillClickAction: function() { root.triggerCapture(); }
    pillRightClickAction: function() { root.selectImageAndAnnotate(); }

    // Control Center Integration
    ccWidgetIcon: "photo_camera"
    ccWidgetPrimaryText: "Quick Capture"
    ccWidgetSecondaryText: isCapturing ? "Capturing..." : (modal.shouldBeVisible ? "Annotating" : "Ready")
    ccWidgetIsActive: modal.shouldBeVisible || isCapturing
    onCcWidgetToggled: {
        root.triggerCapture();
    }
    Component.onCompleted: {
        if (root.isDaemonInstance && pluginService && pluginId)
            root.registerDaemonAsWidget();

    }
    Component.onDestruction: {
        if (root.isDaemonInstance && pluginService && pluginId)
            root.unregisterDaemonInstance();

    }

    QuickCaptureModal {
        id: modal

        parentWidget: root
    }

    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: I18n.tr("Select Image to Annotate")
        browserIcon: "image"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        onFileSelected: path => {
            // Copy selected file to temp location where QuickCaptureModal expects it
            Proc.runCommand("copy-image", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    modal.shouldBeVisible = true;
                    modal.openCentered();
                } else {
                    ToastService.showError("Failed to load image.");
                }
            });
            close();
        }
    }

    IpcHandler {
        function screenshot(mode: string) : string {
            if (mode === "default") {
                root.triggerCapture("");
            } else {
                root.triggerCapture(mode);
            }
            return "SUCCESS";
        }

        function selectFile() : string {
            root.selectImageAndAnnotate();
            return "SUCCESS";
        }

        function close() : string {
            modal.shouldBeVisible = false;
            modal.close();
            return "SUCCESS";
        }

        target: "quickCapture"
        enabled: root.isDaemonInstance
    }

    Timer {
        id: captureDelayTimer

        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        repeat: false
        onTriggered: root.startActualCapture()
    }

}
