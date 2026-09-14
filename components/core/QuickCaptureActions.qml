import QtQuick
import qs.Common
import qs.Services
import "Helpers.js" as Helpers
import "Defaults.js" as Defaults

QtObject {
    id: root

    property var daemon: null
    property var modal: null
    property var floatService: null
    property var exportAndExecute: null

    signal closeRequested

    readonly property var pluginData: daemon?.pluginData ?? ({})

    function setting(key) {
        return Defaults.get(root.pluginData, key);
    }

    function saveDirectory() {
        return Paths.expandTilde(String(setting("saveDirectory")));
    }

    function screenshotFilename() {
        const name = Helpers.expandDateTokens(setting("saveFilenamePattern")) || Helpers.expandDateTokens(Defaults.values.saveFilenamePattern);
        return name + "." + setting("outputFormat");
    }

    function cleanupTemp(path) {
        if (!path || !(path.startsWith("/tmp/dms_capture_") || path.startsWith("/tmp/img_")))
            return;
        // Delayed so notification daemons can still load the image
        Proc.runCommand(null, ["sh", "-c", 'sleep 10 && rm -f -- "$1"', "_", path]);
    }

    function cleanupConvertedFiles(finalPath, originalPng) {
        cleanupTemp(finalPath);
        if (originalPng)
            cleanupTemp(originalPng);
    }

    function commandOutputOrFallback(output, fallback) {
        return output ? output.trim() : fallback;
    }

    function sendNotification(title, message, imagePath, openPath) {
        if (!message)
            return;
        const mode = setting("postNotification");
        if (mode === "none")
            return;
        if (mode === "toast" || mode === "both")
            ToastService.showInfo(message);
        if (mode !== "notification" && mode !== "both")
            return;

        let icon = imagePath || "camera-photo-symbolic";
        if (icon.toLowerCase().endsWith(".pdf"))
            icon = "image-x-generic";
        const args = [Proc.dmsBin, "notify", "--app", "Quick Capture", "--icon", icon];
        const fileTarget = openPath || (imagePath && !imagePath.toLowerCase().endsWith(".pdf") ? imagePath : "");
        if (fileTarget)
            args.push("--file", fileTarget);
        args.push("--timeout", "5000", title, message);
        Proc.runCommand("quickCapture.notify", args);
    }

    function notifyWarning(message) {
        ToastService.showWarning(message);
    }

    function notifyError(message, detail) {
        const fullMsg = detail ? message + "\n" + detail : message;
        console.error("quickCapture:", message, detail || "");
        ToastService.showError(fullMsg);
        const mode = setting("postNotification");
        if (mode !== "notification" && mode !== "both")
            return;
        Proc.runCommand("quickCapture.notifyError", ["notify-send", "-u", "critical", "-a", "Quick Capture", "-i", "error", I18n.trFor("quickCapture", "Quick Capture Error"), fullMsg]);
    }

    function withExport(callback) {
        if (!root.exportAndExecute) {
            console.warn("quickCapture: exportAndExecute is not wired");
            return;
        }
        root.exportAndExecute(callback);
    }

    function convertIfNeeded(pngPath, callback) {
        const format = setting("outputFormat");
        if (format === "png" || format === "ppm") {
            callback(pngPath, "");
            return;
        }

        const finalOut = pngPath.replace(/\.png$/, "." + format);
        let command = [];
        if (format === "webp" || format === "jpg") {
            const quality = String(setting(format === "webp" ? "webpQuality" : "jpegQuality"));
            command = ["magick", "convert", pngPath, "-quality", quality, finalOut];
        } else if (format === "pdf") {
            command = ["img2pdf", pngPath, "-o", finalOut];
        }
        if (command.length === 0) {
            callback(pngPath, "");
            return;
        }

        Proc.runCommand("quickCapture.convert", command, (stdout, exitCode) => {
            if (exitCode === 0) {
                callback(finalOut, pngPath);
                return;
            }
            console.error("quickCapture: conversion failed (exit " + exitCode + "):", stdout);
            callback(pngPath, "");
        });
    }

    function withConvertedExport(callback) {
        withExport(pngPath => convertIfNeeded(pngPath, callback));
    }

    function copyFileToClipboard(tempOut, callback) {
        Proc.runCommand("quickCapture.checkCopyFile", ["test", "-s", tempOut], (checkOut, checkCode) => {
            if (checkCode !== 0) {
                callback("Exported file missing or empty (" + tempOut + ")", checkCode);
                return;
            }
            DMSService.sendRequest("clipboard.copyFile", {
                "filePath": tempOut
            }, response => {
                if (response?.error) {
                    callback(String(response.error), 1);
                    return;
                }
                callback("", 0);
            });
        }, 0, 2000);
    }

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
        saveFileToPath(tempOut, targetPath, (stdout, exitCode) => callback(stdout, exitCode, saveDir, filename, targetPath));
    }

    function saveFileToPath(tempOut, targetPath, callback) {
        const resolvedTargetPath = Paths.expandTilde(String(targetPath));
        const slashIndex = resolvedTargetPath.lastIndexOf("/");
        const saveDir = slashIndex > 0 ? resolvedTargetPath.slice(0, slashIndex) : ".";
        const saveCmd = '[ -s "$1" ] || { echo "ERROR: Exported screenshot file is empty or missing" >&2; exit 2; }; ' + 'mkdir -p -- "$2" && cp -- "$1" "$3"';
        Proc.runCommand("quickCapture.saveFile", ["sh", "-c", saveCmd, "_", tempOut, saveDir, resolvedTargetPath], callback, 0, 5000);
    }

    function normalizeSaveAsPath(path) {
        let targetPath = Paths.strip(String(path || "").trim());
        if (!targetPath)
            return "";
        targetPath = Paths.expandTilde(targetPath);
        const extension = "." + String(setting("outputFormat")).toLowerCase();
        const slashIndex = targetPath.lastIndexOf("/");
        const dotIndex = targetPath.lastIndexOf(".");
        if (dotIndex <= slashIndex)
            return targetPath + extension;
        return targetPath.slice(0, dotIndex) + extension;
    }

    function notifySaved(targetPath, originalPng) {
        const notifyPath = Paths.expandTilde(targetPath);
        const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
        sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot saved to %1").arg(notifyPath), iconPath, notifyPath);
    }

    function copyImage(path, after) {
        copyExportedFile(path, () => {
            sendNotification(I18n.trFor("quickCapture", "Screenshot Copied"), I18n.trFor("quickCapture", "Copied to clipboard"), path);
            if (after)
                after(true);
        }, detail => {
            notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot"), detail);
            if (after)
                after(false);
        });
    }

    function saveImage(path, after, originalPng) {
        saveFile(path, (stdout, exitCode, saveDir, filename, targetPath) => {
            if (exitCode !== 0) {
                notifyError(I18n.trFor("quickCapture", "Failed to save screenshot"), commandOutputOrFallback(stdout, "Save exit code " + exitCode));
                if (after)
                    after(false);
                return;
            }
            notifySaved(targetPath, originalPng);
            if (after)
                after(true);
        });
    }

    function saveImageAs(path, targetPath, after, originalPng) {
        saveFileToPath(path, targetPath, (stdout, exitCode) => {
            if (exitCode !== 0) {
                notifyError(I18n.trFor("quickCapture", "Failed to save screenshot"), commandOutputOrFallback(stdout, "Save exit code " + exitCode));
                if (after)
                    after(false);
                return;
            }
            notifySaved(targetPath, originalPng);
            if (after)
                after(true);
        });
    }

    function copyAndSaveImage(path, after, originalPng) {
        copyExportedFile(path, () => {
            saveFile(originalPng ? path : path, (stdout, exitCode, saveDir, filename, targetPath) => {
                if (exitCode !== 0) {
                    notifyWarning(I18n.trFor("quickCapture", "Screenshot copied to clipboard but failed to save file: %1").arg(commandOutputOrFallback(stdout, "Save exit code " + exitCode)));
                    if (after)
                        after(false);
                    return;
                }
                const notifyPath = Paths.expandTilde(targetPath);
                const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot copied to clipboard and saved to %1").arg(saveDir), iconPath, notifyPath);
                if (after)
                    after(true);
            });
        }, detail => {
            notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot"), detail);
            if (after)
                after(false);
        });
    }

    function finishExport(finalPath, originalPng) {
        root.closeRequested();
        cleanupConvertedFiles(finalPath, originalPng);
    }

    function performSaveOnly() {
        withConvertedExport((finalPath, originalPng) => {
            saveImage(finalPath, ok => {
                if (ok)
                    root.closeRequested();
                cleanupConvertedFiles(finalPath, originalPng);
            }, originalPng);
        });
    }

    function performSaveAs(path) {
        const targetPath = normalizeSaveAsPath(path);
        if (!targetPath)
            return;
        withConvertedExport((finalPath, originalPng) => {
            saveImageAs(finalPath, targetPath, ok => {
                if (ok)
                    root.closeRequested();
                cleanupConvertedFiles(finalPath, originalPng);
            }, originalPng);
        });
    }

    function performCopyOnly() {
        withConvertedExport((finalPath, originalPng) => {
            copyImage(originalPng || finalPath, () => finishExport(finalPath, originalPng));
        });
    }

    function performCopyAndSave() {
        withConvertedExport((finalPath, originalPng) => {
            const clipSource = originalPng || finalPath;
            copyExportedFile(clipSource, () => {
                saveImageAfterCopy(finalPath, originalPng);
            }, detail => {
                notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot"), detail);
                finishExport(finalPath, originalPng);
            });
        });
    }

    function saveImageAfterCopy(finalPath, originalPng) {
        saveFile(finalPath, (stdout, exitCode, saveDir, filename, targetPath) => {
            if (exitCode !== 0) {
                notifyWarning(I18n.trFor("quickCapture", "Screenshot copied to clipboard but failed to save file: %1").arg(commandOutputOrFallback(stdout, "Save exit code " + exitCode)));
            } else {
                const notifyPath = Paths.expandTilde(targetPath);
                const iconPath = (notifyPath.toLowerCase().endsWith(".pdf") && originalPng) ? originalPng : notifyPath;
                sendNotification(I18n.trFor("quickCapture", "Screenshot Saved"), I18n.trFor("quickCapture", "Screenshot copied to clipboard and saved to %1").arg(saveDir), iconPath, notifyPath);
            }
            finishExport(finalPath, originalPng);
        });
    }

    function generateRandomString(length) {
        const chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let result = "";
        for (let i = 0; i < length; i++)
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        return result;
    }

    function performAnonymousCopy() {
        withExport(pngPath => {
            const anonPath = "/tmp/img_" + generateRandomString(12) + ".png";
            const copyAnon = (sourceFile, stripped) => {
                copyExportedFile(sourceFile, () => {
                    const msg = stripped ? I18n.trFor("quickCapture", "Screenshot copied anonymously with randomized name and stripped metadata.") : I18n.trFor("quickCapture", "Screenshot copied with randomized name.");
                    sendNotification(I18n.trFor("quickCapture", "Copied Anonymously"), msg, sourceFile);
                    finishExport(pngPath, sourceFile !== pngPath ? sourceFile : "");
                }, detail => {
                    notifyError(I18n.trFor("quickCapture", "Failed to copy screenshot"), detail);
                    finishExport(pngPath, sourceFile !== pngPath ? sourceFile : "");
                });
            };

            Proc.runCommand("quickCapture.stripMetadata", ["magick", "convert", "--", pngPath, "-strip", anonPath], (stdout, exitCode) => {
                if (exitCode === 0) {
                    copyAnon(anonPath, true);
                    return;
                }
                Proc.runCommand("quickCapture.anonFallback", ["cp", "--", pngPath, anonPath], (fbOut, fbExit) => {
                    copyAnon(fbExit === 0 ? anonPath : pngPath, false);
                });
            });
        });
    }

    function performDoneAction() {
        switch (setting("doneAction")) {
        case "clipboard":
            performCopyOnly();
            return;
        case "file":
            performSaveOnly();
            return;
        default:
            performCopyAndSave();
        }
    }

    function performFloatAction() {
        if (!root.modal) {
            console.error("quickCapture: modal reference is null");
            return;
        }
        if (!root.floatService) {
            notifyError(I18n.trFor("quickCapture", "Float service not available."));
            return;
        }

        const serializedStrokes = (root.modal.strokes || []).map(s => {
            const copy = {
                tool: s.tool,
                color: s.color,
                width: s.width,
                points: (s.points || []).map(p => ({
                            x: p.x,
                            y: p.y
                        }))
            };
            Helpers.copyStrokeProperties(s, copy);
            return copy;
        });

        const m = root.modal;
        const annotationState = {
            strokes: serializedStrokes,
            originalImageSource: m.bgImageSource,
            stampCounter: m.stampCounter,
            bgRotation: m.bgRotation,
            bgFlipH: m.bgFlipH,
            bgFlipV: m.bgFlipV,
            cropRect: {
                x: m.cropRect.x,
                y: m.cropRect.y,
                width: m.cropRect.width,
                height: m.cropRect.height
            },
            hasSelection: m.hasSelection,
            backgroundMode: m.backgroundMode,
            backgroundImagePath: m.backgroundImagePath,
            backgroundImageBlur: m.backgroundImageBlur,
            backgroundImageDim: m.backgroundImageDim,
            backgroundImageDimStrength: m.backgroundImageDimStrength,
            watermarkEnabled: m.watermarkEnabled,
            backgroundSolidColor: m.backgroundSolidColor,
            backgroundGradientStart: m.backgroundGradientStart,
            backgroundGradientEnd: m.backgroundGradientEnd,
            backgroundGradientAngle: m.backgroundGradientAngle,
            backgroundPadding: m.backgroundPadding,
            backgroundCornerRadius: m.backgroundCornerRadius,
            backgroundShadowStrength: m.backgroundShadowStrength,
            backgroundAspectRatio: m.backgroundAspectRatio,
            backgroundAlignment: m.backgroundAlignment,
            customAspectRatio: m.customAspectRatio,
            hasUserCustomizedBackground: m.hasUserCustomizedBackground,
            autoBackgroundGradientStart: m.autoBackgroundGradientStart,
            autoBackgroundGradientEnd: m.autoBackgroundGradientEnd,
            autoBackgroundSolidColor: m.autoBackgroundSolidColor
        };

        withConvertedExport((finalPath, originalPng) => {
            const tempPaths = originalPng ? [finalPath, originalPng] : [finalPath];
            root.floatService.spawnWindow("file://" + finalPath, annotationState, tempPaths);
            root.closeRequested();
        });
    }
}
