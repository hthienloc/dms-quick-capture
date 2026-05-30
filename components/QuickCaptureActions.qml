import QtQuick
import qs.Common
import qs.Services

QtObject {
    id: root

    property var parentWidget: null
    property var exportAndExecute: null

    signal closeRequested()

    function saveDirectory() {
        const hasParent = root.parentWidget && root.parentWidget.pluginData;
        return hasParent ? (root.parentWidget.pluginData.saveDirectory || "~/Pictures/Screenshots") : "~/Pictures/Screenshots";
    }

    function screenshotFilename() {
        return "Screenshot_" + Date.now() + ".png";
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

    function notifyInfo(message) {
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(message);
        }
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
    }

    function withExport(callback) {
        if (!root.exportAndExecute) {
            console.warn("QuickCaptureActions: exportAndExecute is not initialized");
            return;
        }
        root.exportAndExecute(callback);
    }

    function copyFileToClipboard(tempOut, callback) {
        // Use native DMS clipboard service to copy the image file.
        // This removes the dependency on wl-clipboard and ensures it appears in DMS history.
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
        withExport((tempOut) => {
            saveFile(tempOut, (stdout, exitCode, saveDir, filename) => {
                if (exitCode === 0) {
                    notifyInfo("Screenshot saved to " + saveDir + "/" + filename);
                    root.closeRequested();
                } else {
                    notifyError("Failed to save screenshot file.");
                }
            });
        });
    }

    function performCopyOnly() {
        withExport((tempOut) => {
            copyFileToClipboard(tempOut, (stdout, exitCode) => {
                if (exitCode === 0) {
                    notifyInfo("Screenshot copied to clipboard.");
                    root.closeRequested();
                } else {
                    notifyError("Failed to copy screenshot to clipboard.");
                    root.closeRequested();
                }
            });
        });
    }

    function performCopyAndSave() {
        withExport((tempOut) => {
            copyFileToClipboard(tempOut, (stdout, exitCode) => {
                if (exitCode === 0) {
                    saveFile(tempOut, (saveOut, saveCode, saveDir) => {
                        if (saveCode === 0) {
                            notifyInfo("Screenshot copied to clipboard and saved to " + saveDir);
                        } else {
                            notifyWarning("Screenshot copied to clipboard but failed to save file.");
                        }
                        root.closeRequested();
                    });
                } else {
                    notifyError("Failed to copy screenshot to clipboard.");
                    root.closeRequested();
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
}
