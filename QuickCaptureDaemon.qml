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
    function screenshotMode() {
        return root.activeIpcMode !== "" ? root.activeIpcMode : root.captureMode;
    }

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
        Proc.runCommand("pre-capture-cleanup", ["rm", "-f", "/tmp/dms_capture_bg.png"], () => {
            const cmdStr = root.screenshotArgs().map(arg => '"' + arg.replace(/"/g, '\\"') + '"').join(" ") + " 2>&1";
            Proc.runCommand("screenshot-trigger", ["sh", "-c", cmdStr], (stdout, exitCode) => {
                if (exitCode === 0) {
                    // Verify the file was actually written before opening the editor.
                    // If the user pressed ESC, dms may return 0 but write no file.
                    Proc.runCommand("verify-capture", ["test", "-f", "/tmp/dms_capture_bg.png"], (_, fileExists) => {
                        root.isCapturing = false;
                        root.activeIpcMode = "";
                        if (fileExists === 0) {
                            root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                        }
                    });
                } else {
                    const failMode = root.screenshotMode();
                    root.isCapturing = false;
                    root.activeIpcMode = "";
                    if (typeof ToastService !== "undefined" && ToastService) {
                        const errorMsg = (stdout && stdout.trim()) ? stdout.trim() : "Screenshot failed (mode: " + failMode + ").";
                        ToastService.showError(errorMsg);
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
        const checkCmd = "if wl-paste -t image/png > /tmp/dms_capture_bg.png 2>/dev/null; then echo \"IMAGE\"; else TEXT=$(dms cl paste 2>/dev/null); if [ -n \"$TEXT\" ]; then echo \"TEXT:$TEXT\"; else echo \"EMPTY\"; fi; fi";
        Proc.runCommand("smart-paste", ["sh", "-c", checkCmd], (stdout, exitCode) => {
            const output = stdout.trim();
            if (output === "IMAGE") {
                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
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

    function loadImageFromUri(uri) {
        if (uri.startsWith("file://"))
            uri = uri.substring(7);

        if (uri.startsWith("http://") || uri.startsWith("https://")) {
            root.isDownloading = true;
            Proc.runCommand("download-image", ["curl", "-s", "-L", "-o", "/tmp/dms_capture_bg.png", uri], (stdout, exitCode) => {
                root.isDownloading = false;
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Failed to download image.");
                }
            });
        } else {
            Proc.runCommand("copy-image", ["cp", "-f", uri, "/tmp/dms_capture_bg.png"], (stdout, exitCode) => {
                if (exitCode === 0) {
                    root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError("Failed to copy image.");
                }
            });
        }
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
            if (path === "/tmp/dms_capture_bg.png") {
                root.restoringFromFloat = false;
                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
            } else if (path.startsWith("/tmp/dms_capture_float/")) {
                const floatBase = path.replace(/\.png$/, "");
                const bgPath = floatBase + "_bg.png";
                const strokesPath = floatBase + "_strokes.json";
                Proc.runCommand("check-float-bg", ["test", "-f", bgPath], (_, bgExists) => {
                    if (bgExists === 0) {
                        Proc.runCommand("cp-float-bg", ["cp", "-f", bgPath, "/tmp/dms_capture_bg.png"], () => {
                            Proc.runCommand("cp-float-strokes", ["cp", "-f", strokesPath, "/tmp/dms_capture_strokes.json"], () => {
                                root.restoringFromFloat = true;
                                root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                            });
                        });
                    } else {
                        Proc.runCommand("cp-float-img", ["cp", "-f", path, "/tmp/dms_capture_bg.png"], () => {
                            root.restoringFromFloat = false;
                            root.validateAndOpenCapturedImage("/tmp/dms_capture_bg.png");
                        });
                    }
                });
            } else {
                root.restoringFromFloat = false;
                root.loadImageFromUri(path);
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

        // Resolve dms path once at startup
        Proc.runCommand("check-dms-local", ["test", "-x", "/usr/local/bin/dms"], (_, exitCode) => {
            if (exitCode === 0) {
                root.resolvedDmsPath = "/usr/local/bin/dms";
            } else {
                Proc.runCommand("check-dms-usr", ["test", "-x", "/usr/bin/dms"], (_, exitCodeUsr) => {
                    if (exitCodeUsr === 0) {
                        root.resolvedDmsPath = "/usr/bin/dms";
                    } else {
                        root.resolvedDmsPath = "dms";
                    }
                });
            }
        });
    }

    Component.onDestruction: {
        if (pluginService && pluginService.pluginInstances[pluginId] === root) {
            const newInstances = Object.assign({}, pluginService.pluginInstances);
            delete newInstances[pluginId];
            pluginService.pluginInstances = newInstances;
        }
    }
}
