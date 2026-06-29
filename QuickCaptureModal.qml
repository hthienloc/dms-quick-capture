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
import "components/Helpers.js" as Helpers
import "components/DrawingRenderer.js" as DrawingRenderer
import "components/StrokeProperties.js" as StrokeProps

DankModal {
    id: window

    CaptureConfig { 
        id: config 
        pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})
    }

    Image {
        id: watermarkImageLoader
        
        source: {
            const rawPath = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.watermarkImage) ? window.parentWidget.pluginData.watermarkImage : "";
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
            return "";
        }
        
        visible: false
        cache: true
    }

    layerNamespace: "dms:plugins:quickCapture"
    keepPopoutsOpen: true

    // Parent communication reference
    property var parentWidget: null

    // State Variables
    property string currentTool: "crop" // crop, select, pen, line, arrow, rect, ellipse, text, pixelate, redact, stamp, highlighter, eraser, spotlight, backdrop
    property string lastActiveTool: "pen"
    readonly property real dpr: Screen.devicePixelRatio || 1.0
    onCurrentToolChanged: {
        if (currentTool !== "text" && window.isTyping) {
            window.commitTypingText();
        }
        if (currentTool !== "crop" && currentTool !== "backdrop" && currentTool !== "select") {
            lastActiveTool = currentTool;
        }
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }

    // Backdrop State Variables
    property string backdropMode: "none" // none, solid, gradient
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property int backdropGradientAngle: 45
    property int backdropPadding: 40
    property int backdropCornerRadius: 12
    property int backdropShadowStrength: 50
    property string backdropAspectRatio: "auto" // auto, 1:1, 16:9, 4:3
    property bool hasUserCustomizedBackdrop: false
    property color autoBackdropGradientStart: Theme.primary
    property color autoBackdropGradientEnd: Theme.secondary
    property color autoBackdropSolidColor: Theme.primary

    // Intensity Management
    property int strokeWidth: 8
    property int pixelateIntensity: 8
    property int spotlightIntensity: 50
    property int textFontSize: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textFontSize !== undefined ? window.parentWidget.pluginData.textFontSize : 36
    property int calloutZoom: 150
    property bool calloutDestDragging: false

    readonly property string effectiveTool: (currentTool === "select" && selectedStroke) ? selectedStroke.tool : currentTool
    property int activeIntensity: {
        if (effectiveTool === "text") return textFontSize;
        if (effectiveTool === "pixelate") return pixelateIntensity;
        if (effectiveTool === "spotlight") return spotlightIntensity;
        if (effectiveTool === "callout") return calloutZoom;
        return strokeWidth;
    }

    function updateActiveIntensity(val) {
        if (effectiveTool === "text") textFontSize = val;
        else if (effectiveTool === "pixelate") pixelateIntensity = Math.max(2, Math.min(12, val));
        else if (effectiveTool === "spotlight") spotlightIntensity = Math.max(10, Math.min(95, val));
        else if (effectiveTool === "callout") calloutZoom = Math.max(100, Math.min(500, val));
        else strokeWidth = Math.max(1, Math.min(50, val));

        if (selectedStroke) {
            selectedStroke.width = val;
            const idx = window.strokes.indexOf(selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (currentStroke) {
            currentStroke.width = val;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
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
    property int stampCounter: 1
    property string stampCounterFormat: "numeric" // numeric, alpha, roman
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false


    // --- Proxy Editing Optimization ---
    readonly property real maxEditDimension: {
        const q = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.editQuality) || "1080";
        if (q === "original") return Infinity;
        const val = parseInt(q);
        return (isNaN(val) || val <= 0) ? 1080 : val;
    }
    readonly property real editScale: {
        if (!window.bgImageItem) return 1.0;
        const w = window.bgImageItem.sourceSize.width;
        const h = window.bgImageItem.sourceSize.height;
        const max = Math.max(w, h);
        if (isNaN(max) || max <= 0 || max <= maxEditDimension) return 1.0;
        return maxEditDimension / max;
    }

    readonly property string effectiveBackdropMode: window.currentTool === "crop" ? "none" : window.backdropMode

    readonly property real screenshotWidth: {
        if (window.currentTool !== "crop" && window.hasSelection) {
            return window.cropRect.width;
        }
        return window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
    }
    readonly property real screenshotHeight: {
        if (window.currentTool !== "crop" && window.hasSelection) {
            return window.cropRect.height;
        }
        return window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
    }

    readonly property real canvasWidth: {
        if (window.effectiveBackdropMode === "none") {
            return screenshotWidth;
        }
        const baseW = screenshotWidth + 2 * window.backdropPadding;
        const baseH = screenshotHeight + 2 * window.backdropPadding;
        if (window.backdropAspectRatio === "auto") {
            return baseW;
        }
        if (window.backdropAspectRatio === "1:1") {
            return Math.max(baseW, baseH);
        }
        if (window.backdropAspectRatio === "16:9") {
            const targetRatio = 16 / 9;
            const currentRatio = baseW / baseH;
            if (currentRatio > targetRatio) {
                return baseW;
            } else {
                return baseH * targetRatio;
            }
        }
        if (window.backdropAspectRatio === "4:3") {
            const targetRatio = 4 / 3;
            const currentRatio = baseW / baseH;
            if (currentRatio > targetRatio) {
                return baseW;
            } else {
                return baseH * targetRatio;
            }
        }
        return baseW;
    }

    readonly property real canvasHeight: {
        if (window.effectiveBackdropMode === "none") {
            return screenshotHeight;
        }
        const baseW = screenshotWidth + 2 * window.backdropPadding;
        const baseH = screenshotHeight + 2 * window.backdropPadding;
        if (window.backdropAspectRatio === "auto") {
            return baseH;
        }
        if (window.backdropAspectRatio === "1:1") {
            return Math.max(baseW, baseH);
        }
        if (window.backdropAspectRatio === "16:9") {
            const targetRatio = 16 / 9;
            const currentRatio = baseW / baseH;
            if (currentRatio > targetRatio) {
                return baseW / targetRatio;
            } else {
                return baseH;
            }
        }
        if (window.backdropAspectRatio === "4:3") {
            const targetRatio = 4 / 3;
            const currentRatio = baseW / baseH;
            if (currentRatio > targetRatio) {
                return baseW / targetRatio;
            } else {
                return baseH;
            }
        }
        return baseH;
    }

    readonly property real backdropScaleFactor: 1.0

    readonly property real screenshotXOffset: window.effectiveBackdropMode === "none" ? 0 : (canvasWidth - screenshotWidth) / 2
    readonly property real screenshotYOffset: window.effectiveBackdropMode === "none" ? 0 : (canvasHeight - screenshotHeight) / 2

    function drawBackdropBackground(ctx, w, h) {
        if (window.backdropMode === "solid") {
            ctx.fillStyle = window.backdropSolidColor.toString();
            ctx.fillRect(0, 0, w, h);
        } else if (window.backdropMode === "gradient") {
            const angleRad = (window.backdropGradientAngle * Math.PI) / 180;
            const x1 = w / 2 - Math.cos(angleRad) * w / 2;
            const y1 = h / 2 - Math.sin(angleRad) * h / 2;
            const x2 = w / 2 + Math.cos(angleRad) * w / 2;
            const y2 = h / 2 + Math.sin(angleRad) * h / 2;
            const grad = ctx.createLinearGradient(x1, y1, x2, y2);
            grad.addColorStop(0, window.backdropGradientStart.toString());
            grad.addColorStop(1, window.backdropGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        }
    }

    function drawScreenshotShadow(ctx) {
        if (window.backdropShadowStrength <= 0) return;
        ctx.save();
        const r = window.backdropCornerRadius * window.backdropScaleFactor;
        const x = window.screenshotXOffset;
        const y = window.screenshotYOffset;
        const w = window.screenshotWidth * window.backdropScaleFactor;
        const h = window.screenshotHeight * window.backdropScaleFactor;
        
        const opacity = (window.backdropShadowStrength / 100.0) * 0.45;
        
        // Draw 4 concentric shadow layers for a soft, fast shadow effect without Gaussian blur CPU cost
        for (let i = 1; i <= 4; i++) {
            ctx.fillStyle = "rgba(0, 0, 0, " + (opacity / i) + ")";
            const offset = i * 3.5;
            const blur = i * 5;
            
            const sx = x - blur/2;
            const sy = y - blur/2 + offset;
            const sw = w + blur;
            const sh = h + blur;
            const sr = r + blur/2;
            
            ctx.beginPath();
            if (sr > 0) {
                ctx.moveTo(sx + sr, sy);
                ctx.lineTo(sx + sw - sr, sy);
                ctx.arcTo(sx + sw, sy, sx + sw, sy + sr, sr);
                ctx.lineTo(sx + sw, sy + sh - sr);
                ctx.arcTo(sx + sw, sy + sh, sx + sw - sr, sy + sh, sr);
                ctx.lineTo(sx + sr, sy + sh);
                ctx.arcTo(sx, sy + sh, sx, sy + sh - sr, sr);
                ctx.lineTo(sx, sy + sr);
                ctx.arcTo(sx, sy, sx + sr, sy, sr);
            } else {
                ctx.rect(sx, sy, sw, sh);
            }
            ctx.closePath();
            ctx.fill();
        }
        ctx.restore();
    }

    function drawScreenshotImage(ctx, imgSource) {
        if (!imgSource || imgSource.status !== Image.Ready) return;
        ctx.save();
        ctx.imageSmoothingEnabled = true;
        if (ctx.imageSmoothingQuality !== undefined) {
            ctx.imageSmoothingQuality = "high";
        }
        
        const r = window.backdropCornerRadius * window.backdropScaleFactor;
        const x = window.screenshotXOffset;
        const y = window.screenshotYOffset;
        const w = window.screenshotWidth * window.backdropScaleFactor;
        const h = window.screenshotHeight * window.backdropScaleFactor;
        
        ctx.beginPath();
        if (r > 0) {
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.arcTo(x + w, y, x + w, y + r, r);
            ctx.lineTo(x + w, y + h - r);
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
            ctx.lineTo(x + r, y + h);
            ctx.arcTo(x, y + h, x, y + h - r, r);
            ctx.lineTo(x, y + r);
            ctx.arcTo(x, y, x + r, y, r);
        } else {
            ctx.rect(x, y, w, h);
        }
        ctx.closePath();
        ctx.clip();
        
        if (window.hasSelection) {
            ctx.drawImage(imgSource, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, x, y, w, h);
        } else {
            ctx.drawImage(imgSource, x, y, w, h);
        }
        ctx.restore();
    }

    property bool isZoomPressed: false
    property real cursorX: 0
    property real cursorY: 0
    readonly property real boardCursorX: boardContainerItem ? (boardContainerItem.width / 2 + (cursorX - canvasWidth / 2) * fitScale) : 0
    readonly property real boardCursorY: boardContainerItem ? (boardContainerItem.height / 2 + (cursorY - canvasHeight / 2) * fitScale) : 0

    property bool showAnnotations: true
    onShowAnnotationsChanged: {
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }
    property var copiedStroke: null

    property var strokes: []
    readonly property bool hasSpotlights: {
        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool === "spotlight") return true;
        }
        return false;
    }
    property var currentStroke: null
    property var selectedStroke: null
    property int preGrabStrokeWidth: 8
    property int preGrabTextFontSize: 36
    property int preGrabPixelateIntensity: 8
    property int preGrabSpotlightIntensity: 50
    property int preGrabCalloutZoom: 150
    property color preGrabColor: Theme.primary
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

    // Text Input Management
    property bool isTyping: false
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""

    // Helper to decode hex color to RGB
    function hexToRgb(hex) { return Helpers.hexToRgb(hex, Qt); }

    backgroundOpacity: (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.modalOpacity !== undefined ? window.parentWidget.pluginData.modalOpacity : 60) / 100
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

    readonly property bool textMonospace: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textMonospace !== undefined ? window.parentWidget.pluginData.textMonospace : false
    
    // Rich Text Options
    property bool textBold: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textBold !== undefined ? window.parentWidget.pluginData.textBold : false
    onTextBoldChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textItalic: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textItalic !== undefined ? window.parentWidget.pluginData.textItalic : false
    onTextItalicChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textUnderline: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textUnderline !== undefined ? window.parentWidget.pluginData.textUnderline : false
    onTextUnderlineChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textBackground: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textBackground !== undefined ? window.parentWidget.pluginData.textBackground : false
    onTextBackgroundChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int textCornerRadius: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textCornerRadius !== undefined ? window.parentWidget.pluginData.textCornerRadius : 8
    onTextCornerRadiusChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string textFontFamily: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textFontFamily !== undefined ? window.parentWidget.pluginData.textFontFamily : (textMonospace ? "monospace" : "sans-serif")
    onTextFontFamilyChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    readonly property string textInputMode: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textInputMode !== undefined ? window.parentWidget.pluginData.textInputMode : "inline"
    readonly property string toolbarPosition: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.toolbarPosition !== undefined ? window.parentWidget.pluginData.toolbarPosition : "top"
    readonly property bool configShowToolbar: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.showToolbar !== undefined ? window.parentWidget.pluginData.showToolbar : true
    readonly property bool enableMagnifier: true
    property bool toolbarVisible: true
    onConfigShowToolbarChanged: {
        window.toolbarVisible = window.configShowToolbar;
    }

    function openCentered() {
        open();
    }

    function rotateScreenshot() {
        const originalW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const originalH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;

        let bgPath = "/tmp/dms_capture_bg.png";
        if (window.bgImageSource) {
            let srcStr = window.bgImageSource.toString();
            const qIdx = srcStr.indexOf("?");
            if (qIdx !== -1) {
                srcStr = srcStr.substring(0, qIdx);
            }
            if (srcStr.startsWith("file://")) {
                bgPath = srcStr.substring(7);
            } else if (srcStr.startsWith("/")) {
                bgPath = srcStr;
            }
        }

        Proc.runCommand("rotate-image", ["mogrify", "-rotate", "90", bgPath], (stdout, exitCode) => {
            if (exitCode === 0) {
                if (window.hasSelection) {
                    const cx = window.cropRect.x;
                    const cy = window.cropRect.y;
                    const cw = window.cropRect.width;
                    const ch = window.cropRect.height;
                    window.cropRect = Qt.rect(originalH - (cy + ch), cx, ch, cw);
                }

                const list = [...window.strokes];
                for (let s of list) {
                    if (s.points) {
                        s.points = s.points.map(p => ({
                            x: originalH - p.y,
                            y: p.x
                        }));
                    }
                }
                window.strokes = list;

                window.bgImageSource = "";
                window.bgImageSource = "file://" + bgPath + "?t=" + Date.now();
            }
        });
    }

    function mirrorScreenshot() {
        const originalW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;

        let bgPath = "/tmp/dms_capture_bg.png";
        if (window.bgImageSource) {
            let srcStr = window.bgImageSource.toString();
            const qIdx = srcStr.indexOf("?");
            if (qIdx !== -1) {
                srcStr = srcStr.substring(0, qIdx);
            }
            if (srcStr.startsWith("file://")) {
                bgPath = srcStr.substring(7);
            } else if (srcStr.startsWith("/")) {
                bgPath = srcStr;
            }
        }

        Proc.runCommand("mirror-image", ["mogrify", "-flop", bgPath], (stdout, exitCode) => {
            if (exitCode === 0) {
                if (window.hasSelection) {
                    const cx = window.cropRect.x;
                    const cy = window.cropRect.y;
                    const cw = window.cropRect.width;
                    const ch = window.cropRect.height;
                    window.cropRect = Qt.rect(originalW - (cx + cw), cy, cw, ch);
                }

                const list = [...window.strokes];
                for (let s of list) {
                    if (s.points) {
                        s.points = s.points.map(p => ({
                            x: originalW - p.x,
                            y: p.y
                        }));
                    }
                }
                window.strokes = list;

                window.bgImageSource = "";
                window.bgImageSource = "file://" + bgPath + "?t=" + Date.now();
            }
        });
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

    // Radial Menu Presets & History
    property var radialPresets: []
    property var presetHistory: []

    function recordPresetUsage(preset) {
        if (!preset) return;
        let history = [...window.presetHistory];
        
        // Find if preset (tool+color+thickness) is already in history and remove it
        const matchIdx = history.findIndex(p => 
            p.tool === preset.tool && 
            p.color.toString() === preset.color.toString() && 
            p.thickness === preset.thickness
        );
        if (matchIdx !== -1) history.splice(matchIdx, 1);
        
        // Add current to front
        history.unshift({
            tool: preset.tool,
            color: preset.color,
            thickness: preset.thickness
        });
        
        // Keep only latest 2 for toggling
        if (history.length > 2) history = history.slice(0, 2);
        window.presetHistory = history;
    }

    function performPasteAction() {
        if (!window.copiedStroke) return;

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
            points: newPoints
        };
        StrokeProps.copyStrokeProperties(window.copiedStroke, pasted);
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
    }

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
        const targetW = window.canvasWidth;
        const targetH = window.canvasHeight;
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

    readonly property bool roundRect: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundRect !== undefined ? window.parentWidget.pluginData.roundRect : true
    readonly property bool roundHighlighter: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundHighlighter !== undefined ? window.parentWidget.pluginData.roundHighlighter : false
    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property var exportCallback: null

    QuickCaptureActions {
        id: captureActions
        parentWidget: window.parentWidget
        modal: window
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
        return Helpers.isInsideCropRect(mx, my, window.hasSelection, window.cropRect);
    }

    function constrainSquarePoint(start, point) {
        return Helpers.constrainSquarePoint(start, point, Qt);
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
            } else if (stroke.tool === "rect" || stroke.tool === "redact" || stroke.tool === "pixelate" || stroke.tool === "spotlight") {
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
            } else if (stroke.tool === "callout" && stroke.points.length === 4) {
                const srcP0 = stroke.points[0];
                const srcP1 = stroke.points[1];
                const dstP0 = stroke.points[2];
                const dstP1 = stroke.points[3];
                if ((mx >= srcP0.x - 5 && mx <= srcP1.x + 5 && my >= srcP0.y - 5 && my <= srcP1.y + 5) ||
                    (mx >= dstP0.x - 5 && mx <= dstP1.x + 5 && my >= dstP0.y - 5 && my <= dstP1.y + 5)) {
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
            window.exportCanvasItem.width = window.canvasWidth / window.dpr;
            window.exportCanvasItem.height = window.canvasHeight / window.dpr;
        }
        window.exportCanvasItem.requestPaint();
    }

    function shortcutToken(key) { return Helpers.shortcutToken(key, Qt); }

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
                // Duplicate: Copy then Paste
                window.copiedStroke = {
                    tool: window.selectedStroke.tool,
                    color: window.selectedStroke.color.toString(),
                    width: window.selectedStroke.width,
                    points: window.selectedStroke.points.map(p => Qt.point(p.x, p.y))
                };
                StrokeProps.copyStrokeProperties(window.selectedStroke, window.copiedStroke);
                window.performPasteAction();
                event.accepted = true;
                return;
            } else if (window.copiedStroke) {
                // Just Paste
                window.performPasteAction();
                event.accepted = true;
                return;
            }
        }

        if (token === "V" && !hasCtrl) {
            window.currentTool = "select";
            event.accepted = true;
            return;
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
            if (window.currentTool === toolShortcut.tool) {
                if (toolShortcut.tool === "backdrop" || toolShortcut.tool === "crop") {
                    window.currentTool = window.lastActiveTool;
                }
            } else {
                window.currentTool = toolShortcut.tool;
            }
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
            if (window.currentTool === "select") {
                window.currentTool = window.lastActiveTool;
            } else if (window.currentTool === window.lastActiveTool) {
                window.currentTool = "select";
            } else if (window.presetHistory.length >= 2) {
                const current = { 
                    tool: window.currentTool, 
                    color: window.currentColor.toString(), 
                    thickness: window.strokeWidth 
                };
                const p0 = window.presetHistory[0];
                const p1 = window.presetHistory[1];
                
                // Compare with history[0] to toggle
                const isP0 = current.tool === p0.tool && 
                             current.color.toString() === p0.color.toString() && 
                             current.thickness === p0.thickness;
                
                const target = isP0 ? p1 : p0;
                window.currentTool = target.tool;
                window.currentColor = target.color;
                window.strokeWidth = target.thickness;
                
                // Update history so the new current is at the top
                window.recordPresetUsage(target);
            } else {
                window.currentTool = "select";
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_G) {
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
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_G) {
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

        const defaultToolMode = config.pluginData.defaultToolMode || "preset";
        if (defaultToolMode === "preset") {
            const presetIdxRaw = config.pluginData.defaultPresetIndex || "0";
            const presetIdx = parseInt(presetIdxRaw, 10);
            const t = config.pluginData["preset_" + presetIdx + "_tool"];
            if (t && t !== "none") {
                startTool = t;
                const rawColor = config.pluginData["preset_" + presetIdx + "_color"] || Theme.primary;
                startColor = config.resolveColor(rawColor);
                startThickness = config.pluginData["preset_" + presetIdx + "_thickness"] || 6;
            } else {
                startTool = config.pluginData.defaultTool || "pen";
                startThickness = config.pluginData.defaultThickness || 6;
            }
        } else {
            startTool = config.pluginData.defaultTool || "pen";
            startThickness = config.pluginData.defaultThickness || 6;
        }

        window.currentTool = startTool;
        window.toolbarVisible = window.configShowToolbar;
        window.strokeWidth = startThickness;
        window.currentColor = startColor;
        window.recordPresetUsage({ tool: startTool, color: startColor, thickness: startThickness });

        window.strokes = [];
        window.stampCounter = 1;
        window.bgImageSource = "";
        window.bgImageSource = "file:///tmp/dms_capture_bg.png";
        window.isScreenshotDark = false;
        window.hasSampledContrast = false;
        window.hasUserCustomizedBackdrop = false;
        window.cropRect = Qt.rect(0, 0, 0, 0);
        window.hasSelection = false;
        window.activeHandle = "none";

        if (window.parentWidget && window.parentWidget.restoringFromFloat) {
            Proc.runCommand("read-strokes", ["cat", "/tmp/dms_capture_strokes.json"], (stdout, exitCode) => {
                if (exitCode === 0 && stdout) {
                    try {
                        let data = JSON.parse(stdout);
                        if (data && data.strokes) {
                            let restoredStrokes = [];
                            for (let i = 0; i < data.strokes.length; i++) {
                                let s = data.strokes[i];
                                let stroke = {
                                    tool: s.tool,
                                    color: s.color,
                                    width: s.width,
                                    points: []
                                };
                                if (s.points) {
                                    for (let j = 0; j < s.points.length; j++) {
                                        stroke.points.push(Qt.point(s.points[j].x, s.points[j].y));
                                    }
                                }
                                StrokeProps.copyStrokeProperties(s, stroke);
                                restoredStrokes.push(stroke);
                            }
                            window.strokes = restoredStrokes;
                        }
                        if (data && data.stampCounter !== undefined) {
                            window.stampCounter = data.stampCounter;
                        }
                        if (data && data.cropRect) {
                            window.cropRect = Qt.rect(data.cropRect.x, data.cropRect.y, data.cropRect.width, data.cropRect.height);
                            window.hasSelection = (data.cropRect.width > 0 && data.cropRect.height > 0);
                        }
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    } catch (e) {
                        console.error("Failed to parse strokes json:", e);
                    }
                }
                // Cleanup sidecar immediately
                Proc.runCommand("clean-strokes", ["rm", "-f", "/tmp/dms_capture_strokes.json"]);
                if (window.parentWidget) {
                    window.parentWidget.restoringFromFloat = false;
                }
            });
        } else {
            // Delete sidecar just in case it exists from a previous float that was closed
            Proc.runCommand("clean-strokes", ["rm", "-f", "/tmp/dms_capture_strokes.json"]);
        }

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
                smooth: true
                mipmap: true

                Component.onCompleted: {
                    window.bgImageItem = bgImage;
                }

                onStatusChanged: {
                    if (status === Image.Ready) {
                        window.hasSampledContrast = false;
                        if (window.activeCanvas) {
                            window.activeCanvas.unloadImage(source);
                            window.activeCanvas.loadImage(source);
                        }
                        contrastSampler.requestPaint();
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
                    pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})

                    anchors.top: window.toolbarPosition === "bottom" ? undefined : parent.top
                    anchors.bottom: window.toolbarPosition === "bottom" ? parent.bottom : undefined
                    anchors.left: window.toolbarPosition === "left" ? parent.left : undefined
                    anchors.right: window.toolbarPosition === "right" ? parent.right : undefined

                    anchors.horizontalCenter: (window.toolbarPosition === "top" || window.toolbarPosition === "bottom") ? parent.horizontalCenter : undefined
                    anchors.verticalCenter: (window.toolbarPosition === "left" || window.toolbarPosition === "right") ? parent.verticalCenter : undefined

                    anchors.margins: Theme.spacingM
                    isVertical: (window.toolbarPosition === "left" || window.toolbarPosition === "right")

                    showAnnotations: window.showAnnotations

                    currentTool: window.currentTool
                    activeToolType: window.effectiveTool
                    currentColor: window.currentColor

                    strokeWidth: window.activeIntensity
                    canUndo: window.strokes.length > 0

                    backdropMode: window.backdropMode
                    backdropSolidColor: window.backdropSolidColor
                    backdropGradientStart: window.backdropGradientStart
                    backdropGradientEnd: window.backdropGradientEnd
                    backdropGradientAngle: window.backdropGradientAngle
                    backdropPadding: window.backdropPadding
                    backdropCornerRadius: window.backdropCornerRadius
                    backdropShadowStrength: window.backdropShadowStrength
                    backdropAspectRatio: window.backdropAspectRatio

                    onChangeBackdropMode: (mode) => {
                        window.backdropMode = mode;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropSolidColor: (col) => {
                        window.backdropSolidColor = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropGradientStart: (col) => {
                        window.backdropGradientStart = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropGradientEnd: (col) => {
                        window.backdropGradientEnd = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropGradientAngle: (angle) => {
                        window.backdropGradientAngle = angle;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropPadding: (pad) => {
                        window.backdropPadding = pad;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropCornerRadius: (r) => {
                        window.backdropCornerRadius = r;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropShadowStrength: (s) => {
                        window.backdropShadowStrength = s;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropAspectRatio: (ratio) => {
                        window.backdropAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onAutoColorBalanceRequested: {
                        window.backdropGradientStart = window.autoBackdropGradientStart;
                        window.backdropGradientEnd = window.autoBackdropGradientEnd;
                        window.backdropSolidColor = window.autoBackdropSolidColor;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }

                    onToolSelected: (tool) => {
                        moreToolsMenu.close();
                        if (tool === "back") {
                            window.currentTool = window.lastActiveTool;
                        } else if (tool === "crop" && window.currentTool === "crop") {
                            window.currentTool = window.lastActiveTool;
                        } else {
                            window.currentTool = tool;
                        }
                    }
                    onColorSelected: (color) => {
                        moreToolsMenu.close();
                        window.currentColor = color;
                    }
                    onStrokeWidthSelected: (width) => {
                        moreToolsMenu.close();
                        window.updateActiveIntensity(width);
                    }
                    onUndoRequested: {
                        moreToolsMenu.close();
                        window.performUndo();
                    }
                    onAnnotationsToggled: window.showAnnotations = !window.showAnnotations

                    onFloatRequested: {
                        moreToolsMenu.close();
                        captureActions.performFloatAction();
                    }
                    onSaveRequested: {
                        moreToolsMenu.close();
                        captureActions.performSaveOnly();
                    }

                    onCopyRequested: {
                        moreToolsMenu.close();
                        captureActions.performCopyOnly();
                    }
                    onCopyAndSaveRequested: {
                        moreToolsMenu.close();
                        captureActions.performCopyAndSave();
                    }
                    onCloseRequested: {
                        moreToolsMenu.close();
                        window.discardAndClose();
                    }
                    onTextToolRightClicked: (globalX, globalY) => {
                        moreToolsMenu.close();
                        textOptionsRadialMenu.open(globalX, globalY);
                    }
                    onStampToolRightClicked: (globalX, globalY) => {
                        moreToolsMenu.close();
                        stampOptionsRadialMenu.open(globalX, globalY);
                    }
                    onMoreToolsClicked: (buttonItem) => {
                        if (moreToolsMenu.opened) {
                            moreToolsMenu.close();
                        } else {
                            var pt = buttonItem.mapToItem(contentRoot, 0, 0);
                            if (toolbarCard.isVertical) {
                                moreToolsMenu.x = pt.x + buttonItem.width + Theme.spacingS;
                                moreToolsMenu.y = pt.y;
                            } else {
                                moreToolsMenu.x = pt.x;
                                moreToolsMenu.y = pt.y + buttonItem.height + Theme.spacingS;
                            }
                            moreToolsMenu.open();
                        }
                    }
                    onBackdropControlHovered: (type, controlItem) => {
                        var pt = controlItem.mapToItem(contentRoot, 0, 0);
                        var popover;
                        if (type === "padding") popover = backdropPaddingPopover;
                        else if (type === "radius") popover = backdropRadiusPopover;
                        else if (type === "shadow") popover = backdropShadowPopover;
                        else if (type === "angle") popover = backdropAnglePopover;

                        if (popover) {
                            if (toolbarCard.isVertical) {
                                if (window.toolbarPosition === "right") {
                                    popover.x = pt.x - popover.width - Theme.spacingXS;
                                } else {
                                    popover.x = pt.x + controlItem.width + Theme.spacingXS;
                                }
                                popover.y = pt.y + (controlItem.height - popover.height) / 2;
                            } else {
                                popover.x = pt.x + (controlItem.width - popover.width) / 2;
                                if (window.toolbarPosition === "bottom") {
                                    popover.y = pt.y - popover.height - Theme.spacingXS;
                                } else {
                                    popover.y = pt.y + controlItem.height + Theme.spacingXS;
                                }
                            }
                            popover.open();
                        }
                    }
                    onBackdropControlExited: (type) => {
                        var popover;
                        if (type === "padding") popover = backdropPaddingPopover;
                        else if (type === "radius") popover = backdropRadiusPopover;
                        else if (type === "shadow") popover = backdropShadowPopover;
                        else if (type === "angle") popover = backdropAnglePopover;

                        if (popover) {
                            popover.startCloseTimer();
                        }
                    }
                    onBackdropControlWheel: (type, delta) => {
                        let step = delta > 0 ? 5 : -5;
                        if (type === "padding") {
                            window.backdropPadding = Math.max(10, Math.min(150, window.backdropPadding + step));
                        } else if (type === "radius") {
                            let rStep = delta > 0 ? 2 : -2;
                            window.backdropCornerRadius = Math.max(0, Math.min(60, window.backdropCornerRadius + rStep));
                        } else if (type === "shadow") {
                            window.backdropShadowStrength = Math.max(0, Math.min(100, window.backdropShadowStrength + step));
                        } else if (type === "angle") {
                            let aStep = delta > 0 ? 15 : -15;
                            window.backdropGradientAngle = (window.backdropGradientAngle + aStep + 360) % 360;
                        }
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
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
                        visible: window.effectiveBackdropMode === "none"

                        Image {
                            id: staticBgImage
                            source: window.bgImageSource
                            cache: false
                            smooth: true
                            mipmap: true
                            
                            // Handle crop positioning
                            x: (window.currentTool !== "crop" && window.hasSelection) ? -window.cropRect.x * window.editScale : 0
                            y: (window.currentTool !== "crop" && window.hasSelection) ? -window.cropRect.y * window.editScale : 0
                            
                            // Scale to original size if cropped, otherwise fit to canvas
                            width: (window.currentTool !== "crop" && window.hasSelection) ? window.bgImageItem.sourceSize.width * window.editScale : parent.width
                            height: (window.currentTool !== "crop" && window.hasSelection) ? window.bgImageItem.sourceSize.height * window.editScale : parent.height
                        }
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image

                        width: window.canvasWidth * window.editScale
                        height: window.canvasHeight * window.editScale

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
                            ctx.save();
                            ctx.scale(window.editScale, window.editScale);

                            // 0. Paint Backdrop (if active)
                            const isBackdropActive = window.effectiveBackdropMode !== "none";
                            if (isBackdropActive) {
                                window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
                                window.drawScreenshotShadow(ctx);
                                window.drawScreenshotImage(ctx, bgImage);
                            }

                            // 1. Draw Dimming Selection Overlay (only if in crop mode)
                            DrawingRenderer.drawSelectionOverlay(ctx, {
                                isCropMode: window.currentTool === "crop",
                                cropRect: window.cropRect,
                                canvasWidth: window.canvasWidth,
                                canvasHeight: window.canvasHeight
                            }, Theme);

                            // 2. Draw annotations (translated in edit mode, or clipped in crop mode)
                            ctx.save();
                            const hasCropSelection = window.currentTool !== "crop" && window.hasSelection;
                            if (isBackdropActive || hasCropSelection) {
                                const cropX = hasCropSelection ? window.cropRect.x : 0;
                                const cropY = hasCropSelection ? window.cropRect.y : 0;
                                ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
                                if (isBackdropActive) {
                                    ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
                                }
                                ctx.translate(-cropX, -cropY);
                            } else if (window.hasSelection) {
                                ctx.beginPath();
                                ctx.rect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
                                ctx.clip();
                            }

                            if (window.showAnnotations) {
                                // 2.05 Draw Pixelate strokes BEFORE dimming layer
                                // This ensures they get dimmed if they are outside a spotlight
                                for (let i = 0; i < window.strokes.length; i++) {
                                    if (window.strokes[i].tool === "pixelate") {
                                        drawStroke(ctx, window.strokes[i]);
                                    }
                                }
                                if (window.currentStroke && window.currentStroke.tool === "pixelate") {
                                    const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
                                    drawStroke(ctx, tempStroke);
                                }

                                // 2.1 Draw Spotlight Layer (Dimming + Holes)
                                const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
                                if (window.hasSpotlights || isDrawingSpotlight) {
                                    const spotlights = window.strokes.filter(s => s.tool === "spotlight");
                                    if (isDrawingSpotlight) {
                                        spotlights.push(window.currentStroke);
                                    }

                                    if (spotlights.length > 0) {
                                        ctx.save();
                                        
                                        // Determine which intensity to use for the global dimming opacity
                                        let activeInt = window.spotlightIntensity;
                                        if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "spotlight") {
                                            activeInt = window.selectedStroke.width;
                                        } else {
                                            const lastSpotlight = window.strokes.slice().reverse().find(s => s.tool === "spotlight");
                                            if (lastSpotlight) activeInt = lastSpotlight.width;
                                        }

                                        const spotlightOpacity = activeInt / 100.0;
                                        
                                        const dimmingX = 0;
                                        const dimmingY = 0;
                                        const dimmingW = window.screenshotWidth;
                                        const dimmingH = window.screenshotHeight;

                                        ctx.beginPath();
                                        // Outer rectangle covering the whole view
                                        ctx.rect(dimmingX, dimmingY, dimmingW, dimmingH);
                                        
                                        for (let s of spotlights) {
                                            if (s.points.length >= 2) {
                                                const p0 = s.points[0];
                                                const p1 = s.points[s.points.length - 1];
                                                const rx = Math.min(p0.x, p1.x);
                                                const ry = Math.min(p0.y, p1.y);
                                                const rw = Math.abs(p1.x - p0.x);
                                                const rh = Math.abs(p1.y - p0.y);
                                                
                                                if (rw > 0 && rh > 0) {
                                                    const radius = window.roundRect ? Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2) : 0;
                                                    if (radius > 0) {
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
                                                        ctx.rect(rx, ry, rw, rh);
                                                    }
                                                }
                                            }
                                        }
                                        
                                        ctx.clip("evenodd");
                                        ctx.fillStyle = "rgba(0, 0, 0, " + spotlightOpacity + ")";
                                        ctx.fillRect(0, 0, window.screenshotWidth, window.screenshotHeight);
                                        ctx.restore();
                                    }
                                }

                                for (var i = 0; i < window.strokes.length; i++) {
                                    if (window.strokes[i].tool !== "spotlight" && window.strokes[i].tool !== "pixelate") {
                                        drawStroke(ctx, window.strokes[i]);
                                    }
                                }

                                // 3. Draw current dragging stroke
                                if (window.currentStroke && window.currentStroke.tool !== "spotlight" && window.currentStroke.tool !== "pixelate") {
                                    const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
                                    drawStroke(ctx, tempStroke);
                                }

                                // 4. Draw temporary live typing text
                                if (window.isTyping) {
                                    ctx.fillStyle = window.currentColor;
                                    
                                    let styleStr = "";
                                    if (window.textItalic) styleStr += "italic ";
                                    if (window.textBold) styleStr += "bold ";
                                    
                                    ctx.font = styleStr + Math.round(window.textFontSize) + "px " + window.textFontFamily;
                                    ctx.textAlign = "left";
                                    ctx.textBaseline = "middle";

                                    if (window.textBackground) {
                                        const textMetrics = ctx.measureText(window.currentTypingText + "|");
                                        const textWidth = textMetrics.width;
                                        const h = window.textFontSize;
                                        const padX = h * 0.3;
                                        const padY = h * 0.15; // Further reduced vertical padding
                                        const rx = window.typingCoords.x - padX;
                                        const ry = window.typingCoords.y - padY;
                                        const rw = textWidth + padX * 2;
                                        const rh = h + padY * 2; // Symmetric height
                                        const radius = window.textCornerRadius;

                                        ctx.fillStyle = Helpers.getContrastingColor(window.currentColor.toString(), Qt);
                                        
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

                                        // Re-set fill color for text
                                        ctx.fillStyle = window.currentColor;
                                    }

                                    ctx.fillText(window.currentTypingText + "|", window.typingCoords.x, window.typingCoords.y + window.textFontSize / 2);

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
                            const pData = (window.parentWidget && window.parentWidget.pluginData) || {};
                            DrawingRenderer.drawWatermark(ctx, {
                                enabled: pData.enableWatermark && window.currentTool !== "crop",
                                type: pData.watermarkType || "text",
                                opacity: (pData.watermarkOpacity !== undefined ? pData.watermarkOpacity : 20) / 100.0,
                                position: pData.watermarkPosition || "bottom_right",
                                text: pData.watermarkText || "© {user}",
                                textScale: (pData.watermarkTextSize !== undefined ? pData.watermarkTextSize : 5) / 100.0,
                                imageScale: (pData.watermarkSize !== undefined ? pData.watermarkSize : 5) / 100.0,
                                canvasWidth: window.canvasWidth,
                                canvasHeight: window.canvasHeight,
                                imageLoader: watermarkImageLoader,
                                imageReady: watermarkImageLoader.status === Image.Ready,
                                imageSourceSize: watermarkImageLoader.sourceSize
                            }, config);

                            ctx.restore();
                        }

                        function drawStroke(ctx, stroke) {
                            DrawingRenderer.drawStroke(ctx, stroke, Helpers, Qt, Theme, {
                                roundRect: window.roundRect,
                                roundHighlighter: window.roundHighlighter,
                                bgImageItem: window.bgImageItem,
                                canvasWidth: window.canvasWidth,
                                canvasHeight: window.canvasHeight,
                                canvasMinX: (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.x : 0,
                                canvasMinY: (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.y : 0,
                            });
                        }

                        // Mouse Drawing & Action Capture
                        MouseArea {
                            id: drawMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                            function getAbsolutePoint(mx, my) {
                                let rx = mx / window.editScale;
                                let ry = my / window.editScale;
                                if (window.effectiveBackdropMode !== "none") {
                                    rx = (rx - window.screenshotXOffset) / window.backdropScaleFactor;
                                    ry = (ry - window.screenshotYOffset) / window.backdropScaleFactor;
                                }
                                if (window.currentTool !== "crop" && window.hasSelection) {
                                    return Qt.point(rx + window.cropRect.x, ry + window.cropRect.y);
                                }
                                return Qt.point(rx, ry);
                            }

                            // Visual cursor feedback based on hover position
                            property string hoveredHandle: "none"
                            property int hoveredStrokeIdx: -1
                            onPositionChanged: (mouse) => {
                                const origX = mouse.x / window.editScale;
                                const origY = mouse.y / window.editScale;
                                window.cursorX = origX;
                                window.cursorY = origY;
                                hoveredHandle = window.getHoveredHandle(origX, origY);

                                const absPt = getAbsolutePoint(mouse.x, mouse.y);

                                if (window.currentTool === "select") {
                                    if (window.selectedStroke) {
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
                                        drawingCanvas.requestPaint();
                                    } else {
                                        hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    }
                                    return;
                                }

                                if (window.currentTool === "crop") {
                                    if (window.activeHandle === "new") {
                                        const x1 = Math.min(window.selectStart.x, origX);
                                        const y1 = Math.min(window.selectStart.y, origY);
                                        const w = Math.abs(origX - window.selectStart.x);
                                        const h = Math.abs(origY - window.selectStart.y);
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
                                            newX = Math.min(origX, cr.x + cr.width - 10);
                                            newY = Math.min(origY, cr.y + cr.height - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "tr") {
                                            newY = Math.min(origY, cr.y + cr.height - 10);
                                            newW = Math.max(10, origX - cr.x);
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "bl") {
                                            newX = Math.min(origX, cr.x + cr.width - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = Math.max(10, origY - cr.y);
                                        } else if (window.activeHandle === "br") {
                                            newW = Math.max(10, origX - cr.x);
                                            newH = Math.max(10, origY - cr.y);
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
                                              || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "highlighter" || window.currentTool === "spotlight" || window.currentTool === "callout") {
                                         
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
                                         } else if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "ellipse" || window.currentTool === "rect" || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "spotlight")) {
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
                                if (window.hasSelection && window.isInsideCropRect(mouseX / window.editScale, mouseY / window.editScale)) {
                                    return Qt.CrossCursor;
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
                                            stampOptionsRadialMenu.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "text") {
                                            textOptionsRadialMenu.open(mapped.x, mapped.y);
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
                                        
                                        // Save previous style state if nothing was selected yet
                                        if (!window.selectedStroke) {
                                            window.preGrabStrokeWidth = window.strokeWidth;
                                            window.preGrabTextFontSize = window.textFontSize;
                                            window.preGrabPixelateIntensity = window.pixelateIntensity;
                                            window.preGrabSpotlightIntensity = window.spotlightIntensity;
                                            window.preGrabCalloutZoom = window.calloutZoom;
                                            window.preGrabColor = window.currentColor;
                                        }
                                        
                                        window.selectedStroke = stroke;
                                        window.currentColor = stroke.color;

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
                                        else if (stroke.tool === "pixelate") window.pixelateIntensity = stroke.width;
                                        else if (stroke.tool === "spotlight") window.spotlightIntensity = stroke.width;
                                        else if (stroke.tool === "callout") window.calloutZoom = stroke.width;
                                        else window.strokeWidth = stroke.width;
                                        
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
                                    const ox = mouse.x / window.editScale;
                                    const oy = mouse.y / window.editScale;
                                    const handle = window.getHoveredHandle(ox, oy);
                                    if (handle !== "none") {
                                        window.activeHandle = handle;
                                        return;
                                    }

                                    // Drag-to-select crop area
                                    window.activeHandle = "new";
                                    window.selectStart = Qt.point(ox, oy);
                                    window.cropRect = Qt.rect(ox, oy, 0, 0);
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
                                        counter: window.stampCounter,
                                        format: window.stampCounterFormat
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
                                    width: window.activeIntensity,
                                    points: [getAbsolutePoint(mouse.x, mouse.y)]
                                };
                                drawingCanvas.requestPaint();
                            }

                            onReleased: (mouse) => {
                                if (window.currentTool === "select") {
                                     window.selectedStroke = null;
                                     window.strokeWidth = window.preGrabStrokeWidth;
                                     window.textFontSize = window.preGrabTextFontSize;
                                     window.pixelateIntensity = window.preGrabPixelateIntensity;
                                     window.spotlightIntensity = window.preGrabSpotlightIntensity;
                                     window.calloutZoom = window.preGrabCalloutZoom;
                                     window.currentColor = window.preGrabColor;
                                     window.calloutDestDragging = false;
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
                                        const visX = (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.x : 0;
                                        const visY = (window.currentTool !== "crop" && window.hasSelection) ? window.cropRect.y : 0;
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
                                     
                                     window.previewX = wheel.x;
                                     window.previewY = wheel.y;
                                     window.showSizePreview = true;
                                     previewTimer.restart();
                                     
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

                        Rectangle {
                            id: sizePreviewItem
                            visible: window.showSizePreview
                            x: window.previewX - (width / 2)
                            y: window.previewY - (height / 2)
                            width: {
                                let base = window.activeIntensity;
                                const tool = window.effectiveTool;
                                if (tool === "highlighter") {
                                    base = window.activeIntensity * 4;
                                } else if (tool === "stamp") {
                                    base = window.activeIntensity * 10;
                                } else if (tool === "pixelate") {
                                    base = Math.max(8, Math.min(36, window.activeIntensity * 3));
                                } else if (tool === "spotlight") {
                                    base = 100;
                                } else if (tool === "callout") {
                                    if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                                        const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                                        base = bw * 2;
                                    } else {
                                        base = 40; // Small anchor size for text feedback
                                    }
                                }
                                return base * window.editScale;
                            }
                            height: width
                            radius: {
                                const tool = window.effectiveTool;
                                if (tool === "highlighter") return window.roundHighlighter ? width / 2 : 0;
                                if (tool === "spotlight" || tool === "rect" || tool === "redact") return window.roundRect ? (Theme.cornerRadius * window.editScale) : 0;
                                if (tool === "pixelate" || tool === "text") return 0;
                                if (tool === "callout") {
                                    if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                                        return width / 2;
                                    }
                                    return 0;
                                }
                                return width / 2;
                            }
                            color: "transparent"
                            border.color: {
                                if (window.effectiveTool === "callout") {
                                    if (window.currentTool === "select" && !window.calloutDestDragging && window.selectedStroke) {
                                        return Theme.primary;
                                    }
                                    return "transparent";
                                }
                                return Theme.primary;
                            }
                            border.width: 1.5 / drawingCanvas.scale
                            z: 20

                            StyledText {
                                anchors.top: parent.bottom
                                anchors.topMargin: 4 / drawingCanvas.scale
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "callout") {
                                        if (window.calloutDestDragging) {
                                            return window.selectedStroke.width + "%";
                                        } else {
                                            const bw = window.selectedStroke.borderWidth !== undefined ? window.selectedStroke.borderWidth : 2;
                                            return bw + "px";
                                        }
                                    }
                                    const tool = window.effectiveTool;
                                    if (tool === "spotlight" || tool === "callout") {
                                        return window.activeIntensity + "%";
                                    }
                                    return window.activeIntensity + "px";
                                }

                                color: Theme.primary
                                font.pixelSize: 10 / drawingCanvas.scale
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
                        visible: (config.pluginData["showCanvasBorder"] !== undefined ? config.pluginData["showCanvasBorder"] : true) && (window.effectiveBackdropMode === "none")
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

                        x: drawingCanvas.mapToItem(boardContainer, window.cursorX * window.editScale, window.cursorY * window.editScale).x - (width / 2)
                        y: drawingCanvas.mapToItem(boardContainer, window.cursorX * window.editScale, window.cursorY * window.editScale).y - (height / 2)

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
                                if (window.effectiveBackdropMode !== "none") {
                                    window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
                                    window.drawScreenshotShadow(ctx);
                                    window.drawScreenshotImage(ctx, bgImage);
                                    
                                    // 2. Draw annotations
                                    if (window.showAnnotations) {
                                        ctx.save();
                                        ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
                                        ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
                                        const cropX = window.hasSelection ? window.cropRect.x : 0;
                                        const cropY = window.hasSelection ? window.cropRect.y : 0;
                                        ctx.translate(-cropX, -cropY);
                                        for (var i = 0; i < window.strokes.length; i++) {
                                            drawingCanvas.drawStroke(ctx, window.strokes[i]);
                                        }
                                        if (window.currentStroke) {
                                            drawingCanvas.drawStroke(ctx, window.currentStroke);
                                        }
                                        ctx.restore();
                                    }
                                } else {
                                    if (staticBgImage.status === Image.Ready || staticBgImage.width > 0) {
                                        ctx.drawImage(staticBgImage, 0, 0, window.canvasWidth, window.canvasHeight);
                                    }
                                    if (window.showAnnotations) {
                                        for (var i = 0; i < window.strokes.length; i++) {
                                            drawingCanvas.drawStroke(ctx, window.strokes[i]);
                                        }
                                        if (window.currentStroke) {
                                            drawingCanvas.drawStroke(ctx, window.currentStroke);
                                        }
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
                        
                        // 0. Paint Backdrop (if active)
                        const isBackdropActive = window.effectiveBackdropMode !== "none";
                        if (isBackdropActive) {
                            window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
                            window.drawScreenshotShadow(ctx);
                            window.drawScreenshotImage(ctx, bgImage);
                        } else {
                            if (bgImage.status === Image.Ready) {
                                 if (window.hasSelection) {
                                     // Draw the cropped portion of the raw background
                                     ctx.drawImage(bgImage, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.cropRect.width, window.cropRect.height);
                                 } else {
                                     // Fullscreen background
                                     ctx.drawImage(bgImage, 0, 0);
                                 }
                            }
                        }

                        // 1.5 Overlay the Spotlight Layer and Annotations
                        if (window.showAnnotations) {
                            ctx.save();
                            const hasCropSelection = window.hasSelection;
                            if (isBackdropActive || hasCropSelection) {
                                const cropX = hasCropSelection ? window.cropRect.x : 0;
                                const cropY = hasCropSelection ? window.cropRect.y : 0;
                                ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
                                ctx.scale(window.backdropScaleFactor, window.backdropScaleFactor);
                                ctx.translate(-cropX, -cropY);
                            }

                            // 1.4 Draw Pixelate BEFORE spotlight layer in export
                            for (let i = 0; i < window.strokes.length; i++) {
                                if (window.strokes[i].tool === "pixelate") {
                                    window.activeCanvas.drawStroke(ctx, window.strokes[i]);
                                }
                            }
                            if (window.currentStroke && window.currentStroke.tool === "pixelate") {
                                window.activeCanvas.drawStroke(ctx, window.currentStroke);
                            }

                            const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
                            if (window.hasSpotlights || isDrawingSpotlight) {
                                const spotlights = window.strokes.filter(s => s.tool === "spotlight");
                                if (isDrawingSpotlight) {
                                    spotlights.push(window.currentStroke);
                                }

                                if (spotlights.length > 0) {
                                    ctx.save();
                                    
                                    let activeInt = window.spotlightIntensity;
                                    if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "spotlight") {
                                        activeInt = window.selectedStroke.width;
                                    } else {
                                        const lastSpotlight = window.strokes.slice().reverse().find(s => s.tool === "spotlight");
                                        if (lastSpotlight) activeInt = lastSpotlight.width;
                                    }

                                    const spotlightOpacity = activeInt / 100.0;

                                    ctx.beginPath();
                                    ctx.rect(0, 0, window.screenshotWidth, window.screenshotHeight);
                                    
                                    for (let s of spotlights) {
                                        if (s.points.length >= 2) {
                                            const p0 = s.points[0];
                                            const p1 = s.points[s.points.length - 1];
                                            const rx = Math.min(p0.x, p1.x);
                                            const ry = Math.min(p0.y, p1.y);
                                            const rw = Math.abs(p1.x - p0.x);
                                            const rh = Math.abs(p1.y - p0.y);
                                            
                                             if (rw > 0 && rh > 0) {
                                                 const radius = window.roundRect ? Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2) : 0;
                                                 if (radius > 0) {
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
                                                     ctx.rect(rx, ry, rw, rh);
                                                 }
                                             }
                                        }
                                    }
                                    
                                    ctx.clip("evenodd");
                                    ctx.fillStyle = "rgba(0, 0, 0, " + spotlightOpacity + ")";
                                    ctx.fillRect(0, 0, window.screenshotWidth, window.screenshotHeight);
                                    ctx.restore();
                                }
                            }

                            // 2. Overlay the annotations at full resolution
                            if (window.activeCanvas) {
                                // Draw all completed strokes (except pixelate and spotlight)
                                for (var i = 0; i < window.strokes.length; i++) {
                                    if (window.strokes[i].tool !== "pixelate" && window.strokes[i].tool !== "spotlight") {
                                        window.activeCanvas.drawStroke(ctx, window.strokes[i]);
                                    }
                                }
                                // Draw current dragging stroke if any
                                if (window.currentStroke && window.currentStroke.tool !== "pixelate" && window.currentStroke.tool !== "spotlight") {
                                    window.activeCanvas.drawStroke(ctx, window.currentStroke);
                                }
                            }
                            ctx.restore();
                        }

                        // 3. Overlay custom watermark if enabled
                        const pData = (window.parentWidget && window.parentWidget.pluginData) || {};
                        DrawingRenderer.drawWatermark(ctx, {
                            enabled: pData.enableWatermark,
                            type: pData.watermarkType || "text",
                            opacity: (pData.watermarkOpacity !== undefined ? pData.watermarkOpacity : 20) / 100.0,
                            position: pData.watermarkPosition || "bottom_right",
                            text: pData.watermarkText || "© {user}",
                            textScale: (pData.watermarkTextSize !== undefined ? pData.watermarkTextSize : 5) / 100.0,
                            imageScale: (pData.watermarkSize !== undefined ? pData.watermarkSize : 5) / 100.0,
                            canvasWidth: window.canvasWidth,
                            canvasHeight: window.canvasHeight,
                            imageLoader: watermarkImageLoader,
                            imageReady: watermarkImageLoader.status === Image.Ready,
                            imageSourceSize: watermarkImageLoader.sourceSize
                        }, config);

                        ctx.restore();

                        const tempOut = "/tmp/dms_capture_" + Date.now() + ".png";
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
                    hoverTrigger: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverTrigger !== undefined ? window.parentWidget.pluginData.radialHoverTrigger : false
                    hoverDelay: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverDelay !== undefined ? window.parentWidget.pluginData.radialHoverDelay : 300
                    menuOpacity: (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialMenuOpacity !== undefined ? window.parentWidget.pluginData.radialMenuOpacity : 100) / 100
                    onPresetSelected: (preset) => {
                        window.currentTool = preset.tool;
                        window.currentColor = preset.color;
                        if (preset.tool === "text") window.textFontSize = preset.thickness;
                        else if (preset.tool === "pixelate") window.pixelateIntensity = Math.max(2, Math.min(12, preset.thickness));
                        else if (preset.tool === "spotlight") window.spotlightIntensity = Math.max(10, Math.min(95, preset.thickness));
                        else if (preset.tool === "callout") window.calloutZoom = Math.max(100, Math.min(500, preset.thickness));
                        else window.strokeWidth = preset.thickness;
                        window.recordPresetUsage(preset);
                    }
                    onCenterClicked: {
                        window.currentTool = "select";
                    }
                }

                TextOptionsRadialMenu {
                    id: textOptionsRadialMenu
                    boldActive: window.textBold
                    italicActive: window.textItalic
                    underlineActive: window.textUnderline
                    backgroundActive: window.textBackground
                    onBoldToggled: window.textBold = !window.textBold
                    onItalicToggled: window.textItalic = !window.textItalic
                    onUnderlineToggled: window.textUnderline = !window.textUnderline
                    onBackgroundToggled: window.textBackground = !window.textBackground
                    onCenterClicked: {
                        window.currentTool = "text";
                        textOptionsRadialMenu.close();
                    }
                }

                StampOptionsRadialMenu {
                    id: stampOptionsRadialMenu
                    currentFormat: window.stampCounterFormat
                    onFormatSelected: (format) => window.stampCounterFormat = format
                    onCenterClicked: {
                        window.currentTool = "stamp";
                        stampOptionsRadialMenu.close();
                    }
                }

                MoreToolsMenu {
                    id: moreToolsMenu
                    onRotateRequested: window.rotateScreenshot()
                    onMirrorRequested: window.mirrorScreenshot()
                }

                HoverSliderPopover {
                    id: backdropPaddingPopover
                    minimum: 10
                    maximum: 150
                    value: window.backdropPadding
                    onUserValueChanged: (val) => {
                        window.backdropPadding = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropRadiusPopover
                    minimum: 0
                    maximum: 60
                    stepSize: 2
                    value: window.backdropCornerRadius
                    onUserValueChanged: (val) => {
                        window.backdropCornerRadius = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropShadowPopover
                    minimum: 0
                    maximum: 100
                    value: window.backdropShadowStrength
                    onUserValueChanged: (val) => {
                        window.backdropShadowStrength = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                HoverSliderPopover {
                    id: backdropAnglePopover
                    minimum: 0
                    maximum: 360
                    stepSize: 15
                    value: window.backdropGradientAngle
                    onUserValueChanged: (val) => {
                        window.backdropGradientAngle = val;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                Canvas {
                    id: contrastSampler
                    visible: false
                    width: 4
                    height: 4
                    onPaint: {
                        var ctx = contrastSampler.getContext("2d");
                        ctx.drawImage(bgImage, 0, 0, 4, 4, 0, 0, 4, 4);
                        var imgData = ctx.getImageData(0, 0, 4, 4);
                        if (imgData && imgData.data) {
                            // Sample center pixel (index 5) for luminance
                            var r = imgData.data[5 * 4];
                            var g = imgData.data[5 * 4 + 1];
                            var b = imgData.data[5 * 4 + 2];
                            var brightness = Helpers.getLuminance({ r: r/255, g: g/255, b: b/255 });
                            window.isScreenshotDark = (brightness < 0.35);
                            window.hasSampledContrast = true;

                            // Extract auto-balanced colors
                            var colors = Helpers.extractDominantColors(imgData, Qt);
                            window.autoBackdropGradientStart = colors.start;
                            window.autoBackdropGradientEnd = colors.end;
                            window.autoBackdropSolidColor = colors.start;

                            if (!window.hasUserCustomizedBackdrop) {
                                window.backdropGradientStart = colors.start;
                                window.backdropGradientEnd = colors.end;
                                window.backdropSolidColor = colors.start;
                            }
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
                hasBackground: window.textBackground,
                cornerRadius: window.textCornerRadius,
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
