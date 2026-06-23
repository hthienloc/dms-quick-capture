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
    property string resolvedDmsPath: "dms"
    property bool restoringFromFloat: false
    property bool isDownloading: false
    // Exposed so the widget surface can read annotation state without accessing internal modal id
    readonly property bool isAnnotating: modal.shouldBeVisible

    // ── Capture helpers ───────────────────────────────────────────────────────
    function screenshotArgs() {
        const mode = root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
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

    function triggerCapture(mode) {
        root.restoringFromFloat = false;
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
        // Delete any existing capture file before taking the screenshot.
        // This lets us detect ESC cancellation when `dms screenshot region`
        // incorrectly returns exit code 0 without writing a new file.
        //
        // For region mode, sleep 400ms first so the bar layer-shell releases
        // mouse/keyboard input before dms screenshot tries to show its overlay.
        const captureMode = root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
        const needsInputRelease = (captureMode === "region" || captureMode === "");
        const cleanupAndShoot = needsInputRelease
            ? ["sh", "-c", "sleep 0.4 && rm -f /tmp/dms_capture_bg.png"]
            : ["rm", "-f", "/tmp/dms_capture_bg.png"];

        Proc.runCommand("pre-capture-cleanup", cleanupAndShoot, () => {
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
        root.closeControlCenter();
        fileBrowserModal.open();
    }

    function fromClipboard() {
        root.restoringFromFloat = false;
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
