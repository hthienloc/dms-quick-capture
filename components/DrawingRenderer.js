.pragma library

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
        ctx.moveTo(stroke.points[0].x, stroke.points[0].y);
        for (var i = 1; i < stroke.points.length; i++) {
            ctx.lineTo(stroke.points[i].x, stroke.points[i].y);
        }
        ctx.stroke();

    } else if (stroke.tool === "line") {
        ctx.strokeStyle = stroke.color;
        ctx.lineWidth = stroke.width;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        ctx.beginPath();
        ctx.moveTo(p0.x, p0.y);
        ctx.lineTo(p1.x, p1.y);
        ctx.stroke();

    } else if (stroke.tool === "highlighter") {
        ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.4);
        ctx.lineWidth = stroke.width * 4;
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
            const angle = Math.atan2(dy, dx);
            const spread = Math.PI / 7;
            const headLength = Math.max(15, stroke.width * 4);
            const shaftLength = Math.max(0, len - headLength * 0.8);
            const shaftEndX = p0.x + shaftLength * Math.cos(angle);
            const shaftEndY = p0.y + shaftLength * Math.sin(angle);

            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(shaftEndX, shaftEndY);
            ctx.stroke();

            ctx.beginPath();
            ctx.moveTo(p1.x, p1.y);
            ctx.lineTo(p1.x - headLength * Math.cos(angle - spread), p1.y - headLength * Math.sin(angle - spread));
            ctx.lineTo(p1.x - headLength * Math.cos(angle + spread), p1.y - headLength * Math.sin(angle + spread));
            ctx.closePath();
            ctx.fill();
        }

    } else if (stroke.tool === "redact") {
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const rx = Math.min(p0.x, p1.x);
        const ry = Math.min(p0.y, p1.y);
        const rw = Math.abs(p1.x - p0.x);
        const rh = Math.abs(p1.y - p0.y);
        const radius = config.roundRect ? Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2) : 0;

        ctx.fillStyle = stroke.color;
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
        ctx.fill();

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
                    const sampleSize = Math.max(1, Math.round(blockSize / 5));
                    const imgW = config.bgImageItem.sourceSize.width;
                    const imgH = config.bgImageItem.sourceSize.height;
                    for (let y = ry; y < ry + rh; y += blockSize) {
                        for (let x = rx; x < rx + rw; x += blockSize) {
                            const bw = Math.min(blockSize, rx + rw - x);
                            const bh = Math.min(blockSize, ry + rh - y);
                            if (bw <= 0 || bh <= 0) continue;
                            let sx = Math.min(x + Math.floor(bw / 2), rx + rw - 1);
                            let sy = Math.min(y + Math.floor(bh / 2), ry + rh - 1);
                            sx = Math.max(0, Math.min(sx, Math.max(0, imgW - sampleSize)));
                            sy = Math.max(0, Math.min(sy, Math.max(0, imgH - sampleSize)));
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
        const pt = stroke.points[0];
        const radius = stroke.width * 5;
        const textColor = Helpers.getContrastingColor(stroke.color, Qt);

        ctx.fillStyle = stroke.color;
        ctx.beginPath();
        ctx.arc(pt.x, pt.y, radius, 0, 2 * Math.PI);
        ctx.fill();

        const fontSize = Math.round(radius * 1.2);
        const text = Helpers.formatCounter(stroke.counter, stroke.format || "numeric");
        ctx.fillStyle = textColor;
        ctx.font = "bold " + fontSize + "px sans-serif";
        ctx.textBaseline = "middle";
        ctx.textAlign = "left";
        const textW = ctx.measureText(text).width;
        ctx.fillText(text, pt.x - textW / 2, pt.y + Math.round(fontSize * 0.1));

    } else if (stroke.tool === "text") {
        const pt = stroke.points[0];
        ctx.fillStyle = stroke.color;
        
        let styleStr = "";
        if (stroke.isItalic) styleStr += "italic ";
        if (stroke.isBold) styleStr += "bold ";
        const fFamily = stroke.fontFamily || (stroke.isMonospace ? "monospace" : "sans-serif");
        
        ctx.font = styleStr + Math.round(stroke.width) + "px " + fFamily;
        ctx.textAlign = "left";
        ctx.textBaseline = "top";
        ctx.fillText(stroke.text, pt.x, pt.y);

        if (stroke.isUnderline) {
            const textWidth = ctx.measureText(stroke.text).width;
            ctx.strokeStyle = stroke.color;
            ctx.lineWidth = Math.max(1.5, Math.round(stroke.width * 0.08));
            ctx.beginPath();
            ctx.moveTo(pt.x, pt.y + stroke.width * 1.05);
            ctx.lineTo(pt.x + textWidth, pt.y + stroke.width * 1.05);
            ctx.stroke();
        }
    }
}

/**
 * Draws the selection (crop) overlay with dimming and handles.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} options - Selection options (cropRect, canvasWidth, canvasHeight, isCropMode)
 * @param {object} Theme - The Theme object.
 */
function drawSelectionOverlay(ctx, options, Theme) {
    if (!options.isCropMode) return;

    ctx.save();
    if (options.cropRect.width > 0 && options.cropRect.height > 0) {
        ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
        const cr = options.cropRect;
        const cw = options.canvasWidth;
        const ch = options.canvasHeight;

        // Left
        ctx.fillRect(0, 0, cr.x, ch);
        // Right
        ctx.fillRect(cr.x + cr.width, 0, cw - (cr.x + cr.width), ch);
        // Top
        ctx.fillRect(cr.x, 0, cr.width, cr.y);
        // Bottom
        ctx.fillRect(cr.x, cr.y + cr.height, cr.width, ch - (cr.y + cr.height));

        // Selection border
        ctx.strokeStyle = Theme.primary;
        ctx.lineWidth = 1.5;
        ctx.strokeRect(cr.x, cr.y, cr.width, cr.height);

        // 4 Corner resize handles
        const hs = 10;
        const hh = hs / 2;
        ctx.fillStyle = Theme.primary;
        ctx.strokeStyle = "#ffffff";
        ctx.lineWidth = 1.5;

        const x1 = cr.x;
        const y1 = cr.y;
        const x2 = cr.x + cr.width;
        const y2 = cr.y + cr.height;

        // TL
        ctx.fillRect(x1 - hh, y1 - hh, hs, hs);
        ctx.strokeRect(x1 - hh, y1 - hh, hs, hs);
        // TR
        ctx.fillRect(x2 - hh, y1 - hh, hs, hs);
        ctx.strokeRect(x2 - hh, y1 - hh, hs, hs);
        // BL
        ctx.fillRect(x1 - hh, y2 - hh, hs, hs);
        ctx.strokeRect(x1 - hh, y2 - hh, hs, hs);
        // BR
        ctx.fillRect(x2 - hh, y2 - hh, hs, hs);
        ctx.strokeRect(x2 - hh, y2 - hh, hs, hs);
    } else {
        // Dim full canvas slightly before selection
        ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
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
