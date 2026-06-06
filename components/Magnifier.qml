import QtQuick
import qs.Common
import "StrokePainter.js" as StrokePainter

Rectangle {
    id: root
    width: 140
    height: 140
    radius: 70
    border.color: Theme.primary
    border.width: 2
    color: "black"
    visible: window.enableMagnifier && window.isZoomPressed && drawMouseArea.containsMouse
    z: 200
    enabled: false

    x: drawingCanvas.mapToItem(boardContainer, window.cursorX, window.cursorY).x - (width / 2)
    y: drawingCanvas.mapToItem(boardContainer, window.cursorX, window.cursorY).y - (height / 2)

    property var window
    property var drawingCanvas
    property var staticBgImage
    property var boardContainer
    property var drawMouseArea

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
            target: root
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
            ctx.scale(root.zoomFactor, root.zoomFactor);
            // Translate cursor to (0,0)
            ctx.translate(-window.cursorX, -window.cursorY);

            // 1. Draw background image
            if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                ctx.drawImage(staticBgImage, 0, 0, drawingCanvas.width, drawingCanvas.height);
            }

            // 2. Draw annotations
            if (window.showAnnotations) {
                const options = {
                    roundHighlighter: window.roundHighlighter,
                    roundRect: window.roundRect,
                    cornerRadius: Theme.cornerRadius,
                    bgImageItem: window.bgImageItem,
                    bgImageReady: window.bgImageItem && window.bgImageItem.status === Image.Ready,
                    isCurrentStroke: false
                };

                for (var i = 0; i < window.strokes.length; i++) {
                    StrokePainter.drawStroke(ctx, window.strokes[i], options);
                }
                if (window.currentStroke) {
                    StrokePainter.drawStroke(ctx, window.currentStroke, options);
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
}
