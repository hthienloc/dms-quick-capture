import QtQuick
import Quickshell
import qs.Common
import qs.Services
import "Helpers.js" as Helpers

MouseArea {
    id: drawMouseArea
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

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
    required property var pixelateOptionsToolbar

    property string activeHandle: "none"
    property string hoveredHandle: "none"
    property int hoveredStrokeIdx: -1

    function getAbsolutePoint(mx, my) {
        let rx = mx / window.editScale;
        let ry = my / window.editScale;
        if (window.effectiveBackdropMode !== "none") {
            rx = (rx - window.screenshotXOffset) / window.backdropScaleFactor;
            ry = (ry - window.screenshotYOffset) / window.backdropScaleFactor;
        }
        if (window.hasActiveCropSelection) {
            return Qt.point(rx + window.cropRect.x, ry + window.cropRect.y);
        }
        return Qt.point(rx, ry);
    }

    onPositionChanged: (mouse) => {
         const origX = mouse.x / window.editScale;
         const origY = mouse.y / window.editScale;
         window.cursorX = origX;
         window.cursorY = origY;
         if (window.currentTool === "colorpicker") {
             window.hoveredColor = window.sampleCanvasColor(mouse.x, mouse.y);
         };
        hoveredHandle = window.getHoveredHandle(origX, origY);

        const absPt = getAbsolutePoint(mouse.x, mouse.y);

        if (window.currentTool === "select") {
            if (window.selectedStroke) {
                hoveredHandle = window.getSelectedStrokeHandleAt(absPt.x, absPt.y);

                if (window.activeHandle === "none" && window.originalPoints.length > 0) {
                    const dx = absPt.x - window.pressCoords.x;
                    const dy = absPt.y - window.pressCoords.y;
                    if (window.selectedStroke.tool === "callout" && window.calloutDestDragging && window.originalPoints.length === 4) {
                        const newPoints = [...window.selectedStroke.points];
                        newPoints[2] = Qt.point(window.originalPoints[2].x + dx, window.originalPoints[2].y + dy);
                        newPoints[3] = Qt.point(window.originalPoints[3].x + dx, window.originalPoints[3].y + dy);
                        window.selectedStroke.points = newPoints;
                    } else {
                        const newPoints = [];
                        for (let i = 0; i < window.originalPoints.length; i++) {
                            newPoints.push(Qt.point(window.originalPoints[i].x + dx, window.originalPoints[i].y + dy));
                        }
                        window.selectedStroke.points = newPoints;
                    }
                    if (window.selectedStroke.tool === "redact") {
                        window.selectedStroke.cachedCleanColor = undefined;
                    }
                } else if (window.activeHandle !== "none" && window.originalPoints.length > 0) {
                    const dx = absPt.x - window.pressCoords.x;
                    const dy = absPt.y - window.pressCoords.y;
                    const orig = window.originalPoints;
                    const tool = window.selectedStroke.tool;

                    if (tool === "rect" || tool === "ellipse" || tool === "redact" ||
                        tool === "pixelate" || tool === "spotlight") {
                        const p0 = orig[0];
                        const p1 = orig[orig.length - 1];
                        let x1 = Math.min(p0.x, p1.x);
                        let y1 = Math.min(p0.y, p1.y);
                        let x2 = Math.max(p0.x, p1.x);
                        let y2 = Math.max(p0.y, p1.y);
                        const minSize = 10;

                        switch (window.activeHandle) {
                            case "tl": x1 = Math.min(x1 + dx, x2 - minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "tr": x2 = Math.max(x2 + dx, x1 + minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "bl": x1 = Math.min(x1 + dx, x2 - minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "br": x2 = Math.max(x2 + dx, x1 + minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "tc": y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "bc": y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "lc": x1 = Math.min(x1 + dx, x2 - minSize); break;
                            case "rc": x2 = Math.max(x2 + dx, x1 + minSize); break;
                        }

                        const wasFlippedX = p0.x > p1.x;
                        const wasFlippedY = p0.y > p1.y;
                        const newP0 = Qt.point(wasFlippedX ? x2 : x1, wasFlippedY ? y2 : y1);
                        const newP1 = Qt.point(wasFlippedX ? x1 : x2, wasFlippedY ? y1 : y2);

                        const newPoints = [...window.selectedStroke.points];
                        newPoints[0] = newP0;
                        newPoints[newPoints.length - 1] = newP1;
                        window.selectedStroke.points = newPoints;

                        if (tool === "redact") {
                            window.selectedStroke.cachedCleanColor = undefined;
                        }
                    } else if (tool === "line" || tool === "arrow" || tool === "highlighter") {
                        const newPoints = [...window.selectedStroke.points];
                        if (window.activeHandle === "start") {
                            newPoints[0] = Qt.point(orig[0].x + dx, orig[0].y + dy);
                        } else if (window.activeHandle === "end") {
                            newPoints[newPoints.length - 1] = Qt.point(orig[orig.length - 1].x + dx, orig[orig.length - 1].y + dy);
                        }
                        window.selectedStroke.points = newPoints;
                    } else if (tool === "callout" && window.activeHandle && window.activeHandle.indexOf("src_") === 0 && orig.length === 4) {
                        const p0 = orig[0];
                        const p1 = orig[1];
                        let x1 = Math.min(p0.x, p1.x);
                        let y1 = Math.min(p0.y, p1.y);
                        let x2 = Math.max(p0.x, p1.x);
                        let y2 = Math.max(p0.y, p1.y);
                        const minSize = 10;
                        const h = window.activeHandle.slice(4);

                        switch (h) {
                            case "tl": x1 = Math.min(x1 + dx, x2 - minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "tr": x2 = Math.max(x2 + dx, x1 + minSize); y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "bl": x1 = Math.min(x1 + dx, x2 - minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "br": x2 = Math.max(x2 + dx, x1 + minSize); y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "tc": y1 = Math.min(y1 + dy, y2 - minSize); break;
                            case "bc": y2 = Math.max(y2 + dy, y1 + minSize); break;
                            case "lc": x1 = Math.min(x1 + dx, x2 - minSize); break;
                            case "rc": x2 = Math.max(x2 + dx, x1 + minSize); break;
                        }

                        const wasFlippedX = p0.x > p1.x;
                        const wasFlippedY = p0.y > p1.y;
                        const newP0 = Qt.point(wasFlippedX ? x2 : x1, wasFlippedY ? y2 : y1);
                        const newP1 = Qt.point(wasFlippedX ? x1 : x2, wasFlippedY ? y1 : y2);

                        const newPoints = [...window.selectedStroke.points];
                        newPoints[0] = newP0;
                        newPoints[1] = newP1;

                        const newSW = Math.abs(newP1.x - newP0.x);
                        const newSH = Math.abs(newP1.y - newP0.y);
                        const zoom = window.selectedStroke.width / 100.0;
                        newPoints[3] = Qt.point(newPoints[2].x + newSW * zoom, newPoints[2].y + newSH * zoom);
                        window.selectedStroke.points = newPoints;
                    } else if (tool === "stamp") {
                        const newPoints = [...window.selectedStroke.points];
                        const hasLeader = window.selectedStroke.hasLeaderLine && window.selectedStroke.points.length >= 2;
                        if (window.activeHandle === "anchor" && hasLeader) {
                            newPoints[0] = Qt.point(orig[0].x + dx, orig[0].y + dy);
                        } else if (window.activeHandle === "stamp") {
                            const idx = hasLeader ? 1 : 0;
                            newPoints[idx] = Qt.point(orig[idx].x + dx, orig[idx].y + dy);
                        }
                        window.selectedStroke.points = newPoints;
                    }
                }
                if (window.originalPoints.length === 0) {
                    hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                }
                drawingCanvas.requestPaint();
            } else {
                hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                hoveredHandle = "none";
            }
            return;
        }

        if (window.currentTool === "crop") {
            const ox = Math.max(0, Math.min(origX, window.screenshotWidth));
            const oy = Math.max(0, Math.min(origY, window.screenshotHeight));
            if (window.activeHandle === "new") {
                const x1 = Math.min(window.selectStart.x, ox);
                const y1 = Math.min(window.selectStart.y, oy);
                const w = Math.abs(ox - window.selectStart.x);
                const h = Math.abs(oy - window.selectStart.y);
                window.cropRect = window.clampCropRect(x1, y1, w, h);
                drawingCanvas.requestPaint();
                return;
            }

            if (window.activeHandle !== "none" && window.activeHandle !== "new") {
                // Drag resizing one of the corners
                const cr = window.cropRect;
                let newX = cr.x;
                let newY = cr.y;
                let newW = cr.width;
                let newH = cr.height;
                if (window.activeHandle === "tl") {
                    newX = Math.min(ox, cr.x + cr.width - 10);
                    newY = Math.min(oy, cr.y + cr.height - 10);
                    newW = cr.x + cr.width - newX;
                    newH = cr.y + cr.height - newY;
                } else if (window.activeHandle === "tr") {
                    newY = Math.min(oy, cr.y + cr.height - 10);
                    newW = Math.max(10, ox - cr.x);
                    newH = cr.y + cr.height - newY;
                } else if (window.activeHandle === "bl") {
                    newX = Math.min(ox, cr.x + cr.width - 10);
                    newW = cr.x + cr.width - newX;
                    newH = Math.max(10, oy - cr.y);
                } else if (window.activeHandle === "br") {
                    newW = Math.max(10, ox - cr.x);
                    newH = Math.max(10, oy - cr.y);
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
                return;
            }
        } else if (window.currentTool === "ocr" || window.currentTool === "qr") {
            if (window.activeHandle === "ocr" || window.activeHandle === "qr") {
                const ox = mouse.x / window.editScale;
                const oy = mouse.y / window.editScale;
                const x1 = Math.min(window.selectStart.x, ox);
                const y1 = Math.min(window.selectStart.y, oy);
                const w = Math.abs(ox - window.selectStart.x);
                const h = Math.abs(oy - window.selectStart.y);
                window.ocrRect = Qt.rect(x1, y1, w, h);
                drawingCanvas.requestPaint();
            }
            return;
        } else {
            // Standard stroke drawing positions update
            if (!window.currentStroke) return;

            const absPt = getAbsolutePoint(mouse.x, mouse.y);
            if (window.currentTool === "pen") {
                if (mouse.modifiers & Qt.ShiftModifier) {
                    if (window.currentStroke.points.length > 1) {
                        window.currentStroke.points = [window.currentStroke.points[0], absPt];
                    } else {
                        window.currentStroke.points.push(absPt);
                    }
                } else {
                    window.currentStroke.points.push(absPt);
                }
               } else if (window.currentTool === "redact") {
                 let finalPt = absPt;
                 if ((mouse.modifiers & Qt.ShiftModifier)) {
                     if (window.currentStroke.points[0]) {
                         finalPt = Helpers.constrainSquarePoint(window.currentStroke.points[0], absPt, Qt);
                     }
                 }
                 if (window.currentStroke.points.length > 1) {
                      window.currentStroke.points[window.currentStroke.points.length - 1] = finalPt;
                  } else {
                      window.currentStroke.points.push(finalPt);
                  }
              } else if (window.currentTool === "rect" || window.currentTool === "ellipse" || window.currentTool === "arrow" || window.currentTool === "line"
                       || window.currentTool === "pixelate" || window.currentTool === "highlighter" || window.currentTool === "spotlight" || window.currentTool === "callout") {
                  
                 let finalPt = absPt;
                 if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "line" || window.currentTool === "arrow" || window.currentTool === "highlighter")) {
                     // Snapping angle calculation (24 directions / 15 degrees)
                     const p0 = window.currentStroke.points[0];
                     if (p0) {
                         const dx = absPt.x - p0.x;
                         const dy = absPt.y - p0.y;
                         const L = Math.sqrt(dx * dx + dy * dy);
                         if (L > 0) {
                             const angle = Math.atan2(dy, dx);
                             const SNAP_STEP = Math.PI / 12; // 15 degrees
                             const snappedAngle = Math.round(angle / SNAP_STEP) * SNAP_STEP;
                             finalPt = Qt.point(p0.x + L * Math.cos(snappedAngle), p0.y + L * Math.sin(snappedAngle));
                         }
                     }
                 } else if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "ellipse" || window.currentTool === "rect" || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "spotlight" || window.currentTool === "callout")) {
                     if (window.currentStroke.points[0]) {
                         finalPt = Helpers.constrainSquarePoint(window.currentStroke.points[0], absPt, Qt);
                     }
                 }

                 if (window.currentStroke.points.length > 1) {
                      window.currentStroke.points[window.currentStroke.points.length - 1] = finalPt;
                  } else {
                      window.currentStroke.points.push(finalPt);
                  }
              } else if (window.currentTool === "stamp") {
                   const p0 = window.currentStroke.points[0];
                   if (p0) {
                       let finalPt = absPt;
                       const dx = absPt.x - p0.x;
                       const dy = absPt.y - p0.y;
                       const dist = Math.sqrt(dx * dx + dy * dy);
                       if (dist > 10 / window.editScale) {
                           window.currentStroke.hasLeaderLine = true;
                           
                           if (mouse.modifiers & Qt.ShiftModifier) {
                               const angle = Math.atan2(dy, dx);
                               const SNAP_STEP = Math.PI / 12; // 15 degrees
                               const snappedAngle = Math.round(angle / SNAP_STEP) * SNAP_STEP;
                               finalPt = Qt.point(p0.x + dist * Math.cos(snappedAngle), p0.y + dist * Math.sin(snappedAngle));
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
    }

    cursorShape: {
        const h = (window.activeHandle !== "none" && window.activeHandle !== "new") ? window.activeHandle : hoveredHandle;
        const hs = (h && h.length > 4) ? h.slice(-3) : h;
        if (h === "tl" || h === "br" || hs === "_tl" || hs === "_br") return Qt.SizeFDiagCursor;
        if (h === "tr" || h === "bl" || hs === "_tr" || hs === "_bl") return Qt.SizeBDiagCursor;
        if (h === "tc" || h === "bc" || hs === "_tc" || hs === "_bc") return Qt.SplitVCursor;
        if (h === "lc" || h === "rc" || hs === "_lc" || hs === "_rc") return Qt.SplitHCursor;
        if (h === "start" || h === "end" || h === "stamp" || h === "anchor") return Qt.SizeAllCursor;
        if (window.currentTool === "colorpicker") {
            return Qt.CrossCursor;
        }
        if (window.currentTool === "select") {
            return pressed && window.selectedStroke ? Qt.ClosedHandCursor : (hoveredStrokeIdx !== -1 ? Qt.OpenHandCursor : Qt.ArrowCursor);
        }
        return Qt.CrossCursor;
    }

    onPressed: (mouse) => {
        if (moreToolsMenu.opened) {
            moreToolsMenu.close();
            return;
        }

        if (window.isTyping) {
            window.commitTypingText();
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
                } else if (window.currentTool === "pixelate") {
                    pixelateOptionsToolbar.open(mapped.x, mapped.y);
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
                    window.strokeWidth = window.preGrabStrokeWidth;
                    window.textFontSize = window.preGrabTextFontSize;
                    window.pixelateIntensity = window.preGrabPixelateIntensity;
                    window.spotlightIntensity = window.preGrabSpotlightIntensity;
                    window.calloutZoom = window.preGrabCalloutZoom;
                    window.currentColor = window.preGrabColor;
                    window.activeRedactMode = window.preGrabRedactMode;
                    window.activeRedactShape = window.preGrabRedactShape;
                    window.calloutLinkLines = window.preGrabCalloutLinkLines;
                    window.selectedStroke = null;
                }
                drawingCanvas.requestPaint();
            }
            return;
        }

        const absPt = getAbsolutePoint(mouse.x, mouse.y);
        if (window.currentTool === "select") {
            // Check if clicking on a resize handle
            if (window.selectedStroke) {
                const sh = window.getSelectedStrokeHandleAt(absPt.x, absPt.y);
                if (sh !== "none") {
                    window.activeHandle = sh;
                    window.pressCoords = absPt;
                    const orig = [];
                    for (let p of window.selectedStroke.points) {
                        orig.push(Qt.point(p.x, p.y));
                    }
                    window.originalPoints = orig;
                    drawingCanvas.requestPaint();
                    return;
                }
            }

            const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
            if (strokeIdx === -1) {
                // Clicked empty space — deselect
                if (window.selectedStroke) {
                    window.selectedStroke = null;
                    window.strokeWidth = window.preGrabStrokeWidth;
                    window.textFontSize = window.preGrabTextFontSize;
                    window.pixelateIntensity = window.preGrabPixelateIntensity;
                    window.spotlightIntensity = window.preGrabSpotlightIntensity;
                    window.calloutZoom = window.preGrabCalloutZoom;
                    window.currentColor = window.preGrabColor;
                    window.activeRedactMode = window.preGrabRedactMode;
                    window.activeRedactShape = window.preGrabRedactShape;
                    window.calloutLinkLines = window.preGrabCalloutLinkLines;
                }
                window.originalPoints = [];
                window.activeHandle = "none";
                hoveredHandle = "none";
                drawingCanvas.requestPaint();
                return;
            }

            if (strokeIdx !== -1) {
                const stroke = window.strokes[strokeIdx];
                
                // Save previous style state if nothing was selected yet
                if (!window.selectedStroke) {
                    window.preGrabStrokeWidth = window.strokeWidth;
                    window.preGrabTextFontSize = window.textFontSize;
                    window.preGrabPixelateIntensity = window.pixelateIntensity;
                    window.preGrabSpotlightIntensity = window.spotlightIntensity;
                    window.preGrabCalloutZoom = window.calloutZoom;
                    window.preGrabColor = window.currentColor;
                    window.preGrabRedactMode = window.activeRedactMode;
                    window.preGrabRedactShape = window.activeRedactShape;
                    window.preGrabCalloutLinkLines = window.calloutLinkLines;
                }
                
                window.selectedStroke = stroke;
                window.currentColor = stroke.color;
                if (stroke.tool === "line" && stroke.lineStyle) {
                    window.activeLineStyle = stroke.lineStyle;
                }
                if (stroke.tool === "arrow") {
                    if (stroke.arrowLineStyle) window.activeArrowLineStyle = stroke.arrowLineStyle;
                    if (stroke.arrowHeadStyle) window.activeArrowHeadStyle = stroke.arrowHeadStyle;
                }
                if (stroke.tool === "redact" && stroke.redactMode) {
                    window.activeRedactMode = stroke.redactMode;
                }
                if (stroke.tool === "redact" && stroke.redactShape) {
                    window.activeRedactShape = stroke.redactShape;
                }
                if (stroke.tool === "callout") {
                    window.calloutLinkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 1;
                }

                // Detection for callout destination dragging
                if (stroke.tool === "callout" && stroke.points.length === 4) {
                    const dstP0 = stroke.points[2];
                    const dstP1 = stroke.points[3];
                    if (absPt.x >= dstP0.x && absPt.x <= dstP1.x && absPt.y >= dstP0.y && absPt.y <= dstP1.y) {
                        window.calloutDestDragging = true;
                    } else {
                        window.calloutDestDragging = false;
                    }
                }

                // Sync internal state with stroke's intensity
                if (stroke.tool === "text") window.textFontSize = stroke.width;
                else if (stroke.tool === "pixelate") {
                    window.pixelateIntensity = stroke.width;
                    window.pixelateRandomize = stroke.randomize === true;
                    if (window.pixelateRandomize && stroke.randomSeed === undefined) {
                        stroke.randomSeed = Math.floor(Math.random() * 2147483647);
                    }
                }
                else if (stroke.tool === "spotlight") window.spotlightIntensity = stroke.width;
                else if (stroke.tool === "callout") window.calloutZoom = stroke.width;
                else window.strokeWidth = stroke.width;
                
                window.pressCoords = absPt;
                const orig = [];
                for (let p of stroke.points) {
                    orig.push(Qt.point(p.x, p.y));
                }
                window.originalPoints = orig;

                // Bring selected stroke to front (move to end of strokes array)
                const reorder = [...window.strokes];
                reorder.splice(strokeIdx, 1);
                reorder.push(stroke);
                window.strokes = reorder;
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
            return;
        }

         if (window.currentTool === "colorpicker") {
              if (mouse.button === Qt.LeftButton) {
                  const pickedColor = window.sampleCanvasColor(mouse.x, mouse.y);
                  if (window.backdropColorPickingSlot !== "none") {
                      if (window.backdropColorPickingSlot === "solid") {
                          window.backdropSolidColor = pickedColor;
                      } else if (window.backdropColorPickingSlot === "start") {
                          window.backdropGradientStart = pickedColor;
                      } else if (window.backdropColorPickingSlot === "end") {
                          window.backdropGradientEnd = pickedColor;
                      }
                      window.hasUserCustomizedBackdrop = true;
                      window.backdropColorPickingSlot = "none";
                      window.currentTool = "backdrop";
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

            // Drag-to-select crop area
            window.activeHandle = "new";
            window.selectStart = Qt.point(Math.max(0, Math.min(ox, pw)), Math.max(0, Math.min(oy, ph)));
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
            window.typingCoords = getAbsolutePoint(mouse.x, mouse.y);
            window.currentTypingText = "";
            window.isTyping = true;
            if (window.textInputMode === "popup") {
                textInputDialog.open();
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            return;
        }

        if (window.currentTool === "stamp") {
             window.currentStroke = {
                 id: Date.now() + Math.random(),
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
                
                const bbox = Helpers.getStrokeBBox(stroke, Helpers.estimateTextWidth);
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
              randomize: window.currentTool === "pixelate" ? window.pixelateRandomize : false,
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

        window.editingStroke = stroke;
        window.selectedStroke = null;
        window.typingCoords = Qt.point(stroke.points[0].x, stroke.points[0].y);
        window.currentTypingText = stroke.text;
        window.isTyping = true;
        window.currentColor = stroke.color;
        window.textFontSize = stroke.width;
        window.textBold = stroke.isBold;
        window.textItalic = stroke.isItalic;
        window.textUnderline = stroke.isUnderline;
        window.textBackground = stroke.hasBackground;
        window.textCornerRadius = stroke.cornerRadius;
        window.textFontFamily = stroke.fontFamily;
        textInputDialog.open();
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    onReleased: (mouse) => {
        if (window.currentTool === "select") {
             window.activeHandle = "none";
             window.calloutDestDragging = false;
             window.originalPoints = [];
             drawingCanvas.requestPaint();
             return;
        }

          if (window.currentTool === "crop") {
              var resizeHandles = ["new", "tl", "tr", "bl", "br", "tc", "bc", "lc", "rc"];
              if (resizeHandles.indexOf(window.activeHandle) >= 0) {
                 // Check for accidental click (too small) BEFORE clamping
                 if (Math.min(window.cropRect.width, window.cropRect.height) <= 3) {
                     if (window.strokes.length === 0) {
                         window.discardAndClose();
                     } else {
                         window.hasSelection = false;
                         window.cropRect = Qt.rect(0, 0, 0, 0);
                     }
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
        if (stroke.tool === "callout" && stroke.points.length >= 2) {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const rw = Math.abs(p1.x - p0.x);
            const rh = Math.abs(p1.y - p0.y);
            
            if (rw > 5 && rh > 5) {
                const margin = 50;
                const zoom = stroke.width / 100.0;
                const dw = rw * zoom;
                const dh = rh * zoom;

                // Visible canvas bounds in absolute coordinates
                const visX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                const visY = window.hasActiveCropSelection ? window.cropRect.y : 0;
                const visW = window.canvasWidth;
                const visH = window.canvasHeight;

                // Smart placement: opposite side of source relative to visible area center
                const srcMinX = Math.min(p0.x, p1.x);
                const srcMaxX = Math.max(p0.x, p1.x);
                const srcMinY = Math.min(p0.y, p1.y);
                const srcMaxY = Math.max(p0.y, p1.y);
                const srcCx = (srcMinX + srcMaxX) / 2;
                const srcCy = (srcMinY + srcMaxY) / 2;
                const visCx = visX + visW / 2;
                const visCy = visY + visH / 2;

                const dirX = visCx - srcCx >= 0 ? 1 : -1;
                const dirY = visCy - srcCy >= 0 ? 1 : -1;

                let dx = dirX > 0 ? srcMaxX + margin : srcMinX - dw - margin;
                let dy = dirY > 0 ? srcMaxY + margin : srcMinY - dh - margin;

                const rightBound = visX + visW - dw - margin;
                const bottomBound = visY + visH - dh - margin;
                dx = Math.max(visX + margin, Math.min(dx, rightBound));
                dy = Math.max(visY + margin, Math.min(dy, bottomBound));
                
                stroke.points = [
                    Qt.point(srcMinX, srcMinY),
                    Qt.point(srcMaxX, srcMaxY),
                    Qt.point(dx, dy),
                    Qt.point(dx + dw, dy + dh)
                ];
            } else {
                window.currentStroke = null;
                return;
            }
        }
        if (stroke.tool === "pen" && stroke.points.length >= 3) {
            stroke.points = Helpers.smoothStrokePoints(stroke.points, 6, Qt);

            // Auto-close: if start and end are within 20 screen-px, snap closed
            if (window.penAutoClose) {
                const snapThreshold = 20 / window.editScale;
                const fp = stroke.points[0];
                const lp = stroke.points[stroke.points.length - 1];
                const dx = lp.x - fp.x;
                const dy = lp.y - fp.y;
                if (Math.sqrt(dx * dx + dy * dy) < snapThreshold) {
                    stroke.points = [...stroke.points, Qt.point(fp.x, fp.y)];
                    stroke.isClosed = true;
                }
            }
        }
         if (stroke.tool === "stamp") {
             window.stampCounter++;
         }
         window.pushStroke(window.currentStroke);
         window.currentStroke = null;
    }

     onWheel: (wheel) => {
         const step = wheel.angleDelta.y > 0 ? 1 : -1;
         if (window.enableMagnifier && window.isZoomPressed) {
             magnifier.zoomFactor = Math.max(1.5, Math.min(4.0, magnifier.zoomFactor + (step * 0.5)));
             wheel.accepted = true;
             return;
         }

         if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "callout") {
             if (window.calloutDestDragging) {
                 const currentZoom = window.selectedStroke.width;
                 const nextZoom = Math.max(100, Math.min(500, currentZoom + step * 10));
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
                 const nextBorderWidth = Math.max(1, Math.min(10, currentBorderWidth + step));
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
          let multiplier = 1;
          if (tool === "text" || tool === "pixelate") multiplier = 2;
          else if (tool === "spotlight") multiplier = 5;
          else if (tool === "callout") multiplier = 10;
 
          window.updateActiveIntensity(window.activeIntensity + (step * multiplier));
 
          window.previewX = wheel.x;
          window.previewY = wheel.y;
          window.showSizePreview = true;
          previewTimer.restart();
         wheel.accepted = true;
     }
}
