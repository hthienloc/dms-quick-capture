import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "quickCapture"
    pluginService: PluginService

    readonly property bool isDaemonInstance: root.parent !== null
    property bool isCapturing: false

    // Control Center Integration
    ccWidgetIcon: "photo_camera"
    ccWidgetPrimaryText: "Quick Capture"
    ccWidgetSecondaryText: isCapturing ? "Capturing..." : (modal.shouldBeVisible ? "Annotating" : "Ready")
    ccWidgetIsActive: modal.shouldBeVisible || isCapturing

    onCcWidgetToggled: {
        root.triggerCapture();
    }

    QuickCaptureModal {
        id: modal
        parentWidget: root
    }

    IpcHandler {
        target: "quickCapture"
        enabled: root.isDaemonInstance

        function screenshot(): string {
            root.triggerCapture();
            return "SUCCESS";
        }

        function close(): string {
            modal.shouldBeVisible = false;
            modal.close();
            return "SUCCESS";
        }

        function toggle(): string {
            if (modal.shouldBeVisible) {
                return close();
            } else {
                return screenshot();
            }
        }
    }

    Timer {
        id: captureDelayTimer
        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        repeat: false
        onTriggered: {
            root.startActualCapture();
        }
    }

    function triggerCapture() {
        if (root.isDaemonInstance) {
            if (root.isCapturing || modal.shouldBeVisible) return;
            root.isCapturing = true;

            if (typeof PopoutService !== "undefined" && PopoutService) {
                PopoutService.closeControlCenter();
            }

            captureDelayTimer.start();
        } else {
            const daemon = PluginService.pluginInstances["quickCapture"];
            if (daemon) {
                if (typeof PopoutService !== "undefined" && PopoutService) {
                    PopoutService.closeControlCenter();
                }
                daemon.triggerCapture();
            } else {
                // Fallback if daemon is somehow missing
                if (root.isCapturing || modal.shouldBeVisible) return;
                root.isCapturing = true;
                if (typeof PopoutService !== "undefined" && PopoutService) {
                    PopoutService.closeControlCenter();
                }
                captureDelayTimer.start();
            }
        }
    }

    function startActualCapture() {
        const hasData = root.pluginData !== null && typeof root.pluginData !== "undefined";
        const captureMode = hasData ? (root.pluginData.captureMode || "region") : "region";

        const args = ["dms", "screenshot"];
        if (captureMode === "full") {
            args.push("full");
        } else {
            args.push("region");
        }

        // Capture to temporary file for annotation phase
        args.push("--no-clipboard", "--no-notify", "--dir", "/tmp", "--filename", "dms_capture_bg.png");

        Proc.runCommand(
            "dms-screenshot",
            args,
            (stdout, exitCode) => {
                root.isCapturing = false;
                if (exitCode === 0) {
                    modal.shouldBeVisible = true;
                    modal.openCentered();
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Screenshot canceled or failed.");
                    }
                }
            },
            0,     // 0ms debounce (execute instantly)
            60000  // 60 seconds timeout for region selection
        );
    }

    function closeOverlay() {
        modal.shouldBeVisible = false;
        modal.close();
    }

    Component.onCompleted: {
        if (root.isDaemonInstance && pluginService && pluginId) {
            // 1. Dynamic registration in pluginWidgetComponents
            if (pluginService.pluginWidgetComponents && !pluginService.pluginWidgetComponents[pluginId]) {
                const newWidgets = Object.assign({}, pluginService.pluginWidgetComponents);
                newWidgets[pluginId] = pluginService.pluginDaemonComponents[pluginId];
                pluginService.pluginWidgetComponents = newWidgets;
            }
            // 2. Bypass daemon filter in WidgetModel by updating in-memory type to widget
            const plugins = pluginService.getLoadedPlugins ? pluginService.getLoadedPlugins() : [];
            const pluginInfo = plugins.find(p => p.id === pluginId);
            if (pluginInfo) {
                pluginInfo.type = "widget";
            }
        }
    }
}
