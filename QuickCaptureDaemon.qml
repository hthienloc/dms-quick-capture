import "./dms-common"
import "./components"
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import qs.Modals.Common
import qs.Modals.FileBrowser

PluginComponent {
    id: root

    // ── State ────────────────────────────────────────────────────────────────
    property bool isCapturing: false
    readonly property string captureMode: (pluginData.captureMode || "region")
    readonly property var allowedModes: ["region", "window", "full", "output", "all", "last", ""]
    property string activeIpcMode: ""
    property bool isDownloading: false
    property string currentCapturePath: ""
    property string captureOutputName: ""
    // Exposed so the widget surface can read annotation state without accessing internal modal id
    readonly property bool isAnnotating: modal.shouldBeVisible

    // ── Capture helpers ───────────────────────────────────────────────────────
    function capturePath() {
        return "/tmp/dms_capture_" + Date.now() + ".png";
    }

    function screenshotMode() {
        return root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
    }

    function screenshotArgs(filename) {
        const mode = root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
        const cursorVal = pluginData.includeCursor ? "on" : "off";
        const args = ["dms", "screenshot", mode, "--no-clipboard", "--dir", "/tmp", "--filename", filename, "--format", "png", "--cursor", cursorVal, "--no-notify", "--json"];

        if (mode === "region" && pluginData.skipConfirm !== false) {
            args.push("--no-confirm");
        }

        if (mode === "output") {
            const outName = root.captureOutputName || pluginData.outputTargetName || "DP-1";
            args.push("--output", outName);
        }

        return args;
    }

    function triggerCaptureWithAction(mode, action) {
        const normalizedMode = mode === "default" ? "" : (mode || "");
        const allowedModes = root.allowedModes;
        if (normalizedMode && !allowedModes.includes(normalizedMode)) {
            console.warn("Invalid screenshot mode rejected: " + mode);
            return;
        }

        root.activeIpcMode = normalizedMode;
        captureDelayTimer.captureAction = action || "edit";
        root.startCaptureAfterDelay();
    }

    function closeControlCenter() {
        if (typeof PopoutService !== "undefined" && PopoutService)
            PopoutService.closeControlCenter();
    }

    function startCaptureAfterDelay() {
        if (root.isCapturing || modal.shouldBeVisible)
            return;

        root.isCapturing = true;
        root.closeControlCenter();
        captureDelayTimer.start();
    }

    function startActualCapture() {
        const action = captureDelayTimer.captureAction || "edit";
        root.currentCapturePath = root.capturePath();
        const filename = root.currentCapturePath.split("/").pop();
        const cmdStr = root.screenshotArgs(filename).map(arg => "'" + arg.replace(/'/g, "'\\''") + "'").join(" ") + " 2>&1";
        Proc.runCommand("screenshot-trigger", ["sh", "-c", cmdStr], (stdout, exitCode) => {
            root.isCapturing = false;
            root.activeIpcMode = "";
            root.captureOutputName = "";
            try {
                const trimmed = stdout.trim();
                const startIdx = trimmed.indexOf("{");
                const endIdx = trimmed.lastIndexOf("}");
                const meta = startIdx !== -1 && endIdx > startIdx
                    ? JSON.parse(trimmed.substring(startIdx, endIdx + 1))
                    : JSON.parse(trimmed);
                if (meta.status === "success") {
                    root.currentCapturePath = meta.path;
                    root.validateAndOpenCapturedImage(meta.path, action, meta.width, meta.height);
                } else if (meta.status !== "aborted") {
                    const failMode = root.screenshotMode();
                    if (typeof ToastService !== "undefined" && ToastService) {
                        const errorMsg = meta.message || meta.error || I18n.tr("Screenshot failed (mode: %1).").arg(failMode);
                        ToastService.showError(errorMsg);
                    }
                }
            } catch (e) {
                const failMode = root.screenshotMode();
                if (typeof ToastService !== "undefined" && ToastService) {
                    const errorMsg = (stdout && stdout.trim()) ? stdout.trim() : I18n.tr("Screenshot failed (mode: %1).").arg(failMode);
                    ToastService.showError(errorMsg);
                }
            }
        }, 0, 60000);
    }

    function selectImageAndAnnotateWithAction(action) {
        root.closeControlCenter();
        fileBrowserModal.captureAction = action || "edit";
        fileBrowserModal.open();
    }

    function fromClipboardWithAction(action) {
        root.closeControlCenter();
        root.currentCapturePath = root.capturePath();
        const checkCmd = "if dms cl paste > " + root.currentCapturePath + " 2>/dev/null && file -b " + root.currentCapturePath + " | grep -qi \"image\"; then echo \"IMAGE\"; else TEXT=$(dms cl paste 2>/dev/null); if [ -n \"$TEXT\" ]; then echo \"TEXT:$TEXT\"; else echo \"EMPTY\"; fi; fi";
        Proc.runCommand("smart-paste", ["sh", "-c", checkCmd], (stdout, exitCode) => {
            const output = stdout.trim();
            if (output === "IMAGE") {
                root.validateAndOpenCapturedImage(root.currentCapturePath, action);
            } else if (output.startsWith("TEXT:")) {
                let text = output.substring(5).trim();
                if (text === "") {
                    if (typeof ToastService !== "undefined" && ToastService)
                        ToastService.showError("Clipboard text is not a valid URL or path.");
                } else {
                    root.loadImageFromUriWithAction(text, action);
                }
            } else {
                if (typeof ToastService !== "undefined" && ToastService)
                    ToastService.showError("No valid image, URL, or path in clipboard.");
            }
        });
    }

    function validateAndOpenCapturedImage(path, action, width, height) {
        if (width !== undefined && height !== undefined) {
            const minSize = pluginData.minImageSize ?? 16;
            if (width < minSize || height < minSize) {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Image is too small (" + width + "x" + height + "). Minimum: " + minSize + "px");
                }
                return;
            }
            root.openAction(path, action);
        } else {
            Proc.runCommand("validate-image", ["file", "-b", path], function(stdout, exitCode) {
                const output = stdout.toLowerCase();
                if (exitCode !== 0 || output.includes("empty") || !output.includes("image")) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Invalid or corrupted image file.");
                    }
                    return;
                }
                root.openAction(path, action);
            });
        }
    }

    function openAction(path, action) {
        if (action === "float") {
            floatServiceItem.spawnWindow("file://" + path, pluginData, null, [path]);
        } else {
            modal.currentCapturePath = path;
            modal.shouldBeVisible = true;
            modal.open();
        }
    }

    function loadImageFromUriWithAction(uri, action) {
        if (uri.startsWith("file://"))
            uri = uri.substring(7);

        if (uri.startsWith("http://") || uri.startsWith("https://")) {
            root.isDownloading = true;
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", root.currentCapturePath, uri], (stdout, exitCode) => {
                root.isDownloading = false;
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath, action);
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Failed to download image.");
                }
            });
        } else {
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("copy-image", ["cp", "-f", uri, root.currentCapturePath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath, action);
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Failed to copy image.");
                }
            });
        }
    }

    function handleDrop(drop) {
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

        root.loadImageFromUriWithAction(urlStr, "edit");
    }

    // ── Plugin identity ───────────────────────────────────────────────────────
    pluginId: "quickCapture"
    pluginService: PluginService

    // ── IPC handlers ─────────────────────────────────────────────────────────
    IpcHandler {
        function screenshot(mode: string, action: string) : string {
            root.triggerCaptureWithAction(mode, action);
            return "SUCCESS";
        }

        function selectFile(action: string) : string {
            root.selectImageAndAnnotateWithAction(action);
            return "SUCCESS";
        }

        function fromClipboard(action: string) : string {
            root.fromClipboardWithAction(action);
            return "SUCCESS";
        }

        function openImage(path: string, action: string) : string {
            if (path.startsWith("file://")) {
                path = path.substring(7);
            }
            root.loadImageFromUriWithAction(path, action);
            return "SUCCESS";
        }

        function close() : string {
            modal.shouldBeVisible = false;
            modal.close();
            return "SUCCESS";
        }

        function showHistory() : string {
            root.showHistoryCarousel();
            return "SUCCESS";
        }

        target: "quickCapture"
        enabled: true
    }

    // ── Capture delay timer ───────────────────────────────────────────────────
    Timer {
        id: captureDelayTimer
        property string captureAction: "edit"

        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        repeat: false
        onTriggered: root.startActualCapture()
    }

    // ── Float service ─────────────────────────────────────────────────────────
    FloatService {
        id: floatServiceItem
    }

    // ── Modal ─────────────────────────────────────────────────────────────────
    QuickCaptureModal {
        id: modal

        parentWidget: root
        floatService: floatServiceItem
    }

    // ── File browser ──────────────────────────────────────────────────────────
    FileBrowserModal {
        id: fileBrowserModal
        property string captureAction: "edit"
        browserTitle: I18n.tr("Select Image to Annotate")
        browserIcon: "image"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        onFileSelected: path => {
            const action = fileBrowserModal.captureAction;
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("copy-image", ["cp", "-f", path, root.currentCapturePath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath, action);
                } else {
                    ToastService.showError("Failed to load image.");
                }
            });
            close();
        }
    }

    // ── History carousel modal ────────────────────────────────────────────────
    function showHistoryCarousel() {
        if (historyModal.contentLoader && historyModal.contentLoader.item)
            historyModal.contentLoader.item.refresh()
        historyModal.shouldBeVisible = true
        historyModal.open()
    }

    DankModal {
        id: historyModal
        shouldBeVisible: false
        positioning: "center"
        enableShadow: true
        keepContentLoaded: true
        closeOnEscapeKey: true
        closeOnBackgroundClick: true
        onBackgroundClicked: close()

        content: Component {
            RecentEditsCarousel {
                daemon: root
            }
        }

        readonly property real _screenW: targetScreen ? targetScreen.width : (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920)
        readonly property real _screenH: targetScreen ? targetScreen.height : (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080)
        modalWidth: Math.round(_screenW * 0.9)
        modalHeight: Math.round(_screenH * (historyModal.contentLoader && historyModal.contentLoader.item ? historyModal.contentLoader.item.heightFraction : 0.45))
    }

    // ── Lifecycle: register self so widget surface can delegate to daemon ─────
    Component.onCompleted: {
        if (pluginService && pluginId) {
            const newInstances = Object.assign({}, pluginService.pluginInstances);
            newInstances[pluginId] = root;
            pluginService.pluginInstances = newInstances;
        }
    }

    Component.onDestruction: {
        if (pluginService && pluginService.pluginInstances[pluginId] === root) {
            const newInstances = Object.assign({}, pluginService.pluginInstances);
            delete newInstances[pluginId];
            pluginService.pluginInstances = newInstances;
        }
    }
}
