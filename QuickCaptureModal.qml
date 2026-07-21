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
    property string activeRedactShape: window.roundRect ? "roundRect" : "rect" // rect, roundRect, ellipse
    onActiveRedactShapeChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "redact") {
            window.selectedStroke.redactShape = window.activeRedactShape;
            window.selectedStroke.cachedCleanColor = undefined;
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                window.strokes[idx] = window.selectedStroke;
                window.strokes = [...window.strokes];
            }
        }
        if (window.currentStroke && window.currentStroke.tool === "redact") {
            window.currentStroke.redactShape = window.activeRedactShape;
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
        if (currentTool !== "select" && window.selectedStroke) {
            const restoreColor = window.preGrabColor;
            window.selectedStroke = null;
            window.originalPoints = [];
            window.strokeWidth = window.preGrabStrokeWidth;
            window.textFontSize = window.preGrabTextFontSize;
            window.pixelateIntensity = window.preGrabPixelateIntensity;
            window.spotlightIntensity = window.preGrabSpotlightIntensity;
            window.calloutZoom = window.preGrabCalloutZoom;
            window.currentColor = restoreColor;
            window.activeRedactMode = window.preGrabRedactMode;
            window.activeRedactShape = window.preGrabRedactShape;
            window.calloutLinkLines = window.preGrabCalloutLinkLines;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
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
        if (currentTool === "select" && !window.selectedStroke && window.strokes.length > 0) {
            const s = window.strokes[window.strokes.length - 1];
            window.preGrabStrokeWidth = window.strokeWidth;
            window.preGrabTextFontSize = window.textFontSize;
            window.preGrabPixelateIntensity = window.pixelateIntensity;
            window.preGrabSpotlightIntensity = window.spotlightIntensity;
            window.preGrabCalloutZoom = window.calloutZoom;
            window.preGrabColor = window.currentColor;
            window.preGrabRedactMode = window.activeRedactMode;
            window.preGrabRedactShape = window.activeRedactShape;
            window.preGrabCalloutLinkLines = window.calloutLinkLines;
            window.selectedStroke = s;
            window.currentColor = s.color;
            if (s.tool === "text") window.textFontSize = s.width;
            else if (s.tool === "pixelate") window.pixelateIntensity = s.width;
            else if (s.tool === "spotlight") window.spotlightIntensity = s.width;
            else if (s.tool === "callout") window.calloutZoom = s.width;
            else window.strokeWidth = s.width;
            if (s.tool === "line" && s.lineStyle) window.activeLineStyle = s.lineStyle;
            if (s.tool === "arrow") {
                if (s.arrowLineStyle) window.activeArrowLineStyle = s.arrowLineStyle;
                if (s.arrowHeadStyle) window.activeArrowHeadStyle = s.arrowHeadStyle;
            }
            if (s.tool === "redact" && s.redactMode) window.activeRedactMode = s.redactMode;
            if (s.tool === "redact" && s.redactShape) window.activeRedactShape = s.redactShape;
            if (s.tool === "callout") window.calloutLinkLines = s.calloutLinkLines !== undefined ? s.calloutLinkLines : 1;
            const reorder = [...window.strokes];
            const idx = reorder.indexOf(s);
            if (idx !== -1) {
                reorder.splice(idx, 1);
                reorder.push(s);
            }
            window.strokes = reorder;
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
    property var customBackdropPresets: []
    property var hiddenPresetIds: []
    readonly property var backdropPresets: {
        var customMap = {};
        if (customBackdropPresets) {
            for (var i = 0; i < customBackdropPresets.length; i++) {
                var cp = customBackdropPresets[i];
                customMap[cp.id] = cp;
            }
        }

        var list = [];
        if (Constants && Constants.defaultBackdropPresets) {
            for (var j = 0; j < Constants.defaultBackdropPresets.length; j++) {
                var dp = Constants.defaultBackdropPresets[j];
                if (!hiddenPresetIds || hiddenPresetIds.indexOf(dp.id) === -1) {
                    if (customMap[dp.id]) {
                        list.push(customMap[dp.id]);
                    } else {
                        list.push(dp);
                    }
                }
            }
        }
        if (customBackdropPresets) {
            for (var k = 0; k < customBackdropPresets.length; k++) {
                var up = customBackdropPresets[k];
                if (up.isCustomUserCreated && (!hiddenPresetIds || hiddenPresetIds.indexOf(up.id) === -1)) {
                    list.push(up);
                }
            }
        }
        return list;
    }

    // Intensity Management
    property real penSmoothingAlpha: 0.4
    property int strokeWidth: 8
    property int pixelateIntensity: 8
    property bool pixelateRandomize: true
    onPixelateRandomizeChanged: {
        if (window.selectedStroke && window.selectedStroke.tool === "pixelate") {
            window.selectedStroke.randomize = window.pixelateRandomize;
            if (window.pixelateRandomize && window.selectedStroke.randomSeed === undefined) {
                window.selectedStroke.randomSeed = Math.floor(Math.random() * 2147483647);
            }
            const idx = window.strokes.indexOf(window.selectedStroke);
            if (idx !== -1) {
                const list = [...window.strokes];
                list[idx] = window.selectedStroke;
                window.strokes = list;
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }
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
    property int stampIdCounter: 1
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
        // When backdrop is active, render at screen resolution for sharp preview
        if (window.effectiveBackdropMode !== "none") return Math.max(1e-3, window.fitScale);
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
        
        const opacity = (window.backdropShadowStrength / 100.0) * Constants.shadowBaseOpacityFactor;
        const STEPS = Constants.defaultShadowSteps;
        const maxOffset = Constants.maxShadowOffset;
        const maxBlur = Constants.maxShadowBlur;
        
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
    property string preGrabRedactShape: "rect"
    property int preGrabCalloutLinkLines: 1
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

    // Text Input Management
    property bool isTyping: false
    onIsTypingChanged: {
        if (isTyping) {
            typingCursorVisible = true;
        }
    }
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""
    property int typingCursorIndex: 0
    property bool typingCursorVisible: true
    property var editingStroke: null
    property bool typingIsSpeechBubble: false
    property point typingTargetCoords: Qt.point(0,0)

    Timer {
        id: typingCursorTimer
        interval: 500
        repeat: true
        running: window.isTyping
        onTriggered: {
            window.typingCursorVisible = !window.typingCursorVisible;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
    }

    backgroundOpacity: {
        const data = window.parentWidget && window.parentWidget.pluginData;
        if (!data) return 0.6;
        if (data.overlayOpacity !== undefined) return data.overlayOpacity / 100;
        if (data.modalOpacity !== undefined) return data.modalOpacity / 100;
        return 0.6;
    }
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

    readonly property var pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})

    readonly property bool textMonospace: pluginData.textMonospace !== undefined ? pluginData.textMonospace : false
    
    // Rich Text Options
    property bool textBold: pluginData.textBold !== undefined ? pluginData.textBold : false
    onTextBoldChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textItalic: pluginData.textItalic !== undefined ? pluginData.textItalic : false
    onTextItalicChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textUnderline: pluginData.textUnderline !== undefined ? pluginData.textUnderline : false
    onTextUnderlineChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property bool textBackground: pluginData.textBackground !== undefined ? pluginData.textBackground : false
    onTextBackgroundChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property int textCornerRadius: pluginData.textCornerRadius !== undefined ? pluginData.textCornerRadius : 8
    onTextCornerRadiusChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    property string textFontFamily: (pluginData.textFontFamily && pluginData.textFontFamily !== "system") ? pluginData.textFontFamily : (textMonospace ? "monospace" : (Theme.fontFamily || "sans-serif"))
    onTextFontFamilyChanged: {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }
    readonly property string textInputMode: pluginData.textInputMode !== undefined ? pluginData.textInputMode : "inline"
    readonly property string toolbarPosition: pluginData.toolbarPosition !== undefined ? pluginData.toolbarPosition : "bottom"
    readonly property bool configShowToolbar: pluginData.showToolbar !== undefined ? pluginData.showToolbar : true
    readonly property bool enableMagnifier: true
    property bool toolbarVisible: true
    onConfigShowToolbarChanged: {
        window.toolbarVisible = window.configShowToolbar;
    }

    function rotateScreenshot(direction) {
        const isLeft = (direction === "left");
        const originalW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const originalH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;

        let bgPath = "";
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

        if (!bgPath) return;
        const degrees = isLeft ? "270" : "90";
        Proc.runCommand("rotate-image", ["mogrify", "-rotate", degrees, bgPath], (stdout, exitCode) => {
            if (exitCode === 0) {
                if (window.hasSelection) {
                    const cx = window.cropRect.x;
                    const cy = window.cropRect.y;
                    const cw = window.cropRect.width;
                    const ch = window.cropRect.height;
                    if (isLeft) {
                        window.cropRect = Qt.rect(cy, originalW - (cx + cw), ch, cw);
                    } else {
                        window.cropRect = Qt.rect(originalH - (cy + ch), cx, ch, cw);
                    }
                }

                const list = [...window.strokes];
                for (let s of list) {
                    if (s.points) {
                        s.points = s.points.map(p => ({
                            x: isLeft ? p.y : originalH - p.y,
                            y: isLeft ? originalW - p.x : p.x
                        }));
                    }
                }
                window.strokes = list;

                window.bgImageSource = "";
                window.bgImageSource = "file://" + bgPath + "?t=" + Date.now();
            }
        });
    }

    function mirrorScreenshot(direction) {
        const isVertical = (direction === "vertical" || direction === "v");
        const originalW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const originalH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;

        let bgPath = "";
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

        if (!bgPath) return;
        const flag = isVertical ? "-flip" : "-flop";
        Proc.runCommand("mirror-image", ["mogrify", flag, bgPath], (stdout, exitCode) => {
            if (exitCode === 0) {
                if (window.hasSelection) {
                    const cx = window.cropRect.x;
                    const cy = window.cropRect.y;
                    const cw = window.cropRect.width;
                    const ch = window.cropRect.height;
                    if (isVertical) {
                        window.cropRect = Qt.rect(cx, originalH - (cy + ch), cw, ch);
                    } else {
                        window.cropRect = Qt.rect(originalW - (cx + cw), cy, cw, ch);
                    }
                }

                const list = [...window.strokes];
                for (let s of list) {
                    if (s.points) {
                        s.points = s.points.map(p => ({
                            x: isVertical ? p.x : originalW - p.x,
                            y: isVertical ? originalH - p.y : p.y
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
    
    // Modal sized to the screenshot (logical px), clamped between the toolbar's
    // footprint and 90% of the screen; falls back to 90% until the image loads
    readonly property real _screenW: window.targetScreen ? window.targetScreen.width : (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920)
    readonly property real _screenH: window.targetScreen ? window.targetScreen.height : (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080)
    readonly property real _maxModalW: Math.round((config.modalAspectRatio === "portrait" ? Math.min(_screenW, _screenH) : Math.max(_screenW, _screenH)) * 0.9)
    readonly property real _maxModalH: Math.round((config.modalAspectRatio === "portrait" ? Math.max(_screenW, _screenH) : Math.min(_screenW, _screenH)) * 0.9)
    readonly property bool _toolbarHorizontal: window.toolbarPosition === "top" || window.toolbarPosition === "bottom"
    // Chrome = boardContainer margins plus the edge the toolbar occupies (56px rail + its margin)
    readonly property real _chromeW: Theme.spacingM * 2 + (window.toolbarVisible && !_toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _chromeH: Theme.spacingM * 2 + (window.toolbarVisible && _toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _minModalW: _toolbarHorizontal && window.toolbarItem && window.toolbarItem.width ? window.toolbarItem.width + Theme.spacingM * 2 : 400
    readonly property real _minModalH: !_toolbarHorizontal && window.toolbarItem && window.toolbarItem.height ? window.toolbarItem.height + Theme.spacingM * 2 : 300
    readonly property bool _bgSizeKnown: window.bgImageItem
                                         && window.bgImageItem.status === Image.Ready
                                         && window.bgImageItem.sourceSize.width > 0
                                         && window.bgImageItem.sourceSize.height > 0
    // Compositor scale (not Screen.devicePixelRatio, which reports the integer buffer scale)
    readonly property real _outputScale: (window.targetScreen && CompositorService.getScreenScale(window.targetScreen)) || 1
    readonly property bool _shouldScale: !!(window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.modalScaleToContent)
    modalWidth: _shouldScale && _bgSizeKnown ? Math.round(Math.min(_maxModalW, Math.max(_minModalW, window.bgImageItem.sourceSize.width / _outputScale + _chromeW))) : _maxModalW
    modalHeight: _shouldScale && _bgSizeKnown ? Math.round(Math.min(_maxModalH, Math.max(_minModalH, window.bgImageItem.sourceSize.height / _outputScale + _chromeH))) : _maxModalH
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
        Helpers.copyStrokeProperties(window.copiedStroke, pasted);
        window.pushStroke(pasted);
        
        if (window.currentTool === "select") {
            window.preGrabStrokeWidth = window.strokeWidth;
            window.preGrabColor = window.currentColor;
            window.preGrabRedactMode = window.activeRedactMode;
            window.preGrabRedactShape = window.activeRedactShape;
            window.preGrabCalloutLinkLines = window.calloutLinkLines;
            window.strokeWidth = pasted.width;
            window.currentColor = pasted.color;
            if (pasted.tool === "redact" && pasted.redactMode) window.activeRedactMode = pasted.redactMode;
            if (pasted.tool === "redact" && pasted.redactShape) window.activeRedactShape = pasted.redactShape;
            window.selectedStroke = pasted;
            window.pressCoords = absPt;
            window.originalPoints = newPoints;
        }
        
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function getPresetTool(index) {
        const val = window.pluginData["preset_" + index + "_tool"];
        return val !== undefined ? val : (Constants.defaultRadialTools[index] || "none");
    }

    function getPresetColor(index) {
        const val = window.pluginData["preset_" + index + "_color"];
        if (val !== undefined) return val;
        const defaultColors = ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"];
        return defaultColors[index] || "primary";
    }

    function getPresetThickness(index) {
        const val = window.pluginData["preset_" + index + "_thickness"];
        return val !== undefined ? (parseInt(val, 10) || 6) : 6;
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
    readonly property bool penAutoClose: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.penAutoClose !== undefined ? window.parentWidget.pluginData.penAutoClose : false

    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property rect ocrRect: Qt.rect(0, 0, 0, 0)
    property var exportCallback: null

    property var restoreState: null
    property string restoreSource: ""
    property string currentCapturePath: ""
    property var floatService: null

    Connections {
        target: window.floatService
        function onRestoreRequested(imageSource, annotationState) {
            window.restoreSource = imageSource;
            window.restoreState = annotationState;
            window.shouldBeVisible = true;
            window.open();
        }
    }

    QuickCaptureActions {
        id: captureActions
        parentWidget: window.parentWidget
        modal: window
        exportAndExecute: window.exportAndExecute
        floatService: window.floatService
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

    function estimateTextWidth(text, fontSize, isBold, isMonospace) {
        return Helpers.estimateTextWidth(text, fontSize, isBold, isMonospace);
    }

    function findStrokeAt(mx, my) {
        return Helpers.findStrokeAt(mx, my, window.strokes, window.estimateTextWidth);
    }

    function getSelectedStrokeHandleAt(mx, my) {
        if (!window.selectedStroke) return "none";
        return Helpers.getStrokeHandleAt(mx, my, window.selectedStroke, window.estimateTextWidth);
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
        if (window.hasSelection && window.effectiveBackdropMode === "none") {
            window.exportCanvasItem.width = window.cropRect.width / window.dpr;
            window.exportCanvasItem.height = window.cropRect.height / window.dpr;
        } else if (window.activeCanvas) {
            window.exportCanvasItem.width = window.canvasWidth / window.dpr;
            window.exportCanvasItem.height = window.canvasHeight / window.dpr;
        }
        window.exportCanvasItem.requestPaint();
    }

    function formatHexColor(color) { return Helpers.formatHexColor(color); }

    function reindexStamps() {
        let stamps = [];
        for (let i = 0; i < window.strokes.length; i++) {
            let stroke = window.strokes[i];
            if (stroke && stroke.tool === "stamp") {
                if (stroke.id === undefined) {
                    stroke.id = window.stampIdCounter++;
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
        const canvas = window.bakedCanvas || window.activeCanvas;
        if (!canvas) return window.currentColor;
        
        // Clamp and round coordinates to prevent out-of-bounds errors and ensure integer coordinates in device pixels
        const x = Helpers.clamp(Math.floor(mouseX * window.dpr), 0, Math.floor(canvas.width * window.dpr) - 1);
        const y = Helpers.clamp(Math.floor(mouseY * window.dpr), 0, Math.floor(canvas.height * window.dpr) - 1);
        
        // Performance optimization: skip sampling if the pixel coordinates haven't changed
        if (window._lastSampledX === x && window._lastSampledY === y) {
            return window._lastSampledColor || window.currentColor;
        }
        
        try {
            const ctx = canvas.getContext("2d");
            if (!ctx) return window.currentColor;
            
            const imgData = ctx.getImageData(x, y, 1, 1);
            if (imgData && imgData.data && imgData.data.length >= 4) {
                const r = imgData.data[0];
                const g = imgData.data[1];
                const b = imgData.data[2];
                const a = imgData.data[3];
                
                let pickedColor;
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

    function handleTypingKey(event) {
        window.typingCursorVisible = true;
        typingCursorTimer.restart();

        if (event.key === Qt.Key_Escape) {
            window.editingStroke = null;
            window.isTyping = false;
            window.currentTypingText = "";
            window.typingCursorIndex = 0;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (event.modifiers & Qt.ShiftModifier) {
                const txt = window.currentTypingText;
                const idx = Math.max(0, Math.min(txt.length, window.typingCursorIndex));
                window.currentTypingText = txt.slice(0, idx) + "\n" + txt.slice(idx);
                window.typingCursorIndex = idx + 1;
                if (window.activeCanvas) window.activeCanvas.requestPaint();
                event.accepted = true;
                return;
            }
            window.commitTypingText();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Left) {
            const len = window.currentTypingText.length;
            window.typingCursorIndex = Math.max(0, Math.min(len, window.typingCursorIndex) - 1);
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Right) {
            const len = window.currentTypingText.length;
            window.typingCursorIndex = Math.min(len, Math.max(0, window.typingCursorIndex) + 1);
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Home) {
            window.typingCursorIndex = 0;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_End) {
            window.typingCursorIndex = window.currentTypingText.length;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            const txt = window.currentTypingText;
            const idx = Math.max(0, Math.min(txt.length, window.typingCursorIndex));
            if (idx > 0) {
                window.currentTypingText = txt.slice(0, idx - 1) + txt.slice(idx);
                window.typingCursorIndex = idx - 1;
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Delete) {
            const txt = window.currentTypingText;
            const idx = Math.max(0, Math.min(txt.length, window.typingCursorIndex));
            if (idx < txt.length) {
                window.currentTypingText = txt.slice(0, idx) + txt.slice(idx + 1);
                window.typingCursorIndex = idx;
                if (window.activeCanvas) window.activeCanvas.requestPaint();
            }
            event.accepted = true;
            return;
        }
        if (event.text && event.text.length > 0 && !(event.modifiers & Qt.ControlModifier) && !(event.modifiers & Qt.AltModifier)) {
            const txt = window.currentTypingText;
            const idx = Math.max(0, Math.min(txt.length, window.typingCursorIndex));
            const insertStr = event.text;
            window.currentTypingText = txt.slice(0, idx) + insertStr + txt.slice(idx);
            window.typingCursorIndex = idx + insertStr.length;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            event.accepted = true;
        }
    }

    function handleShortcutKey(event) {
        const token = Helpers.shortcutToken(event.key, Qt);
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
                Helpers.copyStrokeProperties(window.selectedStroke, window.copiedStroke);
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
            const colorShortcut = Helpers.findByKey(config.colorShortcuts, token);
            if (colorShortcut) {
                let idx = config.colorShortcuts.indexOf(colorShortcut);
                if (idx !== -1) {
                    window.activeColorSlotIndex = idx;
                }
                window.currentColor = colorShortcut.color === "primary" ? Theme.primary : colorShortcut.color;
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

        const toolShortcut = Helpers.findByKey(config.toolShortcuts, token);
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
            } else if (event.key !== Qt.Key_Escape) {
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
        window.selectedStroke = null;
        window.copiedStroke = null;
        window.stampCounter = 1;
        window.stampIdCounter = 1;
        window.bgImageSource = "";
        if (window.restoreSource) {
            window.bgImageSource = window.restoreSource;
        } else if (window.currentCapturePath) {
            window.bgImageSource = "file://" + window.currentCapturePath;
            // currentCapturePath is consumed in onDialogClosed to survive re-fires during screen changes
        }
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
        window.backdropAlignment = backdropConfigValue("backdropDefaultAlignment", Constants.defaultBackdropAlignment, false);
        window.cropRect = Qt.rect(0, 0, 0, 0);
        window.hasSelection = false;
        window.activeHandle = "none";

        // Restore state from FloatService if returning from float window
        if (window.restoreState) {
            const data = window.restoreState;
            if (data.strokes) {
                const restoredStrokes = [];
                for (let rsi = 0; rsi < data.strokes.length; rsi++) {
                    const rs = data.strokes[rsi];
                    const stroke = {
                        tool: rs.tool,
                        color: rs.color,
                        width: rs.width,
                        points: rs.points ? rs.points.map(p => Qt.point(p.x, p.y)) : []
                    };
                    Helpers.copyStrokeProperties(rs, stroke);
                    restoredStrokes.push(stroke);
                }
                window.strokes = restoredStrokes;
            }
            if (data.originalBackground) {
                window.bgImageSource = data.originalBackground;
            }
            if (data.stampCounter !== undefined) {
                window.stampCounter = data.stampCounter;
            }
            if (data.cropRect) {
                window.cropRect = Qt.rect(data.cropRect.x, data.cropRect.y, data.cropRect.width, data.cropRect.height);
                window.hasSelection = (data.cropRect.width > 0 && data.cropRect.height > 0);
            }
            if (data.backdropMode !== undefined) {
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
            if (data.user_backdrop_presets) {
                try {
                    const parsed = JSON.parse(data.user_backdrop_presets);
                    if (Array.isArray(parsed)) window.customBackdropPresets = parsed;
                } catch (e) {
                    console.error("Failed to parse user_backdrop_presets:", e);
                }
            }
            if (data.hidden_backdrop_presets) {
                try {
                    const parsed = JSON.parse(data.hidden_backdrop_presets);
                    if (Array.isArray(parsed)) window.hiddenPresetIds = parsed;
                } catch (e) {
                    console.error("Failed to parse hidden_backdrop_presets:", e);
                }
            }
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            window.restoreState = null;
            window.restoreSource = "";
        }

        Qt.callLater(() => {
            if (modalFocusScope) modalFocusScope.forceActiveFocus();
        });
    }

    function applyBackdropPreset(preset) {
        if (!preset) return;
        if (preset.mode !== undefined) window.backdropMode = preset.mode;
        if (preset.solidColor !== undefined) window.backdropSolidColor = preset.solidColor;
        if (preset.gradientStart !== undefined) window.backdropGradientStart = preset.gradientStart;
        if (preset.gradientEnd !== undefined) window.backdropGradientEnd = preset.gradientEnd;
        if (preset.gradientAngle !== undefined) window.backdropGradientAngle = preset.gradientAngle;
        if (preset.padding !== undefined) window.backdropPadding = preset.padding;
        if (preset.cornerRadius !== undefined) window.backdropCornerRadius = preset.cornerRadius;
        if (preset.shadowStrength !== undefined) window.backdropShadowStrength = preset.shadowStrength;
        if (preset.aspectRatio !== undefined) window.backdropAspectRatio = preset.aspectRatio;
        if (preset.customAspectRatio !== undefined) window.customAspectRatio = preset.customAspectRatio;
        window.hasUserCustomizedBackdrop = true;
        window.requestPaintAll();
    }

    function saveCurrentBackdropAsPreset() {
        const idx = window.customBackdropPresets.length + 1;
        const newPreset = {
            id: "custom_" + Date.now(),
            name: "Custom " + idx,
            mode: window.backdropMode,
            solidColor: window.backdropSolidColor.toString(),
            gradientStart: window.backdropGradientStart.toString(),
            gradientEnd: window.backdropGradientEnd.toString(),
            gradientAngle: window.backdropGradientAngle,
            padding: window.backdropPadding,
            cornerRadius: window.backdropCornerRadius,
            shadowStrength: window.backdropShadowStrength,
            aspectRatio: window.backdropAspectRatio,
            customAspectRatio: window.customAspectRatio,
            isCustomUserCreated: true
        };
        const newList = [...window.customBackdropPresets, newPreset];
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
    }

    function deletePreset(presetId) {
        if (!presetId) return;
        const newCustom = window.customBackdropPresets.filter(p => p.id !== presetId);
        const newHidden = window.hiddenPresetIds.indexOf(presetId) === -1 ? [...window.hiddenPresetIds, presetId] : window.hiddenPresetIds;
        window.customBackdropPresets = newCustom;
        window.hiddenPresetIds = newHidden;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newCustom));
            window.parentWidget.pluginService.savePluginData("quickCapture", "hidden_backdrop_presets", JSON.stringify(newHidden));
        }
    }

    function updatePresetWithCurrent(presetId) {
        if (!presetId) return;
        const currentData = {
            mode: window.backdropMode,
            solidColor: window.backdropSolidColor.toString(),
            gradientStart: window.backdropGradientStart.toString(),
            gradientEnd: window.backdropGradientEnd.toString(),
            gradientAngle: window.backdropGradientAngle,
            padding: window.backdropPadding,
            cornerRadius: window.backdropCornerRadius,
            shadowStrength: window.backdropShadowStrength,
            aspectRatio: window.backdropAspectRatio,
            customAspectRatio: window.customAspectRatio
        };

        const existingIdx = window.customBackdropPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackdropPresets.map(p => p.id === presetId ? Object.assign({}, p, currentData) : p);
        } else {
            const original = Constants.defaultBackdropPresets ? Constants.defaultBackdropPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, currentData);
                newList = [...window.customBackdropPresets, updated];
            } else {
                newList = window.customBackdropPresets;
            }
        }
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
    }

    function renamePreset(presetId, newName) {
        if (!presetId || !newName) return;
        const existingIdx = window.customBackdropPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackdropPresets.map(p => p.id === presetId ? Object.assign({}, p, { name: newName }) : p);
        } else {
            const original = Constants.defaultBackdropPresets ? Constants.defaultBackdropPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, { name: newName });
                newList = [...window.customBackdropPresets, updated];
            } else {
                newList = window.customBackdropPresets;
            }
        }
        window.customBackdropPresets = newList;
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", "user_backdrop_presets", JSON.stringify(newList));
        }
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
                        // bakedCanvas must also call loadImage so its onImageLoaded fires
                        // and triggers requestPaint — without this the background is never drawn
                        if (window.bakedCanvas) {
                            window.bakedCanvas.unloadImage(source);
                            window.bakedCanvas.loadImage(source);
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
                        if (window.modalFocusScope) window.modalFocusScope.forceActiveFocus();
                    }
                    onColorSelected: (color, index) => {
                        moreToolsMenu.close();
                        window.activeColorSlotIndex = index;
                        window.currentColor = color;
                        if (window.modalFocusScope) window.modalFocusScope.forceActiveFocus();
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
                            const pt = buttonItem.mapToItem(contentRoot, 0, 0);
                            if (toolbarCard.isVertical) {
                                if (window.toolbarPosition === "right") {
                                    moreToolsMenu.x = pt.x - moreToolsMenu.width - Theme.spacingS;
                                } else {
                                    moreToolsMenu.x = pt.x + buttonItem.width + Theme.spacingS;
                                }
                                const targetY = pt.y + (buttonItem.height - moreToolsMenu.height) / 2;
                                moreToolsMenu.y = Math.max(Theme.spacingS, Math.min(targetY, contentRoot.height - moreToolsMenu.height - Theme.spacingS));
                            } else {
                                const targetX = pt.x + (buttonItem.width - moreToolsMenu.width) / 2;
                                moreToolsMenu.x = Math.max(Theme.spacingS, Math.min(targetX, contentRoot.width - moreToolsMenu.width - Theme.spacingS));
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
                        else if (type === "presets") popover = backdropPresetsPopover;

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
                                    // Popover above control: use anchor binding so height changes don't overlap toolbar
                                    if (popover._anchorIsAbove !== undefined) {
                                        popover._anchorY = pt.y;
                                        popover._anchorIsAbove = true;
                                    } else {
                                        popover.y = pt.y - popover.height - Theme.spacingXS;
                                    }
                                } else {
                                    // Popover below control: use anchor binding so height changes don't overlap toolbar
                                    if (popover._anchorIsAbove !== undefined) {
                                        popover._anchorY = pt.y + controlItem.height + Theme.spacingXS;
                                        popover._anchorIsAbove = false;
                                    } else {
                                        popover.y = pt.y + controlItem.height + Theme.spacingXS;
                                    }
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
                        else if (type === "presets") popover = backdropPresetsPopover;

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

                                    const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                    const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;

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
                                    if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate" && strokes[i] !== selectedStroke && (!window.isTyping || strokes[i] !== window.editingStroke)) {
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

                                    const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                    const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;

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
                                if (selectedStroke && selectedStroke.tool !== "spotlight" && selectedStroke.tool !== "pixelate" && (!window.isTyping || selectedStroke !== window.editingStroke)) {
                                    drawStroke(ctx, selectedStroke);
                                }

                                // Draw selection resize handles in select mode
                                if (selectedStroke && window.currentTool === "select") {
                                    DrawingRenderer.drawSelectionHandles(ctx, selectedStroke, Theme, window.estimateTextWidth, Qt, Helpers);
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

                                    const rawText = window.currentTypingText || "";
                                    const previewLines = rawText.split("\n");
                                    const lineH = window.textFontSize * 1.35;

                                    if (window.textBackground) {
                                        let maxW = 0;
                                        for (let li = 0; li < previewLines.length; li++) {
                                            const m = ctx.measureText(previewLines[li]);
                                            if (m.width > maxW) maxW = m.width;
                                        }
                                        if (maxW === 0) maxW = Math.max(10, window.textFontSize * 0.4);
                                        const h = window.textFontSize;
                                        const padX = h * 0.3;
                                        const padY = h * 0.15;
                                        const totalH = previewLines.length * lineH - (lineH - h);
                                        const rx = window.typingCoords.x - padX;
                                        const ry = window.typingCoords.y - padY;
                                        const rw = maxW + padX * 2;
                                        const rh = totalH + padY * 2;
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

                                    for (let li = 0; li < previewLines.length; li++) {
                                        ctx.fillText(previewLines[li], window.typingCoords.x, window.typingCoords.y + li * lineH + window.textFontSize / 2);
                                    }

                                    if (window.textUnderline) {
                                        ctx.strokeStyle = window.currentColor;
                                        ctx.lineWidth = Math.max(1.5, Math.round(window.textFontSize * 0.08));
                                        for (let li = 0; li < previewLines.length; li++) {
                                            const textWidth = ctx.measureText(previewLines[li]).width;
                                            ctx.beginPath();
                                            ctx.moveTo(window.typingCoords.x, window.typingCoords.y + li * lineH + window.textFontSize * 1.05);
                                            ctx.lineTo(window.typingCoords.x + textWidth, window.typingCoords.y + li * lineH + window.textFontSize * 1.05);
                                            ctx.stroke();
                                        }
                                    }

                                    // Draw Overlaid Blinking Cursor Line
                                    if (window.typingCursorVisible) {
                                        let cursorLine = 0;
                                        let charAcc = 0;
                                        let cursorCol = 0;
                                        const targetIdx = Math.max(0, Math.min(rawText.length, window.typingCursorIndex));

                                        for (let i = 0; i < previewLines.length; i++) {
                                            const lineLen = previewLines[i].length;
                                            if (targetIdx <= charAcc + lineLen) {
                                                cursorLine = i;
                                                cursorCol = targetIdx - charAcc;
                                                break;
                                            }
                                            charAcc += lineLen + 1;
                                        }

                                        const subText = (previewLines[cursorLine] || "").substring(0, cursorCol);
                                        const subW = ctx.measureText(subText).width;
                                        const curX = window.typingCoords.x + subW;
                                        const curY = window.typingCoords.y + cursorLine * lineH;

                                        ctx.strokeStyle = window.currentColor;
                                        ctx.lineWidth = Math.max(2, Math.round(window.textFontSize * 0.07));
                                        ctx.beginPath();
                                        ctx.moveTo(curX, curY);
                                        ctx.lineTo(curX, curY + window.textFontSize);
                                        ctx.stroke();
                                    }
                                }
                            }

                            ctx.restore();
                            ctx.restore();
                        }

                        // Mouse Drawing & Action Capture
                        DrawMouseArea {
                            id: drawMouseArea
                            anchors.fill: parent
                            window: rootWindow
                            drawingCanvas: drawingCanvas
                            previewTimer: previewTimer
                            magnifier: magnifier
                            radialMenu: radialMenu
                            textInputDialog: textInputDialog
                            moreToolsMenu: moreToolsMenu
                            stampOptionsToolbar: stampOptionsToolbar
                            textOptionsToolbar: textOptionsToolbar
                            lineOptionsToolbar: lineOptionsToolbar
                            arrowOptionsToolbar: arrowOptionsToolbar
                            redactOptionsToolbar: redactOptionsToolbar
                             calloutOptionsToolbar: calloutOptionsToolbar
                             pixelateOptionsToolbar: pixelateOptionsToolbar
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
                            if (isBackdropActive || window.hasActiveCropSelection) {
                                const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
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

                                    const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
                                    const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;

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
                    currentShape: window.activeRedactShape
                    onModeSelected: (mode) => window.activeRedactMode = mode
                    onShapeSelected: (shape) => window.activeRedactShape = shape
                }

                CalloutOptionsToolbar {
                    id: calloutOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    currentLinkLines: window.calloutLinkLines
                    onLinkLinesSelected: (count) => window.calloutLinkLines = count
                }

                PixelateOptionsToolbar {
                    id: pixelateOptionsToolbar
                    toolbarPosition: window.toolbarPosition
                    randomizeActive: window.pixelateRandomize
                    onRandomizeToggled: window.pixelateRandomize = !window.pixelateRandomize
                }

                MoreToolsMenu {
                    id: moreToolsMenu
                    onRotateLeftRequested: window.rotateScreenshot("left")
                    onRotateRightRequested: window.rotateScreenshot("right")
                    onFlipHorizontalRequested: window.mirrorScreenshot("horizontal")
                    onFlipVerticalRequested: window.mirrorScreenshot("vertical")
                    onRotateRequested: window.rotateScreenshot("right")
                    onMirrorRequested: window.mirrorScreenshot("horizontal")
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
                        const customList = [];
                        const primaryRaw = config.pluginData["toolbar_color_primary"] || "primary";
                        const primaryColor = primaryRaw === "primary" ? Theme.primary : primaryRaw;
                        customList.push(typeof primaryColor === "string" ? Qt.color(primaryColor) : primaryColor);
                        for (let i = 0; i < 7; i++) {
                            const val = config.pluginData["toolbar_color_" + i] || config.adaptiveColors[i];
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
                    isVertical: toolbarCard.isVertical
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
                    isVertical: toolbarCard.isVertical
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
                    isVertical: toolbarCard.isVertical
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
                    isVertical: toolbarCard.isVertical
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

                    // Anchor-based positioning so popover stays correctly placed
                    // when height changes (e.g. customActive toggles the slider section)
                    property real _anchorY: 0
                    property bool _anchorIsAbove: false
                    y: _anchorIsAbove ? (_anchorY - height - Theme.spacingXS) : _anchorY

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

                BackdropPresetsPopover {
                    id: backdropPresetsPopover
                    presetsList: window.backdropPresets
                    onPresetSelected: (preset) => window.applyBackdropPreset(preset)
                    onSaveCurrentAsPreset: window.saveCurrentBackdropAsPreset()
                    onDeletePreset: (presetId) => window.deletePreset(presetId)
                    onUpdatePresetWithCurrent: (presetId) => window.updatePresetWithCurrent(presetId)
                    onRenamePreset: (presetId, newName) => window.renamePreset(presetId, newName)
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
        if (window.editingStroke) {
            if (textStr.length > 0) {
                const s = window.editingStroke;
                s.text = textStr;
                s.color = window.currentColor.toString();
                s.width = window.textFontSize;
                s.isMonospace = window.textFontFamily === "monospace";
                s.fontFamily = window.textFontFamily;
                s.isBold = window.textBold;
                s.isItalic = window.textItalic;
                s.isUnderline = window.textUnderline;
                s.hasBackground = window.textBackground;
                s.cornerRadius = window.textCornerRadius;
                if (s.isSpeechBubble) {
                    s.points = [window.typingTargetCoords, window.typingCoords];
                } else {
                    s.points = [window.typingCoords];
                }
                const idx = window.strokes.indexOf(s);
                if (idx !== -1) {
                    const list = [...window.strokes];
                    list[idx] = s;
                    window.strokes = list;
                }
                if (window.currentTool === "select") {
                    window.selectedStroke = s;
                }
            } else {
                const list = [...window.strokes];
                const idx = list.indexOf(window.editingStroke);
                if (idx !== -1) list.splice(idx, 1);
                window.strokes = list;
            }
            window.editingStroke = null;
        } else if (textStr.length > 0) {
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
                isSpeechBubble: window.typingIsSpeechBubble,
                points: window.typingIsSpeechBubble
                    ? [Qt.point(window.typingTargetCoords.x, window.typingTargetCoords.y), Qt.point(window.typingCoords.x, window.typingCoords.y)]
                    : [Qt.point(window.typingCoords.x, window.typingCoords.y)],
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
        window.selectedStroke = null;
        window.copiedStroke = null;
        window.close();
    }

    onDialogClosed: {
        // Reset path state here (not in onOpened) so re-fires during layout/screen changes
        // don't wipe bgImageSource before the image has a chance to render.
        window.currentCapturePath = "";
        window.restoreSource = "";
        window.bgImageSource = "";
        window.exportCallback = null;
    }
}
