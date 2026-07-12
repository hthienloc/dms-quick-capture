import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "./dms-common"
import "components"
import "components/Helpers.js" as Helpers
import "components/DrawingRenderer.js" as DrawingRenderer
import "components/StrokeProperties.js" as StrokeProps
import "components/Constants.js" as Constants

DankModal {
    id: window

    readonly property var rootWindow: window

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
    property var paletteWarningDialogRef: null
    property var toolbarItem: null
    property int activeColorSlotIndex: 0
    property color pendingColorToSave: "transparent"
    property int pendingSlotToSave: -1
    property string currentTool: "crop" // crop, select, pen, line, arrow, rect, ellipse, text, pixelate, redact, stamp, highlighter, eraser, spotlight, backdrop
    property string lastActiveTool: "pen"
    property string colorPickerMode: "draw" // draw, copy
    property color hoveredColor: "transparent"
    property string activeLineStyle: "solid"
    property string activeRedactMode: "solid" // solid, blur, clean
    onActiveRedactModeChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "redact") {
            window.selectedStroke.redactMode = window.activeRedactMode;
            window.selectedStroke.cachedCleanColor = undefined;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "redact") {
            window.currentStroke.redactMode = window.activeRedactMode;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    onActiveLineStyleChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "line") {
            window.selectedStroke.lineStyle = window.activeLineStyle;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "line") {
            window.currentStroke.lineStyle = window.activeLineStyle;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string activeArrowLineStyle: "solid"
    property string activeArrowHeadStyle: "single-filled"
    onActiveArrowLineStyleChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "arrow") {
            window.selectedStroke.arrowLineStyle = window.activeArrowLineStyle;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "arrow") {
            window.currentStroke.arrowLineStyle = window.activeArrowLineStyle;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    onActiveArrowHeadStyleChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "arrow") {
            window.selectedStroke.arrowHeadStyle = window.activeArrowHeadStyle;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "arrow") {
            window.currentStroke.arrowHeadStyle = window.activeArrowHeadStyle;
        }
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int _lastSampledX: -1
    property int _lastSampledY: -1
    property color _lastSampledColor: "transparent"
    readonly property real dpr: Screen.devicePixelRatio || 1.0
    onCurrentToolChanged: {
        if (currentTool !== "colorpicker") {
            window.backdropColorPickingSlot = "none";
        }
        if (currentTool !== "text" && window.isTyping) {
            window.commitTypingText();
        }
        if (currentTool !== "crop" && currentTool !== "backdrop" && currentTool !== "select" && currentTool !== "colorpicker") {
            lastActiveTool = currentTool;
        }
        if (currentTool === "colorpicker") {
            window._lastSampledX = -1;
            window._lastSampledY = -1;
            window._lastSampledColor = "transparent";
            window.requestPaintAll();
            window.hoveredColor = window.sampleCanvasColor(window.cursorX * window.editScale, window.cursorY * window.editScale);
        }
        if (currentTool === "backdrop" && window.backdropMode === "none") {
            const defaultMode = (config && config.pluginData && config.pluginData["backdropDefaultMode"]) || Constants.defaultBackdropMode;
            window.backdropMode = defaultMode;
        }
        window.requestPaintAll();
    }

    // Backdrop State Variables
    property string backdropMode: "none" // none, solid, gradient
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property int backdropGradientAngle: Constants.defaultBackdropGradientAngle
    property int backdropPadding: Constants.defaultBackdropPadding
    property int backdropCornerRadius: Constants.defaultBackdropCornerRadius
    property int backdropShadowStrength: Constants.defaultBackdropShadowStrength
    property string backdropAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property string backdropAlignment: "center"
    property string backdropColorPickingSlot: "none" // none, solid, start, end
    readonly property real customRatioMin: 0.50
    readonly property real customRatioMax: 2.50
    readonly property real customRatioStep: 0.05
    readonly property var aspectPresets: [
        { value: "auto", label: I18n.tr("AUTO") },
        { value: "1:1", label: "1:1" },
        { value: "16:9", label: "16:9" },
        { value: "9:16", label: "9:16" },
        { value: "4:3", label: "4:3" },
        { value: "3:2", label: "3:2" },
        { value: "21:9", label: "21:9" },
        { value: "custom", label: I18n.tr("CUST") }
    ]
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
    readonly property bool hasActiveCropSelection: window.currentTool !== "crop" && window.hasSelection
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
            if (window.selectedStroke.tool === "redact") {
                window.selectedStroke.cachedCleanColor = undefined;
            }
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
    onStampCounterFormatChanged: {
        window.reindexStamps();
        window.requestPaintAll();
    }
    property int calloutLinkLines: 1 // 1, 2
    onCalloutLinkLinesChanged: {
        if (selectedStroke && selectedStroke.tool === "callout") {
            if (selectedStroke.calloutLinkLines !== calloutLinkLines) {
                selectedStroke.calloutLinkLines = calloutLinkLines;
                const idx = window.strokes.indexOf(selectedStroke);
                if (idx !== -1) {
                    window.strokes[idx] = selectedStroke;
                    window.strokes = [...window.strokes];
                }
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
        }
    }
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false


    // --- Proxy Editing Optimization ---
    readonly property real maxEditDimension: {
        const q = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.editQuality) || String(Constants.defaultEditQuality);
        if (q === "original") return Infinity;
        const val = parseInt(q);
        return (isNaN(val) || val <= 0) ? Constants.defaultEditQuality : val;
    }
    readonly property real editScale: {
        if (!window.bgImageItem) return 1.0;
        const w = window.bgImageItem.sourceSize.width;
        const h = window.bgImageItem.sourceSize.height;
        const max = Math.max(w, h);
        let baseScale = 1.0;
        if (!(isNaN(max) || max <= 0 || max <= maxEditDimension)) {
            baseScale = maxEditDimension / max;
        }
        // Cap the editScale to fitScale so that the canvas resolution
        // never exceeds the actual display size on the screen.
        const maxRequiredScale = window.fitScale;
        return Math.min(baseScale, maxRequiredScale);
    }

    readonly property string effectiveBackdropMode: window.currentTool === "crop" ? "none" : window.backdropMode

    readonly property real screenshotWidth: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.width;
        }
        return window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
    }
    readonly property real screenshotHeight: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.height;
        }
        return window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
    }

    function getTargetRatio(ratioStr) {
        if (ratioStr === "auto") return 0.0;
        if (ratioStr === "1:1") return 1.0;
        if (ratioStr === "16:9") return 16.0 / 9.0;
        if (ratioStr === "9:16") return 9.0 / 16.0;
        if (ratioStr === "4:3") return 4.0 / 3.0;
        if (ratioStr === "3:2") return 3.0 / 2.0;
        if (ratioStr === "21:9") return 21.0 / 9.0;
        if (ratioStr === "custom") {
            const val = window.customAspectRatio;
            return (isFinite(val) && val > 0) ? val : 1.0;
        }
        return 0.0;
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
        const targetRatio = getTargetRatio(window.backdropAspectRatio);
        if (!(targetRatio > 0.0)) {
            return baseW;
        }
        const currentRatio = baseW / baseH;
        if (currentRatio > targetRatio) {
            return baseW;
        } else {
            return baseH * targetRatio;
        }
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
        const targetRatio = getTargetRatio(window.backdropAspectRatio);
        if (!(targetRatio > 0.0)) {
            return baseH;
        }
        const currentRatio = baseW / baseH;
        if (currentRatio > targetRatio) {
            return baseW / targetRatio;
        } else {
            return baseH;
        }
    }

    readonly property real backdropScaleFactor: 1.0

    readonly property real screenshotXOffset: {
        if (window.effectiveBackdropMode === "none") return 0;
        const align = window.backdropAlignment;
        if (align.endsWith("-left"))  return 0;
        if (align.endsWith("-right")) return canvasWidth - screenshotWidth;
        return (canvasWidth - screenshotWidth) / 2;
    }
    readonly property real screenshotYOffset: {
        if (window.effectiveBackdropMode === "none") return 0;
        const align = window.backdropAlignment;
        if (align.startsWith("top-"))    return 0;
        if (align.startsWith("bottom-")) return canvasHeight - screenshotHeight;
        return (canvasHeight - screenshotHeight) / 2;
    }

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
        } else if (window.backdropMode === "radial") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            grad.addColorStop(0, window.backdropGradientStart.toString());
            grad.addColorStop(1, window.backdropGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        } else if (window.backdropMode === "conic") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const startAngle = (window.backdropGradientAngle * Math.PI) / 180;
            const numSlices = 240;

            // Cache color components to avoid JS-to-C++ property boundary crossing cost
            const startCol = window.backdropGradientStart;
            const endCol = window.backdropGradientEnd;
            const sr = startCol.r * 255;
            const sg = startCol.g * 255;
            const sb = startCol.b * 255;
            const sa = startCol.a;
            const er = endCol.r * 255;
            const eg = endCol.g * 255;
            const eb = endCol.b * 255;
            const ea = endCol.a;

            ctx.save();
            ctx.translate(cx, cy);
            for (let i = 0; i < numSlices; i++) {
                const angle1 = startAngle + (i / numSlices) * Math.PI * 2;
                const angle2 = startAngle + ((i + 1.01) / numSlices) * Math.PI * 2;
                const t = i / numSlices;
                const rComp = Math.round(sr * (1 - t) + er * t);
                const gComp = Math.round(sg * (1 - t) + eg * t);
                const bComp = Math.round(sb * (1 - t) + eb * t);
                const aComp = sa * (1 - t) + ea * t;
                ctx.fillStyle = "rgba(" + rComp + "," + gComp + "," + bComp + "," + aComp + ")";
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.arc(0, 0, r, angle1, angle2);
                ctx.closePath();
                ctx.fill();
            }
            ctx.restore();
        }
    }

    function getScreenshotLayout() {
        const factor = window.backdropScaleFactor;
        return {
            x: window.screenshotXOffset,
            y: window.screenshotYOffset,
            w: window.screenshotWidth * factor,
            h: window.screenshotHeight * factor,
            r: window.backdropCornerRadius * factor
        };
    }

    function drawScreenshotShadow(ctx) {
        if (window.backdropShadowStrength <= 0) return;
        ctx.save();
        const layout = window.getScreenshotLayout();
        const r = layout.r;
        const x = layout.x;
        const y = layout.y;
        const w = layout.w;
        const h = layout.h;
        
        const opacity = (window.backdropShadowStrength / 100.0) * 0.55;
        const STEPS = 12;
        const maxOffset = 24.0;
        const maxBlur = 45.0;
        
        // Draw 12 concentric shadow layers with quadratic spacing and falloff for smooth rendering
        for (let i = 1; i <= STEPS; i++) {
            const t = i / STEPS;
            const blur = Math.pow(t, 1.5) * maxBlur;
            const offset = Math.pow(t, 1.5) * maxOffset;
            const alpha = opacity * Math.pow(1.0 - t, 1.5) * 0.75;
            
            ctx.fillStyle = Qt.rgba(0, 0, 0, alpha);
            
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
        
        const layout = window.getScreenshotLayout();
        const r = layout.r;
        const x = layout.x;
        const y = layout.y;
        const w = layout.w;
        const h = layout.h;
        
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
        window.requestPaintAll();
    }
    property var copiedStroke: null

    property var strokes: []
    onStrokesChanged: {
        window.reindexStamps();
        window.requestPaintAll();
    }
    readonly property bool hasSpotlights: {
        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool === "spotlight") return true;
        }
        return false;
    }
    property var currentStroke: null
    onCurrentStrokeChanged: {
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }
    property var selectedStroke: null
    property int preGrabStrokeWidth: 8
    property int preGrabTextFontSize: 36
    property int preGrabPixelateIntensity: 8
    property int preGrabSpotlightIntensity: 50
    property int preGrabCalloutZoom: 150
    property color preGrabColor: Theme.primary
    property string preGrabRedactMode: "solid"
    property int preGrabCalloutLinkLines: 1
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

    // Text Input Management
    property bool isTyping: false
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""

    // Helper to decode hex color to RGB
    function hexToRgb(hex) { return Helpers.hexToRgb(hex, Qt); }

    backgroundOpacity: {
        const data = window.parentWidget && window.parentWidget.pluginData;
        if (!data) return 0.6;
        if (data.overlayOpacity !== undefined) return data.overlayOpacity / 100;
        if (data.modalOpacity !== undefined) return data.modalOpacity / 100;
        return 0.6;
    }
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

    function runOcr() {
        window.ocrRect = Qt.rect(0, 0, 0, 0);
        window.currentTool = "ocr";
        if (window.activeCanvas) window.activeCanvas.requestPaint();
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(I18n.tr("OCR: Draw a rectangle on the image to scan"));
        }
    }

    function executeOcr() {
        const r = window.ocrRect;
        if (r.width < 10 || r.height < 10) {
            window.ocrRect = Qt.rect(0, 0, 0, 0);
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            return;
        }

        // Account for crop offset when mapping to source image coordinates
        const cropOffsetX = window.hasSelection ? window.cropRect.x : 0;
        const cropOffsetY = window.hasSelection ? window.cropRect.y : 0;
        const ix = Math.round(r.x + cropOffsetX);
        const iy = Math.round(r.y + cropOffsetY);
        const iw = Math.round(r.width);
        const ih = Math.round(r.height);

        let bgPath = decodeURIComponent(window.bgImageSource.toString());
        if (bgPath.startsWith("file://")) bgPath = bgPath.substring(7);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);
        let ocrLang = "eng";

        const uniqueId = Date.now() + "_" + Math.floor(Math.random() * 1000000);
        const tempCropPath = "/tmp/dms_ocr_crop_" + uniqueId + ".png";
        Proc.runCommand("crop-ocr-temp", ["magick", bgPath, "-crop", iw + "x" + ih + "+" + ix + "+" + iy, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-ocr", ["tesseract", tempCropPath, "-", "-l", ocrLang], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-ocr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("OCR: %1 chars copied to clipboard").arg(result.length));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("OCR: No text detected"));
                            }
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("OCR failed during text extraction"));
                        }
                    }
                    window.currentTool = window.lastActiveTool;
                    window.ocrRect = Qt.rect(0, 0, 0, 0);
                    if (window.activeCanvas) window.activeCanvas.requestPaint();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("OCR failed: Could not crop image"));
                }
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
        });
    }

    function runQrScan() {
        window.ocrRect = Qt.rect(0, 0, 0, 0);
        window.currentTool = "qr";
        if (window.activeCanvas) window.activeCanvas.requestPaint();
        if (typeof ToastService !== "undefined" && ToastService) {
            ToastService.showInfo(I18n.tr("QR Scan: Draw a rectangle on the image to scan"));
        }
    }

    function executeQrScan() {
        const r = window.ocrRect;
        if (r.width < 10 || r.height < 10) {
            window.ocrRect = Qt.rect(0, 0, 0, 0);
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            return;
        }

        // Account for crop offset when mapping to source image coordinates
        const cropOffsetX = window.hasSelection ? window.cropRect.x : 0;
        const cropOffsetY = window.hasSelection ? window.cropRect.y : 0;
        const ix = Math.round(r.x + cropOffsetX);
        const iy = Math.round(r.y + cropOffsetY);
        const iw = Math.round(r.width);
        const ih = Math.round(r.height);

        let bgPath = decodeURIComponent(window.bgImageSource.toString());
        if (bgPath.startsWith("file://")) bgPath = bgPath.substring(7);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);

        const uniqueId = Date.now() + "_" + Math.floor(Math.random() * 1000000);
        const tempCropPath = "/tmp/dms_qr_crop_" + uniqueId + ".png";
        Proc.runCommand("crop-qr-temp", ["magick", bgPath, "-crop", iw + "x" + ih + "+" + ix + "+" + iy, tempCropPath], (stdout1, exitCode1) => {
            if (exitCode1 === 0) {
                Proc.runCommand("run-qr-scan", ["zbarimg", "--raw", "-q", tempCropPath], (stdout2, exitCode2) => {
                    Proc.runCommand("cleanup-qr-temp", ["rm", "-f", tempCropPath]);

                    if (exitCode2 === 0) {
                        const result = stdout2.trim();
                        if (result) {
                            DMSService.sendRequest("clipboard.copy", { "text": result }, function(response) {
                                if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo(I18n.tr("QR Decoded: Copied to clipboard"));
                                }
                            });
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                            }
                        }
                    } else if (exitCode2 === 4) {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showInfo(I18n.tr("QR Scan: No QR code detected"));
                        }
                    } else {
                        if (typeof ToastService !== "undefined" && ToastService) {
                            ToastService.showError(I18n.tr("QR Scan failed or command execution error"));
                        }
                    }
                    window.currentTool = window.lastActiveTool;
                    window.ocrRect = Qt.rect(0, 0, 0, 0);
                    if (window.activeCanvas) window.activeCanvas.requestPaint();
                });
            } else {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.tr("QR Scan failed: Could not crop image"));
                }
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
        });
    }

    shouldBeVisible: false
    
    // Spacious modal dimensions occupying 90% width and 90% height of the screen
    modalWidth: Math.round((window.targetScreen ? window.targetScreen.width : (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920)) * 0.9)
    modalHeight: Math.round((window.targetScreen ? window.targetScreen.height : (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080)) * 0.9)
    enableShadow: true
    positioning: "center"

    targetScreen: {
        const mode = config.modalDisplayTarget;
        const fallback = (Quickshell.screens && Quickshell.screens.length > 0) ? Quickshell.screens[0] : null;
        if (mode === "focused") {
            return CompositorService.getFocusedScreen() ?? fallback;
        }
        if (mode === "primary") {
            return fallback;
        }
        // Specific screen name matching with defensive check
        if (Quickshell.screens) {
            for (let i = 0; i < Quickshell.screens.length; i++) {
                const s = Quickshell.screens[i];
                if (s && s.name === mode) {
                    return s;
                }
            }
        }
        return (CompositorService.getFocusedScreen() ?? fallback);
    }

    // Component scope bridging properties
    property string bgImageSource: ""
    property var activeCanvas: null
    property var bakedCanvas: null
    property var bgImageItem: null
    property var boardContainerItem: null
    property var exportCanvasItem: null
    property var offscreenSamplerItem: null

    onSelectedStrokeChanged: window.requestPaintAll()
    onEffectiveBackdropModeChanged: window.requestPaintAll()
    onBackdropSolidColorChanged: window.requestPaintAll()
    onBackdropGradientStartChanged: window.requestPaintAll()
    onBackdropGradientEndChanged: window.requestPaintAll()
    onBackdropPaddingChanged: window.requestPaintAll()
    onBackdropCornerRadiusChanged: window.requestPaintAll()
    onBackdropShadowStrengthChanged: window.requestPaintAll()
    onBackdropGradientAngleChanged: window.requestPaintAll()
    onBackdropAspectRatioChanged: window.requestPaintAll()
    onEditScaleChanged: window.requestPaintAll()

    function requestPaintAll() {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }

    function drawStroke(ctx, stroke) {
        DrawingRenderer.drawStroke(ctx, stroke, Helpers, Qt, Theme, {
            roundRect: window.roundRect,
            roundHighlighter: window.roundHighlighter,
            bgImageItem: window.bgImageItem,
            offscreenSampler: window.offscreenSamplerItem,
            canvasWidth: window.canvasWidth,
            canvasHeight: window.canvasHeight,
            canvasMinX: window.hasActiveCropSelection ? window.cropRect.x : 0,
            canvasMinY: window.hasActiveCropSelection ? window.cropRect.y : 0,
        });
    }

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
        const absPt = window.hasActiveCropSelection ? Qt.point(mx + window.cropRect.x, my + window.cropRect.y) : Qt.point(mx, my);

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
            window.preGrabRedactMode = window.activeRedactMode;
            window.preGrabCalloutLinkLines = window.calloutLinkLines;
            window.strokeWidth = pasted.width;
            window.currentColor = pasted.color;
            if (pasted.tool === "redact" && pasted.redactMode) window.activeRedactMode = pasted.redactMode;
            window.selectedStroke = pasted;
            window.pressCoords = absPt;
            window.originalPoints = newPoints;
        }
        
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function getPresetTool(index) {
        let pData = {};
        if (window.parentWidget && window.parentWidget.pluginData) {
            pData = window.parentWidget.pluginData;
        } else if (typeof config !== "undefined" && config.pluginData) {
            pData = config.pluginData;
        }
        const val = pData["preset_" + index + "_tool"];
        if (val !== undefined) return val;
        
        const defaultTools = ["pen", "arrow", "rect", "highlighter", "ellipse", "stamp", "redact", "pixelate"];
        return defaultTools[index] || "none";
    }

    function getPresetColor(index) {
        let pData = {};
        if (window.parentWidget && window.parentWidget.pluginData) {
            pData = window.parentWidget.pluginData;
        } else if (typeof config !== "undefined" && config.pluginData) {
            pData = config.pluginData;
        }
        const val = pData["preset_" + index + "_color"];
        if (val !== undefined) return val;
        
        const defaultColors = ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"];
        return defaultColors[index] || "primary";
    }

    function getPresetThickness(index) {
        let pData = {};
        if (window.parentWidget && window.parentWidget.pluginData) {
            pData = window.parentWidget.pluginData;
        } else if (typeof config !== "undefined" && config.pluginData) {
            pData = config.pluginData;
        }
        const val = pData["preset_" + index + "_thickness"];
        if (val !== undefined) return parseInt(val, 10) || 6;
        return 6;
    }

    function updateRadialPresets() {
        const list = [];
        for (let i = 0; i < 8; i++) {
            const t = window.getPresetTool(i);
            if (t && t !== "none") {
                const rawColor = window.getPresetColor(i);
                const resolvedColor = config.resolveColor(rawColor);
                list.push({
                    tool: t,
                    color: resolvedColor,
                    thickness: window.getPresetThickness(i)
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
        if (window.hasActiveCropSelection) {
            return Math.min(scale, 1.0);
        }
        return scale;
    }

    // Crop Selection State
    property rect cropRect: Qt.rect(0, 0, 0, 0)
    property bool hasSelection: false
    readonly property bool roundRect: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundRect !== undefined ? window.parentWidget.pluginData.roundRect : true
    readonly property bool roundHighlighter: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.roundHighlighter !== undefined ? window.parentWidget.pluginData.roundHighlighter : false
    readonly property bool penAutoClose: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.penAutoClose !== undefined ? window.parentWidget.pluginData.penAutoClose : true

    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property rect ocrRect: Qt.rect(0, 0, 0, 0)
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

        // Check corners first
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y1) <= threshold) return "tl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y1) <= threshold) return "tr";
        if (Math.abs(mx - x1) <= threshold && Math.abs(my - y2) <= threshold) return "bl";
        if (Math.abs(mx - x2) <= threshold && Math.abs(my - y2) <= threshold) return "br";

        // Check full edges
        if (Math.abs(my - y1) <= threshold && mx >= x1 && mx <= x2) return "tc";
        if (Math.abs(my - y2) <= threshold && mx >= x1 && mx <= x2) return "bc";
        if (Math.abs(mx - x1) <= threshold && my >= y1 && my <= y2) return "lc";
        if (Math.abs(mx - x2) <= threshold && my >= y1 && my <= y2) return "rc";

        return "none";
    }

    function isInsideCropRect(mx, my) {
        return Helpers.isInsideCropRect(mx, my, window.hasSelection, window.cropRect);
    }

    function clampCropRect(x, y, w, h) {
        const bw = window.screenshotWidth;
        const bh = window.screenshotHeight;
        const minSize = 10;
        const cx = Math.max(0, Math.min(x, Math.max(0, bw - minSize)));
        const cy = Math.max(0, Math.min(y, Math.max(0, bh - minSize)));
        const cw = Math.max(minSize, Math.min(w, bw - cx));
        const ch = Math.max(minSize, Math.min(h, bh - cy));
        return Qt.rect(cx, cy, cw, ch);
    }

    function backdropConfigValue(key, defaultValue, numeric) {
        const pd = config && config.pluginData;
        if (!pd || pd[key] === undefined || pd[key] === null) return defaultValue;
        return numeric ? parseInt(pd[key], 10) : pd[key];
    }

    function backdropConfigColor(key, defaultValue) {
        const pd = config && config.pluginData;
        if (!pd) return defaultValue;
        const val = pd[key];
        if (!val) return defaultValue;
        return config.resolveColor(val);
    }

    function constrainSquarePoint(start, point) {
        return Helpers.constrainSquarePoint(start, point, Qt);
    }

    function estimateTextWidth(text, fontSize, isBold, isMonospace) {
        return Helpers.estimateTextWidth(text, fontSize, isBold, isMonospace);
    }

    function findStrokeAt(mx, my) {
        return Helpers.findStrokeAt(mx, my, window.strokes, window.estimateTextWidth);
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

    function formatHexColor(color) { return Helpers.formatHexColor(color); }

    function reindexStamps() {
        let stamps = [];
        for (let i = 0; i < window.strokes.length; i++) {
            let stroke = window.strokes[i];
            if (stroke && stroke.tool === "stamp") {
                if (stroke.id === undefined) {
                    stroke.id = Date.now() + (i / 1000000);
                }
                stamps.push(stroke);
            }
        }

        stamps.sort((a, b) => a.id - b.id);

        let modified = false;
        for (let i = 0; i < stamps.length; i++) {
            let stroke = stamps[i];
            let stampCount = i + 1;
            if (stroke.counter !== stampCount) {
                stroke.counter = stampCount;
                modified = true;
            }
            if (stroke.format !== window.stampCounterFormat) {
                stroke.format = window.stampCounterFormat;
                modified = true;
            }
        }

        const nextCounter = stamps.length + 1;
        if (window.stampCounter !== nextCounter) {
            window.stampCounter = nextCounter;
        }
        if (modified && window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }

    function updateColorSlot(slotIdx, colorValue) {
        const hex = window.formatHexColor(colorValue).toUpperCase();
        if (config.selectedPreset !== "custom") {
            window.pendingColorToSave = colorValue;
            window.pendingSlotToSave = slotIdx;
            if (window.paletteWarningDialogRef) window.paletteWarningDialogRef.open();
        } else {
            window.currentColor = colorValue;
            window.writeColorSlotToCustom(slotIdx, hex);
        }
    }

    function openColorPickerModal() {
        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
            PopoutService.colorPickerModal.selectedColor = window.currentColor;
            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Color");
            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                window.updateColorSlot(window.activeColorSlotIndex, selectedColor);
            };
            PopoutService.colorPickerModal.show();
            return true;
        }
        return false;
    }

    function writeColorSlotToCustom(slotIdx, hex) {
        if (!window.parentWidget || !window.parentWidget.pluginService || slotIdx < 0) return;
        
        let pData = Object.assign({}, window.parentWidget.pluginData);
        pData["color_palette_preset"] = "custom";
        
        const key = slotIdx === 0 ? "toolbar_color_primary" : "toolbar_color_" + (slotIdx - 1);
        pData[key] = hex;
        
        window.parentWidget.pluginData = pData;
        
        window.parentWidget.pluginService.savePluginData("quickCapture", "color_palette_preset", "custom");
        window.parentWidget.pluginService.savePluginData("quickCapture", key, hex);
    }

    function switchPresetToCustom(copyCurrent) {
        if (!window.parentWidget || !window.parentWidget.pluginService) return;
        
        // 1. Read current palette FIRST before switching preset to custom
        // to avoid QML reactive bindings immediately resetting the palette to custom empty/defaults.
        const currentPalette = (copyCurrent && window.toolbarItem && window.toolbarItem.toolbarPalette) ? window.toolbarItem.toolbarPalette : [];
        
        let pData = Object.assign({}, window.parentWidget.pluginData);
        pData["color_palette_preset"] = "custom";
        window.parentWidget.pluginService.savePluginData("quickCapture", "color_palette_preset", "custom");
        
        if (copyCurrent && currentPalette && currentPalette.length >= 8) {
            pData["toolbar_color_primary"] = window.formatHexColor(currentPalette[0]).toUpperCase();
            window.parentWidget.pluginService.savePluginData("quickCapture", "toolbar_color_primary", pData["toolbar_color_primary"]);
            
            for (let i = 0; i < 7; i++) {
                const key = "toolbar_color_" + i;
                pData[key] = window.formatHexColor(currentPalette[i + 1]).toUpperCase();
                window.parentWidget.pluginService.savePluginData("quickCapture", key, pData[key]);
            }
        }
        
        if (window.pendingSlotToSave >= 0) {
            const hex = window.formatHexColor(window.pendingColorToSave).toUpperCase();
            const key = window.pendingSlotToSave === 0 ? "toolbar_color_primary" : "toolbar_color_" + (window.pendingSlotToSave - 1);
            pData[key] = hex;
            window.parentWidget.pluginService.savePluginData("quickCapture", key, hex);
            
            window.parentWidget.pluginData = pData;
            window.currentColor = window.pendingColorToSave;
        }
        
        window.pendingColorToSave = "transparent";
        window.pendingSlotToSave = -1;
    }

    function sampleCanvasColor(mouseX, mouseY) {
        var canvas = window.bakedCanvas || window.activeCanvas;
        if (!canvas) return window.currentColor;
        
        // Clamp and round coordinates to prevent out-of-bounds errors and ensure integer coordinates in device pixels
        var x = Math.max(0, Math.min(Math.floor(mouseX * window.dpr), Math.floor(canvas.width * window.dpr) - 1));
        var y = Math.max(0, Math.min(Math.floor(mouseY * window.dpr), Math.floor(canvas.height * window.dpr) - 1));
        
        // Performance optimization: skip sampling if the pixel coordinates haven't changed
        if (window._lastSampledX === x && window._lastSampledY === y) {
            return window._lastSampledColor || window.currentColor;
        }
        
        try {
            var ctx = canvas.getContext("2d");
            if (!ctx) return window.currentColor;
            
            var imgData = ctx.getImageData(x, y, 1, 1);
            if (imgData && imgData.data && imgData.data.length >= 4) {
                var r = imgData.data[0];
                var g = imgData.data[1];
                var b = imgData.data[2];
                var a = imgData.data[3];
                
                var pickedColor;
                if (a === 0) {
                    pickedColor = window.currentColor;
                } else {
                    // Force alpha to 1.0 to ensure we always sample an opaque color.
                    pickedColor = Qt.rgba(r / 255, g / 255, b / 255, 1.0);
                }
                
                window._lastSampledX = x;
                window._lastSampledY = y;
                window._lastSampledColor = pickedColor;
                
                return pickedColor;
            }
        } catch (e) {
            console.warn("Color picker failed to sample pixel color:", e);
        }
        return window.currentColor;
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
            if (window.currentTool === "ocr" || window.currentTool === "qr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                if (window.activeCanvas) window.activeCanvas.requestPaint();
                event.accepted = true;
                return;
            }
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
                let idx = config.colorShortcuts.indexOf(colorShortcut);
                if (idx !== -1) {
                    window.activeColorSlotIndex = idx;
                }
                window.currentColor = window.shortcutColor(colorShortcut.color);
                event.accepted = true;
            }
            return;
        }

        if (token === "O" && !hasCtrl) {
            if (window.currentTool === "ocr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            } else {
                window.runOcr();
            }
            event.accepted = true;
            return;
        }

        const toolShortcut = config.findByKey(config.toolShortcuts, token);
        if (toolShortcut) {
            if (toolShortcut.tool === "colorpicker") {
                if (!window.openColorPickerModal()) {
                    if (window.currentTool === "colorpicker") {
                        window.currentTool = window.lastActiveTool;
                    } else {
                        window.colorPickerMode = "draw";
                        window.currentTool = "colorpicker";
                    }
                }
                event.accepted = true;
                return;
            }

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
        if (event.key === Qt.Key_G && !window.isTyping) {
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
        if (event.key === Qt.Key_G && !window.isTyping) {
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
            const t = window.getPresetTool(presetIdx);
            if (t && t !== "none") {
                startTool = t;
                const rawColor = window.getPresetColor(presetIdx);
                startColor = config.resolveColor(rawColor);
                startThickness = window.getPresetThickness(presetIdx);
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
        window.backdropSolidColor = backdropConfigColor("backdropDefaultSolidColor", config.resolveColor("slot_1"));
        window.backdropGradientStart = backdropConfigColor("backdropDefaultGradientStart", config.resolveColor("slot_1"));
        window.backdropGradientEnd = backdropConfigColor("backdropDefaultGradientEnd", config.resolveColor("slot_2"));

        const pd = config && config.pluginData;
        const hasCustomSolid = pd && pd["backdropDefaultSolidColor"] !== undefined;
        const hasCustomGradStart = pd && pd["backdropDefaultGradientStart"] !== undefined;
        const hasCustomGradEnd = pd && pd["backdropDefaultGradientEnd"] !== undefined;
        window.hasUserCustomizedBackdrop = !!(hasCustomSolid || hasCustomGradStart || hasCustomGradEnd);
        window.backdropMode = "none";
        if (config && config.pluginData && config.pluginData["backdropAutoApply"] === true) {
            const bm = config.pluginData["backdropDefaultMode"];
            if (bm) window.backdropMode = bm;
        }
        window.backdropPadding = backdropConfigValue("backdropDefaultPadding", Constants.defaultBackdropPadding, true);
        window.backdropCornerRadius = backdropConfigValue("backdropDefaultRadius", Constants.defaultBackdropCornerRadius, true);
        window.backdropShadowStrength = backdropConfigValue("backdropDefaultShadow", Constants.defaultBackdropShadowStrength, true);
        window.backdropGradientAngle = backdropConfigValue("backdropDefaultAngle", Constants.defaultBackdropGradientAngle, true);
        window.backdropAspectRatio = backdropConfigValue("backdropDefaultAspectRatio", Constants.defaultBackdropAspectRatio, false);
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
                        if (data && data.backdropMode !== undefined) {
                            window.backdropMode = data.backdropMode;
                            window.backdropSolidColor = data.backdropSolidColor;
                            window.backdropGradientStart = data.backdropGradientStart;
                            window.backdropGradientEnd = data.backdropGradientEnd;
                            window.backdropGradientAngle = data.backdropGradientAngle;
                            window.backdropPadding = data.backdropPadding;
                            window.backdropCornerRadius = data.backdropCornerRadius;
                            window.backdropShadowStrength = data.backdropShadowStrength;
                            window.backdropAspectRatio = data.backdropAspectRatio;
                            window.customAspectRatio = data.customAspectRatio;
                            if (data.backdropAlignment) window.backdropAlignment = data.backdropAlignment;
                            window.hasUserCustomizedBackdrop = data.hasUserCustomizedBackdrop;
                            window.autoBackdropGradientStart = data.autoBackdropGradientStart;
                            window.autoBackdropGradientEnd = data.autoBackdropGradientEnd;
                            window.autoBackdropSolidColor = data.autoBackdropSolidColor;
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
                        offscreenSampler.requestPaint();
                    }
                }

            }

            Item {
                id: mainLayout
                anchors.fill: parent

                QuickCaptureToolbar {
                    id: toolbarCard
                    Component.onCompleted: window.toolbarItem = toolbarCard
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
                    activeColorSlotIndex: window.activeColorSlotIndex

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
                    customAspectRatio: window.customAspectRatio
                    backdropAlignment: window.backdropAlignment
                    backdropColorPickingSlot: window.backdropColorPickingSlot

                    onChangeBackdropMode: (mode) => {
                        window.backdropMode = mode;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropSolidColor: (col) => {
                        window.backdropSolidColor = col;
                        window.hasUserCustomizedBackdrop = true;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onBackdropColorPickerRequested: (currentColor) => {
                        moreToolsMenu.close();
                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                            PopoutService.colorPickerModal.selectedColor = currentColor;
                            PopoutService.colorPickerModal.pickerTitle = I18n.tr("Choose Color");
                            PopoutService.colorPickerModal.onColorSelectedCallback = function (selectedColor) {
                                if (window.backdropMode === "solid") {
                                    window.backdropSolidColor = selectedColor;
                                } else {
                                    const activeSlot = (window.toolbarItem ? window.toolbarItem.gradientActiveSlot : "start");
                                    if (activeSlot === "start") {
                                        window.backdropGradientStart = selectedColor;
                                    } else {
                                        window.backdropGradientEnd = selectedColor;
                                    }
                                }
                                window.hasUserCustomizedBackdrop = true;
                                if (window.activeCanvas) window.activeCanvas.requestPaint();
                            };
                            PopoutService.colorPickerModal.show();
                        }
                    }
                    onBackdropEyedropperRequested: (slot) => {
                        window.backdropColorPickingSlot = slot;
                        window.currentTool = "colorpicker";
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
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeBackdropAlignment: (alignment) => {
                        window.backdropAlignment = alignment;
                        window.requestPaintAll();
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
                        } else if (tool === "colorpicker-draw") {
                            window.colorPickerMode = "draw";
                            window.currentTool = "colorpicker";
                        } else if (tool === "colorpicker-copy") {
                            window.colorPickerMode = "copy";
                            window.currentTool = "colorpicker";
                        } else {
                            window.currentTool = tool;
                        }
                    }
                    onColorSelected: (color, index) => {
                        moreToolsMenu.close();
                        window.activeColorSlotIndex = index;
                        window.currentColor = color;
                    }
                    onCustomColorPickerRequested: (buttonItem) => {
                        moreToolsMenu.close();
                        if (!window.openColorPickerModal()) {
                            if (window.currentTool === "colorpicker") {
                                window.currentTool = window.lastActiveTool;
                            } else {
                                window.colorPickerMode = "draw";
                                window.currentTool = "colorpicker";
                            }
                        }
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
                    onMoreToolsClicked: (buttonItem) => {
                        if (moreToolsMenu.opened) {
                            moreToolsMenu.close();
                        } else {
                            var pt = buttonItem.mapToItem(contentRoot, 0, 0);
                            if (toolbarCard.isVertical) {
                                if (window.toolbarPosition === "right") {
                                    moreToolsMenu.x = pt.x - moreToolsMenu.width - Theme.spacingS;
                                } else {
                                    moreToolsMenu.x = pt.x + buttonItem.width + Theme.spacingS;
                                }
                                moreToolsMenu.y = Math.max(Theme.spacingS, Math.min(pt.y, contentRoot.height - moreToolsMenu.height - Theme.spacingS));
                            } else {
                                moreToolsMenu.x = Math.max(Theme.spacingS, Math.min(pt.x, contentRoot.width - moreToolsMenu.width - Theme.spacingS));
                                if (window.toolbarPosition === "bottom") {
                                    moreToolsMenu.y = pt.y - moreToolsMenu.height - Theme.spacingS;
                                } else {
                                    moreToolsMenu.y = pt.y + buttonItem.height + Theme.spacingS;
                                }
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
                        else if (type === "aspectRatio") popover = backdropAspectRatioPopover;
                        else if (type === "alignment") popover = backdropAlignmentPopover;

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
                        else if (type === "aspectRatio") popover = backdropAspectRatioPopover;
                        else if (type === "alignment") popover = backdropAlignmentPopover;

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
                        } else if (type === "aspectRatio") {
                            if (window.backdropAspectRatio === "custom") {
                                let ratioStep = delta > 0 ? 5 : -5;
                                let scaled = Math.round(window.customAspectRatio * 100) + ratioStep;
                                window.customAspectRatio = Math.max(50, Math.min(250, scaled)) / 100.0;
                            }
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
                            x: window.hasActiveCropSelection ? -window.cropRect.x * window.editScale : 0
                            y: window.hasActiveCropSelection ? -window.cropRect.y * window.editScale : 0
                            
                            // Scale to original size if cropped, otherwise fit to canvas
                            width: window.hasActiveCropSelection ? window.bgImageItem.sourceSize.width * window.editScale : parent.width
                            height: window.hasActiveCropSelection ? window.bgImageItem.sourceSize.height * window.editScale : parent.height
                        }
                    }

                    Canvas {
                        id: bakedCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image
                        z: 1

                        width: window.canvasWidth * window.editScale
                        height: window.canvasHeight * window.editScale

                        layer.enabled: false

                        Component.onCompleted: {
                            window.bakedCanvas = bakedCanvas;
                        }

                        onImageLoaded: {
                            bakedCanvas.requestPaint();
                        }

                        onPaint: {
                            var ctx = bakedCanvas.getContext("2d");
                            ctx.clearRect(0, 0, bakedCanvas.width, bakedCanvas.height);
                            ctx.save();
                            ctx.scale(window.editScale, window.editScale);

                            // 0. Paint Backdrop (if active)
                            const isBackdropActive = window.effectiveBackdropMode !== "none";
                            if (isBackdropActive) {
                                window.drawBackdropBackground(ctx, window.canvasWidth, window.canvasHeight);
                                window.drawScreenshotShadow(ctx);
                                window.drawScreenshotImage(ctx, bgImage);
                            } else if (window.currentTool === "colorpicker") {
                                if (bgImage.status === Image.Ready) {
                                    if (window.hasSelection) {
                                        ctx.drawImage(bgImage, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.canvasWidth, window.canvasHeight);
                                    } else {
                                        ctx.drawImage(bgImage, 0, 0, window.canvasWidth, window.canvasHeight);
                                    }
                                }
                            }

                            // 2. Draw annotations (translated in edit mode, or clipped in crop mode)
                            ctx.save();
                            if (isBackdropActive || window.hasActiveCropSelection) {
                                const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
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
                                const strokes = window.strokes;
                                const selectedStroke = window.selectedStroke;

                                // 2.05 Draw Pixelate strokes BEFORE dimming layer
                                for (let i = 0; i < strokes.length; i++) {
                                    if (strokes[i].tool === "pixelate" && strokes[i] !== selectedStroke) {
                                        drawStroke(ctx, strokes[i]);
                                    }
                                }

                                // 2.1 Draw Spotlight Layer (Dimming + Holes)
                                const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
                                const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
                                const spotlightStrokes = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
                                if (spotlightStrokes.length > 0 && !isDrawingSpotlight && !isEditingSpotlight) {
                                    ctx.save();
                                    const sw = window.screenshotWidth;
                                    const sh = window.screenshotHeight;

                                    const lastSpotlight = spotlightStrokes[spotlightStrokes.length - 1];
                                    const activeInt = lastSpotlight ? lastSpotlight.width : window.spotlightIntensity;
                                    const spotlightOpacity = activeInt / 100.0;

                                    const cropX = hasCropSelection ? window.cropRect.x : 0;
                                    const cropY = hasCropSelection ? window.cropRect.y : 0;

                                    ctx.beginPath();
                                    if (window.effectiveBackdropMode !== "none" && window.backdropCornerRadius > 0) {
                                        const r = Math.min(window.backdropCornerRadius, sw / 2, sh / 2);
                                        ctx.moveTo(cropX + r, cropY);
                                        ctx.lineTo(cropX + sw - r, cropY);
                                        ctx.arcTo(cropX + sw, cropY, cropX + sw, cropY + r, r);
                                        ctx.lineTo(cropX + sw, cropY + sh - r);
                                        ctx.arcTo(cropX + sw, cropY + sh, cropX + sw - r, cropY + sh, r);
                                        ctx.lineTo(cropX + r, cropY + sh);
                                        ctx.arcTo(cropX, cropY + sh, cropX, cropY + sh - r, r);
                                        ctx.lineTo(cropX, cropY + r);
                                        ctx.arcTo(cropX, cropY, cropX + r, cropY, r);
                                        ctx.closePath();
                                    } else {
                                        ctx.rect(cropX, cropY, sw, sh);
                                    }

                                    for (let s of spotlightStrokes) {
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
                                    ctx.fillRect(cropX, cropY, sw, sh);
                                    ctx.restore();
                                }

                                for (let i = 0; i < strokes.length; i++) {
                                    if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate" && strokes[i] !== selectedStroke) {
                                        drawStroke(ctx, strokes[i]);
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
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image

                        z: 2

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

                            // 1. Draw Dimming Selection Overlay (only if in crop/ocr/qr mode)
                            DrawingRenderer.drawSelectionOverlay(ctx, {
                                isCropMode: window.currentTool === "crop",
                                isOcrMode: window.currentTool === "ocr" || window.currentTool === "qr",
                                cropRect: window.cropRect,
                                ocrRect: window.ocrRect,
                                canvasWidth: window.canvasWidth,
                                canvasHeight: window.canvasHeight
                            }, Theme);

                            // 2. Draw active/selected annotations (translated in edit mode, or clipped in crop mode)
                            ctx.save();
                            const isBackdropActive = window.effectiveBackdropMode !== "none";
                            if (isBackdropActive || window.hasActiveCropSelection) {
                                const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
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
                                const strokes = window.strokes;
                                const selectedStroke = window.selectedStroke;

                                // Draw active/selected pixelate stroke
                                if (window.currentStroke && window.currentStroke.tool === "pixelate") {
                                    const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
                                    drawStroke(ctx, tempStroke);
                                }
                                if (selectedStroke && selectedStroke.tool === "pixelate") {
                                    drawStroke(ctx, selectedStroke);
                                }

                                // Draw active/selected spotlight dimming + holes
                                const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
                                const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
                                if (isDrawingSpotlight || isEditingSpotlight) {
                                    const activeSpotlights = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
                                    if (isDrawingSpotlight) activeSpotlights.push(window.currentStroke);
                                    if (isEditingSpotlight) activeSpotlights.push(selectedStroke);

                                    ctx.save();
                                    const sw = window.screenshotWidth;
                                    const sh = window.screenshotHeight;

                                    let activeInt = window.spotlightIntensity;
                                    if (isEditingSpotlight) {
                                        activeInt = selectedStroke.width;
                                    }

                                    const spotlightOpacity = activeInt / 100.0;

                                    const cropX = hasCropSelection ? window.cropRect.x : 0;
                                    const cropY = hasCropSelection ? window.cropRect.y : 0;

                                    ctx.beginPath();
                                    if (window.effectiveBackdropMode !== "none" && window.backdropCornerRadius > 0) {
                                        const r = Math.min(window.backdropCornerRadius, sw / 2, sh / 2);
                                        ctx.moveTo(cropX + r, cropY);
                                        ctx.lineTo(cropX + sw - r, cropY);
                                        ctx.arcTo(cropX + sw, cropY, cropX + sw, cropY + r, r);
                                        ctx.lineTo(cropX + sw, cropY + sh - r);
                                        ctx.arcTo(cropX + sw, cropY + sh, cropX + sw - r, cropY + sh, r);
                                        ctx.lineTo(cropX + r, cropY + sh);
                                        ctx.arcTo(cropX, cropY + sh, cropX, cropY + sh - r, r);
                                        ctx.lineTo(cropX, cropY + r);
                                        ctx.arcTo(cropX, cropY, cropX + r, cropY, r);
                                        ctx.closePath();
                                    } else {
                                        ctx.rect(cropX, cropY, sw, sh);
                                    }

                                    for (let s of activeSpotlights) {
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
                                    ctx.fillRect(cropX, cropY, sw, sh);
                                    ctx.restore();
                                }

                                // Draw active/current stroke
                                if (window.currentStroke && window.currentStroke.tool !== "spotlight" && window.currentStroke.tool !== "pixelate") {
                                    const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
                                    drawStroke(ctx, tempStroke);
                                }

                                // Draw selected stroke
                                if (selectedStroke && selectedStroke.tool !== "spotlight" && selectedStroke.tool !== "pixelate") {
                                    drawStroke(ctx, selectedStroke);
                                }

                                // Draw temporary live typing text
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
                                        const padY = h * 0.15;
                                        const rx = window.typingCoords.x - padX;
                                        const ry = window.typingCoords.y - padY;
                                        const rw = textWidth + padX * 2;
                                        const rh = h + padY * 2;
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
                            ctx.restore();
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
                                if (window.hasActiveCropSelection) {
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
                                 if (window.currentTool === "colorpicker") {
                                     window.hoveredColor = window.sampleCanvasColor(mouse.x, mouse.y);
                                 };
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
                                         if (window.selectedStroke.tool === "redact") {
                                             window.selectedStroke.cachedCleanColor = undefined;
                                         }
                                         drawingCanvas.requestPaint();
                                    } else {
                                        hoveredStrokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    }
                                    return;
                                }

                                if (window.currentTool === "crop") {
                                    const ox = Math.max(0, Math.min(origX, window.screenshotWidth));
                                    const oy = Math.max(0, Math.min(origY, window.screenshotHeight));
                                    if (window.activeHandle === "new") {
                                        const x1 = Math.min(window.selectStart.x, ox);
                                        const y1 = Math.min(window.selectStart.y, oy);
                                        const w = Math.abs(ox - window.selectStart.x);
                                        const h = Math.abs(oy - window.selectStart.y);
                                        window.cropRect = window.clampCropRect(x1, y1, w, h);
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
                                            newX = Math.min(ox, cr.x + cr.width - 10);
                                            newY = Math.min(oy, cr.y + cr.height - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "tr") {
                                            newY = Math.min(oy, cr.y + cr.height - 10);
                                            newW = Math.max(10, ox - cr.x);
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "bl") {
                                            newX = Math.min(ox, cr.x + cr.width - 10);
                                            newW = cr.x + cr.width - newX;
                                            newH = Math.max(10, oy - cr.y);
                                        } else if (window.activeHandle === "br") {
                                            newW = Math.max(10, ox - cr.x);
                                            newH = Math.max(10, oy - cr.y);
                                        } else if (window.activeHandle === "tc") {
                                            newY = Math.min(oy, cr.y + cr.height - 10);
                                            newH = cr.y + cr.height - newY;
                                        } else if (window.activeHandle === "bc") {
                                            newH = Math.max(10, oy - cr.y);
                                        } else if (window.activeHandle === "lc") {
                                            newX = Math.min(ox, cr.x + cr.width - 10);
                                            newW = cr.x + cr.width - newX;
                                        } else if (window.activeHandle === "rc") {
                                            newW = Math.max(10, ox - cr.x);
                                        }
                                        window.cropRect = window.clampCropRect(newX, newY, newW, newH);
                                        drawingCanvas.requestPaint();
                                        return;
                                    }
                                } else if (window.currentTool === "ocr" || window.currentTool === "qr") {
                                    if (window.activeHandle === "ocr" || window.activeHandle === "qr") {
                                        const ox = mouse.x / window.editScale;
                                        const oy = mouse.y / window.editScale;
                                        const x1 = Math.min(window.selectStart.x, ox);
                                        const y1 = Math.min(window.selectStart.y, oy);
                                        const w = Math.abs(ox - window.selectStart.x);
                                        const h = Math.abs(oy - window.selectStart.y);
                                        window.ocrRect = Qt.rect(x1, y1, w, h);
                                        drawingCanvas.requestPaint();
                                    }
                                    return;
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
                                            const pts = window.currentStroke.points;
                                            const lastPt = (pts && pts.length > 0) ? pts[pts.length - 1] : null;
                                            if (!lastPt || Math.abs(absPt.x - lastPt.x) > 2 || Math.abs(absPt.y - lastPt.y) > 2) {
                                                pts.push(absPt);
                                            }
                                        }
                                     } else if (window.currentTool === "rect" || window.currentTool === "ellipse" || window.currentTool === "arrow" || window.currentTool === "line"
                                              || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "highlighter" || window.currentTool === "spotlight" || window.currentTool === "callout") {
                                         
                                         let finalPt = absPt;
                                         if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "line" || window.currentTool === "arrow" || window.currentTool === "highlighter")) {
                                             // Snapping angle calculation (24 directions / 15 degrees)
                                             const p0 = window.currentStroke.points[0];
                                             if (p0) {
                                                 const dx = absPt.x - p0.x;
                                                 const dy = absPt.y - p0.y;
                                                 const L = Math.sqrt(dx * dx + dy * dy);
                                                 if (L > 0) {
                                                     const angle = Math.atan2(dy, dx);
                                                     const SNAP_STEP = Math.PI / 12; // 15 degrees
                                                     const snappedAngle = Math.round(angle / SNAP_STEP) * SNAP_STEP;
                                                     finalPt = Qt.point(p0.x + L * Math.cos(snappedAngle), p0.y + L * Math.sin(snappedAngle));
                                                 }
                                             }
                                         } else if ((mouse.modifiers & Qt.ShiftModifier) && (window.currentTool === "ellipse" || window.currentTool === "rect" || window.currentTool === "redact" || window.currentTool === "pixelate" || window.currentTool === "spotlight" || window.currentTool === "callout")) {
                                             if (window.currentStroke.points[0]) {
                                                 finalPt = window.constrainSquarePoint(window.currentStroke.points[0], absPt);
                                             }
                                         }

                                         if (window.currentStroke.points.length > 1) {
                                              window.currentStroke.points[window.currentStroke.points.length - 1] = finalPt;
                                          } else {
                                              window.currentStroke.points.push(finalPt);
                                          }
                                      } else if (window.currentTool === "stamp") {
                                           const p0 = window.currentStroke.points[0];
                                           if (p0) {
                                               let finalPt = absPt;
                                               const dx = absPt.x - p0.x;
                                               const dy = absPt.y - p0.y;
                                               const dist = Math.sqrt(dx * dx + dy * dy);
                                               if (dist > 10 / window.editScale) {
                                                   window.currentStroke.hasLeaderLine = true;
                                                   
                                                   if (mouse.modifiers & Qt.ShiftModifier) {
                                                       const angle = Math.atan2(dy, dx);
                                                       const SNAP_STEP = Math.PI / 12; // 15 degrees
                                                       const snappedAngle = Math.round(angle / SNAP_STEP) * SNAP_STEP;
                                                       finalPt = Qt.point(p0.x + dist * Math.cos(snappedAngle), p0.y + dist * Math.sin(snappedAngle));
                                                   }

                                                   if (window.currentStroke.points.length > 1) {
                                                       window.currentStroke.points[1] = finalPt;
                                                   } else {
                                                       window.currentStroke.points.push(finalPt);
                                                   }
                                               } else {
                                                   window.currentStroke.hasLeaderLine = false;
                                                   if (window.currentStroke.points.length > 1) {
                                                       window.currentStroke.points = [p0];
                                                   }
                                               }
                                           }
                                       }
                                    drawingCanvas.requestPaint();
                                }
                            }

                            cursorShape: {
                                const h = (window.activeHandle !== "none" && window.activeHandle !== "new") ? window.activeHandle : hoveredHandle;
                                if (h === "tl" || h === "br") return Qt.SizeFDiagCursor;
                                if (h === "tr" || h === "bl") return Qt.SizeBDiagCursor;
                                if (h === "tc" || h === "bc") return Qt.SplitVCursor;
                                if (h === "lc" || h === "rc") return Qt.SplitHCursor;
                                if (window.currentTool === "colorpicker") {
                                    return Qt.CrossCursor;
                                }
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
                                            stampOptionsToolbar.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "text") {
                                            textOptionsToolbar.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "line") {
                                            lineOptionsToolbar.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "arrow") {
                                            arrowOptionsToolbar.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "redact") {
                                            redactOptionsToolbar.open(mapped.x, mapped.y);
                                            return;
                                        } else if (window.currentTool === "callout") {
                                            calloutOptionsToolbar.open(mapped.x, mapped.y);
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
                                        list.splice(strokeIdx, 1);
                                        window.strokes = list;
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
                                            window.preGrabRedactMode = window.activeRedactMode;
                                            window.preGrabCalloutLinkLines = window.calloutLinkLines;
                                        }
                                        
                                        window.selectedStroke = stroke;
                                        window.currentColor = stroke.color;
                                        if (stroke.tool === "line" && stroke.lineStyle) {
                                            window.activeLineStyle = stroke.lineStyle;
                                        }
                                        if (stroke.tool === "arrow") {
                                            if (stroke.arrowLineStyle) window.activeArrowLineStyle = stroke.arrowLineStyle;
                                            if (stroke.arrowHeadStyle) window.activeArrowHeadStyle = stroke.arrowHeadStyle;
                                        }
                                        if (stroke.tool === "redact" && stroke.redactMode) {
                                            window.activeRedactMode = stroke.redactMode;
                                        }
                                        if (stroke.tool === "callout") {
                                            window.calloutLinkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 1;
                                        }

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

                                        // Bring selected stroke to front (move to end of strokes array)
                                        const reorder = [...window.strokes];
                                        reorder.splice(strokeIdx, 1);
                                        reorder.push(stroke);
                                        window.strokes = reorder;
                                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                                    }
                                    return;
                                }

                                 if (window.currentTool === "colorpicker") {
                                      if (mouse.button === Qt.LeftButton) {
                                          const pickedColor = window.sampleCanvasColor(mouse.x, mouse.y);
                                          if (window.backdropColorPickingSlot !== "none") {
                                              if (window.backdropColorPickingSlot === "solid") {
                                                  window.backdropSolidColor = pickedColor;
                                              } else if (window.backdropColorPickingSlot === "start") {
                                                  window.backdropGradientStart = pickedColor;
                                              } else if (window.backdropColorPickingSlot === "end") {
                                                  window.backdropGradientEnd = pickedColor;
                                              }
                                              window.hasUserCustomizedBackdrop = true;
                                              window.backdropColorPickingSlot = "none";
                                              window.currentTool = "backdrop";
                                          } else {
                                              const hexStr = window.formatHexColor(pickedColor).toUpperCase();
                                              if (window.colorPickerMode === "copy") {
                                                  Quickshell.execDetached(["dms", "cl", "copy", hexStr]);
                                                  if (typeof ToastService !== "undefined" && ToastService) {
                                                      ToastService.showInfo(I18n.tr("Color copied to clipboard: %1").arg(hexStr));
                                                  }
                                              } else {
                                                   window.updateColorSlot(window.activeColorSlotIndex, pickedColor);
                                               }
                                               window.currentTool = window.lastActiveTool;
                                          }
                                      }
                                      return;
                                  }

                                if (window.currentTool === "crop") {
                                    const ox = mouse.x / window.editScale;
                                    const oy = mouse.y / window.editScale;
                                    const pw = window.screenshotWidth;
                                    const ph = window.screenshotHeight;
                                    const handle = window.getHoveredHandle(ox, oy);
                                    if (handle !== "none") {
                                        window.activeHandle = handle;
                                        return;
                                    }

                                    // Drag-to-select crop area
                                    window.activeHandle = "new";
                                    window.selectStart = Qt.point(Math.max(0, Math.min(ox, pw)), Math.max(0, Math.min(oy, ph)));
                                    window.cropRect = Qt.rect(window.selectStart.x, window.selectStart.y, 0, 0);
                                    window.hasSelection = false;
                                    drawingCanvas.requestPaint();
                                    return;
                                }

                                if (window.currentTool === "ocr" || window.currentTool === "qr") {
                                    const ox = mouse.x / window.editScale;
                                    const oy = mouse.y / window.editScale;
                                    window.selectStart = Qt.point(ox, oy);
                                    window.ocrRect = Qt.rect(ox, oy, 0, 0);
                                    window.activeHandle = window.currentTool;
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
                                     window.currentStroke = {
                                         id: Date.now() + Math.random(),
                                         tool: "stamp",
                                         color: window.currentColor.toString(),
                                         width: window.strokeWidth,
                                         points: [getAbsolutePoint(mouse.x, mouse.y)],
                                         counter: window.stampCounter,
                                         format: window.stampCounterFormat,
                                         hasLeaderLine: false
                                     };
                                     window.pressCoords = getAbsolutePoint(mouse.x, mouse.y);
                                     if (window.activeCanvas) window.activeCanvas.requestPaint();
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
                                        
                                        const bbox = Helpers.getStrokeBBox(stroke, window.estimateTextWidth);
                                        const pad = 12 + stroke.width * 2;
                                        if (sx >= bbox.minX - pad && sx <= bbox.maxX + pad && sy >= bbox.minY - pad && sy <= bbox.maxY + pad) {
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

                                 window.currentStroke = {
                                     tool: window.currentTool,
                                     color: window.currentColor.toString(),
                                     width: window.activeIntensity,
                                     points: [getAbsolutePoint(mouse.x, mouse.y)],
                                     lineStyle: window.currentTool === "line" ? window.activeLineStyle : "solid",
                                     arrowLineStyle: window.currentTool === "arrow" ? window.activeArrowLineStyle : "solid",
                                     arrowHeadStyle: window.currentTool === "arrow" ? window.activeArrowHeadStyle : "single-filled",
                                     redactMode: window.currentTool === "redact" ? window.activeRedactMode : "solid",
                                     calloutLinkLines: window.currentTool === "callout" ? window.calloutLinkLines : 1
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
                                     window.activeRedactMode = window.preGrabRedactMode;
                                     window.calloutLinkLines = window.preGrabCalloutLinkLines;
                                     window.calloutDestDragging = false;
                                     window.originalPoints = [];
                                     drawingCanvas.requestPaint();
                                     return;
                                }

                                 if (window.currentTool === "crop") {
                                    if (window.activeHandle === "new" || window.activeHandle === "tl" || window.activeHandle === "tr" || window.activeHandle === "bl" || window.activeHandle === "br") {
                                        // Check for accidental click (too small) BEFORE clamping
                                        if (Math.min(window.cropRect.width, window.cropRect.height) <= 3) {
                                            if (window.strokes.length === 0) {
                                                window.discardAndClose();
                                            } else {
                                                window.hasSelection = false;
                                                window.cropRect = Qt.rect(0, 0, 0, 0);
                                            }
                                            return;
                                        }
                                        window.cropRect = window.clampCropRect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
                                        if (Math.min(window.cropRect.width, window.cropRect.height) >= 16) {
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

                                if (window.currentTool === "ocr") {
                                    window.activeHandle = "none";
                                    window.executeOcr();
                                    return;
                                }

                                if (window.currentTool === "qr") {
                                    window.activeHandle = "none";
                                    window.executeQrScan();
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
                                        const visX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                        const visY = window.hasActiveCropSelection ? window.cropRect.y : 0;
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
                                if (stroke.tool === "pen" && stroke.points.length >= 3) {
                                    stroke.points = Helpers.smoothStrokePoints(stroke.points, 6, Qt);

                                    // Auto-close: if start and end are within 20 screen-px, snap closed
                                    if (window.penAutoClose) {
                                        const snapThreshold = 20 / window.editScale;
                                        const fp = stroke.points[0];
                                        const lp = stroke.points[stroke.points.length - 1];
                                        const dx = lp.x - fp.x;
                                        const dy = lp.y - fp.y;
                                        if (Math.sqrt(dx * dx + dy * dy) < snapThreshold) {
                                            stroke.points = [...stroke.points, Qt.point(fp.x, fp.y)];
                                            stroke.isClosed = true;
                                        }
                                    }
                                }
                                 if (stroke.tool === "stamp") {
                                     window.stampCounter++;
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

                        SizePreviewCard {
                            id: sizePreviewItem
                            window: rootWindow
                            drawingCanvas: drawingCanvas
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
                    TextInputDialog {
                        id: textInputDialog
                        window: rootWindow
                        modalFocusScope: modalFocusScope
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

                    MagnifierLoupe {
                        id: magnifier
                        window: rootWindow
                        drawingCanvas: drawingCanvas
                        boardContainer: boardContainer
                        bgImage: bgImage
                        staticBgImage: staticBgImage
                        drawMouseArea: drawMouseArea
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
                                    window.drawStroke(ctx, window.strokes[i]);
                                }
                            }
                            if (window.currentStroke && window.currentStroke.tool === "pixelate") {
                                window.drawStroke(ctx, window.currentStroke);
                            }

                            const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
                            if (window.hasSpotlights || isDrawingSpotlight) {
                                const spotlights = window.strokes.filter(s => s.tool === "spotlight");
                                if (isDrawingSpotlight) {
                                    spotlights.push(window.currentStroke);
                                }

                                if (spotlights.length > 0) {
                                    ctx.save();
                                    
                                    const sw = window.screenshotWidth;
                                    const sh = window.screenshotHeight;
                                    
                                    let activeInt = window.spotlightIntensity;
                                    if (window.currentTool === "select" && window.selectedStroke && window.selectedStroke.tool === "spotlight") {
                                        activeInt = window.selectedStroke.width;
                                    } else {
                                        const lastSpotlight = window.strokes.slice().reverse().find(s => s.tool === "spotlight");
                                        if (lastSpotlight) activeInt = lastSpotlight.width;
                                    }

                                    const spotlightOpacity = activeInt / 100.0;

                                    const cropX = hasCropSelection ? window.cropRect.x : 0;
                                    const cropY = hasCropSelection ? window.cropRect.y : 0;

                                    ctx.beginPath();
                                    // Outer rectangle covering the whole view (rounded if backdrop active)
                                    if (window.effectiveBackdropMode !== "none" && window.backdropCornerRadius > 0) {
                                        const r = Math.min(window.backdropCornerRadius, sw / 2, sh / 2);
                                        ctx.moveTo(cropX + r, cropY);
                                        ctx.lineTo(cropX + sw - r, cropY);
                                        ctx.arcTo(cropX + sw, cropY, cropX + sw, cropY + r, r);
                                        ctx.lineTo(cropX + sw, cropY + sh - r);
                                        ctx.arcTo(cropX + sw, cropY + sh, cropX + sw - r, cropY + sh, r);
                                        ctx.lineTo(cropX + r, cropY + sh);
                                        ctx.arcTo(cropX, cropY + sh, cropX, cropY + sh - r, r);
                                        ctx.lineTo(cropX, cropY + r);
                                        ctx.arcTo(cropX, cropY, cropX + r, cropY, r);
                                        ctx.closePath();
                                    } else {
                                        ctx.rect(cropX, cropY, sw, sh);
                                    }
                                    
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
                                    ctx.fillRect(cropX, cropY, sw, sh);
                                    ctx.restore();
                                }
                            }

                            // 2. Overlay the annotations at full resolution
                            // Draw all completed strokes (except pixelate and spotlight)
                            for (var i = 0; i < window.strokes.length; i++) {
                                if (window.strokes[i].tool !== "pixelate" && window.strokes[i].tool !== "spotlight") {
                                    window.drawStroke(ctx, window.strokes[i]);
                                }
                            }
                            // Draw current dragging stroke if any
                            if (window.currentStroke && window.currentStroke.tool !== "pixelate" && window.currentStroke.tool !== "spotlight") {
                                window.drawStroke(ctx, window.currentStroke);
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

                TextOptionsToolbar {
                    id: textOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    boldActive: window.textBold
                    italicActive: window.textItalic
                    underlineActive: window.textUnderline
                    backgroundActive: window.textBackground
                    onBoldToggled: window.textBold = !window.textBold
                    onItalicToggled: window.textItalic = !window.textItalic
                    onUnderlineToggled: window.textUnderline = !window.textUnderline
                    onBackgroundToggled: window.textBackground = !window.textBackground
                }

                StampOptionsToolbar {
                    id: stampOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentFormat: window.stampCounterFormat
                    onFormatSelected: (format) => window.stampCounterFormat = format
                }

                LineOptionsToolbar {
                    id: lineOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentStyle: window.activeLineStyle
                    onStyleSelected: (style) => window.activeLineStyle = style
                }

                ArrowOptionsToolbar {
                    id: arrowOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentLineStyle: window.activeArrowLineStyle
                    currentHeadStyle: window.activeArrowHeadStyle
                    onLineStyleSelected: (style) => window.activeArrowLineStyle = style
                    onHeadStyleSelected: (style) => window.activeArrowHeadStyle = style
                }

                RedactOptionsToolbar {
                    id: redactOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentMode: window.activeRedactMode
                    onModeSelected: (mode) => window.activeRedactMode = mode
                }

                CalloutOptionsToolbar {
                    id: calloutOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentLinkLines: window.calloutLinkLines
                    onLinkLinesSelected: (count) => window.calloutLinkLines = count
                }

                MoreToolsMenu {
                    id: moreToolsMenu
                    onRotateRequested: window.rotateScreenshot()
                    onMirrorRequested: window.mirrorScreenshot()
                    onOcrRequested: window.runOcr()
                    onQrScanRequested: window.runQrScan()
                    onEraserRequested: window.currentTool = "eraser"
                    onCopyColorRequested: {
                        window.colorPickerMode = "copy";
                        window.currentTool = "colorpicker";
                    }
                }



                PaletteWarningDialog {
                    id: paletteWarningDialog
                    Component.onCompleted: window.paletteWarningDialogRef = paletteWarningDialog
                    currentPaletteColors: toolbarCard.toolbarPalette
                    customPaletteColors: {
                        var customList = [];
                        var primaryRaw = config.pluginData["toolbar_color_primary"] || "primary";
                        var primaryColor = primaryRaw === "primary" ? Theme.primary : primaryRaw;
                        customList.push(typeof primaryColor === "string" ? Qt.color(primaryColor) : primaryColor);
                        for (var i = 0; i < 7; i++) {
                            var val = config.pluginData["toolbar_color_" + i] || config.adaptiveColors[i];
                            customList.push(typeof val === "string" ? Qt.color(val) : val);
                        }
                        return customList;
                    }
                    onCopyAndSwitch: {
                        window.switchPresetToCustom(true);
                    }
                    onSwitchOnly: {
                        window.switchPresetToCustom(false);
                    }
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

                BackdropAspectRatioPopover {
                    id: backdropAspectRatioPopover
                    backdropAspectRatio: window.backdropAspectRatio
                    customAspectRatio: window.customAspectRatio
                    presets: window.aspectPresets
                    onChangeBackdropAspectRatio: (ratio) => {
                        window.backdropAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                        if (window.activeCanvas) window.activeCanvas.requestPaint();
                    }
                }

                BackdropAlignmentPopover {
                    id: backdropAlignmentPopover
                    backdropAlignment: window.backdropAlignment
                    onChangeBackdropAlignment: (alignment) => {
                        window.backdropAlignment = alignment;
                        window.requestPaintAll();
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
                        }
                    }
                }

                Canvas {
                    id: offscreenSampler
                    visible: false
                    width: window.bgImageItem ? window.bgImageItem.sourceSize.width : 1
                    height: window.bgImageItem ? window.bgImageItem.sourceSize.height : 1
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.drawImage(bgImage, 0, 0, width, height);
                    }
                    Component.onCompleted: {
                        window.offscreenSamplerItem = offscreenSampler;
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
            list.pop();
            window.strokes = list;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    function discardAndClose() {
        window.close();
    }
}
