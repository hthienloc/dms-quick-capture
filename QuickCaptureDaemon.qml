import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Modals.Common
import qs.Modals.FileBrowser
import "./components/core"
import "./components/floating"
import "./components/history"
import "./components/recording"
import "./components/core/Defaults.js" as Defaults

PluginComponent {
    id: root

    pluginId: "quickCapture"
    pluginService: PluginService

    readonly property alias recordingController: recorder
    readonly property alias actions: captureActions
    readonly property bool isRecording: recorder.isRecording
    readonly property bool isAnnotating: modal.shouldBeVisible
    readonly property var allowedModes: ["region", "window", "full", "output", "all", "last", "scroll"]
    readonly property int captureTimeoutMs: 60000
    readonly property int scrollCaptureTimeoutMs: 120000

    property string widgetMode: "photo"
    property bool isCapturing: false
    property bool isDownloading: false
    property bool hideControlCenter: Defaults.get(pluginData, "defaultHideControlCenter")
    property var outputs: []
    property string currentCapturePath: ""

    property string pendingCaptureAction: "edit"
    property string pendingCaptureMode: ""
    property string pendingOutputName: ""
    property bool waitingForControlCenterClose: false

    function savePluginData(key, value) {
        pluginService.savePluginData(pluginId, key, value);
    }

    function refreshAudioDevices() {
        recorder.refreshAudioDevices();
    }

    function refreshOutputs(callback) {
        Proc.runCommand("quickCapture.listOutputs", [Proc.dmsBin, "screenshot", "list"], (stdout, exitCode) => {
            const list = [];
            for (const line of (stdout || "").trim().split("\n")) {
                const m = line.match(/^([^:]+):\s+(\d+)x(\d+)/);
                if (!m)
                    continue;
                list.push({
                    name: m[1].trim(),
                    width: parseInt(m[2], 10),
                    height: parseInt(m[3], 10)
                });
            }
            root.outputs = list;
            if (callback)
                callback(list);
        });
    }

    function capture(mode, action, outputName) {
        switch (mode) {
        case "clipboard":
            fromClipboard(action);
            return;
        case "selectFile":
            selectImage(action);
            return;
        default:
            triggerCapture(mode, action, outputName);
        }
    }

    function record(mode, geometry) {
        closeControlCenter();
        recorder.startRecording(mode || "screen", geometry || "");
    }

    function openFolder(kind) {
        const key = kind === "video" ? "recordingDirectory" : "saveDirectory";
        Proc.runCommand("quickCapture.openFolder", ["xdg-open", Paths.expandTilde(String(Defaults.get(pluginData, key)))]);
    }

    function toggleHideControlCenter() {
        root.hideControlCenter = !root.hideControlCenter;
    }

    function closeControlCenter() {
        PopoutService.closeControlCenter();
    }

    function capturePath() {
        return "/tmp/dms_capture_" + Date.now() + ".png";
    }

    function modeFlags(mode) {
        const flags = [];
        if (mode === "region" && Defaults.get(pluginData, "skipConfirm"))
            flags.push("--no-confirm");
        if (mode === "scroll")
            flags.push("--interval", String(parseInt(Defaults.get(pluginData, "scrollInterval"), 10) || Defaults.values.scrollInterval));
        if (mode === "output")
            flags.push("--output", root.pendingOutputName || Defaults.get(pluginData, "outputTargetName") || "DP-1");
        if (Defaults.get(pluginData, "resetLastRegion"))
            flags.push("--reset");
        return flags;
    }

    function screenshotArgs(mode, filename) {
        const cursor = Defaults.get(pluginData, "includeCursor") ? "on" : "off";
        return [Proc.dmsBin, "screenshot", mode, "--no-clipboard", "--dir", "/tmp", "--filename", filename, "--format", "png", "--cursor", cursor, "--no-notify", "--json"].concat(modeFlags(mode));
    }

    function triggerCapture(mode, action, outputName) {
        const finalMode = mode || Defaults.get(pluginData, "middleClickAction");
        if (!root.allowedModes.includes(finalMode)) {
            console.warn("quickCapture: rejected screenshot mode", finalMode);
            return;
        }
        if (root.isCapturing || modal.shouldBeVisible)
            return;

        root.isCapturing = true;
        root.pendingCaptureAction = action || "edit";
        root.pendingCaptureMode = finalMode;
        root.pendingOutputName = outputName || "";

        if (!root.hideControlCenter) {
            startActualCapture();
            return;
        }
        closeControlCenter();
        root.waitingForControlCenterClose = true;
        captureDelayTimer.start();
    }

    function startCaptureAfterControlCenterClose() {
        if (!root.waitingForControlCenterClose)
            return;
        root.waitingForControlCenterClose = false;
        captureDelayTimer.stop();
        startActualCapture();
    }

    function startActualCapture() {
        root.waitingForControlCenterClose = false;
        const mode = root.pendingCaptureMode;
        const action = root.pendingCaptureAction;
        const timeout = mode === "scroll" ? root.scrollCaptureTimeoutMs : root.captureTimeoutMs;

        root.currentCapturePath = capturePath();
        const filename = root.currentCapturePath.split("/").pop();
        Proc.runCommand("quickCapture.screenshot", screenshotArgs(mode, filename), (stdout, exitCode) => {
            root.isCapturing = false;
            root.pendingCaptureMode = "";
            root.pendingCaptureAction = "edit";
            root.pendingOutputName = "";
            const fallback = I18n.trFor("quickCapture", "Screenshot failed (mode: %1).").arg(mode);
            let meta = null;
            try {
                meta = JSON.parse((stdout || "").trim());
            } catch (e) {
                captureActions.notifyError((stdout && stdout.trim()) || fallback);
                return;
            }
            if (meta.status === "success") {
                root.currentCapturePath = meta.path;
                openCaptured(meta.path, action, meta.width, meta.height);
                return;
            }
            if (meta.status !== "aborted")
                captureActions.notifyError(meta.message || meta.error || fallback);
        }, 0, timeout);
    }

    function selectImage(action) {
        closeControlCenter();
        fileBrowserModal.captureAction = action || "edit";
        fileBrowserModal.open();
    }

    function fromClipboard(action) {
        closeControlCenter();
        const destPath = capturePath();
        root.currentCapturePath = destPath;
        Proc.runCommand("quickCapture.clipboardPasteFile", ["sh", "-c", '"$1" cl paste > "$2" 2>/dev/null', "_", Proc.dmsBin, destPath], (stdout, exitCode) => {
            if (exitCode !== 0) {
                tryClipboardAsText(action);
                return;
            }
            Proc.runCommand("quickCapture.clipboardCheckImage", ["file", "-b", destPath], (fileOut, fileExit) => {
                if (fileExit === 0 && fileOut.toLowerCase().includes("image")) {
                    validateAndOpen(destPath, action);
                    return;
                }
                tryClipboardAsText(action);
            });
        });
    }

    function tryClipboardAsText(action) {
        Proc.runCommand("quickCapture.clipboardPasteText", [Proc.dmsBin, "cl", "paste"], (stdout, exitCode) => {
            const text = (stdout || "").trim();
            if (exitCode !== 0 || text === "") {
                captureActions.notifyWarning(I18n.trFor("quickCapture", "No valid image, URL, or path in clipboard."));
                return;
            }
            loadImageFromUri(text, action);
        });
    }

    function openCaptured(path, action, width, height) {
        const minSize = Defaults.get(pluginData, "minImageSize");
        if (width < minSize || height < minSize) {
            captureActions.notifyWarning(I18n.trFor("quickCapture", "Image is too small (%1×%2). Minimum: %3px").arg(width).arg(height).arg(minSize));
            return;
        }
        openAction(path, action);
    }

    function validateAndOpen(path, action) {
        Proc.runCommand("quickCapture.validateImage", ["file", "-b", path], (stdout, exitCode) => {
            const output = (stdout || "").toLowerCase();
            if (exitCode !== 0 || output.includes("empty") || !output.includes("image")) {
                captureActions.notifyError(I18n.trFor("quickCapture", "Invalid or corrupted image file."));
                return;
            }
            openAction(path, action);
        });
    }

    function openAction(path, action) {
        switch (action) {
        case "float":
            floatServiceItem.spawnWindow("file://" + path, null, [path]);
            return;
        case "copy":
            captureActions.copyImage(path, () => captureActions.cleanupTemp(path));
            return;
        case "save":
            captureActions.saveImage(path, () => captureActions.cleanupTemp(path));
            return;
        case "copyAndSave":
            captureActions.copyAndSaveImage(path, () => captureActions.cleanupTemp(path));
            return;
        default:
            closeControlCenter();
            modal.currentCapturePath = path;
            modal.shouldBeVisible = true;
            modal.open();
        }
    }

    function loadImageFromUri(uri, action) {
        if (uri.startsWith("file://"))
            uri = uri.substring(7);
        root.currentCapturePath = capturePath();

        if (uri.startsWith("http://") || uri.startsWith("https://")) {
            root.isDownloading = true;
            Proc.runCommand("quickCapture.download", ["curl", "-s", "-L", "-o", root.currentCapturePath, uri], (stdout, exitCode) => {
                root.isDownloading = false;
                if (exitCode !== 0) {
                    captureActions.notifyError(I18n.trFor("quickCapture", "Failed to download image."));
                    return;
                }
                validateAndOpen(root.currentCapturePath, action);
            });
            return;
        }

        Proc.runCommand("quickCapture.copyImage", ["cp", "-f", "--", uri, root.currentCapturePath], (stdout, exitCode) => {
            if (exitCode !== 0) {
                captureActions.notifyError(I18n.trFor("quickCapture", "Failed to load image: %1").arg(uri));
                return;
            }
            validateAndOpen(root.currentCapturePath, action);
        });
    }

    function handleDrop(drop) {
        let url = "";
        if (drop.hasUrls && drop.urls.length > 0)
            url = drop.urls[0].toString();
        else if (drop.hasText && /^https?:\/\//.test(drop.text.trim()))
            url = drop.text.trim();

        if (url === "") {
            captureActions.notifyWarning(I18n.trFor("quickCapture", "No valid image file or URL found in drop."));
            return;
        }
        loadImageFromUri(url, "edit");
    }

    function showHistoryCarousel() {
        historyModal.shouldBeVisible = true;
        historyModal.open();
    }

    IpcHandler {
        target: "quickCapture"

        function screenshot(mode: string, action: string): string {
            root.triggerCapture(mode, action);
            return "SUCCESS";
        }

        function selectFile(action: string): string {
            root.selectImage(action);
            return "SUCCESS";
        }

        function fromClipboard(action: string): string {
            root.fromClipboard(action);
            return "SUCCESS";
        }

        function openImage(path: string, action: string): string {
            root.loadImageFromUri(path, action);
            return "SUCCESS";
        }

        function close(): string {
            modal.close();
            return "SUCCESS";
        }

        function showHistory(): string {
            root.showHistoryCarousel();
            return "SUCCESS";
        }

        function recordStart(mode: string, geometry: string): string {
            root.record(mode, geometry);
            return "SUCCESS";
        }

        function recordStop(): string {
            recorder.stopRecording();
            return "SUCCESS";
        }

        function recordPause(): string {
            recorder.pauseRecording();
            return "SUCCESS";
        }

        function recordCancel(): string {
            recorder.cancelRecording();
            return "SUCCESS";
        }

        function recordToggle(mode: string): string {
            if (recorder.isRecording) {
                recorder.stopRecording();
                return "STOPPED";
            }
            root.record(mode);
            return "STARTED";
        }

        function recordStatus(): string {
            return JSON.stringify({
                "recordingState": recorder.recordingState,
                "isRecording": recorder.isRecording,
                "isPaused": recorder.isPaused,
                "duration": recorder.recordingSeconds,
                "outputPath": recorder.outputPath
            });
        }
    }

    Timer {
        id: captureDelayTimer
        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        onTriggered: {
            if (root.waitingForControlCenterClose)
                root.startCaptureAfterControlCenterClose();
            else
                root.startActualCapture();
        }
    }

    Connections {
        target: PopoutService.controlCenterPopout
        function onPopoutClosed() {
            root.startCaptureAfterControlCenterClose();
        }
    }

    FloatService {
        id: floatServiceItem
        pluginData: root.pluginData
    }

    QuickCaptureActions {
        id: captureActions
        daemon: root
        modal: modal
        floatService: floatServiceItem
        exportAndExecute: callback => modal.exportAndExecute(callback)
        onCloseRequested: modal.discardAndClose()
    }

    QuickCaptureModal {
        id: modal
        parentWidget: root
        floatService: floatServiceItem
        actions: captureActions
    }

    FileBrowserModal {
        id: fileBrowserModal
        property string captureAction: "edit"
        browserTitle: I18n.trFor("quickCapture", "Select Image to Annotate")
        browserIcon: "image"
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp"]
        onFileSelected: path => {
            root.loadImageFromUri(path, fileBrowserModal.captureAction);
            close();
        }
    }

    DankModal {
        id: historyModal
        shouldBeVisible: false
        positioning: "center"
        enableShadow: true
        useOverlayLayer: true
        closeOnEscapeKey: true
        closeOnBackgroundClick: true
        onBackgroundClicked: close()

        readonly property real screenW: targetScreen ? targetScreen.width : (Quickshell.screens[0]?.width ?? 1920)
        readonly property real screenH: targetScreen ? targetScreen.height : (Quickshell.screens[0]?.height ?? 1080)
        readonly property real heightFraction: contentLoader?.item?.heightFraction ?? 0.45
        modalWidth: Math.round(screenW * 0.9)
        modalHeight: Math.round(screenH * heightFraction)

        content: Component {
            RecentEditsCarousel {
                daemon: root
                onCloseRequested: historyModal.close()
            }
        }
    }

    RecordingController {
        id: recorder
        daemon: root
    }

    RecordingRegionBorder {
        recordingController: recorder
    }
}
