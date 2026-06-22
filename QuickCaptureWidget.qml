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
    property string resolvedDmsPath: "dms"
    property bool restoringFromFloat: false

    function triggerCapture(mode) {
        root.restoringFromFloat = false;
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
        // Always use PNG for the background to ensure compatibility with the editor
        const format = "png";
        const cursorVal = pluginData.includeCursor ? "on" : "off";
        const args = [root.resolvedDmsPath, "screenshot", mode, "--no-clipboard", "--dir", "/tmp", "--filename", "dms_capture_bg.png", "--format", format, "--cursor", cursorVal, "--no-notify"];

        if (mode === "region" && pluginData.skipConfirm !== false) {
            args.push("--no-confirm");
        }

        if (mode === "output") {
            const outName = pluginData.outputTargetName || "DP-1";
            args.push("--output", outName);
        }

        return args;
    }

    function startActualCapture() {
        // Delete any existing capture file before taking the screenshot.
        // This lets us detect ESC cancellation when `dms screenshot region`
        // incorrectly returns exit code 0 without writing a new file.
        Proc.runCommand("pre-capture-cleanup", ["rm", "-f", "/tmp/dms_capture_bg.png"], () => {
            Proc.runCommand("screenshot-trigger", root.screenshotArgs(), (stdout, exitCode) => {
                if (exitCode === 0) {
                    // Verify the file was actually written before opening the editor.
                    // If the user pressed ESC, dms may return 0 but write no file.
                    Proc.runCommand("verify-capture", ["test", "-f", "/tmp/dms_capture_bg.png"], (_, fileExists) => {
                        if (fileExists === 0) {
                            root.isCapturing = false;
                            root.activeIpcMode = "";
                            root.resolvedDmsPath = "dms"; // reset to default path on success
                            modal.shouldBeVisible = true;
                            modal.openCentered();
                        } else {
                            // File not written — user cancelled with ESC. Reset silently.
                            root.isCapturing = false;
                            root.activeIpcMode = "";
                            root.resolvedDmsPath = "dms";
                        }
                    });
                } else {
                    if (root.resolvedDmsPath === "dms") {
                        root.resolvedDmsPath = "/usr/local/bin/dms";
                        root.startActualCapture();
                    } else if (root.resolvedDmsPath === "/usr/local/bin/dms") {
                        root.resolvedDmsPath = "/usr/bin/dms";
                        root.startActualCapture();
                    } else {
                        root.isCapturing = false;
                        root.activeIpcMode = "";
                        root.resolvedDmsPath = "dms"; // reset to default path for next attempts
                        if (typeof ToastService !== "undefined" && ToastService)
                            ToastService.showError("Screenshot canceled or failed.");
                    }
                }
            }, 0, 60000);
        });
    }

    function closeOverlay() {
        modal.shouldBeVisible = false;
        modal.close();
    }

    function selectImageAndAnnotate() {
        root.restoringFromFloat = false;
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

    function fromClipboard() {
        root.restoringFromFloat = false;
        if (root.isDaemonInstance) {
            root.closeControlCenter();
            const checkCmd = "if wl-paste -t image/png > /tmp/dms_capture_bg.png 2>/dev/null || xclip -selection clipboard -t image/png -o > /tmp/dms_capture_bg.png 2>/dev/null; then echo \"IMAGE\"; else TEXT=$(wl-paste -n 2>/dev/null || xclip -selection clipboard -o 2>/dev/null); if [ -n \"$TEXT\" ]; then echo \"TEXT:$TEXT\"; else echo \"EMPTY\"; fi; fi";
            Proc.runCommand("smart-paste", ["sh", "-c", checkCmd], (stdout, exitCode) => {
                const output = stdout.trim();
                if (output === "IMAGE") {
                    root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else if (output.startsWith("TEXT:")) {
                    let text = output.substring(5).trim();
                    if (text.startsWith("file://")) {
                        text = text.substring(7);
                    }
                    if (text.startsWith("http://") || text.startsWith("https://")) {
                        root.isDownloading = true;
                        Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", "/tmp/dms_capture_bg.png", text], (stdout, exitCode) => {
                            root.isDownloading = false;
                            if (exitCode === 0) {
                                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                            } else {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showError("Failed to download image from URL.");
                                }
                            }
                        });
                    } else if (text.startsWith("/") || text.length > 0) {
                        Proc.runCommand("copy-image", ["cp", "-f", text, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                            if (exitCode === 0) {
                                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                            } else {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showError("Failed to copy image from local path.");
                                }
                            }
                        });
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService)
                            ToastService.showError("Clipboard text is not a valid URL or path.");
                    }
                } else {
                    if (typeof ToastService !== "undefined" && ToastService)
                        ToastService.showError("No valid image, URL, or path in clipboard.");
                }
            });
        } else {
            const daemon = PluginService.pluginInstances["quickCapture"];
            if (daemon) {
                root.closeControlCenter();
                daemon.fromClipboard();
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

    property bool isDownloading: false

    function validateAndOpenCapturedImage(path) {
        Proc.runCommand("validate-image", ["file", "-b", path], function(stdout, exitCode) {
            const output = stdout.toLowerCase();
            if (exitCode !== 0 || output.includes("empty") || !output.includes("image")) {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Invalid or corrupted image file.");
                }
                return;
            }

            let w = 0, h = 0;
            let re = /(\d+)\s*x\s*(\d+)/g;
            let match;
            while ((match = re.exec(stdout)) !== null) {
                w = parseInt(match[1]);
                h = parseInt(match[2]);
            }

            if (w > 0 && h > 0) {
                const minSize = 16;
                if (w < minSize || h < minSize) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Image is too small (" + w + "x" + h + "). Minimum: " + minSize + "px");
                    }
                    return;
                }
            }

            modal.shouldBeVisible = true;
            modal.openCentered();
        });
    }

    function handleDrop(drop) {
        root.restoringFromFloat = false;
        let urlStr = "";
        if (drop.hasUrls && drop.urls.length > 0) {
            urlStr = drop.urls[0].toString();
        } else if (drop.hasText) {
            const trimmed = drop.text.trim();
            if (trimmed.startsWith("http://") || trimmed.startsWith("https://")) {
                urlStr = trimmed;
            }
        }

        if (urlStr === "") {
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showWarning("No valid image file or URL found in drop.");
            }
            return;
        }

        if (urlStr.startsWith("http://") || urlStr.startsWith("https://")) {
            root.isDownloading = true;
            Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", "/tmp/dms_capture_bg.png", urlStr], (stdout, exitCode) => {
                root.isDownloading = false;
                if (exitCode === 0) {
                    validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to download dropped image.");
                    }
                }
            });
        } else if (urlStr.startsWith("file://")) {
            const path = urlStr.substring(7);
            Proc.runCommand("copy-image", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to copy local image.");
                    }
                }
            });
        } else {
            Proc.runCommand("copy-image", ["cp", "-f", urlStr, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to copy local image.");
                    }
                }
            });
        }
    }

    pluginId: "quickCapture"
    pluginService: PluginService

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
                    color: draggingOver ? Theme.primary : (root.isCapturing || modal.shouldBeVisible || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    root.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.triggerCapture("full");
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
                    name: root.isDownloading ? "download" : "screenshot_region"
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isCapturing || modal.shouldBeVisible || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    root.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        root.triggerCapture("full");
                    }
                }
            }
        }
    }

    // Bar Pill Interactions
    pillClickAction: function() { root.triggerCapture(); }
    pillRightClickAction: function() { root.fromClipboard(); }

    // Control Center Integration
    ccWidgetIcon: "screenshot_region"
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

        function fromClipboard() : string {
            root.fromClipboard();
            return "SUCCESS";
        }

        function openImage(path: string) : string {
            if (path.startsWith("file://")) {
                path = path.substring(7);
            }
            if (path === "/tmp/dms_capture_bg.png" || path === "/tmp/dms_capture_float.png") {
                root.restoringFromFloat = (path === "/tmp/dms_capture_float.png");
                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
            } else if (path.startsWith("http://") || path.startsWith("https://")) {
                root.restoringFromFloat = false;
                root.isDownloading = true;
                Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", "/tmp/dms_capture_bg.png", path], (stdout, exitCode) => {
                    root.isDownloading = false;
                    if (exitCode === 0) {
                        root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                    }
                });
            } else {
                root.restoringFromFloat = false;
                Proc.runCommand("copy-image", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                    if (exitCode === 0) {
                        root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                    }
                });
            }
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
