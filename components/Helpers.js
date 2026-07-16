.pragma library
.import "Constants.js" as Constants

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
 * Returns a contrasting text color (black or white) based on hex color luminance.
 * @param {string} hex - The hex color string.
 * @param {object} Qt - The Qt object.
 * @returns {string} "#000000" or "#ffffff"
 */
function getContrastingColor(hex, Qt) {
    const rgb = hexToRgb(hex, Qt);
    const lum = getLuminance(rgb);
    return lum > 0.5 ? "#000000" : "#ffffff";
}

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
    for (var i = 0; i < items.length; i++) {
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
    const pad = function(num, size) {
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

/**
 * Downsamples screenshot pixels to extract a matching backdrop gradient.
 * @param {object} imgData - Canvas getImageData object of size 4x4.
 * @param {object} Qt - The Qt object.
 * @returns {object} { start, end } QML color values.
 */
function extractDominantColors(imgData, Qt) {
    var fallback = {
        start: Qt.rgba(0.2, 0.33, 0.47, 1),
        end: Qt.rgba(0.07, 0.13, 0.2, 1)
    };
    if (!imgData || !imgData.data || imgData.data.length < 64) {
        return fallback;
    }

    var pixels = [];
    for (var i = 0; i < 16; i++) {
        var r = imgData.data[i * 4];
        var g = imgData.data[i * 4 + 1];
        var b = imgData.data[i * 4 + 2];
        
        // Calculate saturation: max(r,g,b) - min(r,g,b)
        var max = Math.max(r, g, b);
        var min = Math.min(r, g, b);
        var sat = max - min;
        
        pixels.push({ r: r, g: g, b: b, sat: sat, max: max });
    }
    
    // Sort by saturation descending to prefer vibrant colors
    pixels.sort(function(a, b) { return b.sat - a.sat; });
    
    var colorStart, colorEnd;
    
    // If the image is extremely grey/monochromatic (saturation < 15)
    if (pixels[0].sat < 15) {
        var avg = 0;
        for (var i = 0; i < 16; i++) {
            avg += (pixels[i].r + pixels[i].g + pixels[i].b) / 3;
        }
        avg = Math.round(avg / 16);
        // Fallback: use a nice muted grey-blue gradient based on the average brightness
        colorStart = Qt.rgba(Math.max(0, avg - 20)/255, Math.max(0, avg - 10)/255, Math.min(255, avg + 10)/255, 1);
        colorEnd = Qt.rgba(Math.min(255, avg + 20)/255, Math.min(255, avg + 10)/255, Math.max(0, avg - 10)/255, 1);
    } else {
        // Start color: the most vibrant color
        var pStart = pixels[0];
        colorStart = Qt.rgba(pStart.r/255, pStart.g/255, pStart.b/255, 1);
        
        // End color: find a pixel that is sufficiently different from start color in RGB space
        var pEnd = null;
        var maxDist = -1;
        for (var j = 1; j < pixels.length; j++) {
            var pj = pixels[j];
            var dist = Math.sqrt(Math.pow(pj.r - pStart.r, 2) + Math.pow(pj.g - pStart.g, 2) + Math.pow(pj.b - pStart.b, 2));
            if (dist > maxDist) {
                maxDist = dist;
                pEnd = pj;
            }
        }
        
        if (pEnd && maxDist > 40) {
            colorEnd = Qt.rgba(pEnd.r/255, pEnd.g/255, pEnd.b/255, 1);
        } else {
            // Generate a complementary/analogous color if no distinct color is found
            colorEnd = Qt.rgba(
                Math.min(255, Math.round(pStart.r * 0.7 + 50))/255,
                Math.min(255, Math.round(pStart.g * 0.7 + 30))/255,
                Math.min(255, Math.round(pStart.b * 1.2))/255,
                1
            );
        }
    }
    
    // Calculate average image luminance
    var imgLuminance = 0;
    for (var i = 0; i < 16; i++) {
        var pr = imgData.data[i * 4] / 255;
        var pg = imgData.data[i * 4 + 1] / 255;
        var pb = imgData.data[i * 4 + 2] / 255;
        imgLuminance += (0.299 * pr + 0.587 * pg + 0.114 * pb);
    }
    imgLuminance /= 16;

    // Helper to adjust color to a specific target luminance
    function adjustToLuminance(c, targetL) {
        var l = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
        if (Math.abs(l - targetL) < 0.01) return c;
        
        if (targetL < l) {
            // Make darker
            var scale = targetL / Math.max(0.01, l);
            return Qt.rgba(Math.min(1.0, c.r * scale), Math.min(1.0, c.g * scale), Math.min(1.0, c.b * scale), 1);
        } else {
            // Make lighter
            if (l >= 0.99) return Qt.rgba(targetL, targetL, targetL, 1);
            var t = (targetL - l) / (1.0 - l);
            return Qt.rgba(c.r + (1.0 - c.r) * t, c.g + (1.0 - c.g) * t, c.b + (1.0 - c.b) * t, 1);
        }
    }

    var lStart = 0.299 * colorStart.r + 0.587 * colorStart.g + 0.114 * colorStart.b;
    var ratioStart = (Math.max(lStart, imgLuminance) + 0.05) / (Math.min(lStart, imgLuminance) + 0.05);
    
    var finalStart = colorStart;
    var finalEnd = colorEnd;
    
    if (ratioStart < 4.5) {
        var targetLStart;
        var targetLEnd;
        if (imgLuminance > 0.5) {
            // Image is light -> Make backdrop darker
            targetLStart = Math.max(0.05, (imgLuminance + 0.05) / 4.5 - 0.05);
            targetLEnd = Math.max(0.02, targetLStart * 0.65); // Make end color even darker
        } else {
            // Image is dark -> Make backdrop lighter
            targetLStart = Math.min(0.95, 4.5 * (imgLuminance + 0.05) - 0.05);
            targetLEnd = Math.min(0.98, targetLStart + (1.0 - targetLStart) * 0.35); // Make end color even lighter
        }
        finalStart = adjustToLuminance(colorStart, targetLStart);
        finalEnd = adjustToLuminance(colorEnd, targetLEnd);
    } else {
        // Start color already has good contrast. Ensure End color also has contrast,
        // and keep a healthy luminance gap between them to ensure gradient visibility.
        var lEnd = 0.299 * colorEnd.r + 0.587 * colorEnd.g + 0.114 * colorEnd.b;
        var ratioEnd = (Math.max(lEnd, imgLuminance) + 0.05) / (Math.min(lEnd, imgLuminance) + 0.05);
        
        if (ratioEnd < 4.5) {
            var targetLEnd;
            if (imgLuminance > 0.5) {
                targetLEnd = Math.max(0.02, (imgLuminance + 0.05) / 4.5 - 0.05);
                if (Math.abs(lStart - targetLEnd) < 0.1) {
                    targetLEnd = Math.max(0.02, targetLEnd * 0.65);
                }
            } else {
                targetLEnd = Math.min(0.98, 4.5 * (imgLuminance + 0.05) - 0.05);
                if (Math.abs(lStart - targetLEnd) < 0.1) {
                    targetLEnd = Math.min(0.98, targetLEnd + (1.0 - targetLEnd) * 0.35);
                }
            }
            finalStart = colorStart;
            finalEnd = adjustToLuminance(colorEnd, targetLEnd);
        } else {
            // Both already have good contrast. Ensure they are not too close in luminance
            if (Math.abs(lStart - lEnd) < 0.08) {
                if (imgLuminance > 0.5) {
                    finalEnd = adjustToLuminance(colorEnd, Math.max(0.02, lEnd * 0.75));
                } else {
                    finalEnd = adjustToLuminance(colorEnd, Math.min(0.98, lEnd + (1.0 - lEnd) * 0.25));
                }
            }
        }
    }

    return { 
        start: finalStart, 
        end: finalEnd 
    };
}

/**
 * Estimates text width based on characters and properties.
 * @param {string} text - The text string.
 * @param {number} fontSize - Font size in pixels.
 * @param {boolean} isBold - True if bold.
 * @param {boolean} isMonospace - True if monospace.
 * @returns {number} Estimated text width.
 */
function estimateTextWidth(text, fontSize, isBold, isMonospace) {
    if (!text) return 0;
    const lines = String(text).split("\n");
    let maxWidth = 0;
    for (let li = 0; li < lines.length; li++) {
        const line = lines[li];
        if (!line) continue;
        let charWidthRatio = isMonospace ? 0.6 : 0.52;
        if (isBold) charWidthRatio += 0.05;

        let estWidth = 0;
        for (let c = 0; c < line.length; c++) {
            const charCode = line.charCodeAt(c);
            if (charCode > 255) {
                const isCJKOrWideScript =
                        (charCode >= 0x3400 && charCode <= 0x4DBF) ||
                        (charCode >= 0x4E00 && charCode <= 0x9FFF) ||
                        (charCode >= 0xF900 && charCode <= 0xFAFF) ||
                        (charCode >= 0x3040 && charCode <= 0x309F) ||
                        (charCode >= 0x30A0 && charCode <= 0x30FF) ||
                        (charCode >= 0xAC00 && charCode <= 0xD7AF);

                if (isCJKOrWideScript) {
                    estWidth += fontSize * 0.9;
                } else {
                    estWidth += fontSize * charWidthRatio;
                }
            } else if (isMonospace) {
                estWidth += fontSize * charWidthRatio;
            } else {
                const ch = line.charAt(c);
                if ("iIlldt1|()[]{}".indexOf(ch) !== -1) {
                    estWidth += fontSize * 0.28;
                } else if ("mwMW".indexOf(ch) !== -1) {
                    estWidth += fontSize * 0.8;
                } else if (ch >= "A" && ch <= "Z") {
                    estWidth += fontSize * 0.65;
                } else {
                    estWidth += fontSize * charWidthRatio;
                }
            }
        }

        const maxW = fontSize * line.length * (isMonospace ? 1.2 : 1.6);
        estWidth = Math.min(estWidth, maxW);
        if (estWidth > maxWidth) maxWidth = estWidth;
    }

    return maxWidth;
}

/**
 * Finds the index of the stroke under coordinate (mx, my).
 * @param {number} mx - X coordinate.
 * @param {number} my - Y coordinate.
 * @param {array} strokes - List of strokes.
 * @param {function} estimateTextWidthFn - Text width estimation function.
 * @returns {number} Stroke index or -1.
 */
function getStrokeBBox(stroke, estimateTextWidthFn) {
    let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
    const pts = stroke.points;
    const len = pts.length;
    if (len === 0) return { minX: 0, minY: 0, maxX: 0, maxY: 0 };

    if (stroke.tool === "text") {
        const p0 = pts[0];
        const fontSize = stroke.width;
        const txt = stroke.text || "";
        const lines = String(txt).split("\n");
        const numLines = lines.length || 1;
        const lineHeight = fontSize * 1.35;

        let textW = Constants.minTextWidth;
        if (estimateTextWidthFn) {
            textW = Math.max(Constants.minTextWidth, estimateTextWidthFn(txt, fontSize, stroke.isBold === true, stroke.isMonospace === true));
        }
        let textH = fontSize + (numLines - 1) * lineHeight;
        let textX = p0.x;
        let textY = p0.y;

        if (stroke.hasBackground) {
            const padX = fontSize * Constants.textPaddingMultiplierX;
            const padY = fontSize * Constants.textPaddingMultiplierY;
            textX -= padX;
            textY -= padY;
            textW += padX * 2;
            textH += padY * 2;
        }
        minX = textX;
        maxX = textX + textW;
        minY = textY;
        maxY = textY + textH;
    } else if (stroke.tool === "stamp") {
        const radius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
        if (stroke.hasLeaderLine && len >= 2) {
            const p0 = pts[0];
            const p1 = pts[1];
            minX = Math.min(p0.x, p1.x) - radius;
            maxX = Math.max(p0.x, p1.x) + radius;
            minY = Math.min(p0.y, p1.y) - radius;
            maxY = Math.max(p0.y, p1.y) + radius;
        } else {
            const p0 = pts[0];
            minX = p0.x - radius;
            maxX = p0.x + radius;
            minY = p0.y - radius;
            maxY = p0.y + radius;
        }
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

function findStrokeAt(mx, my, strokes, estimateTextWidthFn) {
    for (let i = strokes.length - 1; i >= 0; i--) {
        const stroke = strokes[i];
        if (stroke.points.length === 0) continue;

        const threshold = Constants.selectionThresholdBase + stroke.width;

        // Fast bounding box reject check
        const bbox = getStrokeBBox(stroke, estimateTextWidthFn);
        const pad = threshold + 2;
        if (mx < bbox.minX - pad || mx > bbox.maxX + pad ||
            my < bbox.minY - pad || my > bbox.maxY + pad) {
            continue;
        }

        if (stroke.tool === "pen" || stroke.tool === "highlighter") {
            for (let j = 0; j < stroke.points.length - 1; j++) {
                const A = stroke.points[j];
                const B = stroke.points[j+1];
                const dx = B.x - A.x;
                const dy = B.y - A.y;
                const lenSq = dx * dx + dy * dy;
                let dist = Infinity;
                if (lenSq === 0) {
                    dist = Math.sqrt((mx - A.x) * (mx - A.x) + (my - A.y) * (my - A.y));
                } else {
                    let t = ((mx - A.x) * dx + (my - A.y) * dy) / lenSq;
                    t = Math.max(0, Math.min(1, t));
                    const px = A.x + t * dx;
                    const py = A.y + t * dy;
                    dist = Math.sqrt((mx - px) * (mx - px) + (my - py) * (my - py));
                }
                if (dist < threshold) return i;
            }
        } else if (stroke.tool === "rect") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const x1 = Math.min(p0.x, p1.x);
            const x2 = Math.max(p0.x, p1.x);
            const y1 = Math.min(p0.y, p1.y);
            const y2 = Math.max(p0.y, p1.y);
            if (mx >= x1 - threshold && mx <= x2 + threshold && my >= y1 - threshold && my <= y2 + threshold) {
                const dx = Math.min(Math.abs(mx - x1), Math.abs(mx - x2));
                const dy = Math.min(Math.abs(my - y1), Math.abs(my - y2));
                if (dx <= threshold || dy <= threshold) return i;
            }
        } else if (stroke.tool === "redact") {
            const shape = stroke.redactShape || "rect";
            let x1, x2, y1, y2;
            if (shape === "freehand" && stroke.freehandPoints && stroke.freehandPoints.length > 0) {
                x1 = Infinity; x2 = -Infinity; y1 = Infinity; y2 = -Infinity;
                for (let j = 0; j < stroke.freehandPoints.length; j++) {
                    const p = stroke.freehandPoints[j];
                    if (p.x < x1) x1 = p.x;
                    if (p.x > x2) x2 = p.x;
                    if (p.y < y1) y1 = p.y;
                    if (p.y > y2) y2 = p.y;
                }
            } else {
                const p0 = stroke.points[0];
                const p1 = stroke.points[stroke.points.length - 1];
                x1 = Math.min(p0.x, p1.x);
                x2 = Math.max(p0.x, p1.x);
                y1 = Math.min(p0.y, p1.y);
                y2 = Math.max(p0.y, p1.y);
            }
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
        } else if (stroke.tool === "pixelate" || stroke.tool === "spotlight") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const x1 = Math.min(p0.x, p1.x);
            const x2 = Math.max(p0.x, p1.x);
            const y1 = Math.min(p0.y, p1.y);
            const y2 = Math.max(p0.y, p1.y);
            if (mx >= x1 - Constants.rectSelectionPadding && mx <= x2 + Constants.rectSelectionPadding && my >= y1 - Constants.rectSelectionPadding && my <= y2 + Constants.rectSelectionPadding) {
                return i;
            }
        } else if (stroke.tool === "ellipse") {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const x1 = Math.min(p0.x, p1.x);
            const x2 = Math.max(p0.x, p1.x);
            const y1 = Math.min(p0.y, p1.y);
            const y2 = Math.max(p0.y, p1.y);
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
            const dx = p1.x - p0.x;
            const dy = p1.y - p0.y;
            const lenSq = dx * dx + dy * dy;
            let dist = Infinity;
            if (lenSq === 0) {
                dist = Math.sqrt((mx - p0.x) * (mx - p0.x) + (my - p0.y) * (my - p0.y));
            } else {
                let t = ((mx - p0.x) * dx + (my - p0.y) * dy) / lenSq;
                t = Math.max(0, Math.min(1, t));
                const px = p0.x + t * dx;
                const py = p0.y + t * dy;
                dist = Math.sqrt((mx - px) * (mx - px) + (my - py) * (my - py));
            }
            if (dist < threshold) return i;
        } else if (stroke.tool === "stamp") {
            const radius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
            if (stroke.hasLeaderLine && stroke.points.length >= 2) {
                const p0 = stroke.points[0];
                const p1 = stroke.points[1];

                // Check stamp circle at points[1]
                const distStamp = Math.sqrt((mx - p1.x) * (mx - p1.x) + (my - p1.y) * (my - p1.y));
                if (distStamp <= radius) return i;

                // Check leader line segment points[0] -> points[1]
                const dx = p1.x - p0.x;
                const dy = p1.y - p0.y;
                const lenSq = dx * dx + dy * dy;
                let distLine = Infinity;
                if (lenSq === 0) {
                    distLine = Math.sqrt((mx - p0.x) * (mx - p0.x) + (my - p0.y) * (my - p0.y));
                } else {
                    let t = ((mx - p0.x) * dx + (my - p0.y) * dy) / lenSq;
                    t = Math.max(0, Math.min(1, t));
                    const px = p0.x + t * dx;
                    const py = p0.y + t * dy;
                    distLine = Math.sqrt((mx - px) * (mx - px) + (my - py) * (my - py));
                }
                if (distLine < threshold) return i;
            } else {
                const p0 = stroke.points[0];
                const dist = Math.sqrt((mx - p0.x) * (mx - p0.x) + (my - p0.y) * (my - p0.y));
                if (dist <= radius) return i;
            }
        } else if (stroke.tool === "text") {
            const p0 = stroke.points[0];
            const fontSize = stroke.width;
            const txt = stroke.text || "";
            const lines = String(txt).split("\n");
            const numLines = lines.length || 1;
            const lineHeight = fontSize * 1.35;

            let textW = Math.max(Constants.minTextWidth, estimateTextWidthFn(txt, fontSize, stroke.isBold === true, stroke.isMonospace === true));
            let textH = fontSize + (numLines - 1) * lineHeight;
            let textY = p0.y;
            let textX = p0.x;

            if (stroke.hasBackground) {
                const padX = fontSize * Constants.textPaddingMultiplierX;
                const padY = fontSize * Constants.textPaddingMultiplierY;
                textX -= padX;
                textY -= padY;
                textW += padX * 2;
                textH += padY * 2;
            }

            if (mx >= textX - Constants.ocrSelectionPadding && mx <= textX + textW + Constants.ocrSelectionPadding && my >= textY - Constants.ocrSelectionPadding && my <= textY + textH + Constants.ocrSelectionPadding) {
                return i;
            }
        } else if (stroke.tool === "callout" && stroke.points.length === 4) {
            const srcP0 = stroke.points[0];
            const srcP1 = stroke.points[1];
            const dstP0 = stroke.points[2];
            const dstP1 = stroke.points[3];
            if ((mx >= srcP0.x - Constants.calloutSelectionPadding && mx <= srcP1.x + Constants.calloutSelectionPadding && my >= srcP0.y - Constants.calloutSelectionPadding && my <= srcP1.y + Constants.calloutSelectionPadding) ||
                (mx >= dstP0.x - Constants.calloutSelectionPadding && mx <= dstP1.x + Constants.calloutSelectionPadding && my >= dstP0.y - Constants.calloutSelectionPadding && my <= dstP1.y + Constants.calloutSelectionPadding)) {
                return i;
            }
        }
    }
    return -1;
}

/**
 * Checks if a point (mx, my) is hovering over a resize handle of the given stroke.
 * Returns the handle identifier or "none".
 * Shapes: tl, tr, bl, br, tc, bc, lc, rc
 * Lines: start, end
 */
function getStrokeHandleAt(mx, my, stroke, estimateTextWidthFn) {
    if (!stroke || !stroke.points || stroke.points.length === 0) return "none";
    const threshold = Constants.selectionHandleSize + 4;

    if (stroke.tool === "rect" || stroke.tool === "ellipse" || stroke.tool === "redact" ||
        stroke.tool === "pixelate" || stroke.tool === "spotlight") {
        if (stroke.points.length < 2) return "none";
        let x1, y1, x2, y2;
        if (stroke.tool === "redact" && stroke.redactShape === "freehand" && stroke.freehandPoints && stroke.freehandPoints.length > 0) {
            x1 = Infinity; x2 = -Infinity; y1 = Infinity; y2 = -Infinity;
            for (let j = 0; j < stroke.freehandPoints.length; j++) {
                const p = stroke.freehandPoints[j];
                if (p.x < x1) x1 = p.x;
                if (p.x > x2) x2 = p.x;
                if (p.y < y1) y1 = p.y;
                if (p.y > y2) y2 = p.y;
            }
        } else {
            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            x1 = Math.min(p0.x, p1.x);
            y1 = Math.min(p0.y, p1.y);
            x2 = Math.max(p0.x, p1.x);
            y2 = Math.max(p0.y, p1.y);
        }
        const cx = (x1 + x2) / 2;
        const cy = (y1 + y2) / 2;

        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y1) <= threshold) return "tl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y1) <= threshold) return "tr";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y2) <= threshold) return "bl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y2) <= threshold) return "br";
        if (Math.abs(mx - cx) <= threshold && Math.abs(my - y1) <= threshold) return "tc";
        if (Math.abs(mx - cx) <= threshold && Math.abs(my - y2) <= threshold) return "bc";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - cy) <= threshold) return "lc";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - cy) <= threshold) return "rc";
        return "none";
    }

    if (stroke.tool === "line" || stroke.tool === "arrow" || stroke.tool === "highlighter") {
        if (stroke.points.length < 2) return "none";
        const p0 = stroke.points[0];
        const p1 = stroke.points[stroke.points.length - 1];
        if (Math.abs(mx - p0.x) <= threshold && Math.abs(my - p0.y) <= threshold) return "start";
        if (Math.abs(mx - p1.x) <= threshold && Math.abs(my - p1.y) <= threshold) return "end";
        return "none";
    }

    if (stroke.tool === "stamp") {
        const hasLeader = stroke.hasLeaderLine && stroke.points.length >= 2;
        const stampPt = hasLeader ? stroke.points[1] : stroke.points[0];
        const stampRadius = stroke.width * Constants.stampRadiusMultiplier + Constants.stampSelectThresholdOffset;
        const dx = mx - stampPt.x;
        const dy = my - stampPt.y;
        if (dx * dx + dy * dy <= stampRadius * stampRadius) return "stamp";
        if (hasLeader) {
            const anchorPt = stroke.points[0];
            if (Math.abs(mx - anchorPt.x) <= threshold && Math.abs(my - anchorPt.y) <= threshold) return "anchor";
        }
        return "none";
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

        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y1) <= threshold) return "src_tl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y1) <= threshold) return "src_tr";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y2) <= threshold) return "src_bl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y2) <= threshold) return "src_br";
        if (Math.abs(mx - cx) <= threshold && Math.abs(my - y1) <= threshold) return "src_tc";
        if (Math.abs(mx - cx) <= threshold && Math.abs(my - y2) <= threshold) return "src_bc";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - cy) <= threshold) return "src_lc";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - cy) <= threshold) return "src_rc";
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
        const r = Math.round((color.r || 0) * 255).toString(16).padStart(2, '0');
        const g = Math.round((color.g || 0) * 255).toString(16).padStart(2, '0');
        const b = Math.round((color.b || 0) * 255).toString(16).padStart(2, '0');
        return ("#" + r + g + b).toUpperCase();
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
    const r = Math.round((col.r || 0) * 255).toString(16).padStart(2, '0');
    const g = Math.round((col.g || 0) * 255).toString(16).padStart(2, '0');
    const b = Math.round((col.b || 0) * 255).toString(16).padStart(2, '0');
    return ("#" + r + g + b).toLowerCase();
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
