import QtQuick
import qs.Common
import qs.Services

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
        const MM = pad(now.getMonth() + 1);
        const dd = pad(now.getDate());
        const HH = pad(now.getHours());
        const mm = pad(now.getMinutes());
        const ss = pad(now.getSeconds());
        const zzz = pad(now.getMilliseconds(), 3);

        let filename = pattern
            .replace(/%Y/g, yyyy)
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
            Proc.runCommand("cleanup-temp", ["rm", "-f", path]);
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
            // Use actual image as icon to encourage "Fill" behavior in many daemons.
            const icon = imagePath ? imagePath : "camera-photo-symbolic";
            const args = ["notify-send", "-a", "Quick Capture", "-i", icon, I18n.tr("Quick Capture"), message];
            if (imagePath) {
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
            callback(stdout, exitCode, saveDir, filename);
        }, 0, 5000);
    }

    function performSaveOnly() {
        withExport((tempOut, pngTemp) => {
            saveFile(tempOut, (stdout, exitCode, saveDir, filename) => {
                if (exitCode === 0) {
                    notifyInfo(I18n.tr("Screenshot saved to %1/%2").arg(saveDir).arg(filename), tempOut);
                    root.closeRequested();
                } else {
                    notifyError("Failed to save screenshot file.");
                }
                cleanupTemp(tempOut);
                if (pngTemp) cleanupTemp(pngTemp);
            });
        });
    }

    function performCopyOnly() {
        withExport((tempOut, pngTemp) => {
            const clipSource = pngTemp || tempOut;
            copyFileToClipboard(clipSource, (stdout, exitCode) => {
                if (exitCode === 0) {
                    notifyInfo(I18n.tr("Screenshot copied to clipboard."), clipSource);
                    root.closeRequested();
                } else {
                    notifyError("Failed to copy screenshot to clipboard.");
                    root.closeRequested();
                }
                cleanupTemp(tempOut);
                if (pngTemp) cleanupTemp(pngTemp);
            });
        });
    }

    function performCopyAndSave() {
        withExport((tempOut, pngTemp) => {
            const clipSource = pngTemp || tempOut;
            copyFileToClipboard(clipSource, (stdout, exitCode) => {
                if (exitCode === 0) {
                    saveFile(tempOut, (saveOut, saveCode, saveDir, filename) => {
                        if (saveCode === 0) {
                            notifyInfo(I18n.tr("Screenshot copied to clipboard and saved to %1").arg(saveDir), tempOut);
                        } else {
                            notifyWarning("Screenshot copied to clipboard but failed to save file.");
                        }
                        root.closeRequested();
                        cleanupTemp(tempOut);
                        if (pngTemp) cleanupTemp(pngTemp);
                    });
                } else {
                    notifyError("Failed to copy screenshot to clipboard.");
                    root.closeRequested();
                    cleanupTemp(tempOut);
                    if (pngTemp) cleanupTemp(pngTemp);
                }
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

        withExport((tempOut, pngTemp) => {
            // 1. Serialize strokes (typing text is already committed by withExport)
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
                if (s.text !== undefined) newStroke.text = s.text;
                if (s.isMonospace !== undefined) newStroke.isMonospace = s.isMonospace;
                if (s.fontFamily !== undefined) newStroke.fontFamily = s.fontFamily;
                if (s.isBold !== undefined) newStroke.isBold = s.isBold;
                if (s.isItalic !== undefined) newStroke.isItalic = s.isItalic;
                if (s.isUnderline !== undefined) newStroke.isUnderline = s.isUnderline;
                if (s.counter !== undefined) newStroke.counter = s.counter;
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
                hasSelection: root.modal.hasSelection
            };

            let jsonStr = JSON.stringify(stateData);

            // 3. Write strokes to sidecar file
            Proc.runCommand("write-strokes", ["python3", "-c", "import sys; open('/tmp/dms_capture_strokes.json', 'w').write(sys.argv[1])", jsonStr], (stdout, writeExitCode) => {
                if (writeExitCode !== 0) {
                    console.error("Failed to write strokes JSON sidecar");
                }
                
                // 4. Float the baked image
                const cmd = "cp -f -- " + shellPathExpression(tempOut) + " /tmp/dms_capture_float.png" +
                            " && dms ipc call floaty floatFromUrl file:///tmp/dms_capture_float.png";
                Proc.runCommand("float-capture", ["sh", "-c", cmd], (stdout, exitCode) => {
                    if (exitCode === 0) {
                        root.closeRequested();
                    } else {
                        notifyError("Failed to float image (make sure dms-floaty is running).");
                    }
                    cleanupTemp(tempOut);
                    if (pngTemp) cleanupTemp(pngTemp);
                });
            });
        });
    }
}
