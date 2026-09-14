import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Rectangle {
    id: root

    required property var widget
    readonly property var daemon: widget.daemon
    readonly property var config: widget.config
    readonly property bool videoMode: widget.widgetMode === "video"
    readonly property bool isRecording: widget.isRecording

    radius: Theme.cornerRadius
    color: Theme.nestedSurface
    border.color: Theme.outlineMedium
    border.width: Theme.layerOutlineWidth
    implicitHeight: childrenRect.height

    component ModeTile: Rectangle {
        id: tile
        required property var modelData
        property int columns: 4

        signal triggered

        width: (parent.width - parent.spacing * (columns - 1)) / columns
        height: 68
        radius: Theme.cornerRadius
        color: tileArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.surfaceContainerLow
        border.color: tileArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.12)
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.shorterDuration
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.shorterDuration
            }
        }

        Column {
            anchors.centerIn: parent
            width: parent.width
            spacing: Theme.spacingXS

            DankIcon {
                name: tile.modelData.icon
                size: Theme.iconSize
                color: tileArea.containsMouse ? Theme.primary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: tile.modelData.label
                font.pixelSize: Theme.fontSizeSmall
                color: tileArea.containsMouse ? Theme.primary : Theme.surfaceText
                width: parent.width - Theme.spacingXS * 2
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }

        DankRipple {
            id: tileRipple
            anchors.fill: parent
            rippleColor: Theme.primary
            cornerRadius: tile.radius
            clip: true
        }

        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => tileRipple.trigger(mouse.x, mouse.y)
            onClicked: tile.triggered()
        }
    }

    Item {
        id: headerRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: Math.max(headerLabel.implicitHeight, headerControls.implicitHeight) + Theme.spacingS * 2

        StyledText {
            id: headerLabel
            text: root.videoMode ? I18n.trFor("quickCapture", "Screen Recording") : I18n.trFor("quickCapture", "Quick Capture")
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
                iconName: root.videoMode ? "photo_camera" : "videocam"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                iconColor: root.videoMode ? Theme.primary : Theme.surfaceVariantText
                tooltipText: root.videoMode ? I18n.trFor("quickCapture", "Quick Capture") : I18n.trFor("quickCapture", "Screen Recording")
                tooltipSide: "bottom"
                onClicked: root.widget.setWidgetMode(root.videoMode ? "photo" : "video")
            }

            DankActionButton {
                iconName: "settings"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.trFor("quickCapture", "Settings")
                tooltipSide: "bottom"
                onClicked: PopoutService.openSettingsWithTab("plugins")
            }

            DankActionButton {
                iconName: "open_in_new"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.surfaceVariantText
                tooltipText: root.videoMode ? I18n.trFor("quickCapture", "Recording Folder") : I18n.trFor("quickCapture", "Screenshot Folder")
                tooltipSide: "bottom"
                onClicked: root.daemon?.openFolder(root.videoMode ? "video" : "photo")
            }

            DankActionButton {
                iconName: "history"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                iconColor: Theme.surfaceVariantText
                tooltipText: I18n.trFor("quickCapture", "History")
                tooltipSide: "bottom"
                onClicked: root.daemon?.showHistoryCarousel()
            }

            DankActionButton {
                readonly property bool hiding: root.daemon?.hideControlCenter ?? true
                iconName: hiding ? "visibility_off" : "visibility"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                iconColor: hiding ? Theme.surfaceVariantText : Theme.primary
                tooltipText: hiding ? I18n.trFor("quickCapture", "Hide Control Center") : I18n.trFor("quickCapture", "Show Control Center")
                tooltipSide: "bottom"
                onClicked: root.daemon?.toggleHideControlCenter()
            }
        }
    }

    Grid {
        visible: !root.videoMode
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        columns: 4
        spacing: Theme.spacingS

        Repeater {
            model: root.config.modesFor(["region", "full", "window", "last", "scroll", "all", "clipboard", "selectFile"])

            delegate: ModeTile {
                columns: 4
                onTriggered: root.daemon?.capture(modelData.value, "edit")
            }
        }
    }

    Rectangle {
        visible: root.videoMode && root.isRecording
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

                RecordingDot {
                    dotSize: 10
                    paused: root.widget.isPaused
                    blink: root.widget.blinkRecordDot
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.widget.durationText
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Bold
                    font.features: {
                        "tnum": 1
                    }
                    color: root.widget.isPaused ? Theme.warning : Theme.error
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            RecordingTransport {
                anchors.verticalCenter: parent.verticalCenter
                recorder: root.widget.recorder
                buttonSize: 36
                iconSize: Theme.iconSize
            }
        }
    }

    Grid {
        visible: root.videoMode && !root.isRecording
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: headerRow.bottom
        anchors.margins: Theme.spacingM
        anchors.topMargin: Theme.spacingS
        columns: 3
        spacing: Theme.spacingS

        Repeater {
            model: root.config.recordModes

            delegate: ModeTile {
                columns: 3
                onTriggered: root.daemon?.record(modelData.value)
            }
        }
    }
}
