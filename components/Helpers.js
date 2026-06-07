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
