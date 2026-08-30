import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "Helpers.js" as Helpers
import "Constants.js" as Constants

MouseArea {
    id: drawMouseArea
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.XButton1 | Qt.XButton2

    required property var window
    required property var drawingCanvas
    required property var previewTimer
    required property var magnifier
    required property var radialMenu
    required property var textInputDialog
    required property var moreToolsMenu
    required property var stampOptionsToolbar
    required property var textOptionsToolbar
    required property var lineOptionsToolbar
    required property var arrowOptionsToolbar
    required property var redactOptionsToolbar
    required property var calloutOptionsToolbar

    property string activeHandle: "none"
    property string hoveredHandle: "none"
    property int hoveredStrokeIdx: -1
    property string shiftLockAxis: "none"
    property real originalRotation: 0
    property point rotationCenter: Qt.point(0, 0)
    property real rotationStartAngle: 0
    property point cropMoveStart: Qt.point(0, 0)
    property rect cropMoveOrigin: Qt.rect(0, 0, 0, 0)

    // Pen real-time smoothing state (exponential moving average)
    property real penSmoothX: 0
    property real penSmoothY: 0

    function resetInteractionState() {
        activeHandle = "none";
        hoveredHandle = "none";
        hoveredStrokeIdx = -1;
        shiftLockAxis = "none";
        originalRotation = 0;
        rotationCenter = Qt.point(0, 0);
        rotationStartAngle = 0;
        cropMoveStart = Qt.point(0, 0);
        cropMoveOrigin = Qt.rect(0, 0, 0, 0);
        penSmoothX = 0;
        penSmoothY = 0;
    }

    function getAbsolutePoint(mx, my) {
        let rx = mx / window.editScale;
        let ry = my / window.editScale;
        if (window.effectiveBackgroundMode !== "none") {
            rx = (rx - window.screenshotXOffset) / window.backgroundScaleFactor;
            ry = (ry - window.screenshotYOffset) / window.backgroundScaleFactor;
        }
        if (window.hasActiveCropSelection) {
            return Qt.point(rx + window.cropRect.x, ry + window.cropRect.y);
        }
        return Qt.point(rx, ry);
    }

    function updateSelectHover(mx, my) {
        if (window.pastePreviewActive) {
            hoveredStrokeIdx = -1;
            hoveredHandle = "none";
            return;
        }

        if (window.currentTool !== "select") {
            hoveredStrokeIdx = -1;
            hoveredHandle = "none";
            return;
        }

        const absPt = getAbsolutePoint(mx, my);
        hoveredHandle = window.selectedStroke
            ? window.getSelectedStrokeHandleAt(absPt.x, absPt.y)
            : "none";
        hoveredStrokeIdx = hoveredHandle !== "none"
            ? window.strokes.indexOf(window.selectedStroke)
            : window.findStrokeAt(absPt.x, absPt.y);
    }

    function updateCalloutDestinationDrag(stroke, pt) {
        if (stroke.tool !== "callout" || stroke.points.length !== 4) {
            window.calloutDestDragging = false;
            return;
        }

        const dstP0 = stroke.points[2];
        const dstP1 = stroke.points[3];
        window.calloutDestDragging = pt.x >= dstP0.x && pt.x <= dstP1.x
            && pt.y >= dstP0.y && pt.y <= dstP1.y;
    }

    // Applies the shared rectangle resize rules used by shapes and callouts.
    function resizeRectEndpoints(p0, p1, handle, dx, dy, keepSquare) {
        let x1 = Math.min(p0.x, p1.x);
        let y1 = Math.min(p0.y, p1.y);
        let x2 = Math.max(p0.x, p1.x);
        let y2 = Math.max(p0.y, p1.y);
        const minSize = 10;

        switch (handle) {
        case "tl": x1 = Math.min(x1 + dx, x2 - minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
        case "tr": x2 = Math.max(x2 + dx, x1 + minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
        case "bl": x1 = Math.min(x1 + dx, x2 - minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
        case "br": x2 = Math.max(x2 + dx, x1 + minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
        case "tc": y1 = Math.min(y1 + dy, y2 - minSize); break;
        case "bc": y2 = Math.max(y2 + dy, y1 + minSize); break;
        case "lc": x1 = Math.min(x1 + dx, x2 - minSize); break;
        case "rc": x2 = Math.max(x2 + dx, x1 + minSize); break;
        }

        if (keepSquare && ["tl", "tr", "bl", "br"].indexOf(handle) !== -1) {
            const side = Math.max(x2 - x1, y2 - y1);
            if (handle === "br") { x2 = x1 + side; y2 = y1 + side; }
            else if (handle === "tl") { x1 = x2 - side; y1 = y2 - side; }
            else if (handle === "tr") { x2 = x1 + side; y1 = y2 - side; }
            else if (handle === "bl") { x1 = x2 - side; y2 = y1 + side; }
        }

        return {
            start: Qt.point(p0.x > p1.x ? x2 : x1, p0.y > p1.y ? y2 : y1),
            end: Qt.point(p0.x > p1.x ? x1 : x2, p0.y > p1.y ? y1 : y2)
        };
    }

    // Snaps a point around a fixed point to the nearest 15-degree direction.
    function snapPointToAngle(point, fixed) {
        const dx = point.x - fixed.x;
        const dy = point.y - fixed.y;
        const length = Math.sqrt(dx * dx + dy * dy);
        if (length === 0) return point;
        const snapStep = Math.PI / 12;
        const angle = Math.atan2(dy, dx);
        const snapped = Math.round(angle / snapStep) * snapStep;
        return Qt.point(fixed.x + length * Math.cos(snapped), fixed.y + length * Math.sin(snapped));
    }

    function updateCurrentStrokeEndpoint(point) {
        const points = window.currentStroke.points;
        if (points.length > 1) {
            points[points.length - 1] = point;
        } else {
            points.push(point);
        }
    }

    /**
     * Calculates the normalized rectangle covered by a drag.
     * @param {object} start - Drag start point with x and y properties.
     * @param {number} x - Current pointer X coordinate.
     * @param {number} y - Current pointer Y coordinate.
     * @returns {object} Rectangle with x, y, width and height properties.
     */
    function getDragRect(start, x, y) {
        return {
            x: Math.min(start.x, x),
            y: Math.min(start.y, y),
            width: Math.abs(x - start.x),
            height: Math.abs(y - start.y)
        };
    }

    function constrainCropSquarePoint(start, point) {
        const dx = point.x - start.x;
        const dy = point.y - start.y;
        const sx = dx < 0 ? -1 : 1;
        const sy = dy < 0 ? -1 : 1;
        let side = Math.max(Math.abs(dx), Math.abs(dy));
        const maxX = sx < 0 ? start.x : window.screenshotWidth - start.x;
        const maxY = sy < 0 ? start.y : window.screenshotHeight - start.y;
        side = Math.min(side, maxX, maxY);
        return Qt.point(start.x + sx * side, start.y + sy * side);
    }

    function handleCropPosition(origX, origY, keepSquare) {
        const ox = Helpers.clamp(origX, 0, window.screenshotWidth);
        const oy = Helpers.clamp(origY, 0, window.screenshotHeight);
        const nextHoveredHandle = window.getHoveredHandle(ox, oy);
        if (hoveredHandle !== nextHoveredHandle) {
            hoveredHandle = nextHoveredHandle;
            drawingCanvas.requestPaint();
        }
        if (window.activeHandle === "new") {
            const end = keepSquare
                ? constrainCropSquarePoint(window.selectStart, Qt.point(ox, oy))
                : Qt.point(ox, oy);
            const rect = getDragRect(window.selectStart, end.x, end.y);
            window.cropRect = window.clampCropRect(rect.x, rect.y, rect.width, rect.height);
            drawingCanvas.requestPaint();
            return;
        }

        if (window.activeHandle === "move") {
            const dx = ox - cropMoveStart.x;
            const dy = oy - cropMoveStart.y;
            window.cropRect = window.clampCropRect(
                cropMoveOrigin.x + dx,
                cropMoveOrigin.y + dy,
                cropMoveOrigin.width,
                cropMoveOrigin.height);
            drawingCanvas.requestPaint();
            return;
        }

        if (window.activeHandle !== "none" && window.activeHandle !== "new") {
            const cr = window.cropRect;
            let newX = cr.x;
            let newY = cr.y;
            let newW = cr.width;
            let newH = cr.height;
            if (["tl", "tr", "bl", "br"].indexOf(window.activeHandle) !== -1) {
                const point = keepSquare
                    ? constrainCropSquarePoint(
                        Qt.point(cr.x + (window.activeHandle.indexOf("l") !== -1 ? cr.width : 0),
                            cr.y + (window.activeHandle.indexOf("t") !== -1 ? cr.height : 0)),
                        Qt.point(ox, oy))
                    : Qt.point(ox, oy);
                if (window.activeHandle === "tl") {
                    newX = Math.min(point.x, cr.x + cr.width - 10);
                    newY = Math.min(point.y, cr.y + cr.height - 10);
                    newW = cr.x + cr.width - newX;
                    newH = cr.y + cr.height - newY;
                } else if (window.activeHandle === "tr") {
                    newY = Math.min(point.y, cr.y + cr.height - 10);
                    newW = Math.max(10, point.x - cr.x);
                    newH = cr.y + cr.height - newY;
                } else if (window.activeHandle === "bl") {
                    newX = Math.min(point.x, cr.x + cr.width - 10);
                    newW = cr.x + cr.width - newX;
                    newH = Math.max(10, point.y - cr.y);
                } else {
                    newW = Math.max(10, point.x - cr.x);
                    newH = Math.max(10, point.y - cr.y);
                }
            } else if (window.activeHandle === "tc") {
                newY = Math.min(oy, cr.y + cr.height - 10);
                newH = cr.y + cr.height - newY;
            } else if (window.activeHandle === "bc") {
                newH = Math.max(10, oy - cr.y);
            } else if (window.activeHandle === "lc") {
                newX = Math.min(ox, cr.x + cr.width - 10);
                newW = cr.x + cr.width - newX;
            } else if (window.activeHandle === "rc") {
                newW = Math.max(10, ox - cr.x);
            }
            window.cropRect = window.clampCropRect(newX, newY, newW, newH);
            drawingCanvas.requestPaint();
        }
    }

    function handleScanPosition(mouse) {
        if (window.activeHandle !== "ocr" && window.activeHandle !== "qr") return;
        const ox = mouse.x / window.editScale;
        const oy = mouse.y / window.editScale;
        const rect = getDragRect(window.selectStart, ox, oy);
        window.ocrRect = Qt.rect(rect.x, rect.y, rect.width, rect.height);
        drawingCanvas.requestPaint();
    }

    function moveSelectedStroke(dx, dy, moveCalloutDestination) {
        if (!window.selectedStroke || window.originalPoints.length === 0) return;
        const newPoints = [];
        if (moveCalloutDestination && window.selectedStroke.tool === "callout" &&
            window.calloutDestDragging && window.originalPoints.length === 4) {
            for (let i = 0; i < window.originalPoints.length; i++) {
                newPoints.push(Qt.point(window.originalPoints[i].x, window.originalPoints[i].y));
            }
            newPoints[2] = Qt.point(window.originalPoints[2].x + dx, window.originalPoints[2].y + dy);
            newPoints[3] = Qt.point(window.originalPoints[3].x + dx, window.originalPoints[3].y + dy);
        } else {
            for (let i = 0; i < window.originalPoints.length; i++) {
                newPoints.push(Qt.point(window.originalPoints[i].x + dx, window.originalPoints[i].y + dy));
            }
        }
        window.selectedStroke.points = newPoints;
        if (window.selectedStroke.tool === "redact") {
            window.selectedStroke.cachedCleanColor = undefined;
        }
    }

    function handleSelectPosition(mouse, absPt) {
        if (window.selectedStroke) {
            hoveredHandle = window.getSelectedStrokeHandleAt(absPt.x, absPt.y);

            if (window.activeHandle === "move" && window.originalPoints.length > 0 && (mouse.buttons & Qt.LeftButton)) {
                moveSelectedStroke(absPt.x - window.pressCoords.x, absPt.y - window.pressCoords.y, false);
            } else if (window.activeHandle === "none" && window.originalPoints.length > 0 && (mouse.buttons & Qt.LeftButton)) {
                let dx = absPt.x - window.pressCoords.x;
                let dy = absPt.y - window.pressCoords.y;

                if (mouse.modifiers & Qt.ShiftModifier) {
                    if (shiftLockAxis === "none") {
                        const threshold = 4;
                        if (Math.abs(dx) > threshold || Math.abs(dy) > threshold) {
                            shiftLockAxis = Math.abs(dx) > Math.abs(dy) ? "horizontal" : "vertical";
                        }
                    }
                    if (shiftLockAxis === "horizontal") dy = 0;
                    else if (shiftLockAxis === "vertical") dx = 0;
                } else {
                    shiftLockAxis = "none";
                }

                moveSelectedStroke(dx, dy, true);
            } else if (window.activeHandle !== "none" && window.originalPoints.length > 0 && (mouse.buttons & Qt.LeftButton)) {
                const dx = absPt.x - window.pressCoords.x;
                const dy = absPt.y - window.pressCoords.y;
                const orig = window.originalPoints;
                const tool = window.selectedStroke.tool;

                if (window.activeHandle === "rotate" && tool === "text") {
                    const currentAngle = Math.atan2(absPt.y - rotationCenter.y, absPt.x - rotationCenter.x);
                    let angle = currentAngle - rotationStartAngle;
                    if (mouse.modifiers & Qt.ShiftModifier) {
                        angle = Math.round(angle / (Math.PI / 12)) * (Math.PI / 12);
                    }
                    window.selectedStroke.rotation = window.originalRotation + angle * 180 / Math.PI;
                } else if (tool === "rect" || tool === "ellipse" || tool === "redact" ||
                    tool === "pixelate" || tool === "spotlight") {
                    const resized = resizeRectEndpoints(orig[0], orig[orig.length - 1], window.activeHandle, dx, dy, mouse.modifiers & Qt.ShiftModifier);
                    const newPoints = [...window.selectedStroke.points];
                    newPoints[0] = resized.start;
                    newPoints[newPoints.length - 1] = resized.end;
                    window.selectedStroke.points = newPoints;
                    if (tool === "redact") window.selectedStroke.cachedCleanColor = undefined;
                } else if (tool === "line" || tool === "arrow" || tool === "highlighter" || (tool === "text" && window.selectedStroke.isSpeechBubble)) {
                    const newPoints = [...window.selectedStroke.points];
                    let targetIdx = -1;
                    let fixedIdx = -1;
                    if (window.activeHandle === "start") {
                        targetIdx = 0;
                        fixedIdx = orig.length - 1;
                    } else if (window.activeHandle === "end") {
                        targetIdx = orig.length - 1;
                        fixedIdx = 0;
                    }
                    if (targetIdx !== -1) {
                        let newPt = Qt.point(orig[targetIdx].x + dx, orig[targetIdx].y + dy);
                        if (mouse.modifiers & Qt.ShiftModifier) newPt = snapPointToAngle(newPt, orig[fixedIdx]);
                        newPoints[targetIdx] = newPt;
                    }
                    window.selectedStroke.points = newPoints;
                } else if (tool === "callout" && window.activeHandle && window.activeHandle.indexOf("src_") === 0 && orig.length === 4) {
                    const resized = resizeRectEndpoints(orig[0], orig[1], window.activeHandle.slice(4), dx, dy, mouse.modifiers & Qt.ShiftModifier);
                    const newPoints = [...window.selectedStroke.points];
                    newPoints[0] = resized.start;
                    newPoints[1] = resized.end;
                    const zoom = window.selectedStroke.width / 100.0;
                    newPoints[3] = Qt.point(newPoints[2].x + Math.abs(resized.end.x - resized.start.x) * zoom,
                        newPoints[2].y + Math.abs(resized.end.y - resized.start.y) * zoom);
                    window.selectedStroke.points = newPoints;
                } else if (tool === "stamp") {
                    const newPoints = [...window.selectedStroke.points];
                    const hasLeader = window.selectedStroke.hasLeaderLine && window.selectedStroke.points.length >= 2;
                    if (window.activeHandle === "anchor" && hasLeader) {
                        let newPt = Qt.point(orig[0].x + dx, orig[0].y + dy);
                        if (mouse.modifiers & Qt.ShiftModifier) newPt = snapPointToAngle(newPt, orig[1]);
                        newPoints[0] = newPt;
                    } else if (window.activeHandle === "stamp") {
                        const idx = hasLeader ? 1 : 0;
                        let newPt = Qt.point(orig[idx].x + dx, orig[idx].y + dy);
                        if (idx === 1 && (mouse.modifiers & Qt.ShiftModifier)) newPt = snapPointToAngle(newPt, orig[0]);
                        newPoints[idx] = newPt;
                    } else if (window.activeHandle === "stampBody") {
                        for (let i = 0; i < orig.length; i++) {
                            newPoints[i] = Qt.point(orig[i].x + dx, orig[i].y + dy);
                        }
                    }
                    window.selectedStroke.points = newPoints;
                }
            }
            if (window.originalPoints.length === 0 || !(mouse.buttons & Qt.LeftButton)) {
                hoveredStrokeIdx = hoveredHandle !== "none"
                    ? window.strokes.indexOf(window.selectedStroke)
                    : window.findStrokeAt(absPt.x, absPt.y);
            }
            drawingCanvas.requestPaint();
        } else {
            hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
            hoveredHandle = "none";
        }
    }

    function handleDrawingPosition(mouse, absPt) {
        if (!window.currentStroke) return;

        if (window.currentTool === "pen") {
            if (mouse.modifiers & Qt.ShiftModifier) {
                if (window.currentStroke.points.length > 1) {
                    window.currentStroke.points = [window.currentStroke.points[0], absPt];
                } else {
                    window.currentStroke.points.push(absPt);
                }
            } else {
                const alpha = Math.min(1, Math.max(0, window.penSmoothingAlpha));
                penSmoothX = alpha * absPt.x + (1 - alpha) * penSmoothX;
                penSmoothY = alpha * absPt.y + (1 - alpha) * penSmoothY;
                window.currentStroke.points.push(Qt.point(penSmoothX, penSmoothY));
            }
        } else if (window.currentTool === "redact") {
            let finalPt = absPt;
            if (mouse.modifiers & Qt.ShiftModifier && window.currentStroke.points[0]) {
                finalPt = Helpers.constrainSquarePoint(window.currentStroke.points[0], absPt, Qt);
            }
            updateCurrentStrokeEndpoint(finalPt);
        } else if (window.currentTool === "rect" || window.currentTool === "ellipse" || window.currentTool === "arrow" || window.currentTool === "line"
                   || window.currentTool === "pixelate" || window.currentTool === "highlighter" || window.currentTool === "spotlight" || window.currentTool === "callout" || window.currentTool === "text") {
            let finalPt = absPt;
            if (mouse.modifiers & Qt.ShiftModifier && (window.currentTool === "line" || window.currentTool === "arrow" || window.currentTool === "highlighter")) {
                const p0 = window.currentStroke.points[0];
                if (p0) finalPt = snapPointToAngle(absPt, p0);
            } else if (mouse.modifiers & Qt.ShiftModifier && (window.currentTool === "ellipse" || window.currentTool === "rect" || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "spotlight" || window.currentTool === "callout")) {
                if (window.currentStroke.points[0]) {
                    finalPt = Helpers.constrainSquarePoint(window.currentStroke.points[0], absPt, Qt);
                }
            }

            updateCurrentStrokeEndpoint(finalPt);

            if (window.currentTool === "text") {
                const p0 = window.currentStroke.points[0];
                const dist = Helpers.distance(p0, finalPt);
                window.currentStroke.isSpeechBubble = dist > Constants.textBubbleDragThreshold / window.editScale;
            }
        } else if (window.currentTool === "stamp") {
            const p0 = window.currentStroke.points[0];
            if (p0) {
                let finalPt = absPt;
                const dist = Helpers.distance(p0, absPt);
                if (dist > Constants.textBubbleDragThreshold / window.editScale) {
                    window.currentStroke.hasLeaderLine = true;

                    if (mouse.modifiers & Qt.ShiftModifier) {
                        finalPt = snapPointToAngle(absPt, p0);
                    }

                    if (window.currentStroke.points.length > 1) {
                        window.currentStroke.points[1] = finalPt;
                    } else {
                        window.currentStroke.points.push(finalPt);
                    }
                } else {
                    window.currentStroke.hasLeaderLine = false;
                    if (window.currentStroke.points.length > 1) {
                        window.currentStroke.points = [p0];
                    }
                }
            }
        }

        drawingCanvas.requestPaint();
    }

    /**
     * Returns the wheel-step multiplier for a tool's intensity setting.
     * @param {string} tool - Active tool name.
     * @returns {number} Intensity multiplier.
     */
    function getIntensityMultiplier(tool) {
        if (tool === "text" || tool === "pixelate") return 2;
        if (tool === "spotlight") return 5;
        if (tool === "callout") return 10;
        return 1;
    }

    onPositionChanged: (mouse) => {
         if (pressed && (mouse.buttons & Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier) && (mouse.modifiers & Qt.ShiftModifier)) {
             const currentPt = drawMouseArea.mapToItem(window.boardContainerItem, mouse.x, mouse.y);
             if (window.lastPanMouse.x === 0 && window.lastPanMouse.y === 0) {
                 window.lastPanMouse = currentPt;
             } else {
                 const dx = currentPt.x - window.lastPanMouse.x;
                 const dy = currentPt.y - window.lastPanMouse.y;
                 window.updatePanOffset(window.userPanX + dx, window.userPanY + dy);
                 window.lastPanMouse = currentPt;
             }
             return;
         }

         const origX = mouse.x / window.editScale;
         const origY = mouse.y / window.editScale;
         window.cursorX = origX;
         window.cursorY = origY;
         if (window.pastePreviewActive && window.activeCanvas) {
             hoveredStrokeIdx = -1;
             hoveredHandle = "none";
             window.activeCanvas.requestPaint();
             return;
         }
         if (window.currentTool === "colorpicker") {
             window.hoveredColor = window.sampleCanvasColor(mouse.x, mouse.y);
         };

        const absPt = getAbsolutePoint(mouse.x, mouse.y);

        if (window.currentTool === "select") {
            handleSelectPosition(mouse, absPt);
            return;
        }

        if (window.currentTool === "crop") {
            handleCropPosition(origX, origY, !!(mouse.modifiers & Qt.ShiftModifier));
            return;
        } else if (window.currentTool === "ocr" || window.currentTool === "qr") {
            handleScanPosition(mouse);
            return;
        } else {
            handleDrawingPosition(mouse, absPt);
        }
    }

    cursorShape: {
        if (window.lastPanMouse.x !== 0 || window.lastPanMouse.y !== 0) {
            return Qt.ClosedHandCursor;
        }
        if (window.pastePreviewActive) {
            return Qt.ClosedHandCursor;
        }

        const h = (window.activeHandle !== "none" && window.activeHandle !== "new") ? window.activeHandle : hoveredHandle;
        const hs = (h && h.length > 4) ? h.slice(-3) : h;
        if (h === "tl" || h === "br" || hs === "_tl" || hs === "_br") return Qt.SizeFDiagCursor;
        if (h === "tr" || h === "bl" || hs === "_tr" || hs === "_bl") return Qt.SizeBDiagCursor;
        if (h === "tc" || h === "bc" || hs === "_tc" || hs === "_bc") return Qt.SplitVCursor;
        if (h === "lc" || h === "rc" || hs === "_lc" || hs === "_rc") return Qt.SplitHCursor;
        if (h === "rotate") return Qt.SizeAllCursor;
        if (h === "move") return Qt.SizeAllCursor;
        if (h === "stamp" && window.selectedStroke && window.selectedStroke.tool === "stamp" && window.selectedStroke.hasLeaderLine) return Qt.SizeAllCursor;
        if (h === "stampBody") return pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
        if (h === "stamp") return pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor;
        if (h === "start" || h === "end" || h === "anchor") return Qt.SizeAllCursor;
        if (window.currentTool === "colorpicker") {
            return Qt.CrossCursor;
        }
        if (window.currentTool === "select") {
            return pressed && window.selectedStroke ? Qt.ClosedHandCursor : (hoveredStrokeIdx !== -1 ? Qt.OpenHandCursor : Qt.ArrowCursor);
        }
        return Qt.CrossCursor;
    }

    onPressed: (mouse) => {
        shiftLockAxis = "none";
        if (window.modalFocusScope) {
            window.modalFocusScope.forceActiveFocus();
        }

        if ((mouse.button === Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier) && (mouse.modifiers & Qt.ShiftModifier)) {
            window.lastPanMouse = drawMouseArea.mapToItem(window.boardContainerItem, mouse.x, mouse.y);
            return;
        }

        if (moreToolsMenu.opened) {
            moreToolsMenu.close();
            return;
        }

        if (window.isTyping) {
            window.commitTypingText();
            return;
        }

        if (mouse.button === Qt.BackButton || mouse.button === Qt.XButton1) {
            window.performUndo();
            return;
        }

        if (mouse.button === Qt.ForwardButton || mouse.button === Qt.XButton2) {
            window.performRedo();
            return;
        }

        if (mouse.button === Qt.RightButton) {
            const mapped = drawMouseArea.mapToItem(radialMenu.parent, mouse.x, mouse.y);
            if (mouse.modifiers & Qt.ShiftModifier) {
                radialMenu.close();
                if (window.currentTool === "stamp") {
                    stampOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                } else if (window.currentTool === "text") {
                    textOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                } else if (window.currentTool === "line") {
                    lineOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                } else if (window.currentTool === "arrow") {
                    arrowOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                } else if (window.currentTool === "redact") {
                    redactOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                } else if (window.currentTool === "callout") {
                    calloutOptionsToolbar.open(mapped.x, mapped.y);
                    return;
                }
            }
            radialMenu.open(mapped.x, mapped.y);
            return;
        }

        if (mouse.button === Qt.MiddleButton) {
            const absPt = getAbsolutePoint(mouse.x, mouse.y);
            const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
            if (strokeIdx !== -1) {
                const list = [...window.strokes];
                const removed = list.splice(strokeIdx, 1);
                window.strokes = list;
                if (window.selectedStroke === removed[0]) {
                    window.deselectStrokeForEditing(true);
                }
                drawingCanvas.requestPaint();
            }
            return;
        }

        const absPt = getAbsolutePoint(mouse.x, mouse.y);
        if (mouse.button === Qt.LeftButton && window.pastePreviewActive) {
            window.performPasteAction();
            return;
        }

        if (window.currentTool === "select") {
            // Check if clicking on a resize handle
            if (window.selectedStroke) {
                const sh = window.getSelectedStrokeHandleAt(absPt.x, absPt.y);
                if (sh !== "none") {
                    window.activeHandle = sh;
                    window.pressCoords = absPt;
                    window.originalPoints = window.copyStrokePoints(window.selectedStroke.points);
                    window.originalRotation = Number(window.selectedStroke.rotation) || 0;
                    if (sh === "rotate") {
                        const bounds = window.measureTextBounds(window.selectedStroke);
                        const frame = Helpers.getTextTransformFrame(window.selectedStroke, bounds);
                        rotationCenter = Qt.point(frame.center.x, frame.center.y);
                        rotationStartAngle = Math.atan2(absPt.y - frame.center.y, absPt.x - frame.center.x);
                    }
                    drawingCanvas.requestPaint();
                    return;
                }

                if (mouse.modifiers & Qt.ControlModifier) {
                    window.activeHandle = "move";
                    window.pressCoords = absPt;
                    window.originalPoints = window.copyStrokePoints(window.selectedStroke.points);
                    drawingCanvas.requestPaint();
                    return;
                }
            }

            const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
            if (strokeIdx === -1) {
                // Clicked empty space — deselect
                if (window.selectedStroke) {
                    window.deselectStrokeForEditing(true);
                }
                hoveredHandle = "none";
                drawingCanvas.requestPaint();
                return;
            }

            if (strokeIdx !== -1) {
                const stroke = window.strokes[strokeIdx];
                
                if (stroke.tool === "pixelate" && stroke.randomSeed === undefined) {
                    stroke.randomSeed = Math.floor(Math.random() * 2147483647);
                }

                window.selectStrokeForEditing(stroke, !window.selectedStroke);
                updateCalloutDestinationDrag(stroke, absPt);
                window.pressCoords = absPt;
                if (mouse.modifiers & Qt.ControlModifier) {
                    window.activeHandle = "move";
                }
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
            return;
        }

         if (window.currentTool === "colorpicker") {
              if (mouse.button === Qt.LeftButton) {
                  const pickedColor = window.sampleCanvasColor(mouse.x, mouse.y);
                  if (window.backgroundColorPickingSlot !== "none") {
                      if (window.backgroundColorPickingSlot === "solid") {
                          window.backgroundSolidColor = pickedColor;
                      } else if (window.backgroundColorPickingSlot === "start") {
                          window.backgroundGradientStart = pickedColor;
                      } else if (window.backgroundColorPickingSlot === "end") {
                          window.backgroundGradientEnd = pickedColor;
                      }
                      window.hasUserCustomizedBackground = true;
                      window.backgroundColorPickingSlot = "none";
                      window.currentTool = "background";
                  } else {
                      const hexStr = window.formatHexColor(pickedColor).toUpperCase();
                      if (window.colorPickerMode === "copy") {
                          Quickshell.execDetached(["dms", "cl", "copy", hexStr]);
                          if (typeof ToastService !== "undefined" && ToastService) {
                              ToastService.showInfo(I18n.tr("Color copied to clipboard: %1").arg(hexStr));
                          }
                      } else {
                           window.updateColorSlot(window.activeColorSlotIndex, pickedColor);
                       }
                       window.currentTool = window.lastActiveTool;
                  }
              }
              return;
          }

        if (window.currentTool === "crop") {
            const ox = mouse.x / window.editScale;
            const oy = mouse.y / window.editScale;
            const pw = window.screenshotWidth;
            const ph = window.screenshotHeight;
            const handle = window.getHoveredHandle(ox, oy);
            if (handle !== "none") {
                window.activeHandle = handle;
                return;
            }

            if ((mouse.modifiers & Qt.ControlModifier) && window.hasSelection) {
                window.activeHandle = "move";
                cropMoveStart = Qt.point(ox, oy);
                cropMoveOrigin = window.cropRect;
                drawingCanvas.requestPaint();
                return;
            }

            // Drag-to-select crop area
            window.activeHandle = "new";
            window.selectStart = Qt.point(Helpers.clamp(ox, 0, pw), Helpers.clamp(oy, 0, ph));
            window.cropRect = Qt.rect(window.selectStart.x, window.selectStart.y, 0, 0);
            window.hasSelection = false;
            drawingCanvas.requestPaint();
            return;
        }

        if (window.currentTool === "ocr" || window.currentTool === "qr") {
            const ox = mouse.x / window.editScale;
            const oy = mouse.y / window.editScale;
            window.selectStart = Qt.point(ox, oy);
            window.ocrRect = Qt.rect(ox, oy, 0, 0);
            window.activeHandle = window.currentTool;
            drawingCanvas.requestPaint();
            return;
        }

        // Annotation Mode: perform drawing!
        if (window.currentTool === "text") {
            const absPt = getAbsolutePoint(mouse.x, mouse.y);
            window.pressCoords = absPt;
            window.currentStroke = {
                tool: "text",
                color: window.currentColor.toString(),
                width: window.textFontSize,
                points: [absPt],
                isSpeechBubble: false,
                text: "",
                isBold: window.textBold,
                isItalic: window.textItalic,
                isUnderline: window.textUnderline,
                hasBackground: window.textBackground,
                cornerRadius: window.textCornerRadius,
                fontFamily: window.textFontFamily,
                rotation: 0
            };
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            return;
        }

        if (window.currentTool === "stamp") {
             window.currentStroke = {
                 id: window.stampIdCounter++,
                 tool: "stamp",
                 color: window.currentColor.toString(),
                 width: window.strokeWidth,
                 points: [getAbsolutePoint(mouse.x, mouse.y)],
                 counter: window.stampCounter,
                 format: window.stampCounterFormat,
                 hasLeaderLine: false
             };
             window.pressCoords = getAbsolutePoint(mouse.x, mouse.y);
             if (window.activeCanvas) window.activeCanvas.requestPaint();
             return;
        }

        if (window.currentTool === "eraser") {
            const absPt = getAbsolutePoint(mouse.x, mouse.y);
            const sx = absPt.x;
            const sy = absPt.y;
            let found = -1;
            for (let i = window.strokes.length - 1; i >= 0; i--) {
                const stroke = window.strokes[i];
                if (stroke.points.length === 0) continue;
                
                const bbox = Helpers.getStrokeBBox(stroke, window.measureTextBounds);
                const pad = 12 + stroke.width * 2;
                if (sx >= bbox.minX - pad && sx <= bbox.maxX + pad && sy >= bbox.minY - pad && sy <= bbox.maxY + pad) {
                    found = i;
                    break;
                }
            }
             if (found !== -1) {
                 const list = [...window.strokes];
                 list.splice(found, 1);
                 window.strokes = list;
                 drawingCanvas.requestPaint();
             }
            return;
        }

        // Initialize pen smoothing state for real-time EMA filtering
        if (window.currentTool === "pen") {
            const pt = getAbsolutePoint(mouse.x, mouse.y);
            penSmoothX = pt.x;
            penSmoothY = pt.y;
        }

         window.currentStroke = {
              tool: window.currentTool,
              color: window.currentColor.toString(),
              width: window.activeIntensity,
              points: [getAbsolutePoint(mouse.x, mouse.y)],
              lineStyle: window.currentTool === "line" ? window.activeLineStyle : "solid",
              arrowLineStyle: window.currentTool === "arrow" ? window.activeArrowLineStyle : "solid",
              arrowHeadStyle: window.currentTool === "arrow" ? window.activeArrowHeadStyle : "single-filled",
              redactMode: window.currentTool === "redact" ? window.activeRedactMode : "solid",
              redactShape: window.currentTool === "redact" ? window.activeRedactShape : "rect",
              calloutLinkLines: window.currentTool === "callout" ? window.calloutLinkLines : 1,
              calloutShape: window.currentTool === "callout" ? window.calloutShape : "rect",
              randomize: window.currentTool === "pixelate" ? true : false,
              randomSeed: window.currentTool === "pixelate" ? Math.floor(Math.random() * 2147483647) : 0
          };
         drawingCanvas.requestPaint();
    }

    onDoubleClicked: (mouse) => {
        if (window.currentTool !== "select") return;
        const absPt = getAbsolutePoint(mouse.x, mouse.y);
        const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
        if (strokeIdx === -1) return;
        const stroke = window.strokes[strokeIdx];
        if (stroke.tool !== "text" || !stroke.points || stroke.points.length === 0) return;

        window.beginEditingTextStroke(stroke, textInputDialog);
    }

    onReleased: (mouse) => {
        shiftLockAxis = "none";
        if (window.lastPanMouse.x !== 0 || window.lastPanMouse.y !== 0) {
            window.lastPanMouse = Qt.point(0, 0);
            return;
        }
        if (mouse.button === Qt.LeftButton && window.pastePreviewActive) {
            window.performPasteAction();
            return;
        }
        if (window.currentTool === "select") {
             window.activeHandle = "none";
             window.calloutDestDragging = false;
             window.originalPoints = [];
             window.originalRotation = 0;
             drawingCanvas.requestPaint();
             return;
        }

          if (window.currentTool === "crop") {
              var resizeHandles = ["new", "move", "tl", "tr", "bl", "br", "tc", "bc", "lc", "rc"];
              if (resizeHandles.indexOf(window.activeHandle) >= 0) {
                 // Ignore accidental clicks and tiny drags without closing the editor.
                 if (Math.min(window.cropRect.width, window.cropRect.height) <= 3) {
                     window.hasSelection = false;
                     window.cropRect = Qt.rect(0, 0, 0, 0);
                     window.activeHandle = "none";
                     drawingCanvas.requestPaint();
                     return;
                 }
                 window.cropRect = window.clampCropRect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
                 if (Math.min(window.cropRect.width, window.cropRect.height) >= 16) {
                     window.hasSelection = true;
                      if (window.activeHandle === "new") {
                         window.currentTool = window.lastActiveTool;
                     }
                 } else {
                     window.hasSelection = false;
                     window.cropRect = Qt.rect(0, 0, 0, 0);
                 }
              }
              window.activeHandle = "none";
              drawingCanvas.requestPaint();
              return;
          }

        if (window.currentTool === "ocr") {
            window.activeHandle = "none";
            window.executeOcr();
            return;
        }

        if (window.currentTool === "qr") {
            window.activeHandle = "none";
            window.executeQrScan();
            return;
        }

        if (!window.currentStroke) return;
        let stroke = window.currentStroke;
        if (stroke.tool === "text") {
            window.beginNewTextStroke(stroke, textInputDialog);
            return;
        }
        window.finalizeCurrentStroke();
        penSmoothX = 0;
        penSmoothY = 0;
     }

     onWheel: (wheel) => {
         if ((wheel.modifiers & Qt.ControlModifier) && (wheel.modifiers & Qt.ShiftModifier)) {
             const zoomStep = wheel.angleDelta.y > 0 ? 0.1 : -0.1;
             let focusPt = null;
             if (window.boardContainerItem) {
                 const containerPt = drawMouseArea.mapToItem(window.boardContainerItem, wheel.x, wheel.y);
                 focusPt = Qt.point(containerPt.x - window.boardContainerItem.width / 2, containerPt.y - window.boardContainerItem.height / 2);
             }
             window.adjustUserZoom(zoomStep, focusPt);
             wheel.accepted = true;
             return;
         }

         if (wheel.modifiers & Qt.ControlModifier) {
             const scrollDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
             const panStep = scrollDelta > 0 ? 40 : -40;
             window.updatePanOffset(window.userPanX, window.userPanY + panStep);
             wheel.accepted = true;
             return;
         }

         if (wheel.modifiers & Qt.ShiftModifier) {
             const scrollDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
             const panStep = scrollDelta > 0 ? 40 : -40;
             window.updatePanOffset(window.userPanX + panStep, window.userPanY);
             wheel.accepted = true;
             return;
         }

         const step = wheel.angleDelta.y > 0 ? 1 : -1;
         if (window.enableMagnifier && window.isZoomPressed) {
             magnifier.zoomFactor = Helpers.clamp(magnifier.zoomFactor + (step * 0.5), 1.5, 4.0);
             wheel.accepted = true;
             return;
         }

          if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "callout") {
              const calloutMeta = Constants.getToolMeta("callout");
              if (window.calloutDestDragging) {
                  const currentZoom = window.selectedStroke.width;
                  const nextZoom = Helpers.clamp(currentZoom + step * calloutMeta.step, calloutMeta.min, calloutMeta.max);
                 window.selectedStroke.width = nextZoom;
                 window.calloutZoom = nextZoom;
                 
                 if (window.selectedStroke.points.length === 4 && window.originalPoints.length === 4) {
                     const srcP0 = window.selectedStroke.points[0];
                     const srcP1 = window.selectedStroke.points[1];
                     const dstP0 = window.selectedStroke.points[2];
                     
                     const rw = srcP1.x - srcP0.x;
                     const rh = srcP1.y - srcP0.y;
                     const zoom = nextZoom / 100.0;
                     const dw = rw * zoom;
                     const dh = rh * zoom;
                     
                     const newPoints = [...window.selectedStroke.points];
                     newPoints[3] = Qt.point(dstP0.x + dw, dstP0.y + dh);
                     window.selectedStroke.points = newPoints;
                     
                     window.originalPoints[3] = Qt.point(window.originalPoints[2].x + dw, window.originalPoints[2].y + dh);
                 }
             } else {
                  const currentBorderWidth = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                  const nextBorderWidth = Helpers.clamp(currentBorderWidth + step, calloutMeta.borderWidthMin, calloutMeta.borderWidthMax);
                 window.selectedStroke.borderWidth = nextBorderWidth;
                 window.strokeWidth = nextBorderWidth;
             }
             
             const idx = window.strokes.indexOf(window.selectedStroke);
             if (idx !== -1) {
                 window.strokes[idx] = window.selectedStroke;
                 window.strokes = [...window.strokes];
             }
             
              drawingCanvas.requestPaint();
              wheel.accepted = true;
              return;
          }

          const tool = window.effectiveTool;
          const multiplier = getIntensityMultiplier(tool);

          window.updateActiveIntensity(window.activeIntensity + (step * multiplier));

          window.previewX = wheel.x;
          window.previewY = wheel.y;
          window.showSizePreview = true;
          previewTimer.restart();
          wheel.accepted = true;
     }

     Connections {
         target: window
         function onCurrentToolChanged() {
             penSmoothX = 0;
             penSmoothY = 0;
             updateSelectHover(window.cursorX * window.editScale, window.cursorY * window.editScale);
         }
     }
}
