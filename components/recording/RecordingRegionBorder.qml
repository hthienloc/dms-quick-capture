import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common

Variants {
    id: root

    required property var recordingController

    model: Quickshell.screens
    delegate: PanelWindow {
        id: overlayWin
        required property var modelData
        screen: modelData

        visible: root.recordingController
                 && root.recordingController.isRecording
                 && root.recordingController.showRegionBorder
                 && root.recordingController.activeRecordingMode === "region"
                 && root.recordingController.regionW > 0
                 && root.recordingController.regionH > 0
        color: "transparent"

        WlrLayershell.namespace: "dms:quick-capture-region-overlay"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region {}

        anchors {
            left: true
            right: true
            top: true
            bottom: true
        }

        Rectangle {
            id: borderRect
            readonly property int padding: 4

            // Position relative to current screen, padded outward by 4px so border isn't recorded
            x: (root.recordingController ? root.recordingController.regionX : 0) - padding - modelData.x
            y: (root.recordingController ? root.recordingController.regionY : 0) - padding - modelData.y
            width: (root.recordingController ? root.recordingController.regionW : 0) + (padding * 2)
            height: (root.recordingController ? root.recordingController.regionH : 0) + (padding * 2)
            color: "transparent"

            visible: (x + width > 0) && (x < modelData.width) && (y + height > 0) && (y < modelData.height)

            Canvas {
                id: borderCanvas
                anchors.fill: parent

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    ctx.strokeStyle = Theme.primary;
                    ctx.lineWidth = 2.5;
                    ctx.setLineDash([6, 5]);

                    var strokeOffset = 1.25;
                    var bx = strokeOffset;
                    var by = strokeOffset;
                    var bw = width - (strokeOffset * 2);
                    var bh = height - (strokeOffset * 2);
                    var r = 8;

                    if (bw < r * 2 || bh < r * 2) {
                        r = Math.max(0, Math.min(bw, bh) / 2);
                    }

                    ctx.beginPath();
                    ctx.moveTo(bx + r, by);
                    ctx.lineTo(bx + bw - r, by);
                    ctx.quadraticCurveTo(bx + bw, by, bx + bw, by + r);
                    ctx.lineTo(bx + bw, by + bh - r);
                    ctx.quadraticCurveTo(bx + bw, by + bh, bx + bw - r, by + bh);
                    ctx.lineTo(bx + r, by + bh);
                    ctx.quadraticCurveTo(bx, by + bh, bx, by + bh - r);
                    ctx.lineTo(bx, by + r);
                    ctx.quadraticCurveTo(bx, by, bx + r, by);
                    ctx.closePath();
                    ctx.stroke();
                }

                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onVisibleChanged: {
                    if (visible) requestPaint();
                }

                Connections {
                    target: Theme
                    function onPrimaryChanged() { borderCanvas.requestPaint(); }
                }

                Connections {
                    target: root.recordingController
                    function onRegionGeometryChanged() { borderCanvas.requestPaint(); }
                }
            }

            readonly property bool isPaused: root.recordingController ? root.recordingController.isPaused : false

            opacity: isPaused ? 0.15 : pulseValue

            Behavior on opacity {
                enabled: borderRect.isPaused
                NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
            }

            property real pulseValue: 0.15

            SequentialAnimation on pulseValue {
                running: borderRect.visible && !borderRect.isPaused
                loops: Animation.Infinite
                NumberAnimation { from: 0.15; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 0.6; to: 0.15; duration: 1500; easing.type: Easing.InOutQuad }
            }
        }
    }
}
