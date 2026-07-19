.pragma library
.import "Constants.js" as Constants

/**
 * DrawingRenderer.js
 * Encapsulates all drawing logic for the Quick Capture plugin.
 * This library is designed to be pure and context-aware, receiving the Canvas context (ctx)
 * and necessary state from the QML component.
 */

/**
 * Draws a single stroke (annotation) onto the provided context.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - The stroke data object.
 * @param {object} Helpers - Reference to the Helpers.js library.
 * @param {object} Qt - The Qt object.
 * @param {object} Theme - The Theme object.
 * @param {object} config - Configuration parameters (roundRect, roundHighlighter, etc.)
 */
function drawStroke(ctx, stroke, Helpers, Qt, Theme, config) {
    if (!stroke || !stroke.points || stroke.points.length === 0) return;

    const rgb = Helpers.hexToRgb(stroke.color, Qt);

    if (stroke.tool === "pen") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        
        const pts = stroke.points;
        const len = pts.length;
        ctx.moveTo(pts[0].x, pts[0].y);

        if (len === 1) {
            ctx.lineTo(pts[0].x, pts[0].y);
            ctx.stroke();
            return;
        }
        if (len === 2) {
            ctx.lineTo(pts[1].x, pts[1].y);
            ctx.stroke();
            return;
        }

        for (let i = 1; i < len - 2; i++) {
            const xc = (pts[i].x + pts[i + 1].x) / 2;
            const yc = (pts[i].y + pts[i + 1].y) / 2;
            ctx.quadraticCurveTo(pts[i].x, pts[i].y, xc, yc);
        }
        ctx.quadraticCurveTo(pts[len - 2].x, pts[len - 2].y, pts[len - 1].x, pts[len - 1].y);
        if (stroke.isClosed) {
            ctx.closePath();
        }
        ctx.stroke();

    } else if (stroke.tool === "line") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];

        ctx.save();
        if (stroke.lineStyle === "dashed") {
            ctx.setLineDash([stroke.width * Constants.lineDashMultiplier, stroke.width * Constants.lineGapMultiplier]);
        } else if (stroke.lineStyle === "dotted") {
            ctx.setLineDash([0.01, stroke.width * Constants.dottedGapMultiplier]);
        } else {
            ctx.setLineDash([]);
        }

        ctx.beginPath();
        ctx.moveTo(p0.x, p0.y);
        ctx.lineTo(p1.x, p1.y);
        ctx.stroke();
        ctx.restore();

    } else if (stroke.tool === "highlighter") {
        ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.4);
        ctx.lineWidth = stroke.width * Constants.highlighterScale;
        ctx.lineCap = config.roundHighlighter ? "round" : "square";
        ctx.lineJoin = config.roundHighlighter ? "round" : "miter";
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (var i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
        ctx.stroke();

    } else if (stroke.tool === "rect") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);
        const baseRadius = config.roundRect ? (Theme.cornerRadius + (stroke.width / 2)) : 0;
        const radius = Math.min(baseRadius, Math.min(rw, rh) / 2);

        ctx.beginPath();
        ctx.moveTo(rx + radius, ry);
        ctx.lineTo(rx + rw - radius, ry);
        ctx.arcTo(rx + rw, ry, rx + rw, ry + radius, radius);
        ctx.lineTo(rx + rw, ry + rh - radius);
        ctx.arcTo(rx + rw, ry + rh, rx + rw - radius, ry + rh, radius);
        ctx.lineTo(rx + radius, ry + rh);
        ctx.arcTo(rx, ry + rh, rx, ry + rh - radius, radius);
        ctx.lineTo(rx, ry + radius);
        ctx.arcTo(rx, ry, rx + radius, ry, radius);
        ctx.closePath();
        ctx.stroke();

    } else if (stroke.tool === "ellipse") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);

        if (rw > 0 && rh > 0) {
            ctx.save();
            ctx.beginPath();
            ctx.translate(rx + rw / 2, ry + rh / 2);
            ctx.scale(rw / 2, rh / 2);
            ctx.arc(0, 0, 1, 0, 2 * Math.PI);
            ctx.restore();
            ctx.stroke();
        }

    } else if (stroke.tool === "arrow") {
        ctx.strokeStyle = stroke.color;
        ctx.fillStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const dx = p1.x - p0.x;
        const dy = p1.y - p0.y;
        const len = Math.sqrt(dx * dx + dy * dy);

        if (len > 0) {
            const SPREAD_ANGLE = Math.PI / 7;
            const MIN_HEAD_LENGTH = 15;
            const HEAD_LENGTH_MULTIPLIER = 4;
            const BASE_FACTOR = Math.cos(SPREAD_ANGLE); // ~0.9009, matching base of the arrowhead triangle

            const DASH_LENGTH_RATIO = 2.5;
            const DASH_GAP_RATIO = 1.5;
            const DOTTED_SEGMENT_LENGTH = 0.01;
            const DOTTED_GAP_RATIO = 2;

            const angle = Math.atan2(dy, dx);
            const headLength = Math.max(MIN_HEAD_LENGTH, stroke.width * HEAD_LENGTH_MULTIPLIER);
            
            const isDoubleHead = stroke.arrowHeadStyle === "double-filled";
            const isOpenHead = stroke.arrowHeadStyle === "single-open";

            const startOffset = isDoubleHead ? headLength * BASE_FACTOR : 0;
            const endOffset = isOpenHead ? 0 : headLength * BASE_FACTOR;
            const shaftLength = Math.max(0, len - startOffset - endOffset);

            const shaftStartX = p0.x + startOffset * Math.cos(angle);
            const shaftStartY = p0.y + startOffset * Math.sin(angle);
            const shaftEndX = shaftStartX + shaftLength * Math.cos(angle);
            const shaftEndY = shaftStartY + shaftLength * Math.sin(angle);

            // Draw arrow shaft
            ctx.save();
            if (stroke.arrowLineStyle === "dashed") {
                ctx.setLineDash([stroke.width * DASH_LENGTH_RATIO, stroke.width * DASH_GAP_RATIO]);
            } else if (stroke.arrowLineStyle === "dotted") {
                ctx.setLineDash([DOTTED_SEGMENT_LENGTH, stroke.width * DOTTED_GAP_RATIO]);
            } else {
                ctx.setLineDash([]);
            }

            ctx.beginPath();
            ctx.moveTo(shaftStartX, shaftStartY);
            ctx.lineTo(shaftEndX, shaftEndY);
            ctx.stroke();
            ctx.restore();

            // Draw primary head (at p1)
            if (isOpenHead) {
                ctx.beginPath();
                ctx.moveTo(p1.x - headLength * Math.cos(angle - SPREAD_ANGLE), p1.y - headLength * Math.sin(angle - SPREAD_ANGLE));
                ctx.lineTo(p1.x, p1.y);
                ctx.lineTo(p1.x - headLength * Math.cos(angle + SPREAD_ANGLE), p1.y - headLength * Math.sin(angle + SPREAD_ANGLE));
                ctx.stroke();
            } else {
                ctx.beginPath();
                ctx.moveTo(p1.x, p1.y);
                ctx.lineTo(p1.x - headLength * Math.cos(angle - SPREAD_ANGLE), p1.y - headLength * Math.sin(angle - SPREAD_ANGLE));
                ctx.lineTo(p1.x - headLength * Math.cos(angle + SPREAD_ANGLE), p1.y - headLength * Math.sin(angle + SPREAD_ANGLE));
                ctx.closePath();
                ctx.fill();
            }

            // Draw secondary head (at p0) if double-headed
            if (isDoubleHead) {
                const oppositeAngle = angle + Math.PI;
                ctx.beginPath();
                ctx.moveTo(p0.x, p0.y);
                ctx.lineTo(p0.x - headLength * Math.cos(oppositeAngle - SPREAD_ANGLE), p0.y - headLength * Math.sin(oppositeAngle - SPREAD_ANGLE));
                ctx.lineTo(p0.x - headLength * Math.cos(oppositeAngle + SPREAD_ANGLE), p0.y - headLength * Math.sin(oppositeAngle + SPREAD_ANGLE));
                ctx.closePath();
                ctx.fill();
            }
        }

    } else if (stroke.tool === "redact") {
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.floor(Math.min(p0.x, p1.x));
        const ry = Math.floor(Math.min(p0.y, p1.y));
        const rw = Math.floor(Math.abs(p1.x - p0.x));
        const rh = Math.floor(Math.abs(p1.y - p0.y));
        const shape = stroke.redactShape || "rect";
        const mode = stroke.redactMode || "solid";

        if (rw > 0 && rh > 0) {
            ctx.save();

            if (shape === "ellipse") {
                ctx.save();
                ctx.translate(rx + rw / 2, ry + rh / 2);
                ctx.scale(rw / 2, rh / 2);
                ctx.beginPath();
                ctx.arc(0, 0, 1, 0, 2 * Math.PI);
                ctx.restore();
            } else if (shape === "roundRect") {
                const radius = Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2);
                ctx.beginPath();
                ctx.moveTo(rx + radius, ry);
                ctx.lineTo(rx + rw - radius, ry);
                ctx.arcTo(rx + rw, ry, rx + rw, ry + radius, radius);
                ctx.lineTo(rx + rw, ry + rh - radius);
                ctx.arcTo(rx + rw, ry + rh, rx + rw - radius, ry + rh, radius);
                ctx.lineTo(rx + radius, ry + rh);
                ctx.arcTo(rx, ry + rh, rx, ry + rh - radius, radius);
                ctx.lineTo(rx, ry + radius);
                ctx.arcTo(rx, ry, rx + radius, ry, radius);
                ctx.closePath();
            } else {
                ctx.beginPath();
                ctx.rect(rx, ry, rw, rh);
            }

            if (mode === "clean" && config.offscreenSampler) {
                if (stroke.isCurrent) {
                    try {
                        const octx = config.offscreenSampler.getContext("2d");
                        const imgData = octx.getImageData(rx, ry, 1, 1);
                        ctx.fillStyle = Qt.rgba(imgData.data[0] / 255, imgData.data[1] / 255, imgData.data[2] / 255, 1.0);
                    } catch (e) {
                        ctx.fillStyle = "rgba(128, 128, 128, 0.5)";
                    }
                } else {
                    if (!stroke.cachedCleanColor) {
                        stroke.cachedCleanColor = Helpers.getBoundaryColorOrGradient(ctx, rx, ry, rw, rh, config.offscreenSampler, Qt);
                    }
                    ctx.fillStyle = stroke.cachedCleanColor;
                }
                ctx.fill();
            } else {
                ctx.fillStyle = stroke.color;
                ctx.fill();
            }

            if (stroke.isCurrent) {
                ctx.strokeStyle = "rgba(255, 255, 255, 0.6)";
                ctx.lineWidth = 1;
                ctx.setLineDash([4, 4]);
                ctx.stroke();
            }
            ctx.restore();
        }

    } else if (stroke.tool === "pixelate") {
        if (stroke.points.length >= 2) {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const rx = Math.floor(Math.min(p0.x, p1.x));
            const ry = Math.floor(Math.min(p0.y, p1.y));
            const rw = Math.floor(Math.abs(p1.x - p0.x));
            const rh = Math.floor(Math.abs(p1.y - p0.y));

            if (rw > 2 && rh > 2) {
                ctx.save();
                ctx.beginPath();
                ctx.rect(rx, ry, rw, rh);
                ctx.clip();
                ctx.imageSmoothingEnabled = false;

                if (config.bgImageItem && config.bgImageItem.status === 1 /* Image.Ready */) {
                    const blockSize = Math.max(8, Math.min(36, stroke.width * 3));
                    const imgW = config.bgImageItem.sourceSize.width;
                    const imgH = config.bgImageItem.sourceSize.height;
                    for (let y = ry; y < ry + rh; y += blockSize) {
                        for (let x = rx; x < rx + rw; x += blockSize) {
                            const bw = Math.min(blockSize, rx + rw - x);
                            const bh = Math.min(blockSize, ry + rh - y);
                            if (bw <= 0 || bh <= 0) continue;
                            let sx, sy, sampleSize;
                            if (stroke.randomize) {
                                sampleSize = 1;
                                const seed = stroke.randomSeed !== undefined ? stroke.randomSeed : 0;
                                let h = (x * 374761393 + y * 668265263 + seed) >>> 0;
                                h = Math.imul(h ^ (h >>> 13), 1274126177) >>> 0;
                                h = (h ^ (h >>> 16)) >>> 0;
                                sx = Math.max(0, Math.min(x + (h % bw), imgW - 1));
                                sy = Math.max(0, Math.min(y + ((h >>> 8) % bh), imgH - 1));
                            } else {
                                sampleSize = Math.max(1, Math.round(blockSize / 5));
                                sx = Math.min(x + Math.floor(bw / 2), rx + rw - 1);
                                sy = Math.min(y + Math.floor(bh / 2), ry + rh - 1);
                                sx = Math.max(0, Math.min(sx, Math.max(0, imgW - sampleSize)));
                                sy = Math.max(0, Math.min(sy, Math.max(0, imgH - sampleSize)));
                            }
                            ctx.drawImage(config.bgImageItem, sx, sy, sampleSize, sampleSize, x, y, bw, bh);
                        }
                    }
                }

                if (stroke.isCurrent) {
                    ctx.strokeStyle = "rgba(255, 255, 255, 0.6)";
                    ctx.lineWidth = 1;
                    ctx.setLineDash([4, 4]);
                    ctx.strokeRect(rx, ry, rw, rh);
                }
                ctx.restore();
            }
        }

    } else if (stroke.tool === "stamp") {
        const radius = stroke.width * Constants.stampRadiusMultiplier;
        const textColor = Helpers.getContrastingColor(stroke.color, Qt);
        const hasLeader = stroke.hasLeaderLine && stroke.points.length >= 2;
        const stampPt = hasLeader ? stroke.points[1] : stroke.points[0];

        if (hasLeader) {
            const startPt = stroke.points[0];

            // Connection line
            ctx.save();
            ctx.strokeStyle = stroke.color;
            ctx.lineWidth = Math.max(2, stroke.width);
            ctx.beginPath();
            ctx.moveTo(startPt.x, startPt.y);
            ctx.lineTo(stampPt.x, stampPt.y);
            ctx.stroke();
            ctx.restore();

            // Pointer dot at start point
            ctx.save();
            ctx.fillStyle = stroke.color;
            ctx.beginPath();
            ctx.arc(startPt.x, startPt.y, Math.max(4, stroke.width * 1.5), 0, 2 * Math.PI);
            ctx.fill();
            ctx.restore();
        }

        // Draw stamp circle background at stamp position
        ctx.save();
        ctx.fillStyle = stroke.color;
        ctx.beginPath();
        ctx.arc(stampPt.x, stampPt.y, radius, 0, 2 * Math.PI);
        ctx.fill();
        ctx.restore();

        // Draw text
        ctx.save();
        const fontSize = Math.round(radius * Constants.stampTextFontSizeMultiplier);
        const text = Helpers.formatCounter(stroke.counter, stroke.format || "numeric");
        ctx.fillStyle = textColor;
        ctx.font = "bold " + fontSize + "px sans-serif";
        ctx.textBaseline = "middle";
        ctx.textAlign = "left";
        const textW = ctx.measureText(text).width;
        ctx.fillText(text, stampPt.x - textW / 2, stampPt.y + Math.round(fontSize * Constants.stampTextOffsetMultiplier));
        ctx.restore();

    } else if (stroke.tool === "callout") {
        if (stroke.points.length === 4 || stroke.points.length >= 2) {
            let srcP0, srcP1, dstP0, dstP1;
            if (stroke.points.length === 4) {
                srcP0 = stroke.points[0];
                srcP1 = stroke.points[1];
                dstP0 = stroke.points[2];
                dstP1 = stroke.points[3];
            } else {
                const p0 = stroke.points[0];
                const p1 = stroke.points[stroke.points.length - 1];
                
                srcP0 = { x: Math.min(p0.x, p1.x), y: Math.min(p0.y, p1.y) };
                srcP1 = { x: Math.max(p0.x, p1.x), y: Math.max(p0.y, p1.y) };
                
                const rw = srcP1.x - srcP0.x;
                const rh = srcP1.y - srcP0.y;
                const zoom = stroke.width / 100.0;
                const dw = rw * zoom;
                const dh = rh * zoom;

                // Smart placement: opposite side of source relative to visible area center
                const srcCx = (srcP0.x + srcP1.x) / 2;
                const srcCy = (srcP0.y + srcP1.y) / 2;
                const visX = config.canvasMinX || 0;
                const visY = config.canvasMinY || 0;
                const visW = config.canvasWidth || 1920;
                const visH = config.canvasHeight || 1080;
                const visCx = visX + visW / 2;
                const visCy = visY + visH / 2;
                const dirX = visCx - srcCx >= 0 ? 1 : -1;
                const dirY = visCy - srcCy >= 0 ? 1 : -1;
                const margin = 50;

                let dx = dirX > 0 ? srcP1.x + margin : srcP0.x - dw - margin;
                let dy = dirY > 0 ? srcP1.y + margin : srcP0.y - dh - margin;
                const rightBound = visX + visW - dw - margin;
                const bottomBound = visY + visH - dh - margin;
                dx = Math.max(visX + margin, Math.min(dx, rightBound));
                dy = Math.max(visY + margin, Math.min(dy, bottomBound));
                
                dstP0 = { x: dx, y: dy };
                dstP1 = { x: dx + dw, y: dy + dh };
            }
            
            const sx = srcP0.x;
            const sy = srcP0.y;
            const sw = srcP1.x - srcP0.x;
            const sh = srcP1.y - srcP0.y;
            
            const dx = dstP0.x;
            const dy = dstP0.y;
            const dw = dstP1.x - dstP0.x;
            const dh = dstP1.y - dstP0.y;

            if (sw > 0 && sh > 0 && dw > 0 && dh > 0) {
                const bW = stroke.borderWidth !== undefined ? stroke.borderWidth : 2;

                // 1. Draw connecting lines (dynamic corners) using semi-transparent stroke color
                const linkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 2;
                ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.6);
                ctx.lineWidth = bW;
                ctx.beginPath();
                
                if (linkLines === 2) {
                    // Simple logic: connect closest horizontal corners
                    if (dx > sx + sw) { // Dest is to the right
                        ctx.moveTo(srcP1.x, srcP0.y); ctx.lineTo(dstP0.x, dstP0.y);
                        ctx.moveTo(srcP1.x, srcP1.y); ctx.lineTo(dstP0.x, dstP1.y);
                    } else if (dx + dw < sx) { // Dest is to the left
                        ctx.moveTo(srcP0.x, srcP0.y); ctx.lineTo(dstP1.x, dstP0.y);
                        ctx.moveTo(srcP0.x, srcP1.y); ctx.lineTo(dstP1.x, dstP1.y);
                    } else { // Dest is above/below
                        ctx.moveTo(srcP0.x, srcP1.y); ctx.lineTo(dstP0.x, dstP0.y);
                        ctx.moveTo(srcP1.x, srcP1.y); ctx.lineTo(dstP1.x, dstP0.y);
                    }
                } else { // 1 Line
                    if (dx > sx + sw) { // Dest is to the right
                        ctx.moveTo(sx + sw, sy + sh / 2);
                        ctx.lineTo(dx, dy + dh / 2);
                    } else if (dx + dw < sx) { // Dest is to the left
                        ctx.moveTo(sx, sy + sh / 2);
                        ctx.lineTo(dx + dw, dy + dh / 2);
                    } else { // Dest is above/below
                        if (dy > sy + sh) { // Dest is below
                            ctx.moveTo(sx + sw / 2, sy + sh);
                            ctx.lineTo(dx + dw / 2, dy);
                        } else { // Dest is above
                            ctx.moveTo(sx + sw / 2, sy);
                            ctx.lineTo(dx + dw / 2, dy + dh);
                        }
                    }
                }
                ctx.stroke();

                // 2. Draw destination image (magnified)
                if (config.bgImageItem && config.bgImageItem.status === 1) {
                    const imgW = config.bgImageItem.sourceSize
                        ? config.bgImageItem.sourceSize.width
                        : (config.bgImageItem.width || 0);
                    const imgH = config.bgImageItem.sourceSize
                        ? config.bgImageItem.sourceSize.height
                        : (config.bgImageItem.height || 0);
                    if (imgW > 0 && imgH > 0) {
                        const clampSX = Math.max(0, Math.min(sx, imgW - 1));
                        const clampSY = Math.max(0, Math.min(sy, imgH - 1));
                        const clampSW = Math.min(sw, imgW - clampSX);
                        const clampSH = Math.min(sh, imgH - clampSY);
                        if (clampSW > 0 && clampSH > 0) {
                            ctx.save();
                            ctx.beginPath();
                            ctx.rect(dx, dy, dw, dh);
                            ctx.clip();
                            ctx.drawImage(config.bgImageItem, clampSX, clampSY, clampSW, clampSH, dx, dy, dw, dh);
                            ctx.restore();
                        }
                    }
                }

                // 3. Draw borders with high visibility
                ctx.strokeStyle = stroke.color;
                ctx.lineWidth = bW;
                ctx.strokeRect(sx, sy, sw, sh);
                ctx.strokeRect(dx, dy, dw, dh);
                
                // Contrasting outline shadow
                ctx.strokeStyle = "rgba(0,0,0,0.4)";
                ctx.lineWidth = 1;
                ctx.strokeRect(sx - bW/2 - 0.5, sy - bW/2 - 0.5, sw + bW + 1, sh + bW + 1);
                ctx.strokeRect(dx - bW/2 - 0.5, dy - bW/2 - 0.5, dw + bW + 1, dh + bW + 1);
            }
        }

    } else if (stroke.tool === "text") {
        const pt = stroke.points[0];
        ctx.fillStyle = stroke.color;
        
        let styleStr = "";
        if (stroke.isItalic) styleStr += "italic ";
        if (stroke.isBold) styleStr += "bold ";
        const fFamily = stroke.fontFamily || (stroke.isMonospace ? "monospace" : "sans-serif");
        
        ctx.font = styleStr + Math.round(stroke.width) + "px " + fFamily;
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";

        const lines = (stroke.text || "").split("\n");
        const lineHeight = stroke.width * 1.35;

        if (stroke.hasBackground) {
            let maxWidth = 0;
            for (let li = 0; li < lines.length; li++) {
                const m = ctx.measureText(lines[li]);
                if (m.width > maxWidth) maxWidth = m.width;
            }
            const h = stroke.width;
            const padX = h * 0.3;
            const padY = h * 0.15;
            const totalH = lines.length * lineHeight - (lineHeight - h);
            const rx = pt.x - padX;
            const ry = pt.y - padY;
            const rw = maxWidth + padX * 2;
            const rh = totalH + padY * 2;
            const radius = stroke.cornerRadius || 0;

            ctx.fillStyle = Helpers.getContrastingColor(stroke.color, Qt);

            if (radius > 0) {
                ctx.beginPath();
                ctx.moveTo(rx + radius, ry);
                ctx.lineTo(rx + rw - radius, ry);
                ctx.quadraticCurveTo(rx + rw, ry, rx + rw, ry + radius);
                ctx.lineTo(rx + rw, ry + rh - radius);
                ctx.quadraticCurveTo(rx + rw, ry + rh, rx + rw - radius, ry + rh);
                ctx.lineTo(rx + radius, ry + rh);
                ctx.quadraticCurveTo(rx, ry + rh, rx, ry + rh - radius);
                ctx.lineTo(rx, ry + radius);
                ctx.quadraticCurveTo(rx, ry, rx + radius, ry);
                ctx.closePath();
                ctx.fill();
            } else {
                ctx.fillRect(rx, ry, rw, rh);
            }
            
            ctx.fillStyle = stroke.color;
        }

        for (let li = 0; li < lines.length; li++) {
            ctx.fillText(lines[li], pt.x, pt.y + li * lineHeight + stroke.width / 2);
        }

        if (stroke.isUnderline) {
            ctx.strokeStyle = stroke.color;
            ctx.lineWidth = Math.max(1.5, Math.round(stroke.width * 0.08));
            for (let li = 0; li < lines.length; li++) {
                const textWidth = ctx.measureText(lines[li]).width;
                ctx.beginPath();
                ctx.moveTo(pt.x, pt.y + li * lineHeight + stroke.width * 1.1);
                ctx.lineTo(pt.x + textWidth, pt.y + li * lineHeight + stroke.width * 1.1);
                ctx.stroke();
            }
        }
    }
}

/**
 * Draws resize handles for a selected stroke in select mode.
 * 8-point handles for shapes, 2-point handles for lines.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - The selected stroke data object.
 * @param {object} Theme - The Theme object.
 * @param {function} estimateTextWidthFn - Text width estimation function.
 * @param {object} Qt - The Qt object for color utilities.
 * @param {object} Helpers - The Helpers module for utility functions.
 */
function drawSelectionHandles(ctx, stroke, Theme, estimateTextWidthFn, Qt, Helpers) {
    if (!stroke || !stroke.points || stroke.points.length === 0) return;

    const hs = Constants.selectionHandleSize;
    const hh = hs / 2;

    if (stroke.tool === "rect" || stroke.tool === "ellipse" || stroke.tool === "redact" ||
        stroke.tool === "pixelate" || stroke.tool === "spotlight") {
        if (stroke.points.length < 2) return;
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const x1 = Math.min(p0.x, p1.x);
        const y1 = Math.min(p0.y, p1.y);
        const x2 = Math.max(p0.x, p1.x);
        const y2 = Math.max(p0.y, p1.y);
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        ctx.save();
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.strokeRect(x1, y1, x2 - x1, y2 - y1);
        ctx.restore();

        ctx.fillStyle = "#ffffff";
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1.5;
        const handlePoints = [
            {x: x1, y: y1}, {x: x2, y: y1}, {x: x1, y: y2}, {x: x2, y: y2},
            {x: cx, y: y1}, {x: cx, y: y2}, {x: x1, y: cy}, {x: x2, y: cy}
        ];
        for (let p of handlePoints) {
            ctx.fillRect(p.x - hh, p.y - hh, hs, hs);
            ctx.strokeRect(p.x - hh, p.y - hh, hs, hs);
        }
        return;
    }

    if (stroke.tool === "line" || stroke.tool === "arrow" || stroke.tool === "highlighter") {
        if (stroke.points.length < 2) return;
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];

        // Draw dashed selection line along the stroke path (except highlighter to keep highlighted text readable)
        if (stroke.tool !== "highlighter") {
            ctx.save();
            ctx.strokeStyle = Helpers.getContrastingColor(stroke.color, Qt);
            ctx.lineWidth = Math.max(1.5, Math.min(2.5, stroke.width / 2));
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(p1.x, p1.y);
            ctx.stroke();
            ctx.restore();
        }

        ctx.fillStyle = "#ffffff";
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1.5;
        ctx.fillRect(p0.x - hh, p0.y - hh, hs, hs);
        ctx.strokeRect(p0.x - hh, p0.y - hh, hs, hs);
        ctx.fillRect(p1.x - hh, p1.y - hh, hs, hs);
        ctx.strokeRect(p1.x - hh, p1.y - hh, hs, hs);
        return;
    }

    if (stroke.tool === "stamp") {
        const hasLeader = stroke.hasLeaderLine && stroke.points.length >= 2;
        const stampPt = hasLeader ? stroke.points[1] : stroke.points[0];

        ctx.fillStyle = "#ffffff";
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1.5;

        if (hasLeader) {
            const anchorPt = stroke.points[0];
            ctx.fillRect(anchorPt.x - hh, anchorPt.y - hh, hs, hs);
            ctx.strokeRect(anchorPt.x - hh, anchorPt.y - hh, hs, hs);
        }

        ctx.fillRect(stampPt.x - hh, stampPt.y - hh, hs, hs);
        ctx.strokeRect(stampPt.x - hh, stampPt.y - hh, hs, hs);
        return;
    }

    if (stroke.tool === "text") {
        const p = stroke.points[0];
        const fontSize = stroke.width;
        const txt = stroke.text || "";
        const lines = String(txt).split("\n");
        const numLines = lines.length || 1;
        const lineH = fontSize * 1.35;
        let tw = Constants.minTextWidth;
        if (estimateTextWidthFn) {
            tw = Math.max(Constants.minTextWidth, estimateTextWidthFn(txt, fontSize, stroke.isBold === true, stroke.isMonospace === true));
        }
        let th = fontSize + (numLines - 1) * lineH;
        let tx = p.x;
        let ty = p.y;
        if (stroke.hasBackground) {
            const px = fontSize * Constants.textPaddingMultiplierX;
            const py = fontSize * Constants.textPaddingMultiplierY;
            tx -= px;
            ty -= py;
            tw += px * 2;
            th += py * 2;
        }
        const sp = 6;
        ctx.save();
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.strokeRect(tx - sp, ty - sp, tw + sp * 2, th + sp * 2);
        ctx.restore();
        return;
    }

    if (stroke.tool === "pen") {
        if (stroke.points.length < 2) return;
        ctx.save();
        ctx.strokeStyle = Helpers.getContrastingColor(stroke.color, Qt);
        ctx.lineWidth = 2;
        ctx.setLineDash([4, 4]);
        ctx.beginPath();
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (let i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
        ctx.stroke();
        ctx.restore();
        return;
    }

    if (stroke.tool === "callout" && stroke.points.length === 4) {
        const p0 = stroke.points[0];
        const p1 = stroke.points[1];
        const x1 = Math.min(p0.x, p1.x);
        const y1 = Math.min(p0.y, p1.y);
        const x2 = Math.max(p0.x, p1.x);
        const y2 = Math.max(p0.y, p1.y);
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;
        const sw = x2 - x1;
        const sh = y2 - y1;
        if (sw <= 0 || sh <= 0) return;

        ctx.save();
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1;
        ctx.setLineDash([4, 4]);
        ctx.strokeRect(x1, y1, sw, sh);
        ctx.restore();

        ctx.fillStyle = "#ffffff";
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1.5;
        const handlePoints = [
            {x: x1, y: y1}, {x: x2, y: y1},
            {x: x1, y: y2}, {x: x2, y: y2},
            {x: cx, y: y1}, {x: cx, y: y2},
            {x: x1, y: cy}, {x: x2, y: cy}
        ];
        for (let p of handlePoints) {
            ctx.fillRect(p.x - hh, p.y - hh, hs, hs);
            ctx.strokeRect(p.x - hh, p.y - hh, hs, hs);
        }
        return;
    }
}

/**
 * Draws the selection (crop) overlay with dimming and handles.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} options - Selection options (cropRect, canvasWidth, canvasHeight, isCropMode)
 * @param {object} Theme - The Theme object.
 */
function drawSelectionOverlay(ctx, options, Theme) {
    if (!options.isCropMode && !options.isOcrMode) return;

    ctx.save();
    const rect = options.isOcrMode ? options.ocrRect : options.cropRect;
    const borderColor = options.isOcrMode ? "#4CAF50" : Theme.primary;
    const overlayColor = options.isOcrMode ? "rgba(76, 175, 80, 0.15)" : "rgba(0, 0, 0, 0.4)";



    if (rect.width > 0 && rect.height > 0) {
        ctx.fillStyle = overlayColor;
        const cr = rect;
        const cw = options.canvasWidth;
        const ch = options.canvasHeight;

        // Dim outside selection
        ctx.fillRect(0, 0, cr.x, ch);
        ctx.fillRect(cr.x + cr.width, 0, cw - (cr.x + cr.width), ch);
        ctx.fillRect(cr.x, 0, cr.width, cr.y);
        ctx.fillRect(cr.x, cr.y + cr.height, cr.width, ch - (cr.y + cr.height));

        // Selection border
        ctx.strokeStyle = borderColor;
        ctx.lineWidth = options.isOcrMode ? 2 : 1.5;
        ctx.setLineDash(options.isOcrMode ? [6, 4] : []);
        ctx.strokeRect(cr.x, cr.y, cr.width, cr.height);
        ctx.setLineDash([]);

        if (!options.isOcrMode) {
            const refW = options.canvasWidth || 1920;
            const arm = Math.max(10, Math.min(24, refW * 0.025));
            const edgeLen = Math.max(14, Math.min(30, refW * 0.03));
            const sw = Math.max(1.5, Math.min(3, refW * 0.0035));

            const x1 = cr.x;
            const y1 = cr.y;
            const x2 = cr.x + cr.width;
            const y2 = cr.y + cr.height;
            const cx = (x1 + x2) / 2;
            const cy = (y1 + y2) / 2;

            // Helper: draw a path twice for contrast (white outline + primary fill)
            function drawHandlePath(drawFn) {
                ctx.save();
                ctx.strokeStyle = "#ffffff";
                ctx.lineWidth = sw + 2;
                drawFn();
                ctx.stroke();
                ctx.strokeStyle = Theme.primary;
                ctx.lineWidth = sw;
                drawFn();
                ctx.stroke();
                ctx.restore();
            }

            // 4 Corners — L-shape brackets
            drawHandlePath(() => {
                // Top-left
                ctx.beginPath();
                ctx.moveTo(x1, y1 + arm);
                ctx.lineTo(x1, y1);
                ctx.lineTo(x1 + arm, y1);
                // Top-right
                ctx.moveTo(x2 - arm, y1);
                ctx.lineTo(x2, y1);
                ctx.lineTo(x2, y1 + arm);
                // Bottom-left
                ctx.moveTo(x1, y2 - arm);
                ctx.lineTo(x1, y2);
                ctx.lineTo(x1 + arm, y2);
                // Bottom-right
                ctx.moveTo(x2 - arm, y2);
                ctx.lineTo(x2, y2);
                ctx.lineTo(x2, y2 - arm);
            });

            // 4 Edge centers — short line segments
            drawHandlePath(() => {
                // Top
                ctx.beginPath();
                ctx.moveTo(cx - edgeLen / 2, y1);
                ctx.lineTo(cx + edgeLen / 2, y1);
                // Bottom
                ctx.moveTo(cx - edgeLen / 2, y2);
                ctx.lineTo(cx + edgeLen / 2, y2);
                // Left
                ctx.moveTo(x1, cy - edgeLen / 2);
                ctx.lineTo(x1, cy + edgeLen / 2);
                // Right
                ctx.moveTo(x2, cy - edgeLen / 2);
                ctx.lineTo(x2, cy + edgeLen / 2);
            });
        }
    } else {
        // Dim full canvas slightly before selection
        ctx.fillStyle = overlayColor;
        ctx.fillRect(0, 0, options.canvasWidth, options.canvasHeight);
    }
    ctx.restore();
}

/**
 * Draws the watermark overlay.

 * @param {object} ctx - The Canvas 2D context.
 * @param {object} options - Watermark options and dimensions.
 * @param {object} config - Format helper.
 */
function drawWatermark(ctx, options, config) {
    if (!options.enabled) return;

    ctx.save();
    ctx.globalAlpha = options.opacity;

    if (options.type === "text" || options.type === "hybrid") {
        const textStr = config.formatWatermarkText(options.text);
        const lines = textStr.split("\n");
        const fontSize = Math.round(Math.max(12, options.canvasHeight * options.textScale));
        
        ctx.font = "bold " + fontSize + "px sans-serif";
        ctx.fillStyle = "#ffffff";
        ctx.shadowColor = "#000000";
        ctx.shadowOffsetX = 1;
        ctx.shadowOffsetY = 1;
        ctx.shadowBlur = 2;

        const lineHeight = fontSize * 1.25;
        let maxTextWidth = 0;
        for (let i = 0; i < lines.length; i++) {
            const w = ctx.measureText(lines[i]).width;
            if (w > maxTextWidth) maxTextWidth = w;
        }

        const totalTextHeight = lines.length * lineHeight;
        const margin = 20;
        const spacing = Math.round(fontSize * 0.4);

        const hasImage = (options.type === "hybrid" && options.imageReady);
        let targetW = 0;
        let targetH = 0;
        if (hasImage) {
            const imgW = options.imageSourceSize.width;
            const imgH = options.imageSourceSize.height;
            const maxW = options.canvasWidth * options.imageScale;
            const maxH = options.canvasHeight * options.imageScale;
            const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
            targetW = imgW * scale;
            targetH = imgH * scale;
        }

        const totalW = (hasImage ? targetW + spacing : 0) + maxTextWidth;
        const totalH = Math.max(targetH, totalTextHeight);

        let tx = margin;
        let ty = fontSize + margin;

        const pos = options.position;
        if (pos === "bottom_right") {
            tx = options.canvasWidth - totalW - margin;
            ty = options.canvasHeight - (lines.length - 1) * lineHeight - margin;
        } else if (pos === "bottom_left") {
            tx = margin;
            ty = options.canvasHeight - (lines.length - 1) * lineHeight - margin;
        } else if (pos === "top_right") {
            tx = options.canvasWidth - totalW - margin;
            ty = fontSize + margin;
        } else if (pos === "top_left") {
            tx = margin;
            ty = fontSize + margin;
        } else if (pos === "center") {
            tx = (options.canvasWidth - totalW) / 2;
            ty = (options.canvasHeight - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
        } else if (pos === "top") {
            tx = (options.canvasWidth - totalW) / 2;
            ty = fontSize + margin;
        } else if (pos === "bottom") {
            tx = (options.canvasWidth - totalW) / 2;
            ty = options.canvasHeight - (lines.length - 1) * lineHeight - margin;
        } else if (pos === "left") {
            tx = margin;
            ty = (options.canvasHeight - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
        } else if (pos === "right") {
            tx = options.canvasWidth - totalW - margin;
            ty = (options.canvasHeight - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
        }

        if (hasImage) {
            const iy = ty - fontSize + (totalTextHeight - targetH) / 2;
            ctx.drawImage(options.imageLoader, tx, iy, targetW, targetH);
        }

        const textX = tx + (hasImage ? targetW + spacing : 0);
        for (let i = 0; i < lines.length; i++) {
            ctx.fillText(lines[i], textX, ty + i * lineHeight);
        }

    } else if (options.type === "image" && options.imageReady) {
        const imgW = options.imageSourceSize.width;
        const imgH = options.imageSourceSize.height;
        const maxW = options.canvasWidth * options.imageScale;
        const maxH = options.canvasHeight * options.imageScale;
        const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
        const targetW = imgW * scale;
        const targetH = imgH * scale;

        const margin = 20;
        let ix = margin;
        let iy = margin;

        const pos = options.position;
        if (pos === "bottom_right") {
            ix = options.canvasWidth - targetW - margin;
            iy = options.canvasHeight - targetH - margin;
        } else if (pos === "bottom_left") {
            ix = margin;
            iy = options.canvasHeight - targetH - margin;
        } else if (pos === "top_right") {
            ix = options.canvasWidth - targetW - margin;
            iy = margin;
        } else if (pos === "top_left") {
            ix = margin;
            iy = margin;
        } else if (pos === "center") {
            ix = (options.canvasWidth - targetW) / 2;
            iy = (options.canvasHeight - targetH) / 2;
        } else if (pos === "top") {
            ix = (options.canvasWidth - targetW) / 2;
            iy = margin;
        } else if (pos === "bottom") {
            ix = (options.canvasWidth - targetW) / 2;
            iy = options.canvasHeight - targetH - margin;
        } else if (pos === "left") {
            ix = margin;
            iy = (options.canvasHeight - targetH) / 2;
        } else if (pos === "right") {
            ix = options.canvasWidth - targetW - margin;
            iy = (options.canvasHeight - targetH) / 2;
        }

        ctx.drawImage(options.imageLoader, ix, iy, targetW, targetH);
    }
    ctx.restore();
}
