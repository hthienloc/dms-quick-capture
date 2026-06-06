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
    visible: (rootWindow && drawMouseArea) ? (rootWindow.enableMagnifier && rootWindow.isZoomPressed && drawMouseArea.containsMouse) : false
    z: 200
    enabled: false

    x: (drawingCanvas && boardContainer && rootWindow) ? (drawingCanvas.mapToItem(boardContainer, rootWindow.cursorX, rootWindow.cursorY).x - (width / 2)) : 0
    y: (drawingCanvas && boardContainer && rootWindow) ? (drawingCanvas.mapToItem(boardContainer, rootWindow.cursorX, rootWindow.cursorY).y - (height / 2)) : 0

    property var rootWindow
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
            target: rootWindow
            function onCursorXChanged() { magnifierCanvas.requestPaint(); }
            function onCursorYChanged() { magnifierCanvas.requestPaint(); }
        }

        Connections {
            target: root
            function onZoomFactorChanged() { magnifierCanvas.requestPaint(); }
        }

        onPaint: {
            if (!rootWindow || !drawingCanvas || !staticBgImage) return;

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
            ctx.translate(-rootWindow.cursorX, -rootWindow.cursorY);

            // 1. Draw background image
            if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                ctx.drawImage(staticBgImage, 0, 0, drawingCanvas.width, drawingCanvas.height);
            }

            // 2. Draw annotations
            if (rootWindow.showAnnotations) {
                const options = {
                    roundHighlighter: rootWindow.roundHighlighter,
                    roundRect: rootWindow.roundRect,
                    cornerRadius: Theme.cornerRadius,
                    bgImageItem: rootWindow.bgImageItem,
                    bgImageReady: rootWindow.bgImageItem && rootWindow.bgImageItem.status === Image.Ready,
                    isCurrentStroke: false
                };

                for (var i = 0; i < rootWindow.strokes.length; i++) {
                    StrokePainter.drawStroke(ctx, rootWindow.strokes[i], options);
                }
                if (rootWindow.currentStroke) {
                    StrokePainter.drawStroke(ctx, rootWindow.currentStroke, options);
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
