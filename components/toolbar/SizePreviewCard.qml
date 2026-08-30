import QtQuick
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "../../dms-common"
import "../core/Constants.js" as Constants
import "../core/Helpers.js" as Helpers

Rectangle {
    id: sizePreviewItem

    required property var window
    required property var drawingCanvas

    readonly property point mappedPos: (drawingCanvas && window.boardContainerItem) ? drawingCanvas.mapToItem(window.boardContainerItem, window.previewX, window.previewY) : Qt.point(window.previewX, window.previewY)

    visible: window.showSizePreview
    x: mappedPos.x - (width / 2)
    y: mappedPos.y - (height / 2)

    readonly property bool _showShape: window.effectiveTool !== "spotlight"

    width: _showShape ? shapeWidth : 0
    height: width
    radius: _showShape ? shapeRadius : 0
    color: "transparent"
    border.color: _showShape ? shapeBorderColor : "transparent"
    border.width: _showShape ? 1.5 : 0
    z: 200

    readonly property real shapeWidth: {
        let base = window.activeIntensity;
        const tool = window.effectiveTool;
        const meta = Constants.getToolMeta(tool);

        if (meta.previewFixedWidth !== undefined) {
            base = meta.previewFixedWidth;
        } else if (meta.previewMultiplier) {
            base = window.activeIntensity * meta.previewMultiplier;
        }
        if (meta.previewClampMin !== undefined) {
            base = Helpers.clamp(base, meta.previewClampMin, meta.previewClampMax);
        }

        if (tool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                base = bw * 2;
            }
        }
        return base * window.editScale * (drawingCanvas ? drawingCanvas.scale : 1.0);
    }
    readonly property real shapeRadius: {
        const tool = window.effectiveTool;
        if (tool === "highlighter") return window.roundHighlighter ? shapeWidth / 2 : 0;
        if (tool === "spotlight" || tool === "rect" || tool === "redact") return window.roundRect ? (Theme.cornerRadius * window.editScale * (drawingCanvas ? drawingCanvas.scale : 1.0)) : 0;
        if (tool === "pixelate" || tool === "text") return 0;
        if (tool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                return shapeWidth / 2;
            }
            return 0;
        }
        return shapeWidth / 2;
    }
    readonly property color shapeBorderColor: {
        if (window.effectiveTool === "callout") {
            if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                return Theme.primary;
            }
            return "transparent";
        }
        if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "stamp") {
            return "transparent";
        }
        return Theme.primary;
    }

    StyledText {
        id: valueLabel
        anchors.top: parent.bottom
        anchors.topMargin: 12
        anchors.horizontalCenter: parent.horizontalCenter
        text: {
            if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "callout") {
                if (window.calloutDestDragging) {
                    return window.selectedStroke.width + "%";
                } else {
                    const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                    return bw + "px";
                }
            }
            const tool = window.effectiveTool;
            const meta = Constants.getToolMeta(tool);
            return window.activeIntensity + meta.unit;
        }

        color: Theme.primary
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
    }
}
