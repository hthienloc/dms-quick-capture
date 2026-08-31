.pragma library
.import "Constants.js" as Constants

/**
 * Helpers.js
 * Pure utility library for Quick Capture. No QML context — all state is passed as arguments.
 *
 * Sections:
 *   1. Color utilities     — hexToRgb, getLuminance, getContrastingColor, formatHexColor, colorEquals, toHex6
 *   2. UI / formatting     — formatCounter, shortcutToken, formatWatermarkText, findByKey
 *   3. Geometry            — constrainSquarePoint, distance, clamp, isInsideCropRect, smoothStrokePoints
 *   4. Color analysis      — extractDominantColors, getBoundaryColorOrGradient
 *   5. Stroke geometry     — getStrokeBBox, findStrokeAt, getStrokeHandleAt
 *   6. Stroke data         — copyStrokeProperties
 */

// ─── 1. Color utilities ────────────────────────────────────────────────────────

/**
 * Converts a hex color string to an RGB object { r, g, b } with values 0-1.
 * @param {string} hex - The hex color string.
 * @param {object} Qt - The Qt object.
 * @returns {object} { r, g, b }
 */
function hexToRgb(hex, Qt) {
    if (!hex) return { r: 0.2, g: 0.5, b: 1 };
    const c = Qt.color(hex);
    return { r: c.r, g: c.g, b: c.b };
}

/**
 * Calculates luminance from an RGB object.
 * @param {object} rgb - { r, g, b }
 * @returns {number} luminance value between 0 and 1.
 */
function getLuminance(rgb) {
    return 0.299 * (rgb.r || 0) + 0.587 * (rgb.g || 0) + 0.114 * (rgb.b || 0);
}

/**
 * Returns black or white text for an RGB color based on luminance.
 * @param {object} rgb - RGB color object with channels between 0 and 1.
 * @returns {string} "#000000" or "#ffffff".
 */
function getContrastingColorFromRgb(rgb) {
    return getLuminance(rgb) > 0.5 ? "#000000" : "#ffffff";
}

/**
 * Returns a contrasting text color (black or white) based on hex color luminance.
 * @param {string} hex - The hex color string.
 * @param {object} Qt - The Qt object.
 * @returns {string} "#000000" or "#ffffff"
 */
function getContrastingColor(hex, Qt) {
    const rgb = hexToRgb(hex, Qt);
    return getContrastingColorFromRgb(rgb);
}

/**
 * Converts a normalized RGB color object to a six-digit hex string.
 * @param {object} rgb - RGB color object with channels between 0 and 1.
 * @param {boolean} uppercase - Whether to uppercase the hex digits.
 * @returns {string} A six-digit hex color string.
 */
function rgbToHex(rgb, uppercase) {
    const r = Math.round((rgb.r || 0) * 255).toString(16).padStart(2, "0");
    const g = Math.round((rgb.g || 0) * 255).toString(16).padStart(2, "0");
    const b = Math.round((rgb.b || 0) * 255).toString(16).padStart(2, "0");
    const hex = "#" + r + g + b;
    return uppercase ? hex.toUpperCase() : hex.toLowerCase();
}

/**
 * Formats a normalized RGB color for display.
 * @param {object} rgb - RGB color object with channels between 0 and 1.
 * @returns {string} Text in the form "RGB: r,g,b".
 */
function formatRgbString(rgb) {
    const r = Math.round((rgb.r || 0) * 255);
    const g = Math.round((rgb.g || 0) * 255);
    const b = Math.round((rgb.b || 0) * 255);
    return "RGB: " + r + "," + g + "," + b;
}

// ─── 2. UI / formatting ───────────────────────────────────────────────────────

/**
 * Formats a number according to the specified format.
 * @param {number} n - The number to format.
 * @param {string} format - The format ("numeric", "alpha", "roman").
 * @returns {string} Formatted string.
 */
function formatCounter(n, format) {
    if (format === "alpha") {
        let res = "";
        let num = n;
        while (num > 0) {
            let mod = (num - 1) % 26;
            res = String.fromCharCode(65 + mod) + res;
            num = Math.floor((num - mod) / 26);
        }
        return res || "A";
    }
    if (format === "roman") {
        const roman = [
            { v: 1000, s: "M" }, { v: 900, s: "CM" }, { v: 500, s: "D" }, { v: 400, s: "CD" },
            { v: 100, s: "C" }, { v: 90, s: "XC" }, { v: 50, s: "L" }, { v: 40, s: "XL" },
            { v: 10, s: "X" }, { v: 9, s: "IX" }, { v: 5, s: "V" }, { v: 4, s: "IV" },
            { v: 1, s: "I" }
        ];
        let res = "";
        let num = n;
        for (let i = 0; i < roman.length; i++) {
            while (num >= roman[i].v) {
                res += roman[i].s;
                num -= roman[i].v;
            }
        }
        return res || "I";
    }
    return String(n);
}

/**
 * Maps a Qt.Key to its string representation for shortcut tokens.
 * @param {number} key - The Qt.Key value.
 * @param {object} Qt - The Qt object.
 * @returns {string} The token string.
 */
function shortcutToken(key, Qt) {
    switch (key) {
    case Qt.Key_0: return "0";
    case Qt.Key_1: return "1";
    case Qt.Key_2: return "2";
    case Qt.Key_3: return "3";
    case Qt.Key_4: return "4";
    case Qt.Key_5: return "5";
    case Qt.Key_6: return "6";
    case Qt.Key_7: return "7";
    case Qt.Key_8: return "8";
    case Qt.Key_9: return "9";
    case Qt.Key_A: return "A";
    case Qt.Key_B: return "B";
    case Qt.Key_C: return "C";
    case Qt.Key_D: return "D";
    case Qt.Key_E: return "E";
    case Qt.Key_F: return "F";
    case Qt.Key_G: return "G";
    case Qt.Key_H: return "H";
    case Qt.Key_I: return "I";
    case Qt.Key_J: return "J";
    case Qt.Key_K: return "K";
    case Qt.Key_L: return "L";
    case Qt.Key_M: return "M";
    case Qt.Key_N: return "N";
    case Qt.Key_O: return "O";
    case Qt.Key_P: return "P";
    case Qt.Key_Q: return "Q";
    case Qt.Key_R: return "R";
    case Qt.Key_S: return "S";
    case Qt.Key_T: return "T";
    case Qt.Key_U: return "U";
    case Qt.Key_V: return "V";
    case Qt.Key_W: return "W";
    case Qt.Key_X: return "X";
    case Qt.Key_Y: return "Y";
    case Qt.Key_Z: return "Z";
    default: return "";
    }
}

// ─── 3. Geometry ──────────────────────────────────────────────────────────────

/**
 * Constrains a point to form a square relative to a start point.
 * @param {object} start - Start point {x, y}.
 * @param {object} point - End point {x, y}.
 * @param {object} Qt - The Qt object.
 * @returns {object} Constrained point.
 */
function constrainSquarePoint(start, point, Qt) {
    if (!start || !point) return point || Qt.point(0, 0);
    const dx = point.x - start.x;
    const dy = point.y - start.y;
    const size = Math.max(Math.abs(dx), Math.abs(dy));
    const sx = dx < 0 ? -1 : 1;
    const sy = dy < 0 ? -1 : 1;
    return Qt.point(start.x + sx * size, start.y + sy * size);
}

/**
 * Calculates normalized source and automatically placed destination rectangles for a callout.
 * @param {object} p0 - First source point {x, y}.
 * @param {object} p1 - Last source point {x, y}.
 * @param {number} zoom - Destination scale relative to the source rectangle.
 * @param {number} visibleX - Visible area left edge.
 * @param {number} visibleY - Visible area top edge.
 * @param {number} visibleWidth - Visible area width.
 * @param {number} visibleHeight - Visible area height.
 * @param {number} margin - Gap from the source and visible area edges.
 * @returns {object} Source and destination rectangle endpoints.
 */
function getCalloutPlacement(p0, p1, zoom, visibleX, visibleY, visibleWidth, visibleHeight, margin) {
    const sourceStart = { x: Math.min(p0.x, p1.x), y: Math.min(p0.y, p1.y) };
    const sourceEnd = { x: Math.max(p0.x, p1.x), y: Math.max(p0.y, p1.y) };
    const sourceWidth = sourceEnd.x - sourceStart.x;
    const sourceHeight = sourceEnd.y - sourceStart.y;
    const destinationWidth = sourceWidth * zoom;
    const destinationHeight = sourceHeight * zoom;
    const sourceCenterX = (sourceStart.x + sourceEnd.x) / 2;
    const sourceCenterY = (sourceStart.y + sourceEnd.y) / 2;
    const visibleCenterX = visibleX + visibleWidth / 2;
    const visibleCenterY = visibleY + visibleHeight / 2;
    const directionX = visibleCenterX - sourceCenterX >= 0 ? 1 : -1;
    const directionY = visibleCenterY - sourceCenterY >= 0 ? 1 : -1;

    let destinationX = directionX > 0
        ? sourceEnd.x + margin
        : sourceStart.x - destinationWidth - margin;
    let destinationY = directionY > 0
        ? sourceEnd.y + margin
        : sourceStart.y - destinationHeight - margin;
    const rightBound = visibleX + visibleWidth - destinationWidth - margin;
    const bottomBound = visibleY + visibleHeight - destinationHeight - margin;
    destinationX = Math.max(visibleX + margin, Math.min(destinationX, rightBound));
    destinationY = Math.max(visibleY + margin, Math.min(destinationY, bottomBound));

    return {
        sourceStart: sourceStart,
        sourceEnd: sourceEnd,
        destinationStart: { x: destinationX, y: destinationY },
        destinationEnd: { x: destinationX + destinationWidth, y: destinationY + destinationHeight }
    };
}

/**
 * Checks if a point (mx, my) is inside the crop rectangle.
 * @param {number} mx
 * @param {number} my
 * @param {boolean} hasSelection
 * @param {object} cropRect
 * @returns {boolean}
 */
function isInsideCropRect(mx, my, hasSelection, cropRect) {
    if (!hasSelection) return false;
    return mx >= cropRect.x && mx <= (cropRect.x + cropRect.width) &&
           my >= cropRect.y && my <= (cropRect.y + cropRect.height);
}


/**
 * Finds an item in a list by its 'key' property.

 * @param {Array} items - The list of items.
 * @param {string} key - The key to find.
 * @returns {object|null}
 */
function findByKey(items, key) {
    if (!items) return null;
    for (let i = 0; i < items.length; i++) {
        if (items[i].key === key) return items[i];
    }
    return null;
}

/**
 * Formats watermark text patterns.
 * @param {string} pattern - The pattern string.
 * @param {object} Quickshell - The Quickshell object.
 * @returns {string} Formatted string.
 */
function formatWatermarkText(pattern, Quickshell) {
    if (!pattern) return "";
    const username = Quickshell.env("USER") || Quickshell.env("USERNAME") || "User";
    const now = new Date();
    const pad = (num, size) => {
        let s = num + "";
        while (s.length < (size || 2)) s = "0" + s;
        return s;
    };

    const yyyy = now.getFullYear();
    const yy = pad(yyyy % 100);
    const MM = pad(now.getMonth() + 1);
    const dd = pad(now.getDate());
    const HH = pad(now.getHours());
    const mm = pad(now.getMinutes());
    const ss = pad(now.getSeconds());

    return pattern
        .replace(/\\n/g, "\n")
        .replace(/\{nl\}/gi, "\n")
        .replace(/\{newline\}/gi, "\n")
        .replace(/\{user\}/gi, username)
        .replace(/\{username\}/gi, username)
        .replace(/%Y/g, yyyy)
        .replace(/%y/g, yy)
        .replace(/%m/g, MM)
        .replace(/%d/g, dd)
        .replace(/%H/g, HH)
        .replace(/%M/g, mm)
        .replace(/%S/g, ss)
        .replace(/\{yyyy\}/gi, yyyy)
        .replace(/\{MM\}/g, MM)
        .replace(/\{dd\}/gi, dd)
        .replace(/\{HH\}/gi, HH)
        .replace(/\{mm\}/g, mm)
        .replace(/\{ss\}/gi, ss);
}

// ─── 4. Color analysis ────────────────────────────────────────────────────────

/**
 * Chooses a muted, image-related backdrop using edge colors and simple adjustments.
 * @param {object} imgData - Canvas image data sampled from the image.
 * @param {object} Qt - The Qt object.
 * @returns {object} { start, end } QML color values.
 */
function extractDominantColors(imgData, Qt) {
    const fallback = {
        start: Qt.rgba(0.2, 0.33, 0.47, 1),
        end: Qt.rgba(0.07, 0.13, 0.2, 1)
    };
    if (!imgData || !imgData.data || !imgData.width || !imgData.height) return fallback;

    const sampleWidth = imgData.width;
    const sampleHeight = imgData.height;
    const edgePixels = [];
    for (let y = 0; y < sampleHeight; y++) {
        for (let x = 0; x < sampleWidth; x++) {
            const index = (y * sampleWidth + x) * 4;
            const pixel = {
                r: imgData.data[index] / 255,
                g: imgData.data[index + 1] / 255,
                b: imgData.data[index + 2] / 255
            };
            if (x === 0 || x === sampleWidth - 1 || y === 0 || y === sampleHeight - 1) edgePixels.push(pixel);
        }
    }

    let edgeColor = { r: 0, g: 0, b: 0 };
    for (let i = 0; i < edgePixels.length; i++) {
        edgeColor.r += edgePixels[i].r;
        edgeColor.g += edgePixels[i].g;
        edgeColor.b += edgePixels[i].b;
    }
    edgeColor.r /= edgePixels.length;
    edgeColor.g /= edgePixels.length;
    edgeColor.b /= edgePixels.length;

    const edgeLuminance = edgePixels.reduce((sum, pixel) => sum + getLuminance(pixel), 0) / edgePixels.length;
    const maxChannel = Math.max(edgeColor.r, edgeColor.g, edgeColor.b);
    const minChannel = Math.min(edgeColor.r, edgeColor.g, edgeColor.b);
    const saturation = maxChannel - minChannel;
    const muteAmount = Math.max(0, Math.min(0.72, (saturation - 0.16) * 1.8));
    const gray = getLuminance(edgeColor);
    const muted = {
        r: edgeColor.r * (1 - muteAmount) + gray * muteAmount,
        g: edgeColor.g * (1 - muteAmount) + gray * muteAmount,
        b: edgeColor.b * (1 - muteAmount) + gray * muteAmount
    };

    function adjustLightness(rgb, target) {
        const luminance = getLuminance(rgb);
        if (luminance < target) {
            const amount = (target - luminance) / Math.max(0.01, 1 - luminance);
            return {
                r: rgb.r + (1 - rgb.r) * amount,
                g: rgb.g + (1 - rgb.g) * amount,
                b: rgb.b + (1 - rgb.b) * amount
            };
        }
        const scale = target / Math.max(0.01, luminance);
        return { r: rgb.r * scale, g: rgb.g * scale, b: rgb.b * scale };
    }

    const imageIsLight = edgeLuminance > 0.5;
    const startRgb = adjustLightness(muted, imageIsLight ? 0.24 : 0.70);
    const endRgb = adjustLightness({
        r: muted.r * 0.9,
        g: muted.g * 0.9,
        b: muted.b * 0.9
    }, imageIsLight ? 0.14 : 0.80);

    return {
        start: Qt.rgba(startRgb.r, startRgb.g, startRgb.b, 1),
        end: Qt.rgba(endRgb.r, endRgb.g, endRgb.b, 1)
    };
}

// ─── 5. Stroke geometry & hit-testing ────────────────────────────────────────

/**
 * Returns normalized rectangular bounds for two points.
 * @param {object} p0 - First point {x, y}.
 * @param {object} p1 - Second point {x, y}.
 * @returns {object} { x1, y1, x2, y2 } with minimum and maximum coordinates.
 */
function getRectBounds(p0, p1) {
    return {
        x1: Math.min(p0.x, p1.x),
        y1: Math.min(p0.y, p1.y),
        x2: Math.max(p0.x, p1.x),
        y2: Math.max(p0.y, p1.y)
    };
}

/**
 * Checks whether a point is within a squared distance of a line segment.
 * @param {number} mx - Point X coordinate.
 * @param {number} my - Point Y coordinate.
 * @param {object} p0 - Segment start point {x, y}.
 * @param {object} p1 - Segment end point {x, y}.
 * @param {number} maxDistanceSq - Maximum allowed squared distance.
 * @returns {boolean} Whether the point is near the segment.
 */
function isPointNearSegment(mx, my, p0, p1, maxDistanceSq) {
    const dx = p1.x - p0.x;
    const dy = p1.y - p0.y;
    const lenSq = dx * dx + dy * dy;
    if (lenSq === 0) {
        const sx = mx - p0.x;
        const sy = my - p0.y;
        return sx * sx + sy * sy < maxDistanceSq;
    }
    let t = ((mx - p0.x) * dx + (my - p0.y) * dy) / lenSq;
    t = Math.max(0, Math.min(1, t));
    const px = p0.x + t * dx;
    const py = p0.y + t * dy;
    const sx = mx - px;
    const sy = my - py;
    return sx * sx + sy * sy < maxDistanceSq;
}

function getTextBBox(stroke, measureTextBoundsFn) {
    const txtPt = (stroke.isSpeechBubble && stroke.points.length >= 2) ? stroke.points[1] : stroke.points[0];
    const measured = measureTextBoundsFn ? measureTextBoundsFn(stroke) : null;
    return measured || { minX: txtPt.x, minY: txtPt.y, maxX: txtPt.x, maxY: txtPt.y };
}

/** Rotates a point around a center by an angle in radians. */
function rotatePoint(point, center, angle) {
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const dx = point.x - center.x;
    const dy = point.y - center.y;
    return {
        x: center.x + dx * cos - dy * sin,
        y: center.y + dx * sin + dy * cos
    };
}

/** Returns the shared local frame and rotated bounds for a text stroke. */
function getTextTransformFrame(stroke, textBounds) {
    if (!textBounds) {
        const point = stroke && stroke.points && stroke.points.length > 0
            ? stroke.points[stroke.isSpeechBubble && stroke.points.length >= 2 ? 1 : 0]
            : { x: 0, y: 0 };
        textBounds = { minX: point.x, minY: point.y, maxX: point.x, maxY: point.y };
    }
    const bounds = {
        minX: textBounds.minX,
        minY: textBounds.minY,
        maxX: textBounds.maxX,
        maxY: textBounds.maxY
    };
    if (stroke.isSpeechBubble && stroke.points.length >= 2) {
        const target = stroke.points[0];
        bounds.minX = Math.min(bounds.minX, target.x);
        bounds.minY = Math.min(bounds.minY, target.y);
        bounds.maxX = Math.max(bounds.maxX, target.x);
        bounds.maxY = Math.max(bounds.maxY, target.y);
    }

    const center = {
        x: (textBounds.minX + textBounds.maxX) / 2,
        y: (textBounds.minY + textBounds.maxY) / 2
    };
    const angle = ((Number(stroke.rotation) || 0) * Math.PI) / 180;
    const corners = [
        { x: bounds.minX, y: bounds.minY },
        { x: bounds.maxX, y: bounds.minY },
        { x: bounds.minX, y: bounds.maxY },
        { x: bounds.maxX, y: bounds.maxY }
    ].map(point => rotatePoint(point, center, angle));

    return {
        center: center,
        angle: angle,
        bounds: {
            minX: Math.min(...corners.map(point => point.x)),
            minY: Math.min(...corners.map(point => point.y)),
            maxX: Math.max(...corners.map(point => point.x)),
            maxY: Math.max(...corners.map(point => point.y))
        }
    };
}

/** Maps a screen point back into a text stroke's unrotated coordinate space. */
function inverseRotatePoint(point, center, angle) {
    return rotatePoint(point, center, -angle);
}

/**
 * Calculates the bounding box of a stroke.
 * @param {object} stroke - The stroke object.
 * @param {function} measureTextBoundsFn - Exact Canvas text bounds function.
 * @returns {object} { minX, minY, maxX, maxY }
 */
function getStrokeBBox(stroke, measureTextBoundsFn) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    const pts = stroke.points;
    const len = pts.length;
    if (len === 0) return { minX: 0, minY: 0, maxX: 0, maxY: 0 };

    if (stroke.tool === "text") {
        const textBounds = getTextBBox(stroke, measureTextBoundsFn);
        const frame = getTextTransformFrame(stroke, textBounds);
        minX = frame.bounds.minX;
        minY = frame.bounds.minY;
        maxX = frame.bounds.maxX;
        maxY = frame.bounds.maxY;
    } else if (stroke.tool === "stamp") {
        const radius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
        if (stroke.hasLeaderLine && len >= 2) {
            const bounds = getRectBounds(pts[0], pts[1]);
            minX = bounds.x1 - radius;
            maxX = bounds.x2 + radius;
            minY = bounds.y1 - radius;
            maxY = bounds.y2 + radius;
        } else {
            const p0 = pts[0];
            minX = p0.x - radius;
            maxX = p0.x + radius;
            minY = p0.y - radius;
            maxY = p0.y + radius;
        }
    } else if (stroke.tool === "image") {
        const p0 = pts[0];
        const p1 = pts[len - 1];
        const bounds = getRectBounds(p0, p1);
        minX = bounds.x1;
        minY = bounds.y1;
        maxX = bounds.x2;
        maxY = bounds.y2;
    } else {
        for (let i = 0; i < len; i++) {
            const p = pts[i];
            if (p.x < minX) minX = p.x;
            if (p.y < minY) minY = p.y;
            if (p.x > maxX) maxX = p.x;
            if (p.y > maxY) maxY = p.y;
        }
    }
    return { minX: minX, minY: minY, maxX: maxX, maxY: maxY };
}

/**
 * Finds the index of the stroke under coordinate (mx, my).
 * @param {number} mx - X coordinate.
 * @param {number} my - Y coordinate.
 * @param {array} strokes - List of strokes.
 * @param {function} measureTextBoundsFn - Exact Canvas text bounds function.
 * @returns {number} Stroke index or -1.
 */
function findStrokeAt(mx, my, strokes, measureTextBoundsFn) {
    // Background effects cover large areas. Search regular annotations first,
    // then pixelate, and use Spotlight as the lowest-priority fallback.
    const searchOrder = [];
    for (let i = strokes.length - 1; i >= 0; i--) {
        if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate") searchOrder.push(i);
    }
    for (let i = strokes.length - 1; i >= 0; i--) {
        if (strokes[i].tool === "pixelate") searchOrder.push(i);
    }
    for (let i = strokes.length - 1; i >= 0; i--) {
        if (strokes[i].tool === "spotlight") searchOrder.push(i);
    }

    for (let orderIdx = 0; orderIdx < searchOrder.length; orderIdx++) {
        const i = searchOrder[orderIdx];
        const stroke = strokes[i];
        if (stroke.points.length === 0) continue;

        const threshold = Constants.selectionThresholdBase + stroke.width;
        const thresholdSq = threshold * threshold;

        // Fast bounding box reject check
        const bbox = getStrokeBBox(stroke, measureTextBoundsFn);
        const pad = threshold + 2;
        if (mx < bbox.minX - pad || mx > bbox.maxX + pad ||
            my < bbox.minY - pad || my > bbox.maxY + pad) {
            continue;
        }

        if (stroke.tool === "pen" || stroke.tool === "highlighter") {
            for (let j = 0; j < stroke.points.length - 1; j++) {
                const A = stroke.points[j];
                const B = stroke.points[j+1];
                if (isPointNearSegment(mx, my, A, B, thresholdSq)) return i;
            }
        } else if (stroke.tool === "rect") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = getRectBounds(p0, p1);
            const x1 = bounds.x1;
            const x2 = bounds.x2;
            const y1 = bounds.y1;
            const y2 = bounds.y2;
            if (mx >= x1 - threshold && mx <= x2 + threshold && my >= y1 - threshold && my <= y2 + threshold) {
                const dx = Math.min(Math.abs(mx - x1), Math.abs(mx - x2));
                const dy = Math.min(Math.abs(my - y1), Math.abs(my - y2));
                if (dx <= threshold || dy <= threshold) return i;
            }
        } else if (stroke.tool === "redact") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = getRectBounds(p0, p1);
            const x1 = bounds.x1;
            const x2 = bounds.x2;
            const y1 = bounds.y1;
            const y2 = bounds.y2;
            const shape = stroke.redactShape || "rect";
            if (shape === "ellipse") {
                const rx = Math.max((x2 - x1) / 2, 1);
                const ry = Math.max((y2 - y1) / 2, 1);
                const cx = x1 + rx;
                const cy = y1 + ry;
                const normalized = Math.pow((mx - cx) / rx, 2) + Math.pow((my - cy) / ry, 2);
                if (normalized <= 1.1) return i;
            } else {
                if (mx >= x1 - Constants.rectSelectionPadding && mx <= x2 + Constants.rectSelectionPadding && my >= y1 - Constants.rectSelectionPadding && my <= y2 + Constants.rectSelectionPadding) {
                    return i;
                }
            }
        } else if (stroke.tool === "pixelate" || stroke.tool === "spotlight" || stroke.tool === "image") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = getRectBounds(p0, p1);
            const x1 = bounds.x1;
            const x2 = bounds.x2;
            const y1 = bounds.y1;
            const y2 = bounds.y2;
            if (mx >= x1 - Constants.rectSelectionPadding && mx <= x2 + Constants.rectSelectionPadding && my >= y1 - Constants.rectSelectionPadding && my <= y2 + Constants.rectSelectionPadding) {
                return i;
            }
        } else if (stroke.tool === "ellipse") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = getRectBounds(p0, p1);
            const x1 = bounds.x1;
            const x2 = bounds.x2;
            const y1 = bounds.y1;
            const y2 = bounds.y2;
            const rx = Math.max((x2 - x1) / 2, 1);
            const ry = Math.max((y2 - y1) / 2, 1);
            const cx = x1 + rx;
            const cy = y1 + ry;
            const normalized = Math.pow((mx - cx) / rx, 2) + Math.pow((my - cy) / ry, 2);
            const tolerance = Math.max(0.08, threshold / Math.max(rx, ry));
            if (Math.abs(normalized - 1) <= tolerance) return i;
        } else if (stroke.tool === "arrow" || stroke.tool === "line") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            if (isPointNearSegment(mx, my, p0, p1, thresholdSq)) return i;
        } else if (stroke.tool === "stamp") {
            const radius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
            if (stroke.hasLeaderLine && stroke.points.length >= 2) {
                const p0 = stroke.points[0];
                const p1 = stroke.points[1];

                // Check stamp circle at points[1]
                const distStampSq = (mx - p1.x) * (mx - p1.x) + (my - p1.y) * (my - p1.y);
                if (distStampSq <= radius * radius) return i;

                // Check leader line segment points[0] -> points[1]
                if (isPointNearSegment(mx, my, p0, p1, thresholdSq)) return i;
            } else {
                const p0 = stroke.points[0];
                const distSq = (mx - p0.x) * (mx - p0.x) + (my - p0.y) * (my - p0.y);
                if (distSq <= radius * radius) return i;
            }
        } else if (stroke.tool === "text") {
            const textBounds = getTextBBox(stroke, measureTextBoundsFn);
            const frame = getTextTransformFrame(stroke, textBounds);
            const local = inverseRotatePoint({ x: mx, y: my }, frame.center, frame.angle);
            if (local.x >= textBounds.minX - Constants.ocrSelectionPadding && local.x <= textBounds.maxX + Constants.ocrSelectionPadding &&
                local.y >= textBounds.minY - Constants.ocrSelectionPadding && local.y <= textBounds.maxY + Constants.ocrSelectionPadding) {
                return i;
            }

            if (stroke.isSpeechBubble) {
                const txtPt = stroke.points[1];
                if (stroke.points.length >= 2) {
                    const pTarget = stroke.points[0];
                    const localTarget = inverseRotatePoint(pTarget, frame.center, frame.angle);
                    if (isPointNearSegment(local.x, local.y, txtPt, localTarget, thresholdSq)) return i;
                }
            }
        } else if (stroke.tool === "callout" && stroke.points.length === 4) {
            const srcP0 = stroke.points[0];
            const srcP1 = stroke.points[1];
            const dstP0 = stroke.points[2];
            const dstP1 = stroke.points[3];
            const pad = Constants.calloutSelectionPadding;
            if (stroke.calloutShape === "ellipse") {
                const srcCx = (srcP0.x + srcP1.x) / 2;
                const srcCy = (srcP0.y + srcP1.y) / 2;
                const srcRx = (srcP1.x - srcP0.x) / 2 + pad;
                const srcRy = (srcP1.y - srcP0.y) / 2 + pad;
                let dx = mx - srcCx;
                let dy = my - srcCy;
                if (srcRx > 0 && srcRy > 0 && (dx * dx) / (srcRx * srcRx) + (dy * dy) / (srcRy * srcRy) <= 1) return i;
                const dstCx = (dstP0.x + dstP1.x) / 2;
                const dstCy = (dstP0.y + dstP1.y) / 2;
                const dstRx = (dstP1.x - dstP0.x) / 2 + pad;
                const dstRy = (dstP1.y - dstP0.y) / 2 + pad;
                dx = mx - dstCx;
                dy = my - dstCy;
                if (dstRx > 0 && dstRy > 0 && (dx * dx) / (dstRx * dstRx) + (dy * dy) / (dstRy * dstRy) <= 1) return i;
            } else {
                const srcBounds = getRectBounds(srcP0, srcP1);
                const dstBounds = getRectBounds(dstP0, dstP1);
                if (mx >= srcBounds.x1 - pad && mx <= srcBounds.x2 + pad && my >= srcBounds.y1 - pad && my <= srcBounds.y2 + pad) return i;
                if (mx >= dstBounds.x1 - pad && mx <= dstBounds.x2 + pad && my >= dstBounds.y1 - pad && my <= dstBounds.y2 + pad) return i;
            }
        }
    }
    return -1;
}

/**
 * Checks if a point (mx, my) is hovering over a resize handle of the given stroke.
 * Returns the handle identifier or "none".
 * Shapes: tl, tr, bl, br, tc, bc, lc, rc
 * Lines: start, end; text: rotate, start, end
 * @param {function} measureTextBoundsFn - Optional callback used for text bounds.
 */
function getStrokeHandleAt(mx, my, stroke, measureTextBoundsFn) {
    if (!stroke || !stroke.points || stroke.points.length === 0) return "none";
    const threshold = Constants.selectionHandleSize + 4;
    const thresholdSq = threshold * threshold;

    function isNearSquarePoint(pt) {
        return Math.abs(mx - pt.x) <= threshold && Math.abs(my - pt.y) <= threshold;
    }

    function firstNearHandle(handles) {
        for (let i = 0; i < handles.length; i++) {
            if (isNearSquarePoint(handles[i].point)) return handles[i].name;
        }
        return "none";
    }

    if (stroke.tool === "rect" || stroke.tool === "ellipse" || stroke.tool === "redact" ||
        stroke.tool === "pixelate" || stroke.tool === "spotlight" || stroke.tool === "image") {
        if (stroke.points.length < 2) return "none";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        const bounds = getRectBounds(p0, p1);
        const x1 = bounds.x1;
        const y1 = bounds.y1;
        const x2 = bounds.x2;
        const y2 = bounds.y2;
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        return firstNearHandle([
            { name: "tl", point: { x: x1, y: y1 } },
            { name: "tr", point: { x: x2, y: y1 } },
            { name: "bl", point: { x: x1, y: y2 } },
            { name: "br", point: { x: x2, y: y2 } },
            { name: "tc", point: { x: cx, y: y1 } },
            { name: "bc", point: { x: cx, y: y2 } },
            { name: "lc", point: { x: x1, y: cy } },
            { name: "rc", point: { x: x2, y: cy } }
        ]);
    }

    if (stroke.tool === "line" || stroke.tool === "arrow" || stroke.tool === "highlighter") {
        if (stroke.points.length < 2) return "none";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        if (isNearSquarePoint(p0)) return "start";
        if (isNearSquarePoint(p1)) return "end";
        return "none";
    }

    if (stroke.tool === "stamp") {
        const hasLeader = stroke.hasLeaderLine && stroke.points.length >= 2;
        const stampPt = hasLeader ? stroke.points[1] : stroke.points[0];
        const stampRadius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
        const dx = mx - stampPt.x;
        const dy = my - stampPt.y;
        if (hasLeader) {
            const anchorPt = stroke.points[0];
            const stampHandlePt = {
                x: stampPt.x - stroke.width * Constants.stampRadiusMultiplier,
                y: stampPt.y - stroke.width * Constants.stampRadiusMultiplier
            };
            if (isNearSquarePoint(anchorPt)) return "anchor";
            if (isNearSquarePoint(stampHandlePt)) return "stamp";
            if (dx * dx + dy * dy <= stampRadius * stampRadius) return "stampBody";

            if (isPointNearSegment(mx, my, anchorPt, stampPt, thresholdSq)) return "stampBody";
        } else {
            if (dx * dx + dy * dy <= stampRadius * stampRadius) return "stamp";
        }
        return "none";
    }

    if (stroke.tool === "callout" && stroke.points.length === 4) {
        const p0 = stroke.points[0];
        const p1 = stroke.points[1];
        const bounds = getRectBounds(p0, p1);
        const x1 = bounds.x1;
        const y1 = bounds.y1;
        const x2 = bounds.x2;
        const y2 = bounds.y2;
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        return firstNearHandle([
            { name: "src_tl", point: { x: x1, y: y1 } },
            { name: "src_tr", point: { x: x2, y: y1 } },
            { name: "src_bl", point: { x: x1, y: y2 } },
            { name: "src_br", point: { x: x2, y: y2 } },
            { name: "src_tc", point: { x: cx, y: y1 } },
            { name: "src_bc", point: { x: cx, y: y2 } },
            { name: "src_lc", point: { x: x1, y: cy } },
            { name: "src_rc", point: { x: x2, y: cy } }
        ]);
    }

    if (stroke.tool === "text") {
        const textBounds = getTextBBox(stroke, measureTextBoundsFn);
        const frame = getTextTransformFrame(stroke, textBounds);
        const local = inverseRotatePoint({ x: mx, y: my }, frame.center, frame.angle);
        const rotationPoint = {
            x: (textBounds.minX + textBounds.maxX) / 2,
            y: textBounds.minY - 24
        };
        if (Math.abs(local.x - rotationPoint.x) <= threshold && Math.abs(local.y - rotationPoint.y) <= threshold) {
            return "rotate";
        }
        if (stroke.isSpeechBubble && stroke.points.length >= 2) {
            if (Math.abs(local.x - stroke.points[0].x) <= threshold && Math.abs(local.y - stroke.points[0].y) <= threshold) return "start";
            if (Math.abs(local.x - stroke.points[1].x) <= threshold && Math.abs(local.y - stroke.points[1].y) <= threshold) return "end";
        }
        return "none";
    }

    return "none";
}

/**
 * Smooths a polyline using a multi-pass weighted moving average.
 * Each pass replaces every interior point with:
 *   0.25 * prev + 0.5 * current + 0.25 * next
 * Endpoints are kept fixed. Running multiple passes compounds the effect.
 *
 * @param {Array} points - Array of {x, y} points.
 * @param {number} passes - Number of smoothing passes (recommended: 4-8).
 * @returns {Array} New smoothed array of Qt.point objects.
 */
function smoothStrokePoints(points, passes, Qt) {
    if (!points || points.length < 3) return points;
    let pts = points;
    for (let p = 0; p < passes; p++) {
        const next = [pts[0]]; // keep start fixed
        for (let i = 1; i < pts.length - 1; i++) {
            next.push(Qt.point(
                0.25 * pts[i - 1].x + 0.5 * pts[i].x + 0.25 * pts[i + 1].x,
                0.25 * pts[i - 1].y + 0.5 * pts[i].y + 0.25 * pts[i + 1].y
            ));
        }
        next.push(pts[pts.length - 1]); // keep end fixed
        pts = next;
    }
    return pts;
}

function getBoundaryColorOrGradient(ctx, rx, ry, rw, rh, offscreenSampler, Qt) {
    if (!offscreenSampler) return "transparent";
    const octx = offscreenSampler.getContext("2d");
    const border = 3;
    const sampleX = Math.max(0, Math.min(offscreenSampler.width - 1, rx - border));
    const sampleY = Math.max(0, Math.min(offscreenSampler.height - 1, ry - border));
    const sampleW = Math.max(1, Math.min(offscreenSampler.width - sampleX, rw + border * 2));
    const sampleH = Math.max(1, Math.min(offscreenSampler.height - sampleY, rh + border * 2));
    
    if (sampleW <= 0 || sampleH <= 0) return "transparent";
    
    let imgData;
    try {
        imgData = octx.getImageData(sampleX, sampleY, sampleW, sampleH);
    } catch (e) {
        return "transparent";
    }
    const data = imgData.data;
    
    const counts = {};
    let maxCount = 0;
    let dominantColorKey = null;
    
    for (let y = 0; y < sampleH; y++) {
        for (let x = 0; x < sampleW; x++) {
            const isBorder = (x < border) || (x >= sampleW - border) || (y < border) || (y >= sampleH - border);
            if (isBorder) {
                const idx = (y * sampleW + x) * 4;
                const r = data[idx];
                const g = data[idx + 1];
                const b = data[idx + 2];
                const a = data[idx + 3];
                if (a === 0) continue;
                
                const qr = Math.round(r / 8) * 8;
                const qg = Math.round(g / 8) * 8;
                const qb = Math.round(b / 8) * 8;
                
                const key = (qr << 16) | (qg << 8) | qb;
                counts[key] = (counts[key] || 0) + 1;
                if (counts[key] > maxCount) {
                    maxCount = counts[key];
                    dominantColorKey = key;
                }
            }
        }
    }
    
    if (dominantColorKey === null) return "transparent";
    
    let rSum = 0, gSum = 0, bSum = 0, count = 0;
    for (let y = 0; y < sampleH; y++) {
        for (let x = 0; x < sampleW; x++) {
            const isBorder = (x < border) || (x >= sampleW - border) || (y < border) || (y >= sampleH - border);
            if (isBorder) {
                const idx = (y * sampleW + x) * 4;
                const r = data[idx];
                const g = data[idx + 1];
                const b = data[idx + 2];
                const a = data[idx + 3];
                if (a === 0) continue;
                
                const qr = Math.round(r / 8) * 8;
                const qg = Math.round(g / 8) * 8;
                const qb = Math.round(b / 8) * 8;
                const key = (qr << 16) | (qg << 8) | qb;
                if (key === dominantColorKey) {
                    rSum += r;
                    gSum += g;
                    bSum += b;
                    count++;
                }
            }
        }
    }
    
    const finalR = Math.round(rSum / count);
    const finalG = Math.round(gSum / count);
    const finalB = Math.round(bSum / count);
    return Qt.rgba(finalR / 255, finalG / 255, finalB / 255, 1.0);
}

/**
 * Formats a color object into a hex string (#RRGGBB).
 * @param {object} color - The QML color object.
 * @returns {string} The formatted hex string.
 */
function formatHexColor(color) {
    if (!color) return "#000000";
    
    // Coerce to string to see if it represents a valid hex color
    const s = String(color).trim();
    const match = s.match(/^#?([a-fA-F0-9]{3,8})$/);
    if (match) {
        let h = match[1];
        if (h.length === 8) {
            h = h.substring(2);
        } else if (h.length === 3) {
            h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
        }
        if (h.length === 6) {
            return "#" + h.toUpperCase();
        }
        return "#000000";
    }
    
    // Otherwise, check if it is a QML color object (has r, g, b)
    if (color && typeof color === "object" && color.r !== undefined) {
        return rgbToHex(color, true);
    }
    
    return "#000000";
}

/**
 * Normalizes any color input (string or color object) into a 6-character hex string.
 * @param {*} c - The color input.
 * @param {object} Qt - The Qt object.
 * @returns {string} Normalized lowercase hex string.
 */
function toHex6(c, Qt) {
    if (c === undefined || c === null) return "";
    const col = (typeof c === "string") ? Qt.color(c) : c;
    if (!col) return "";
    return rgbToHex(col, false);
}

/**
 * Compares two color inputs case-insensitively and handles format variations.
 * @param {*} c1 - First color.
 * @param {*} c2 - Second color.
 * @param {object} Qt - The Qt object.
 * @returns {boolean} True if equivalent.
 */
function colorEquals(c1, c2, Qt) {
    return toHex6(c1, Qt) === toHex6(c2, Qt);
}

// ─── 6. Stroke data ───────────────────────────────────────────────────────────

function copyStrokeProperties(source, target) {
    if (!source || !target) return;
    if (source.text !== undefined) target.text = source.text;
    if (source.fontFamily !== undefined) target.fontFamily = source.fontFamily;
    if (source.isBold !== undefined) target.isBold = source.isBold;
    if (source.isItalic !== undefined) target.isItalic = source.isItalic;
    if (source.isUnderline !== undefined) target.isUnderline = source.isUnderline;
    if (source.counter !== undefined) target.counter = source.counter;
    if (source.format !== undefined) target.format = source.format;
    if (source.hasBackground !== undefined) target.hasBackground = source.hasBackground;
    if (source.cornerRadius !== undefined) target.cornerRadius = source.cornerRadius;
    if (source.borderWidth !== undefined) target.borderWidth = source.borderWidth;
    if (source.lineStyle !== undefined) target.lineStyle = source.lineStyle;
    if (source.arrowLineStyle !== undefined) target.arrowLineStyle = source.arrowLineStyle;
    if (source.arrowHeadStyle !== undefined) target.arrowHeadStyle = source.arrowHeadStyle;
    if (source.redactMode !== undefined) target.redactMode = source.redactMode;
    if (source.redactShape !== undefined) target.redactShape = source.redactShape;
    if (source.hasLeaderLine !== undefined) target.hasLeaderLine = source.hasLeaderLine;
    if (source.isSpeechBubble !== undefined) target.isSpeechBubble = source.isSpeechBubble;
    if (source.calloutLinkLines !== undefined) target.calloutLinkLines = source.calloutLinkLines;
    if (source.calloutShape !== undefined) target.calloutShape = source.calloutShape;
    if (source.id !== undefined) target.id = source.id;
    if (source.randomize !== undefined) target.randomize = source.randomize;
    if (source.randomSeed !== undefined) target.randomSeed = source.randomSeed;
    if (source.rotation !== undefined) target.rotation = source.rotation;
    if (source.source !== undefined) target.source = source.source;
    if (source.originalAspectRatio !== undefined) target.originalAspectRatio = source.originalAspectRatio;
    if (source.opacity !== undefined) target.opacity = source.opacity;
}

/**
 * Calculates Euclidean distance between two points {x, y}.
 * @param {object} p1 - First point {x, y}.
 * @param {object} p2 - Second point {x, y}.
 * @returns {number} Distance value.
 */
function distance(p1, p2) {
    if (!p1 || !p2) return 0;
    return Math.hypot(p2.x - p1.x, p2.y - p1.y);
}

/**
 * Clamps a numerical value between min and max bounds.
 * @param {number} val - Input value.
 * @param {number} min - Lower bound.
 * @param {number} max - Upper bound.
 * @returns {number} Clamped value.
 */
function clamp(val, min, max) {
    return Math.max(min, Math.min(max, val));
}

/**
 * Positions a popover horizontally around an anchor while keeping it in bounds.
 * @param {number} containerWidth - Available parent width.
 * @param {number} popoverWidth - Popover width.
 * @param {number} anchorX - Anchor center x.
 * @param {number} margin - Minimum edge margin.
 * @returns {number} Clamped popover x position.
 */
function popoverX(containerWidth, popoverWidth, anchorX, margin) {
    const edgeMargin = margin === undefined ? 10 : margin;
    return clamp(anchorX - popoverWidth / 2, edgeMargin, containerWidth - popoverWidth - edgeMargin);
}

/**
 * Positions a popover above or below an anchor based on toolbar placement.
 * @param {number} containerHeight - Available parent height.
 * @param {number} popoverHeight - Popover height.
 * @param {number} anchorY - Anchor y.
 * @param {string} toolbarPosition - Main toolbar position.
 * @param {number} margin - Minimum edge margin.
 * @param {number} offset - Distance from anchor.
 * @returns {number} Clamped popover y position.
 */
function popoverY(containerHeight, popoverHeight, anchorY, toolbarPosition, margin, offset) {
    const edgeMargin = margin === undefined ? 10 : margin;
    const anchorOffset = offset === undefined ? 20 : offset;
    const targetY = toolbarPosition === "bottom" ? anchorY - popoverHeight - anchorOffset : anchorY + anchorOffset;
    return clamp(targetY, edgeMargin, containerHeight - popoverHeight - edgeMargin);
}
