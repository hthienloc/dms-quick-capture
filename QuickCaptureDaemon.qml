import "./dms-common"
import "./components/floating"
import "./components/history"
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
    readonly property string middleClickAction: (pluginData.middleClickAction || "region")
    readonly property var allowedModes: ["region", "window", "full", "output", "all", "last", "scroll"]
    property string pendingCaptureAction: "edit"
    property string pendingCaptureMode: ""
    property bool isDownloading: false
    property string currentCapturePath: ""
    property string captureOutputName: ""
    property bool hideControlCenter: pluginData.defaultHideControlCenter !== false
    readonly property int captureTimeoutMs: 60000
    readonly property int scrollCaptureTimeoutMs: 120000
    readonly property bool isAnnotating: modal.shouldBeVisible

    // ── Capture helpers ───────────────────────────────────────────────────────
    function capturePath() {
        return "/tmp/dms_capture_" + Date.now() + ".png";
    }

    function modeFlags(mode) {
        const flags = [];

        if (mode === "region" && pluginData.skipConfirm !== false)
            flags.push("--no-confirm");

        if (mode === "scroll") {
            const interval = parseInt(pluginData.scrollInterval, 10) || 500;
            flags.push("--interval", String(interval));
        }

        if (mode === "output") {
            const outName = root.captureOutputName || pluginData.outputTargetName || "DP-1";
            flags.push("--output", outName);
        }

        if (pluginData.resetLastRegion)
            flags.push("--reset");

        return flags;
    }

    function screenshotArgs(mode, filename) {
        const cursorVal = pluginData.includeCursor ? "on" : "off";
        return ["dms", "screenshot", mode, "--no-clipboard", "--dir", "/tmp",
                "--filename", filename, "--format", "png", "--cursor", cursorVal,
                "--no-notify", "--json"].concat(root.modeFlags(mode));
    }

    function triggerCaptureWithAction(mode, action) {
        const finalMode = mode || root.middleClickAction;
        const finalAction = action || "edit";

        if (!root.allowedModes.includes(finalMode)) {
            console.warn("Invalid screenshot mode rejected: " + finalMode);
            return;
        }

        if (root.isCapturing || modal.shouldBeVisible)
            return;

        root.isCapturing = true;
        root.pendingCaptureAction = finalAction;
        root.pendingCaptureMode = finalMode;

        if (root.hideControlCenter) {
            root.closeControlCenter();
            captureDelayTimer.start();
        } else {
            root.startActualCapture();
        }
    }

    function toggleHideControlCenter() {
        root.hideControlCenter = !root.hideControlCenter;
    }

    function closeControlCenter() {
        if (typeof PopoutService !== "undefined" && PopoutService)
            PopoutService.closeControlCenter();
    }

    function escShell(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }

    readonly property bool hasToast: typeof ToastService !== "undefined" && !!ToastService
    function toastInfo(m)    { if (hasToast) ToastService.showInfo(m); }
    function toastError(m)   { if (hasToast) ToastService.showError(m); }
    function toastWarning(m) { if (hasToast) ToastService.showWarning(m); }

    function parseJsonMeta(stdout) {
        return JSON.parse((stdout || "").trim());
    }

    function startActualCapture() {
        const mode = root.pendingCaptureMode;
        const action = root.pendingCaptureAction;
        const timeout = mode === "scroll" ? root.scrollCaptureTimeoutMs : root.captureTimeoutMs;

        root.currentCapturePath = root.capturePath();
        const filename = root.currentCapturePath.split("/").pop();
        const cmdStr = root.screenshotArgs(mode, filename).map(root.escShell).join(" ");
        Proc.runCommand("screenshot-trigger", ["sh", "-c", cmdStr], (stdout, exitCode) => {
            root.isCapturing = false;
            root.pendingCaptureMode = "";
            root.pendingCaptureAction = "edit";
            root.captureOutputName = "";
            try {
                const meta = root.parseJsonMeta(stdout);
                if (meta.status === "success") {
                    root.currentCapturePath = meta.path;
                    root.openCapturedImageWithDimensions(meta.path, action, meta.width, meta.height);
                } else if (meta.status !== "aborted") {
                    root.toastError(meta.message || meta.error || I18n.tr("Screenshot failed (mode: %1).").arg(mode));
                }
            } catch (e) {
                root.toastError((stdout && stdout.trim()) || I18n.tr("Screenshot failed (mode: %1).").arg(mode));
            }
        }, 0, timeout);
    }

    function selectImageAndAnnotateWithAction(action) {
        root.closeControlCenter();
        fileBrowserModal.captureAction = action || "edit";
        fileBrowserModal.open();
    }

    function fromClipboardWithAction(action) {
        root.closeControlCenter();
        const destPath = root.capturePath();
        root.currentCapturePath = destPath;

        // Step 1: Try to paste clipboard as a file.
        Proc.runCommand("clipboard-paste-file", ["sh", "-c", `dms cl paste > ${root.escShell(destPath)} 2>/dev/null`], (stdout, exitCode) => {
            if (exitCode === 0) {
                // Step 2a: Confirm the pasted file is actually an image.
                Proc.runCommand("clipboard-check-image", ["file", "-b", destPath], (fileOut, fileExit) => {
                    if (fileExit === 0 && fileOut.toLowerCase().includes("image")) {
                        root.openCapturedImageUnknown(destPath, action);
                    } else {
                        // Pasted file exists but isn't an image — try reading as text URI.
                        root.tryClipboardAsText(action);
                    }
                });
            } else {
                // Step 2b: Paste failed entirely — try reading clipboard as text URI.
                root.tryClipboardAsText(action);
            }
        });
    }

    function tryClipboardAsText(action) {
        Proc.runCommand("clipboard-paste-text", ["dms", "cl", "paste"], (stdout, exitCode) => {
            const text = stdout.trim();
            if (exitCode !== 0 || text === "") {
                root.toastError("No valid image, URL, or path in clipboard.");
                return;
            }
            root.loadImageFromUriWithAction(text, action);
        });
    }

    // Called when we already have image dimensions (e.g. from screenshot JSON metadata).
    function openCapturedImageWithDimensions(path, action, width, height) {
        const minSize = pluginData.minImageSize ?? 16;
        if (width < minSize || height < minSize) {
            root.toastError(`Image is too small (${width}x${height}). Minimum: ${minSize}px`);
            return;
        }
        root.openAction(path, action);
    }

    // Called when we don't have dimensions — runs `file -b` to confirm it's a valid image.
    function openCapturedImageUnknown(path, action) {
        Proc.runCommand("validate-image", ["file", "-b", path], (stdout, exitCode) => {
            const output = stdout.toLowerCase();
            if (exitCode !== 0 || output.includes("empty") || !output.includes("image")) {
                root.toastError("Invalid or corrupted image file.");
                return;
            }
            root.openAction(path, action);
        });
    }

    function openAction(path, action) {
        if (action === "float") {
            floatServiceItem.spawnWindow("file://" + path, pluginData, null, [path]);
        } else if (action === "copy") {
            DMSService.sendRequest("clipboard.copyFile", { "filePath": path });
            root.toastInfo(I18n.tr("Copied to clipboard"));
        } else if (action === "save") {
            const dir = pluginData.saveDirectory || "~/Pictures/Screenshots";
            const escapedDir = dir.startsWith("~/") ? "$HOME/" + root.escShell(dir.slice(2)) : root.escShell(dir);
            const escapedPath = root.escShell(path);
            const cmd = "mkdir -p -- " + escapedDir + " && cp -- " + escapedPath + " " + escapedDir + "/Screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png";
            Proc.runCommand("capture-save", ["sh", "-c", cmd], (stdout, exitCode) => {
                if (exitCode === 0)
                    root.toastInfo(I18n.tr("Screenshot saved"));
                else
                    root.toastError(I18n.tr("Failed to save screenshot"));
                if (path.startsWith("/tmp/dms_capture_"))
                    Proc.runCommand("cleanup-temp-save", ["rm", "-f", path]);
            });
        } else if (action === "copyAndSave") {
            const dir = pluginData.saveDirectory || "~/Pictures/Screenshots";
            const escapedDir = dir.startsWith("~/") ? "$HOME/" + root.escShell(dir.slice(2)) : root.escShell(dir);
            const escapedPath = root.escShell(path);
            const cmd = "mkdir -p -- " + escapedDir + " && cp -- " + escapedPath + " " + escapedDir + "/Screenshot-$(date '+%Y-%m-%d_%H-%M-%S').png";
            DMSService.sendRequest("clipboard.copyFile", { "filePath": path });
            Proc.runCommand("capture-copy-save", ["sh", "-c", cmd], (stdout, exitCode) => {
                if (exitCode === 0)
                    root.toastInfo(I18n.tr("Copied & saved"));
                else
                    root.toastError(I18n.tr("Failed to save screenshot"));
            });
        } else {
            root.closeControlCenter();
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
                if (exitCode === 0)
                    root.openCapturedImageUnknown(root.currentCapturePath, action);
                else
                    root.toastError("Failed to download image.");
            });
        } else {
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("copy-image", ["cp", "-f", uri, root.currentCapturePath], (stdout, exitCode) => {
                if (exitCode === 0)
                    root.openCapturedImageUnknown(root.currentCapturePath, action);
                else
                    root.toastError("Failed to copy image.");
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
            root.toastWarning("No valid image file or URL found in drop.");
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
                    root.openCapturedImageUnknown(root.currentCapturePath, action);
                } else {
                    root.toastError("Failed to load image.");
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
        useOverlayLayer: true
        keepContentLoaded: true
        closeOnEscapeKey: true
        closeOnBackgroundClick: true
        onBackgroundClicked: close()

        content: Component {
            RecentEditsCarousel {
                daemon: root
                onCloseRequested: historyModal.close()
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
