.pragma library

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
 * Resolves a shortcut color string (e.g., "primary") to its actual color value.
 * @param {string} color
 * @param {object} Theme
 * @returns {color}
 */
function resolveShortcutColor(color, Theme) {
    return color === "primary" ? Theme.primary : color;
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
    const yy = yyyy % 100;
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
    
    return { start: colorStart, end: colorEnd };
}
