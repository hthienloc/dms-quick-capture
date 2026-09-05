import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "Helpers.js" as Helpers

QtObject {
    id: root

    property var parentWidget: null
    property var modal: null
    property var exportAndExecute: null
    property var floatService: null

    signal closeRequested()

    function getPluginData() {
        return (root.parentWidget && root.parentWidget.pluginData) || {};
    }

    function saveDirectory() {
        return root.getPluginData().saveDirectory || "~/Pictures/Screenshots";
    }

    function screenshotFilename() {
        const data = root.getPluginData();
        const pattern = data.saveFilenamePattern || "Screenshot-%Y-%m-%d_%H-%M-%S";
        const format = data.outputFormat || "png";

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
            filename = "Screenshot-" + yyyy + "-" + MM + "-" + dd + "_" + HH + "-" + mm + "-" + ss;
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
        if (path && (path.startsWith("/tmp/dms_capture_") || path.startsWith("/tmp/img_"))) {
            // Delay cleanup by 10s to allow notification daemons to load the image
            Proc.runCommand("cleanup-temp-delayed", ["sh", "-c", "sleep 10 && rm -f -- " + shellPathExpression(path)]);
        }
    }

    function cleanupConvertedFiles(finalPath, originalPng) {
        cleanupTemp(finalPath);
        if (originalPng) cleanupTemp(originalPng);
    }

    function commandOutputOrFallback(output, fallback) {
        return output ? output.trim() : fallback;
    }

    function sendNotification(title, message, imagePath, openPath) {
        if (!message) return;
        const mode = root.getPluginData().postNotification || "notification";
        
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

            const args = ["dms", "notify", "--app", "Quick Capture"];
            if (icon) args.push("--icon", icon);
            if (openPath) args.push("--file", openPath);
            args.push("--timeout", "5000", title, message);
            Proc.runCommand("system-notify", args);
        }
    }

    function notifyWarning(message) {
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showWarning(message);
        }
    }

    function notifyError(message, detail) {
        let fullMsg = message;
        if (detail) {
            fullMsg += "\n" + detail;
        }
        console.error("[QuickCapture Error]", message, detail ? ("| Detail: " + detail) : "");
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showError(fullMsg);
        }
        
        const mode = root.getPluginData().postNotification || "notification";
        if (mode === "notification" || mode === "both") {
            Proc.runCommand("system-notify-error", ["notify-send", "-u", "critical", "-a", "Quick Capture", "-i", "error", I18n.trFor("quickCapture", "Quick Capture Error"), fullMsg]);
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
        const data = root.getPluginData();
        const format = data.outputFormat || "png";

        if (format === "png" || format === "ppm") {
            callback(pngPath, "");
            return;
        }

        const finalOut = pngPath.replace(/\.png$/, "." + format);
        let cmd = "";
        let args = [];

        if (format === "webp" || format === "jpg") {
            const quality = format === "webp"
                ? String(data.webpQuality ?? 80)
                : String(data.jpegQuality ?? 90);
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

    /**
     * Exports the current capture and converts it to the configured format.
     * @param {function} callback - Receives the final path and optional original PNG path.
     */
    function withConvertedExport(callback) {
        withExport((pngPath) => {
            convertIfNeeded(pngPath, callback);
        });
    }

    function copyFileToClipboard(tempOut, callback) {
        const checkCmd = "[ -s " + shellPathExpression(tempOut) + " ] || { echo 'ERROR: Exported screenshot file is empty or missing' >&2; exit 2; }";
        Proc.runCommand("check-copy-file", ["sh", "-c", checkCmd], (checkOut, checkCode) => {
            if (checkCode !== 0) {
                const errDetail = commandOutputOrFallback(checkOut, "Exported file missing or empty (" + tempOut + ")");
                console.error("[QuickCapture] Copy pre-check failed:", errDetail);
                callback(errDetail, checkCode);
                return;
            }
            DMSService.sendRequest("clipboard.copyFile", { "filePath": tempOut }, function(response) {
                if (response && response.error) {
                    const errStr = String(response.error);
                    console.error("[QuickCapture] DMS clipboard copy failed:", errStr);
                    callback(errStr, 1);
                } else {
                    callback("", 0);
                }
            });
        }, 0, 2000);
    }

    /**
     * Copies an exported image and normalizes clipboard failure details.
     * @param {string} sourceFile - File to copy to the clipboard.
     * @param {function} onSuccess - Called after a successful copy.
     * @param {function} onFailure - Called with a readable detail and exit code.
     */
    function copyExportedFile(sourceFile, onSuccess, onFailure) {
        copyFileToClipboard(sourceFile, (output, exitCode) => {
            if (exitCode === 0) {
                onSuccess();
                return;
            }
            onFailure(commandOutputOrFallback(output, "Clipboard exit code " + exitCode), exitCode);
        });
    }

    function saveFile(tempOut, callback) {
        const saveDir = saveDirectory();
        const filename = screenshotFilename();
        const targetPath = saveDir.replace(/\/$/, "") + "/" + filename;
        saveFileToPath(tempOut, targetPath, (stdout, exitCode) => {
            callback(stdout, exitCode, saveDir, filename, targetPath);
        });
    }

    function saveFileToPath(tempOut, targetPath, callback) {
        const slashIndex = targetPath.lastIndexOf("/");
        const saveDir = slashIndex > 0 ? targetPath.slice(0, slashIndex) : ".";
        const saveCmd = "[ -s " + shellPathExpression(tempOut) + " ] || { echo 'ERROR: Exported screenshot file is empty or missing' >&2; exit 2; }; " +
                        "mkdir -p -- " + shellPathExpression(saveDir) +
                        " && cp -- " + shellPathExpression(tempOut) + " " + shellPathExpression(targetPath);

        Proc.runCommand("save-capture-file", ["sh", "-c", saveCmd], callback, 0, 5000);
    }

    function normalizeSaveAsPath(path) {
        let targetPath = Paths.strip(String(path || "").trim());
        if (!targetPath) return "";
        targetPath = Paths.expandTilde(targetPath);

        const format = root.getPluginData().outputFormat || "png";
        const extension = "." + format.toLowerCase();
        const slashIndex = targetPath.lastIndexOf("/");
        const dotIndex = targetPath.lastIndexOf(".");
        if (dotIndex <= slashIndex) return targetPath + extension;
        return targetPath.slice(0, dotIndex) + extension;
    }

    function performSaveOnly() {
        withConvertedExport((finalPath, originalPng) => {
            saveFile(finalPath, (stdout, exitCode, saveDir, filename, targetPath) => {
                if (exitCode === 0) {
                    const notifyPath = Paths.expandTilde(targetPath);
                    const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                    root.sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot saved to %1/%2").arg(saveDir).arg(filename), iconPath, notifyPath);
                    root.closeRequested();
                } else {
                    const errDetail = commandOutputOrFallback(stdout, "Save command failed with exit code " + exitCode);
                    console.error("[QuickCapture] Save failed:", errDetail);
                    notifyError(I18n.trFor("quickCapture", "Failed to save screenshot file."), errDetail);
                }
                cleanupConvertedFiles(finalPath, originalPng);
            });
        });
    }

    function performSaveAs(path) {
        const targetPath = normalizeSaveAsPath(path);
        if (!targetPath) return;

        withConvertedExport((finalPath, originalPng) => {
            saveFileToPath(finalPath, targetPath, (stdout, exitCode) => {
                if (exitCode === 0) {
                    const notifyPath = Paths.expandTilde(targetPath);
                    const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                    root.sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot saved to %1").arg(notifyPath), iconPath, notifyPath);
                    root.closeRequested();
                } else {
                    const errDetail = commandOutputOrFallback(stdout, "Save As command failed with exit code " + exitCode);
                    console.error("[QuickCapture] Save As failed:", errDetail);
                    notifyError(I18n.trFor("quickCapture", "Failed to save screenshot file."), errDetail);
                }
                cleanupConvertedFiles(finalPath, originalPng);
            });
        });
    }

    function performCopyOnly() {
        withConvertedExport((finalPath, originalPng) => {
            const clipSource = originalPng || finalPath;
            copyExportedFile(clipSource, () => {
                root.sendNotification(I18n.trFor("quickCapture", "Screenshot Copied"), I18n.trFor("quickCapture", "Screenshot copied to clipboard."), clipSource);
                root.closeRequested();
                cleanupConvertedFiles(finalPath, originalPng);
            }, (errDetail) => {
                console.error("[QuickCapture] Copy failed:", errDetail);
                notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot to clipboard."), errDetail);
                root.closeRequested();
                cleanupConvertedFiles(finalPath, originalPng);
            });
        });
    }

    function generateRandomString(length) {
        let result = "";
        const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        for (let i = 0; i < (length || 12); i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }

    function performAnonymousCopy() {
        withExport((pngPath) => {
            const randomStr = generateRandomString(12);
            const anonPath = "/tmp/img_" + randomStr + ".png";
            const stripCmd = "magick convert -- " + shellPathExpression(pngPath) + " -strip " + shellPathExpression(anonPath);

            Proc.runCommand("anon-copy-strip", ["sh", "-c", stripCmd], (stdout, exitCode) => {
                const stripSuccess = (exitCode === 0);
                const doCopy = (sourceFile, isStripped) => {
                    copyExportedFile(sourceFile, () => {
                        const msg = isStripped
                            ? I18n.trFor("quickCapture", "Screenshot copied anonymously with randomized name and stripped metadata.")
                            : I18n.trFor("quickCapture", "Screenshot copied with randomized name.");
                        root.sendNotification(I18n.trFor("quickCapture", "Copied Anonymously"), msg, sourceFile);
                        root.closeRequested();
                        cleanupTemp(pngPath);
                        if (sourceFile !== pngPath) cleanupTemp(sourceFile);
                    }, (errDetail) => {
                        notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot to clipboard."), errDetail);
                        root.closeRequested();
                        cleanupTemp(pngPath);
                        if (sourceFile !== pngPath) cleanupTemp(sourceFile);
                    });
                };

                if (stripSuccess) {
                    doCopy(anonPath, true);
                } else {
                    const fallbackCmd = "cp -- " + shellPathExpression(pngPath) + " " + shellPathExpression(anonPath);
                    Proc.runCommand("anon-copy-fallback", ["sh", "-c", fallbackCmd], (fbOut, fbExit) => {
                        const targetFile = (fbExit === 0) ? anonPath : pngPath;
                        doCopy(targetFile, false);
                    });
                }
            });
        });
    }

    function performCopyAndSave() {
        withConvertedExport((finalPath, originalPng) => {
            const clipSource = originalPng || finalPath;
            copyExportedFile(clipSource, () => {
                saveFile(finalPath, (saveOut, saveCode, saveDir, filename, targetPath) => {
                    if (saveCode === 0) {
                        const notifyPath = Paths.expandTilde(targetPath);
                        const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                        root.sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot copied to clipboard and saved to %1").arg(saveDir), iconPath, notifyPath);
                    } else {
                        const errDetail = commandOutputOrFallback(saveOut, "Save exit code " + saveCode);
                        notifyWarning(I18n.trFor("quickCapture", "Screenshot copied to clipboard but failed to save file: %1").arg(errDetail));
                    }
                    root.closeRequested();
                    cleanupConvertedFiles(finalPath, originalPng);
                });
            }, (errDetail) => {
                console.error("[QuickCapture] Copy&Save failed on copy step:", errDetail);
                notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot to clipboard."), errDetail);
                root.closeRequested();
                cleanupConvertedFiles(finalPath, originalPng);
            });
        });
    }

    function performDoneAction() {
        const action = root.getPluginData().doneAction || "both";

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

        if (!root.floatService) {
            notifyError("Float service not available.");
            return;
        }

        // Build annotation state from current modal
        var strokesList = root.modal.strokes || [];
        var serializedStrokes = [];
        for (var si = 0; si < strokesList.length; si++) {
            var s = strokesList[si];
            var newStroke = {
                tool: s.tool,
                color: s.color,
                width: s.width,
                points: []
            };
            if (s.points) {
                for (var pj = 0; pj < s.points.length; pj++) {
                    newStroke.points.push({ x: s.points[pj].x, y: s.points[pj].y });
                }
            }
            Helpers.copyStrokeProperties(s, newStroke);
            serializedStrokes.push(newStroke);
        }

        var annotationState = {
            strokes: serializedStrokes,
            originalImageSource: root.modal.bgImageSource,
            stampCounter: root.modal.stampCounter,
            bgRotation: root.modal.bgRotation,
            bgFlipH: root.modal.bgFlipH,
            bgFlipV: root.modal.bgFlipV,
            cropRect: {
                x: root.modal.cropRect.x,
                y: root.modal.cropRect.y,
                width: root.modal.cropRect.width,
                height: root.modal.cropRect.height
            },
            hasSelection: root.modal.hasSelection,
            backgroundMode: root.modal.backgroundMode,
            backgroundImagePath: root.modal.backgroundImagePath,
            backgroundImageBlur: root.modal.backgroundImageBlur,
            backgroundImageDim: root.modal.backgroundImageDim,
            backgroundImageDimStrength: root.modal.backgroundImageDimStrength,
            watermarkEnabled: root.modal.watermarkEnabled,
            backgroundSolidColor: root.modal.backgroundSolidColor,
            backgroundGradientStart: root.modal.backgroundGradientStart,
            backgroundGradientEnd: root.modal.backgroundGradientEnd,
            backgroundGradientAngle: root.modal.backgroundGradientAngle,
            backgroundPadding: root.modal.backgroundPadding,
            backgroundCornerRadius: root.modal.backgroundCornerRadius,
            backgroundShadowStrength: root.modal.backgroundShadowStrength,
            backgroundAspectRatio: root.modal.backgroundAspectRatio,
            backgroundAlignment: root.modal.backgroundAlignment,
            customAspectRatio: root.modal.customAspectRatio,
            hasUserCustomizedBackground: root.modal.hasUserCustomizedBackground,
            autoBackgroundGradientStart: root.modal.autoBackgroundGradientStart,
            autoBackgroundGradientEnd: root.modal.autoBackgroundGradientEnd,
            autoBackgroundSolidColor: root.modal.autoBackgroundSolidColor
        };

        withConvertedExport((finalPath, originalPng) => {
            var pluginData = root.getPluginData();

            var tempPaths = [finalPath];
            if (originalPng) tempPaths.push(originalPng);

            root.floatService.spawnWindow("file://" + finalPath, pluginData, annotationState, tempPaths);
            root.closeRequested();
        });
    }
}
