import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import "./components/bar"
import "./components/core/Defaults.js" as Defaults

PluginComponent {
    id: root

    pluginId: "quickCapture"
    pluginService: PluginService

    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null
    readonly property var recorder: daemon?.recordingController ?? null
    readonly property bool isRecording: daemon?.isRecording ?? false
    readonly property bool isPaused: recorder?.isPaused ?? false
    readonly property bool isActive: daemon ? (daemon.isCapturing || daemon.isAnnotating) : false
    readonly property bool isDownloading: daemon?.isDownloading ?? false
    readonly property string widgetMode: daemon?.widgetMode ?? "photo"
    readonly property bool blinkRecordDot: Defaults.get(pluginData, "blinkRecordDot")
    readonly property string durationText: recorder ? recorder.formatDuration(recorder.recordingSeconds) : "00:00"
    readonly property alias config: captureConfig

    property var pendingPopoutAction: null

    CaptureConfig {
        id: captureConfig
        pluginData: root.pluginData
    }

    Timer {
        id: popoutCloseTimer
        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        onTriggered: {
            const action = root.pendingPopoutAction;
            root.pendingPopoutAction = null;
            if (action)
                action();
        }
    }

    function runAfterPopoutClosed(action) {
        root.pendingPopoutAction = action;
        root.closePopout();
        popoutCloseTimer.restart();
    }

    function setWidgetMode(mode) {
        if (root.daemon)
            root.daemon.widgetMode = mode;
    }

    function runDefaultAction(settingKey) {
        if (!root.daemon)
            return;
        if (root.widgetMode === "video") {
            root.daemon.record("region");
            return;
        }
        root.daemon.capture(Defaults.get(pluginData, settingKey), "edit");
    }

    popoutWidth: 260
    popoutHeight: root.widgetMode === "video" ? (root.isRecording ? 320 : 290) : 445 + Math.min((root.daemon?.outputs ?? []).length, 5) * 32

    popoutContent: Component {
        CaptureMenu {
            widget: root
        }
    }

    horizontalBarPill: Component {
        CapturePill {
            widget: root
        }
    }

    verticalBarPill: Component {
        CapturePill {
            widget: root
            vertical: true
        }
    }

    pillRightClickAction: function () {
        if (!root.daemon)
            return;
        if (root.isRecording) {
            root.recorder.cancelRecording();
            return;
        }
        root.runDefaultAction("rightClickAction");
    }

    ccWidgetIcon: root.isRecording ? "videocam" : "screenshot_region"
    ccWidgetPrimaryText: root.isRecording ? I18n.trFor("quickCapture", "Recording...") : (root.widgetMode === "video" ? I18n.trFor("quickCapture", "Screen Recording") : I18n.trFor("quickCapture", "Quick Capture"))
    ccWidgetSecondaryText: {
        if (root.isRecording)
            return root.durationText;
        if (!root.isActive)
            return I18n.trFor("quickCapture", "Ready");
        return root.daemon.isCapturing ? I18n.trFor("quickCapture", "Capturing...") : I18n.trFor("quickCapture", "Annotating");
    }
    ccWidgetIsActive: root.isActive || root.isRecording
    onCcWidgetToggled: {
        if (root.isRecording) {
            root.recorder.stopRecording();
            return;
        }
        root.runDefaultAction("middleClickAction");
    }
    ccDetailHeight: 240

    ccDetailContent: Component {
        CaptureDetail {
            widget: root
        }
    }
}
