import QtQuick
import QtQuick.Controls
import "../dms-common"

Rectangle {
    id: magnifier
    width: 160
    height: 160
    radius: 80
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
    required property var Theme

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
            if (window.effectiveBackdropMode !== "none") {
                window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
                window.drawScreenshotShadow(ctx);
                
                // Draw screenshot image directly to bypass nested clip path bug in Qt Canvas
                if (bgImage.status === Image.Ready) {
                    if (window.hasSelection) {
                        ctx.drawImage(bgImage, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, window.screenshotXOffset, window.screenshotYOffset, window.screenshotWidth, window.screenshotHeight);
                    } else {
                        ctx.drawImage(bgImage, window.screenshotXOffset, window.screenshotYOffset, window.screenshotWidth, window.screenshotHeight);
                    }
                }
                
                // 2. Draw annotations
                if (window.showAnnotations) {
                    ctx.save();
                    ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
                    ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
                    const cropX = window.hasSelection ? window.cropRect.x : 0;
                    const cropY = window.hasSelection ? window.cropRect.y : 0;
                    ctx.translate(-cropX, -cropY);
                    for (var i = 0; i < window.strokes.length; i++) {
                        drawingCanvas.drawStroke(ctx, window.strokes[i]);
                    }
                    if (window.currentStroke) {
                        drawingCanvas.drawStroke(ctx, window.currentStroke);
                    }
                    ctx.restore();
                }
            } else {
                if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                    if (window.hasSelection) {
                        ctx.drawImage(staticBgImage, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.canvasWidth, window.canvasHeight);
                    } else {
                        ctx.drawImage(staticBgImage, 0, 0, window.canvasWidth, window.canvasHeight);
                    }
                }
                if (window.showAnnotations) {
                    for (var i = 0; i < window.strokes.length; i++) {
                        drawingCanvas.drawStroke(ctx, window.strokes[i]);
                    }
                    if (window.currentStroke) {
                        drawingCanvas.drawStroke(ctx, window.currentStroke);
                    }
                }
            }

            ctx.restore();
        }
    }

    Rectangle {
        anchors.centerIn: parent
        width: 16
        height: 1.5
        color: Theme.primary
    }
    Rectangle {
        anchors.centerIn: parent
        width: 1.5
        height: 16
        color: Theme.primary
    }

    // Color details banner at the bottom of the magnifier
    Rectangle {
        id: colorInfoBanner
        visible: window.currentTool === "colorpicker" && window.hoveredColor !== Qt.color("transparent")
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 56
        color: Theme.withAlpha(Theme.surfaceContainer, 0.9)
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingS

            // Color preview swatch
            Rectangle {
                width: 20
                height: 20
                radius: 5
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
                    text: {
                        var r = Math.round((window.hoveredColor.r || 0) * 255);
                        var g = Math.round((window.hoveredColor.g || 0) * 255);
                        var b = Math.round((window.hoveredColor.b || 0) * 255);
                        return "RGB: " + r + "," + g + "," + b;
                    }
                    font.pixelSize: 9
                    color: Theme.surfaceVariantText
                }
            }
        }
    }
}
