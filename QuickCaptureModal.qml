import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modals.Common
import "./dms-common"
import "components"

DankModal {
    id: window

    CaptureConfig { 
        id: config 
        pluginData: window.parentWidget?.pluginData || ({})
    }

    Image {
        id: watermarkImageLoader
        
        property int pathIndex: 0
        property var fallbackPaths: []
        
        source: {
            const rawPath = window.parentWidget?.pluginData?.watermarkImage || "";
            if (rawPath) {
                let p = rawPath.trim();
                if (p.indexOf("~/") === 0) {
                    const home = Quickshell.env("HOME") || "";
                    p = home + p.substring(1);
                }
                if (p.indexOf("/") === 0) {
                    p = "file://" + p;
                }
                return p;
            }
            
            if (fallbackPaths.length > 0 && pathIndex < fallbackPaths.length) {
                return fallbackPaths[pathIndex];
            }
            return "";
        }
        
        onStatusChanged: {
            if (status === Image.Error && (!window.parentWidget?.pluginData?.watermarkImage)) {
                if (pathIndex < fallbackPaths.length - 1) {
                    pathIndex++;
                }
            }
        }
        
        Component.onCompleted: {
            const username = Quickshell.env("USER") || Quickshell.env("USERNAME") || "";
            const home = Quickshell.env("HOME") || "";
            const list = [];
            if (home) {
                list.push("file://" + home + "/.face");
                list.push("file://" + home + "/.face.icon");
            }
            if (username) {
                list.push("file:///var/lib/AccountsService/icons/" + username);
            }
            list.push("image://icon/user-info");
            list.push("image://icon/avatar-default");
            fallbackPaths = list;
        }
        
        visible: false
        cache: true
    }

    layerNamespace: "dms:plugins:quickCapture"
    keepPopoutsOpen: true

    // Parent communication reference
    property var parentWidget: null

    // State Variables
    property string currentTool: "crop" // crop, select, pen, line, arrow, rect, ellipse, text, pixelate, redact, stamp, highlighter, eraser
    property string lastActiveTool: "pen"
    readonly property real dpr: Screen.devicePixelRatio || 1.0
    onCurrentToolChanged: {
        if (currentTool !== "text" && window.isTyping) {
            window.commitTypingText();
        }
        if (currentTool !== "crop") {
            lastActiveTool = currentTool;
        }
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }
    property color currentColor: Theme.primary
    onCurrentColorChanged: {
        if (window.selectedStroke) {
            window.selectedStroke.color = window.currentColor.toString();
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke) {
            window.currentStroke.color = window.currentColor.toString();
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int strokeWidth: 8
    onStrokeWidthChanged: {
        // Apply new width to the currently selected stroke so live edits
        // are reflected immediately without needing to re-draw.
        if (window.selectedStroke) {
            window.selectedStroke.width = window.strokeWidth;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes]; // trigger reactivity
            }
        }
        // Also update an in-progress stroke (e.g. actively drawing a highlight)
        if (window.currentStroke) {
            window.currentStroke.width = window.strokeWidth;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int stampCounter: 1
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false

    property bool isTabPressed: false
    property bool isZoomPressed: false
    property string toolBeforeTab: ""
    property real cursorX: 0
    property real cursorY: 0
    readonly property real boardCursorX: boardContainerItem ? (boardContainerItem.width / 2 + (cursorX - drawingCanvas.width / 2) * fitScale) : 0
    readonly property real boardCursorY: boardContainerItem ? (boardContainerItem.height / 2 + (cursorY - drawingCanvas.height / 2) * fitScale) : 0

    property bool showAnnotations: true
    onShowAnnotationsChanged: {
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }
    property var copiedStroke: null

    property var strokes: []
    property var currentStroke: null
    property var selectedStroke: null
    property int preGrabStrokeWidth: 8
    property color preGrabColor: Theme.primary
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

    // Text Input Management
    property bool isTyping: false
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""

    // Helper to decode hex color to RGB
    function hexToRgb(hex) {
        if (!hex) return { r: 0.2, g: 0.5, b: 1 };
        const c = Qt.color(hex);
        return { r: c.r, g: c.g, b: c.b };
    }

    backgroundOpacity: (parentWidget?.pluginData?.modalOpacity ?? 60) / 100
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

    property int textFontSize: parentWidget?.pluginData?.textFontSize ?? 36
    readonly property bool textMonospace: parentWidget?.pluginData?.textMonospace ?? false
    
    // Rich Text Options
    property bool textBold: parentWidget?.pluginData?.textBold ?? false
    onTextBoldChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textItalic: parentWidget?.pluginData?.textItalic ?? false
    onTextItalicChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textUnderline: parentWidget?.pluginData?.textUnderline ?? false
    onTextUnderlineChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string textFontFamily: parentWidget?.pluginData?.textFontFamily ?? (textMonospace ? "monospace" : "sans-serif")
    onTextFontFamilyChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    readonly property string textInputMode: parentWidget?.pluginData?.textInputMode ?? "inline"
    readonly property string toolbarPosition: parentWidget?.pluginData?.toolbarPosition ?? "top"
    readonly property bool configShowToolbar: parentWidget?.pluginData?.showToolbar ?? true
    readonly property bool enableMagnifier: true
    property bool toolbarVisible: true
    onConfigShowToolbarChanged: {
        window.toolbarVisible = window.configShowToolbar;
    }

    function openCentered() {
        open();
    }

    shouldBeVisible: false
    
    // Spacious modal dimensions occupying 90% width and 90% height of the screen
    modalWidth: Math.round(Quickshell.screens[0].width * 0.9)
    modalHeight: Math.round(Quickshell.screens[0].height * 0.9)
    enableShadow: true
    positioning: "center"

    // Component scope bridging properties
    property string bgImageSource: ""
    property var activeCanvas: null
    property var bgImageItem: null
    property var boardContainerItem: null
    property var exportCanvasItem: null

    // Radial Menu Presets
    property var radialPresets: []

    function updateRadialPresets() {
        const list = [];
        if (!window.parentWidget || !window.parentWidget.pluginData) {
            window.radialPresets = list;
            return;
        }
        for (let i = 0; i < 8; i++) {
            const t = window.parentWidget.pluginData["preset_" + i + "_tool"];
            if (t && t !== "none") {
                const rawColor = window.parentWidget.pluginData["preset_" + i + "_color"] || Theme.primary;
                const resolvedColor = config.resolveColor(rawColor);
                list.push({
                    tool: t,
                    color: resolvedColor,
                    thickness: window.parentWidget.pluginData["preset_" + i + "_thickness"] || 6
                });
            }
        }
        window.radialPresets = list;
    }

    // Dynamic scale to fit the screenshot (supports standard, high-DPI, and multi-monitor setups)
    property real fitScale: {
        if (!activeCanvas || !bgImageItem || !boardContainerItem) return 1.0;
        const maxW = boardContainerItem.width;
        const maxH = boardContainerItem.height;
        const targetW = (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.width : bgImageItem.sourceSize.width;
        const targetH = (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.height : bgImageItem.sourceSize.height;
        if (targetW <= 0 || targetH <= 0) return 1.0;
        const scaleX = maxW / targetW;
        const scaleY = maxH / targetH;
        const scale = Math.min(scaleX, scaleY);
        if (window.currentTool !== "crop" && window.hasSelection) {
            return Math.min(scale, 1.0);
        }
        return scale;
    }

    // Crop Selection State
    property rect cropRect: Qt.rect(0, 0, 0, 0)
    property bool hasSelection: false

    readonly property bool roundRect: parentWidget?.pluginData?.roundRect ?? true
    readonly property bool roundHighlighter: parentWidget?.pluginData?.roundHighlighter ?? false
    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property var exportCallback: null

    QuickCaptureActions {
        id: captureActions
        parentWidget: window.parentWidget
        exportAndExecute: window.exportAndExecute
        onCloseRequested: window.discardAndClose()
    }

    function getHoveredHandle(mx, my) {
        if (!hasSelection || currentTool !== "crop") return "none";
        const threshold = 15;
        const x1 = cropRect.x;
        const y1 = cropRect.y;
        const x2 = cropRect.x + cropRect.width;
        const y2 = cropRect.y + cropRect.height;
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y1) <= threshold) return "tl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y1) <= threshold) return "tr";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y2) <= threshold) return "bl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y2) <= threshold) return "br";
        return "none";
    }

    function isInsideCropRect(mx, my) {
        if (!hasSelection) return false;
        return mx >= cropRect.x && mx <= (cropRect.x + cropRect.width) &&
               my >= cropRect.y && my <= (cropRect.y + cropRect.height);
    }

    function constrainSquarePoint(start, point) {
        if (!start || !point) return point || Qt.point(0, 0);
        const dx = point.x - start.x;
        const dy = point.y - start.y;
        const size = Math.max(Math.abs(dx), Math.abs(dy));
        const sx = dx < 0 ? -1 : 1;
        const sy = dy < 0 ? -1 : 1;
        return Qt.point(start.x + sx * size, start.y + sy * size);
    }

    function findStrokeAt(mx, my) {
        for (let i = window.strokes.length - 1; i >= 0; i--) {
            const stroke = window.strokes[i];
            if (stroke.points.length === 0) continue;

            const threshold = 12 + stroke.width;

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
            } else if (stroke.tool === "rect" || stroke.tool === "redact" || stroke.tool === "pixelate") {
                const p0 = stroke.points[0];
                const p1 = stroke.points[stroke.points.length - 1];
                const x1 = Math.min(p0.x, p1.x);
                const x2 = Math.max(p0.x, p1.x);
                const y1 = Math.min(p0.y, p1.y);
                const y2 = Math.max(p0.y, p1.y);
                if (mx >= x1 - 5 && mx <= x2 + 5 && my >= y1 - 5 && my <= y2 + 5) {
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
                const p0 = stroke.points[0];
                const radius = stroke.width * 5 + 6;
                const dist = Math.sqrt((mx - p0.x) * (mx - p0.x) + (my - p0.y) * (my - p0.y));
                if (dist <= radius) return i;
            } else if (stroke.tool === "text") {
                const p0 = stroke.points[0];
                const h = stroke.width * 4 + 10;
                const w = Math.max(40, stroke.text.length * stroke.width * 2 + 10);
                if (mx >= p0.x - 5 && mx <= p0.x + w && my >= p0.y - 5 && my <= p0.y + h) {
                    return i;
                }
            }
        }
        return -1;
    }

    function exportAndExecute(callback) {
        if (window.isTyping) {
            window.commitTypingText();
        }
        window.exportCallback = callback;
        if (!window.exportCanvasItem) {
            console.warn("exportCanvasItem is not initialized yet");
            return;
        }
        if (window.hasSelection) {
            window.exportCanvasItem.width = window.cropRect.width / window.dpr;
            window.exportCanvasItem.height = window.cropRect.height / window.dpr;
        } else if (window.activeCanvas) {
            window.exportCanvasItem.width = window.activeCanvas.width / window.dpr;
            window.exportCanvasItem.height = window.activeCanvas.height / window.dpr;
        }
        window.exportCanvasItem.requestPaint();
    }

    function shortcutToken(key) {
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

    function shortcutColor(color) {
        return color === "primary" ? Theme.primary : color;
    }

    function handleTypingKey(event) {
        if (event.key === Qt.Key_Escape) {
            window.isTyping = false;
            window.currentTypingText = "";
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            window.commitTypingText();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            window.currentTypingText = window.currentTypingText.slice(0, -1);
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.text && event.text.length > 0 && !(event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier)) {
            window.currentTypingText += event.text;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
        }
    }

    function handleShortcutKey(event) {
        const token = window.shortcutToken(event.key);
        const hasCtrl = event.modifiers & Qt.ControlModifier;

        if (event.key === Qt.Key_Escape) {
            window.discardAndClose();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "Z") {
            window.performUndo();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "C") {
            captureActions.performCopyOnly();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            captureActions.performDoneAction();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "S") {
            captureActions.performSaveOnly();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "A") {
            captureActions.performCopyAndSave();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "F") {
            captureActions.performFloatAction();
            event.accepted = true;
            return;
        }
        if (hasCtrl && token === "X") {
            window.currentTool = window.currentTool === "crop" ? window.lastActiveTool : "crop";
            event.accepted = true;
            return;
        }

        if (token === "X" && !hasCtrl) {
            window.showAnnotations = !window.showAnnotations;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }

        if (token === "C" && !hasCtrl) {
            if (window.selectedStroke) {
                window.copiedStroke = {
                    tool: window.selectedStroke.tool,
                    color: window.selectedStroke.color.toString(),
                    width: window.selectedStroke.width,
                    points: window.selectedStroke.points.map(p => Qt.point(p.x, p.y)),
                    counter: window.selectedStroke.counter
                };
                event.accepted = true;
                return;
            }
        }

        if (token === "V" && !hasCtrl) {
            if (window.copiedStroke) {
                const mx = window.cursorX;
                const my = window.cursorY;
                const absPt = window.currentTool !== "crop" && window.hasSelection ? Qt.point(mx + window.cropRect.x, my + window.cropRect.y) : Qt.point(mx, my);

                // Calculate the bounding box center of the copied stroke
                let minX = Infinity, maxX = -Infinity;
                let minY = Infinity, maxY = -Infinity;
                for (let i = 0; i < window.copiedStroke.points.length; i++) {
                    const p = window.copiedStroke.points[i];
                    if (p.x < minX) minX = p.x;
                    if (p.x > maxX) maxX = p.x;
                    if (p.y < minY) minY = p.y;
                    if (p.y > maxY) maxY = p.y;
                }
                const centerX = (minX + maxX) / 2;
                const centerY = (minY + maxY) / 2;

                // Shift points so the pasted stroke is centered exactly at the current cursor position
                const dx = absPt.x - (isFinite(centerX) ? centerX : 0);
                const dy = absPt.y - (isFinite(centerY) ? centerY : 0);
                const newPoints = window.copiedStroke.points.map(p => Qt.point(p.x + dx, p.y + dy));
                
                const pasted = {
                    tool: window.copiedStroke.tool,
                    color: window.copiedStroke.color,
                    width: window.copiedStroke.width,
                    points: newPoints,
                    counter: window.copiedStroke.counter
                };
                
                window.pushStroke(pasted);
                
                if (window.currentTool === "select") {
                    window.preGrabStrokeWidth = window.strokeWidth;
                    window.preGrabColor = window.currentColor;
                    window.strokeWidth = pasted.width;
                    window.currentColor = pasted.color;
                    window.selectedStroke = pasted;
                    window.pressCoords = absPt;
                    window.originalPoints = newPoints;
                }
                
                if (window.activeCanvas) window.activeCanvas.requestPaint();
                event.accepted = true;
                return;
            }
        }

        if (hasCtrl) {
            const colorShortcut = config.findByKey(config.colorShortcuts, token);
            if (colorShortcut) {
                window.currentColor = window.shortcutColor(colorShortcut.color);
                event.accepted = true;
            }
            return;
        }

        const toolShortcut = config.findByKey(config.toolShortcuts, token);
        if (toolShortcut) {
            window.currentTool = toolShortcut.tool;
            event.accepted = true;
        }
    }

    onBackgroundClicked: () => discardAndClose()

    // Keyboard Shortcuts Support
    modalFocusScope.Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            window.isTabPressed = true;
            if (config.tabBehavior === "hold") {
                if (window.currentTool !== "select") {
                    window.toolBeforeTab = window.currentTool;
                    window.currentTool = "select";
                }
            } else {
                if (window.currentTool === "select") {
                    window.currentTool = (window.lastActiveTool === "select" || window.lastActiveTool === "crop") ? "pen" : window.lastActiveTool;
                } else {
                    window.currentTool = "select";
                }
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Z && !(event.modifiers & Qt.ControlModifier)) {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            window.isZoomPressed = true;
            event.accepted = true;
            return;
        }
        if (window.isTyping) {
            if (window.textInputMode === "inline") {
                window.handleTypingKey(event);
            } else {
                event.accepted = true;
            }
            return;
        }

        window.handleShortcutKey(event);
    }

    modalFocusScope.Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Tab) {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            window.isTabPressed = false;
            if (config.tabBehavior === "hold") {
                if (window.toolBeforeTab !== "") {
                    window.currentTool = window.toolBeforeTab;
                    window.toolBeforeTab = "";
                }
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Z && !(event.modifiers & Qt.ControlModifier)) {
            if (event.isAutoRepeat) {
                event.accepted = true;
                return;
            }
            window.isZoomPressed = false;
            event.accepted = true;
            return;
        }
    }

    onOpened: {
        window.updateRadialPresets();

        let startTool = "pen";
        let startThickness = 6;
        let startColor = Theme.primary;

        const defaultToolMode = window.parentWidget && window.parentWidget.pluginData ? (window.parentWidget.pluginData.defaultToolMode || "custom") : "custom";
        if (defaultToolMode === "preset") {
            const presetIdxRaw = window.parentWidget && window.parentWidget.pluginData ? (window.parentWidget.pluginData.defaultPresetIndex ?? "0") : "0";
            const presetIdx = parseInt(presetIdxRaw, 10);
            const t = window.parentWidget && window.parentWidget.pluginData ? window.parentWidget.pluginData["preset_" + presetIdx + "_tool"] : undefined;
            if (t && t !== "none") {
                startTool = t;
                const rawColor = window.parentWidget.pluginData["preset_" + presetIdx + "_color"] || Theme.primary;
                startColor = config.resolveColor(rawColor);
                startThickness = window.parentWidget.pluginData["preset_" + presetIdx + "_thickness"] || 6;
            } else {
                if (window.parentWidget && window.parentWidget.pluginData) {
                    startTool = window.parentWidget.pluginData.defaultTool || "pen";
                    startThickness = window.parentWidget.pluginData.defaultThickness || 6;
                }
            }
        } else {
            if (window.parentWidget && window.parentWidget.pluginData) {
                startTool = window.parentWidget.pluginData.defaultTool || "pen";
                startThickness = window.parentWidget.pluginData.defaultThickness || 6;
            }
        }

        const captureMode = window.parentWidget && window.parentWidget.pluginData ? (window.parentWidget.pluginData.captureMode || "region") : "region";
        if (captureMode === "region") {
            window.currentTool = startTool;
        } else {
            window.currentTool = "crop";
        }
        window.toolbarVisible = window.configShowToolbar;
        window.strokeWidth = startThickness;
        window.currentColor = startColor;

        window.strokes = [];
        window.stampCounter = 1;
        window.bgImageSource = "";
        window.bgImageSource = "file:///tmp/dms_capture_bg.png";
        window.isScreenshotDark = false;
        window.hasSampledContrast = false;
        window.cropRect = Qt.rect(0, 0, 0, 0);
        window.hasSelection = false;
        window.activeHandle = "none";
        Qt.callLater(() => {
            if (modalFocusScope) modalFocusScope.forceActiveFocus();
        });
    }

    content: Component {
        FocusScope {
            id: contentRoot
            focus: true
            implicitWidth: window.modalWidth
            implicitHeight: window.modalHeight

            Image {
                id: bgImage
                source: window.bgImageSource
                visible: false
                cache: false

                Component.onCompleted: {
                    window.bgImageItem = bgImage;
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        if (window.activeCanvas) {
                            window.activeCanvas.loadImage(source);
                        }
                        if (!window.hasSampledContrast) {
                            contrastSampler.requestPaint();
                        }
                    }
                }

            }

            Item {
                id: mainLayout
                anchors.fill: parent

                QuickCaptureToolbar {
                    id: toolbarCard
                    z: 100
                    visible: window.toolbarVisible
                    pluginData: window.parentWidget?.pluginData || ({})

                    anchors.top: window.toolbarPosition === "bottom" ? undefined : parent.top
                    anchors.bottom: window.toolbarPosition === "bottom" ? parent.bottom : undefined
                    anchors.left: window.toolbarPosition === "left" ? parent.left : undefined
                    anchors.right: window.toolbarPosition === "right" ? parent.right : undefined

                    anchors.horizontalCenter: (window.toolbarPosition === "top" || window.toolbarPosition === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (window.toolbarPosition === "left" || window.toolbarPosition === "right") ? parent.verticalCenter : undefined

                    anchors.margins: Theme.spacingM
                    isVertical: (window.toolbarPosition === "left" || window.toolbarPosition === "right")

                    showAnnotations: window.showAnnotations
                    onShowAnnotationsChanged: {
                        if (window.showAnnotations !== toolbarCard.showAnnotations) {
                            window.showAnnotations = toolbarCard.showAnnotations;
                        }
                    }
                    
                    currentTool: window.currentTool
                    currentColor: window.currentColor
                    strokeWidth: window.currentTool === "text" ? window.textFontSize : window.strokeWidth
                    canUndo: window.strokes.length > 0

                    onToolSelected: (tool) => window.currentTool = (tool === "crop" && window.currentTool === "crop") ? window.lastActiveTool : tool
                    onColorSelected: (color) => window.currentColor = color
                    onStrokeWidthSelected: (width) => {
                        if (window.currentTool === "text") {
                            window.textFontSize = width;
                        } else {
                            window.strokeWidth = width;
                        }
                    }
                    onUndoRequested: window.performUndo()
                    onSaveRequested: captureActions.performSaveOnly()
                    onCopyRequested: captureActions.performCopyOnly()
                    onCopyAndSaveRequested: captureActions.performCopyAndSave()
                    onCloseRequested: window.discardAndClose()
                }

                // 2. Centered Canvas Board
                Item {
                    id: boardContainer
                    anchors.top: (window.toolbarVisible && window.toolbarPosition === "top") ? toolbarCard.bottom : parent.top
                    anchors.bottom: (window.toolbarVisible && window.toolbarPosition === "bottom") ? toolbarCard.top : parent.bottom
                    anchors.left: (window.toolbarVisible && window.toolbarPosition === "left") ? toolbarCard.right : parent.left
                    anchors.right: (window.toolbarVisible && window.toolbarPosition === "right") ? toolbarCard.left : parent.right
                    anchors.margins: Theme.spacingM

                    Component.onCompleted: {
                        window.boardContainerItem = boardContainer;
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 0
                    }

                    // Background Image Layer (Hardware Accelerated)
                    Item {
                        id: bgImageLayer
                        anchors.centerIn: parent
                        width: drawingCanvas.width
                        height: drawingCanvas.height
                        scale: drawingCanvas.scale
                        transformOrigin: drawingCanvas.transformOrigin
                        clip: true

                        Image {
                            id: staticBgImage
                            source: window.bgImageSource
                            cache: false
                            smooth: true
                            mipmap: true
                            
                            // Handle crop positioning
                            x: (window.currentTool !== "crop" && window.hasSelection) ? -window.cropRect.x : 0
                            y: (window.currentTool !== "crop" && window.hasSelection) ? -window.cropRect.y : 0
                            
                            // Scale to original size if cropped, otherwise fit to canvas
                            width: (window.currentTool !== "crop" && window.hasSelection) ? window.bgImageItem.sourceSize.width : parent.width
                            height: (window.currentTool !== "crop" && window.hasSelection) ? window.bgImageItem.sourceSize.height : parent.height
                        }
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image

                        width: {
                            if (window.currentTool !== "crop" && window.hasSelection) {
                                return window.cropRect.width;
                            }
                            return window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
                        }
                        height: {
                            if (window.currentTool !== "crop" && window.hasSelection) {
                                return window.cropRect.height;
                            }
                            return window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
                        }

                        layer.enabled: false

                        Component.onCompleted: {
                            window.activeCanvas = drawingCanvas;
                        }

                        onImageLoaded: {
                            drawingCanvas.requestPaint();
                        }

                        onPaint: {
                            var ctx = drawingCanvas.getContext("2d");
                            ctx.clearRect(0, 0, drawingCanvas.width, drawingCanvas.height);

                            // 1. Draw Dimming Selection Overlay (only if in crop mode)
                            if (window.currentTool === "crop") {
                                if (window.cropRect.width > 0 && window.cropRect.height > 0) {
                                    ctx.save();
                                    ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
                                    // Left
                                    ctx.fillRect(0, 0, window.cropRect.x, drawingCanvas.height);
                                    // Right
                                    ctx.fillRect(window.cropRect.x + window.cropRect.width, 0, drawingCanvas.width - (window.cropRect.x + window.cropRect.width), drawingCanvas.height);
                                    // Top
                                    ctx.fillRect(window.cropRect.x, 0, window.cropRect.width, window.cropRect.y);
                                    // Bottom
                                    ctx.fillRect(window.cropRect.x, window.cropRect.y + window.cropRect.height, window.cropRect.width, drawingCanvas.height - (window.cropRect.y + window.cropRect.height));

                                    // Selection border
                                    ctx.strokeStyle = Theme.primary;
                                    ctx.lineWidth = 1.5;
                                    ctx.strokeRect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);

                                    // 4 Corner resize handles
                                    const hs = 10;
                                    const hh = hs / 2;
                                    ctx.fillStyle = Theme.primary;
                                    ctx.strokeStyle = "#ffffff";
                                    ctx.lineWidth = 1.5;

                                    const x1 = window.cropRect.x;
                                    const y1 = window.cropRect.y;
                                    const x2 = window.cropRect.x + window.cropRect.width;
                                    const y2 = window.cropRect.y + window.cropRect.height;

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
                                    ctx.restore();
                                } else {
                                    // Dim full canvas slightly before selection
                                    ctx.fillStyle = "rgba(0, 0, 0, 0.4)";
                                    ctx.fillRect(0, 0, drawingCanvas.width, drawingCanvas.height);
                                }
                            }

                            // 2. Draw annotations (translated in edit mode, or clipped in crop mode)
                            ctx.save();
                            if (window.currentTool !== "crop" && window.hasSelection) {
                                // Shift context so drawings at absolute screen coords display correctly in cropped canvas view
                                ctx.translate(-window.cropRect.x, -window.cropRect.y);
                            } else if (window.hasSelection) {
                                ctx.beginPath();
                                ctx.rect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
                                ctx.clip();
                            }

                            if (window.showAnnotations) {
                                for (var i = 0; i < window.strokes.length; i++) {
                                    drawStroke(ctx, window.strokes[i]);
                                }

                                // 3. Draw current dragging stroke
                                if (window.currentStroke) {
                                    drawStroke(ctx, window.currentStroke);
                                }

                                // 4. Draw temporary live typing text
                                if (window.isTyping) {
                                    ctx.fillStyle = window.currentColor;
                                    
                                    let styleStr = "";
                                    if (window.textItalic) styleStr += "italic ";
                                    if (window.textBold) styleStr += "bold ";
                                    
                                    ctx.font = styleStr + Math.round(window.textFontSize) + "px " + window.textFontFamily;
                                    ctx.textAlign = "left";
                                    ctx.textBaseline = "top";
                                    ctx.fillText(window.currentTypingText + "|", window.typingCoords.x, window.typingCoords.y);

                                    if (window.textUnderline) {
                                        const textWidth = ctx.measureText(window.currentTypingText + "|").width;
                                        ctx.strokeStyle = window.currentColor;
                                        ctx.lineWidth = Math.max(1.5, Math.round(window.textFontSize * 0.08));
                                        ctx.beginPath();
                                        ctx.moveTo(window.typingCoords.x, window.typingCoords.y + window.textFontSize * 1.05);
                                        ctx.lineTo(window.typingCoords.x + textWidth, window.typingCoords.y + window.textFontSize * 1.05);
                                        ctx.stroke();
                                    }
                                }
                            }

                            ctx.restore();

                            // 5. Draw Watermark Preview in Editor
                            const enableWatermark = window.parentWidget?.pluginData?.enableWatermark ?? false;
                            if (enableWatermark && window.currentTool !== "crop") {
                                const watermarkType = window.parentWidget?.pluginData?.watermarkType || "text";
                                const watermarkOpacity = (window.parentWidget?.pluginData?.watermarkOpacity ?? 20) / 100.0;
                                const watermarkPosition = window.parentWidget?.pluginData?.watermarkPosition || "bottom_right";
                                const watermarkSize = (window.parentWidget?.pluginData?.watermarkSize ?? 5) / 100.0;
                                const watermarkTextSize = (window.parentWidget?.pluginData?.watermarkTextSize ?? 5) / 100.0;

                                ctx.save();
                                ctx.globalAlpha = watermarkOpacity;
                                if (watermarkType === "text" || watermarkType === "hybrid") {
                                    const rawText = window.parentWidget?.pluginData?.watermarkText || "© {user}";
                                    const textStr = config.formatWatermarkText(rawText);
                                    const lines = textStr.split("\n");
                                    const fontSize = Math.round(Math.max(12, drawingCanvas.height * watermarkTextSize));
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

                                    const hasImage = (watermarkType === "hybrid" && watermarkImageLoader.status === Image.Ready);
                                    let targetW = 0;
                                    let targetH = 0;
                                    if (hasImage) {
                                        const imgW = watermarkImageLoader.sourceSize.width;
                                        const imgH = watermarkImageLoader.sourceSize.height;
                                        const maxW = drawingCanvas.width * watermarkSize;
                                        const maxH = drawingCanvas.height * watermarkSize;
                                        const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
                                        targetW = imgW * scale;
                                        targetH = imgH * scale;
                                    }

                                    const totalW = (hasImage ? targetW + spacing : 0) + maxTextWidth;
                                    const totalH = Math.max(targetH, totalTextHeight);

                                    let tx = margin;
                                    let ty = fontSize + margin;

                                    if (watermarkPosition === "bottom_right") {
                                        tx = drawingCanvas.width - totalW - margin;
                                        ty = drawingCanvas.height - (lines.length - 1) * lineHeight - margin;
                                    } else if (watermarkPosition === "bottom_left") {
                                        tx = margin;
                                        ty = drawingCanvas.height - (lines.length - 1) * lineHeight - margin;
                                    } else if (watermarkPosition === "top_right") {
                                        tx = drawingCanvas.width - totalW - margin;
                                        ty = fontSize + margin;
                                    } else if (watermarkPosition === "top_left") {
                                        tx = margin;
                                        ty = fontSize + margin;
                                    } else if (watermarkPosition === "center") {
                                        tx = (drawingCanvas.width - totalW) / 2;
                                        ty = (drawingCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                    } else if (watermarkPosition === "top") {
                                        tx = (drawingCanvas.width - totalW) / 2;
                                        ty = fontSize + margin;
                                    } else if (watermarkPosition === "bottom") {
                                        tx = (drawingCanvas.width - totalW) / 2;
                                        ty = drawingCanvas.height - (lines.length - 1) * lineHeight - margin;
                                    } else if (watermarkPosition === "left") {
                                        tx = margin;
                                        ty = (drawingCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                    } else if (watermarkPosition === "right") {
                                        tx = drawingCanvas.width - totalW - margin;
                                        ty = (drawingCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                    }

                                    if (hasImage) {
                                        const iy = ty - fontSize + (totalTextHeight - targetH) / 2;
                                        ctx.drawImage(watermarkImageLoader, tx, iy, targetW, targetH);
                                    }

                                    const textX = tx + (hasImage ? targetW + spacing : 0);
                                    for (let i = 0; i < lines.length; i++) {
                                        ctx.fillText(lines[i], textX, ty + i * lineHeight);
                                    }

                                } else if (watermarkType === "image" && watermarkImageLoader.status === Image.Ready) {
                                    const imgW = watermarkImageLoader.sourceSize.width;
                                    const imgH = watermarkImageLoader.sourceSize.height;
                                    const maxW = drawingCanvas.width * watermarkSize;
                                    const maxH = drawingCanvas.height * watermarkSize;
                                    const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
                                    const targetW = imgW * scale;
                                    const targetH = imgH * scale;

                                    const margin = 20;
                                    let ix = margin;
                                    let iy = margin;

                                    if (watermarkPosition === "bottom_right") {
                                        ix = drawingCanvas.width - targetW - margin;
                                        iy = drawingCanvas.height - targetH - margin;
                                    } else if (watermarkPosition === "bottom_left") {
                                        ix = margin;
                                        iy = drawingCanvas.height - targetH - margin;
                                    } else if (watermarkPosition === "top_right") {
                                        ix = drawingCanvas.width - targetW - margin;
                                        iy = margin;
                                    } else if (watermarkPosition === "top_left") {
                                        ix = margin;
                                        iy = margin;
                                    } else if (watermarkPosition === "center") {
                                        ix = (drawingCanvas.width - targetW) / 2;
                                        iy = (drawingCanvas.height - targetH) / 2;
                                    } else if (watermarkPosition === "top") {
                                        ix = (drawingCanvas.width - targetW) / 2;
                                        iy = margin;
                                    } else if (watermarkPosition === "bottom") {
                                        ix = (drawingCanvas.width - targetW) / 2;
                                        iy = drawingCanvas.height - targetH - margin;
                                    } else if (watermarkPosition === "left") {
                                        ix = margin;
                                        iy = (drawingCanvas.height - targetH) / 2;
                                    } else if (watermarkPosition === "right") {
                                        ix = drawingCanvas.width - targetW - margin;
                                        iy = (drawingCanvas.height - targetH) / 2;
                                    }

                                    ctx.drawImage(watermarkImageLoader, ix, iy, targetW, targetH);
                                }
                                ctx.restore();
                            }
                        }

                        function drawStroke(ctx, stroke) {
                            if (stroke.points.length === 0) return;

                            const rgb = window.hexToRgb(stroke.color);

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
                                ctx.lineCap = window.roundHighlighter ? "round" : "square";
                                ctx.lineJoin = window.roundHighlighter ? "round" : "miter";
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
                                // Adjust radius to be larger than half the stroke width to prevent sharp inner corners
                                const baseRadius = window.roundRect ? (Theme.cornerRadius + (stroke.width / 2)) : 0;
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
                                    
                                    // Shorten shaft so it stops exactly inside the arrowhead base
                                    const shaftLength = Math.max(0, len - headLength * 0.8);
                                    const shaftEndX = p0.x + shaftLength * Math.cos(angle);
                                    const shaftEndY = p0.y + shaftLength * Math.sin(angle);

                                    // Draw shaft
                                    ctx.beginPath();
                                    ctx.moveTo(p0.x, p0.y);
                                    ctx.lineTo(shaftEndX, shaftEndY);
                                    ctx.stroke();

                                    // Draw head
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
                                const radius = window.roundRect ? Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2) : 0;

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

                                        if (window.bgImageItem && window.bgImageItem.status === Image.Ready) {
                                            const blockSize = Math.max(8, Math.min(36, stroke.width * 3));
                                            const sampleSize = Math.max(1, Math.round(blockSize / 5));
                                            const imgW = window.bgImageItem.sourceSize.width;
                                            const imgH = window.bgImageItem.sourceSize.height;
                                            for (let y = ry; y < ry + rh; y += blockSize) {
                                                for (let x = rx; x < rx + rw; x += blockSize) {
                                                    const bw = Math.min(blockSize, rx + rw - x);
                                                    const bh = Math.min(blockSize, ry + rh - y);
                                                    if (bw <= 0 || bh <= 0) continue;
                                                    let sx = Math.min(x + Math.floor(bw / 2), rx + rw - 1);
                                                    let sy = Math.min(y + Math.floor(bh / 2), ry + rh - 1);
                                                    sx = Math.max(0, Math.min(sx, Math.max(0, imgW - sampleSize)));
                                                    sy = Math.max(0, Math.min(sy, Math.max(0, imgH - sampleSize)));
                                                    ctx.drawImage(window.bgImageItem, sx, sy, sampleSize, sampleSize, x, y, bw, bh);
                                                }
                                            }
                                        }

                                        if (stroke === window.currentStroke) {
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
                                const lum = 0.299 * rgb.r + 0.587 * rgb.g + 0.114 * rgb.b;
                                const textColor = lum > 0.5 ? "#000000" : "#ffffff";

                                // Circle backdrop
                                ctx.fillStyle = stroke.color;
                                ctx.beginPath();
                                ctx.arc(pt.x, pt.y, radius, 0, 2 * Math.PI);
                                ctx.fill();

                                // Dynamic contrasting label — measureText for reliable centering across digit counts
                                const fontSize = Math.round(radius * 1.2);
                                const text = String(stroke.counter);
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

                        // Mouse Drawing & Action Capture
                        MouseArea {
                            id: drawMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            function getAbsolutePoint(mx, my) {
                                if (window.currentTool !== "crop" && window.hasSelection) {
                                    return Qt.point(mx + window.cropRect.x, my + window.cropRect.y);
                                }
                                return Qt.point(mx, my);
                            }

                            // Visual cursor feedback based on hover position
                            property string hoveredHandle: "none"
                            property int hoveredStrokeIdx: -1
                            onPositionChanged: (mouse) => {
                                window.cursorX = mouse.x;
                                window.cursorY = mouse.y;
                                hoveredHandle = window.getHoveredHandle(mouse.x, mouse.y);

                                const absPt = getAbsolutePoint(mouse.x, mouse.y);

                                if (window.currentTool === "select") {
                                    if (window.selectedStroke) {
                                        const dx = absPt.x - window.pressCoords.x;
                                        const dy = absPt.y - window.pressCoords.y;
                                        const newPoints = [];
                                        for (let i = 0; i < window.originalPoints.length; i++) {
                                            newPoints.push(Qt.point(window.originalPoints[i].x + dx, window.originalPoints[i].y + dy));
                                        }
                                        window.selectedStroke.points = newPoints;
                                        drawingCanvas.requestPaint();
                                    } else {
                                        hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    }
                                    return;
                                }

                                if (window.currentTool === "crop") {
                                    if (window.activeHandle === "new") {
                                        const x1 = Math.min(window.selectStart.x, mouse.x);
                                        const y1 = Math.min(window.selectStart.y, mouse.y);
                                        const w = Math.abs(mouse.x - window.selectStart.x);
                                        const h = Math.abs(mouse.y - window.selectStart.y);
                                        window.cropRect = Qt.rect(x1, y1, w, h);
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
                                            newX = Math.min(mouse.x, cr.x + cr.width - 10);
                                            newY = Math.min(mouse.y, cr.y + cr.height - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "tr") {
                                            newY = Math.min(mouse.y, cr.y + cr.height - 10);
                                            newW = Math.max(10, mouse.x - cr.x);
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "bl") {
                                            newX = Math.min(mouse.x, cr.x + cr.width - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = Math.max(10, mouse.y - cr.y);
                                        } else if (window.activeHandle === "br") {
                                            newW = Math.max(10, mouse.x - cr.x);
                                            newH = Math.max(10, mouse.y - cr.y);
                                        }

                                        window.cropRect = Qt.rect(newX, newY, newW, newH);
                                        drawingCanvas.requestPaint();
                                        return;
                                    }
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
                                     } else if (window.currentTool === "rect" || window.currentTool === "ellipse" || window.currentTool === "arrow" || window.currentTool === "line"
                                              || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "highlighter") {
                                         
                                         let finalPt = absPt;
                                         if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "line" || window.currentTool === "arrow" || window.currentTool === "highlighter")) {
                                             // Snapping angle calculation (8 directions / 45 degrees)
                                             const p0 = window.currentStroke.points[0];
                                             if (p0) {
                                                 const dx = absPt.x - p0.x;
                                                 const dy = absPt.y - p0.y;
                                                 const L = Math.sqrt(dx * dx + dy * dy);
                                                 if (L > 0) {
                                                     const angle = Math.atan2(dy, dx);
                                                     const snappedAngle = Math.round(angle / (Math.PI / 4)) * (Math.PI / 4);
                                                     finalPt = Qt.point(p0.x + L * Math.cos(snappedAngle), p0.y + L * Math.sin(snappedAngle));
                                                 }
                                             }
                                         } else if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "ellipse" || window.currentTool === "rect" || window.currentTool === "redact" || window.currentTool === "pixelate")) {
                                             if (window.currentStroke.points[0]) {
                                                 finalPt = window.constrainSquarePoint(window.currentStroke.points[0], absPt);
                                             }
                                         }

                                         if (window.currentStroke.points.length > 1) {
                                             window.currentStroke.points[window.currentStroke.points.length - 1] = finalPt;
                                         } else {
                                             window.currentStroke.points.push(finalPt);
                                         }
                                     }
                                    drawingCanvas.requestPaint();
                                }
                            }

                            cursorShape: {
                                if (hoveredHandle === "tl" || hoveredHandle === "br") return Qt.SizeFDiagCursor;
                                if (hoveredHandle === "tr" || hoveredHandle === "bl") return Qt.SizeBDiagCursor;
                                if (window.currentTool === "select") {
                                    return window.selectedStroke ? Qt.ClosedHandCursor : (drawMouseArea.hoveredStrokeIdx !== -1 ? Qt.OpenHandCursor : Qt.ArrowCursor);
                                }
                                if (window.hasSelection && window.isInsideCropRect(mouseX, mouseY)) {
                                    return Qt.CrossCursor;
                                }
                                return Qt.CrossCursor;
                            }

                            onPressed: (mouse) => {
                                if (window.isTyping) {
                                    window.commitTypingText();
                                    return;
                                }

                                if (mouse.button === Qt.RightButton) {
                                    const mapped = drawMouseArea.mapToItem(radialMenu.parent, mouse.x, mouse.y);
                                    radialMenu.open(mapped.x, mapped.y);
                                    return;
                                }

                                if (mouse.button === Qt.MiddleButton) {
                                    const absPt = getAbsolutePoint(mouse.x, mouse.y);
                                    const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    if (strokeIdx !== -1) {
                                        const list = [...window.strokes];
                                        const removed = list.splice(strokeIdx, 1)[0];
                                        window.strokes = list;
                                        if (removed && removed.tool === "stamp" && window.stampCounter > 1) {
                                            window.stampCounter--;
                                        }
                                        drawingCanvas.requestPaint();
                                    }
                                    return;
                                }

                                const absPt = getAbsolutePoint(mouse.x, mouse.y);

                                if (window.currentTool === "select") {
                                    const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    if (strokeIdx !== -1) {
                                        const stroke = window.strokes[strokeIdx];
                                        window.preGrabStrokeWidth = window.strokeWidth;
                                        window.preGrabColor = window.currentColor;
                                        window.strokeWidth = stroke.width;
                                        window.currentColor = stroke.color;
                                        window.selectedStroke = stroke;
                                        window.pressCoords = absPt;
                                        const orig = [];
                                        for (let p of stroke.points) {
                                            orig.push(Qt.point(p.x, p.y));
                                        }
                                        window.originalPoints = orig;
                                    }
                                    return;
                                }

                                if (window.currentTool === "crop") {
                                    const handle = window.getHoveredHandle(mouse.x, mouse.y);
                                    if (handle !== "none") {
                                        window.activeHandle = handle;
                                        return;
                                    }

                                    // Drag-to-select crop area
                                    window.activeHandle = "new";
                                    window.selectStart = Qt.point(mouse.x, mouse.y);
                                    window.cropRect = Qt.rect(mouse.x, mouse.y, 0, 0);
                                    window.hasSelection = false;
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
                                    window.pushStroke({
                                        tool: "stamp",
                                        color: window.currentColor.toString(),
                                        width: window.strokeWidth,
                                        points: [getAbsolutePoint(mouse.x, mouse.y)],
                                        counter: window.stampCounter
                                    });
                                    window.stampCounter++;
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
                                        
                                        let minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity;
                                        for (let p of stroke.points) {
                                            if (p.x < minX) minX = p.x;
                                            if (p.y < minY) minY = p.y;
                                            if (p.x > maxX) maxX = p.x;
                                            if (p.y > maxY) maxY = p.y;
                                        }
                                        
                                        const pad = 12 + stroke.width * 2;
                                        if (sx >= minX - pad && sx <= maxX + pad && sy >= minY - pad && sy <= maxY + pad) {
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

                                // Standard drawing stroke
                                window.currentStroke = {
                                    tool: window.currentTool,
                                    color: window.currentColor.toString(),
                                    width: window.strokeWidth,
                                    points: [getAbsolutePoint(mouse.x, mouse.y)]
                                };
                                drawingCanvas.requestPaint();
                            }

                            onReleased: (mouse) => {
                                if (window.currentTool === "select") {
                                    window.selectedStroke = null;
                                    window.strokeWidth = window.preGrabStrokeWidth;
                                    window.currentColor = window.preGrabColor;
                                    window.originalPoints = [];
                                    drawingCanvas.requestPaint();
                                    return;
                                }

                                if (window.currentTool === "crop") {
                                    if (window.activeHandle === "new" || window.activeHandle === "tl" || window.activeHandle === "tr" || window.activeHandle === "bl" || window.activeHandle === "br") {
                                        if (window.cropRect.width > 10 && window.cropRect.height > 10) {
                                            window.hasSelection = true;
                                            // Automatically enter edit mode with the pen tool once selection is made/resized!
                                            window.currentTool = "pen";
                                        } else {
                                            window.hasSelection = false;
                                            window.cropRect = Qt.rect(0, 0, 0, 0);
                                        }
                                    }
                                    window.activeHandle = "none";
                                    drawingCanvas.requestPaint();
                                    return;
                                }

                                if (!window.currentStroke) return;
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
                                if (window.currentTool === "text") {
                                    window.textFontSize = Math.max(8, Math.min(100, window.textFontSize + (step * 2)));
                                } else {
                                    window.strokeWidth = Math.max(1, Math.min(50, window.strokeWidth + step));
                                }
                                window.previewX = wheel.x;
                                window.previewY = wheel.y;
                                window.showSizePreview = true;
                                previewTimer.restart();
                                wheel.accepted = true;
                            }
                        }

                        Rectangle {
                            id: sizePreviewItem
                            visible: window.showSizePreview
                            x: window.previewX - (width / 2)
                            y: window.previewY - (height / 2)
                            width: {
                                if (window.currentTool === "text") return window.textFontSize;
                                if (window.currentTool === "highlighter") return window.strokeWidth * 4;
                                if (window.currentTool === "stamp") return window.strokeWidth * 10;
                                return window.strokeWidth;
                            }
                            height: width
                            radius: (window.currentTool === "highlighter" || window.currentTool === "pixelate" || window.currentTool === "text") ? 0 : width / 2
                            color: "transparent"
                            border.color: Theme.primary
                            border.width: 1.5
                            z: 20

                            StyledText {
                                anchors.top: parent.bottom
                                anchors.topMargin: 4
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (window.currentTool === "text" ? window.textFontSize : window.strokeWidth) + "px"
                                color: Theme.primary
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        id: canvasBorder
                        x: drawingCanvas.x - 1
                        y: drawingCanvas.y - 1
                        width: drawingCanvas.width + 2
                        height: drawingCanvas.height + 2
                        scale: drawingCanvas.scale
                        transformOrigin: drawingCanvas.transformOrigin
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1.5 / drawingCanvas.scale
                        radius: Theme.cornerRadius / drawingCanvas.scale
                        z: 10
                        visible: config.pluginData["showCanvasBorder"] !== undefined ? config.pluginData["showCanvasBorder"] : true
                    }

                    Item {
                        id: canvasRoundedMask
                        width: drawingCanvas.width
                        height: drawingCanvas.height
                        layer.enabled: true
                        visible: false

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.cornerRadius
                            color: "black"
                        }
                    }
                    Popup {
                        id: textInputDialog
                        width: 320
                        height: 160
                        padding: 0
                        modal: false
                        focus: true
                        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
                        anchors.centerIn: parent

                        background: Rectangle {
                            color: "transparent"
                        }

                        onOpened: {
                            Qt.callLater(() => {
                                textInputField.text = "";
                                textInputField.forceActiveFocus();
                            });
                        }

                        onClosed: {
                            if (window.isTyping) {
                                window.isTyping = false;
                                window.currentTypingText = "";
                                if (window.activeCanvas) window.activeCanvas.requestPaint();
                                modalFocusScope.forceActiveFocus();
                            }
                        }

                        contentItem: Rectangle {
                            color: Theme.surfaceContainer
                            radius: Theme.cornerRadius
                            border.color: Theme.withAlpha(Theme.outline, 0.15)
                            border.width: 1

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.spacingM
                                spacing: Theme.spacingM

                                StyledText {
                                    text: I18n.tr("Add Text Note")
                                    font.bold: true
                                    font.pixelSize: Theme.fontSizeMedium
                                    color: Theme.surfaceText
                                }

                                DankTextField {
                                    id: textInputField
                                    width: parent.width
                                    placeholderText: I18n.tr("Type note...")
                                    focus: true
                                    onAccepted: {
                                        window.currentTypingText = textInputField.text;
                                        textInputDialog.close();
                                        window.commitTypingText();
                                    }
                                }

                                Row {
                                    width: parent.width
                                    spacing: Theme.spacingS
                                    layoutDirection: Qt.RightToLeft

                                    DankButton {
                                        text: I18n.tr("Add")
                                        backgroundColor: Theme.primary
                                        textColor: Theme.primaryText
                                        onClicked: {
                                            window.currentTypingText = textInputField.text;
                                            textInputDialog.close();
                                            window.commitTypingText();
                                        }
                                    }

                                    DankButton {
                                        text: I18n.tr("Cancel")
                                        backgroundColor: Theme.surfaceContainerHigh
                                        textColor: Theme.surfaceText
                                        onClicked: {
                                            textInputDialog.close();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Timer {
                        id: previewTimer
                        interval: 800
                        running: false
                        repeat: false
                        onTriggered: {
                            window.showSizePreview = false;
                        }
                    }

                    Rectangle {
                        id: magnifier
                        width: 140
                        height: 140
                        radius: 70
                        border.color: Theme.primary
                        border.width: 2
                        color: "black"
                        visible: window.enableMagnifier && window.isZoomPressed && drawMouseArea.containsMouse
                        z: 200
                        enabled: false

                        x: drawingCanvas.mapToItem(boardContainer, window.cursorX, window.cursorY).x - (width / 2)
                        y: drawingCanvas.mapToItem(boardContainer, window.cursorX, window.cursorY).y - (height / 2)

                        property real zoomFactor: 1.5

                        clip: true

                        Canvas {
                            id: magnifierCanvas
                            anchors.fill: parent

                            Connections {
                                target: drawingCanvas
                                function onPaint() { magnifierCanvas.requestPaint(); }
                            }

                            Connections {
                                target: window
                                function onCursorXChanged() { magnifierCanvas.requestPaint(); }
                                function onCursorYChanged() { magnifierCanvas.requestPaint(); }
                            }

                            Connections {
                                target: magnifier
                                function onZoomFactorChanged() { magnifierCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = magnifierCanvas.getContext("2d");
                                ctx.clearRect(0, 0, magnifierCanvas.width, magnifierCanvas.height);

                                ctx.save();

                                // Clip to circle shape to match the parent circle magnifier
                                ctx.beginPath();
                                ctx.arc(magnifierCanvas.width / 2, magnifierCanvas.height / 2, magnifierCanvas.width / 2 - 2, 0, 2 * Math.PI);
                                ctx.clip();

                                // Translate center of magnifier to (0,0)
                                ctx.translate(magnifierCanvas.width / 2, magnifierCanvas.height / 2);
                                // Scale zoom factor
                                ctx.scale(magnifier.zoomFactor, magnifier.zoomFactor);
                                // Translate cursor to (0,0)
                                ctx.translate(-window.cursorX, -window.cursorY);

                                // 1. Draw background image
                                if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                                    ctx.drawImage(staticBgImage, 0, 0, drawingCanvas.width, drawingCanvas.height);
                                }

                                // 2. Draw annotations
                                if (window.showAnnotations) {
                                    for (var i = 0; i < window.strokes.length; i++) {
                                        drawingCanvas.drawStroke(ctx, window.strokes[i]);
                                    }
                                    if (window.currentStroke) {
                                        drawingCanvas.drawStroke(ctx, window.currentStroke);
                                    }
                                }

                                ctx.restore();
                            }
                        }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 16
                            height: 1.5
                            color: Theme.primary
                        }
                        Rectangle {
                            anchors.centerIn: parent
                            width: 1.5
                            height: 16
                            color: Theme.primary
                        }
                    }
                }

                Canvas {
                    id: exportCanvas
                    visible: true
                    opacity: 0
                    x: -9999
                    y: -9999
                    z: 0
                    renderTarget: Canvas.Image
                    width: 1
                    height: 1

                    Component.onCompleted: {
                        window.exportCanvasItem = exportCanvas;
                    }

                    onPaint: {
                        var ctx = exportCanvas.getContext("2d");
                        ctx.clearRect(0, 0, exportCanvas.width, exportCanvas.height);
                        ctx.save();
                        ctx.scale(1 / window.dpr, 1 / window.dpr);
                        
                        // 1. Draw the background image first
                        if (bgImage.status === Image.Ready) {
                             if (window.hasSelection) {
                                 // Draw the cropped portion of the raw background
                                 ctx.drawImage(bgImage, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.cropRect.width, window.cropRect.height);
                             } else {
                                 // Fullscreen background
                                 ctx.drawImage(bgImage, 0, 0);
                             }
                        }

                        // 2. Overlay the annotations (drawingCanvas)
                        if (window.activeCanvas) {
                            ctx.drawImage(window.activeCanvas, 0, 0);
                        }

                        // 3. Overlay custom watermark if enabled
                        const enableWatermark = window.parentWidget?.pluginData?.enableWatermark ?? false;
                        if (enableWatermark) {
                              const watermarkType = window.parentWidget?.pluginData?.watermarkType || "text";
                              const watermarkOpacity = (window.parentWidget?.pluginData?.watermarkOpacity ?? 20) / 100.0;
                              const watermarkPosition = window.parentWidget?.pluginData?.watermarkPosition || "bottom_right";
                              const watermarkSize = (window.parentWidget?.pluginData?.watermarkSize ?? 5) / 100.0;
                              const watermarkTextSize = (window.parentWidget?.pluginData?.watermarkTextSize ?? 5) / 100.0;

                             ctx.save();
                             ctx.globalAlpha = watermarkOpacity;
                             if (watermarkType === "text" || watermarkType === "hybrid") {
                                  const rawText = window.parentWidget?.pluginData?.watermarkText || "© {user}";
                                  const textStr = config.formatWatermarkText(rawText);
                                  const lines = textStr.split("\n");
                                  const fontSize = Math.round(Math.max(12, exportCanvas.height * watermarkTextSize));
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

                                  // Check if we have image for hybrid
                                  const hasImage = (watermarkType === "hybrid" && watermarkImageLoader.status === Image.Ready);
                                  let targetW = 0;
                                  let targetH = 0;
                                  if (hasImage) {
                                      const imgW = watermarkImageLoader.sourceSize.width;
                                      const imgH = watermarkImageLoader.sourceSize.height;
                                      const maxW = exportCanvas.width * watermarkSize;
                                      const maxH = exportCanvas.height * watermarkSize;
                                      const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
                                      targetW = imgW * scale;
                                      targetH = imgH * scale;
                                  }

                                  const totalW = (hasImage ? targetW + spacing : 0) + maxTextWidth;
                                  const totalH = Math.max(targetH, totalTextHeight);

                                  let tx = margin;
                                  let ty = fontSize + margin;

                                  if (watermarkPosition === "bottom_right") {
                                      tx = exportCanvas.width - totalW - margin;
                                      ty = exportCanvas.height - (lines.length - 1) * lineHeight - margin;
                                  } else if (watermarkPosition === "bottom_left") {
                                      tx = margin;
                                      ty = exportCanvas.height - (lines.length - 1) * lineHeight - margin;
                                  } else if (watermarkPosition === "top_right") {
                                      tx = exportCanvas.width - totalW - margin;
                                      ty = fontSize + margin;
                                  } else if (watermarkPosition === "top_left") {
                                      tx = margin;
                                      ty = fontSize + margin;
                                  } else if (watermarkPosition === "center") {
                                      tx = (exportCanvas.width - totalW) / 2;
                                      ty = (exportCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                  } else if (watermarkPosition === "top") {
                                      tx = (exportCanvas.width - totalW) / 2;
                                      ty = fontSize + margin;
                                  } else if (watermarkPosition === "bottom") {
                                      tx = (exportCanvas.width - totalW) / 2;
                                      ty = exportCanvas.height - (lines.length - 1) * lineHeight - margin;
                                  } else if (watermarkPosition === "left") {
                                      tx = margin;
                                      ty = (exportCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                  } else if (watermarkPosition === "right") {
                                      tx = exportCanvas.width - totalW - margin;
                                      ty = (exportCanvas.height - totalH) / 2 + fontSize + (totalH - totalTextHeight) / 2;
                                  }

                                  if (hasImage) {
                                      const iy = ty - fontSize + (totalTextHeight - targetH) / 2;
                                      ctx.drawImage(watermarkImageLoader, tx, iy, targetW, targetH);
                                  }

                                  const textX = tx + (hasImage ? targetW + spacing : 0);
                                  for (let i = 0; i < lines.length; i++) {
                                      ctx.fillText(lines[i], textX, ty + i * lineHeight);
                                  }

                             } else if (watermarkType === "image" && watermarkImageLoader.status === Image.Ready) {
                                 const imgW = watermarkImageLoader.sourceSize.width;
                                 const imgH = watermarkImageLoader.sourceSize.height;
                                 const maxW = exportCanvas.width * watermarkSize;
                                 const maxH = exportCanvas.height * watermarkSize;
                                 const scale = Math.min(maxW / imgW, maxH / imgH, 1.0);
                                 const targetW = imgW * scale;
                                 const targetH = imgH * scale;

                                 const margin = 20;
                                 let ix = margin;
                                 let iy = margin;

                                 if (watermarkPosition === "bottom_right") {
                                     ix = exportCanvas.width - targetW - margin;
                                     iy = exportCanvas.height - targetH - margin;
                                 } else if (watermarkPosition === "bottom_left") {
                                     ix = margin;
                                     iy = exportCanvas.height - targetH - margin;
                                 } else if (watermarkPosition === "top_right") {
                                     ix = exportCanvas.width - targetW - margin;
                                     iy = margin;
                                 } else if (watermarkPosition === "top_left") {
                                     ix = margin;
                                     iy = margin;
                                 } else if (watermarkPosition === "center") {
                                     ix = (exportCanvas.width - targetW) / 2;
                                     iy = (exportCanvas.height - targetH) / 2;
                                 } else if (watermarkPosition === "top") {
                                     ix = (exportCanvas.width - targetW) / 2;
                                     iy = margin;
                                 } else if (watermarkPosition === "bottom") {
                                     ix = (exportCanvas.width - targetW) / 2;
                                     iy = exportCanvas.height - targetH - margin;
                                 } else if (watermarkPosition === "left") {
                                     ix = margin;
                                     iy = (exportCanvas.height - targetH) / 2;
                                 } else if (watermarkPosition === "right") {
                                     ix = exportCanvas.width - targetW - margin;
                                     iy = (exportCanvas.height - targetH) / 2;
                                 }

                                 ctx.drawImage(watermarkImageLoader, ix, iy, targetW, targetH);
                            }
                            ctx.restore();
                        }

                        ctx.restore();
                        const format = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.outputFormat) || "png";
                        const tempOut = "/tmp/dms_capture_output." + format;
                        exportCanvas.save(tempOut);

                        if (window.exportCallback) {
                            const cb = window.exportCallback;
                            window.exportCallback = null;
                            Qt.callLater(() => {
                                cb(tempOut);
                            });
                        }
                    }
                }

                RadialMenu {
                    id: radialMenu
                    presets: window.radialPresets
                    hoverTrigger: window.parentWidget?.pluginData?.radialHoverTrigger ?? false
                    hoverDelay: window.parentWidget?.pluginData?.radialHoverDelay ?? 300
                    menuOpacity: (window.parentWidget?.pluginData?.radialMenuOpacity ?? 100) / 100
                    onPresetSelected: (preset) => {
                        window.currentTool = preset.tool;
                        window.currentColor = preset.color;
                        window.strokeWidth = preset.thickness;
                    }
                    onCenterClicked: {
                        window.currentTool = "select";
                    }
                }

                Canvas {
                    id: contrastSampler
                    visible: false
                    width: 1
                    height: 1
                    onPaint: {
                        var ctx = contrastSampler.getContext("2d");
                        ctx.drawImage(bgImage, 0, 0, 1, 1, 0, 0, 1, 1);
                        var imgData = ctx.getImageData(0, 0, 1, 1);
                        if (imgData && imgData.data) {
                            var r = imgData.data[0];
                            var g = imgData.data[1];
                            var b = imgData.data[2];
                            var brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
                            window.isScreenshotDark = (brightness < 0.35);
                            window.hasSampledContrast = true;
                        }
                    }
                }
            }
        }
    }

    function commitTypingText() {
        if (!window.isTyping) return;
        const textStr = window.currentTypingText.trim();
        if (textStr.length > 0) {
            window.pushStroke({
                tool: "text",
                color: window.currentColor.toString(),
                width: window.textFontSize,
                isMonospace: window.textFontFamily === "monospace",
                fontFamily: window.textFontFamily,
                isBold: window.textBold,
                isItalic: window.textItalic,
                isUnderline: window.textUnderline,
                points: [Qt.point(window.typingCoords.x, window.typingCoords.y)],
                text: textStr
            });
        }
        window.currentTypingText = "";
        window.isTyping = false;
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function pushStroke(stroke) {
        const list = [...window.strokes];
        list.push(stroke);
        window.strokes = list;
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function performUndo() {
        if (window.strokes.length > 0) {
            const list = [...window.strokes];
            const last = list.pop();
            window.strokes = list;
            if (last.tool === "stamp" && window.stampCounter > 1) {
                window.stampCounter--;
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    function discardAndClose() {
        window.close();
    }
}
