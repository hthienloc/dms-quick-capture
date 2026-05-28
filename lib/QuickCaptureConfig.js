.pragma library

var toolButtons = [
    { id: "pen", icon: "edit", tooltip: "Freehand Pen (1)" },
    { id: "line", icon: "horizontal_rule", tooltip: "Straight Line (2)" },
    { id: "arrow", icon: "trending_flat", tooltip: "Arrow Vector (3)" },
    { id: "rect", icon: "crop_square", tooltip: "Rectangle Outline (4)" },
    { id: "ellipse", icon: "radio_button_unchecked", tooltip: "Ellipse / Circle (Q)" },
    { id: "text", icon: "text_fields", tooltip: "Text Note (W)" },
    { id: "pixelate", icon: "blur_on", tooltip: "Pixelate (E)" },
    { id: "redact", icon: "square", tooltip: "Redact / Blackout (R)" },
    { id: "stamp", icon: "looks_one", tooltip: "Number Stamp (A)" },
    { id: "highlighter", icon: "border_color", tooltip: "Highlighter (S)" },
    { id: "eraser", icon: "auto_fix_normal", tooltip: "Eraser (D)" },
    { id: "crop", icon: "crop", tooltip: "Crop / Resize Area (P)" }
];

var accentColors = [
    "#3b82f6",
    "#ef4444",
    "#22c55e",
    "#eab308",
    "#a855f7",
    "#ffffff",
    "#000000"
];

var toolShortcuts = [
    { key: "V", tool: "select" },
    { key: "1", tool: "pen" },
    { key: "2", tool: "line" },
    { key: "3", tool: "arrow" },
    { key: "4", tool: "rect" },
    { key: "Q", tool: "ellipse" },
    { key: "W", tool: "text" },
    { key: "E", tool: "pixelate" },
    { key: "R", tool: "redact" },
    { key: "A", tool: "stamp" },
    { key: "S", tool: "highlighter" },
    { key: "D", tool: "eraser" },
    { key: "P", tool: "crop" }
];

var colorShortcuts = [
    { key: "1", color: "primary" },
    { key: "2", color: "#3b82f6" },
    { key: "3", color: "#ef4444" },
    { key: "4", color: "#22c55e" },
    { key: "Q", color: "#eab308" },
    { key: "W", color: "#a855f7" },
    { key: "E", color: "#ffffff" },
    { key: "R", color: "#000000" }
];

function findByKey(items, key) {
    for (var i = 0; i < items.length; i++) {
        if (items[i].key === key) return items[i];
    }
    return null;
}
