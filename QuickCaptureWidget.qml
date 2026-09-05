import "./dms-common"
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    // ── Resolve the daemon instance ───────────────────────────────────────────
    readonly property var daemon: PluginService.pluginInstances["quickCapture"] ?? null

    // ── Bar Pill appearance ───────────────────────────────────────────────────
    readonly property bool isActive: daemon ? (daemon.isCapturing || daemon.isAnnotating) : false
    readonly property bool isDownloading: daemon ? daemon.isDownloading : false
    readonly property bool blinkRecordDot: pluginData.blinkRecordDot ?? true
    readonly property bool showRecordingDot: pluginData.showRecordingDot ?? true
    readonly property bool showPillBorder: pluginData.showPillBorder ?? false
    readonly property int recordingIconSize: showPillBorder ? 12 : Theme.iconSizeSmall

    pluginId: "quickCapture"
    pluginService: PluginService

    readonly property string widgetMode: daemon ? daemon.widgetMode : internalWidgetMode
    property string internalWidgetMode: "photo"

    readonly property bool recordMic: (daemon && daemon.pluginData && daemon.pluginData.recordMic !== undefined)
        ? (daemon.pluginData.recordMic ?? false)
        : (pluginData.recordMic ?? false)
    readonly property bool recordSystemAudio: (daemon && daemon.pluginData && daemon.pluginData.recordSystemAudio !== undefined)
        ? (daemon.pluginData.recordSystemAudio ?? true)
        : (pluginData.recordSystemAudio ?? true)

    readonly property string systemAudioDevice: (daemon && daemon.pluginData && daemon.pluginData.systemAudioDevice !== undefined)
        ? (daemon.pluginData.systemAudioDevice || "default_output")
        : (pluginData.systemAudioDevice || "default_output")
    readonly property string micDevice: (daemon && daemon.pluginData && daemon.pluginData.micDevice !== undefined)
        ? (daemon.pluginData.micDevice || "default_input")
        : (pluginData.micDevice || "default_input")

    readonly property var audioInputsList: daemon && daemon.audioInputsList && daemon.audioInputsList.length > 0
        ? daemon.audioInputsList
        : [{"label": I18n.trFor("quickCapture", "Default Microphone"), "value": "default_input"}]
    readonly property var audioOutputsList: daemon && daemon.audioOutputsList && daemon.audioOutputsList.length > 0
        ? daemon.audioOutputsList
        : [{"label": I18n.trFor("quickCapture", "Default Output"), "value": "default_output"}]

    readonly property string currentMicLabel: {
        const list = root.audioInputsList;
        const val = root.micDevice;
        for (let i = 0; i < list.length; i++) {
            if (list[i].value === val) return list[i].label;
        }
        return val === "default_input" ? I18n.trFor("quickCapture", "Default Microphone") : val;
    }

    readonly property string currentAudioLabel: {
        const list = root.audioOutputsList;
        const val = root.systemAudioDevice;
        for (let i = 0; i < list.length; i++) {
            if (list[i].value === val) return list[i].label;
        }
        return val === "default_output" ? I18n.trFor("quickCapture", "Default Output") : val;
    }

    function savePluginData(key, value) {
        if (daemon && typeof daemon.savePluginData === "function") {
            daemon.savePluginData(key, value);
        }
        if (pluginService && pluginId) {
            pluginService.savePluginData(pluginId, key, value);
        }
        const pData = Object.assign({}, root.pluginData);
        pData[key] = value;
        root.pluginData = pData;
    }

    function setWidgetMode(mode) {
        if (widgetMode === mode) return;
        if (daemon) daemon.widgetMode = mode;
        internalWidgetMode = mode;
    }

    function switchWidgetMode() {
        setWidgetMode((widgetMode === "photo") ? "video" : "photo");
    }

    property bool outputExpanded: false
    property var outputList: []
    property var pendingPopoutAction: null

    Timer {
        id: popoutCloseTimer
        interval: Math.max(50, Theme.popoutAnimationDuration + 50)
        repeat: false
        onTriggered: {
            const action = root.pendingPopoutAction;
            root.pendingPopoutAction = null;
            if (action) action();
        }
    }

    function runAfterPopoutClosed(action) {
        root.pendingPopoutAction = action;
        root.closePopout();
        popoutCloseTimer.restart();
    }

    function execAction(action) {
        if (!root.daemon) return;
        if (root.widgetMode === "video") {
            const target = (action === "screen" || action === "window" || action === "portal" || action === "region") ? action : "region";
            root.daemon.startRecording(target);
            return;
        }
        if (action === "clipboard")
            root.daemon.fromClipboardWithAction("edit");
        else if (action === "selectFile")
            root.daemon.selectImageAndAnnotateWithAction("edit");
        else
            root.daemon.triggerCaptureWithAction(action, "edit");
    }

    function refreshOutputList() {
        Proc.runCommand("list-outputs", ["dms", "screenshot", "list"], (stdout) => {
            const list = [];
            for (const line of stdout.trim().split("\n")) {
                const m = line.match(/^(\S+):\s*(\d+x\d+)/);
                if (m) list.push({ label: m[1] + "  (" + m[2] + ")", value: m[1] });
            }
            outputList = list;
        });
    }

    // ── Popout (left-click menu) ──────────────────────────────────────────────
    popoutWidth: 260
    popoutHeight: root.widgetMode === "video"
        ? (root.daemon && root.daemon.isRecording ? 240 : 290)
        : (outputExpanded ? 445 + Math.min(outputList.length, 5) * 32 : 445)

    popoutContent: Component {
        PopoutComponent {
            width: root.popoutWidth
            headerText: I18n.trFor("quickCapture", "Quick Capture")
            showCloseButton: false
            closePopout: () => root.closePopout()

            Component.onCompleted: {
                if (root.daemon && typeof root.daemon.refreshAudioDevices === "function") {
                    root.daemon.refreshAudioDevices();
                }
            }

            headerActions: Component {
                Row {
                    spacing: 4

                    Rectangle {
                        id: folderBtn
                        width: 32
                        height: 32
                        radius: 16
                        color: folderArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        property bool pressed: false

                        DankIcon {
                            id: folderIcon
                            anchors.centerIn: parent
                            name: "open_in_new"
                            size: Theme.iconSize - 4
                            color: folderArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            scale: folderBtn.pressed ? 0.6 : 1.0
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                        }

                        MouseArea {
                            id: folderArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: folderBtn.pressed = true
                            onReleased: folderBtn.pressed = false
                            onCanceled: folderBtn.pressed = false
                            onClicked: {
                                folderBtn.pressed = false
                                const dir = root.widgetMode === "video" ?
                                    (root.pluginData.recordingDirectory || "~/Videos/Recordings") :
                                    (root.pluginData.saveDirectory || "~/Pictures/Screenshots");
                                Proc.runCommand("open-target-dir", ["sh", "-c", "xdg-open " + dir], null);
                            }
                        }
                    }

                    Rectangle {
                        id: historyBtn
                        width: 32
                        height: 32
                        radius: 16
                        color: historyArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15) : "transparent"

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        property bool pressed: false

                        DankIcon {
                            anchors.centerIn: parent
                            name: "history"
                            size: Theme.iconSize - 4
                            color: historyArea.containsMouse ? Theme.primary : Theme.surfaceVariantText
                            scale: historyBtn.pressed ? 0.6 : 1.0
                            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.OutBack } }
                        }

                        MouseArea {
                            id: historyArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: historyBtn.pressed = true
                            onReleased: historyBtn.pressed = false
                            onCanceled: historyBtn.pressed = false
                            onClicked: {
                                historyBtn.pressed = false
                                root.closePopout()
                                if (root.daemon) root.daemon.showHistoryCarousel()
                            }
                        }
                    }
                }
            }

            // ── Mode Switcher (Screenshot / Video Recorder) ───────────
            Item {
                width: parent.width
                height: 36

                Rectangle {
                    id: modeSwitcherContainer
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant
                    border.width: 1

                    readonly property real segmentPadding: 2
                    readonly property real segmentWidth: Math.floor((width - segmentPadding * 2) / 2)

                    // Sliding active wrapper (indicator pill)
                    Rectangle {
                        id: modeActiveIndicator
                        x: root.widgetMode === "video"
                            ? (modeSwitcherContainer.segmentPadding + modeSwitcherContainer.segmentWidth)
                            : modeSwitcherContainer.segmentPadding
                        y: modeSwitcherContainer.segmentPadding
                        width: modeSwitcherContainer.segmentWidth
                        height: modeSwitcherContainer.height - modeSwitcherContainer.segmentPadding * 2
                        radius: Theme.cornerRadius - 2
                        color: Theme.withAlpha(Theme.primary, 0.18)
                        border.color: Theme.primary
                        border.width: 1

                        Behavior on x {
                            NumberAnimation {
                                duration: Theme.shortDuration
                                easing.type: Theme.standardEasing
                            }
                        }
                    }

                    Row {
                        anchors.fill: parent
                        anchors.margins: modeSwitcherContainer.segmentPadding

                        // Screenshot Mode Icon Button
                        Item {
                            id: photoModeBtn
                            width: modeSwitcherContainer.segmentWidth
                            height: parent.height
                            readonly property bool isSelected: root.widgetMode === "photo"
                            readonly property bool isHovered: photoArea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius - 2
                                color: (!photoModeBtn.isSelected && photoModeBtn.isHovered) ? Theme.primaryHoverLight : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "photo_camera"
                                size: 18
                                color: photoModeBtn.isSelected ? Theme.primary : (photoModeBtn.isHovered ? Theme.surfaceText : Theme.surfaceVariantText)
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankRipple {
                                id: photoRipple
                                anchors.fill: parent
                                rippleColor: Theme.primary
                                cornerRadius: Theme.cornerRadius - 2
                                clip: true
                            }

                            MouseArea {
                                id: photoArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => photoRipple.trigger(mouse.x, mouse.y)
                                onClicked: root.setWidgetMode("photo")
                            }
                        }

                        // Video Recorder Mode Icon Button
                        Item {
                            id: videoModeBtn
                            width: modeSwitcherContainer.segmentWidth
                            height: parent.height
                            readonly property bool isSelected: root.widgetMode === "video"
                            readonly property bool isHovered: videoArea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.cornerRadius - 2
                                color: (!videoModeBtn.isSelected && videoModeBtn.isHovered) ? Theme.primaryHoverLight : "transparent"
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankIcon {
                                anchors.centerIn: parent
                                name: "videocam"
                                size: 18
                                color: videoModeBtn.isSelected ? Theme.primary : (videoModeBtn.isHovered ? Theme.surfaceText : Theme.surfaceVariantText)
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankRipple {
                                id: videoRipple
                                anchors.fill: parent
                                rippleColor: Theme.primary
                                cornerRadius: Theme.cornerRadius - 2
                                clip: true
                            }

                            MouseArea {
                                id: videoArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => videoRipple.trigger(mouse.x, mouse.y)
                                onClicked: root.setWidgetMode("video")
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 2
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS

                visible: root.widgetMode === "photo"

                Repeater {
                    model: [
                        { icon: "screenshot_region", text: I18n.trFor("quickCapture", "Region"), modeKey: "region", isDefault: true },
                        { icon: "fullscreen", text: I18n.trFor("quickCapture", "Full Screen"), modeKey: "full", isDefault: false },
                        { icon: "crop_square", text: I18n.trFor("quickCapture", "Active Window"), modeKey: "window", isDefault: false },
                    ]

                    delegate: menuItemComp
                }

                Rectangle {
                    width: parent.width - Theme.spacingL
                    height: 6
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        { icon: "restart_alt", text: I18n.trFor("quickCapture", "Last Region"), modeKey: "last" },
                        { icon: "unfold_more", text: I18n.trFor("quickCapture", "Scrolling"), modeKey: "scroll" },
                        { icon: "grid_view", text: I18n.trFor("quickCapture", "All Outputs"), modeKey: "all" },
                    ]
                    delegate: menuItemComp
                }

                Rectangle {
                    id: outputHeader
                    width: parent.width; height: 36
                    color: outputMouse.containsMouse ? Theme.primaryHoverLight : "transparent"
                    radius: Theme.cornerRadius
                    Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                    // ── Tree root branch ────────────────────────
                    Rectangle {
                        x: Theme.spacingM + 8
                        y: parent.height / 2
                        width: 2
                        height: parent.height / 2 + (parent.height % 2) + 2
                        color: Theme.outlineVariant
                        visible: root.outputExpanded && root.outputList.length > 0
                    }

                    Row {
                        anchors.left: parent.left; anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 24
                        anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                        DankIcon { name: "display_settings"; size: 18; anchors.verticalCenter: parent.verticalCenter; color: Theme.surfaceText }
                        StyledText { text: I18n.trFor("quickCapture", "Specific Output"); font.pixelSize: Theme.fontSizeNormal; color: Theme.surfaceText; anchors.verticalCenter: parent.verticalCenter }
                    }
                    DankIcon {
                        anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        name: root.outputExpanded ? "expand_more" : "expand_less"
                        size: 16; color: Theme.surfaceText
                    }

                    DankRipple {
                        id: outputRipple
                        anchors.fill: parent
                        rippleColor: Theme.primary
                        cornerRadius: outputHeader.radius
                        clip: true
                    }

                    MouseArea {
                        id: outputMouse
                        anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onPressed: mouse => outputRipple.trigger(mouse.x, mouse.y)
                        onClicked: {
                            if (!root.daemon) return;
                            root.outputExpanded = !root.outputExpanded;
                            if (root.outputExpanded) root.refreshOutputList();
                        }
                    }
                }

                Repeater {
                    model: root.outputExpanded ? root.outputList : []

                    delegate: Rectangle {
                        width: parent.width; height: root.outputExpanded ? 32 : 0
                        visible: root.outputExpanded
                        color: subMouse.containsMouse || pinArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                        radius: Theme.cornerRadius
                        Behavior on height { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                        // ── Tree connector ─────────────────────
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height + 2
                            color: Theme.outlineVariant
                            visible: index < root.outputList.length - 1
                        }
                        Rectangle {
                            x: Theme.spacingM + 8
                            y: 0
                            width: 2
                            height: parent.height / 2 + 2
                            color: Theme.outlineVariant
                            visible: index === root.outputList.length - 1
                        }
                        Rectangle {
                            x: Theme.spacingM + 6
                            y: parent.height / 2 - 3
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.outlineVariant
                        }

                        Row {
                            anchors.left: parent.left; anchors.leftMargin: Theme.spacingM + 20
                            anchors.right: parent.right; anchors.rightMargin: Theme.spacingS + 28
                            anchors.verticalCenter: parent.verticalCenter; spacing: Theme.spacingS
                            StyledText {
                                text: modelData.label
                                font.pixelSize: Theme.fontSizeNormal - 1
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        DankIcon {
                            id: pinIcon
                            anchors.right: parent.right; anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            name: "push_pin"
                            size: 14
                            opacity: subMouse.containsMouse || pinArea.containsMouse ? 1 : 0
                            color: pinArea.containsMouse ? Theme.primary : Theme.surfaceText
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }

                        DankRipple {
                            id: subRipple
                            anchors.fill: parent
                            rippleColor: Theme.primary
                            cornerRadius: parent.radius
                            clip: true
                        }

                        MouseArea {
                            id: subMouse
                            anchors.fill: parent; anchors.rightMargin: 28
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => subRipple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                const outputName = modelData.value;
                                if (root.daemon) {
                                    root.daemon.captureOutputName = outputName;
                                    root.daemon.triggerCaptureWithAction("output", "edit");
                                }
                                root.closePopout();
                                root.outputExpanded = false;
                            }
                        }

                        MouseArea {
                            id: pinArea
                            anchors.right: parent.right
                            anchors.top: parent.top; anchors.bottom: parent.bottom
                            width: 28
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => subRipple.trigger(mouse.x + parent.width - 28, mouse.y)
                            onClicked: {
                                const outputName = modelData.value;
                                if (root.daemon) {
                                    root.daemon.captureOutputName = outputName;
                                    root.daemon.triggerCaptureWithAction("output", "float");
                                }
                                root.closePopout();
                                root.outputExpanded = false;
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    height: root.outputExpanded && root.outputList.length === 0 ? 32 : 0
                    visible: root.outputExpanded && root.outputList.length === 0
                    padding: Theme.spacingM + 20
                    text: I18n.trFor("quickCapture", "No output available")
                    font.pixelSize: Theme.fontSizeNormal - 2
                    font.italic: true
                    color: Theme.surfaceVariantText
                    verticalAlignment: Text.AlignVCenter
                }

                Rectangle {
                    width: parent.width - Theme.spacingL
                    height: 6
                    color: "transparent"
                    anchors.horizontalCenter: parent.horizontalCenter
                    Rectangle {
                        width: parent.width
                        height: 1
                        color: Theme.withAlpha(Theme.outline, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Repeater {
                    model: [
                        { icon: "content_paste", text: I18n.trFor("quickCapture", "From Clipboard"), modeKey: "clipboard" },
                        { icon: "folder_open", text: I18n.trFor("quickCapture", "From File"), modeKey: "selectFile" },
                    ]

                    delegate: menuItemComp
                }
            }

            // ── Video Recording Menu Column ──
            Column {
                width: parent.width
                spacing: 2
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingS
                visible: root.widgetMode === "video"

                // Active Recording Status Card
                Rectangle {
                    width: parent.width
                    height: 110
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerLow
                    border.color: Theme.outlineVariant
                    border.width: 1
                    visible: root.daemon && root.daemon.isRecording

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            spacing: Theme.spacingS
                            anchors.horizontalCenter: parent.horizontalCenter

                            Rectangle {
                                id: toolbarRecordDot
                                width: 10
                                height: 10
                                radius: 5
                                color: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? Theme.warning : Theme.error
                                anchors.verticalCenter: parent.verticalCenter
                                opacity: 1.0

                                SequentialAnimation {
                                    running: root.daemon && root.daemon.isRecording && root.daemon.recordingController && !root.daemon.recordingController.isPaused && root.blinkRecordDot
                                    loops: Animation.Infinite
                                    NumberAnimation { target: toolbarRecordDot; property: "opacity"; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                                    NumberAnimation { target: toolbarRecordDot; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                    onRunningChanged: if (!running) toolbarRecordDot.opacity = 1.0
                                }
                            }

                            StyledText {
                                text: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? I18n.trFor("quickCapture", "PAUSED") : I18n.trFor("quickCapture", "RECORDING")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Font.Bold
                                color: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? Theme.warning : Theme.error
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: (root.daemon && root.daemon.recordingController) ? root.daemon.recordingController.formatDuration(root.daemon.recordingController.recordingSeconds) : "00:00"
                                font.pixelSize: Theme.fontSizeMedium
                                font.weight: Font.Medium
                                font.features: { "tnum": 1 }
                                color: Theme.surfaceText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: Theme.spacingM

                            DankActionButton {
                                iconName: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? "play_arrow" : "pause"
                                buttonSize: 34
                                iconSize: 18
                                iconColor: Theme.primary
                                tooltipText: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? I18n.trFor("quickCapture", "Resume") : I18n.trFor("quickCapture", "Pause")
                                onClicked: {
                                    if (root.daemon) root.daemon.pauseRecording();
                                }
                            }

                            DankActionButton {
                                iconName: "stop"
                                buttonSize: 34
                                iconSize: 18
                                iconColor: Theme.error
                                tooltipText: I18n.trFor("quickCapture", "Stop & Save")
                                onClicked: {
                                    root.closePopout();
                                    if (root.daemon) root.daemon.stopRecording();
                                }
                            }

                            DankActionButton {
                                iconName: "close"
                                buttonSize: 34
                                iconSize: 18
                                iconColor: Theme.surfaceVariantText
                                tooltipText: I18n.trFor("quickCapture", "Cancel")
                                onClicked: {
                                    root.closePopout();
                                    if (root.daemon) root.daemon.cancelRecording();
                                }
                            }
                        }
                    }
                }

                // Idle Recording Menu
                Column {
                    width: parent.width
                    spacing: 2
                    visible: !root.daemon || !root.daemon.isRecording

                    Repeater {
                        model: [
                            { icon: "screenshot_region", text: I18n.trFor("quickCapture", "Region"), modeKey: "region", isDefault: true },
                            { icon: "fullscreen", text: I18n.trFor("quickCapture", "Full Screen"), modeKey: "screen", isDefault: false },
                            { icon: "crop_square", text: I18n.trFor("quickCapture", "Window"), modeKey: "portal", isDefault: false }
                        ]

                        delegate: Rectangle {
                            id: recModeBtn
                            width: parent.width
                            height: 36
                            color: recMouse.containsMouse ? Theme.primaryHoverLight : "transparent"
                            radius: Theme.cornerRadius

                            Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingM
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                DankIcon {
                                    name: modelData.icon
                                    size: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                                }

                                StyledText {
                                    text: modelData.text
                                    font.pixelSize: Theme.fontSizeNormal
                                    font.bold: modelData.isDefault === true
                                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            DankRipple {
                                id: recRipple
                                anchors.fill: parent
                                rippleColor: Theme.primary
                                cornerRadius: recModeBtn.radius
                                clip: true
                            }

                            MouseArea {
                                id: recMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => recRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    root.closePopout();
                                    if (root.daemon) {
                                        root.daemon.startRecording(modelData.modeKey);
                                    }
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width - Theme.spacingL
                        height: 6
                        color: "transparent"
                        anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle {
                            width: parent.width
                            height: 1
                            color: Theme.withAlpha(Theme.outline, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }



                    // Microphone source row: toggle pill + inline device dropdown
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Rectangle {
                            id: micBox
                            width: 40
                            height: 40
                            radius: Theme.cornerRadius
                            readonly property bool isMicOn: root.recordMic
                            color: isMicOn ? Theme.withAlpha(Theme.primary, 0.15) : (micArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                            border.color: isMicOn ? Theme.primary : Theme.outlineVariant
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                            DankIcon {
                                anchors.centerIn: parent
                                name: micBox.isMicOn ? "mic" : "mic_off"
                                size: 20
                                color: micBox.isMicOn ? Theme.primary : Theme.surfaceVariantText
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankRipple {
                                id: micRipple
                                anchors.fill: parent
                                rippleColor: Theme.primary
                                cornerRadius: micBox.radius
                                clip: true
                            }

                            MouseArea {
                                id: micArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => micRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    root.savePluginData("recordMic", !micBox.isMicOn);
                                }
                            }
                        }

                        DankDropdown {
                            width: parent.width - micBox.width - Theme.spacingS
                            height: 40
                            compactMode: true
                            visible: root.recordMic
                            currentValue: root.currentMicLabel
                            options: root.audioInputsList.map(function(item) { return item.label; })
                            onValueChanged: {
                                for (let i = 0; i < root.audioInputsList.length; i++) {
                                    if (root.audioInputsList[i].label === value) {
                                        root.savePluginData("micDevice", root.audioInputsList[i].value);
                                        break;
                                    }
                                }
                            }
                        }
                    }

                    Item { width: parent.width; height: 4 }

                    // System audio source row: toggle pill + inline device dropdown
                    Row {
                        width: parent.width
                        spacing: Theme.spacingS

                        Rectangle {
                            id: audioBox
                            width: 40
                            height: 40
                            radius: Theme.cornerRadius
                            readonly property bool isAudioOn: root.recordSystemAudio
                            color: isAudioOn ? Theme.withAlpha(Theme.primary, 0.15) : (sysAudioArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
                            border.color: isAudioOn ? Theme.primary : Theme.outlineVariant
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            Behavior on border.color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }

                            DankIcon {
                                anchors.centerIn: parent
                                name: audioBox.isAudioOn ? "volume_up" : "volume_off"
                                size: 20
                                color: audioBox.isAudioOn ? Theme.primary : Theme.surfaceVariantText
                                Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
                            }

                            DankRipple {
                                id: audioRipple
                                anchors.fill: parent
                                rippleColor: Theme.primary
                                cornerRadius: audioBox.radius
                                clip: true
                            }

                            MouseArea {
                                id: sysAudioArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onPressed: mouse => audioRipple.trigger(mouse.x, mouse.y)
                                onClicked: {
                                    root.savePluginData("recordSystemAudio", !audioBox.isAudioOn);
                                }
                            }
                        }

                        DankDropdown {
                            width: parent.width - audioBox.width - Theme.spacingS
                            height: 40
                            compactMode: true
                            visible: root.recordSystemAudio
                            currentValue: root.currentAudioLabel
                            options: root.audioOutputsList.map(function(item) { return item.label; })
                            onValueChanged: {
                                for (let i = 0; i < root.audioOutputsList.length; i++) {
                                    if (root.audioOutputsList[i].label === value) {
                                        root.savePluginData("systemAudioDevice", root.audioOutputsList[i].value);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: menuItemComp

        Rectangle {
            id: itemRect
            width: parent.width
            height: 36
            color: itemMouse.containsMouse || pinArea.containsMouse ? Theme.primaryHoverLight : "transparent"
            radius: Theme.cornerRadius
            scale: (itemMouse.pressed || pinArea.pressed) && !itemMouse.drag.active ? 0.98 : 1.0

            Behavior on color { ColorAnimation { duration: Theme.shorterDuration; easing.type: Theme.standardEasing } }
            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.OutQuad } }

            function execMode(action) {
                if (!root.daemon) return;
                const mk = modelData.modeKey;
                root.runAfterPopoutClosed(() => {
                    if (mk === "clipboard") root.daemon.fromClipboardWithAction(action);
                    else if (mk === "selectFile") root.daemon.selectImageAndAnnotateWithAction(action);
                    else root.daemon.triggerCaptureWithAction(mk, action);
                });
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS + 28
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: modelData.icon
                    size: 18
                    anchors.verticalCenter: parent.verticalCenter
                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                }

                StyledText {
                    text: modelData.text
                    font.pixelSize: Theme.fontSizeNormal
                    font.bold: modelData.isDefault === true
                    color: modelData.isDefault ? Theme.primary : Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankRipple {
                id: itemRipple
                anchors.fill: parent
                rippleColor: Theme.primary
                cornerRadius: itemRect.radius
                clip: true
            }

            DankIcon {
                id: pinIcon
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: "push_pin"
                size: 16
                opacity: itemMouse.containsMouse || pinArea.containsMouse ? 1 : 0
                color: pinArea.containsMouse ? Theme.primary : Theme.surfaceText
                Behavior on opacity { NumberAnimation { duration: 100 } }
            }

            MouseArea {
                id: itemMouse
                anchors.fill: parent
                anchors.rightMargin: 28
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => itemRipple.trigger(mouse.x, mouse.y)
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        const action = root.daemon ? (root.daemon.pluginData.menuRightClickAction || "copy") : "copy";
                        execMode(action);
                    } else {
                        execMode("edit");
                    }
                }
            }

            MouseArea {
                id: pinArea
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 28
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => itemRipple.trigger(mouse.x + parent.width - 28, mouse.y)
                onClicked: execMode("float")
            }
        }
    }

    // ── Horizontal bar pill ───────────────────────────────────────────────────
    horizontalBarPill: Component {
        Item {
            readonly property bool isRecording: root.daemon ? root.daemon.isRecording : false
            readonly property bool isPaused: isRecording && root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused
            property bool draggingOver: false

            implicitWidth: isRecording ? recordRow.implicitWidth : Theme.iconSizeSmall
            implicitHeight: Theme.iconSize
            anchors.verticalCenter: parent.verticalCenter

            Behavior on implicitWidth {
                NumberAnimation { duration: 250; easing.type: Easing.InOutQuad }
            }

            Row {
                id: recordRow
                anchors.centerIn: parent
                spacing: isRecording ? Theme.spacingS : 0
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                // Idle mode icon
                DankIcon {
                    visible: !isRecording
                    name: root.isDownloading ? "download" : (root.widgetMode === "video" ? "videocam" : "screenshot_region")
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isActive || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Minimalist recording dot
                Rectangle {
                    id: hRecordDot
                    visible: isRecording && root.showRecordingDot
                    width: 8
                    height: 8
                    radius: 4
                    anchors.verticalCenter: parent.verticalCenter
                    color: isPaused ? Theme.warning : Theme.error
                    opacity: 1.0

                    SequentialAnimation {
                        running: isRecording && !isPaused && root.blinkRecordDot
                        loops: Animation.Infinite
                        NumberAnimation { target: hRecordDot; property: "opacity"; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { target: hRecordDot; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) hRecordDot.opacity = 1.0
                    }
                }

                StyledText {
                    visible: isRecording
                    text: (root.daemon && root.daemon.recordingController) ? root.daemon.recordingController.formatDuration(root.daemon.recordingController.recordingSeconds) : "00:00"
                    color: isPaused ? Theme.warning : Theme.widgetTextColor
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined, root.barConfig ? root.barConfig.maximizeWidgetText : undefined)
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Pause button
                Rectangle {
                    visible: isRecording
                    width: isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: !isPaused
                        ? (hPauseMouse.containsMouse ? Qt.darker(Theme.primary, 1.15) : Theme.primary)
                        : (hPauseMouse.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1))

                    Behavior on color {
                        ColorAnimation { duration: 90; easing.type: Theme.standardEasing }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: isPaused ? "play_arrow" : "pause"
                        size: 14
                        color: !isPaused ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        id: hPauseMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.daemon) root.daemon.pauseRecording();
                        }
                    }
                }

                // Stop button
                Rectangle {
                    visible: isRecording
                    width: isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: hStopMouse.containsMouse ? Qt.darker(Theme.error, 1.15) : Theme.error

                    Behavior on color {
                        ColorAnimation { duration: 90; easing.type: Theme.standardEasing }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "stop"
                        size: 14
                        color: Theme.background
                    }

                    MouseArea {
                        id: hStopMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.daemon) root.daemon.stopRecording();
                        }
                    }
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (root.daemon) root.daemon.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                visible: !isRecording
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        const action = root.daemon ? (root.daemon.pluginData.middleClickAction || "region") : "region";
                        root.execAction(action);
                    }
                }
            }
        }
    }

    // ── Vertical bar pill ─────────────────────────────────────────────────────
    verticalBarPill: Component {
        Item {
            readonly property bool isRecording: root.daemon ? root.daemon.isRecording : false
            readonly property bool isPaused: isRecording && root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused
            property bool draggingOver: false

            implicitWidth: Math.max(Theme.iconSizeSmall, vColumn.implicitWidth)
            implicitHeight: vColumn.implicitHeight
            anchors.horizontalCenter: parent.horizontalCenter

            Column {
                id: vColumn
                anchors.centerIn: parent
                spacing: isRecording ? Theme.spacingXS : 0
                scale: draggingOver ? 1.2 : 1.0
                Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

                // Idle mode icon
                DankIcon {
                    visible: !isRecording
                    name: root.isDownloading ? "download" : (root.widgetMode === "video" ? "videocam" : "screenshot_region")
                    size: Theme.iconSizeSmall
                    color: draggingOver ? Theme.primary : (root.isActive || root.isDownloading ? Theme.primary : Theme.surfaceText)
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                // Minimalist recording dot
                Rectangle {
                    id: vRecordDot
                    visible: isRecording && root.showRecordingDot
                    width: 8
                    height: 8
                    radius: 4
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: isPaused ? Theme.warning : Theme.error
                    opacity: 1.0

                    SequentialAnimation {
                        running: isRecording && !isPaused && root.blinkRecordDot
                        loops: Animation.Infinite
                        NumberAnimation { target: vRecordDot; property: "opacity"; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                        NumberAnimation { target: vRecordDot; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                        onRunningChanged: if (!running) vRecordDot.opacity = 1.0
                    }
                }

                // Pause button
                Rectangle {
                    visible: isRecording
                    width: isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: !isPaused
                        ? (vPauseMouseArea.containsMouse ? Qt.darker(Theme.primary, 1.15) : Theme.primary)
                        : (vPauseMouseArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2) : Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.1))

                    Behavior on color {
                        ColorAnimation { duration: 90; easing.type: Theme.standardEasing }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: isPaused ? "play_arrow" : "pause"
                        size: 14
                        color: !isPaused ? Theme.background : Theme.primary
                    }

                    MouseArea {
                        id: vPauseMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.daemon) root.daemon.pauseRecording();
                        }
                    }
                }

                // Stop button
                Rectangle {
                    visible: isRecording
                    width: isRecording ? 24 : 0
                    height: 24
                    radius: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: vStopMouseArea.containsMouse ? Qt.darker(Theme.error, 1.15) : Theme.error

                    Behavior on color {
                        ColorAnimation { duration: 90; easing.type: Theme.standardEasing }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "stop"
                        size: 14
                        color: Theme.background
                    }

                    MouseArea {
                        id: vStopMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.daemon) root.daemon.stopRecording();
                        }
                    }
                }

                StyledText {
                    visible: isRecording
                    text: (root.daemon && root.daemon.recordingController) ? root.daemon.recordingController.formatDuration(root.daemon.recordingController.recordingSeconds).split(':').join('\n') : "00\n00"
                    color: isPaused ? Theme.warning : Theme.widgetTextColor
                    font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig ? root.barConfig.fontScale : undefined, root.barConfig ? root.barConfig.maximizeWidgetText : undefined)
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            DropArea {
                anchors.fill: parent
                onEntered: draggingOver = true
                onExited: draggingOver = false
                onDropped: (drop) => {
                    draggingOver = false;
                    if (root.daemon) root.daemon.handleDrop(drop);
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.MiddleButton
                cursorShape: Qt.PointingHandCursor
                visible: !isRecording
                onClicked: (mouse) => {
                    if (mouse.button === Qt.MiddleButton) {
                        const action = root.daemon ? (root.daemon.pluginData.middleClickAction || "region") : "region";
                        root.execAction(action);
                    }
                }
            }
        }
    }

    // ── Bar Pill interactions ─────────────────────────────────────────────────
    // popout auto-opens on left click when pillClickAction is not set and popoutContent is defined
    pillRightClickAction: function() {
        if (!root.daemon) return;
        if (root.daemon.isRecording) {
            root.daemon.cancelRecording();
            return;
        }
        const action = root.daemon.pluginData.rightClickAction || "clipboard";
        root.execAction(action);
    }

    // ── Control Center integration ────────────────────────────────────────────
    ccWidgetIcon: (root.daemon && root.daemon.isRecording) ? "videocam" : "screenshot_region"
    ccWidgetPrimaryText: (root.daemon && root.daemon.isRecording) ? I18n.trFor("quickCapture", "Recording...") : (root.widgetMode === "video" ? I18n.trFor("quickCapture", "Screen Recorder") : I18n.trFor("quickCapture", "Quick Capture"))
    ccWidgetSecondaryText: (root.daemon && root.daemon.isRecording)
        ? (root.daemon.recordingController ? root.daemon.recordingController.formatDuration(root.daemon.recordingController.recordingSeconds) : "")
        : (root.isActive ? (daemon.isCapturing ? I18n.trFor("quickCapture", "Capturing...") : I18n.trFor("quickCapture", "Annotating")) : I18n.trFor("quickCapture", "Ready"))
    ccWidgetIsActive: root.isActive || (root.daemon && root.daemon.isRecording)
    onCcWidgetToggled: {
        if (root.daemon && root.daemon.isRecording) {
            root.daemon.stopRecording();
            return;
        }
        const action = root.daemon ? (root.daemon.pluginData.middleClickAction || "region") : "region";
        root.execAction(action);
    }
    ccDetailHeight: 240

    ccDetailContent: Component {
        Rectangle {
            id: detailRoot
            radius: Theme.cornerRadius
            color: Theme.nestedSurface
            border.color: Theme.outlineMedium
            border.width: Theme.layerOutlineWidth
            implicitHeight: childrenRect.height

            Item {
                id: headerRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Math.max(headerLabel.implicitHeight, headerControls.implicitHeight) + Theme.spacingS * 2

                StyledText {
                    id: headerLabel
                    text: root.widgetMode === "video" ? I18n.trFor("quickCapture", "Screen Recorder") : I18n.trFor("quickCapture", "Quick Capture")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    id: headerControls
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    DankActionButton {
                        iconName: root.widgetMode === "photo" ? "videocam" : "photo_camera"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: root.widgetMode === "video" ? Theme.primary : Theme.surfaceVariantText
                        tooltipText: root.widgetMode === "photo" ? I18n.trFor("quickCapture", "Screen Recorder") : I18n.trFor("quickCapture", "Quick Capture")
                        tooltipSide: "bottom"
                        onClicked: {
                            root.switchWidgetMode();
                        }
                    }

                    DankActionButton {
                        iconName: "settings"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: Theme.surfaceVariantText
                        tooltipText: I18n.trFor("quickCapture", "Settings")
                        tooltipSide: "bottom"
                        onClicked: PopoutService.openSettingsWithTab("plugins")
                    }

                    DankActionButton {
                        iconName: "open_in_new"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: Theme.surfaceVariantText
                        tooltipText: root.widgetMode === "video" ? I18n.trFor("quickCapture", "Recording Folder") : I18n.trFor("quickCapture", "Screenshot Folder")
                        tooltipSide: "bottom"
                        onClicked: {
                            const dir = root.widgetMode === "video"
                                ? (root.pluginData.recordingDirectory || "~/Videos/Recordings")
                                : (root.pluginData.saveDirectory || "~/Pictures/Screenshots");
                            Proc.runCommand("open-target-dir", ["sh", "-c", "xdg-open " + dir], null);
                        }
                    }

                    DankActionButton {
                        iconName: "history"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: Theme.surfaceVariantText
                        tooltipText: I18n.trFor("quickCapture", "History")
                        tooltipSide: "bottom"
                        onClicked: {
                            if (root.daemon) root.daemon.showHistoryCarousel();
                        }
                    }

                    DankActionButton {
                        iconName: root.daemon && root.daemon.hideControlCenter ? "visibility_off" : "visibility"
                        buttonSize: 28
                        iconSize: 16
                        iconColor: root.daemon && root.daemon.hideControlCenter ? Theme.surfaceVariantText : Theme.primary
                        tooltipText: root.daemon && root.daemon.hideControlCenter
                            ? I18n.trFor("quickCapture", "Hide Control Center")
                            : I18n.trFor("quickCapture", "Show Control Center")
                        tooltipSide: "bottom"
                        onClicked: {
                            if (root.daemon) root.daemon.toggleHideControlCenter();
                        }
                    }
                }
            }

            Grid {
                id: grid
                visible: root.widgetMode === "photo"
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerRow.bottom
                anchors.margins: Theme.spacingM
                anchors.topMargin: Theme.spacingS
                columns: 4
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { icon: "screenshot_region", text: I18n.trFor("quickCapture", "Region"), modeKey: "region" },
                        { icon: "fullscreen", text: I18n.trFor("quickCapture", "Full Screen"), modeKey: "full" },
                        { icon: "crop_square", text: I18n.trFor("quickCapture", "Window"), modeKey: "window" },
                        { icon: "restart_alt", text: I18n.trFor("quickCapture", "Last Reg"), modeKey: "last" },
                        { icon: "unfold_more", text: I18n.trFor("quickCapture", "Scroll"), modeKey: "scroll" },
                        { icon: "grid_view", text: I18n.trFor("quickCapture", "Outputs"), modeKey: "all" },
                        { icon: "content_paste", text: I18n.trFor("quickCapture", "Clipboard"), modeKey: "clipboard" },
                        { icon: "folder_open", text: I18n.trFor("quickCapture", "From File"), modeKey: "selectFile" }
                    ]

                    delegate: Rectangle {
                        id: modeBtn
                        width: (grid.width - grid.spacing * 3) / 4
                        height: 68
                        radius: Theme.cornerRadius
                        color: mouseArea.containsMouse
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            : Theme.surfaceContainerLow
                        border.color: mouseArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.12)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
                        Behavior on border.color { ColorAnimation { duration: Theme.shorterDuration } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: modelData.icon
                                size: 20
                                color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color: mouseArea.containsMouse ? Theme.primary : Theme.surfaceText
                                width: parent.width - Theme.spacingXS * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        DankRipple {
                            id: ripple
                            anchors.fill: parent
                            rippleColor: Theme.primary
                            cornerRadius: modeBtn.radius
                            clip: true
                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                if (!root.daemon) return;
                                const mk = modelData.modeKey;
                                if (mk === "clipboard") root.daemon.fromClipboardWithAction("edit");
                                else if (mk === "selectFile") root.daemon.selectImageAndAnnotateWithAction("edit");
                                else root.daemon.triggerCaptureWithAction(mk, "edit");
                            }
                        }
                    }
                }
            }

            // Active Recording Card in Control Center
            Rectangle {
                visible: root.widgetMode === "video" && root.daemon && root.daemon.isRecording
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerRow.bottom
                anchors.margins: Theme.spacingM
                anchors.topMargin: Theme.spacingS
                height: 68
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerLow
                border.color: Theme.outlineVariant
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingL

                    Row {
                        spacing: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter

                        Rectangle {
                            id: ccRecordDot
                            width: 10
                            height: 10
                            radius: 5
                            color: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? Theme.warning : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 1.0

                            SequentialAnimation {
                                running: root.daemon && root.daemon.isRecording && root.daemon.recordingController && !root.daemon.recordingController.isPaused && root.blinkRecordDot
                                loops: Animation.Infinite
                                NumberAnimation { target: ccRecordDot; property: "opacity"; to: 0.35; duration: 800; easing.type: Easing.InOutSine }
                                NumberAnimation { target: ccRecordDot; property: "opacity"; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                                onRunningChanged: if (!running) ccRecordDot.opacity = 1.0
                            }
                        }

                        StyledText {
                            text: (root.daemon && root.daemon.recordingController) ? root.daemon.recordingController.formatDuration(root.daemon.recordingController.recordingSeconds) : "00:00"
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Font.Bold
                            font.features: { "tnum": 1 }
                            color: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? Theme.warning : Theme.error
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Row {
                        spacing: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter

                        DankActionButton {
                            iconName: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? "play_arrow" : "pause"
                            buttonSize: 36
                            iconSize: 20
                            iconColor: Theme.primary
                            tooltipText: (root.daemon && root.daemon.recordingController && root.daemon.recordingController.isPaused) ? I18n.trFor("quickCapture", "Resume") : I18n.trFor("quickCapture", "Pause")
                            onClicked: if (root.daemon) root.daemon.pauseRecording()
                        }

                        DankActionButton {
                            iconName: "stop"
                            buttonSize: 36
                            iconSize: 20
                            iconColor: Theme.error
                            tooltipText: I18n.trFor("quickCapture", "Stop & Save")
                            onClicked: if (root.daemon) root.daemon.stopRecording()
                        }

                        DankActionButton {
                            iconName: "close"
                            buttonSize: 36
                            iconSize: 20
                            iconColor: Theme.surfaceVariantText
                            tooltipText: I18n.trFor("quickCapture", "Cancel")
                            onClicked: if (root.daemon) root.daemon.cancelRecording()
                        }
                    }
                }
            }

            // Video Mode Grid (Idle) in Control Center
            Grid {
                id: recGrid
                visible: root.widgetMode === "video" && (!root.daemon || !root.daemon.isRecording)
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: headerRow.bottom
                anchors.margins: Theme.spacingM
                anchors.topMargin: Theme.spacingS
                columns: 3
                spacing: Theme.spacingS

                Repeater {
                    model: [
                        { icon: "screenshot_region", text: I18n.trFor("quickCapture", "Region"), modeKey: "region" },
                        { icon: "fullscreen", text: I18n.trFor("quickCapture", "Screen"), modeKey: "screen" },
                        { icon: "crop_square", text: I18n.trFor("quickCapture", "Window"), modeKey: "portal" }
                    ]

                    delegate: Rectangle {
                        id: recGridBtn
                        width: (recGrid.width - recGrid.spacing * 2) / 3
                        height: 68
                        radius: Theme.cornerRadius
                        color: recGridMouse.containsMouse
                            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                            : Theme.surfaceContainerLow
                        border.color: recGridMouse.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.12)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: Theme.shorterDuration } }
                        Behavior on border.color { ColorAnimation { duration: Theme.shorterDuration } }

                        Column {
                            anchors.centerIn: parent
                            width: parent.width
                            spacing: Theme.spacingXS

                            DankIcon {
                                name: modelData.icon
                                size: 20
                                color: recGridMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: modelData.text
                                font.pixelSize: Theme.fontSizeSmall
                                color: recGridMouse.containsMouse ? Theme.primary : Theme.surfaceText
                                width: parent.width - Theme.spacingXS * 2
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                            }
                        }

                        DankRipple {
                            id: recGridRipple
                            anchors.fill: parent
                            rippleColor: Theme.primary
                            cornerRadius: recGridBtn.radius
                            clip: true
                        }

                        MouseArea {
                            id: recGridMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => recGridRipple.trigger(mouse.x, mouse.y)
                            onClicked: {
                                if (!root.daemon) return;
                                root.daemon.startRecording(modelData.modeKey);
                            }
                        }
                    }
                }
            }
        }
    }
}
