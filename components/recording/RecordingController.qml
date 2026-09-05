import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import "../core/Helpers.js" as Helpers

Item {
    id: root

    property var daemon: null
    property var pluginData: daemon ? daemon.pluginData : ({})

    property bool isRecording: false
    property bool isPaused: false
    property bool isProcessing: false
    property int recordingSeconds: 0
    property string outputPath: ""
    property string recordingState: "idle" // "idle", "starting", "recording", "paused"
    property bool isCancelling: false
    property string activeRecordingMode: "" // "screen", "region", "portal"
    property int regionX: 0
    property int regionY: 0
    property int regionW: 0
    property int regionH: 0
    property string regionGeometry: ""
    property int _recordedAudioCount: 0

    // Settings preferences
    property string targetGifPath: ""
    readonly property string outputDirectory: pluginData.recordingDirectory || "~/Videos/Recordings"
    readonly property string recordingScreenTarget: pluginData.recordingScreenTarget || "screen"
    readonly property string videoFormat: pluginData.recordingFormat || "mp4"
    readonly property int framerate: parseInt(pluginData.recordingFramerate, 10) || 60
    readonly property int gifFramerate: parseInt(pluginData.recordingGifFramerate, 10) || 15
    readonly property string videoQuality: pluginData.recordingQuality || "medium"
    readonly property string videoCodec: pluginData.recordingCodec || "auto"
    readonly property bool showCursor: pluginData.recordCursor !== false
    readonly property bool recordAudio: pluginData.recordSystemAudio ?? true
    readonly property bool recordMic: pluginData.recordMic ?? false
    readonly property string systemAudioDevice: pluginData.systemAudioDevice || "default_output"
    readonly property string micDevice: pluginData.micDevice || "default_input"
    readonly property string audioCodec: pluginData.audioCodec || "opus"
    readonly property bool showRegionBorder: pluginData.showRegionBorder !== false
    property var screenLayouts: ({})

    property var audioInputsList: [{"label": I18n.trFor("quickCapture", "Default Microphone"), "value": "default_input"}]
    property var audioOutputsList: [{"label": I18n.trFor("quickCapture", "Default Output"), "value": "default_output"}]

    property bool gpuScreenRecorderMissing: false

    function formatDuration(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function parseGeometryToGsr(geoStr) {
        if (!geoStr) return "";
        const m = geoStr.trim().match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)/);
        if (m) {
            const x = m[1];
            const y = m[2];
            const w = m[3];
            const h = m[4];
            return `${w}x${h}+${x}+${y}`;
        }
        return "";
    }

    function setRegionFromOutput(geoStr) {
        if (!geoStr) return;
        const m = geoStr.trim().match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)/);
        if (m) {
            root.regionX = parseInt(m[1], 10) || 0;
            root.regionY = parseInt(m[2], 10) || 0;
            root.regionW = parseInt(m[3], 10) || 0;
            root.regionH = parseInt(m[4], 10) || 0;
            root.regionGeometry = `${root.regionW}x${root.regionH}+${root.regionX}+${root.regionY}`;
        }
    }

    function setRegionFromCustom(geomStr) {
        if (!geomStr) return;
        const trimmed = geomStr.trim();
        let match = trimmed.match(/^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)/);
        if (match) {
            root.regionW = parseInt(match[1], 10) || 0;
            root.regionH = parseInt(match[2], 10) || 0;
            root.regionX = parseInt(match[3], 10) || 0;
            root.regionY = parseInt(match[4], 10) || 0;
            root.regionGeometry = trimmed;
            return;
        }
        match = trimmed.match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)/);
        if (match) {
            root.regionX = parseInt(match[1], 10) || 0;
            root.regionY = parseInt(match[2], 10) || 0;
            root.regionW = parseInt(match[3], 10) || 0;
            root.regionH = parseInt(match[4], 10) || 0;
            root.regionGeometry = `${root.regionW}x${root.regionH}+${root.regionX}+${root.regionY}`;
        }
    }

    function clearRegion() {
        root.regionX = 0;
        root.regionY = 0;
        root.regionW = 0;
        root.regionH = 0;
        root.regionGeometry = "";
    }

    function getResolvedDir() {
        let dir = root.outputDirectory;
        if (dir.startsWith("~/")) {
            const home = Quickshell.env("HOME") || "/tmp";
            dir = home + dir.substring(1);
        }
        return dir;
    }

    function getTimestampString() {
        const now = new Date();
        const pad = n => (n < 10 ? "0" : "") + n;
        return now.getFullYear() + "-" +
               pad(now.getMonth() + 1) + "-" +
               pad(now.getDate()) + "_" +
               pad(now.getHours()) + "-" +
               pad(now.getMinutes()) + "-" +
               pad(now.getSeconds());
    }

    Process {
        id: binaryCheck
        command: ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1"]
        running: true
        onExited: exitCode => {
            root.gpuScreenRecorderMissing = (exitCode !== 0);
        }
    }

    Timer {
        id: recordTimer
        interval: 1000
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: {
            root.recordingSeconds += 1;
        }
    }

    Timer {
        id: fileCheckTimer
        interval: 250
        repeat: true
        running: root.recordingState === "starting"
        onTriggered: {
            if (root.outputPath !== "") {
                Proc.runCommand("check-recording-file", ["sh", "-c", `test -f "${root.outputPath}" && test $(stat -c %s "${root.outputPath}" 2>/dev/null || echo 0) -gt 0`], (stdout, exitCode) => {
                    if (exitCode === 0 && root.recordingState === "starting") {
                        fileCheckTimer.stop();
                        safetyTimer.stop();
                        root.recordingState = "recording";
                        root.isRecording = true;
                        root.isPaused = false;
                        root.recordingSeconds = 0;
                    }
                });
            }
        }
    }

    Timer {
        id: safetyTimer
        interval: 20000
        repeat: false
        onTriggered: {
            if (root.recordingState === "starting") {
                root.cancelRecording();
                root.sendNotification(I18n.trFor("quickCapture", "Screen recording timed out or was cancelled."), true);
            }
        }
    }

    Process {
        id: recorderProcess
        running: false
        onStarted: {
            fileCheckTimer.restart();
        }
        onExited: exitCode => {
            fileCheckTimer.stop();
            safetyTimer.stop();

            const wasCancelling = root.isCancelling;
            const finishedPath = root.outputPath;
            const gifTarget = root.targetGifPath;

            root.isRecording = false;
            root.isPaused = false;
            root.recordingState = (gifTarget && !wasCancelling && (exitCode === 0 || exitCode === 130)) ? "processing" : "idle";
            root.isProcessing = (root.recordingState === "processing");
            root.isCancelling = false;
            root.activeRecordingMode = "";
            root.clearRegion();

            if (wasCancelling) {
                if (finishedPath) {
                    Proc.runCommand("cleanup-cancelled-recording", ["rm", "-f", finishedPath]);
                }
                if (gifTarget) {
                    Proc.runCommand("cleanup-cancelled-gif", ["rm", "-f", gifTarget]);
                }
                root.targetGifPath = "";
                return;
            }

            if (exitCode === 0 || exitCode === 130) {
                root.finalizeRecording(finishedPath, gifTarget);
            } else {
                root.sendNotification(I18n.trFor("quickCapture", "Recording ended with error code %1.").arg(exitCode), true);
                if (finishedPath) {
                    Proc.runCommand("cleanup-failed-recording", ["rm", "-f", finishedPath]);
                }
                root.targetGifPath = "";
            }
        }
    }

    function startRecording(mode, customGeometry) {
        if (root.isRecording || root.recordingState !== "idle") return;

        if (root.gpuScreenRecorderMissing) {
            root.sendNotification(I18n.trFor("quickCapture", "gpu-screen-recorder is not installed. Please install it first."), true);
            return;
        }

        const targetMode = mode || "screen";

        if (targetMode === "region" && !customGeometry) {
            root.refreshScreenLayouts(() => {
                Proc.runCommand("dms-region-geom", ["dms", "screenshot", "-g", "--no-confirm"], (stdout, exitCode) => {
                    if (exitCode === 0 && stdout && stdout.trim()) {
                        root.setRegionFromOutput(stdout);
                        if (root.regionGeometry) {
                            root.executeRecordingProcess("region", root.regionGeometry);
                        }
                    }
                });
            });
            return;
        }

        if (targetMode === "region" && customGeometry) {
            root.refreshScreenLayouts(() => {
                root.setRegionFromCustom(customGeometry);
                root.executeRecordingProcess(targetMode, root.regionGeometry || customGeometry || "");
            });
            return;
        }

        root.executeRecordingProcess(targetMode, root.regionGeometry || customGeometry || "");
    }

    function executeRecordingProcess(activeMode, geom) {
        const resolvedDir = root.getResolvedDir();

        Proc.runCommand("screenRecorder.mkdir", ["mkdir", "-p", resolvedDir], () => {
            const isGif = root.videoFormat === "gif";
            if (isGif) {
                root.targetGifPath = resolvedDir + "/recording_" + root.getTimestampString() + ".gif";
                root.outputPath = "/tmp/dms_rec_tmp_" + Date.now() + ".mp4";
            } else {
                root.targetGifPath = "";
                root.outputPath = resolvedDir + "/recording_" + root.getTimestampString() + "." + root.videoFormat;
            }

            let source = "screen";
            if (activeMode === "window" || activeMode === "portal") {
                source = "portal";
            } else if (activeMode === "region") {
                source = "region";
            } else if (activeMode === "screen") {
                const target = root.recordingScreenTarget;
                if (target === "focused") {
                    const focused = CompositorService.getFocusedScreen();
                    source = (focused && focused.name) ? focused.name : "screen";
                } else if (target && target !== "screen") {
                    source = target;
                } else {
                    source = "screen";
                }
            }

            const args = ["gpu-screen-recorder", "-w", source];
            if (activeMode === "region" && geom) {
                args.push("-region", geom);
            }

            const fps = isGif ? Math.min(root.framerate, root.gifFramerate) : root.framerate;
            args.push("-f", fps.toString(), "-o", root.outputPath);
            args.push("-cursor", root.showCursor ? "yes" : "no");

            let hasAudio = false;
            let audioCount = 0;
            if (!isGif) {
                if (root.recordAudio) {
                    args.push("-a", root.systemAudioDevice || "default_output");
                    hasAudio = true;
                    audioCount++;
                }
                if (root.recordMic) {
                    args.push("-a", root.micDevice || "default_input");
                    hasAudio = true;
                    audioCount++;
                }
                if (hasAudio) {
                    args.push("-ac", root.audioCodec);
                }
            }
            root._recordedAudioCount = audioCount;

            args.push("-q", root.videoQuality);

            if (root.videoCodec !== "auto") {
                args.push("-k", root.videoCodec);
            }

            recorderProcess.command = args;
            recorderProcess.running = true;

            root.recordingState = "starting";
            root.activeRecordingMode = activeMode;

            safetyTimer.interval = (activeMode === "portal" || activeMode === "window") ? 120000 : 20000;
            safetyTimer.restart();
        });
    }

    function pauseRecording() {
        if (!root.isRecording) return;
        root.isPaused = !root.isPaused;
        root.recordingState = root.isPaused ? "paused" : "recording";
        Proc.runCommand("screenRecorder.signal", ["killall", "-SIGUSR2", "gpu-screen-recorder"]);
    }

    function stopRecording() {
        if (!root.isRecording && root.recordingState !== "starting") return;
        root.recordingState = "stopping";
        Proc.runCommand("screenRecorder.stop", ["killall", "-INT", "gpu-screen-recorder"]);
        safetyTimer.restart();
    }

    function cancelRecording() {
        if (root.recordingState === "idle") return;
        root.isCancelling = true;
        safetyTimer.stop();
        fileCheckTimer.stop();
        root.recordingState = "idle";
        root.isRecording = false;
        root.isPaused = false;
        root.isProcessing = false;
        root.activeRecordingMode = "";
        root.clearRegion();
        if (root.targetGifPath) {
            Proc.runCommand("cleanup-cancelled-gif", ["rm", "-f", root.targetGifPath]);
            root.targetGifPath = "";
        }
        Proc.runCommand("screenRecorder.kill", ["killall", "-KILL", "gpu-screen-recorder"]);
    }

    function _mergeAudio(videoPath, callback) {
        root.isProcessing = true;
        root.recordingState = "processing";
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(I18n.trFor("quickCapture", "Merging audio tracks..."));
        }
        const ext = root.videoFormat;
        const tempOut = videoPath + ".audio_merged." + ext;

        const ffmpegArgs = ["ffmpeg", "-y", "-i", videoPath,
            "-filter_complex", "[0:a:0]anull[a0];[0:a:1]anull[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]",
            "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", tempOut];

        Proc.runCommand("quickCapture.mergeAudio", ffmpegArgs, (stdout, exitCode) => {
            if (exitCode === 0) {
                Proc.runCommand("quickCapture.replaceMerged", ["mv", "-f", tempOut, videoPath], () => {
                    root.isProcessing = false;
                    root.recordingState = "idle";
                    if (callback) callback();
                });
            } else {
                Proc.runCommand("quickCapture.cleanupTemp", ["rm", "-f", tempOut]);
                root.isProcessing = false;
                root.recordingState = "idle";
                if (callback) callback();
            }
        });
    }

    function finalizeRecording(videoPath, gifTarget) {
        if (!videoPath) return;
        const durationSecs = root.recordingSeconds;
        root.recordingSeconds = 0;
        root.targetGifPath = "";

        if (gifTarget) {
            root.isProcessing = true;
            root.recordingState = "processing";
            if (typeof ToastService !== "undefined" && ToastService) {
                ToastService.showInfo(I18n.trFor("quickCapture", "Converting recording to GIF..."));
            }

            const gifFps = root.gifFramerate;
            const gifFilter = `fps=${gifFps},split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5`;
            const gifArgs = ["ffmpeg", "-y", "-i", videoPath, "-vf", gifFilter, gifTarget];

            Proc.runCommand("convert-to-gif", gifArgs, (convOut, convCode) => {
                Proc.runCommand("cleanup-temp-mp4", ["rm", "-f", videoPath]);
                root.isProcessing = false;
                root.recordingState = "idle";

                if (convCode !== 0) {
                    root.sendNotification(I18n.trFor("quickCapture", "Failed to convert recording to GIF."), true);
                    return;
                }

                root.extractThumbnailAndNotify(gifTarget, durationSecs);
            });
            return;
        }

        if (root._recordedAudioCount > 1) {
            root._mergeAudio(videoPath, () => {
                root._recordedAudioCount = 1;
                root.extractThumbnailAndNotify(videoPath, durationSecs);
            });
            return;
        }

        root.extractThumbnailAndNotify(videoPath, durationSecs);
    }

    function extractThumbnailAndNotify(targetPath, durationSecs) {
        const thumbPath = "/tmp/dms_recording_thumb_" + Date.now() + ".png";
        const ffmpegArgs = ["ffmpeg", "-y"];
        if (durationSecs >= 1) {
            ffmpegArgs.push("-ss", "00:00:01");
        }
        ffmpegArgs.push("-i", targetPath, "-vf", "crop='min(iw,ih)':'min(iw,ih)',scale='min(256,iw)':'min(256,ih)'", "-vframes", "1", thumbPath);
        Proc.runCommand("extract-thumb", ffmpegArgs, (stdout, exitCode) => {
            const icon = (exitCode === 0) ? thumbPath : "video-x-generic";
            const durationStr = root.formatDuration(durationSecs);
            const filename = targetPath.split("/").pop();
            const msg = I18n.trFor("quickCapture", "Saved %1 (%2)").arg(filename).arg(durationStr);
            root.sendNotification(msg, false, icon, targetPath);
        });
    }

    function sendNotification(message, isError, iconPath, videoPath) {
        const title = isError ? I18n.trFor("quickCapture", "Screen Recording Error") : I18n.trFor("quickCapture", "Screen Recording Saved");
        if (isError || !videoPath) {
            const errIcon = iconPath || (isError ? "error" : "video-x-generic");
            const args = ["notify-send", "-a", "Quick Capture", "-i", errIcon, title, message];
            if (isError) args.push("-u", "critical");
            Proc.runCommand("recording-notify", args);
            return;
        }

        const icon = iconPath || "video-x-generic";
        const args = ["notify-send", "-a", "Quick Capture", "-i", icon];
        if (iconPath && iconPath.startsWith("/")) {
            args.push("-h", "string:image-path:file://" + iconPath);
        }
        args.push(
            "-A", "open=" + I18n.trFor("quickCapture", "Open"),
            "-A", "folder=" + I18n.trFor("quickCapture", "Open Folder"),
            "-t", "5000",
            title,
            message
        );

        Proc.runCommand("recording-notify", args, (stdout, exitCode) => {
            const action = stdout ? stdout.trim() : "";
            if (action === "open") {
                Proc.runCommand("open-recording-video", ["xdg-open", videoPath]);
            } else if (action === "folder") {
                const folderPath = videoPath.substring(0, videoPath.lastIndexOf("/"));
                Proc.runCommand("open-recording-folder", ["xdg-open", folderPath || "."]);
            }
        });
    }

    function refreshAudioDevices() {
        Proc.runCommand("screenRecorder.listAudioDevices", ["gpu-screen-recorder", "--list-audio-devices"], (stdout, exitCode) => {
            const inputs = [{"label": I18n.trFor("quickCapture", "Default Microphone"), "value": "default_input"}];
            const outputs = [{"label": I18n.trFor("quickCapture", "Default Output"), "value": "default_output"}];

            if (exitCode === 0 && stdout) {
                const lines = stdout.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    const parts = line.split("|");
                    if (parts.length >= 2) {
                        const name = parts[0];
                        const label = parts[1];
                        if (name.includes(".monitor") || name.includes("output") || name === "default_output") {
                            if (name !== "default_output") {
                                outputs.push({ "label": label, "value": name });
                            }
                        } else {
                            if (name !== "default_input") {
                                inputs.push({ "label": label, "value": name });
                            }
                        }
                    }
                }
            }
            root.audioInputsList = inputs;
            root.audioOutputsList = outputs;
        });
    }

    function refreshScreenLayouts(callback) {
        Proc.runCommand("dms-screen-list", ["dms", "screenshot", "list"], (stdout, exitCode) => {
            if (exitCode === 0 && stdout) {
                const layouts = {};
                const lines = stdout.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i].trim();
                    if (!line) continue;
                    const m = line.match(/^([^:]+):\s+(\d+)x(\d+)\+(-?\d+)\+(-?\d+)(?:\s+scale=([0-9.]+))?/);
                    if (m) {
                        const name = m[1].trim();
                        layouts[name] = {
                            name: name,
                            physW: parseInt(m[2], 10),
                            physH: parseInt(m[3], 10),
                            x: parseInt(m[4], 10),
                            y: parseInt(m[5], 10),
                            scale: m[6] ? parseFloat(m[6]) : 1.0
                        };
                    }
                }
                root.screenLayouts = layouts;
            }
            if (callback) callback();
        });
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            root.refreshScreenLayouts();
        }
    }

    Component.onCompleted: {
        root.refreshAudioDevices();
        root.refreshScreenLayouts();
    }
}
