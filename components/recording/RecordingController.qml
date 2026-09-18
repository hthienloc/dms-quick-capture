import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import "../core/Helpers.js" as Helpers
import "../core/Defaults.js" as Defaults

Item {
    id: root

    property var daemon: null
    readonly property var pluginData: daemon?.pluginData ?? ({})

    property bool isRecording: false
    property bool isPaused: false
    property bool isProcessing: false
    property int recordingSeconds: 0
    property string outputPath: ""
    property string targetGifPath: ""
    property string recordingState: "idle"
    property bool isCancelling: false
    property string activeRecordingMode: ""
    property int regionX: 0
    property int regionY: 0
    property int regionW: 0
    property int regionH: 0
    property string regionGeometry: ""
    property int recordedAudioCount: 0

    property string activeRecorderBin: ""
    readonly property bool isPauseSupported: activeRecorderBin !== "wf-recorder"
    property bool binariesProbed: false
    property bool hasGsr: false
    property bool hasWfRecorder: false

    property var audioInputsList: [
        {
            label: I18n.trFor("quickCapture", "Default Microphone"),
            value: "default_input"
        }
    ]
    property var audioOutputsList: [
        {
            label: I18n.trFor("quickCapture", "Default Output"),
            value: "default_output"
        }
    ]

    function setting(key) {
        return Defaults.get(root.pluginData, key);
    }

    readonly property string videoFormat: setting("recordingFormat")
    readonly property int framerate: parseInt(setting("recordingFramerate"), 10) || 60
    readonly property int gifFramerate: parseInt(setting("recordingGifFramerate"), 10) || 15
    readonly property bool recordAudio: setting("recordSystemAudio")
    readonly property bool recordMic: setting("recordMic")
    readonly property string systemAudioDevice: setting("systemAudioDevice")
    readonly property string micDevice: setting("micDevice")
    readonly property string recordingBackend: setting("recordingBackend")
    readonly property bool showRegionBorder: setting("showRegionBorder")

    function formatDuration(sec) {
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    function setRegion(x, y, w, h) {
        root.regionX = x;
        root.regionY = y;
        root.regionW = w;
        root.regionH = h;
        root.regionGeometry = `${w}x${h}+${x}+${y}`;
    }

    function setRegionFromGeometry(geomStr) {
        const trimmed = (geomStr || "").trim();
        let m = trimmed.match(/^(\d+)x(\d+)\+(-?\d+)\+(-?\d+)/);
        if (m) {
            setRegion(parseInt(m[3], 10) || 0, parseInt(m[4], 10) || 0, parseInt(m[1], 10) || 0, parseInt(m[2], 10) || 0);
            return;
        }
        m = trimmed.match(/^(-?\d+),(-?\d+)\s+(\d+)x(\d+)/);
        if (m)
            setRegion(parseInt(m[1], 10) || 0, parseInt(m[2], 10) || 0, parseInt(m[3], 10) || 0, parseInt(m[4], 10) || 0);
    }

    function clearRegion() {
        setRegion(0, 0, 0, 0);
        root.regionGeometry = "";
    }

    function probeBinaries(callback) {
        if (root.binariesProbed) {
            callback();
            return;
        }
        Proc.runCommand("quickCapture.probeRecorders", ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1 && echo gsr; command -v wf-recorder >/dev/null 2>&1 && echo wf"], stdout => {
            const out = stdout || "";
            root.hasGsr = out.includes("gsr");
            root.hasWfRecorder = out.includes("wf");
            root.binariesProbed = true;
            callback();
        });
    }

    function resolveRecorderBin() {
        switch (root.recordingBackend) {
        case "gpu-screen-recorder":
            return root.hasGsr ? "gpu-screen-recorder" : "";
        case "wf-recorder":
            return root.hasWfRecorder ? "wf-recorder" : "";
        default:
            if (root.hasGsr)
                return "gpu-screen-recorder";
            return root.hasWfRecorder ? "wf-recorder" : "";
        }
    }

    function missingRecorderName() {
        switch (root.recordingBackend) {
        case "gpu-screen-recorder":
            return "gpu-screen-recorder";
        case "wf-recorder":
            return "wf-recorder";
        default:
            return "gpu-screen-recorder / wf-recorder";
        }
    }

    Timer {
        id: recordTimer
        interval: 1000
        repeat: true
        running: root.isRecording && !root.isPaused
        onTriggered: root.recordingSeconds += 1
    }

    Timer {
        id: fileCheckTimer
        interval: 250
        repeat: true
        running: root.recordingState === "starting"
        onTriggered: {
            if (root.outputPath === "")
                return;
            Proc.runCommand("quickCapture.checkRecordingFile", ["sh", "-c", 'test -f "$1" && test $(stat -c %s "$1" 2>/dev/null || echo 0) -gt 0', "_", root.outputPath], (stdout, exitCode) => {
                if (exitCode !== 0 || root.recordingState !== "starting")
                    return;
                fileCheckTimer.stop();
                safetyTimer.stop();
                root.recordingState = "recording";
                root.isRecording = true;
                root.isPaused = false;
                root.recordingSeconds = 0;
            });
        }
    }

    Timer {
        id: safetyTimer
        interval: 20000
        onTriggered: {
            if (root.recordingState !== "starting")
                return;
            root.cancelRecording();
            root.sendNotification(I18n.trFor("quickCapture", "Screen recording timed out or was cancelled."), true);
        }
    }

    Process {
        id: recorderProcess
        running: false
        onStarted: fileCheckTimer.restart()
        onExited: exitCode => {
            fileCheckTimer.stop();
            safetyTimer.stop();

            const wasStarting = root.recordingState === "starting";
            const wasCancelling = root.isCancelling;
            const finishedPath = root.outputPath;
            const gifTarget = root.targetGifPath;
            const prevBin = root.activeRecorderBin;
            const prevMode = root.activeRecordingMode;
            const prevGeom = root.regionGeometry;
            const finishedOk = exitCode === 0 || exitCode === 130;

            root.isRecording = false;
            root.isPaused = false;
            root.recordingState = (gifTarget && !wasCancelling && finishedOk) ? "processing" : "idle";
            root.isProcessing = root.recordingState === "processing";
            root.isCancelling = false;
            root.activeRecordingMode = "";
            root.clearRegion();

            if (wasCancelling) {
                if (finishedPath)
                    Proc.runCommand("quickCapture.cleanupRecording", ["rm", "-f", "--", finishedPath]);
                if (gifTarget)
                    Proc.runCommand("quickCapture.cleanupGif", ["rm", "-f", "--", gifTarget]);
                root.targetGifPath = "";
                return;
            }

            if (finishedOk) {
                root.finalizeRecording(finishedPath, gifTarget);
                return;
            }

            if (wasStarting && prevBin === "gpu-screen-recorder" && root.recordingBackend === "auto" && root.hasWfRecorder) {
                root.sendNotification(I18n.trFor("quickCapture", "GPU encoder failed. Retrying with %1...").arg("wf-recorder (CPU)"), false);
                root.activeRecorderBin = "wf-recorder";
                root.executeRecordingProcess(prevMode, prevGeom);
                return;
            }

            root.sendNotification(I18n.trFor("quickCapture", "Recording ended with error code %1.").arg(exitCode), true);
            if (finishedPath)
                Proc.runCommand("quickCapture.cleanupRecording", ["rm", "-f", "--", finishedPath]);
            root.targetGifPath = "";
        }
    }

    function startRecording(mode, customGeometry) {
        if (root.isRecording || root.recordingState !== "idle")
            return;
        probeBinaries(() => {
            const bin = resolveRecorderBin();
            if (!bin) {
                root.sendNotification(I18n.trFor("quickCapture", "%1 is not installed").arg(missingRecorderName()), true);
                return;
            }
            root.activeRecorderBin = bin;
            const targetMode = mode || "screen";

            if (targetMode !== "region") {
                executeRecordingProcess(targetMode, customGeometry || "");
                return;
            }
            if (customGeometry) {
                setRegionFromGeometry(customGeometry);
                executeRecordingProcess("region", root.regionGeometry || customGeometry);
                return;
            }
            const geomArgs = [Proc.dmsBin, "screenshot", "-g"];
            if (setting("recordingSkipConfirm"))
                geomArgs.push("--no-confirm");
            const hudScale = setting("regionHudScale");
            if (hudScale && hudScale !== "auto")
                geomArgs.push("--hud", hudScale);
            Proc.runCommand("quickCapture.regionGeometry", geomArgs, (stdout, exitCode) => {
                if (exitCode !== 0 || !stdout?.trim())
                    return;
                setRegionFromGeometry(stdout);
                if (root.regionGeometry)
                    executeRecordingProcess("region", root.regionGeometry);
            });
        });
    }

    function screenSource() {
        const target = setting("recordingScreenTarget");
        if (target === "focused")
            return CompositorService.getFocusedScreen()?.name ?? "";
        return target === "screen" ? "" : target;
    }

    function wfRecorderArgs(activeMode, fps) {
        const args = ["wf-recorder", "-c", "libx264", "--no-dmabuf", "-x", "yuv420p", "-p", "preset=ultrafast", "-y"];
        if (activeMode === "region")
            args.push("-g", `${root.regionX},${root.regionY} ${root.regionW}x${root.regionH}`);
        const output = activeMode === "screen" ? screenSource() : "";
        if (output)
            args.push("-o", output);
        args.push("-r", fps.toString(), "-f", root.outputPath);
        root.recordedAudioCount = 0;
        return args;
    }

    function gsrArgs(activeMode, geom, fps, isGif) {
        let source = "screen";
        if (activeMode === "window" || activeMode === "portal")
            source = "portal";
        else if (activeMode === "region")
            source = "region";
        else if (activeMode === "screen")
            source = screenSource() || "screen";

        const args = ["gpu-screen-recorder", "-w", source];
        if (activeMode === "region" && geom)
            args.push("-region", geom);
        args.push("-f", fps.toString(), "-o", root.outputPath, "-cursor", setting("recordCursor") ? "yes" : "no");

        let audioCount = 0;
        if (!isGif) {
            if (root.recordAudio) {
                args.push("-a", root.systemAudioDevice);
                audioCount++;
            }
            if (root.recordMic) {
                args.push("-a", root.micDevice);
                audioCount++;
            }
            if (audioCount > 0)
                args.push("-ac", setting("audioCodec"));
        }
        root.recordedAudioCount = audioCount;

        args.push("-q", setting("recordingQuality"));
        const codec = setting("recordingCodec");
        if (codec !== "auto")
            args.push("-k", codec);
        return args;
    }

    function executeRecordingProcess(activeMode, geom) {
        const resolvedDir = Paths.expandTilde(String(setting("recordingDirectory")));
        Proc.runCommand("quickCapture.mkdirRecording", ["mkdir", "-p", resolvedDir], () => {
            const isGif = root.videoFormat === "gif";
            const baseName = resolvedDir + "/" + Helpers.expandDateTokens("recording_%Y-%m-%d_%H-%M-%S");
            if (isGif) {
                root.targetGifPath = baseName + ".gif";
                root.outputPath = "/tmp/dms_rec_tmp_" + Date.now() + ".mp4";
            } else {
                root.targetGifPath = "";
                root.outputPath = baseName + "." + root.videoFormat;
            }

            const fps = isGif ? Math.min(root.framerate, root.gifFramerate) : root.framerate;
            recorderProcess.command = root.activeRecorderBin === "wf-recorder" ? wfRecorderArgs(activeMode, fps) : gsrArgs(activeMode, geom, fps, isGif);
            recorderProcess.running = true;
            root.recordingState = "starting";
            root.activeRecordingMode = activeMode;
            safetyTimer.interval = (activeMode === "portal" || activeMode === "window") ? 120000 : 20000;
            safetyTimer.restart();
        });
    }

    function pauseRecording() {
        if (!root.isRecording)
            return;
        if (!root.isPauseSupported) {
            root.sendNotification(I18n.trFor("quickCapture", "Pausing is not supported with %1.").arg("wf-recorder"), true);
            return;
        }
        root.isPaused = !root.isPaused;
        root.recordingState = root.isPaused ? "paused" : "recording";
        Proc.runCommand("quickCapture.recorderSignal", ["killall", "-SIGUSR2", "gpu-screen-recorder"]);
    }

    function stopRecording() {
        if (!root.isRecording && root.recordingState !== "starting")
            return;
        root.recordingState = "stopping";
        Proc.runCommand("quickCapture.recorderStop", ["killall", "-INT", root.activeRecorderBin || "gpu-screen-recorder"]);
        safetyTimer.restart();
    }

    function cancelRecording() {
        if (root.recordingState === "idle")
            return;
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
            Proc.runCommand("quickCapture.cleanupGif", ["rm", "-f", "--", root.targetGifPath]);
            root.targetGifPath = "";
        }
        Proc.runCommand("quickCapture.recorderKill", ["killall", "-KILL", root.activeRecorderBin || "gpu-screen-recorder"]);
    }

    function mergeAudio(videoPath, callback) {
        root.isProcessing = true;
        root.recordingState = "processing";
        ToastService.showInfo(I18n.trFor("quickCapture", "Merging audio tracks..."));
        const tempOut = videoPath + ".audio_merged." + root.videoFormat;
        const ffmpegArgs = ["ffmpeg", "-y", "-i", videoPath, "-filter_complex", "[0:a:0]anull[a0];[0:a:1]anull[a1];[a0][a1]amix=inputs=2:duration=first:normalize=0[a]", "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", tempOut];

        const finish = () => {
            root.isProcessing = false;
            root.recordingState = "idle";
            callback();
        };
        Proc.runCommand("quickCapture.mergeAudio", ffmpegArgs, (stdout, exitCode) => {
            if (exitCode !== 0) {
                Proc.runCommand("quickCapture.cleanupMerge", ["rm", "-f", "--", tempOut]);
                finish();
                return;
            }
            Proc.runCommand("quickCapture.replaceMerged", ["mv", "-f", "--", tempOut, videoPath], finish);
        });
    }

    function finalizeRecording(videoPath, gifTarget) {
        if (!videoPath)
            return;
        const durationSecs = root.recordingSeconds;
        root.recordingSeconds = 0;
        root.targetGifPath = "";

        if (gifTarget) {
            root.isProcessing = true;
            root.recordingState = "processing";
            ToastService.showInfo(I18n.trFor("quickCapture", "Converting recording to GIF..."));
            const gifFilter = `fps=${root.gifFramerate},split[s0][s1];[s0]palettegen=stats_mode=diff[p];[s1][p]paletteuse=dither=bayer:bayer_scale=5`;
            Proc.runCommand("quickCapture.convertGif", ["ffmpeg", "-y", "-i", videoPath, "-vf", gifFilter, gifTarget], (convOut, convCode) => {
                Proc.runCommand("quickCapture.cleanupGifSource", ["rm", "-f", "--", videoPath]);
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

        if (root.recordedAudioCount > 1) {
            mergeAudio(videoPath, () => {
                root.recordedAudioCount = 1;
                root.extractThumbnailAndNotify(videoPath, durationSecs);
            });
            return;
        }
        root.extractThumbnailAndNotify(videoPath, durationSecs);
    }

    function extractThumbnailAndNotify(targetPath, durationSecs) {
        const thumbPath = "/tmp/dms_recording_thumb_" + Date.now() + ".png";
        const ffmpegArgs = ["ffmpeg", "-y"];
        if (durationSecs >= 1)
            ffmpegArgs.push("-ss", "00:00:01");
        ffmpegArgs.push("-i", targetPath, "-vf", "crop='min(iw,ih)':'min(iw,ih)',scale='min(256,iw)':'min(256,ih)'", "-vframes", "1", thumbPath);
        Proc.runCommand("quickCapture.thumbnail", ffmpegArgs, (stdout, exitCode) => {
            const icon = exitCode === 0 ? thumbPath : "video-x-generic";
            const filename = targetPath.split("/").pop();
            root.sendNotification(I18n.trFor("quickCapture", "Saved %1 (%2)").arg(filename).arg(formatDuration(durationSecs)), false, icon, targetPath);
        });
    }

    function sendNotification(message, isError, iconPath, videoPath) {
        const title = isError ? I18n.trFor("quickCapture", "Screen Recording Error") : I18n.trFor("quickCapture", "Screen Recording Saved");
        if (isError || !videoPath) {
            const args = ["notify-send", "-a", "Quick Capture", "-i", iconPath || (isError ? "error" : "video-x-generic"), title, message];
            if (isError)
                args.push("-u", "critical");
            Proc.runCommand("quickCapture.recordingNotify", args);
            return;
        }

        const args = ["notify-send", "-a", "Quick Capture", "-i", iconPath || "video-x-generic"];
        if (iconPath && iconPath.startsWith("/"))
            args.push("-h", "string:image-path:file://" + iconPath);
        args.push("-A", "open=" + I18n.trFor("quickCapture", "Open"), "-A", "folder=" + I18n.trFor("quickCapture", "Open folder"), "-t", "5000", title, message);

        Proc.runCommand("quickCapture.recordingNotify", args, stdout => {
            const action = (stdout || "").trim();
            if (action === "open") {
                Proc.runCommand("quickCapture.openRecording", ["xdg-open", videoPath]);
                return;
            }
            if (action === "folder")
                Proc.runCommand("quickCapture.openRecordingFolder", ["xdg-open", videoPath.substring(0, videoPath.lastIndexOf("/")) || "."]);
        });
    }

    function parseAudioDevices(stdout) {
        const inputs = [
            {
                label: I18n.trFor("quickCapture", "Default Microphone"),
                value: "default_input"
            }
        ];
        const outputs = [
            {
                label: I18n.trFor("quickCapture", "Default Output"),
                value: "default_output"
            }
        ];
        for (const rawLine of (stdout || "").trim().split("\n")) {
            const parts = rawLine.trim().split("|");
            if (parts.length < 2)
                continue;
            const name = parts[0];
            const isOutput = name.includes(".monitor") || name.includes("output") || name === "default_output";
            if (name === "default_output" || name === "default_input")
                continue;
            (isOutput ? outputs : inputs).push({
                label: parts[1],
                value: name
            });
        }
        root.audioInputsList = inputs;
        root.audioOutputsList = outputs;
    }

    function refreshAudioDevices() {
        Proc.runCommand("quickCapture.listAudioDevices", ["gpu-screen-recorder", "--list-audio-devices"], (stdout, exitCode) => {
            if (exitCode === 0 && stdout?.trim()) {
                parseAudioDevices(stdout);
                return;
            }
            Proc.runCommand("quickCapture.listAudioDevicesPactl", ["sh", "-c", "pactl list sources 2>/dev/null | awk '/Name: /{name=$2} /Description: /{desc=substr($0, index($0,$2)); print name \"|\" desc}'"], (pactlOut, pactlExit) => {
                parseAudioDevices(pactlExit === 0 ? pactlOut : "");
            });
        });
    }
}
