.pragma library
.import "Helpers.js" as Helpers
.import "Constants.js" as Constants

/**
 * Returns the point where a ray from an ellipse center toward a target hits the ellipse edge.
 * @param {number} cx - Ellipse center X.
 * @param {number} cy - Ellipse center Y.
 * @param {number} rx - Ellipse X radius.
 * @param {number} ry - Ellipse Y radius.
 * @param {number} tx - Target X.
 * @param {number} ty - Target Y.
 * @returns {object} Edge point { x, y }.
 */
function ellipseEdgePoint(cx, cy, rx, ry, tx, ty) {
    const dx = tx - cx;
    const dy = ty - cy;
    if (dx === 0 && dy === 0) { return { x: cx + rx, y: cy }; }
    const angle = Math.atan2(dy, dx);
    return { x: cx + rx * Math.cos(angle), y: cy + ry * Math.sin(angle) };
}

/**
 * Maps canvas coordinates (x, y) to the un-transformed source image pixel coordinates (sx, sy)
 * taking into account rotation, horizontal/vertical flips, and crop selection offsets.
 */
function getTransformedSourcePos(x, y, config) {
    if (!config || !config.bgImageItem) return { x: Math.floor(x), y: Math.floor(y) };

    const rawW = config.bgImageItem.sourceSize.width;
    const rawH = config.bgImageItem.sourceSize.height;
    const rot = (config.bgRotation !== undefined) ? config.bgRotation : 0;
    const flipH = !!config.bgFlipH;
    const flipV = !!config.bgFlipV;

    const cropX = (config.hasActiveCropSelection && config.cropRect) ? config.cropRect.x : (config.cropOffsetX || 0);
    const cropY = (config.hasActiveCropSelection && config.cropRect) ? config.cropRect.y : (config.cropOffsetY || 0);

    const isRotated90 = (rot === 90 || rot === 270);
    const uncroppedW = isRotated90 ? rawH : rawW;
    const uncroppedH = isRotated90 ? rawW : rawH;

    // 1. Shift by crop selection to get position relative to uncropped canvas center
    let cx = (x + cropX) - uncroppedW / 2;
    let cy = (y + cropY) - uncroppedH / 2;

    // 2. Inverse rotation transform
    let rcx = cx;
    let rcy = cy;
    if (rot === 90) {
        rcx = cy;
        rcy = -cx;
    } else if (rot === 180) {
        rcx = -cx;
        rcy = -cy;
    } else if (rot === 270) {
        rcx = -cy;
        rcy = cx;
    }

    // 3. Inverse flip transform
    if (flipH) rcx = -rcx;
    if (flipV) rcy = -rcy;

    // 4. Translate back to raw image top-left
    const sx = rcx + rawW / 2;
    const sy = rcy + rawH / 2;

    return {
        x: Math.max(0, Math.min(Math.floor(sx), rawW - 1)),
        y: Math.max(0, Math.min(Math.floor(sy), rawH - 1))
    };
}

/**
 * Calculates the shared stamp leader geometry at the circle edge.
 * @param {object} stampPt - Stamp center point.
 * @param {object} leaderPt - Leader anchor point.
 * @param {number} radius - Stamp circle radius.
 * @param {number} baseHalfWidth - Half-width of the leader base.
 * @returns {object|null} Unit vector, edge point and leader base points.
 */
function stampTailGeometry(stampPt, leaderPt, radius, baseHalfWidth) {
    const dx = leaderPt.x - stampPt.x;
    const dy = leaderPt.y - stampPt.y;
    const distance = Math.sqrt(dx * dx + dy * dy);
    if (distance <= 0.001) return null;

    const ux = dx / distance;
    const uy = dy / distance;
    const px = -uy;
    const py = ux;
    const overlap = Math.max(1.5, Math.min(radius * 0.18, baseHalfWidth * 0.35));
    const edge = {
        x: stampPt.x + ux * (radius - overlap),
        y: stampPt.y + uy * (radius - overlap)
    };
    return {
        ux: ux,
        uy: uy,
        edge: edge,
        base1: { x: edge.x + px * baseHalfWidth, y: edge.y + py * baseHalfWidth },
        base2: { x: edge.x - px * baseHalfWidth, y: edge.y - py * baseHalfWidth }
    };
}

/**
 * Clamps a bubble leader's center to the usable portion of one edge.
 * @param {number} target - Projected target coordinate on the edge.
 * @param {number} edgeStart - Edge start coordinate.
 * @param {number} edgeEnd - Edge end coordinate.
 * @param {number} tailBaseSize - Half-width of the leader base.
 * @param {number} radius - Bubble corner radius.
 * @returns {number} Usable leader center coordinate.
 */
function getBubbleTailCenter(target, edgeStart, edgeEnd, tailBaseSize, radius) {
    const edgePadding = Math.max(tailBaseSize, radius * 0.35);
    const minAllowed = edgeStart + edgePadding;
    const maxAllowed = edgeEnd - edgePadding;
    if (maxAllowed < minAllowed) return (edgeStart + edgeEnd) / 2;
    return Math.max(minAllowed, Math.min(target, maxAllowed));
}

/**
 * Converts a user/theme font family into a safe Canvas font-family token.
 * Generic families are returned as-is; custom names are quoted and escaped.
 * @param {string} family - Requested font family.
 * @returns {string} Canvas-safe font family.
 */
function canvasFontFamily(family) {
    const fallback = "sans-serif";
    if (!family) return fallback;

    const normalized = String(family).trim();
    if (normalized === "") return fallback;

    const lower = normalized.toLowerCase();
    if (lower === "sans-serif" || lower === "serif" || lower === "monospace" ||
        lower === "cursive" || lower === "fantasy" || lower === "system-ui") {
        return normalized;
    }

    if ((normalized.startsWith("\"") && normalized.endsWith("\"")) ||
        (normalized.startsWith("'") && normalized.endsWith("'"))) {
        return normalized;
    }

    return `"${normalized.replace(/"/g, "\\\"")}"`;
}

/**
 * Resolves the font family used by a text stroke.
 * @param {object} stroke - Text stroke data.
 * @param {object} Theme - The Theme object.
 * @returns {string} Canvas-safe font family.
 */
function textFontFamily(stroke, Theme) {
    const systemFamily = (typeof Theme !== "undefined" && Theme.fontFamily) ? Theme.fontFamily : "sans-serif";
    const family = (stroke.fontFamily && stroke.fontFamily !== "system") ? stroke.fontFamily : systemFamily;
    return canvasFontFamily(family);
}

/**
 * Applies font and text alignment settings for rendering or measuring a text stroke.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - Text stroke data.
 * @param {object} Theme - The Theme object.
 */
function configureTextContext(ctx, stroke, Theme) {
    let style = "";
    if (stroke.isItalic) style += "italic ";
    if (stroke.isBold) style += "bold ";
    ctx.font = `${style}${Math.round(stroke.width)}px ${textFontFamily(stroke, Theme)}`;
    ctx.textAlign = "left";
    ctx.textBaseline = "middle";
}

/**
 * Returns fill, halo, and accent colors for selection handles.
 * Fill/halo are inverted based on Theme.primary luminance so handles keep
 * contrast without sampling the underlying screenshot.
 * @param {object} Theme - The Theme object.
 * @returns {object} { fill, halo, accent } colors.
 */
function handleColors(Theme) {
    const primary = Theme && Theme.primary ? Theme.primary : null;
    const accent = primary || "#3b82f6";
    if (!primary || primary.r === undefined || primary.g === undefined || primary.b === undefined) {
        return {
            fill: "#ffffff",
            halo: "#000000",
            accent: accent
        };
    }
    const fill = Helpers.getContrastingColorFromRgb(primary);
    const halo = fill === "#ffffff" ? "#000000" : "#ffffff";
    return {
        fill: fill,
        halo: halo,
        accent: accent
    };
}

/**
 * Measures the same multiline text layout used by drawStroke(). Width comes
 * from Canvas and vertical bounds come from the renderer's line boxes.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - Text stroke data.
 * @param {object} Theme - The Theme object.
 * @returns {object|null} Text bounds and line metrics, or null when unavailable.
 */
function measureTextLayout(ctx, stroke, Theme) {
    if (!ctx || !stroke || !stroke.points || stroke.points.length === 0) return null;

    const pt = (stroke.isSpeechBubble && stroke.points.length >= 2) ? stroke.points[1] : stroke.points[0];
    const fontSize = stroke.width;
    const lines = String(stroke.text || "").split("\n");
    const lineHeight = fontSize * Constants.textLineHeightMultiplier;
    let minX = Infinity;
    let minY = Infinity;
    let maxX = -Infinity;
    let maxY = -Infinity;
    let maxAdvanceWidth = 0;

    ctx.save();
    configureTextContext(ctx, stroke, Theme);

    for (let i = 0; i < lines.length; i++) {
        const metrics = ctx.measureText(lines[i]);
        const advance = metrics.width || 0;
        const left = pt.x;
        const right = pt.x + advance;
        const top = pt.y + i * lineHeight;
        const bottom = top + fontSize;

        minX = Math.min(minX, left);
        minY = Math.min(minY, top);
        maxX = Math.max(maxX, right);
        maxY = Math.max(maxY, bottom);
        maxAdvanceWidth = Math.max(maxAdvanceWidth, advance);

        if (stroke.isUnderline) {
            const underlineY = pt.y + i * lineHeight + fontSize * 1.1;
            const halfWidth = Math.max(1.5, Math.round(fontSize * 0.08)) / 2;
            minX = Math.min(minX, pt.x);
            maxX = Math.max(maxX, pt.x + advance);
            minY = Math.min(minY, underlineY - halfWidth);
            maxY = Math.max(maxY, underlineY + halfWidth);
        }
    }

    if (stroke.hasBackground || stroke.isSpeechBubble) {
        const isBubble = stroke.isSpeechBubble && stroke.points.length >= 2;
        const padX = fontSize * (isBubble ? Constants.textBubblePaddingMultiplierX : Constants.textPaddingMultiplierX);
        const padY = fontSize * (isBubble ? Constants.textBubblePaddingMultiplierY : Constants.textPaddingMultiplierY);
        const lineBoxHeight = fontSize + (lines.length - 1) * lineHeight;
        minX = Math.min(minX, pt.x - padX);
        minY = Math.min(minY, pt.y - padY);
        maxX = Math.max(maxX, pt.x + maxAdvanceWidth + padX);
        maxY = Math.max(maxY, pt.y + lineBoxHeight + padY);
    }

    ctx.restore();
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
}

/**
 * Draws the spotlight dimming overlay with holes for spotlight rectangles.
 * Extracted to avoid duplication across bakedCanvas, drawingCanvas, and exportCanvas onPaint handlers.
 *
 * @param {object} ctx - Canvas 2D context (must be in save/restore pair)
 * @param {Array} spotlights - Array of spotlight stroke objects
 * @param {object} config - Configuration object with:
 *   - screenshotWidth, screenshotHeight: canvas dimensions
 *   - spotlightIntensity: 0-100 opacity value
 *   - hasActiveCropSelection: boolean
 *   - cropRect: {x, y, width, height}
 *   - effectiveBackgroundMode: "none" | "solid" | "gradient" | etc.
 *   - backgroundCornerRadius: number
 *   - roundRect: boolean
 *   - cornerRadius: number (Theme.cornerRadius)
 */
function drawSpotlightOverlay(ctx, spotlights, config) {
    if (spotlights.length === 0) return;

    const sw = config.screenshotWidth;
    const sh = config.screenshotHeight;
    const spotlightOpacity = config.spotlightIntensity / 100.0;
    const cropX = config.hasActiveCropSelection ? config.cropRect.x : 0;
    const cropY = config.hasActiveCropSelection ? config.cropRect.y : 0;

    function appendRectPath(x, y, w, h, radius) {
        if (radius <= 0) {
            ctx.rect(x, y, w, h);
            return;
        }

        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + w - radius, y);
        ctx.arcTo(x + w, y, x + w, y + radius, radius);
        ctx.lineTo(x + w, y + h - radius);
        ctx.arcTo(x + w, y + h, x + w - radius, y + h, radius);
        ctx.lineTo(x + radius, y + h);
        ctx.arcTo(x, y + h, x, y + h - radius, radius);
        ctx.lineTo(x, y + radius);
        ctx.arcTo(x, y, x + radius, y, radius);
        ctx.closePath();
    }

    ctx.save();
    ctx.beginPath();

    // Outer rectangle covering the whole view (rounded if background active)
    if (config.effectiveBackgroundMode !== "none" && config.backgroundCornerRadius > 0) {
        const r = Math.min(config.backgroundCornerRadius, sw / 2, sh / 2);
        appendRectPath(cropX, cropY, sw, sh, r);
    } else {
        appendRectPath(cropX, cropY, sw, sh, 0);
    }

    // Decompose the spotlight union into non-overlapping vertical bands.
    const rawRects = [];
    for (let i = 0; i < spotlights.length; i++) {
        const s = spotlights[i];
        if (s.points.length >= 2) {
            const p0 = s.points[0];
            const p1 = s.points[s.points.length - 1];
            const bounds = Helpers.getRectBounds(p0, p1);
            const rx = bounds.x1;
            const ry = bounds.y1;
            const rw = bounds.x2 - bounds.x1;
            const rh = bounds.y2 - bounds.y1;

            if (rw > 0 && rh > 0) {
                rawRects.push({ x1: rx, y1: ry, x2: bounds.x2, y2: bounds.y2 });
            }
        }
    }

    let hasOverlap = false;
    for (let i = 0; i < rawRects.length && !hasOverlap; i++) {
        for (let j = i + 1; j < rawRects.length; j++) {
            const a = rawRects[i];
            const b = rawRects[j];
            if (a.x1 < b.x2 && a.x2 > b.x1 && a.y1 < b.y2 && a.y2 > b.y1) {
                hasOverlap = true;
                break;
            }
        }
    }

    if (!hasOverlap) {
        for (let i = 0; i < rawRects.length; i++) {
            const rect = rawRects[i];
            const radius = config.roundRect ? Math.min(config.cornerRadius,
                (rect.x2 - rect.x1) / 2, (rect.y2 - rect.y1) / 2) : 0;
            appendRectPath(rect.x1, rect.y1, rect.x2 - rect.x1, rect.y2 - rect.y1, radius);
        }
    } else {
        const xEdges = [];
        for (let i = 0; i < rawRects.length; i++) {
            xEdges.push(rawRects[i].x1, rawRects[i].x2);
        }
        xEdges.sort((a, b) => a - b);

        const uniqueXEdges = xEdges.filter((x, i) => i === 0 || x !== xEdges[i - 1]);
        for (let i = 0; i < uniqueXEdges.length - 1; i++) {
            const bandX = uniqueXEdges[i];
            const bandWidth = uniqueXEdges[i + 1] - bandX;
            if (bandWidth <= 0) continue;

            const intervals = rawRects
                .filter(rect => rect.x1 < uniqueXEdges[i + 1] && rect.x2 > bandX)
                .map(rect => ({ y1: rect.y1, y2: rect.y2 }))
                .sort((a, b) => a.y1 - b.y1);

            let merged = [];
            for (let j = 0; j < intervals.length; j++) {
                const interval = intervals[j];
                const last = merged[merged.length - 1];
                if (last && interval.y1 <= last.y2) {
                    last.y2 = Math.max(last.y2, interval.y2);
                } else {
                    merged.push({ y1: interval.y1, y2: interval.y2 });
                }
            }

            for (let j = 0; j < merged.length; j++) {
                const interval = merged[j];
                ctx.rect(bandX, interval.y1, bandWidth, interval.y2 - interval.y1);
            }
        }
    }

    // The union bands do not overlap, so even-odd clipping is stable here.
    ctx.clip("evenodd");
    ctx.fillStyle = `rgba(0, 0, 0, ${spotlightOpacity})`;
    ctx.fillRect(cropX, cropY, sw, sh);
    ctx.restore();
}

/**
 * Creates an ellipse path on the current context.
 * @param {object} ctx - The Canvas 2D context.
 * @param {number} cx - Ellipse center X.
 * @param {number} cy - Ellipse center Y.
 * @param {number} rx - Ellipse X radius.
 * @param {number} ry - Ellipse Y radius.
 */
function drawEllipsePath(ctx, cx, cy, rx, ry) {
    ctx.save();
    ctx.translate(cx, cy);
    ctx.scale(rx, ry);
    ctx.beginPath();
    ctx.arc(0, 0, 1, 0, 2 * Math.PI);
    ctx.restore();
}

/**
 * DrawingRenderer.js
 * Encapsulates all drawing logic for the Quick Capture plugin.
 * This library is designed to be pure and context-aware, receiving the Canvas context (ctx)
 * and necessary state from the QML component.
 */

/**
 * Sets up the canvas context for drawing a dashed selection border with auto-contrast color.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - The stroke data object (provides color and width).
 * @param {object} Helpers - Reference to the Helpers.js library.
 * @param {object} Qt - The Qt object for color utilities.
 */
function setDashedSelectionStyle(ctx, stroke, Helpers, Qt) {
    ctx.strokeStyle = Helpers.getContrastingColor(stroke.color, Qt);
    ctx.lineWidth = Math.max(1.5, Math.min(2.5, stroke.width / 2));
    ctx.setLineDash([4, 4]);
}

/**
 * Draws a dashed rectangle with dashes anchored to absolute screen coordinates.
 * Prevents dashes on right, bottom, and left edges from sliding/shifting during resize.
 * @param {object} ctx - The Canvas 2D context.
 * @param {number} x - X coordinate.
 * @param {number} y - Y coordinate.
 * @param {number} w - Width.
 * @param {number} h - Height.
 */
function drawStableDashedRect(ctx, x, y, w, h) {
    const x1 = Math.min(x, x + w);
    const x2 = Math.max(x, x + w);
    const y1 = Math.min(y, y + h);
    const y2 = Math.max(y, y + h);

    ctx.lineDashOffset = 0;

    // Top edge
    ctx.beginPath();
    ctx.moveTo(x1, y1);
    ctx.lineTo(x2, y1);
    ctx.stroke();

    // Right edge
    ctx.beginPath();
    ctx.moveTo(x2, y1);
    ctx.lineTo(x2, y2);
    ctx.stroke();

    // Bottom edge
    ctx.beginPath();
    ctx.moveTo(x2, y2);
    ctx.lineTo(x1, y2);
    ctx.stroke();

    // Left edge
    ctx.beginPath();
    ctx.moveTo(x1, y2);
    ctx.lineTo(x1, y1);
    ctx.stroke();
}

/**
 * Draws a high-contrast dual-tone (alternating black and white dashes) selection rectangle.
 * @param {object} ctx - The Canvas 2D context.
 * @param {number} x - X coordinate.
 * @param {number} y - Y coordinate.
 * @param {number} w - Width.
 * @param {number} h - Height.
 */
function drawHighContrastDashedRect(ctx, x, y, w, h) {
    ctx.save();
    ctx.lineWidth = 1.5;

    // Layer 1: Solid white line underneath
    ctx.setLineDash([]);
    ctx.strokeStyle = "#ffffff";
    ctx.strokeRect(x, y, w, h);

    // Layer 2: Black dashed line on top (gap reveals white underneath)
    ctx.setLineDash([4, 4]);
    ctx.strokeStyle = "#000000";
    drawStableDashedRect(ctx, x, y, w, h);

    ctx.restore();
}

/**
 * Draws selection handle squares with contrast halo and Theme.primary accent stroke.
 * @param {object} ctx - The Canvas 2D context.
 * @param {Array} points - Array of {x, y} handle positions.
 * @param {number} hh - Half the handle size (for centering).
 * @param {number} hs - Handle size in pixels.
 * @param {object} Theme - The Theme object.
 */
function drawHandlePoints(ctx, points, hh, hs, Theme) {
    const colors = handleColors(Theme);
    for (let p of points) {
        ctx.fillStyle = colors.fill;
        ctx.strokeStyle = colors.halo;
        ctx.lineWidth = 3;
        ctx.fillRect(p.x - hh, p.y - hh, hs, hs);
        ctx.strokeRect(p.x - hh, p.y - hh, hs, hs);
        ctx.strokeStyle = colors.accent;
        ctx.lineWidth = 1.5;
        ctx.fillRect(p.x - hh, p.y - hh, hs, hs);
        ctx.strokeRect(p.x - hh, p.y - hh, hs, hs);
    }
}

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

    ctx.setLineDash([]);
    ctx.lineDashOffset = 0;

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
        for (let i = 1; i < stroke.points.length; i++) {
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
        const bounds = Helpers.getRectBounds(p0, p1);
        const rx = bounds.x1;
        const ry = bounds.y1;
        const rw = bounds.x2 - bounds.x1;
        const rh = bounds.y2 - bounds.y1;
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
        const bounds = Helpers.getRectBounds(p0, p1);
        const rx = bounds.x1;
        const ry = bounds.y1;
        const rw = bounds.x2 - bounds.x1;
        const rh = bounds.y2 - bounds.y1;

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
        const bounds = Helpers.getRectBounds(p0, p1);
        const rx = Math.floor(bounds.x1);
        const ry = Math.floor(bounds.y1);
        const rw = Math.floor(bounds.x2 - bounds.x1);
        const rh = Math.floor(bounds.y2 - bounds.y1);
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
            const bounds = Helpers.getRectBounds(p0, p1);
            const rx = Math.floor(bounds.x1);
            const ry = Math.floor(bounds.y1);
            const rw = Math.floor(bounds.x2 - bounds.x1);
            const rh = Math.floor(bounds.y2 - bounds.y1);

            if (rw > 2 && rh > 2) {
                ctx.save();
                ctx.beginPath();
                ctx.rect(rx, ry, rw, rh);
                ctx.clip();
                ctx.imageSmoothingEnabled = false;

                if (config.bgImageItem && config.bgImageItem.status === 1 /* Image.Ready */) {
                    const pixelateMeta = Constants.getToolMeta("pixelate");
                    const blockSize = Math.max(pixelateMeta.previewClampMin, Math.min(pixelateMeta.previewClampMax, stroke.width * 3));
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
                                const sampledCanvasX = x + (h % bw);
                                const sampledCanvasY = y + ((h >>> 8) % bh);
                                const srcPos = getTransformedSourcePos(sampledCanvasX, sampledCanvasY, config);
                                sx = srcPos.x;
                                sy = srcPos.y;
                            } else {
                                sampleSize = Math.max(1, Math.round(blockSize / 5));
                                const sampledCanvasX = Math.min(x + Math.floor(bw / 2), rx + rw - 1);
                                const sampledCanvasY = Math.min(y + Math.floor(bh / 2), ry + rh - 1);
                                const srcPos = getTransformedSourcePos(sampledCanvasX, sampledCanvasY, config);
                                sx = Math.max(0, Math.min(srcPos.x, Math.max(0, imgW - sampleSize)));
                                sy = Math.max(0, Math.min(srcPos.y, Math.max(0, imgH - sampleSize)));
                            }
                            ctx.drawImage(config.bgImageItem, sx, sy, sampleSize, sampleSize, x, y, bw + 1, bh + 1);
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
        const drawOuterRing = config && config.stampOuterRing === true;
        const ringWidth = Math.max(1.5, stroke.width * 0.5);
        const leaderStartPt = hasLeader ? stroke.points[0] : null;
        const tailBaseHalfWidth = Math.max(4, Math.min(radius * 0.28, stroke.width * 1.15));

        function drawStampTail(fillColor, shapeRadius, baseHalfWidth, tipInset) {
            if (!hasLeader) return;
            const geometry = stampTailGeometry(stampPt, leaderStartPt, shapeRadius, baseHalfWidth);
            if (!geometry) return;
            const tip = {
                x: leaderStartPt.x - geometry.ux * tipInset,
                y: leaderStartPt.y - geometry.uy * tipInset
            };

            ctx.fillStyle = fillColor;
            ctx.beginPath();
            ctx.moveTo(geometry.base1.x, geometry.base1.y);
            ctx.lineTo(tip.x, tip.y);
            ctx.lineTo(geometry.base2.x, geometry.base2.y);
            ctx.closePath();
            ctx.fill();
        }

        ctx.save();
        if (drawOuterRing) {
            drawStampTail(textColor, radius + ringWidth, tailBaseHalfWidth + ringWidth, 0);
            ctx.fillStyle = textColor;
            ctx.beginPath();
            ctx.arc(stampPt.x, stampPt.y, radius + ringWidth, 0, 2 * Math.PI);
            ctx.fill();
        }

        // Draw tail and stamp circle background at stamp position.
        drawStampTail(stroke.color, radius, tailBaseHalfWidth, drawOuterRing ? ringWidth * 1.5 : 0);
        ctx.fillStyle = stroke.color;
        ctx.beginPath();
        ctx.arc(stampPt.x, stampPt.y, radius, 0, 2 * Math.PI);
        ctx.fill();
        ctx.restore();

        // Draw text. Keep the actual canvas font below common glyph-cache cliffs
        // and scale the context so the visual size still tracks stamp size.
        ctx.save();
        const visualFontSize = Math.round(radius * Constants.stampTextFontSizeMultiplier);
        const fontSize = Math.min(48, visualFontSize);
        const textScale = visualFontSize / fontSize;
        const text = Helpers.formatCounter(stroke.counter, stroke.format || "numeric");
        ctx.fillStyle = textColor;
        const fontFam = canvasFontFamily((config && config.stampFontFamily) || ((typeof Theme !== "undefined" && Theme.fontFamily) ? Theme.fontFamily : "sans-serif"));
        ctx.font = `bold ${fontSize}px ${fontFam}`;
        ctx.textBaseline = "middle";
        ctx.textAlign = "left";
        const textW = ctx.measureText(text).width;
        ctx.translate(stampPt.x, stampPt.y);
        ctx.scale(textScale, textScale);
        ctx.fillText(text, -textW / 2, Math.round(fontSize * Constants.stampTextOffsetMultiplier));
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
                const visX = config.canvasMinX || 0;
                const visY = config.canvasMinY || 0;
                const visW = config.canvasWidth || Constants.fallbackCanvasWidth;
                const visH = config.canvasHeight || Constants.fallbackCanvasHeight;
                const placement = Helpers.getCalloutPlacement(
                    p0, p1, stroke.width / 100.0,
                    visX, visY, visW, visH,
                    Constants.calloutAutoPlacementMargin
                );
                srcP0 = placement.sourceStart;
                srcP1 = placement.sourceEnd;
                dstP0 = placement.destinationStart;
                dstP1 = placement.destinationEnd;
            }

            // Rotation and mirroring can reverse the point order. Normalize
            // both rectangles before using their dimensions and corners.
            const srcBounds = Helpers.getRectBounds(srcP0, srcP1);
            const dstBounds = Helpers.getRectBounds(dstP0, dstP1);
            srcP0 = { x: srcBounds.x1, y: srcBounds.y1 };
            srcP1 = { x: srcBounds.x2, y: srcBounds.y2 };
            dstP0 = { x: dstBounds.x1, y: dstBounds.y1 };
            dstP1 = { x: dstBounds.x2, y: dstBounds.y2 };
            
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
                const isEllipse = stroke.calloutShape === "ellipse";
                const srcCx = sx + sw / 2;
                const srcCy = sy + sh / 2;
                const dstCx = dx + dw / 2;
                const dstCy = dy + dh / 2;

                // 1. Draw source border
                ctx.strokeStyle = stroke.color;
                ctx.lineWidth = bW;
                if (isEllipse) {
                    drawEllipsePath(ctx, srcCx, srcCy, sw / 2, sh / 2);
                    ctx.stroke();
                    drawEllipsePath(ctx, srcCx, srcCy, sw / 2 + 1, sh / 2 + 1);
                } else {
                    ctx.strokeRect(sx, sy, sw, sh);
                }

                ctx.strokeStyle = "rgba(0,0,0,0.4)";
                ctx.lineWidth = 1;
                if (isEllipse) {
                    ctx.stroke();
                } else {
                    ctx.strokeRect(sx - bW/2 - 0.5, sy - bW/2 - 0.5, sw + bW + 1, sh + bW + 1);
                }

                // 2. Draw connecting lines using semi-transparent stroke color
                const linkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 2;
                ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.6);
                ctx.lineWidth = bW;
                ctx.beginPath();

                if (isEllipse) {
                    const srcRx = sw / 2;
                    const srcRy = sh / 2;
                    const dstRx = dw / 2;
                    const dstRy = dh / 2;
                    if (linkLines === 2) {
                        const e1 = ellipseEdgePoint(srcCx, srcCy, srcRx, srcRy, dstP0.x, dstP0.y);
                        const e2 = ellipseEdgePoint(srcCx, srcCy, srcRx, srcRy, dstP1.x, dstP1.y);
                        const d1 = ellipseEdgePoint(dstCx, dstCy, dstRx, dstRy, srcP0.x, srcP0.y);
                        const d2 = ellipseEdgePoint(dstCx, dstCy, dstRx, dstRy, srcP1.x, srcP1.y);
                        ctx.moveTo(e1.x, e1.y); ctx.lineTo(d1.x, d1.y);
                        ctx.moveTo(e2.x, e2.y); ctx.lineTo(d2.x, d2.y);
                    } else {
                        const e1 = ellipseEdgePoint(srcCx, srcCy, srcRx, srcRy, dstCx, dstCy);
                        const d1 = ellipseEdgePoint(dstCx, dstCy, dstRx, dstRy, srcCx, srcCy);
                        ctx.moveTo(e1.x, e1.y); ctx.lineTo(d1.x, d1.y);
                    }
                } else if (linkLines === 2) {
                    if (dx > sx + sw) {
                        ctx.moveTo(srcP1.x, srcP0.y); ctx.lineTo(dstP0.x, dstP0.y);
                        ctx.moveTo(srcP1.x, srcP1.y); ctx.lineTo(dstP0.x, dstP1.y);
                    } else if (dx + dw < sx) {
                        ctx.moveTo(srcP0.x, srcP0.y); ctx.lineTo(dstP1.x, dstP0.y);
                        ctx.moveTo(srcP0.x, srcP1.y); ctx.lineTo(dstP1.x, dstP1.y);
                    } else {
                        ctx.moveTo(srcP0.x, srcP1.y); ctx.lineTo(dstP0.x, dstP0.y);
                        ctx.moveTo(srcP1.x, srcP1.y); ctx.lineTo(dstP1.x, dstP0.y);
                    }
                } else {
                    if (dx > sx + sw) {
                        ctx.moveTo(sx + sw, sy + sh / 2);
                        ctx.lineTo(dx, dy + dh / 2);
                    } else if (dx + dw < sx) {
                        ctx.moveTo(sx, sy + sh / 2);
                        ctx.lineTo(dx + dw, dy + dh / 2);
                    } else {
                        if (dy > sy + sh) {
                            ctx.moveTo(sx + sw / 2, sy + sh);
                            ctx.lineTo(dx + dw / 2, dy);
                        } else {
                            ctx.moveTo(sx + sw / 2, sy);
                            ctx.lineTo(dx + dw / 2, dy + dh);
                        }
                    }
                }
                ctx.stroke();

                // 3. Draw destination image (foreground magnified pop-up view)
                if (config.bgImageItem && config.bgImageItem.status === 1) {
                    const rawW = config.bgImageItem.sourceSize
                        ? config.bgImageItem.sourceSize.width
                        : (config.bgImageItem.width || 0);
                    const rawH = config.bgImageItem.sourceSize
                        ? config.bgImageItem.sourceSize.height
                        : (config.bgImageItem.height || 0);
                    if (rawW > 0 && rawH > 0) {
                        const rotation = config.bgRotation || 0;
                        const isRotated90 = rotation === 90 || rotation === 270;
                        const imageW = isRotated90 ? rawH : rawW;
                        const imageH = isRotated90 ? rawW : rawH;
                        ctx.save();
                        ctx.beginPath();
                        if (isEllipse) {
                            drawEllipsePath(ctx, dstCx, dstCy, dw / 2, dh / 2);
                        } else {
                            ctx.rect(dx, dy, dw, dh);
                        }
                        ctx.clip();

                        // Map the transformed source rectangle to the destination
                        // while applying the same image transform as the background.
                        ctx.translate(dx, dy);
                        ctx.scale(dw / sw, dh / sh);
                        ctx.translate(-sx, -sy);
                        ctx.translate(imageW / 2, imageH / 2);
                        if (rotation !== 0) ctx.rotate(rotation * Math.PI / 180);
                        ctx.scale(config.bgFlipH ? -1 : 1, config.bgFlipV ? -1 : 1);
                        ctx.drawImage(config.bgImageItem, -rawW / 2, -rawH / 2, rawW, rawH);
                        ctx.restore();
                    }
                }

                // 4. Draw destination border and shadow (foreground)
                ctx.strokeStyle = stroke.color;
                ctx.lineWidth = bW;
                if (isEllipse) {
                    ctx.beginPath();
                    drawEllipsePath(ctx, dstCx, dstCy, dw / 2, dh / 2);
                    ctx.stroke();
                } else {
                    ctx.strokeRect(dx, dy, dw, dh);
                }

                ctx.strokeStyle = "rgba(0,0,0,0.4)";
                ctx.lineWidth = 1;
                if (isEllipse) {
                    ctx.beginPath();
                    drawEllipsePath(ctx, dstCx, dstCy, dw / 2 + 1, dh / 2 + 1);
                    ctx.stroke();
                } else {
                    ctx.strokeRect(dx - bW/2 - 0.5, dy - bW/2 - 0.5, dw + bW + 1, dh + bW + 1);
                }
            }
        }

    } else if (stroke.tool === "text") {
        const pt = (stroke.isSpeechBubble && stroke.points.length >= 2) ? stroke.points[1] : stroke.points[0];
        ctx.fillStyle = stroke.color;
        
        configureTextContext(ctx, stroke, Theme);

        const lines = (stroke.text || "").split("\n");
        const lineHeight = stroke.width * Constants.textLineHeightMultiplier;

        const isBubble = stroke.isSpeechBubble && stroke.points.length >= 2;
        const textBounds = measureTextLayout(ctx, stroke, Theme);
        const textFrame = Helpers.getTextTransformFrame(stroke, textBounds);
        ctx.save();
        ctx.translate(textFrame.center.x, textFrame.center.y);
        ctx.rotate(textFrame.angle);
        ctx.translate(-textFrame.center.x, -textFrame.center.y);

        if (isBubble || stroke.hasBackground) {
            let maxWidth = 0;
            for (let li = 0; li < lines.length; li++) {
                const m = ctx.measureText(lines[li]);
                if (m.width > maxWidth) maxWidth = m.width;
            }
            const h = stroke.width;
            const padX = h * (isBubble ? Constants.textBubblePaddingMultiplierX : Constants.textPaddingMultiplierX);
            const padY = h * (isBubble ? Constants.textBubblePaddingMultiplierY : Constants.textPaddingMultiplierY);
            const totalH = lines.length * lineHeight - (lineHeight - h);
            const rx = pt.x - padX;
            const ry = pt.y - padY;
            const rw = maxWidth + padX * 2;
            const rh = totalH + padY * 2;
            const radius = isBubble ? Math.max(Constants.textBubbleMinRadius, stroke.cornerRadius || Constants.textBubbleDefaultRadius) : (stroke.cornerRadius || 0);

            ctx.save();

            if (isBubble) {
                const contrastColor = Helpers.getContrastingColor(stroke.color, Qt);
                ctx.fillStyle = (contrastColor === "#ffffff") ? "rgba(255, 255, 255, 0.95)" : "rgba(30, 30, 30, 0.95)";
            } else {
                ctx.fillStyle = Helpers.getContrastingColor(stroke.color, Qt);
            }

            if (isBubble) {
                const p1 = stroke.points[0];
                const tx = p1.x;
                const ty = p1.y;
                const cx = rx + rw / 2;
                const cy = ry + rh / 2;
                const inBubble = tx >= rx && tx <= rx + rw && ty >= ry && ty <= ry + rh;

                let activeEdge = "";
                if (!inBubble) {
                    const dx = tx - cx;
                    const dy = ty - cy;
                    const angle = Math.atan2(dy, dx);
                    const diagAngle = Math.atan2(rh, rw);

                    if (angle >= -diagAngle && angle < diagAngle) {
                        activeEdge = "right";
                    } else if (angle >= diagAngle && angle < Math.PI - diagAngle) {
                        activeEdge = "bottom";
                    } else if (angle >= Math.PI - diagAngle || angle < -Math.PI + diagAngle) {
                        activeEdge = "left";
                    } else {
                        activeEdge = "top";
                    }
                }

                let base1X = 0, base1Y = 0, base2X = 0, base2Y = 0;
                const tailBaseSize = Math.max(8, stroke.width * 0.3);

                if (activeEdge === "top") {
                    const closestX = getBubbleTailCenter(tx, rx, rx + rw, tailBaseSize, radius);
                    base1X = closestX - tailBaseSize;
                    base1Y = ry;
                    base2X = closestX + tailBaseSize;
                    base2Y = ry;
                } else if (activeEdge === "bottom") {
                    const closestX = getBubbleTailCenter(tx, rx, rx + rw, tailBaseSize, radius);
                    base1X = closestX - tailBaseSize;
                    base1Y = ry + rh;
                    base2X = closestX + tailBaseSize;
                    base2Y = ry + rh;
                } else if (activeEdge === "left") {
                    const closestY = getBubbleTailCenter(ty, ry, ry + rh, tailBaseSize, radius);
                    base1X = rx;
                    base1Y = closestY - tailBaseSize;
                    base2X = rx;
                    base2Y = closestY + tailBaseSize;
                } else if (activeEdge === "right") {
                    const closestY = getBubbleTailCenter(ty, ry, ry + rh, tailBaseSize, radius);
                    base1X = rx + rw;
                    base1Y = closestY - tailBaseSize;
                    base2X = rx + rw;
                    base2Y = closestY + tailBaseSize;
                }

                let cornerTail = "";
                if ((activeEdge === "top" && base1X < rx + radius) || (activeEdge === "left" && base1Y < ry + radius)) {
                    cornerTail = "topLeft";
                } else if ((activeEdge === "top" && base2X > rx + rw - radius) || (activeEdge === "right" && base1Y < ry + radius)) {
                    cornerTail = "topRight";
                } else if ((activeEdge === "bottom" && base1X < rx + radius) || (activeEdge === "left" && base2Y > ry + rh - radius)) {
                    cornerTail = "bottomLeft";
                } else if ((activeEdge === "bottom" && base2X > rx + rw - radius) || (activeEdge === "right" && base2Y > ry + rh - radius)) {
                    cornerTail = "bottomRight";
                }
                const cornerTailInset = Math.max(tailBaseSize, radius * 0.65);

                ctx.beginPath();
                if (cornerTail === "topLeft") {
                    ctx.moveTo(rx, ry + cornerTailInset);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx + cornerTailInset, ry);
                } else {
                    ctx.moveTo(rx + radius, ry);
                }

                // Top edge
                if (cornerTail === "topRight") {
                    ctx.lineTo(rx + rw - cornerTailInset, ry);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx + rw, ry + cornerTailInset);
                } else if (activeEdge === "top" && cornerTail !== "topLeft") {
                    ctx.lineTo(base1X, ry);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(base2X, ry);
                }
                if (cornerTail !== "topRight") {
                    ctx.lineTo(rx + rw - radius, ry);
                    ctx.quadraticCurveTo(rx + rw, ry, rx + rw, ry + radius);
                }

                // Right edge
                if (activeEdge === "right" && cornerTail !== "topRight" && cornerTail !== "bottomRight") {
                    ctx.lineTo(rx + rw, base1Y);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx + rw, base2Y);
                }
                if (cornerTail === "bottomRight") {
                    ctx.lineTo(rx + rw, ry + rh - cornerTailInset);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx + rw - cornerTailInset, ry + rh);
                } else {
                    ctx.lineTo(rx + rw, ry + rh - radius);
                    ctx.quadraticCurveTo(rx + rw, ry + rh, rx + rw - radius, ry + rh);
                }

                // Bottom edge
                if (cornerTail === "bottomLeft") {
                    ctx.lineTo(rx + cornerTailInset, ry + rh);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx, ry + rh - cornerTailInset);
                } else if (activeEdge === "bottom") {
                    if (cornerTail !== "bottomRight") {
                        ctx.lineTo(base2X, ry + rh);
                        ctx.lineTo(tx, ty);
                        ctx.lineTo(base1X, ry + rh);
                    }
                }
                if (cornerTail !== "bottomLeft") {
                    ctx.lineTo(rx + radius, ry + rh);
                    ctx.quadraticCurveTo(rx, ry + rh, rx, ry + rh - radius);
                }

                // Left edge
                if (activeEdge === "left" && cornerTail !== "bottomLeft" && cornerTail !== "topLeft") {
                    ctx.lineTo(rx, base2Y);
                    ctx.lineTo(tx, ty);
                    ctx.lineTo(rx, base1Y);
                }
                if (cornerTail !== "topLeft") {
                    ctx.lineTo(rx, ry + radius);
                    ctx.quadraticCurveTo(rx, ry, rx + radius, ry);
                } else {
                    ctx.lineTo(rx, ry + cornerTailInset);
                }
                ctx.closePath();

                ctx.fill();

                // Draw border for bubble
                ctx.shadowColor = "transparent";
                ctx.strokeStyle = stroke.color;
                ctx.lineWidth = Math.max(1.5, Math.round(stroke.width * 0.05));
                ctx.stroke();
            } else {
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
            }
            ctx.restore();

            ctx.fillStyle = stroke.color;
        }

        if (!config.skipText) {
            for (let li = 0; li < lines.length; li++) {
                ctx.fillText(lines[li], pt.x, pt.y + li * lineHeight + stroke.width / 2);
            }
        }

        if (stroke.isUnderline && !config.skipText) {
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
        ctx.restore();

    } else if (stroke.tool === "image") {
        if (stroke.points && stroke.points.length >= 2) {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = Helpers.getRectBounds(p0, p1);
            const rx = bounds.x1;
            const ry = bounds.y1;
            const rw = bounds.x2 - bounds.x1;
            const rh = bounds.y2 - bounds.y1;

            if (rw > 0 && rh > 0 && stroke.imageObj) {
                ctx.save();
                if (stroke.opacity !== undefined && stroke.opacity !== 1.0) {
                    ctx.globalAlpha = stroke.opacity;
                }
                ctx.drawImage(stroke.imageObj, rx, ry, rw, rh);
                ctx.restore();
            }
        }
    }
}

/**
 * Draws selection outlines and edit handles for a selected stroke in select mode.
 * Shape resize handles and endpoint/control-point handles are square.
 * @param {object} ctx - The Canvas 2D context.
 * @param {object} stroke - The selected stroke data object.
 * @param {object} Theme - The Theme object.
 * @param {object} Qt - The Qt object for color utilities.
 * @param {object} Helpers - The Helpers module for utility functions.
 */
function drawSelectionHandles(ctx, stroke, Theme, Qt, Helpers) {
    if (!stroke || !stroke.points || stroke.points.length === 0) return;

    const hs = Constants.selectionHandleSize;
    const hh = hs / 2;

    if (stroke.tool === "ellipse") {
        if (stroke.points.length < 2) return;
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const bounds = Helpers.getRectBounds(p0, p1);
        const x1 = bounds.x1;
        const y1 = bounds.y1;
        const rw = bounds.x2 - bounds.x1;
        const rh = bounds.y2 - bounds.y1;
        const x2 = x1 + rw;
        const y2 = y1 + rh;
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        if (rw > 0 && rh > 0) {
            ctx.save();
            setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
            ctx.save();
            ctx.beginPath();
            ctx.translate(x1 + rw / 2, y1 + rh / 2);
            ctx.scale(rw / 2, rh / 2);
            ctx.arc(0, 0, 1, 0, 2 * Math.PI);
            ctx.restore();
            ctx.stroke();
            ctx.restore();
        }

        drawHandlePoints(ctx, [
            {x: x1, y: y1}, {x: x2, y: y1}, {x: x1, y: y2}, {x: x2, y: y2},
            {x: cx, y: y1}, {x: cx, y: y2}, {x: x1, y: cy}, {x: x2, y: cy}
        ], hh, hs, Theme);
        return;
    }

    if (stroke.tool === "rect" || stroke.tool === "redact" ||
        stroke.tool === "pixelate" || stroke.tool === "spotlight" || stroke.tool === "image") {
        if (stroke.points.length < 2) return;
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const bounds = Helpers.getRectBounds(p0, p1);
        const x1 = bounds.x1;
        const y1 = bounds.y1;
        const x2 = bounds.x2;
        const y2 = bounds.y2;
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        if (stroke.tool === "spotlight" || stroke.tool === "pixelate") {
            drawHighContrastDashedRect(ctx, x1, y1, x2 - x1, y2 - y1);
        } else {
            ctx.save();
            setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
            drawStableDashedRect(ctx, x1, y1, x2 - x1, y2 - y1);
            ctx.restore();
        }

        drawHandlePoints(ctx, [
            {x: x1, y: y1}, {x: x2, y: y1}, {x: x1, y: y2}, {x: x2, y: y2},
            {x: cx, y: y1}, {x: cx, y: y2}, {x: x1, y: cy}, {x: x2, y: cy}
        ], hh, hs, Theme);
        return;
    }

    if (stroke.tool === "line" || stroke.tool === "arrow" || stroke.tool === "highlighter") {
        if (stroke.points.length < 2) return;
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];

        // Draw dashed selection line along the stroke path (except highlighter to keep highlighted text readable)
        if (stroke.tool !== "highlighter") {
            ctx.save();
            setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(p1.x, p1.y);
            ctx.stroke();
            ctx.restore();
        }

        drawHandlePoints(ctx, [p0, p1], hh, hs, Theme);
        return;
    }

    if (stroke.tool === "stamp") {
        const hasLeader = stroke.hasLeaderLine && stroke.points.length >= 2;
        const stampPt = hasLeader ? stroke.points[1] : stroke.points[0];
        const radius = stroke.width * Constants.stampRadiusMultiplier;
        const tailBaseHalfWidth = Math.max(4, Math.min(radius * 0.28, stroke.width * 1.15));

        ctx.save();
        setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
        let circleGapAngle = null;
        let circleGapHalfAngle = 0;
        if (hasLeader) {
        const anchorPt = stroke.points[0];
            const geometry = stampTailGeometry(stampPt, anchorPt, radius, tailBaseHalfWidth);
            if (geometry) {
                circleGapAngle = Math.atan2(geometry.uy, geometry.ux);
                circleGapHalfAngle = Math.asin(Math.min(0.92, (tailBaseHalfWidth + 2) / Math.max(1, radius)));
                ctx.beginPath();
                ctx.moveTo(geometry.base1.x, geometry.base1.y);
                ctx.lineTo(anchorPt.x, anchorPt.y);
                ctx.lineTo(geometry.base2.x, geometry.base2.y);
                ctx.stroke();
            }
        }
        ctx.beginPath();
        if (circleGapAngle !== null) {
            ctx.arc(stampPt.x, stampPt.y, radius,
                    circleGapAngle + circleGapHalfAngle,
                    circleGapAngle - circleGapHalfAngle + 2 * Math.PI);
        } else {
            ctx.arc(stampPt.x, stampPt.y, radius, 0, 2 * Math.PI);
        }
        ctx.stroke();
        ctx.restore();

        if (hasLeader) {
            const anchorPt = stroke.points[0];
            const stampHandlePt = {
                x: stampPt.x - radius,
                y: stampPt.y - radius
            };
            drawHandlePoints(ctx, [anchorPt, stampHandlePt], hh, hs, Theme);
        }

        return;
    }

    if (stroke.tool === "text") {
        const bounds = measureTextLayout(ctx, stroke, Theme);
        if (!bounds) return;
        const frame = Helpers.getTextTransformFrame(stroke, bounds);
        const rotationPoint = {
            x: (bounds.minX + bounds.maxX) / 2,
            y: bounds.minY - 24
        };
        ctx.save();
        ctx.translate(frame.center.x, frame.center.y);
        ctx.rotate(frame.angle);
        ctx.translate(-frame.center.x, -frame.center.y);

        if (stroke.isSpeechBubble && stroke.points.length >= 2) {
            const p0 = stroke.points[0];
            const p1 = stroke.points[1];
            ctx.save();
            ctx.strokeStyle = Theme.primary;
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);
            ctx.beginPath();
            ctx.moveTo(p0.x, p0.y);
            ctx.lineTo(p1.x, p1.y);
            ctx.stroke();
            ctx.restore();
            drawHandlePoints(ctx, [p0, p1, rotationPoint], hh, hs, Theme);
            ctx.restore();
            return;
        }

        const sp = 6;
        drawHighContrastDashedRect(ctx, bounds.minX - sp, bounds.minY - sp,
                                   bounds.maxX - bounds.minX + sp * 2,
                                   bounds.maxY - bounds.minY + sp * 2);
        drawHandlePoints(ctx, [rotationPoint], hh, hs, Theme);
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
        const bounds = Helpers.getRectBounds(p0, p1);
        const x1 = bounds.x1;
        const y1 = bounds.y1;
        const x2 = bounds.x2;
        const y2 = bounds.y2;
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;
        const sw = x2 - x1;
        const sh = y2 - y1;
        if (sw <= 0 || sh <= 0) return;

        if (stroke.calloutShape === "ellipse") {
            ctx.save();
            setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
            ctx.beginPath();
            drawEllipsePath(ctx, cx, cy, sw / 2, sh / 2);
            ctx.stroke();
            ctx.restore();
        } else {
            ctx.save();
            setDashedSelectionStyle(ctx, stroke, Helpers, Qt);
            drawStableDashedRect(ctx, x1, y1, sw, sh);
            ctx.restore();
        }

        drawHandlePoints(ctx, [
            {x: x1, y: y1}, {x: x2, y: y1},
            {x: x1, y: y2}, {x: x2, y: y2},
            {x: cx, y: y1}, {x: cx, y: y2},
            {x: x1, y: cy}, {x: x2, y: cy}
        ], hh, hs, Theme);
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
            const refW = options.canvasWidth || Constants.fallbackCanvasWidth;
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
        
        const watermarkFont = (typeof Theme !== "undefined" && Theme.fontFamily) ? Theme.fontFamily : "sans-serif";
        ctx.font = `bold ${fontSize}px ${watermarkFont}`;
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
