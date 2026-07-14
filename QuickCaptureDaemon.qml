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

    // ── State ────────────────────────────────────────────────────────────────
    property bool isCapturing: false
    readonly property string captureMode: (pluginData.captureMode || "region")
    property string activeIpcMode: ""
    property bool isDownloading: false
    property string currentCapturePath: ""
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
        filename = filename || "dms_capture_bg.png";
        const mode = root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
        const format = "png";
        const cursorVal = pluginData.includeCursor ? "on" : "off";
        const args = ["dms", "screenshot", mode, "--no-clipboard", "--dir", "/tmp", "--filename", filename, "--format", format, "--cursor", cursorVal, "--no-notify"];

        if (mode === "region" && pluginData.skipConfirm !== false) {
            args.push("--no-confirm");
        }

        if (mode === "output") {
            const outName = pluginData.outputTargetName || "DP-1";
            args.push("--output", outName);
        }

        return args;
    }

    function triggerCapture(mode) {
        // Strictly validate mode against allowlist to prevent command injection
        const allowedModes = ["region", "window", "full", "output", ""];
        if (mode && !allowedModes.includes(mode)) {
            console.warn("Invalid screenshot mode rejected: " + mode);
            return;
        }

        root.activeIpcMode = mode || "";
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
        root.currentCapturePath = root.capturePath();
        const filename = root.currentCapturePath.split("/").pop();
        const cmdStr = root.screenshotArgs(filename).map(arg => "'" + arg.replace(/'/g, "'\\''") + "'").join(" ") + " 2>&1";
        Proc.runCommand("screenshot-trigger", ["sh", "-c", cmdStr], (stdout, exitCode) => {
            if (exitCode === 0) {
                Proc.runCommand("verify-capture", ["test", "-f", root.currentCapturePath], (_, fileExists) => {
                    root.isCapturing = false;
                    root.activeIpcMode = "";
                    if (fileExists === 0) {
                        root.validateAndOpenCapturedImage(root.currentCapturePath);
                    }
                });
            } else {
                const failMode = root.screenshotMode();
                root.isCapturing = false;
                root.activeIpcMode = "";
                if (typeof ToastService !== "undefined" && ToastService) {
                    const errorMsg = (stdout && stdout.trim()) ? stdout.trim() : I18n.tr("Screenshot failed (mode: %1).").arg(failMode);
                    ToastService.showError(errorMsg);
                }
            }
        }, 0, 60000);
    }

    function closeOverlay() {
        modal.shouldBeVisible = false;
        modal.close();
        Proc.runCommand("cleanup-old-captures", ["sh", "-c", "find /tmp -name 'dms_capture_*.png' -mmin +60 -delete 2>/dev/null"]);
    }

    function selectImageAndAnnotate() {
        root.closeControlCenter();
        fileBrowserModal.open();
    }

    function fromClipboard() {
        root.closeControlCenter();
        root.currentCapturePath = root.capturePath();
        const checkCmd = "if dms cl paste > " + root.currentCapturePath + " 2>/dev/null && file -b " + root.currentCapturePath + " | grep -qi \"image\"; then echo \"IMAGE\"; else TEXT=$(dms cl paste 2>/dev/null); if [ -n \"$TEXT\" ]; then echo \"TEXT:$TEXT\"; else echo \"EMPTY\"; fi; fi";
        Proc.runCommand("smart-paste", ["sh", "-c", checkCmd], (stdout, exitCode) => {
            const output = stdout.trim();
            if (output === "IMAGE") {
                root.validateAndOpenCapturedImage(root.currentCapturePath);
            } else if (output.startsWith("TEXT:")) {
                let text = output.substring(5).trim();
                if (text === "") {
                    if (typeof ToastService !== "undefined" && ToastService)
                        ToastService.showError("Clipboard text is not a valid URL or path.");
                } else {
                    root.loadImageFromUri(text);
                }
            } else {
                if (typeof ToastService !== "undefined" && ToastService)
                    ToastService.showError("No valid image, URL, or path in clipboard.");
            }
        });
    }

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
                const minSize = pluginData.minImageSize ?? 16;
                if (w < minSize || h < minSize) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Image is too small (" + w + "x" + h + "). Minimum: " + minSize + "px");
                    }
                    return;
                }
            }

            modal.currentCapturePath = path;
            modal.shouldBeVisible = true;
            modal.openCentered();
        });
    }

    function loadImageFromUri(uri) {
        if (uri.startsWith("file://"))
            uri = uri.substring(7);

        if (uri.startsWith("http://") || uri.startsWith("https://")) {
            root.isDownloading = true;
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", root.currentCapturePath, uri], (stdout, exitCode) => {
                root.isDownloading = false;
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath);
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Failed to download image.");
                }
            });
        } else {
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("copy-image", ["cp", "-f", uri, root.currentCapturePath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath);
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

        root.loadImageFromUri(urlStr);
    }

    // ── Plugin identity ───────────────────────────────────────────────────────
    pluginId: "quickCapture"
    pluginService: PluginService

    // ── IPC handlers ─────────────────────────────────────────────────────────
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
            root.loadImageFromUri(path);
            return "SUCCESS";
        }

        function close() : string {
            modal.shouldBeVisible = false;
            modal.close();
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

    // ── Modal ─────────────────────────────────────────────────────────────────
    QuickCaptureModal {
        id: modal

        parentWidget: root
    }

    // ── File browser ──────────────────────────────────────────────────────────
    FileBrowserModal {
        id: fileBrowserModal
        browserTitle: I18n.tr("Select Image to Annotate")
        browserIcon: "image"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        onFileSelected: path => {
            root.currentCapturePath = root.capturePath();
            Proc.runCommand("copy-image", ["cp", "-f", path, root.currentCapturePath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage(root.currentCapturePath);
                } else {
                    ToastService.showError("Failed to load image.");
                }
            });
            close();
        }
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
