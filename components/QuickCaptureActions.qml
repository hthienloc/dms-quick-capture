import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "StrokeProperties.js" as StrokeProps

QtObject {
    id: root

    property var parentWidget: null
    property var modal: null
    property var exportAndExecute: null

    signal closeRequested()

    function saveDirectory() {
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        return hasParent ? (root.parentWidget.pluginData.saveDirectory || "~/Pictures/Screenshots") : "~/Pictures/Screenshots";
    }

    function screenshotFilename() {
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        const pattern = hasParent ? (root.parentWidget.pluginData.saveFilenamePattern || "Screenshot_%Y-%m-%d_%H-%M-%S") : "Screenshot_%Y-%m-%d_%H-%M-%S";
        const format = hasParent ? (root.parentWidget.pluginData.outputFormat || "png") : "png";

        const now = new Date();
        const pad = function(num, size) {
            let s = num + "";
            while (s.length < (size || 2)) s = "0" + s;
            return s;
        };

        const yyyy = now.getFullYear();
        const yy = pad(yyyy % 100);
        const MM = pad(now.getMonth() + 1);
        const dd = pad(now.getDate());
        const HH = pad(now.getHours());
        const mm = pad(now.getMinutes());
        const ss = pad(now.getSeconds());
        const zzz = pad(now.getMilliseconds(), 3);

        let filename = pattern
            .replace(/%Y/g, yyyy)
            .replace(/%y/g, yy)
            .replace(/%m/g, MM)
            .replace(/%d/g, dd)
            .replace(/%H/g, HH)
            .replace(/%M/g, mm)
            .replace(/%S/g, ss)
            .replace(/\{yyyy\}/gi, yyyy)
            .replace(/\{MM\}/g, MM)
            .replace(/\{dd\}/gi, dd)
            .replace(/\{HH\}/gi, HH)
            .replace(/\{mm\}/g, mm)
            .replace(/\{ss\}/gi, ss)
            .replace(/\{zzz\}/gi, zzz);

        if (!filename) {
            filename = "Screenshot_" + yyyy + "-" + MM + "-" + dd + "_" + HH + "-" + mm + "-" + ss;
        }

        return filename + "." + format;
    }

    function escapeDoubleQuoted(value) {
        return String(value)
            .replace(/\\/g, "\\\\")
            .replace(/"/g, "\\\"")
            .replace(/\$/g, "\\$")
            .replace(/`/g, "\\`");
    }

    function shellPathExpression(path) {
        const value = String(path);
        if (value === "~") return "\"$HOME\"";
        if (value.indexOf("~/") === 0) return "\"$HOME/" + escapeDoubleQuoted(value.slice(2)) + "\"";
        return "\"" + escapeDoubleQuoted(value) + "\"";
    }

    function cleanupTemp(path) {
        if (path && path.startsWith("/tmp/dms_capture_")) {
            // Delay cleanup by 10s to allow notification daemons to load the image
            Proc.runCommand("cleanup-temp-delayed", ["sh", "-c", "sleep 10 && rm -f -- " + shellPathExpression(path)]);
        }
    }

    function sendNotification(message, imagePath) {
        if (!message) return;
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        const mode = hasParent ? (root.parentWidget.pluginData.postNotification || "notification") : "notification";
        
        if (mode === "none") return;

        // Toast Notification
        if (mode === "toast" || mode === "both") {
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showInfo(message);
            }
        }

        // System Notification
        if (mode === "notification" || mode === "both") {
            let icon = imagePath ? imagePath : "camera-photo-symbolic";
            
            if (icon.toLowerCase().endsWith(".pdf")) {
                icon = "image-x-generic";
            }

            const args = ["notify-send", "-a", "Quick Capture", "-i", icon, I18n.tr("Quick Capture"), message];
            if (imagePath && !imagePath.toLowerCase().endsWith(".pdf")) {
                let cleanPath = imagePath.replace(/^file:\/\//, "");
                args.push("-h", "string:image-path:" + cleanPath);
                args.push("-h", "string:image_path:" + cleanPath);
            }
            Proc.runCommand("system-notify", args);
        }
    }

    function notifyInfo(message, imagePath) {
        root.sendNotification(message, imagePath);
    }

    function notifyWarning(message) {
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showWarning(message);
        }
    }

    function notifyError(message) {
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showError(message);
        }
        
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        const mode = hasParent ? (root.parentWidget.pluginData.postNotification || "notification") : "notification";
        if (mode === "notification" || mode === "both") {
            Proc.runCommand("system-notify-error", ["notify-send", "-u", "critical", "-a", "Quick Capture", "-i", "error", I18n.tr("Quick Capture Error"), message]);
        }
    }

    function withExport(callback) {
        if (!root.exportAndExecute) {
            console.warn("QuickCaptureActions: exportAndExecute is not initialized");
            return;
        }
        root.exportAndExecute(callback);
    }

    function convertIfNeeded(pngPath, callback) {
        const pData = (root.parentWidget && root.parentWidget.pluginData) || {};
        const format = pData.outputFormat || "png";

        if (format === "png" || format === "ppm") {
            callback(pngPath, "");
            return;
        }

        const finalOut = pngPath.replace(/\.png$/, "." + format);
        let cmd = "";
        let args = [];

        if (format === "webp") {
            const quality = String(pData.webpQuality ?? 80);
            cmd = "magick";
            args = ["convert", pngPath, "-quality", quality, finalOut];
        } else if (format === "jpg") {
            const quality = String(pData.jpegQuality ?? 90);
            cmd = "magick";
            args = ["convert", pngPath, "-quality", quality, finalOut];
        } else if (format === "pdf") {
            cmd = "img2pdf";
            args = [pngPath, "-o", finalOut];
        }

        if (cmd) {
            Proc.runCommand("convert-format", [cmd].concat(args), (stdout, exitCode) => {
                if (exitCode === 0) {
                    callback(finalOut, pngPath);
                } else {
                    console.error("[QuickCapture] Conversion failed (exit " + exitCode + "):", stdout);
                    callback(pngPath, ""); // Fallback to PNG
                }
            });
        } else {
            callback(pngPath, "");
        }
    }

    function copyFileToClipboard(tempOut, callback) {
        DMSService.sendRequest("clipboard.copyFile", { "filePath": tempOut }, function(response) {
            if (response.error) {
                console.error("DMS native copy failed:", response.error);
                callback(response.error, 1);
            } else {
                callback("", 0);
            }
        });
    }

    function saveFile(tempOut, callback) {
        const saveDir = saveDirectory();
        const filename = screenshotFilename();
        const targetPath = saveDir.replace(/\/$/, "") + "/" + filename;
        const saveCmd = "mkdir -p -- " + shellPathExpression(saveDir) +
                        " && cp -- " + shellPathExpression(tempOut) + " " + shellPathExpression(targetPath);

        Proc.runCommand("save-capture-file", ["sh", "-c", saveCmd], (stdout, exitCode) => {
            callback(stdout, exitCode, saveDir, filename, targetPath);
        }, 0, 5000);
    }

    function performSaveOnly() {
        withExport((pngPath) => {
            convertIfNeeded(pngPath, (finalPath, originalPng) => {
                saveFile(finalPath, (stdout, exitCode, saveDir, filename, targetPath) => {
                    if (exitCode === 0) {
                        const notifyPath = targetPath.replace(/^~/, Quickshell.env("HOME"));
                        const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                        notifyInfo(I18n.tr("Screenshot saved to %1/%2").arg(saveDir).arg(filename), iconPath);
                        root.closeRequested();
                    } else {
                        notifyError("Failed to save screenshot file.");
                    }
                    cleanupTemp(finalPath);
                    if (originalPng) cleanupTemp(originalPng);
                });
            });
        });
    }

    function performCopyOnly() {
        withExport((pngPath) => {
            convertIfNeeded(pngPath, (finalPath, originalPng) => {
                const clipSource = originalPng || finalPath;
                copyFileToClipboard(clipSource, (stdout, exitCode) => {
                    if (exitCode === 0) {
                        notifyInfo(I18n.tr("Screenshot copied to clipboard."), clipSource);
                        root.closeRequested();
                    } else {
                        notifyError("Failed to copy screenshot to clipboard.");
                        root.closeRequested();
                    }
                    cleanupTemp(finalPath);
                    if (originalPng) cleanupTemp(originalPng);
                });
            });
        });
    }

    function performCopyAndSave() {
        withExport((pngPath) => {
            convertIfNeeded(pngPath, (finalPath, originalPng) => {
                const clipSource = originalPng || finalPath;
                copyFileToClipboard(clipSource, (stdout, exitCode) => {
                    if (exitCode === 0) {
                        saveFile(finalPath, (saveOut, saveCode, saveDir, filename, targetPath) => {
                            if (saveCode === 0) {
                                const notifyPath = targetPath.replace(/^~/, Quickshell.env("HOME"));
                                const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                                notifyInfo(I18n.tr("Screenshot copied to clipboard and saved to %1").arg(saveDir), iconPath);
                            } else {
                                notifyWarning("Screenshot copied to clipboard but failed to save file.");
                            }
                            root.closeRequested();
                            cleanupTemp(finalPath);
                            if (originalPng) cleanupTemp(originalPng);
                        });
                    } else {
                        notifyError("Failed to copy screenshot to clipboard.");
                        root.closeRequested();
                        cleanupTemp(finalPath);
                        if (originalPng) cleanupTemp(originalPng);
                    }
                });
            });
        });
    }

    function performDoneAction() {
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        const action = hasParent ? (root.parentWidget.pluginData.doneAction || "both") : "both";

        if (action === "clipboard") {
            root.performCopyOnly();
        } else if (action === "file") {
            root.performSaveOnly();
        } else {
            root.performCopyAndSave();
        }
    }

    function performFloatAction() {
        if (!root.modal) {
            console.error("QuickCaptureActions: modal reference is null");
            return;
        }

        withExport((pngPath) => {
            convertIfNeeded(pngPath, (finalPath, originalPng) => {
                // 1. Serialize strokes
                let strokesList = root.modal.strokes || [];
                let serializedStrokes = [];
                for (let i = 0; i < strokesList.length; i++) {
                    let s = strokesList[i];
                    let newStroke = {
                        tool: s.tool,
                        color: s.color,
                        width: s.width,
                        points: []
                    };
                    if (s.points) {
                        for (let j = 0; j < s.points.length; j++) {
                            newStroke.points.push({ x: s.points[j].x, y: s.points[j].y });
                        }
                    }
                    StrokeProps.copyStrokeProperties(s, newStroke);
                    serializedStrokes.push(newStroke);
                }

                // 2. Serialize other states
                let stateData = {
                    strokes: serializedStrokes,
                    stampCounter: root.modal.stampCounter,
                    cropRect: {
                        x: root.modal.cropRect.x,
                        y: root.modal.cropRect.y,
                        width: root.modal.cropRect.width,
                        height: root.modal.cropRect.height
                    },
                    hasSelection: root.modal.hasSelection,
                    backdropMode: root.modal.backdropMode,
                    backdropSolidColor: root.modal.backdropSolidColor,
                    backdropGradientStart: root.modal.backdropGradientStart,
                    backdropGradientEnd: root.modal.backdropGradientEnd,
                    backdropGradientAngle: root.modal.backdropGradientAngle,
                    backdropPadding: root.modal.backdropPadding,
                    backdropCornerRadius: root.modal.backdropCornerRadius,
                    backdropShadowStrength: root.modal.backdropShadowStrength,
                    backdropAspectRatio: root.modal.backdropAspectRatio,
                    customAspectRatio: root.modal.customAspectRatio,
                    hasUserCustomizedBackdrop: root.modal.hasUserCustomizedBackdrop,
                    autoBackdropGradientStart: root.modal.autoBackdropGradientStart,
                    autoBackdropGradientEnd: root.modal.autoBackdropGradientEnd,
                    autoBackdropSolidColor: root.modal.autoBackdropSolidColor
                };

                let jsonStr = JSON.stringify(stateData);

                // 3. Write strokes to sidecar file
                Proc.runCommand("write-strokes", ["python3", "-c", "import sys; open('/tmp/dms_capture_strokes.json', 'w').write(sys.argv[1])", jsonStr], (stdout, writeExitCode) => {
                    if (writeExitCode !== 0) {
                        console.error("Failed to write strokes JSON sidecar");
                    }
                    
                    // 4. Float the baked image
                    const floatDest = "/tmp/dms_capture_float/" + Date.now() + ".png";
                    const floatBase = floatDest.replace(/\.png$/, "");

                    Proc.runCommand("mkdir-float-dir", ["mkdir", "-p", "/tmp/dms_capture_float"], () => {
                        Proc.runCommand("cp-float", ["cp", "-f", finalPath, floatDest], () => {
                            Proc.runCommand("cp-float-bg", ["cp", "-f", "/tmp/dms_capture_bg.png", floatBase + "_bg.png"]);
                            Proc.runCommand("cp-float-strokes", ["cp", "-f", "/tmp/dms_capture_strokes.json", floatBase + "_strokes.json"]);
                            Proc.runCommand("float-capture", ["dms", "ipc", "call", "floaty", "floatFromUrl", "file://" + floatDest], (stdout, exitCode) => {
                                if (exitCode === 0) {
                                    root.closeRequested();
                                } else {
                                    notifyError("Failed to float image (make sure dms-floaty is running).");
                                }
                                cleanupTemp(finalPath);
                                if (originalPng) cleanupTemp(originalPng);
                            });
                        });
                    });
                });
            });
        });
    }
}
