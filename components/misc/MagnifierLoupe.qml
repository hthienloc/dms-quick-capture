import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "../../dms-common"
import "../core/Constants.js" as Constants
import "../core/Helpers.js" as Helpers

Rectangle {
    id: magnifier
    width: Constants.magnifierSize
    height: Constants.magnifierSize
    radius: width / 2
    border.color: Theme.primary
    border.width: 2
    color: "black"
    visible: (window.enableMagnifier && window.isZoomPressed && drawMouseArea.containsMouse) || (window.currentTool === "colorpicker" && drawMouseArea.containsMouse)
    z: 200
    enabled: false

    required property var window
    required property var drawingCanvas
    required property var boardContainer
    required property var bgImage
    required property var staticBgImage
    required property var drawMouseArea

    x: drawingCanvas.mapToItem(boardContainer, window.cursorX * window.editScale, window.cursorY * window.editScale).x - (width / 2)
    y: drawingCanvas.mapToItem(boardContainer, window.cursorX * window.editScale, window.cursorY * window.editScale).y - (height / 2)

    property real zoomFactor: 1.5

    clip: true

    Canvas {
        id: magnifierCanvas
        anchors.fill: parent

        Connections {
            target: drawingCanvas
            function onPaint() { magnifierCanvas.requestPaint(); }
        }

        Connections {
            target: window
            function onCursorXChanged() { magnifierCanvas.requestPaint(); }
            function onCursorYChanged() { magnifierCanvas.requestPaint(); }
        }

        Connections {
            target: magnifier
            function onZoomFactorChanged() { magnifierCanvas.requestPaint(); }
        }

        onPaint: {
            var ctx = magnifierCanvas.getContext("2d");
            ctx.clearRect(0, 0, magnifierCanvas.width, magnifierCanvas.height);

            ctx.save();

            // Clip to circle shape to match the parent circle magnifier
            ctx.beginPath();
            ctx.arc(magnifierCanvas.width / 2, magnifierCanvas.height / 2, magnifierCanvas.width / 2 - 2, 0, 2 * Math.PI);
            ctx.clip();

            // Translate center of magnifier to (0,0)
            ctx.translate(magnifierCanvas.width / 2, magnifierCanvas.height / 2);
            // Scale zoom factor
            ctx.scale(magnifier.zoomFactor, magnifier.zoomFactor);
            // Translate cursor to (0,0)
            ctx.translate(-window.cursorX, -window.cursorY);

            // 1. Draw background image
            if (window.effectiveBackgroundMode !== "none") {
                window.drawEditorBackground(ctx, window.canvasWidth, window.canvasHeight);
                window.drawScreenshotShadow(ctx, magnifier.zoomFactor);
                window.drawScreenshotImage(ctx, bgImage, true);
                
                // 2. Draw annotations
                if (window.showAnnotations) {
                    ctx.save();
                    ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
                    ctx.scale(window.backgroundScaleFactor, window.backgroundScaleFactor);
                    const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                    const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
                    ctx.translate(-cropX, -cropY);
                    for (var i = 0; i < window.strokes.length; i++) {
                        window.drawStroke(ctx, window.strokes[i]);
                    }
                    if (window.currentStroke) {
                        window.drawStroke(ctx, window.currentStroke);
                    }
                    ctx.restore();
                }
            } else {
                if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                    window.drawExportBackgroundLayer(ctx, staticBgImage, false, 1.0);
                }
                if (window.showAnnotations) {
                    for (var i = 0; i < window.strokes.length; i++) {
                        window.drawStroke(ctx, window.strokes[i]);
                    }
                    if (window.currentStroke) {
                        window.drawStroke(ctx, window.currentStroke);
                    }
                }
            }

            ctx.restore();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: Constants.magnifierCrosshairSize
        height: 1.5
        color: Theme.primary
    }
    Rectangle {
        anchors.centerIn: parent
        width: 1.5
        height: Constants.magnifierCrosshairSize
        color: Theme.primary
    }

    // Color details banner at the bottom of the magnifier
    Rectangle {
        id: colorInfoBanner
        visible: window.currentTool === "colorpicker" && window.hoveredColor !== Qt.color("transparent")
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: Constants.magnifierBannerHeight
        color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            // Color preview swatch
            Rectangle {
                width: Constants.magnifierSwatchSize
                height: Constants.magnifierSwatchSize
                radius: Constants.magnifierSwatchRadius
                color: window.hoveredColor
                border.color: Theme.withAlpha(Theme.outline, 0.3)
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0

                StyledText {
                    text: window.formatHexColor(window.hoveredColor).toUpperCase()
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.surfaceText
                }

                StyledText {
                    text: Helpers.formatRgbString(window.hoveredColor)
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
