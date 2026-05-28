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
        onTriggered: root.startActualCapture()
    }

    function triggerCapture() {
        if (root.isDaemonInstance) {
            root.startCaptureAfterDelay();
        } else {
            const daemon = PluginService.pluginInstances["quickCapture"];
            if (daemon) {
                root.closeControlCenter();
                daemon.triggerCapture();
            } else {
                // Fallback if daemon is somehow missing
                root.startCaptureAfterDelay();
            }
        }
    }

    function closeControlCenter() {
        if (typeof PopoutService !== "undefined" && PopoutService) {
            PopoutService.closeControlCenter();
        }
    }

    function startCaptureAfterDelay() {
        if (root.isCapturing || modal.shouldBeVisible) return;
        root.isCapturing = true;
        root.closeControlCenter();
        captureDelayTimer.start();
    }

    function screenshotArgs() {
        return ["dms", "screenshot", "full", "--no-clipboard", "--no-notify", "--dir", "/tmp", "--filename", "dms_capture_bg.png"];
    }

    function startActualCapture() {
        Proc.runCommand(
            "dms-screenshot",
            root.screenshotArgs(),
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
            60000  // 60 seconds timeout
        );
    }

    function closeOverlay() {
        modal.shouldBeVisible = false;
        modal.close();
    }

    Component.onCompleted: {
        if (root.isDaemonInstance && pluginService && pluginId) {
            root.registerDaemonAsWidget();
        }
    }

    Component.onDestruction: {
        if (root.isDaemonInstance && pluginService && pluginId) {
            root.unregisterDaemonInstance();
        }
    }

    function registerDaemonAsWidget() {
        // Register self so Control Center widget instances can delegate capture to the daemon.
        if (!pluginService.pluginInstances[pluginId]) {
            const newInstances = Object.assign({}, pluginService.pluginInstances);
            newInstances[pluginId] = root;
            pluginService.pluginInstances = newInstances;
        }

        // Expose this daemon component to widget placement without changing plugin.json.
        if (pluginService.pluginWidgetComponents && !pluginService.pluginWidgetComponents[pluginId]) {
            const newWidgets = Object.assign({}, pluginService.pluginWidgetComponents);
            newWidgets[pluginId] = pluginService.pluginDaemonComponents[pluginId];
            pluginService.pluginWidgetComponents = newWidgets;
        }

        const plugins = pluginService.getLoadedPlugins ? pluginService.getLoadedPlugins() : [];
        const pluginInfo = plugins.find(p => p.id === pluginId);
        if (pluginInfo) {
            pluginInfo.type = "widget";
        }
    }

    function unregisterDaemonInstance() {
        if (pluginService.pluginInstances[pluginId] === root) {
            const newInstances = Object.assign({}, pluginService.pluginInstances);
            delete newInstances[pluginId];
            pluginService.pluginInstances = newInstances;
        }
    }
}
