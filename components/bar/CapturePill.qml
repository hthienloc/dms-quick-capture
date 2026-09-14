import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property var widget
    property bool vertical: false
    readonly property bool isRecording: widget.isRecording
    readonly property bool isPaused: widget.isPaused
    property bool draggingOver: false

    implicitWidth: vertical ? Math.max(Theme.iconSizeSmall, layout.implicitWidth) : (isRecording ? layout.implicitWidth : Theme.iconSizeSmall)
    implicitHeight: vertical ? layout.implicitHeight : Theme.iconSize
    anchors.verticalCenter: vertical ? undefined : parent.verticalCenter
    anchors.horizontalCenter: vertical ? parent.horizontalCenter : undefined

    Behavior on implicitWidth {
        enabled: !root.vertical
        NumberAnimation {
            duration: Theme.shortDuration
            easing.type: Theme.standardEasing
        }
    }

    Grid {
        id: layout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 10
        spacing: root.isRecording ? (root.vertical ? Theme.spacingXS : Theme.spacingS) : 0
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
        scale: root.draggingOver ? 1.2 : 1.0
        Behavior on scale {
            NumberAnimation {
                duration: Theme.shortDuration
                easing.type: Easing.OutBack
            }
        }

        DankIcon {
            visible: !root.isRecording
            name: root.widget.isDownloading ? "download" : (root.widget.widgetMode === "video" ? "videocam" : "screenshot_region")
            size: Theme.iconSizeSmall
            color: root.draggingOver || root.widget.isActive || root.widget.isDownloading ? Theme.primary : Theme.surfaceText
        }

        RecordingDot {
            visible: root.isRecording
            paused: root.isPaused
            blink: root.widget.blinkRecordDot
        }

        StyledText {
            visible: root.isRecording
            text: root.vertical ? root.widget.durationText.split(":").join("\n") : root.widget.durationText
            color: root.isPaused ? Theme.warning : Theme.widgetTextColor
            font.pixelSize: Theme.barTextSize(root.widget.barThickness, root.widget.barConfig?.fontScale, root.widget.barConfig?.maximizeWidgetText)
            font.weight: Font.Medium
            font.features: {
                "tnum": 1
            }
            horizontalAlignment: Text.AlignHCenter
        }

        RecordingTransport {
            visible: root.isRecording
            recorder: root.widget.recorder
            vertical: root.vertical
            buttonSize: 24
            iconSize: 14
            filled: true
            showCancel: false
        }
    }

    DropArea {
        anchors.fill: parent
        onEntered: root.draggingOver = true
        onExited: root.draggingOver = false
        onDropped: drop => {
            root.draggingOver = false;
            root.widget.daemon?.handleDrop(drop);
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        visible: !root.isRecording
        onClicked: root.widget.runDefaultAction("middleClickAction")
    }
}
