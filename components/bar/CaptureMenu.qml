import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets
import "../core/Defaults.js" as Defaults

PopoutComponent {
    id: root

    required property var widget
    readonly property var daemon: widget.daemon
    readonly property var recorder: widget.recorder
    readonly property var config: widget.config
    readonly property bool isRecording: widget.isRecording
    readonly property bool videoMode: widget.widgetMode === "video"
    readonly property string menuRightClickAction: Defaults.get(widget.pluginData, "menuRightClickAction")
    readonly property bool recordingIsGif: (recorder?.videoFormat ?? "mp4") === "gif"
    readonly property bool recordingHasAudio: (recorder?.activeRecorderBin ?? "") !== "wf-recorder"
    property bool outputExpanded: false

    readonly property string recordingTargetIcon: {
        switch (recorder?.activeRecordingMode) {
        case "region":
            return "crop_square";
        case "portal":
            return "window";
        default:
            return "fullscreen";
        }
    }

    readonly property string recordingTargetText: {
        if (!recorder)
            return "";
        if (recorder.activeRecordingMode === "region")
            return recorder.regionW > 0 ? recorder.regionW + " × " + recorder.regionH : I18n.trFor("quickCapture", "Region");
        if (recorder.activeRecordingMode === "portal")
            return I18n.trFor("quickCapture", "Window");
        const target = Defaults.get(widget.pluginData, "recordingScreenTarget");
        let scr = Quickshell.screens.find(s => s.name === target) ?? null;
        if (!scr)
            scr = CompositorService.getFocusedScreen() ?? Quickshell.screens[0] ?? null;
        if (!scr)
            return I18n.trFor("quickCapture", "Fullscreen");
        return scr.name + " (" + scr.width + " × " + scr.height + ")";
    }

    readonly property string recordingFormatText: {
        if (!recorder)
            return "";
        const fmt = recorder.videoFormat.toUpperCase();
        const fps = fmt === "GIF" ? recorder.gifFramerate : recorder.framerate;
        return fmt + " · " + fps + " FPS";
    }

    width: widget.popoutWidth
    headerText: I18n.trFor("quickCapture", "Quick Capture")
    showCloseButton: false
    closePopout: () => widget.closePopout()

    function refreshDevices() {
        if (root.videoMode && root.daemon)
            root.daemon.refreshAudioDevices();
    }

    Component.onCompleted: refreshDevices()
    onVideoModeChanged: refreshDevices()

    function run(mode, action, outputName) {
        if (!root.daemon)
            return;
        root.widget.runAfterPopoutClosed(() => root.daemon.capture(mode, action, outputName));
    }

    component MenuDivider: Item {
        width: parent.width - Theme.spacingL
        height: 6
        anchors.horizontalCenter: parent.horizontalCenter

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.12)
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    component InfoRow: Item {
        id: infoRow
        property string icon: ""
        property string label: ""
        property string value: ""
        property bool accent: false

        width: parent.width
        implicitHeight: 18

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            DankIcon {
                name: infoRow.icon
                size: 14
                color: infoRow.accent ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: infoRow.label
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - 100)
            text: infoRow.value
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.Medium
            color: infoRow.accent ? Theme.surfaceText : Theme.surfaceVariantText
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
    }

    headerActions: Component {
        Row {
            spacing: Theme.spacingXS

            DankActionButton {
                iconName: "open_in_new"
                buttonSize: 32
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                tooltipText: root.videoMode ? I18n.trFor("quickCapture", "Recording Folder") : I18n.trFor("quickCapture", "Screenshot Folder")
                onClicked: root.daemon?.openFolder(root.videoMode ? "video" : "photo")
            }

            DankActionButton {
                iconName: "history"
                buttonSize: 32
                iconSize: Theme.iconSize - 4
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.trFor("quickCapture", "History")
                onClicked: {
                    root.widget.closePopout();
                    root.daemon?.showHistoryCarousel();
                }
            }
        }
    }

    Item {
        width: parent.width
        height: 36

        Rectangle {
            id: modeSwitcher
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

            Rectangle {
                x: modeSwitcher.segmentPadding + (root.videoMode ? modeSwitcher.segmentWidth : 0)
                y: modeSwitcher.segmentPadding
                width: modeSwitcher.segmentWidth
                height: modeSwitcher.height - modeSwitcher.segmentPadding * 2
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
                anchors.margins: modeSwitcher.segmentPadding

                Repeater {
                    model: [
                        {
                            mode: "photo",
                            icon: "photo_camera"
                        },
                        {
                            mode: "video",
                            icon: "videocam"
                        }
                    ]

                    delegate: Item {
                        id: segment
                        required property var modelData
                        readonly property bool selected: root.widget.widgetMode === modelData.mode

                        width: modeSwitcher.segmentWidth
                        height: parent.height

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius - 2
                            color: !segment.selected && segmentArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shorterDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        DankIcon {
                            anchors.centerIn: parent
                            name: segment.modelData.icon
                            size: Theme.iconSizeSmall
                            color: segment.selected ? Theme.primary : (segmentArea.containsMouse ? Theme.surfaceText : Theme.surfaceVariantText)
                            Behavior on color {
                                ColorAnimation {
                                    duration: Theme.shorterDuration
                                    easing.type: Theme.standardEasing
                                }
                            }
                        }

                        DankRipple {
                            id: segmentRipple
                            anchors.fill: parent
                            rippleColor: Theme.primary
                            cornerRadius: Theme.cornerRadius - 2
                            clip: true
                        }

                        MouseArea {
                            id: segmentArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onPressed: mouse => segmentRipple.trigger(mouse.x, mouse.y)
                            onClicked: root.widget.setWidgetMode(segment.modelData.mode)
                        }
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
        visible: !root.videoMode

        Repeater {
            model: root.config.modesFor(["region", "full", "window"])

            delegate: CaptureMenuItem {
                required property var modelData
                icon: modelData.icon
                text: modelData.label
                highlighted: modelData.value === "region"
                rightClickAction: root.menuRightClickAction
                onTriggered: action => root.run(modelData.value, action)
            }
        }

        MenuDivider {}

        Repeater {
            model: root.config.modesFor(["last", "scroll", "all"])

            delegate: CaptureMenuItem {
                required property var modelData
                icon: modelData.icon
                text: modelData.label
                rightClickAction: root.menuRightClickAction
                onTriggered: action => root.run(modelData.value, action)
            }
        }

        Rectangle {
            id: outputHeader
            width: parent.width
            height: 36
            color: outputMouse.containsMouse ? Theme.primaryHoverLight : "transparent"
            radius: Theme.cornerRadius
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shorterDuration
                    easing.type: Theme.standardEasing
                }
            }

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingM
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS + 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                DankIcon {
                    name: "display_settings"
                    size: Theme.iconSizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.surfaceText
                }

                StyledText {
                    text: I18n.trFor("quickCapture", "Specific Output")
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            DankIcon {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: root.outputExpanded ? "expand_more" : "expand_less"
                size: Theme.iconSizeSmall - 2
                color: Theme.surfaceText
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
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => outputRipple.trigger(mouse.x, mouse.y)
                onClicked: {
                    if (!root.daemon)
                        return;
                    root.outputExpanded = !root.outputExpanded;
                    if (root.outputExpanded)
                        root.daemon.refreshOutputs();
                }
            }
        }

        Repeater {
            model: root.outputExpanded ? (root.daemon?.outputs ?? []) : []

            delegate: CaptureMenuItem {
                required property var modelData
                height: 32
                icon: "monitor"
                text: modelData.name + "  (" + modelData.width + "×" + modelData.height + ")"
                rightClickAction: root.menuRightClickAction
                onTriggered: action => {
                    root.outputExpanded = false;
                    root.run("output", action, modelData.name);
                }
            }
        }

        StyledText {
            width: parent.width
            height: 32
            visible: root.outputExpanded && (root.daemon?.outputs ?? []).length === 0
            leftPadding: Theme.spacingM + 20
            text: I18n.trFor("quickCapture", "No output available")
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
            color: Theme.surfaceVariantText
            verticalAlignment: Text.AlignVCenter
        }

        MenuDivider {}

        Repeater {
            model: root.config.modesFor(["clipboard", "selectFile"])

            delegate: CaptureMenuItem {
                required property var modelData
                icon: modelData.icon
                text: modelData.label
                rightClickAction: root.menuRightClickAction
                onTriggered: action => root.run(modelData.value, action)
            }
        }
    }

    Column {
        width: parent.width
        spacing: 2
        topPadding: Theme.spacingS
        bottomPadding: Theme.spacingS
        visible: root.videoMode

        Rectangle {
            width: parent.width
            height: activeRecordingColumn.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadius
            color: Theme.surfaceContainerLow
            border.color: Theme.outlineVariant
            border.width: 1
            visible: root.isRecording

            Column {
                id: activeRecordingColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    spacing: Theme.spacingS
                    anchors.horizontalCenter: parent.horizontalCenter

                    RecordingDot {
                        dotSize: 10
                        paused: root.widget.isPaused
                        blink: root.widget.blinkRecordDot
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: (root.widget.isPaused ? I18n.trFor("quickCapture", "Paused") : I18n.trFor("quickCapture", "Recording")).toUpperCase()
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Bold
                        color: root.widget.isPaused ? Theme.warning : Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: root.widget.durationText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Font.Medium
                        font.features: {
                            "tnum": 1
                        }
                        color: Theme.surfaceText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                RecordingTransport {
                    anchors.horizontalCenter: parent.horizontalCenter
                    recorder: root.recorder
                    onActionTriggered: action => {
                        if (action !== "pause")
                            root.widget.closePopout();
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.withAlpha(Theme.outline, 0.12)
                }

                Column {
                    width: parent.width
                    spacing: Theme.spacingXS

                    InfoRow {
                        icon: root.recordingTargetIcon
                        label: I18n.trFor("quickCapture", "Display")
                        value: root.recordingTargetText
                        accent: true
                    }

                    InfoRow {
                        visible: root.recordingHasAudio
                        readonly property bool on: !root.recordingIsGif && (root.recorder?.recordMic ?? false)
                        icon: on ? "mic" : "mic_off"
                        label: I18n.trFor("quickCapture", "Microphone")
                        value: on ? micRow.currentLabel : I18n.trFor("quickCapture", "Off")
                        accent: on
                    }

                    InfoRow {
                        visible: root.recordingHasAudio
                        readonly property bool on: !root.recordingIsGif && (root.recorder?.recordAudio ?? false)
                        icon: on ? "volume_up" : "volume_off"
                        label: I18n.trFor("quickCapture", "Audio")
                        value: on ? audioRow.currentLabel : I18n.trFor("quickCapture", "Off")
                        accent: on
                    }

                    InfoRow {
                        icon: "movie"
                        label: I18n.trFor("quickCapture", "Output Format")
                        value: root.recordingFormatText
                        accent: true
                    }
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2
            visible: !root.isRecording

            Repeater {
                model: root.config.recordModes

                delegate: CaptureMenuItem {
                    required property var modelData
                    icon: modelData.icon
                    text: modelData.label
                    highlighted: modelData.value === "region"
                    showPin: false
                    onTriggered: {
                        root.widget.closePopout();
                        root.daemon?.record(modelData.value);
                    }
                }
            }

            MenuDivider {}

            AudioSourceRow {
                id: micRow
                active: root.recorder?.recordMic ?? false
                iconOn: "mic"
                iconOff: "mic_off"
                options: root.recorder?.audioInputsList ?? []
                currentValue: root.recorder?.micDevice ?? ""
                onToggled: root.daemon?.savePluginData("recordMic", !active)
                onValueSelected: value => root.daemon?.savePluginData("micDevice", value)
            }

            Item {
                width: parent.width
                height: Theme.spacingXS
            }

            AudioSourceRow {
                id: audioRow
                active: root.recorder?.recordAudio ?? false
                iconOn: "volume_up"
                iconOff: "volume_off"
                options: root.recorder?.audioOutputsList ?? []
                currentValue: root.recorder?.systemAudioDevice ?? ""
                onToggled: root.daemon?.savePluginData("recordSystemAudio", !active)
                onValueSelected: value => root.daemon?.savePluginData("systemAudioDevice", value)
            }
        }
    }
}
