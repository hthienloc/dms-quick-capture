import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Modals.FileBrowser
import qs.Services
import "./dms-common"
import "components/core"
import "components/misc"
import "components/popovers"
import "components/toolbar"
import "components/toolbar/options"
import "components/core/Helpers.js" as Helpers
import "components/core/DrawingRenderer.js" as DrawingRenderer
import "components/core/Constants.js" as Constants

Item {
    id: window

    readonly property var rootWindow: window

    property bool floatingMode: false
    property bool sessionDisplayModeOverride: false
    property bool presentationSwitching: false
    property bool shouldBeVisible: false
    property bool shouldHaveFocus: shouldBeVisible
    property real modalWidth
    property real modalHeight
    property var targetScreen
    property var floatingTargetScreen: null
    readonly property var presentationScreen: floatingMode && floatingTargetScreen ? floatingTargetScreen : targetScreen
    property real backgroundOpacity
    property color backgroundColor
    property bool allowStacking: false
    property bool useOverlayLayer: true
    readonly property alias modalFocusScope: modalSurface.modalFocusScope

    signal opened
    signal dialogClosed
    signal backgroundClicked

    function open() {
        if (!window.sessionDisplayModeOverride) {
            window.floatingMode = config.modalDisplayMode === "floating";
        }
        if (window.floatingMode)
            window.floatingTargetScreen = window.targetScreen;
        window.shouldBeVisible = true;
        if (window.floatingMode) {
            const wasVisible = floatingSurface.visible;
            floatingSurface.visible = true;
            if (!wasVisible)
                window.opened();
        } else {
            modalSurface.open();
        }
    }

    function close() {
        window.shouldBeVisible = false;
        if (window.floatingMode) {
            const wasVisible = floatingSurface.visible;
            floatingSurface.visible = false;
            window.floatingTargetScreen = null;
            if (wasVisible)
                window.dialogClosed();
        } else {
            modalSurface.close();
        }
    }

    function instantClose() {
        window.shouldBeVisible = false;
        if (window.floatingMode) {
            const wasVisible = floatingSurface.visible;
            floatingSurface.visible = false;
            window.floatingTargetScreen = null;
            if (wasVisible)
                window.dialogClosed();
        } else {
            modalSurface.instantClose();
        }
    }

    DankModal {
        id: modalSurface
        shouldBeVisible: window.shouldBeVisible && !window.floatingMode
        shouldHaveFocus: window.shouldHaveFocus && !window.floatingMode
        modalWidth: window.modalWidth
        modalHeight: window.modalHeight
        targetScreen: window.targetScreen
        backgroundOpacity: window.backgroundOpacity
        backgroundColor: window.backgroundColor
        allowStacking: window.allowStacking
        useOverlayLayer: window.useOverlayLayer
        layerNamespace: "dms:plugins:quickCapture"
        keepPopoutsOpen: true
        content: window.editorContent

        onOpened: window.opened()
        onDialogClosed: window.dialogClosed()
        onBackgroundClicked: window.backgroundClicked()
    }

    DankFloatingWindow {
        id: floatingSurface
        title: I18n.trFor("quickCapture", "Quick Capture")
        objectName: "quickCaptureEditor"
        visible: false
        implicitWidth: window.modalWidth
        implicitHeight: window.modalHeight
        minimumSize: Qt.size(400, 300)
        screen: window.presentationScreen
        readonly property real editorAspectRatio: window.modalHeight > 0 ? window.modalWidth / window.modalHeight : 1
        property bool syncingAspectRatio: false

        onWidthChanged: {
            if (!visible || syncingAspectRatio || editorAspectRatio <= 0 || width <= 0)
                return;
            syncingAspectRatio = true;
            height = Math.max(minimumSize.height, Math.round(width / editorAspectRatio));
            syncingAspectRatio = false;
        }

        onHeightChanged: {
            if (!visible || syncingAspectRatio || editorAspectRatio <= 0 || height <= 0)
                return;
            syncingAspectRatio = true;
            width = Math.max(minimumSize.width, Math.round(height * editorAspectRatio));
            syncingAspectRatio = false;
        }

        onVisibleChanged: {
            if (visible) {
                Qt.callLater(() => {
                    if (typeof floatingSurface.requestActivate === "function")
                        floatingSurface.requestActivate();
                    if (floatingEditorLoader.item)
                        floatingEditorLoader.item.forceActiveFocus();
                });
            }
        }
        onClosed: {
            if (window.presentationSwitching)
                return;
            window.floatingTargetScreen = null;
            floatingSurface.visible = false;
            if (window.shouldBeVisible) {
                window.shouldBeVisible = false;
                window.dialogClosed();
            }
        }

        Item {
            anchors.fill: parent

            Loader {
                id: floatingEditorLoader
                anchors.fill: parent
                active: floatingSurface.visible
                sourceComponent: window.editorContent
            }
        }

        FloatingWindowControls {
            id: floatingWindowControls
            targetWindow: floatingSurface
        }

    }

    CaptureConfig { 
        id: config 
        pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})
        onPluginDataChanged: window.loadPresetsFromPluginData()
    }

    Image {
        id: watermarkImageLoader
        
        source: {
            const rawPath = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.watermarkImage) ? window.parentWidget.pluginData.watermarkImage : "";
            if (rawPath) {
                let p = Paths.expandTilde(rawPath.trim());
                if (p.indexOf("/") === 0) {
                    p = Paths.toFileUrl(p);
                }
                return p;
            }
            return "";
        }
        
        visible: false
        cache: true
    }

    Image {
        id: backgroundImageLoader
        source: window.backgroundMode === "image"
            ? window.localImageSource(window.effectiveBackgroundImagePath) : ""
        visible: false
        cache: true
        asynchronous: true
        onStatusChanged: window.requestPaintAll()
    }

    // Parent communication reference
    property var parentWidget: null

    // State Variables
    property var paletteWarningDialogRef: null
    property var toolbarItem: null
    property int activeColorSlotIndex: 0
    property var scanResultPopoverRef: null
    property int editorSessionGeneration: 0
    property color pendingColorToSave: "transparent"
    property int pendingSlotToSave: -1
    property string currentTool: "crop" // crop, select, pen, line, arrow, rect, ellipse, text, pixelate, redact, stamp, highlighter, eraser, spotlight, background
    property string lastActiveTool: "pen"
    property string colorPickerMode: "draw" // draw, copy
    property color hoveredColor: "transparent"

    function requestActiveCanvasPaint() {
        if (window.activeCanvas) {
            window.activeCanvas.requestPaint();
        }
    }

    function savePluginData(key, value) {
        if (window.parentWidget && window.parentWidget.pluginService) {
            window.parentWidget.pluginService.savePluginData("quickCapture", key, value);
        }
    }

    function parseJsonArrayValue(rawValue, key) {
        try {
            const parsed = JSON.parse(rawValue);
            return Array.isArray(parsed) ? parsed : undefined;
        } catch (e) {
            console.error(`Failed to parse ${key}:`, e);
            return undefined;
        }
    }

    function refreshStrokeReference(stroke) {
        const idx = window.strokes.indexOf(stroke);
        if (idx !== -1) {
            window.strokes[idx] = stroke;
            window.strokes = [...window.strokes];
        }
    }

    function copyStrokePoints(points) {
        const copied = [];
        for (let p of points) {
            copied.push(Qt.point(p.x, p.y));
        }
        return copied;
    }

    function updateToolStrokeState(tool, updater) {
        if (window.selectedStroke && window.selectedStroke.tool === tool) {
            updater(window.selectedStroke);
            window.refreshStrokeReference(window.selectedStroke);
        }
        if (window.currentStroke && window.currentStroke.tool === tool) {
            updater(window.currentStroke);
        }
        window.requestActiveCanvasPaint();
    }

    function syncStyleFromStroke(stroke) {
        window.currentColor = stroke.color;
        if (stroke.tool === "text") window.textFontSize = stroke.width;
        else if (stroke.tool === "pixelate") window.pixelateIntensity = stroke.width;
        else if (stroke.tool === "spotlight") window.spotlightIntensity = stroke.width;
        else if (stroke.tool === "callout") window.calloutZoom = stroke.width;
        else window.strokeWidth = stroke.width;

        if (stroke.tool === "line" && stroke.lineStyle) window.activeLineStyle = stroke.lineStyle;
        if (stroke.tool === "arrow") {
            if (stroke.arrowLineStyle) window.activeArrowLineStyle = stroke.arrowLineStyle;
            if (stroke.arrowHeadStyle) window.activeArrowHeadStyle = stroke.arrowHeadStyle;
        }
        if (stroke.tool === "redact" && stroke.redactMode) window.activeRedactMode = stroke.redactMode;
        if (stroke.tool === "redact" && stroke.redactShape) window.activeRedactShape = stroke.redactShape;
        if (stroke.tool === "callout") {
            window.calloutLinkLines = stroke.calloutLinkLines !== undefined ? stroke.calloutLinkLines : 1;
            window.calloutShape = stroke.calloutShape !== undefined ? stroke.calloutShape : "rect";
        }
    }

    function bringStrokeToFront(stroke) {
        const reorder = [...window.strokes];
        const idx = reorder.indexOf(stroke);
        if (idx !== -1) {
            reorder.splice(idx, 1);
            reorder.push(stroke);
            window.strokes = reorder;
        }
    }

    function selectStrokeForEditing(stroke, saveCurrentState) {
        if (saveCurrentState) {
            window.savePreGrabState();
        }
        window.selectedStroke = stroke;
        window.originalPoints = window.copyStrokePoints(stroke.points);
        window.originalRotation = Number(stroke.rotation) || 0;
        window.syncStyleFromStroke(stroke);
        if (stroke.tool !== "spotlight") {
            window.bringStrokeToFront(stroke);
        }
    }

    function deselectStrokeForEditing(restoreStyle) {
        window.selectedStroke = null;
        window.originalPoints = [];
        window.originalRotation = 0;
        window.activeHandle = "none";
        window.calloutDestDragging = false;
        if (restoreStyle) {
            window.restorePreGrabState();
        }
    }

    function enterColorPickerTool() {
        window._lastSampledX = -1;
        window._lastSampledY = -1;
        window._lastSampledColor = "transparent";
        window.requestPaintAll();
        window.hoveredColor = window.sampleCanvasColor(window.cursorX * window.editScale, window.cursorY * window.editScale);
    }

    function enterBackgroundTool() {
        if (window.backgroundMode !== "none") return;
        const defaultMode = (config && config.pluginData && config.pluginData["backgroundDefaultMode"]) || Constants.defaultBackgroundMode;
        window.backgroundMode = defaultMode;
        if (defaultMode === "image") {
            window.refreshBackgroundBlurCache(false);
        }
    }

    function enterSelectTool() {
        if (window.selectedStroke || window.strokes.length === 0) return;
        window.selectStrokeForEditing(window.strokes[window.strokes.length - 1], true);
    }

    readonly property var intensityTools: [
        "pen", "line", "arrow", "rect", "ellipse", "highlighter",
        "redact", "stamp", "text", "pixelate", "spotlight", "callout"
    ]

    function isIntensityTool(tool) {
        return window.intensityTools.indexOf(tool) !== -1;
    }

    function intensitySettingKey(tool) {
        const keys = {
            pen: "defaultPenThickness",
            line: "defaultLineThickness",
            arrow: "defaultArrowThickness",
            rect: "defaultRectThickness",
            ellipse: "defaultEllipseThickness",
            highlighter: "defaultHighlighterThickness",
            redact: "defaultRedactThickness",
            stamp: "defaultStampSize",
            text: "textFontSize",
            pixelate: "defaultPixelateIntensity",
            spotlight: "defaultSpotlightIntensity",
            callout: "defaultCalloutZoom"
        };
        return keys[tool] || "";
    }

    function clampToolIntensity(tool, value) {
        const meta = Constants.getToolMeta(tool);
        const parsed = parseInt(value, 10);
        const fallback = meta.defaultValue;
        const nextValue = isNaN(parsed) ? fallback : parsed;
        return Helpers.clamp(nextValue, meta.min, meta.max);
    }

    function configuredToolIntensity(tool) {
        const key = window.intensitySettingKey(tool);
        let rawValue = key ? window.pluginData[key] : undefined;
        if (rawValue === undefined && tool === "pen") {
            rawValue = window.pluginData.defaultThickness;
        }
        return window.clampToolIntensity(tool, rawValue);
    }

    function resetSessionToolIntensities() {
        const values = {};
        for (let i = 0; i < window.intensityTools.length; i++) {
            const tool = window.intensityTools[i];
            values[tool] = window.configuredToolIntensity(tool);
        }
        window.sessionToolIntensities = values;
    }

    function updateSessionToolIntensity(tool, value) {
        if (!window.isIntensityTool(tool)) return;
        const nextValues = Object.assign({}, window.sessionToolIntensities);
        nextValues[tool] = window.clampToolIntensity(tool, value);
        window.sessionToolIntensities = nextValues;
    }

    function sessionToolIntensity(tool) {
        if (!window.isIntensityTool(tool)) return window.strokeWidth;
        const current = window.sessionToolIntensities[tool];
        if (current !== undefined) return window.clampToolIntensity(tool, current);
        return window.configuredToolIntensity(tool);
    }

    function applyToolIntensity(tool, value) {
        const clamped = window.clampToolIntensity(tool, value);
        if (tool === "text") window.textFontSize = clamped;
        else if (tool === "pixelate") window.pixelateIntensity = clamped;
        else if (tool === "spotlight") {
            window.spotlightIntensity = clamped;
            window.preGrabSpotlightIntensity = clamped;
        }
        else if (tool === "callout") window.calloutZoom = clamped;
        else window.strokeWidth = clamped;
    }

    function applyCurrentToolSessionIntensity() {
        if (!window.isIntensityTool(window.currentTool)) return;
        window.applyToolIntensity(window.currentTool, window.sessionToolIntensity(window.currentTool));
    }

    readonly property var colorTools: [
        "pen", "line", "arrow", "rect", "ellipse", "highlighter", "stamp", "text"
    ]

    property var sessionToolColors: ({})

    function isColorTool(tool) {
        return window.colorTools.indexOf(tool) !== -1;
    }

    function colorSettingKey(tool) {
        const keys = {
            pen: "defaultPenColor",
            line: "defaultLineColor",
            arrow: "defaultArrowColor",
            rect: "defaultRectColor",
            ellipse: "defaultEllipseColor",
            highlighter: "defaultHighlighterColor",
            stamp: "defaultStampColor",
            text: "defaultTextColor"
        };
        return keys[tool] || "";
    }

    function configuredToolColor(tool) {
        const key = window.colorSettingKey(tool);
        let rawValue = key ? window.pluginData[key] : undefined;
        if (rawValue === undefined) {
            return "primary";
        }
        return rawValue;
    }

    function resetSessionToolColors() {
        const values = {};
        for (let i = 0; i < window.colorTools.length; i++) {
            const tool = window.colorTools[i];
            values[tool] = window.configuredToolColor(tool);
        }
        window.sessionToolColors = values;
    }

    function updateSessionToolColor(tool, colorValue) {
        if (!window.isColorTool(tool)) return;
        const nextValues = Object.assign({}, window.sessionToolColors);
        nextValues[tool] = colorValue ? colorValue.toString() : "primary";
        window.sessionToolColors = nextValues;
    }

    function sessionToolColor(tool) {
        if (!window.isColorTool(tool)) return window.currentColor;
        const current = window.sessionToolColors[tool];
        if (current !== undefined) return config.resolveColor(current);
        return config.resolveColor(window.configuredToolColor(tool));
    }

    function shouldSkipCurrentStrokeCommit(stroke) {
        if (!stroke || stroke.tool === "text") return true;

        const isStamp = stroke.tool === "stamp";
        if ((!isStamp && stroke.points.length < 2) || (isStamp && stroke.points.length < 1)) {
            window.currentStroke = null;
            return true;
        }
        return false;
    }

    function finalizeCurrentStroke() {
        const stroke = window.currentStroke;
        if (window.shouldSkipCurrentStrokeCommit(stroke)) return false;

        if (stroke.tool === "callout") {
            if (stroke.points.length < 2) {
                window.currentStroke = null;
                return false;
            }

            const p0 = stroke.points[0];
            const p1 = stroke.points[stroke.points.length - 1];
            const bounds = Helpers.getRectBounds(p0, p1);
            const rw = bounds.x2 - bounds.x1;
            const rh = bounds.y2 - bounds.y1;
            if (rw <= 5 || rh <= 5) {
                window.currentStroke = null;
                return false;
            }

            const visX = window.hasActiveCropSelection ? window.cropRect.x : 0;
            const visY = window.hasActiveCropSelection ? window.cropRect.y : 0;
            const visW = window.canvasWidth;
            const visH = window.canvasHeight;
            const placement = Helpers.getCalloutPlacement(
                p0, p1, stroke.width / 100.0,
                visX, visY, visW, visH,
                Constants.calloutAutoPlacementMargin
            );
            stroke.points = [
                Qt.point(placement.sourceStart.x, placement.sourceStart.y),
                Qt.point(placement.sourceEnd.x, placement.sourceEnd.y),
                Qt.point(placement.destinationStart.x, placement.destinationStart.y),
                Qt.point(placement.destinationEnd.x, placement.destinationEnd.y)
            ];
        }

        if (stroke.tool === "pen" && stroke.points.length >= 3) {
            stroke.points = Helpers.smoothStrokePoints(stroke.points, 6, Qt);
            if (window.penAutoClose) {
                const snapThreshold = 20 / window.editScale;
                const fp = stroke.points[0];
                const lp = stroke.points[stroke.points.length - 1];
                if (Helpers.distance(fp, lp) < snapThreshold) {
                    stroke.points = [...stroke.points, Qt.point(fp.x, fp.y)];
                    stroke.isClosed = true;
                }
            }
        }
        if (stroke.tool === "stamp") window.stampCounter++;
        window.pushStroke(stroke);
        window.currentStroke = null;
        return true;
    }

    function commitStrokeBeforeToolChange() {
        const stroke = window.currentStroke;
        if (window.shouldSkipCurrentStrokeCommit(stroke)) return null;

        const dragStart = stroke.points[stroke.points.length - 1];
        return window.finalizeCurrentStroke() ? dragStart : null;
    }

    function handleCurrentToolChanged() {
        if (window.currentTool !== "background") {
            Qt.callLater(window.closeBackgroundPopovers);
        }
        if (window.currentTool !== "colorpicker") {
            window.backgroundColorPickingSlot = "none";
        }
        if (window.currentTool !== "text" && window.isTyping) {
            window.commitTypingText();
        }
        let toolChangeDragStart = null;
        if (window.currentStroke && window.currentStroke.tool !== window.currentTool) {
            toolChangeDragStart = window.commitStrokeBeforeToolChange();
        }
        if (window.currentTool !== "crop" && window.currentTool !== "background" && window.currentTool !== "select" && window.currentTool !== "colorpicker") {
            window.lastActiveTool = window.currentTool;
        }
        window.applyCurrentToolSessionIntensity();
        if (window.isColorTool(window.currentTool)) {
            window.activeColorSlotIndex = -1;
            window.currentColor = window.sessionToolColor(window.currentTool);
        }
        if (window.currentTool !== "select" && window.selectedStroke) {
            window.deselectStrokeForEditing(true);
            window.requestActiveCanvasPaint();
        }
        if (window.currentTool === "colorpicker") {
            window.enterColorPickerTool();
        }
        if (window.currentTool === "background") {
            window.enterBackgroundTool();
        }
        if (window.currentTool === "select") {
            window.enterSelectTool();
            window.activeHandle = "none";
            if (toolChangeDragStart && window.selectedStroke) {
                window.originalPoints = window.copyStrokePoints(window.selectedStroke.points);
                window.pressCoords = Qt.point(toolChangeDragStart.x, toolChangeDragStart.y);
            } else {
                window.originalPoints = [];
            }
        }
        window.requestPaintAll();
    }

    property string activeLineStyle: "solid"
    property string activeRedactMode: "solid" // solid, blur, clean
    onActiveRedactModeChanged: {
        window.updateToolStrokeState("redact", function(stroke) {
            stroke.redactMode = window.activeRedactMode;
            stroke.cachedCleanColor = undefined;
        });
    }
    property string activeRedactShape: window.roundRect ? "roundRect" : "rect" // rect, roundRect, ellipse
    onActiveRedactShapeChanged: {
        window.updateToolStrokeState("redact", function(stroke) {
            stroke.redactShape = window.activeRedactShape;
            stroke.cachedCleanColor = undefined;
        });
    }
    onActiveLineStyleChanged: {
        window.updateToolStrokeState("line", function(stroke) {
            stroke.lineStyle = window.activeLineStyle;
        });
    }
    property string activeArrowLineStyle: "solid"
    property string activeArrowHeadStyle: "single-filled"
    onActiveArrowLineStyleChanged: {
        window.updateToolStrokeState("arrow", function(stroke) {
            stroke.arrowLineStyle = window.activeArrowLineStyle;
        });
    }
    onActiveArrowHeadStyleChanged: {
        window.updateToolStrokeState("arrow", function(stroke) {
            stroke.arrowHeadStyle = window.activeArrowHeadStyle;
        });
    }
    property int _lastSampledX: -1
    property int _lastSampledY: -1
    property color _lastSampledColor: "transparent"
    readonly property real dpr: Screen.devicePixelRatio || 1.0
    onCurrentToolChanged: {
        window.handleCurrentToolChanged();
    }

    // Background State Variables
    property string backgroundMode: "none" // none, solid, gradient, radial, conic, image
    property string backgroundImagePath: ""
    property string backgroundImageFolder: "~/Pictures/Wallpaper"
    property var backgroundImages: []
    property bool backgroundImagesLoading: false
    property bool backgroundImageBlur: false
    property bool backgroundImageDim: false
    property int backgroundImageDimStrength: 28
    property string backgroundBlurredImagePath: ""
    property string backgroundBlurredSourcePath: ""
    property string backgroundBlurPendingSourcePath: ""
    property bool backgroundBlurLoading: false
    property bool backgroundBlurShowIndicator: false
    property int backgroundBlurGeneration: 0
    readonly property string effectiveBackgroundImagePath: window.backgroundImageBlur && window.backgroundBlurredImagePath
        ? window.backgroundBlurredImagePath : window.backgroundImagePath
    property color backgroundSolidColor: Theme.primary
    property color backgroundGradientStart: Theme.primary
    property color backgroundGradientEnd: Theme.secondary
    property int backgroundGradientAngle: Constants.defaultBackgroundGradientAngle
    property int backgroundPadding: Constants.defaultBackgroundPadding
    property int backgroundCornerRadius: Constants.defaultBackgroundCornerRadius
    property int backgroundShadowStrength: Constants.defaultBackgroundShadowStrength
    property string backgroundAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property string backgroundAlignment: "center"
    property string backgroundColorPickingSlot: "none" // none, solid, start, end
    readonly property real customRatioMin: 0.50
    readonly property real customRatioMax: 2.50
    readonly property var aspectPresets: [
        { value: "auto", label: I18n.trFor("quickCapture", "AUTO") },
        { value: "1:1", label: "1:1" },
        { value: "16:9", label: "16:9" },
        { value: "9:16", label: "9:16" },
        { value: "4:3", label: "4:3" },
        { value: "3:2", label: "3:2" },
        { value: "21:9", label: "21:9" },
        { value: "custom", label: I18n.trFor("quickCapture", "CUST") }
    ]
    property bool hasUserCustomizedBackground: false
    property color autoBackgroundGradientStart: Theme.primary
    property color autoBackgroundGradientEnd: Theme.secondary
    property color autoBackgroundSolidColor: Theme.primary
    property bool preservingRestoredBackground: false
    property var customBackgroundPresets: []
    property var hiddenPresetIds: []

    function localImageSource(rawPath) {
        if (!rawPath) return "";
        let path = Paths.expandTilde(String(rawPath).trim());
        if (path.indexOf("/") === 0) return Paths.toFileUrl(path);
        return path;
    }

    function localFolderPath(rawPath) {
        if (!rawPath) return "";
        let path = Paths.strip(String(rawPath).trim());
        if (path.indexOf("~/") === 0)
            path = Paths.expandTilde(path);
        return path;
    }

    function loadBackgroundImages() {
        const folder = window.localFolderPath(window.backgroundImageFolder);
        const generation = window.editorSessionGeneration;
        window.backgroundImagesLoading = true;
        Proc.runCommand("scan-background-images", ["find", folder, "-maxdepth", "1", "-type", "f", "-printf", "%T@|%p\n"], (stdout, exitCode) => {
            if (generation !== window.editorSessionGeneration) return;
            const images = [];
            if (exitCode === 0 && stdout) {
                const lines = stdout.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const separator = lines[i].indexOf("|");
                    if (separator < 0) continue;
                    const path = lines[i].substring(separator + 1);
                    if (!/\.(png|jpe?g|webp|bmp)$/i.test(path)) continue;
                    images.push({
                        timestamp: parseFloat(lines[i].substring(0, separator)) || 0,
                        path: path,
                        name: path.substring(path.lastIndexOf("/") + 1)
                    });
                }
                images.sort((a, b) => b.timestamp - a.timestamp);
            }
            window.backgroundImages = images.slice(0, 100);
            window.backgroundImagesLoading = false;
        });
    }

    function setBackgroundImage(path, persist) {
        if (!path) return;
        window.backgroundImagePath = String(path);
        window.backgroundMode = "image";
        window.hasUserCustomizedBackground = true;
        if (persist) window.savePluginData("backgroundDefaultImagePath", window.backgroundImagePath);
        window.refreshBackgroundBlurCache(true);
    }

    function cleanupBackgroundBlurCache(path) {
        if (!path) return;
        Proc.runCommand("cleanup-background-blur-cache", ["rm", "-f", "--", path]);
    }

    function cancelBackgroundBlurPreparation() {
        if (!window.backgroundBlurLoading) return;
        window.backgroundBlurGeneration += 1;
        window.backgroundBlurPendingSourcePath = "";
        window.backgroundBlurLoading = false;
        window.backgroundBlurShowIndicator = false;
    }

    function refreshBackgroundBlurCache(showIndicator) {
        if (window.backgroundMode !== "image") {
            window.cancelBackgroundBlurPreparation();
            window.requestPaintAll();
            return;
        }

        const inputPath = window.localFolderPath(window.backgroundImagePath);
        if (inputPath && window.backgroundBlurredImagePath && window.backgroundBlurredSourcePath === inputPath) {
            window.backgroundBlurLoading = false;
            window.backgroundBlurShowIndicator = false;
            window.requestPaintAll();
            return;
        }
        if (inputPath && window.backgroundBlurLoading && window.backgroundBlurPendingSourcePath === inputPath) {
            if (showIndicator === true) window.backgroundBlurShowIndicator = true;
            return;
        }

        window.backgroundBlurGeneration += 1;
        const generation = window.backgroundBlurGeneration;
        const previousPath = window.backgroundBlurredImagePath;
        window.backgroundBlurredImagePath = "";
        window.backgroundBlurredSourcePath = "";
        window.backgroundBlurPendingSourcePath = "";
        window.backgroundBlurLoading = false;
        window.backgroundBlurShowIndicator = false;
        window.cleanupBackgroundBlurCache(previousPath);

        if (!inputPath) {
            window.requestPaintAll();
            return;
        }

        const tempDir = Quickshell.env("TMPDIR") || "/tmp";
        const outputPath = `${tempDir}/dms-quick-capture-background-blur-${Date.now()}-${generation}.jpg`;
        window.backgroundBlurLoading = true;
        window.backgroundBlurPendingSourcePath = inputPath;
        window.backgroundBlurShowIndicator = showIndicator === true;

        Proc.runCommand("generate-background-blur", ["magick", inputPath, "-auto-orient", "-blur", "0x18", "-quality", "88", outputPath], (stdout, exitCode) => {
            if (generation !== window.backgroundBlurGeneration) {
                window.cleanupBackgroundBlurCache(outputPath);
                return;
            }

            window.backgroundBlurLoading = false;
            window.backgroundBlurPendingSourcePath = "";
            window.backgroundBlurShowIndicator = false;
            if (exitCode === 0) {
                window.backgroundBlurredImagePath = outputPath;
                window.backgroundBlurredSourcePath = inputPath;
                window.requestPaintAll();
                return;
            }

            window.cleanupBackgroundBlurCache(outputPath);
            if (window.backgroundImageBlur) {
                window.backgroundImageBlur = false;
                window.savePluginData("backgroundImageBlur", false);
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.trFor("quickCapture", "Failed to generate blurred background image"));
                }
            }
            window.requestPaintAll();
        });
    }

    function setBackgroundImageDim(enabled, persist) {
        window.backgroundImageDim = enabled;
        if (persist) window.savePluginData("backgroundImageDim", enabled);
    }

    function setBackgroundImageBlur(enabled, persist) {
        window.backgroundImageBlur = enabled;
        if (persist) window.savePluginData("backgroundImageBlur", enabled);
        if (enabled && window.backgroundMode === "image" && !window.backgroundBlurredImagePath && !window.backgroundBlurLoading) {
            window.refreshBackgroundBlurCache(true);
        } else {
            window.requestPaintAll();
        }
    }

    function setBackgroundImageDimStrength(value, persist) {
        window.backgroundImageDimStrength = Helpers.clamp(Math.round(value), 0, 80);
        if (persist) window.savePluginData("backgroundImageDimStrength", window.backgroundImageDimStrength);
    }

    readonly property var backgroundPresets: {
        var customMap = {};
        if (customBackgroundPresets) {
            for (var i = 0; i < customBackgroundPresets.length; i++) {
                var cp = customBackgroundPresets[i];
                customMap[cp.id] = cp;
            }
        }

        var list = [];
        if (Constants && Constants.defaultBackgroundPresets) {
            for (var j = 0; j < Constants.defaultBackgroundPresets.length; j++) {
                var dp = Constants.defaultBackgroundPresets[j];
                if (!hiddenPresetIds || hiddenPresetIds.indexOf(dp.id) === -1) {
                    if (customMap[dp.id]) {
                        list.push(customMap[dp.id]);
                    } else {
                        list.push(dp);
                    }
                }
            }
        }
        if (customBackgroundPresets) {
            for (var k = 0; k < customBackgroundPresets.length; k++) {
                var up = customBackgroundPresets[k];
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
    property var sessionToolIntensities: ({})

    property int spotlightIntensity: 50
    onSpotlightIntensityChanged: {
        preGrabSpotlightIntensity = spotlightIntensity;
        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i].tool === "spotlight") {
                window.strokes[i].width = window.spotlightIntensity;
            }
        }
        window.repaintActiveCanvas();
    }
    property var undoneStrokes: []
    readonly property bool canUndo: strokes.length > 0
    readonly property bool canRedo: undoneStrokes.length > 0
    property int textFontSize: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.textFontSize !== undefined ? window.parentWidget.pluginData.textFontSize : 36
    property int calloutZoom: 150
    property bool calloutDestDragging: false

    readonly property string effectiveTool: (pastePreviewActive && copiedStroke) ? copiedStroke.tool : ((currentTool === "select" && selectedStroke) ? selectedStroke.tool : currentTool)
    readonly property bool hasActiveCropSelection: window.currentTool !== "crop" && window.hasSelection
    property int activeIntensity: {
        if (pastePreviewActive && copiedStroke && copiedStroke.width !== undefined) return copiedStroke.width;
        if (effectiveTool === "text") return textFontSize;
        if (effectiveTool === "pixelate") return pixelateIntensity;
        if (effectiveTool === "spotlight") return spotlightIntensity;
        if (effectiveTool === "callout") return calloutZoom;
        return strokeWidth;
    }

    function updateCalloutDestFromWidth(stroke, width) {
        if (!stroke || stroke.tool !== "callout" || !stroke.points || stroke.points.length !== 4) return;

        const srcP0 = stroke.points[0];
        const srcP1 = stroke.points[1];
        const dstP0 = stroke.points[2];
        const rw = srcP1.x - srcP0.x;
        const rh = srcP1.y - srcP0.y;
        const zoom = width / 100.0;
        const newPoints = [...stroke.points];
        newPoints[3] = Qt.point(dstP0.x + rw * zoom, dstP0.y + rh * zoom);
        stroke.points = newPoints;
    }

    function updatePastePreviewWidth(width) {
        if (!window.pastePreviewActive || !window.copiedStroke) return false;

        const nextStroke = Object.assign({}, window.copiedStroke, { width: width });
        if (nextStroke.tool === "redact") {
            nextStroke.cachedCleanColor = undefined;
        }
        window.updateCalloutDestFromWidth(nextStroke, width);
        window.copiedStroke = nextStroke;
        window.repaintActiveCanvas();
        return true;
    }

    function updatePastePreviewColor(color) {
        if (!window.pastePreviewActive || !window.copiedStroke) return false;

        const nextStroke = Object.assign({}, window.copiedStroke, { color: color.toString() });
        if (nextStroke.tool === "redact") {
            nextStroke.cachedCleanColor = undefined;
        }
        window.copiedStroke = nextStroke;
        window.repaintActiveCanvas();
        return true;
    }

    function updateActiveIntensity(val) {
        const meta = Constants.getToolMeta(effectiveTool);
        const clamped = Helpers.clamp(val, meta.min, meta.max);

        window.updateSessionToolIntensity(effectiveTool, clamped);

        if (effectiveTool === "text") textFontSize = clamped;
        else if (effectiveTool === "pixelate") pixelateIntensity = clamped;
        else if (effectiveTool === "spotlight") {
            spotlightIntensity = clamped;
            preGrabSpotlightIntensity = clamped;
        }
        else if (effectiveTool === "callout") calloutZoom = clamped;
        else strokeWidth = clamped;

        if (window.updatePastePreviewWidth(clamped)) return;

        if (selectedStroke) {
            selectedStroke.width = clamped;
            window.updateCalloutDestFromWidth(selectedStroke, clamped);
            window.refreshStrokeReference(selectedStroke);
        }
        if (currentStroke) {
            currentStroke.width = clamped;
        }
        window.repaintActiveCanvas();
    }

    property color currentColor: Theme.primary
    onCurrentColorChanged: {
        if (window.isColorTool(window.currentTool) && window.currentTool !== "select" && !window.selectedStroke) {
            window.updateSessionToolColor(window.currentTool, window.currentColor);
        }
        if (window.updatePastePreviewColor(window.currentColor)) {
            return;
        }
        if (window.selectedStroke) {
            window.selectedStroke.color = window.currentColor.toString();
            if (window.selectedStroke.tool === "redact") {
                window.selectedStroke.cachedCleanColor = undefined;
            }
            window.refreshStrokeReference(window.selectedStroke);
        }
        if (window.currentStroke) {
            window.currentStroke.color = window.currentColor.toString();
        }
        window.repaintActiveCanvas();
    }
    property int stampCounter: 1
    property int stampIdCounter: 1
    property string stampCounterFormat: "numeric" // numeric, alpha, roman
    onStampCounterFormatChanged: {
        window.reindexStamps();
        window.requestPaintAll();
    }
    property string calloutShape: "rect" // rect, ellipse
    onCalloutShapeChanged: {
        if (selectedStroke && selectedStroke.tool === "callout") {
            if (selectedStroke.calloutShape !== calloutShape) {
                selectedStroke.calloutShape = calloutShape;
                window.refreshStrokeReference(selectedStroke);
                window.requestActiveCanvasPaint();
            }
        }
    }
    property int calloutLinkLines: 1 // 1, 2
    onCalloutLinkLinesChanged: {
        if (selectedStroke && selectedStroke.tool === "callout") {
            if (selectedStroke.calloutLinkLines !== calloutLinkLines) {
                selectedStroke.calloutLinkLines = calloutLinkLines;
                window.refreshStrokeReference(selectedStroke);
                window.requestActiveCanvasPaint();
            }
        }
    }
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false


    // --- Proxy Editing Optimization ---
    readonly property real maxEditPixels: {
        const q = (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.editQuality) || String(Constants.defaultEditPixelBudget);
        const val = parseInt(q, 10);
        const supportedBudgets = [150000, 300000, 450000, 600000];
        return supportedBudgets.indexOf(val) !== -1 ? val : Constants.defaultEditPixelBudget;
    }
    readonly property real editScale: {
        if (!window.bgImageItem) return 1.0;
        const w = window.bgImageItem.sourceSize.width;
        const h = window.bgImageItem.sourceSize.height;
        // Background mode can make the logical canvas much larger than the image.
        // Keep the editor backing canvas bounded while preserving logical/export size.
        const logicalW = window.effectiveBackgroundMode !== "none" ? window.canvasWidth : w;
        const logicalH = window.effectiveBackgroundMode !== "none" ? window.canvasHeight : h;
        let baseScale = 1.0;
        const area = logicalW * logicalH;
        if (!(isNaN(area) || area <= 0 || area <= maxEditPixels)) {
            baseScale = Math.sqrt(maxEditPixels / area);
        }
        // Cap the editScale to fitScale so that the canvas resolution
        // never exceeds the actual display size on the screen.
        const maxRequiredScale = window.fitScale;
        return Math.min(baseScale, maxRequiredScale);
    }

    readonly property string effectiveBackgroundMode: window.currentTool === "crop" ? "none" : window.backgroundMode

    readonly property real screenshotWidth: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.width;
        }
        if (!window.bgImageItem) return 1;
        return (window.bgRotation % 180 === 0) ? window.bgImageItem.sourceSize.width : window.bgImageItem.sourceSize.height;
    }
    readonly property real screenshotHeight: {
        if (window.hasActiveCropSelection) {
            return window.cropRect.height;
        }
        if (!window.bgImageItem) return 1;
        return (window.bgRotation % 180 === 0) ? window.bgImageItem.sourceSize.height : window.bgImageItem.sourceSize.width;
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
        if (window.effectiveBackgroundMode === "none") {
            return screenshotWidth;
        }
        const baseW = screenshotWidth + 2 * window.backgroundPadding;
        const baseH = screenshotHeight + 2 * window.backgroundPadding;
        if (window.backgroundAspectRatio === "auto") {
            return baseW;
        }
        const targetRatio = getTargetRatio(window.backgroundAspectRatio);
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
        if (window.effectiveBackgroundMode === "none") {
            return screenshotHeight;
        }
        const baseW = screenshotWidth + 2 * window.backgroundPadding;
        const baseH = screenshotHeight + 2 * window.backgroundPadding;
        if (window.backgroundAspectRatio === "auto") {
            return baseH;
        }
        const targetRatio = getTargetRatio(window.backgroundAspectRatio);
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

    readonly property real backgroundScaleFactor: 1.0

    readonly property real screenshotXOffset: {
        if (window.effectiveBackgroundMode === "none") return 0;
        const align = window.backgroundAlignment;
        if (align.endsWith("-left"))  return 0;
        if (align.endsWith("-right")) return canvasWidth - screenshotWidth;
        return (canvasWidth - screenshotWidth) / 2;
    }
    readonly property real screenshotYOffset: {
        if (window.effectiveBackgroundMode === "none") return 0;
        const align = window.backgroundAlignment;
        if (align.startsWith("top-"))    return 0;
        if (align.startsWith("bottom-")) return canvasHeight - screenshotHeight;
        return (canvasHeight - screenshotHeight) / 2;
    }

    function drawEditorBackground(ctx, w, h) {
        if (window.backgroundMode === "solid") {
            ctx.fillStyle = window.backgroundSolidColor.toString();
            ctx.fillRect(0, 0, w, h);
        } else if (window.backgroundMode === "image") {
            // Keep exports deterministic while the image is loading or unavailable.
            ctx.fillStyle = window.backgroundSolidColor.toString();
            ctx.fillRect(0, 0, w, h);

            if (backgroundImageLoader.status === Image.Ready) {
                const sourceW = backgroundImageLoader.sourceSize.width;
                const sourceH = backgroundImageLoader.sourceSize.height;
                if (sourceW > 0 && sourceH > 0) {
                    const scale = Math.max(w / sourceW, h / sourceH);
                    const drawW = sourceW * scale;
                    const drawH = sourceH * scale;
                    ctx.drawImage(backgroundImageLoader, (w - drawW) / 2, (h - drawH) / 2, drawW, drawH);
                }
            }

            if (window.backgroundImageDim) {
                ctx.fillStyle = Qt.rgba(0, 0, 0, window.backgroundImageDimStrength / 100.0);
                ctx.fillRect(0, 0, w, h);
            }
        } else if (window.backgroundMode === "gradient") {
            const angleRad = (window.backgroundGradientAngle * Math.PI) / 180;
            const x1 = w / 2 - Math.cos(angleRad) * w / 2;
            const y1 = h / 2 - Math.sin(angleRad) * h / 2;
            const x2 = w / 2 + Math.cos(angleRad) * w / 2;
            const y2 = h / 2 + Math.sin(angleRad) * h / 2;
            const grad = ctx.createLinearGradient(x1, y1, x2, y2);
            grad.addColorStop(0, window.backgroundGradientStart.toString());
            grad.addColorStop(1, window.backgroundGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        } else if (window.backgroundMode === "radial") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
            grad.addColorStop(0, window.backgroundGradientStart.toString());
            grad.addColorStop(1, window.backgroundGradientEnd.toString());
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, w, h);
        } else if (window.backgroundMode === "conic") {
            const cx = w / 2;
            const cy = h / 2;
            const r = Math.hypot(cx, cy);
            const startAngle = (window.backgroundGradientAngle * Math.PI) / 180;
            const startColor = window.backgroundGradientStart.toString();
            const endColor = window.backgroundGradientEnd.toString();
            if (typeof ctx.createConicGradient === "function") {
                const grad = ctx.createConicGradient(startAngle, cx, cy);
                grad.addColorStop(0, startColor);
                grad.addColorStop(0.5, endColor);
                grad.addColorStop(1, startColor);
                ctx.fillStyle = grad;
                ctx.fillRect(0, 0, w, h);
                return;
            }

            const numSlices = 90;

            // Cache color components to avoid JS-to-C++ property boundary crossing cost
            const startCol = window.backgroundGradientStart;
            const endCol = window.backgroundGradientEnd;
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
                const angle2 = startAngle + ((i + 1.2) / numSlices) * Math.PI * 2;
                const phase = (i + 0.5) / numSlices;
                const t = phase <= 0.5 ? phase * 2 : (1 - phase) * 2;
                const rComp = Math.round(sr * (1 - t) + er * t);
                const gComp = Math.round(sg * (1 - t) + eg * t);
                const bComp = Math.round(sb * (1 - t) + eb * t);
                const aComp = sa * (1 - t) + ea * t;
                ctx.fillStyle = `rgba(${rComp},${gComp},${bComp},${aComp})`;
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
        const factor = window.backgroundScaleFactor;
        return {
            x: window.screenshotXOffset,
            y: window.screenshotYOffset,
            w: window.screenshotWidth * factor,
            h: window.screenshotHeight * factor,
            r: window.backgroundCornerRadius * factor
        };
    }

    function drawScreenshotShadow(ctx, scale) {
        if (window.backgroundShadowStrength <= 0) return;
        ctx.save();
        const layout = window.getScreenshotLayout();
        const r = layout.r;
        const x = layout.x;
        const y = layout.y;
        const w = layout.w;
        const h = layout.h;
        
        const s = (scale !== undefined && scale > 0) ? scale : 1.0;
        const opacity = (window.backgroundShadowStrength / 100.0) * Constants.shadowBaseOpacityFactor;
        const STEPS = Constants.defaultShadowSteps;
        
        // Proportional shadow bounds for small layouts
        const baseBlur = Math.min(Constants.maxShadowBlur, Math.min(w, h) * 0.15);
        const baseOffset = Math.min(Constants.maxShadowOffset, Math.min(w, h) * 0.08);
        
        const maxOffset = baseOffset / s;
        const maxBlur = baseBlur / s;
        
        // Draw 12 concentric shadow layers with quadratic spacing and falloff for smooth rendering
        for (let i = 1; i <= STEPS; i++) {
            const t = i / STEPS;
            const blur = Math.pow(t, 1.5) * maxBlur;
            const offset = Math.pow(t, 1.5) * maxOffset;
            const verticalOffset = offset * 0.35;
            const alpha = opacity * Math.pow(1.0 - t, 1.5) * 0.75;
            
            ctx.fillStyle = Qt.rgba(0, 0, 0, alpha);
            
            const sx = x - blur/2;
            const sy = y - blur/2 + verticalOffset;
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

    function drawScreenshotImage(ctx, imgSource, skipClip) {
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
        
        if (!skipClip) {
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
        }
        
        const rawW = imgSource.sourceSize.width;
        const rawH = imgSource.sourceSize.height;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            ctx.translate(-window.cropRect.x, -window.cropRect.y);
        }

        ctx.translate(x + uncroppedW / 2, y + uncroppedH / 2);
        if (window.bgRotation !== 0) {
            ctx.rotate(window.bgRotation * Math.PI / 180);
        }
        const sx = window.bgFlipH ? -1 : 1;
        const sy = window.bgFlipV ? -1 : 1;
        if (sx !== 1 || sy !== 1) {
            ctx.scale(sx, sy);
        }

        ctx.drawImage(imgSource, -rawW / 2, -rawH / 2, rawW, rawH);
        ctx.restore();
    }

    property bool isZoomPressed: false
    property real cursorX: 0
    property real cursorY: 0

    property bool showAnnotations: true
    property bool watermarkEnabled: false
    onShowAnnotationsChanged: {
        window.requestPaintAll();
    }

    function setWatermarkEnabled(enabled) {
        window.watermarkEnabled = enabled;
        window.requestPaintAll();
    }
    property var copiedStroke: null
    property bool pastePreviewActive: false

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
    property string preGrabCalloutShape: "rect"

    function savePreGrabState() {
        window.preGrabStrokeWidth = window.strokeWidth;
        window.preGrabTextFontSize = window.textFontSize;
        window.preGrabPixelateIntensity = window.pixelateIntensity;
        window.preGrabSpotlightIntensity = window.spotlightIntensity;
        window.preGrabCalloutZoom = window.calloutZoom;
        window.preGrabColor = window.currentColor;
        window.preGrabRedactMode = window.activeRedactMode;
        window.preGrabRedactShape = window.activeRedactShape;
        window.preGrabCalloutLinkLines = window.calloutLinkLines;
        window.preGrabCalloutShape = window.calloutShape;
    }

    function restorePreGrabState() {
        const restoreColor = window.preGrabColor;
        window.strokeWidth = window.preGrabStrokeWidth;
        window.textFontSize = window.preGrabTextFontSize;
        window.pixelateIntensity = window.preGrabPixelateIntensity;
        window.spotlightIntensity = window.preGrabSpotlightIntensity;
        window.calloutZoom = window.preGrabCalloutZoom;
        window.currentColor = restoreColor;
        window.activeRedactMode = window.preGrabRedactMode;
        window.activeRedactShape = window.preGrabRedactShape;
        window.calloutLinkLines = window.preGrabCalloutLinkLines;
        window.calloutShape = window.preGrabCalloutShape;
    }
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []
    property real originalRotation: 0

    // Text Input Management
    property bool isTyping: false
    property point typingCoords: Qt.point(0,0)
    property string currentTypingText: ""
    property int typingCursorIndex: 0
    property var editingStroke: null
    property bool typingIsSpeechBubble: false
    property bool typingHasTargetCoords: false
    property point typingTargetCoords: Qt.point(0,0)
    readonly property bool inlineTextEditorActive: window.isTyping && window.textInputMode === "inline"
    property var inlineTextEditorItem: null

    backgroundOpacity: {
        const data = window.parentWidget && window.parentWidget.pluginData;
        if (!data) return 0.6;
        if (data.overlayOpacity !== undefined) return data.overlayOpacity / 100;
        if (data.modalOpacity !== undefined) return data.modalOpacity / 100;
        return 0.6;
    }
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

    readonly property var pluginData: (window.parentWidget && window.parentWidget.pluginData) ? window.parentWidget.pluginData : ({})

    // Rich Text Options
    property bool textBold: pluginData.textBold !== undefined ? pluginData.textBold : false
    onTextBoldChanged: {
        window.repaintActiveCanvas();
    }
    property bool textItalic: pluginData.textItalic !== undefined ? pluginData.textItalic : false
    onTextItalicChanged: {
        window.repaintActiveCanvas();
    }
    property bool textUnderline: pluginData.textUnderline !== undefined ? pluginData.textUnderline : false
    onTextUnderlineChanged: {
        window.repaintActiveCanvas();
    }
    property bool textBackground: pluginData.textBackground !== undefined ? pluginData.textBackground : false
    onTextBackgroundChanged: {
        window.repaintActiveCanvas();
    }
    property int textCornerRadius: pluginData.textCornerRadius !== undefined ? pluginData.textCornerRadius : 8
    onTextCornerRadiusChanged: {
        window.repaintActiveCanvas();
    }
    property string textFontFamily: (pluginData.textFontFamily && pluginData.textFontFamily !== "system") ? pluginData.textFontFamily : (Theme.fontFamily || "sans-serif")
    onTextFontFamilyChanged: {
        window.repaintActiveCanvas();
    }
    property string stampFontFamily: (pluginData.stampFontFamily && pluginData.stampFontFamily !== "system") ? pluginData.stampFontFamily : (Theme.fontFamily || "sans-serif")
    onStampFontFamilyChanged: {
        window.repaintActiveCanvas();
    }
    property bool stampOuterRing: pluginData.stampOuterRing !== undefined ? pluginData.stampOuterRing : false
    onStampOuterRingChanged: window.requestPaintAll()
    readonly property string textInputMode: pluginData.textInputMode !== undefined ? pluginData.textInputMode : "inline"
    readonly property string toolbarPosition: pluginData.toolbarPosition !== undefined ? pluginData.toolbarPosition : "bottom"
    readonly property bool configShowToolbar: pluginData.showToolbar !== undefined ? pluginData.showToolbar : true
    readonly property bool enableMagnifier: true
    property bool toolbarVisible: true
    onConfigShowToolbarChanged: {
        window.toolbarVisible = window.configShowToolbar;
    }

    function getUncroppedImageSize() {
        const rawW = window.bgImageItem ? window.bgImageItem.sourceSize.width : 1;
        const rawH = window.bgImageItem ? window.bgImageItem.sourceSize.height : 1;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        return {
            width: isRotated90 ? rawH : rawW,
            height: isRotated90 ? rawW : rawH
        };
    }

    function rotateScreenshot(direction) {
        const isLeft = (direction === "left");
        const imageSize = window.getUncroppedImageSize();
        const uncroppedW = imageSize.width;
        const uncroppedH = imageSize.height;

        if (window.hasSelection) {
            const cx = window.cropRect.x;
            const cy = window.cropRect.y;
            const cw = window.cropRect.width;
            const ch = window.cropRect.height;
            if (isLeft) {
                window.cropRect = Qt.rect(cy, uncroppedW - (cx + cw), ch, cw);
            } else {
                window.cropRect = Qt.rect(uncroppedH - (cy + ch), cx, ch, cw);
            }
        }

        const list = [...window.strokes];
        for (let s of list) {
            if (s.points) {
                s.points = s.points.map(p => ({
                    x: isLeft ? p.y : uncroppedH - p.y,
                    y: isLeft ? uncroppedW - p.x : p.x
                }));
            }
        }
        window.strokes = list;
        window.bgRotation = (window.bgRotation + (isLeft ? 270 : 90)) % 360;
        window.requestPaintAll();
    }

    function mirrorScreenshot(direction) {
        const isVertical = (direction === "vertical" || direction === "v");
        const imageSize = window.getUncroppedImageSize();
        const uncroppedW = imageSize.width;
        const uncroppedH = imageSize.height;

        if (window.hasSelection) {
            const cx = window.cropRect.x;
            const cy = window.cropRect.y;
            const cw = window.cropRect.width;
            const ch = window.cropRect.height;
            if (isVertical) {
                window.cropRect = Qt.rect(cx, uncroppedH - (cy + ch), cw, ch);
            } else {
                window.cropRect = Qt.rect(uncroppedW - (cx + cw), cy, cw, ch);
            }
        }

        const list = [...window.strokes];
        for (let s of list) {
            if (s.points) {
                s.points = s.points.map(p => ({
                    x: isVertical ? p.x : uncroppedW - p.x,
                    y: isVertical ? uncroppedH - p.y : p.y
                }));
            }
        }
        window.strokes = list;

        if (window.bgRotation === 0 || window.bgRotation === 180) {
            if (isVertical) window.bgFlipV = !window.bgFlipV;
            else window.bgFlipH = !window.bgFlipH;
        } else {
            if (isVertical) window.bgFlipH = !window.bgFlipH;
            else window.bgFlipV = !window.bgFlipV;
        }

        window.requestPaintAll();
    }

    function resetRegionScanRect() {
        window.ocrRect = Qt.rect(0, 0, 0, 0);
    }

    function startRegionScanTool(tool) {
        window.resetRegionScanRect();
        window.currentTool = tool;
        window.requestActiveCanvasPaint();
    }

    function finishRegionScanTool() {
        window.currentTool = window.lastActiveTool;
        window.resetRegionScanRect();
        window.requestActiveCanvasPaint();
    }

    function getRegionScanCrop() {
        const r = window.ocrRect;
        if (r.width < 10 || r.height < 10) return null;

        // Account for crop offset when mapping to source image coordinates.
        const cropOffsetX = window.hasSelection ? window.cropRect.x : 0;
        const cropOffsetY = window.hasSelection ? window.cropRect.y : 0;
        return {
            x: Math.round(r.x + cropOffsetX),
            y: Math.round(r.y + cropOffsetY),
            width: Math.round(r.width),
            height: Math.round(r.height)
        };
    }

    function getBackgroundImagePath() {
        let bgPath = Paths.strip(window.bgImageSource);
        const qIdx = bgPath.indexOf("?");
        if (qIdx !== -1) bgPath = bgPath.substring(0, qIdx);
        return bgPath;
    }

    function makeTempCropPath(kind) {
        const uniqueId = `${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
        return `/tmp/dms_${kind}_crop_${uniqueId}.png`;
    }

    function runOcr() {
        window.startRegionScanTool("ocr");
    }

    function showScanResult(type, text) {
        if (window.scanResultPopoverRef) {
            window.scanResultPopoverRef.show(type, text);
        }
    }

    /**
     * Crops the selected region and runs the configured external scanner.
     * @param {string} type - Scan type: "ocr" or "qr".
     * @param {object} crop - Source image crop with x, y, width and height.
     */
    function runRegionScan(type, crop) {
        const generation = window.editorSessionGeneration;
        const isQr = type === "qr";
        const scanConfig = isQr ? {
            cropCommandId: "crop-qr-temp",
            scanCommandId: "run-qr-scan",
            cleanupCommandId: "cleanup-qr-temp",
            scanArgs: (path) => ["zbarimg", "--raw", "-q", path],
            noResultMessage: "QR Scan: No QR code detected",
            scanErrorMessage: "QR Scan failed or command execution error",
            cropErrorMessage: "QR Scan failed: Could not crop image"
        } : {
            cropCommandId: "crop-ocr-temp",
            scanCommandId: "run-ocr",
            cleanupCommandId: "cleanup-ocr-temp",
            scanArgs: (path) => ["tesseract", path, "-", "-l", "eng"],
            noResultMessage: "OCR: No text detected",
            scanErrorMessage: "OCR failed during text extraction",
            cropErrorMessage: "OCR failed: Could not crop image"
        };

        const bgPath = window.getBackgroundImagePath();
        const tempCropPath = window.makeTempCropPath(type);
        const cropArgs = ["magick", bgPath, "-crop", `${crop.width}x${crop.height}+${crop.x}+${crop.y}`, tempCropPath];

        Proc.runCommand(scanConfig.cropCommandId, cropArgs, (stdout1, exitCode1) => {
            if (generation !== window.editorSessionGeneration) {
                Proc.runCommand(scanConfig.cleanupCommandId, ["rm", "-f", tempCropPath]);
                return;
            }
            if (exitCode1 !== 0) {
                if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.trFor("quickCapture", scanConfig.cropErrorMessage));
                }
                window.finishRegionScanTool();
                return;
            }

            Proc.runCommand(scanConfig.scanCommandId, scanConfig.scanArgs(tempCropPath), (stdout2, exitCode2) => {
                if (generation !== window.editorSessionGeneration) {
                    Proc.runCommand(scanConfig.cleanupCommandId, ["rm", "-f", tempCropPath]);
                    return;
                }
                Proc.runCommand(scanConfig.cleanupCommandId, ["rm", "-f", tempCropPath]);

                if (exitCode2 === 0) {
                    const result = stdout2.trim();
                    if (result) {
                        window.showScanResult(type, result);
                    } else if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showInfo(I18n.trFor("quickCapture", scanConfig.noResultMessage));
                    }
                } else if (isQr && exitCode2 === 4) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showInfo(I18n.trFor("quickCapture", scanConfig.noResultMessage));
                    }
                } else if (typeof ToastService !== "undefined" && ToastService) {
                    ToastService.showError(I18n.trFor("quickCapture", scanConfig.scanErrorMessage));
                }
                window.finishRegionScanTool();
            });
        });
    }

    function executeOcr() {
        const crop = window.getRegionScanCrop();
        if (!crop) {
            window.resetRegionScanRect();
            window.requestActiveCanvasPaint();
            return;
        }
        window.runRegionScan("ocr", crop);
    }

    function runQrScan() {
        window.startRegionScanTool("qr");
    }

    function executeQrScan() {
        const crop = window.getRegionScanCrop();
        if (!crop) {
            window.resetRegionScanRect();
            window.requestActiveCanvasPaint();
            return;
        }
        window.runRegionScan("qr", crop);
    }

    // Modal sized to the screenshot (logical px), clamped between the toolbar's
    // footprint and 90% of the screen; falls back to 90% until the image loads
    readonly property real _screenW: window.presentationScreen ? window.presentationScreen.width : (Quickshell.screens[0] ? Quickshell.screens[0].width : 1920)
    readonly property real _screenH: window.presentationScreen ? window.presentationScreen.height : (Quickshell.screens[0] ? Quickshell.screens[0].height : 1080)
    readonly property real _maxModalW: Math.round((config.modalAspectRatio === "portrait" ? Math.min(_screenW, _screenH) : Math.max(_screenW, _screenH)) * 0.9)
    readonly property real _maxModalH: Math.round((config.modalAspectRatio === "portrait" ? Math.max(_screenW, _screenH) : Math.min(_screenW, _screenH)) * 0.9)
    readonly property bool _toolbarHorizontal: window.toolbarPosition === "top" || window.toolbarPosition === "bottom"
    // Chrome = boardContainer margins plus the edge the toolbar occupies (56px rail + its margin)
    readonly property real _chromeW: Theme.spacingM * 2 + (window.toolbarVisible && !_toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _chromeH: Theme.spacingM * 2 + (window.toolbarVisible && _toolbarHorizontal ? 56 + Theme.spacingM : 0)
    readonly property real _floatingTooltipPadding: 10
    readonly property real _minModalW: _toolbarHorizontal && window.toolbarItem && window.toolbarItem.width ? window.toolbarItem.width + Theme.spacingM * 2 : 400
    readonly property real _minModalH: !_toolbarHorizontal && window.toolbarItem && window.toolbarItem.height ? window.toolbarItem.height + Theme.spacingM * 2 : 300
    readonly property bool _bgSizeKnown: window.bgImageItem
                                         && window.bgImageItem.status === Image.Ready
                                         && window.bgImageItem.sourceSize.width > 0
                                         && window.bgImageItem.sourceSize.height > 0
    // Compositor scale (not Screen.devicePixelRatio, which reports the integer buffer scale)
    readonly property real _outputScale: (window.presentationScreen && CompositorService.getScreenScale(window.presentationScreen)) || 1
    readonly property bool _shouldScale: !!(window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.modalScaleToContent)
    modalWidth: _shouldScale && _bgSizeKnown ? Math.round(Helpers.clamp(window.bgImageItem.sourceSize.width / _outputScale + _chromeW, _minModalW, _maxModalW)) : _maxModalW
    modalHeight: _shouldScale && _bgSizeKnown ? Math.round(Helpers.clamp(window.bgImageItem.sourceSize.height / _outputScale + _chromeH, _minModalH, _maxModalH)) : _maxModalH
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
    property int bgRotation: 0
    property bool bgFlipH: false
    property bool bgFlipV: false
    property var activeCanvas: null
    property var bakedCanvas: null
    property var backgroundCanvas: null
    property var bgImageItem: null
    property var boardContainerItem: null
    property var exportCanvasItem: null
    property var offscreenSamplerItem: null

    onSelectedStrokeChanged: window.requestAnnotationPaintAll()
    onEffectiveBackgroundModeChanged: window.requestPaintAll()
    onBackgroundSolidColorChanged: window.requestPaintAll()
    onBackgroundGradientStartChanged: window.requestPaintAll()
    onBackgroundGradientEndChanged: window.requestPaintAll()
    onBackgroundPaddingChanged: window.requestPaintAll()
    onBackgroundCornerRadiusChanged: window.requestPaintAll()
    onBackgroundShadowStrengthChanged: window.requestPaintAll()
    onBackgroundGradientAngleChanged: window.requestPaintAll()
    onBackgroundAspectRatioChanged: window.requestPaintAll()
    onCustomAspectRatioChanged: window.requestPaintAll()
    onBackgroundAlignmentChanged: window.requestPaintAll()
    onBackgroundImageDimChanged: window.requestPaintAll()
    onBackgroundImageDimStrengthChanged: window.requestPaintAll()
    onEffectiveBackgroundImagePathChanged: window.requestPaintAll()
    onEditScaleChanged: window.requestPaintAll()

    function requestPaintAll() {
        if (window.backgroundCanvas) window.backgroundCanvas.requestPaint();
        window.repaintActiveCanvas();
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }

    function requestAnnotationPaintAll() {
        window.repaintActiveCanvas();
        if (window.bakedCanvas) window.bakedCanvas.requestPaint();
    }

    function applyEditorAnnotationTransform(ctx, isBackgroundActive) {
        if (isBackgroundActive || window.hasActiveCropSelection) {
            const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
            const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
            ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
            if (isBackgroundActive) {
                ctx.scale(window.backgroundScaleFactor, window.backgroundScaleFactor);
            }
            ctx.translate(-cropX, -cropY);
        } else if (window.hasSelection) {
            ctx.beginPath();
            ctx.rect(window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height);
            ctx.clip();
        }
    }

    function applyExportAnnotationTransform(ctx, isBackgroundActive) {
        if (isBackgroundActive || window.hasActiveCropSelection) {
            const cropX = window.hasActiveCropSelection ? window.cropRect.x : 0;
            const cropY = window.hasActiveCropSelection ? window.cropRect.y : 0;
            ctx.translate(window.screenshotXOffset, window.screenshotYOffset);
            ctx.scale(window.backgroundScaleFactor, window.backgroundScaleFactor);
            ctx.translate(-cropX, -cropY);
        }
    }

    function getSpotlightRenderConfig() {
        return {
            screenshotWidth: window.screenshotWidth,
            screenshotHeight: window.screenshotHeight,
            spotlightIntensity: window.spotlightIntensity,
            hasActiveCropSelection: window.hasActiveCropSelection,
            cropRect: window.cropRect,
            effectiveBackgroundMode: window.effectiveBackgroundMode,
            backgroundCornerRadius: window.backgroundCornerRadius,
            roundRect: window.roundRect,
            cornerRadius: Theme.cornerRadius
        };
    }

    function drawStroke(ctx, stroke, extraConfig) {
        DrawingRenderer.drawStroke(ctx, stroke, Helpers, Qt, Theme, {
            roundRect: window.roundRect,
            roundHighlighter: window.roundHighlighter,
            bgImageItem: window.bgImageItem,
            offscreenSampler: window.offscreenSamplerItem,
            canvasWidth: window.canvasWidth,
            canvasHeight: window.canvasHeight,
            canvasMinX: window.hasActiveCropSelection ? window.cropRect.x : 0,
            canvasMinY: window.hasActiveCropSelection ? window.cropRect.y : 0,
            stampFontFamily: window.stampFontFamily,
            stampOuterRing: window.stampOuterRing,
            bgRotation: window.bgRotation,
            bgFlipH: window.bgFlipH,
            bgFlipV: window.bgFlipV,
            hasActiveCropSelection: window.hasActiveCropSelection,
            cropRect: window.cropRect,
            screenshotXOffset: window.screenshotXOffset,
            screenshotYOffset: window.screenshotYOffset,
            cropOffsetX: window.hasActiveCropSelection ? window.cropRect.x : 0,
            cropOffsetY: window.hasActiveCropSelection ? window.cropRect.y : 0,
            skipText: extraConfig && extraConfig.skipText === true
        });
    }

    function drawBakedAnnotationLayer(ctx) {
        if (!window.showAnnotations) return;

        const strokes = window.strokes;
        const selectedStroke = window.selectedStroke;

        // Pixelate must render before spotlight dimming.
        for (let i = 0; i < strokes.length; i++) {
            if (strokes[i].tool === "pixelate" && strokes[i] !== selectedStroke) {
                window.drawStroke(ctx, strokes[i]);
            }
        }

        const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
        const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
        const spotlightStrokes = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
        if (spotlightStrokes.length > 0 && !isDrawingSpotlight && !isEditingSpotlight) {
            DrawingRenderer.drawSpotlightOverlay(ctx, spotlightStrokes, window.getSpotlightRenderConfig());
        }

        if (!isDrawingSpotlight && !isEditingSpotlight) {
            for (let i = 0; i < strokes.length; i++) {
                if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate" && strokes[i] !== selectedStroke && (!window.isTyping || strokes[i] !== window.editingStroke)) {
                    window.drawStroke(ctx, strokes[i]);
                }
            }
        }
    }

    function drawActiveAnnotationLayer(ctx) {
        if (!window.showAnnotations) return;

        const strokes = window.strokes;
        const selectedStroke = window.selectedStroke;

        if (window.currentStroke && window.currentStroke.tool === "pixelate") {
            const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
            window.drawStroke(ctx, tempStroke);
        }
        if (selectedStroke && selectedStroke.tool === "pixelate") {
            window.drawStroke(ctx, selectedStroke);
        }

        let pastePreview = null;
        if (window.pastePreviewActive) {
            pastePreview = window.getPastePreviewStroke();
        }

        const isDrawingSpotlight = window.currentStroke && window.currentStroke.tool === "spotlight";
        const isEditingSpotlight = selectedStroke && selectedStroke.tool === "spotlight";
        const isPastingSpotlight = pastePreview && pastePreview.tool === "spotlight";
        if (isDrawingSpotlight || isEditingSpotlight || isPastingSpotlight) {
            const activeSpotlights = strokes.filter(s => s.tool === "spotlight" && s !== selectedStroke);
            if (isDrawingSpotlight) activeSpotlights.push(window.currentStroke);
            if (isEditingSpotlight) activeSpotlights.push(selectedStroke);
            if (isPastingSpotlight) activeSpotlights.push(pastePreview);

            DrawingRenderer.drawSpotlightOverlay(ctx, activeSpotlights, window.getSpotlightRenderConfig());

            if (window.currentStroke && (window.currentStroke.tool === "spotlight" || window.currentStroke.tool === "pixelate") && window.currentStroke.points.length >= 2) {
                const p0 = window.currentStroke.points[0];
                const p1 = window.currentStroke.points[window.currentStroke.points.length - 1];
                const bounds = Helpers.getRectBounds(p0, p1);
                DrawingRenderer.drawHighContrastDashedRect(ctx, bounds.x1, bounds.y1,
                    bounds.x2 - bounds.x1, bounds.y2 - bounds.y1);
            }
        }

        // Spotlight is a background effect: keep regular annotations above it
        // while its active overlay is being drawn or edited.
        if (isDrawingSpotlight || isEditingSpotlight || isPastingSpotlight) {
            for (let i = 0; i < strokes.length; i++) {
                if (strokes[i].tool !== "spotlight" && strokes[i].tool !== "pixelate" && (!window.isTyping || strokes[i] !== window.editingStroke)) {
                    window.drawStroke(ctx, strokes[i]);
                }
            }
        }

        if (window.currentStroke && window.currentStroke.tool !== "spotlight" && window.currentStroke.tool !== "pixelate") {
            const tempStroke = Object.assign({}, window.currentStroke, { isCurrent: true });
            window.drawStroke(ctx, tempStroke);
        }

        if (selectedStroke && selectedStroke.tool !== "spotlight" && selectedStroke.tool !== "pixelate" && (!window.isTyping || selectedStroke !== window.editingStroke)) {
            window.drawStroke(ctx, selectedStroke);
        }

        if (pastePreview) window.drawStroke(ctx, pastePreview);

        const handleStroke = pastePreview || selectedStroke;
        if (handleStroke && window.currentTool === "select") {
            DrawingRenderer.drawSelectionHandles(ctx, handleStroke, Theme, Qt, Helpers);
        }
    }

    function drawTypingPreview(ctx) {
        if (!window.isTyping) return;

        const rawText = window.currentTypingText || "";
        if (window.inlineTextEditorActive) {
            const previewStroke = window.getTypingStrokeStyle(rawText);
            previewStroke.isSpeechBubble = window.typingIsSpeechBubble;
            if (previewStroke.isSpeechBubble) {
                const targetCoords = window.typingHasTargetCoords
                    ? window.typingTargetCoords
                    : window.defaultTypingSpeechBubbleTarget();
                previewStroke.points = [
                    Qt.point(targetCoords.x, targetCoords.y),
                    Qt.point(window.typingCoords.x, window.typingCoords.y)
                ];
            } else {
                previewStroke.points = [Qt.point(window.typingCoords.x, window.typingCoords.y)];
            }
            window.drawStroke(ctx, previewStroke, { skipText: true });
            return;
        }

        ctx.fillStyle = window.currentColor;

        let styleStr = "";
        if (window.textItalic) styleStr += "italic ";
        if (window.textBold) styleStr += "bold ";

        ctx.font = `${styleStr}${Math.round(window.textFontSize)}px ${DrawingRenderer.canvasFontFamily(window.textFontFamily)}`;
        ctx.textAlign = "left";
        ctx.textBaseline = "middle";

        const previewLines = rawText.split("\n");
        const lineH = window.textFontSize * 1.35;

        if (window.typingIsSpeechBubble && rawText.length > 0) {
            const targetCoords = window.typingHasTargetCoords
                ? window.typingTargetCoords
                : window.defaultTypingSpeechBubbleTarget();
            const previewStroke = window.getTypingStrokeStyle(rawText);
            previewStroke.isSpeechBubble = true;
            previewStroke.points = [
                Qt.point(targetCoords.x, targetCoords.y),
                Qt.point(window.typingCoords.x, window.typingCoords.y)
            ];
            window.drawStroke(ctx, previewStroke);
            return;
        }

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

    }

    function drawExportAnnotationLayer(ctx, isBackgroundActive) {
        if (!window.showAnnotations) return;

        ctx.save();
        window.applyExportAnnotationTransform(ctx, isBackgroundActive);

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
                DrawingRenderer.drawSpotlightOverlay(ctx, spotlights, window.getSpotlightRenderConfig());
            }
        }

        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i].tool !== "pixelate" && window.strokes[i].tool !== "spotlight") {
                window.drawStroke(ctx, window.strokes[i]);
            }
        }

        if (window.currentStroke && window.currentStroke.tool !== "pixelate" && window.currentStroke.tool !== "spotlight") {
            window.drawStroke(ctx, window.currentStroke);
        }

        ctx.restore();
    }

    function getWatermarkRenderConfig(enabled) {
        const pData = (window.parentWidget && window.parentWidget.pluginData) || {};
        return {
            enabled: enabled && window.watermarkEnabled,
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
        };
    }

    function drawWatermarkLayer(ctx, enabled) {
        DrawingRenderer.drawWatermark(ctx, window.getWatermarkRenderConfig(enabled), config);
    }

    function drawEditorBackgroundLayer(ctx, imgSource, isBackgroundActive) {
        if (isBackgroundActive) {
            window.drawEditorBackground(ctx, window.canvasWidth, window.canvasHeight);
            window.drawScreenshotShadow(ctx, window.editScale);
            window.drawScreenshotImage(ctx, imgSource);
            return;
        }

        if (window.currentTool !== "colorpicker" || imgSource.status !== Image.Ready) return;

        ctx.save();
        const rawW = imgSource.sourceSize.width;
        const rawH = imgSource.sourceSize.height;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            ctx.translate(-window.cropRect.x, -window.cropRect.y);
        }

        ctx.translate(uncroppedW / 2, uncroppedH / 2);
        if (window.bgRotation !== 0) {
            ctx.rotate(window.bgRotation * Math.PI / 180);
        }
        const sx = window.bgFlipH ? -1 : 1;
        const sy = window.bgFlipV ? -1 : 1;
        if (sx !== 1 || sy !== 1) {
            ctx.scale(sx, sy);
        }

        ctx.drawImage(imgSource, -rawW / 2, -rawH / 2, rawW, rawH);
        ctx.restore();
    }

    function drawExportBackgroundLayer(ctx, imgSource, isBackgroundActive, exportDpr) {
        if (isBackgroundActive) {
            window.drawEditorBackground(ctx, window.canvasWidth, window.canvasHeight);
            window.drawScreenshotShadow(ctx, 1 / exportDpr);
            window.drawScreenshotImage(ctx, imgSource);
            return;
        }

        if (imgSource.status !== Image.Ready) return;

        ctx.save();
        const rawW = imgSource.sourceSize.width;
        const rawH = imgSource.sourceSize.height;
        const isRotated90 = (window.bgRotation === 90 || window.bgRotation === 270);
        const uncroppedW = isRotated90 ? rawH : rawW;
        const uncroppedH = isRotated90 ? rawW : rawH;

        if (window.hasSelection) {
            ctx.translate(-window.cropRect.x, -window.cropRect.y);
        }

        ctx.translate(uncroppedW / 2, uncroppedH / 2);
        if (window.bgRotation !== 0) {
            ctx.rotate(window.bgRotation * Math.PI / 180);
        }
        const sx = window.bgFlipH ? -1 : 1;
        const sy = window.bgFlipV ? -1 : 1;
        if (sx !== 1 || sy !== 1) {
            ctx.scale(sx, sy);
        }

        ctx.drawImage(imgSource, -rawW / 2, -rawH / 2, rawW, rawH);
        ctx.restore();
    }

    function renderBakedCanvas(canvas, imgSource) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.save();
        ctx.scale(window.editScale, window.editScale);

        const isBackgroundActive = window.effectiveBackgroundMode !== "none";
        if (!isBackgroundActive) {
            window.drawEditorBackgroundLayer(ctx, imgSource, false);
        }

        ctx.save();
        window.applyEditorAnnotationTransform(ctx, isBackgroundActive);
        window.drawBakedAnnotationLayer(ctx);
        ctx.restore();

        window.drawWatermarkLayer(ctx, window.currentTool !== "crop");

        ctx.restore();
    }

    function renderBackgroundCanvas(canvas, imgSource) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (window.effectiveBackgroundMode === "none") return;

        ctx.save();
        ctx.scale(window.editScale, window.editScale);
        window.drawEditorBackgroundLayer(ctx, imgSource, true);
        ctx.restore();
    }

    function finishExportCanvas(canvas) {
        const tempOut = `/tmp/dms_capture_${Date.now()}.png`;
        canvas.save(tempOut);

        if (window.exportCallback) {
            const cb = window.exportCallback;
            window.exportCallback = null;
            Qt.callLater(() => {
                cb(tempOut);
            });
        }
    }

    function renderExportCanvas(canvas, imgSource) {
        const ctx = canvas.getContext("2d");
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        ctx.save();
        ctx.scale(1 / canvas.exportDpr, 1 / canvas.exportDpr);

        const isBackgroundActive = window.effectiveBackgroundMode !== "none";
        window.drawExportBackgroundLayer(ctx, imgSource, isBackgroundActive, canvas.exportDpr);
        window.drawExportAnnotationLayer(ctx, isBackgroundActive);
        window.drawWatermarkLayer(ctx, true);

        ctx.restore();
        window.finishExportCanvas(canvas);
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

    function getCursorAbsolutePoint() {
        let mx = window.cursorX;
        let my = window.cursorY;
        if (window.effectiveBackgroundMode !== "none") {
            mx = (mx - window.screenshotXOffset) / window.backgroundScaleFactor;
            my = (my - window.screenshotYOffset) / window.backgroundScaleFactor;
        }
        return window.hasActiveCropSelection ? Qt.point(mx + window.cropRect.x, my + window.cropRect.y) : Qt.point(mx, my);
    }

    function getPastePreviewStroke() {
        if (!window.copiedStroke) return;

        const absPt = window.getCursorAbsolutePoint();

        // Center using the rendered bounds, not just control points. Text stores its
        // origin as a top-left point, so point bounds alone place it beside the cursor.
        const bbox = Helpers.getStrokeBBox(window.copiedStroke, window.measureTextBounds);
        const centerX = (bbox.minX + bbox.maxX) / 2;
        const centerY = (bbox.minY + bbox.maxY) / 2;

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
        window.prepareStampCopyForPaste(pasted);
        return pasted;
    }

    function getStampCount() {
        let count = 0;
        for (let i = 0; i < window.strokes.length; i++) {
            if (window.strokes[i] && window.strokes[i].tool === "stamp") count++;
        }
        return count;
    }

    function getNextStampId() {
        let maxId = 0;
        for (let i = 0; i < window.strokes.length; i++) {
            const stroke = window.strokes[i];
            if (!stroke || stroke.tool !== "stamp") continue;
            const id = Number(stroke.id);
            if (isFinite(id)) maxId = Math.max(maxId, id);
        }
        return Math.max(maxId + 1, window.stampIdCounter);
    }

    function prepareStampCopyForPaste(stroke) {
        if (!stroke || stroke.tool !== "stamp") return;
        stroke.id = window.getNextStampId();
        stroke.counter = window.getStampCount() + 1;
        stroke.format = window.stampCounterFormat;
    }

    function beginPastePreview() {
        if (!window.copiedStroke) return;
        window.pastePreviewActive = true;
        window.currentTool = "select";
        window.repaintActiveCanvas();
    }

    function cancelPastePreview() {
        if (!window.pastePreviewActive) return false;
        window.pastePreviewActive = false;
        window.repaintActiveCanvas();
        return true;
    }

    function performPasteAction() {
        const pasted = window.getPastePreviewStroke();
        if (!pasted) return;

        window.pushStroke(pasted);
        window.pastePreviewActive = false;

        if (window.currentTool === "select") {
            window.savePreGrabState();
            window.strokeWidth = pasted.width;
            window.currentColor = pasted.color;
            if (pasted.tool === "redact" && pasted.redactMode) window.activeRedactMode = pasted.redactMode;
            if (pasted.tool === "redact" && pasted.redactShape) window.activeRedactShape = pasted.redactShape;
            if (pasted.tool === "callout") window.calloutShape = pasted.calloutShape !== undefined ? pasted.calloutShape : "rect";
            window.selectedStroke = pasted;
            window.pressCoords = window.getCursorAbsolutePoint();
            window.originalPoints = window.copyStrokePoints(pasted.points);
        }

        window.repaintActiveCanvas();
    }

    function getPresetTool(index) {
        const val = window.pluginData[`preset_${index}_tool`];
        return val !== undefined ? val : (Constants.defaultRadialTools[index] || "none");
    }

    function getPresetColor(index) {
        const val = window.pluginData[`preset_${index}_color`];
        if (val !== undefined) return val;
        const defaultColors = ["primary", "primary", "primary", "primary", "primary", "primary", "#000000", "#ffffff"];
        return defaultColors[index] || "primary";
    }

    function getPresetThickness(index) {
        const val = window.pluginData[`preset_${index}_thickness`];
        if (val === undefined) return Constants.getToolMeta("pen").defaultValue;
        const parsed = parseInt(val, 10);
        return isNaN(parsed) ? Constants.getToolMeta("pen").defaultValue : parsed;
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
    property real userZoomScale: 1.0
    readonly property real effectiveFitScale: window.fitScale * window.userZoomScale
    property real userPanX: 0.0
    property real userPanY: 0.0
    property bool isPanSpacePressed: false
    property bool isCtrlPressed: false
    property point lastPanMouse: Qt.point(0, 0)

    function adjustUserZoom(delta, focusPt) {
        const oldZoom = window.userZoomScale;
        const nextZoom = Helpers.clamp(oldZoom + delta, 1.0, 4.0);
        if (Math.abs(nextZoom - oldZoom) <= 0.001) return;

        window.userZoomScale = Math.round(nextZoom * 100) / 100.0;
        if (window.userZoomScale === 1.0) {
            window.userPanX = 0;
            window.userPanY = 0;
            return;
        }

        if (focusPt && focusPt.x !== undefined && focusPt.y !== undefined) {
            const ratio = window.userZoomScale / oldZoom;
            const newPanX = window.userPanX - (ratio - 1.0) * (focusPt.x - window.userPanX);
            const newPanY = window.userPanY - (ratio - 1.0) * (focusPt.y - window.userPanY);
            window.updatePanOffset(newPanX, newPanY);
        }
    }

    function resetUserZoom() {
        window.userZoomScale = 1.0;
        window.userPanX = 0;
        window.userPanY = 0;
    }

    function updatePanOffset(newX, newY) {
        const baseW = window.drawingCanvas ? window.drawingCanvas.width * window.drawingCanvas.scale : 800;
        const baseH = window.drawingCanvas ? window.drawingCanvas.height * window.drawingCanvas.scale : 600;
        const maxPanX = Math.max(500, (baseW * (window.userZoomScale || 1.0)) / 2);
        const maxPanY = Math.max(500, (baseH * (window.userZoomScale || 1.0)) / 2);
        window.userPanX = Helpers.clamp(newX, -maxPanX, maxPanX);
        window.userPanY = Helpers.clamp(newY, -maxPanY, maxPanY);
    }

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

    Connections {
        target: (typeof PopoutService !== "undefined") ? PopoutService.colorPickerModal : null
        ignoreUnknownSignals: true
        function onDialogClosed() {
            if (target) target.useOverlayLayer = false;
            window.shouldHaveFocus = Qt.binding(() => window.shouldBeVisible);
            if (window.floatingMode)
                Qt.callLater(() => window.focusModalAfterToolbarAction());
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

    FileBrowserSurfaceModal {
        id: saveAsDialog
        browserTitle: I18n.trFor("quickCapture", "Save Screenshot As")
        browserIcon: "save"
        browserType: "quick_capture_save"
        saveMode: true
        allowStacking: true
        onFileSelected: path => captureActions.performSaveAs(path)
    }

    Connections {
        target: saveAsDialog
        function onDialogClosed() {
            window.shouldHaveFocus = Qt.binding(() => window.shouldBeVisible);
            if (window.floatingMode)
                Qt.callLater(() => window.focusModalAfterToolbarAction());
        }
    }

    FileBrowserSurfaceModal {
        id: insertImageDialog
        browserTitle: I18n.trFor("quickCapture", "Insert Image")
        browserIcon: "add_photo_alternate"
        browserType: "quick_capture_insert_image"
        saveMode: false
        allowStacking: true
        fileExtensions: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif", "*.bmp"]
        onFileSelected: path => window.insertImageFromFile(path)
    }

    Connections {
        target: insertImageDialog
        function onDialogClosed() {
            window.shouldHaveFocus = Qt.binding(() => window.shouldBeVisible);
            if (window.floatingMode)
                Qt.callLater(() => window.focusModalAfterToolbarAction());
        }
    }

    function openInsertImageDialog() {
        if (insertImageDialog.shouldBeVisible) return;
        insertImageDialog.useOverlayLayer = true;
        insertImageDialog.fileExtensions = ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.svg", "*.gif", "*.bmp"];
        window.shouldHaveFocus = false;
        insertImageDialog.open();
    }

    function insertImageFromFile(filePath) {
        if (!filePath) return;
        let fileUrl = String(filePath).trim();
        if (!fileUrl.startsWith("file://") && !fileUrl.startsWith("http://") && !fileUrl.startsWith("https://") && !fileUrl.startsWith("data:")) {
            fileUrl = "file://" + fileUrl;
        }

        const tempImg = Qt.createQmlObject('import QtQuick; Image { visible: false; source: "' + fileUrl + '" }', window, "tempImgLoader_" + Date.now());
        if (!tempImg) return;

        function processAndInsert() {
            let origW = tempImg.implicitWidth || tempImg.sourceSize.width || 300;
            let origH = tempImg.implicitHeight || tempImg.sourceSize.height || 300;
            if (origW <= 0) origW = 300;
            if (origH <= 0) origH = 300;

            const visW = window.editWidth || 800;
            const visH = window.editHeight || 600;
            const centerX = visW / 2;
            const centerY = visH / 2;

            const maxW = visW * 0.5;
            const maxH = visH * 0.5;
            const scaleFactor = Math.min(1.0, maxW / origW, maxH / origH);

            const finalW = Math.round(origW * scaleFactor);
            const finalH = Math.round(origH * scaleFactor);

            const x1 = Math.round(centerX - finalW / 2);
            const y1 = Math.round(centerY - finalH / 2);
            const x2 = x1 + finalW;
            const y2 = y1 + finalH;

            const newStroke = {
                id: "img_" + Date.now(),
                tool: "image",
                color: "#000000",
                width: 1,
                points: [{ x: x1, y: y1 }, { x: x2, y: y2 }],
                source: fileUrl,
                imageObj: tempImg,
                originalAspectRatio: origW / origH,
                opacity: 1.0
            };

            window.strokes = [...window.strokes, newStroke];
            window.currentTool = "select";
            window.selectStrokeForEditing(newStroke, true);
            window.requestPaintAll();
        }

        if (tempImg.status === Image.Ready) {
            processAndInsert();
        } else {
            tempImg.statusChanged.connect(function() {
                if (tempImg.status === Image.Ready) {
                    processAndInsert();
                }
            });
        }
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
        const cx = Helpers.clamp(x, 0, Math.max(0, bw - minSize));
        const cy = Helpers.clamp(y, 0, Math.max(0, bh - minSize));
        const cw = Helpers.clamp(w, minSize, bw - cx);
        const ch = Helpers.clamp(h, minSize, bh - cy);
        return Qt.rect(cx, cy, cw, ch);
    }

    function backgroundConfigValue(key, defaultValue, numeric) {
        const pd = config && config.pluginData;
        if (!pd || pd[key] === undefined || pd[key] === null) return defaultValue;
        return numeric ? parseInt(pd[key], 10) : pd[key];
    }

    function backgroundConfigColor(key, defaultValue) {
        const pd = config && config.pluginData;
        if (!pd) return defaultValue;
        const val = pd[key];
        if (!val) return defaultValue;
        return config.resolveColor(val);
    }

    function backgroundUsesAdaptiveColor(key) {
        const pd = config && config.pluginData;
        return !!(pd && (pd[key + "Mode"] === "adaptive" || pd[key] === "adaptive"));
    }

    function applyAdaptiveBackgroundColors() {
        if (window.preservingRestoredBackground) return;
        if (backgroundUsesAdaptiveColor("backgroundDefaultSolidColor")) {
            window.backgroundSolidColor = window.autoBackgroundSolidColor;
        }
        if (backgroundUsesAdaptiveColor("backgroundDefaultGradientStart")) {
            window.backgroundGradientStart = window.autoBackgroundGradientStart;
        }
        if (backgroundUsesAdaptiveColor("backgroundDefaultGradientEnd")) {
            window.backgroundGradientEnd = window.autoBackgroundGradientEnd;
        }
        window.requestActiveCanvasPaint();
    }

    function measureTextBounds(stroke) {
        if (!window.activeCanvas) return null;
        const ctx = window.activeCanvas.getContext("2d");
        return DrawingRenderer.measureTextLayout(ctx, stroke, Theme);
    }

    function findStrokeAt(mx, my) {
        return Helpers.findStrokeAt(mx, my, window.strokes, window.measureTextBounds);
    }

    function getSelectedStrokeHandleAt(mx, my) {
        if (!window.selectedStroke) return "none";
        return Helpers.getStrokeHandleAt(mx, my, window.selectedStroke, window.measureTextBounds);
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
        const exportWidth = window.hasSelection && window.effectiveBackgroundMode === "none"
            ? window.cropRect.width
            : window.canvasWidth;
        const exportHeight = window.hasSelection && window.effectiveBackgroundMode === "none"
            ? window.cropRect.height
            : window.canvasHeight;
        window.exportCanvasItem.outputPixelWidth = Math.max(1, Math.round(exportWidth));
        window.exportCanvasItem.outputPixelHeight = Math.max(1, Math.round(exportHeight));
        window.exportCanvasItem.width = window.exportCanvasItem.outputPixelWidth / window.exportCanvasItem.exportDpr;
        window.exportCanvasItem.height = window.exportCanvasItem.outputPixelHeight / window.exportCanvasItem.exportDpr;
        window.exportCanvasItem.requestPaint();
    }

    function formatHexColor(color) { return Helpers.formatHexColor(color); }

    function reindexStamps() {
        let stamps = [];
        let maxId = 0;
        for (let i = 0; i < window.strokes.length; i++) {
            let stroke = window.strokes[i];
            if (stroke && stroke.tool === "stamp") {
                stamps.push(stroke);
                const id = Number(stroke.id);
                if (isFinite(id)) maxId = Math.max(maxId, id);
            }
        }

        let modified = false;
        let nextId = Math.max(maxId + 1, window.stampIdCounter);
        let usedIds = {};
        for (let i = 0; i < stamps.length; i++) {
            let stroke = stamps[i];
            const id = Number(stroke.id);
            if (!isFinite(id) || usedIds[id]) {
                stroke.id = nextId++;
                modified = true;
            }
            usedIds[Number(stroke.id)] = true;
        }

        stamps.sort((a, b) => Number(a.id) - Number(b.id));

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
        if (window.stampIdCounter !== nextId) {
            window.stampIdCounter = nextId;
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
            const picker = PopoutService.colorPickerModal;
            picker.useOverlayLayer = true;
            picker.selectedColor = window.currentColor;
            picker.pickerTitle = I18n.trFor("quickCapture", "Choose Color");
            picker.onColorSelectedCallback = function (selectedColor) {
                window.updateColorSlot(window.activeColorSlotIndex, selectedColor);
            };
            window.shouldHaveFocus = false;
            picker.show();
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
        
        window.savePluginData("color_palette_preset", "custom");
        window.savePluginData(key, hex);
    }

    function switchPresetToCustom(copyCurrent) {
        if (!window.parentWidget || !window.parentWidget.pluginService) return;
        
        // 1. Read current palette FIRST before switching preset to custom
        // to avoid QML reactive bindings immediately resetting the palette to custom empty/defaults.
        const currentPalette = (copyCurrent && window.toolbarItem && window.toolbarItem.toolbarPalette) ? window.toolbarItem.toolbarPalette : [];
        
        let pData = Object.assign({}, window.parentWidget.pluginData);
        pData["color_palette_preset"] = "custom";
        window.savePluginData("color_palette_preset", "custom");
        
        if (copyCurrent && currentPalette && currentPalette.length >= 8) {
            pData["toolbar_color_primary"] = window.formatHexColor(currentPalette[0]).toUpperCase();
            window.savePluginData("toolbar_color_primary", pData["toolbar_color_primary"]);
            
            for (let i = 0; i < 7; i++) {
                const key = `toolbar_color_${i}`;
                pData[key] = window.formatHexColor(currentPalette[i + 1]).toUpperCase();
                window.savePluginData(key, pData[key]);
            }
        }
        
        if (window.pendingSlotToSave >= 0) {
            const hex = window.formatHexColor(window.pendingColorToSave).toUpperCase();
            const key = window.pendingSlotToSave === 0 ? "toolbar_color_primary" : "toolbar_color_" + (window.pendingSlotToSave - 1);
            pData[key] = hex;
            window.savePluginData(key, hex);
            
            window.parentWidget.pluginData = pData;
            window.currentColor = window.pendingColorToSave;
        }
        
        window.pendingColorToSave = "transparent";
        window.pendingSlotToSave = -1;
    }

    function readCanvasPixel(canvas, x, y) {
        if (!canvas) return null;
        try {
            const ctx = canvas.getContext("2d");
            if (!ctx) return null;
            const imgData = ctx.getImageData(x, y, 1, 1);
            if (!imgData || !imgData.data || imgData.data.length < 4 || imgData.data[3] === 0) return null;

            // Force alpha to 1.0 so the picker always returns an opaque color.
            return Qt.rgba(imgData.data[0] / 255, imgData.data[1] / 255, imgData.data[2] / 255, 1.0);
        } catch (e) {
            return null;
        }
    }

    function sampleCanvasColor(mouseX, mouseY) {
        const canvases = [window.activeCanvas, window.bakedCanvas, window.backgroundCanvas];
        const firstCanvas = canvases.find(canvas => canvas !== null && canvas !== undefined);
        if (!firstCanvas) return window.currentColor;

        // Clamp and round coordinates to prevent out-of-bounds errors and ensure integer coordinates in device pixels.
        const x = Helpers.clamp(Math.floor(mouseX * window.dpr), 0, Math.floor(firstCanvas.width * window.dpr) - 1);
        const y = Helpers.clamp(Math.floor(mouseY * window.dpr), 0, Math.floor(firstCanvas.height * window.dpr) - 1);

        // Performance optimization: skip sampling if the pixel coordinates haven't changed.
        if (window._lastSampledX === x && window._lastSampledY === y) {
            return window._lastSampledColor || window.currentColor;
        }

        let pickedColor = null;
        for (let i = 0; i < canvases.length; i++) {
            pickedColor = window.readCanvasPixel(canvases[i], x, y);
            if (pickedColor) break;
        }

        window._lastSampledX = x;
        window._lastSampledY = y;
        window._lastSampledColor = pickedColor || window.currentColor;
        return window._lastSampledColor;
    }

    function cancelTypingText() {
        window.editingStroke = null;
        window.isTyping = false;
        window.currentTypingText = "";
        window.typingCursorIndex = 0;
        window.requestAnnotationPaintAll();
        Qt.callLater(() => window.focusModalAfterToolbarAction());
    }

    function acceptKeyEvent(event) {
        event.accepted = true;
        return true;
    }

    function closeColorPickerIfOpen() {
        if (typeof PopoutService === "undefined" || !PopoutService || !PopoutService.colorPickerModal) {
            return false;
        }
        const picker = PopoutService.colorPickerModal;
        if (!picker.shouldBeVisible) return false;
        picker.hide();
        return true;
    }

    function repaintActiveCanvas() {
        if (window.activeCanvas) window.activeCanvas.requestPaint();
    }

    function handleSelectedStrokeDeleteShortcut(event) {
        if ((event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) && window.currentTool === "select" && window.selectedStroke) {
            const list = [...window.strokes];
            const idx = list.indexOf(window.selectedStroke);
            if (idx !== -1) {
                list.splice(idx, 1);
                window.undoneStrokes = [...window.undoneStrokes, window.selectedStroke];
                window.strokes = list;
            }
            window.deselectStrokeForEditing(false);
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleSelectedStrokeMoveShortcut(event) {
        if ((event.key === Qt.Key_Left || event.key === Qt.Key_Right || event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            && window.currentTool === "select" && window.selectedStroke) {

            let step = (event.modifiers & Qt.ShiftModifier) ? 10 : 1;
            let dx = 0;
            let dy = 0;
            if (event.key === Qt.Key_Left) dx = -step;
            else if (event.key === Qt.Key_Right) dx = step;
            else if (event.key === Qt.Key_Up) dy = -step;
            else if (event.key === Qt.Key_Down) dy = step;

            const newPoints = [];
            for (let i = 0; i < window.selectedStroke.points.length; i++) {
                newPoints.push(Qt.point(window.selectedStroke.points[i].x + dx, window.selectedStroke.points[i].y + dy));
            }
            window.selectedStroke.points = newPoints;

            if (window.selectedStroke.tool === "redact") {
                window.selectedStroke.cachedCleanColor = undefined;
            }

            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleEscapeShortcut(event) {
        if (event.key === Qt.Key_Escape) {
            if (window.isPanSpacePressed) {
                window.isPanSpacePressed = false;
                window.lastPanMouse = Qt.point(0, 0);
                return window.acceptKeyEvent(event);
            }
            if (window.cancelPastePreview()) {
                return window.acceptKeyEvent(event);
            }
            if (window.currentStroke) {
                window.currentStroke = null;
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "select" && window.originalPoints && window.originalPoints.length > 0) {
                if (window.selectedStroke) {
                    window.selectedStroke.points = window.originalPoints.map(p => Qt.point(p.x, p.y));
                    if (window.originalRotation !== undefined) window.selectedStroke.rotation = window.originalRotation;
                }
                window.activeHandle = "none";
                window.originalPoints = [];
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.selectedStroke) {
                window.deselectStrokeForEditing(false);
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "ocr" || window.currentTool === "qr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                window.repaintActiveCanvas();
                return window.acceptKeyEvent(event);
            }
            if (window.currentTool === "crop") {
                window.hasSelection = false;
                window.cropRect = Qt.rect(0, 0, 0, 0);
                window.activeHandle = "none";
                window.currentTool = window.lastActiveTool;
                window.requestPaintAll();
                return window.acceptKeyEvent(event);
            }
            window.discardAndClose();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function saveAsFileExtensions() {
        const format = (config.pluginData.outputFormat || "png").toLowerCase();
        return ["*." + format];
    }

    function openSaveAsDialog() {
        if (saveAsDialog.shouldBeVisible) return;
        saveAsDialog.useOverlayLayer = true;
        saveAsDialog.defaultFileName = captureActions.screenshotFilename();
        saveAsDialog.fileExtensions = window.saveAsFileExtensions();
        window.shouldHaveFocus = false;
        saveAsDialog.open();
    }

    function handleCaptureActionShortcut(event, token, hasCtrl) {
        if (hasCtrl && (token === "Y" || (event.modifiers & Qt.ShiftModifier && token === "Z"))) {
            window.performRedo();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "Z") {
            window.performUndo();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && (event.modifiers & Qt.ShiftModifier) && token === "C") {
            captureActions.performAnonymousCopy();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "C") {
            captureActions.performCopyOnly();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            captureActions.performDoneAction();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && (event.modifiers & Qt.ShiftModifier) && token === "S") {
            window.openSaveAsDialog();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && !(event.modifiers & Qt.ShiftModifier) && token === "S") {
            captureActions.performSaveOnly();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "A") {
            captureActions.performCopyAndSave();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "F") {
            captureActions.performFloatAction();
            return window.acceptKeyEvent(event);
        }
        if (hasCtrl && token === "X") {
            window.currentTool = window.currentTool === "crop" ? window.lastActiveTool : "crop";
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleAnnotationVisibilityShortcut(event, token, hasCtrl) {
        if (token === "X" && !hasCtrl) {
            window.showAnnotations = !window.showAnnotations;
            window.repaintActiveCanvas();
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleStrokeClipboardShortcut(event, token, hasCtrl) {
        if (token === "C" && !hasCtrl) {
            if (window.pastePreviewActive) {
                // Place the current preview and immediately prepare the next duplicate.
                window.performPasteAction();
                window.beginPastePreview();
                return window.acceptKeyEvent(event);
            }
            if (window.currentStroke && window.currentStroke.tool !== "text" && window.currentStroke.tool !== "callout") {
                window.commitStrokeBeforeToolChange();
            }
            if (window.currentTool !== "select" && window.strokes.length > 0) {
                window.currentTool = "select";
            }
            if (window.selectedStroke) {
                window.copiedStroke = {
                    tool: window.selectedStroke.tool,
                    color: window.selectedStroke.color.toString(),
                    width: window.selectedStroke.width,
                    points: window.selectedStroke.points.map(p => Qt.point(p.x, p.y))
                };
                Helpers.copyStrokeProperties(window.selectedStroke, window.copiedStroke);
                window.prepareStampCopyForPaste(window.copiedStroke);
                window.beginPastePreview();
                return window.acceptKeyEvent(event);
            } else if (window.copiedStroke) {
                window.beginPastePreview();
                return window.acceptKeyEvent(event);
            }
        }

        if (token === "V" && !hasCtrl) {
            window.currentTool = "select";
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleColorShortcut(event, token) {
        const colorShortcut = Helpers.findByKey(config.colorShortcuts, token);
        if (!colorShortcut) return false;
        let idx = config.colorShortcuts.indexOf(colorShortcut);
        if (idx !== -1) {
            window.activeColorSlotIndex = idx;
        }
        window.currentColor = colorShortcut.color === "primary" ? Theme.primary : colorShortcut.color;
        return window.acceptKeyEvent(event);
    }

    function handleOcrShortcut(event, token, hasCtrl) {
        if (token === "O" && !hasCtrl) {
            if (window.currentTool === "ocr") {
                window.currentTool = window.lastActiveTool;
                window.ocrRect = Qt.rect(0, 0, 0, 0);
                window.repaintActiveCanvas();
            } else {
                window.runOcr();
            }
            return window.acceptKeyEvent(event);
        }

        return false;
    }

    function handleInsertImageShortcut(event, token, hasCtrl) {
        if (token === "I" && !hasCtrl) {
            window.openInsertImageDialog();
            return window.acceptKeyEvent(event);
        }
        return false;
    }

    function handleWatermarkShortcut(event, token, hasCtrl) {
        if (token === "M" && !hasCtrl) {
            window.setWatermarkEnabled(!window.watermarkEnabled);
            return window.acceptKeyEvent(event);
        }
        return false;
    }

    function handleToolShortcut(event, token) {
        const toolShortcut = Helpers.findByKey(config.toolShortcuts, token);
        if (!toolShortcut) return false;

        if (toolShortcut.tool === "colorpicker") {
            if (!window.openColorPickerModal()) {
                if (window.currentTool === "colorpicker") {
                    window.currentTool = window.lastActiveTool;
                } else {
                    window.colorPickerMode = "draw";
                    window.currentTool = "colorpicker";
                }
            }
            return window.acceptKeyEvent(event);
        }

        if (window.currentTool === toolShortcut.tool) {
            if (toolShortcut.tool === "background" || toolShortcut.tool === "crop") {
                window.currentTool = window.lastActiveTool;
            }
        } else {
            window.currentTool = toolShortcut.tool;
        }
        return window.acceptKeyEvent(event);
    }

    function handleViewZoomShortcut(event, token, hasCtrl) {
        if (window.isTyping) return false;
        if (token === "0") {
            window.resetUserZoom();
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal) {
            window.adjustUserZoom(0.15);
            return window.acceptKeyEvent(event);
        }
        if (event.key === Qt.Key_Minus) {
            window.adjustUserZoom(-0.15);
            return window.acceptKeyEvent(event);
        }
        return false;
    }

    function handleStrokeSizeShortcut(event, token, hasCtrl) {
        if (hasCtrl || window.isTyping) return false;
        const isDecrease = event.key === Qt.Key_BracketLeft;
        const isIncrease = event.key === Qt.Key_BracketRight;
        if (!isDecrease && !isIncrease) return false;

        const tool = window.effectiveTool;
        const meta = Constants.getToolMeta(tool);
        const multiplier = meta.step !== undefined ? meta.step : 1;
        const step = isIncrease ? multiplier : -multiplier;

        window.updateActiveIntensity(window.activeIntensity + step);
        window.previewX = window.cursorX * window.editScale;
        window.previewY = window.cursorY * window.editScale;
        window.showSizePreview = true;
        return window.acceptKeyEvent(event);
    }

    function handleShortcutKey(event) {
        if (window.handleSelectedStrokeDeleteShortcut(event)) return;
        if (window.handleSelectedStrokeMoveShortcut(event)) return;

        const token = Helpers.shortcutToken(event.key, Qt);
        const hasCtrl = event.modifiers & Qt.ControlModifier;

        if (window.handleEscapeShortcut(event)) return;
        if (window.handleCaptureActionShortcut(event, token, hasCtrl)) return;
        if (window.handleAnnotationVisibilityShortcut(event, token, hasCtrl)) return;
        if (window.handleStrokeClipboardShortcut(event, token, hasCtrl)) return;
        if (window.handleViewZoomShortcut(event, token, hasCtrl)) return;
        if (window.handleStrokeSizeShortcut(event, token, hasCtrl)) return;

        if (hasCtrl) {
            window.handleColorShortcut(event, token);
            return;
        }

        if (window.handleInsertImageShortcut(event, token, hasCtrl)) return;
        if (window.handleWatermarkShortcut(event, token, hasCtrl)) return;
        if (window.handleOcrShortcut(event, token, hasCtrl)) return;
        window.handleToolShortcut(event, token);
    }

    function handleTabShortcut(event) {
        if (event.key !== Qt.Key_Tab) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
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

            const isP0 = current.tool === p0.tool &&
                         current.color.toString() === p0.color.toString() &&
                         current.thickness === p0.thickness;

            const target = isP0 ? p1 : p0;
            window.currentTool = target.tool;
            window.currentColor = target.color;
            window.applyToolIntensity(target.tool, target.thickness);
            window.updateSessionToolIntensity(target.tool, target.thickness);
            window.recordPresetUsage(target);
        } else {
            window.currentTool = "select";
        }

        return window.acceptKeyEvent(event);
    }

    function handleZoomKeyPressed(event) {
        if (event.key === Qt.Key_Space && !window.isTyping) {
            if (!event.isAutoRepeat) {
                window.isPanSpacePressed = !window.isPanSpacePressed;
                window.lastPanMouse = Qt.point(0, 0);
            }
            return window.acceptKeyEvent(event);
        }
        if (event.key !== Qt.Key_G || window.isTyping) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
        }
        window.isZoomPressed = true;
        return window.acceptKeyEvent(event);
    }

    function handleZoomKeyReleased(event) {
        if (event.key === Qt.Key_Space) {
            return window.acceptKeyEvent(event);
        }
        if (event.key !== Qt.Key_G || window.isTyping) return false;
        if (event.isAutoRepeat) {
            return window.acceptKeyEvent(event);
        }
        window.isZoomPressed = false;
        return window.acceptKeyEvent(event);
    }

    function handleTypingKeyPressed(event) {
        if (!window.isTyping) return false;
        if (window.textInputMode === "inline" && window.isTyping) {
            if (event.key === Qt.Key_Escape) {
                window.cancelTypingText();
                return window.acceptKeyEvent(event);
            }
            const isEnter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
            if (isEnter) {
                if (event.modifiers & Qt.ControlModifier) {
                    Qt.inputMethod.commit();
                    Qt.callLater(() => window.commitTypingText());
                    return window.acceptKeyEvent(event);
                }
                if (window.inlineTextEditorItem)
                    window.inlineTextEditorItem.handleEnterKey(event);
                else
                    event.accepted = true;
                return true;
            }
            if (event.modifiers & Qt.ControlModifier) {
                const token = Helpers.shortcutToken(event.key, Qt);
                if (window.handleColorShortcut(event, token)) return true;
                if ((event.modifiers & Qt.ShiftModifier) && token === "S") {
                    window.openSaveAsDialog();
                    return window.acceptKeyEvent(event);
                }
            }
            event.accepted = true;
            return true;
        }

        if (event.modifiers & Qt.ControlModifier) {
            const token = Helpers.shortcutToken(event.key, Qt);
            if (window.handleColorShortcut(event, token)) return true;
            if ((event.modifiers & Qt.ShiftModifier) && token === "S") {
                window.openSaveAsDialog();
                return window.acceptKeyEvent(event);
            }
        }
        if (window.textInputMode === "popup" && event.key !== Qt.Key_Escape) {
            event.accepted = true;
        }
        return true;
    }

    function handleModalKeyPressed(event) {
        if (event.key === Qt.Key_Control) {
            window.isCtrlPressed = true;
        }
        if (event.key === Qt.Key_Escape && saveAsDialog.shouldBeVisible) {
            saveAsDialog.close();
            window.acceptKeyEvent(event);
            return;
        }
        if (event.key === Qt.Key_Escape && insertImageDialog.shouldBeVisible) {
            insertImageDialog.close();
            window.acceptKeyEvent(event);
            return;
        }
        if (event.key === Qt.Key_Escape && window.closeColorPickerIfOpen()) {
            window.acceptKeyEvent(event);
            return;
        }
        if (window.handleTabShortcut(event)) return;
        if (window.handleZoomKeyPressed(event)) return;
        if (window.handleTypingKeyPressed(event)) return;
        window.handleShortcutKey(event);
    }

    function handleModalKeyReleased(event) {
        if (event.key === Qt.Key_Control) {
            window.isCtrlPressed = false;
        }
        if (event.key === Qt.Key_Tab) {
            event.accepted = true;
            return;
        }
        window.handleZoomKeyReleased(event);
    }

    function resetEditorSessionState() {
        window.editorSessionGeneration++;
        if (typeof drawMouseArea !== "undefined" && drawMouseArea) drawMouseArea.resetInteractionState();

        window.strokes = [];
        window.undoneStrokes = [];
        window.currentStroke = null;
        window.selectedStroke = null;
        window.originalPoints = [];
        window.originalRotation = 0;
        window.activeHandle = "none";
        window.calloutDestDragging = false;
        window.copiedStroke = null;
        window.pastePreviewActive = false;
        window.presetHistory = [];

        window.isTyping = false;
        window.currentTypingText = "";
        window.typingCursorIndex = 0;
        window.editingStroke = null;
        window.typingIsSpeechBubble = false;
        window.typingHasTargetCoords = false;
        window.typingCoords = Qt.point(0, 0);
        window.typingTargetCoords = Qt.point(0, 0);

        window.showAnnotations = true;
        window.showSizePreview = false;
        window.userZoomScale = 1.0;
        window.userPanX = 0;
        window.userPanY = 0;
        window.isPanSpacePressed = false;
        window.lastPanMouse = Qt.point(0, 0);
        window.previewX = 0;
        window.previewY = 0;
        window.cropRect = Qt.rect(0, 0, 0, 0);
        window.hasSelection = false;
        window.selectStart = Qt.point(0, 0);
        window.ocrRect = Qt.rect(0, 0, 0, 0);
        window.isZoomPressed = false;
        window.cursorX = 0;
        window.cursorY = 0;
        window._lastSampledX = -1;
        window._lastSampledY = -1;
        window._lastSampledColor = "transparent";
        window.hoveredColor = "transparent";
        window.colorPickerMode = "draw";
        window.backgroundColorPickingSlot = "none";
        window.pressCoords = Qt.point(0, 0);

        const previousBlurPath = window.backgroundBlurredImagePath;
        window.cancelBackgroundBlurPreparation();
        window.backgroundBlurredImagePath = "";
        window.backgroundBlurredSourcePath = "";
        window.backgroundBlurPendingSourcePath = "";
        window.backgroundBlurLoading = false;
        window.backgroundBlurShowIndicator = false;
        window.cleanupBackgroundBlurCache(previousBlurPath);
    }

    onBackgroundClicked: () => discardAndClose()

    // Keyboard Shortcuts Support
    modalFocusScope.Keys.onPressed: (event) => {
        window.handleModalKeyPressed(event);
    }

    modalFocusScope.Keys.onReleased: (event) => {
        window.handleModalKeyReleased(event);
    }

    onOpened: {
        if (window.presentationSwitching) {
            window.presentationSwitching = false;
            window.focusModalAfterToolbarAction();
            return;
        }
        if (window.floatService) {
            window.floatService.hideAllWindows();
        }
        window.preservingRestoredBackground = false;
        window.updateRadialPresets();
        window.watermarkEnabled = config.pluginData.defaultWatermark === true;

        let startTool = "pen";
        let startThickness = Constants.getToolMeta("pen").defaultValue;
        let startColor = Theme.primary;

        window.resetSessionToolIntensities();
        window.resetSessionToolColors();

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
                startThickness = window.sessionToolIntensity(startTool);
                startColor = window.sessionToolColor(startTool);
            }
        } else {
            startTool = config.pluginData.defaultTool || "pen";
            startThickness = window.sessionToolIntensity(startTool);
            startColor = window.sessionToolColor(startTool);
        }

        window.resetEditorSessionState();

        window.currentTool = startTool;
        window.toolbarVisible = window.configShowToolbar;
        window.applyToolIntensity(startTool, startThickness);
        window.updateSessionToolIntensity(startTool, startThickness);
        window.currentColor = startColor;
        window.updateSessionToolColor(startTool, startColor);
        window.recordPresetUsage({ tool: startTool, color: startColor, thickness: startThickness });

        window.stampCounter = 1;
        window.stampIdCounter = 1;
        window.bgRotation = 0;
        window.bgFlipH = false;
        window.bgFlipV = false;
        window.bgImageSource = "";
        if (window.restoreSource) {
            window.bgImageSource = window.restoreSource;
        } else if (window.currentCapturePath) {
            window.bgImageSource = `file://${window.currentCapturePath}`;
            // currentCapturePath is consumed in onDialogClosed to survive re-fires during screen changes
        }
        window.isScreenshotDark = false;
        window.hasSampledContrast = false;
        window.backgroundSolidColor = backgroundUsesAdaptiveColor("backgroundDefaultSolidColor")
            ? window.autoBackgroundSolidColor
            : backgroundConfigColor("backgroundDefaultSolidColor", config.resolveColor("slot_1"));
        window.backgroundGradientStart = backgroundUsesAdaptiveColor("backgroundDefaultGradientStart")
            ? window.autoBackgroundGradientStart
            : backgroundConfigColor("backgroundDefaultGradientStart", config.resolveColor("slot_1"));
        window.backgroundGradientEnd = backgroundUsesAdaptiveColor("backgroundDefaultGradientEnd")
            ? window.autoBackgroundGradientEnd
            : backgroundConfigColor("backgroundDefaultGradientEnd", config.resolveColor("slot_2"));
        window.backgroundImagePath = backgroundConfigValue("backgroundDefaultImagePath", "", false);
        window.backgroundImageFolder = backgroundConfigValue("backgroundImageFolder", "~/Pictures/Wallpaper", false);
        window.backgroundImageBlur = backgroundConfigValue("backgroundImageBlur", false, false) === true;
        window.backgroundImageDim = backgroundConfigValue("backgroundImageDim", false, false) === true;
        window.backgroundImageDimStrength = backgroundConfigValue("backgroundImageDimStrength", 28, true);

        const pd = config && config.pluginData;
        const hasCustomSolid = pd && pd["backgroundDefaultSolidColor"] !== undefined;
        const hasCustomGradStart = pd && pd["backgroundDefaultGradientStart"] !== undefined;
        const hasCustomGradEnd = pd && pd["backgroundDefaultGradientEnd"] !== undefined;
        window.hasUserCustomizedBackground = !!(hasCustomSolid || hasCustomGradStart || hasCustomGradEnd);
        window.backgroundMode = "none";
        if (config && config.pluginData && config.pluginData["backgroundAutoApply"] === true) {
            const bm = config.pluginData["backgroundDefaultMode"];
            if (bm) window.backgroundMode = bm;
        }
        window.backgroundPadding = backgroundConfigValue("backgroundDefaultPadding", Constants.defaultBackgroundPadding, true);
        window.backgroundCornerRadius = backgroundConfigValue("backgroundDefaultRadius", Constants.defaultBackgroundCornerRadius, true);
        window.backgroundShadowStrength = backgroundConfigValue("backgroundDefaultShadow", Constants.defaultBackgroundShadowStrength, true);
        window.backgroundGradientAngle = backgroundConfigValue("backgroundDefaultAngle", Constants.defaultBackgroundGradientAngle, true);
        window.backgroundAspectRatio = backgroundConfigValue("backgroundDefaultAspectRatio", Constants.defaultBackgroundAspectRatio, false);
        window.backgroundAlignment = backgroundConfigValue("backgroundDefaultAlignment", Constants.defaultBackgroundAlignment, false);
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
                    if (rs.tool === "image" && rs.source) {
                        const restoredImg = Qt.createQmlObject('import QtQuick; Image { visible: false; source: "' + rs.source + '" }', window, "restoredImgLoader_" + rsi + "_" + Date.now());
                        if (restoredImg) {
                            stroke.imageObj = restoredImg;
                            if (restoredImg.status !== Image.Ready) {
                                restoredImg.statusChanged.connect(function() {
                                    if (restoredImg.status === Image.Ready) {
                                        window.requestPaintAll();
                                    }
                                });
                            }
                        }
                    }
                    restoredStrokes.push(stroke);
                }
                window.strokes = restoredStrokes;
            }
            if (data.originalImageSource) {
                window.bgImageSource = data.originalImageSource;
            }
            if (data.watermarkEnabled !== undefined) {
                window.watermarkEnabled = data.watermarkEnabled === true;
            }
            if (data.stampCounter !== undefined) {
                window.stampCounter = data.stampCounter;
            }
            if (data.bgRotation !== undefined) {
                window.bgRotation = data.bgRotation;
            }
            if (data.bgFlipH !== undefined) {
                window.bgFlipH = data.bgFlipH;
            }
            if (data.bgFlipV !== undefined) {
                window.bgFlipV = data.bgFlipV;
            }
            if (data.cropRect) {
                window.cropRect = Qt.rect(data.cropRect.x, data.cropRect.y, data.cropRect.width, data.cropRect.height);
                window.hasSelection = (data.cropRect.width > 0 && data.cropRect.height > 0);
            }
            if (data.backgroundMode !== undefined) {
                window.preservingRestoredBackground = true;
                window.backgroundMode = data.backgroundMode;
                window.backgroundImagePath = data.backgroundImagePath || "";
                window.backgroundImageBlur = data.backgroundImageBlur === true;
                window.backgroundImageDim = data.backgroundImageDim === true;
                window.backgroundImageDimStrength = data.backgroundImageDimStrength !== undefined ? data.backgroundImageDimStrength : 28;
                window.backgroundSolidColor = data.backgroundSolidColor;
                window.backgroundGradientStart = data.backgroundGradientStart;
                window.backgroundGradientEnd = data.backgroundGradientEnd;
                window.backgroundGradientAngle = data.backgroundGradientAngle;
                window.backgroundPadding = data.backgroundPadding;
                window.backgroundCornerRadius = data.backgroundCornerRadius;
                window.backgroundShadowStrength = data.backgroundShadowStrength;
                window.backgroundAspectRatio = data.backgroundAspectRatio;
                window.customAspectRatio = data.customAspectRatio;
                if (data.backgroundAlignment) window.backgroundAlignment = data.backgroundAlignment;
                window.hasUserCustomizedBackground = data.hasUserCustomizedBackground;
                window.autoBackgroundGradientStart = data.autoBackgroundGradientStart;
                window.autoBackgroundGradientEnd = data.autoBackgroundGradientEnd;
                window.autoBackgroundSolidColor = data.autoBackgroundSolidColor;
            }
            if (data.user_background_presets) {
                const parsed = window.parseJsonArrayValue(data.user_background_presets, "user_background_presets");
                if (parsed !== undefined) window.customBackgroundPresets = parsed;
            }
            if (data.hidden_background_presets) {
                const parsed = window.parseJsonArrayValue(data.hidden_background_presets, "hidden_background_presets");
                if (parsed !== undefined) window.hiddenPresetIds = parsed;
            }
            window.repaintActiveCanvas();
            window.restoreState = null;
            window.restoreSource = "";
        }

        Qt.callLater(() => {
            if (window.backgroundMode === "image") {
                window.refreshBackgroundBlurCache(false);
            }
            if (modalFocusScope) modalFocusScope.forceActiveFocus();
        });
    }

    function applyBackgroundPreset(preset) {
        if (!preset) return;
        if (preset.imagePath !== undefined) window.backgroundImagePath = preset.imagePath;
        if (preset.imageBlur !== undefined) window.backgroundImageBlur = preset.imageBlur;
        if (preset.imageDim !== undefined) window.backgroundImageDim = preset.imageDim;
        if (preset.imageDimStrength !== undefined) window.backgroundImageDimStrength = preset.imageDimStrength;
        if (preset.mode !== undefined) window.backgroundMode = preset.mode;
        if (preset.solidColor !== undefined) window.backgroundSolidColor = preset.solidColor;
        if (preset.gradientStart !== undefined) window.backgroundGradientStart = preset.gradientStart;
        if (preset.gradientEnd !== undefined) window.backgroundGradientEnd = preset.gradientEnd;
        if (preset.gradientAngle !== undefined) window.backgroundGradientAngle = preset.gradientAngle;
        if (preset.padding !== undefined) window.backgroundPadding = preset.padding;
        if (preset.cornerRadius !== undefined) window.backgroundCornerRadius = preset.cornerRadius;
        if (preset.shadowStrength !== undefined) window.backgroundShadowStrength = preset.shadowStrength;
        if (preset.aspectRatio !== undefined) window.backgroundAspectRatio = preset.aspectRatio;
        if (preset.customAspectRatio !== undefined) window.customAspectRatio = preset.customAspectRatio;
        window.hasUserCustomizedBackground = true;
        window.refreshBackgroundBlurCache(true);
        window.requestPaintAll();
    }

    function saveCurrentBackgroundAsPreset() {
        const idx = window.customBackgroundPresets.length + 1;
        const newPreset = {
            id: `custom_${Date.now()}`,
            name: `Custom ${idx}`,
            mode: window.backgroundMode,
            imagePath: window.backgroundImagePath,
            imageBlur: window.backgroundImageBlur,
            imageDim: window.backgroundImageDim,
            imageDimStrength: window.backgroundImageDimStrength,
            solidColor: window.backgroundSolidColor.toString(),
            gradientStart: window.backgroundGradientStart.toString(),
            gradientEnd: window.backgroundGradientEnd.toString(),
            gradientAngle: window.backgroundGradientAngle,
            padding: window.backgroundPadding,
            cornerRadius: window.backgroundCornerRadius,
            shadowStrength: window.backgroundShadowStrength,
            aspectRatio: window.backgroundAspectRatio,
            customAspectRatio: window.customAspectRatio,
            isCustomUserCreated: true
        };
        const newList = [...window.customBackgroundPresets, newPreset];
        window.customBackgroundPresets = newList;
        window.savePluginData("user_background_presets", JSON.stringify(newList));
    }

    function deletePreset(presetId) {
        if (!presetId) return;
        const newCustom = window.customBackgroundPresets.filter(p => p.id !== presetId);
        const newHidden = window.hiddenPresetIds.indexOf(presetId) === -1 ? [...window.hiddenPresetIds, presetId] : window.hiddenPresetIds;
        window.customBackgroundPresets = newCustom;
        window.hiddenPresetIds = newHidden;
        window.savePluginData("user_background_presets", JSON.stringify(newCustom));
        window.savePluginData("hidden_background_presets", JSON.stringify(newHidden));
    }

    function updatePresetWithCurrent(presetId) {
        if (!presetId) return;
        const currentData = {
            mode: window.backgroundMode,
            imagePath: window.backgroundImagePath,
            imageBlur: window.backgroundImageBlur,
            imageDim: window.backgroundImageDim,
            imageDimStrength: window.backgroundImageDimStrength,
            solidColor: window.backgroundSolidColor.toString(),
            gradientStart: window.backgroundGradientStart.toString(),
            gradientEnd: window.backgroundGradientEnd.toString(),
            gradientAngle: window.backgroundGradientAngle,
            padding: window.backgroundPadding,
            cornerRadius: window.backgroundCornerRadius,
            shadowStrength: window.backgroundShadowStrength,
            aspectRatio: window.backgroundAspectRatio,
            customAspectRatio: window.customAspectRatio
        };

        const existingIdx = window.customBackgroundPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackgroundPresets.map(p => p.id === presetId ? Object.assign({}, p, currentData) : p);
        } else {
            const original = Constants.defaultBackgroundPresets ? Constants.defaultBackgroundPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, currentData);
                newList = [...window.customBackgroundPresets, updated];
            } else {
                newList = window.customBackgroundPresets;
            }
        }
        window.customBackgroundPresets = newList;
        window.savePluginData("user_background_presets", JSON.stringify(newList));
    }

    function renamePreset(presetId, newName) {
        if (!presetId || !newName) return;
        const existingIdx = window.customBackgroundPresets.findIndex(p => p.id === presetId);
        let newList;
        if (existingIdx !== -1) {
            newList = window.customBackgroundPresets.map(p => p.id === presetId ? Object.assign({}, p, { name: newName }) : p);
        } else {
            const original = Constants.defaultBackgroundPresets ? Constants.defaultBackgroundPresets.find(p => p.id === presetId) : undefined;
            if (original) {
                const updated = Object.assign({}, original, { name: newName });
                newList = [...window.customBackgroundPresets, updated];
            } else {
                newList = window.customBackgroundPresets;
            }
        }
        window.customBackgroundPresets = newList;
        window.savePluginData("user_background_presets", JSON.stringify(newList));
    }

    function loadPresetsFromPluginData() {
        if (!config || !config.pluginData) return;
        
        const userPresetsRaw = config.pluginData["user_background_presets"];
        if (userPresetsRaw !== undefined) {
            if (userPresetsRaw) {
                const parsed = window.parseJsonArrayValue(userPresetsRaw, "user_background_presets");
                if (parsed !== undefined) {
                    window.customBackgroundPresets = parsed;
                }
            } else {
                window.customBackgroundPresets = [];
            }
        }

        const hiddenPresetsRaw = config.pluginData["hidden_background_presets"];
        if (hiddenPresetsRaw !== undefined) {
            if (hiddenPresetsRaw) {
                const parsed = window.parseJsonArrayValue(hiddenPresetsRaw, "hidden_background_presets");
                if (parsed !== undefined) {
                    window.hiddenPresetIds = parsed;
                }
            } else {
                window.hiddenPresetIds = [];
            }
        }
    }

    function focusModalAfterToolbarAction() {
        if (window.floatingMode && floatingEditorLoader.item) {
            floatingEditorLoader.item.forceActiveFocus();
        } else if (window.modalFocusScope) {
            window.modalFocusScope.forceActiveFocus();
        }
    }

    function togglePresentationMode() {
        window.sessionDisplayModeOverride = true;
        if (!window.shouldBeVisible) {
            window.floatingMode = !window.floatingMode;
            return;
        }

        const nextMode = !window.floatingMode;
        window.presentationSwitching = true;
        if (window.floatingMode) {
            floatingSurface.visible = false;
        } else {
            modalSurface.instantClose();
        }
        window.floatingMode = nextMode;
        Qt.callLater(() => {
            window.open();
        });
    }

    function closeMoreToolsMenu(menu) {
        if (menu) {
            menu.close();
        }
    }

    function handleToolbarToolSelected(tool, menu) {
        window.closeMoreToolsMenu(menu);
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
        window.focusModalAfterToolbarAction();
    }

    function handleToolbarColorSelected(color, index, menu) {
        window.closeMoreToolsMenu(menu);
        window.activeColorSlotIndex = index;
        window.currentColor = color;
        window.focusModalAfterToolbarAction();
    }

    function handleToolbarCustomColorPickerRequested(menu) {
        window.closeMoreToolsMenu(menu);
        if (!window.openColorPickerModal()) {
            if (window.currentTool === "colorpicker") {
                window.currentTool = window.lastActiveTool;
            } else {
                window.colorPickerMode = "draw";
                window.currentTool = "colorpicker";
            }
        }
    }

    function handleToolbarStrokeWidthSelected(width, menu) {
        window.closeMoreToolsMenu(menu);
        window.updateActiveIntensity(width);
    }

    function runToolbarAction(action, menu) {
        window.closeMoreToolsMenu(menu);
        action();
    }

    function toggleMoreToolsMenu(buttonItem, menu, toolbar, contentItem) {
        if (menu.opened) {
            menu.close();
            return;
        }

        const pt = buttonItem.mapToItem(contentItem, 0, 0);
        if (toolbar.isVertical) {
            if (window.toolbarPosition === "right") {
                menu.x = pt.x - menu.width - Theme.spacingS;
            } else {
                menu.x = pt.x + buttonItem.width + Theme.spacingS;
            }
            const targetY = pt.y + (buttonItem.height - menu.height) / 2;
            menu.y = Helpers.clamp(targetY, Theme.spacingS, contentItem.height - menu.height - Theme.spacingS);
        } else {
            const targetX = pt.x + (buttonItem.width - menu.width) / 2;
            menu.x = Helpers.clamp(targetX, Theme.spacingS, contentItem.width - menu.width - Theme.spacingS);
            if (window.toolbarPosition === "bottom") {
                menu.y = pt.y - menu.height - Theme.spacingS;
            } else {
                menu.y = pt.y + buttonItem.height + Theme.spacingS;
            }
        }
        menu.open();
    }

    function positionBackgroundPopover(popover, controlItem, toolbar, contentItem) {
        const pt = controlItem.mapToItem(contentItem, 0, 0);
        if (toolbar.isVertical) {
            if (window.toolbarPosition === "right") {
                popover.x = pt.x - popover.width - Theme.spacingXS;
            } else {
                popover.x = pt.x + controlItem.width + Theme.spacingXS;
            }
            popover.y = pt.y + (controlItem.height - popover.height) / 2;
            return;
        }

        popover.x = pt.x + (controlItem.width - popover.width) / 2;
        if (window.toolbarPosition === "bottom") {
            if (popover._anchorIsAbove !== undefined) {
                popover._anchorY = pt.y;
                popover._anchorIsAbove = true;
            } else {
                popover.y = pt.y - popover.height - Theme.spacingXS;
            }
        } else {
            if (popover._anchorIsAbove !== undefined) {
                popover._anchorY = pt.y + controlItem.height + Theme.spacingXS;
                popover._anchorIsAbove = false;
            } else {
                popover.y = pt.y + controlItem.height + Theme.spacingXS;
            }
        }
    }

    function handleBackgroundControlHovered(popover, controlItem, toolbar, contentItem) {
        if (!popover) return;

        window.positionBackgroundPopover(popover, controlItem, toolbar, contentItem);
        popover.open();
    }

    function handleBackgroundControlExited(popover) {
        if (popover) {
            popover.startCloseTimer();
        }
    }

    function closeBackgroundPopover(popover) {
        if (!popover) return;
        if (typeof popover.stopCloseTimer === "function") {
            popover.stopCloseTimer();
        }
        if (typeof popover.close === "function") {
            popover.close();
        }
    }

    function closeBackgroundPopovers() {
        const popovers = [
            backgroundPaddingPopover,
            backgroundRadiusPopover,
            backgroundShadowPopover,
            backgroundAnglePopover,
            backgroundImageDimPopover,
            backgroundAspectRatioPopover,
            backgroundAlignmentPopover,
            backgroundImagePopover,
            backgroundPresetsPopover
        ];
        for (let i = 0; i < popovers.length; i++) {
            window.closeBackgroundPopover(popovers[i]);
        }
    }

    function showBackgroundImagePopover(popover, controlItem, toolbar, contentItem) {
        if (!popover || !controlItem) return;
        if (popover.opened) {
            popover.close();
            return;
        }
        window.loadBackgroundImages();
        window.positionBackgroundPopover(popover, controlItem, toolbar, contentItem);
        popover.x = Helpers.clamp(popover.x, Theme.spacingS, contentItem.width - popover.width - Theme.spacingS);
        popover.y = Helpers.clamp(popover.y, Theme.spacingS, contentItem.height - popover.height - Theme.spacingS);
        popover.open();
    }

    function handleBackgroundControlWheel(type, delta) {
        const step = delta > 0 ? 5 : -5;
        if (type === "padding") {
            window.backgroundPadding = Helpers.clamp(window.backgroundPadding + step, 10, 150);
        } else if (type === "radius") {
            const rStep = delta > 0 ? 2 : -2;
            window.backgroundCornerRadius = Helpers.clamp(window.backgroundCornerRadius + rStep, 0, 60);
        } else if (type === "shadow") {
            window.backgroundShadowStrength = Helpers.clamp(window.backgroundShadowStrength + step, 0, 100);
        } else if (type === "angle") {
            const aStep = delta > 0 ? 15 : -15;
            window.backgroundGradientAngle = (window.backgroundGradientAngle + aStep + 360) % 360;
        } else if (type === "aspectRatio" && window.backgroundAspectRatio === "custom") {
            const ratioStep = delta > 0 ? 5 : -5;
            const scaled = Math.round(window.customAspectRatio * 100) + ratioStep;
            window.customAspectRatio = Helpers.clamp(scaled, 50, 250) / 100.0;
        } else if (type === "imageDim" && window.backgroundImageDim) {
            window.setBackgroundImageDimStrength(window.backgroundImageDimStrength + step, true);
        }
        window.requestActiveCanvasPaint();
    }

    property Component editorContent: Component {
        FocusScope {
            id: contentRoot
            focus: true
            implicitWidth: window.modalWidth
            implicitHeight: window.modalHeight

            Keys.onPressed: (event) => {
                if (window.floatingMode)
                    window.handleModalKeyPressed(event);
            }
            Keys.onReleased: (event) => {
                if (window.floatingMode)
                    window.handleModalKeyReleased(event);
            }

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
                        // Keep each canvas image cache warm; background rendering lives on backgroundCanvas.
                        if (window.bakedCanvas) {
                            window.bakedCanvas.unloadImage(source);
                            window.bakedCanvas.loadImage(source);
                        }
                        if (window.backgroundCanvas) {
                            window.backgroundCanvas.unloadImage(source);
                            window.backgroundCanvas.loadImage(source);
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
                    floatingWindowControls: window.floatingMode ? floatingWindowControls : null
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
                    anchors.topMargin: Theme.spacingM + (window.floatingMode && window.toolbarPosition === "top" ? window._floatingTooltipPadding : 0)
                    anchors.bottomMargin: Theme.spacingM + (window.floatingMode && window.toolbarPosition === "bottom" ? window._floatingTooltipPadding : 0)
                    anchors.leftMargin: Theme.spacingM + (window.floatingMode && window.toolbarPosition === "left" ? window._floatingTooltipPadding : 0)
                    anchors.rightMargin: Theme.spacingM + (window.floatingMode && window.toolbarPosition === "right" ? window._floatingTooltipPadding : 0)
                    isVertical: (window.toolbarPosition === "left" || window.toolbarPosition === "right")

                    showAnnotations: window.showAnnotations

                    currentTool: window.currentTool
                    activeToolType: window.effectiveTool
                    currentColor: window.currentColor
                    activeColorSlotIndex: window.activeColorSlotIndex

                    strokeWidth: window.activeIntensity
                    canUndo: window.canUndo
                    canRedo: window.canRedo

                    backgroundMode: window.backgroundMode
                    backgroundSolidColor: window.backgroundSolidColor
                    backgroundGradientStart: window.backgroundGradientStart
                    backgroundGradientEnd: window.backgroundGradientEnd
                    backgroundGradientAngle: window.backgroundGradientAngle
                    backgroundPadding: window.backgroundPadding
                    backgroundCornerRadius: window.backgroundCornerRadius
                    backgroundShadowStrength: window.backgroundShadowStrength
                    backgroundAspectRatio: window.backgroundAspectRatio
                    customAspectRatio: window.customAspectRatio
                    backgroundAlignment: window.backgroundAlignment
                    backgroundColorPickingSlot: window.backgroundColorPickingSlot
                    backgroundImageBlur: window.backgroundImageBlur
                    backgroundImageDim: window.backgroundImageDim
                    backgroundImageDimStrength: window.backgroundImageDimStrength

                    onChangeBackgroundMode: (mode, controlItem) => {
                        window.backgroundMode = mode;
                        if (mode === "image") {
                            window.refreshBackgroundBlurCache(false);
                            window.showBackgroundImagePopover(backgroundImagePopover, controlItem, toolbarCard, contentRoot);
                        } else {
                            window.cancelBackgroundBlurPreparation();
                            backgroundImagePopover.close();
                        }
                    }
                    onChangeBackgroundImageBlur: (enabled) => window.setBackgroundImageBlur(enabled, true)
                    onChangeBackgroundImageDim: (enabled) => window.setBackgroundImageDim(enabled, true)
                    onChangeBackgroundSolidColor: (col) => {
                        window.backgroundSolidColor = col;
                        window.hasUserCustomizedBackground = true;
                    }
                    onBackgroundColorPickerRequested: (currentColor) => {
                        moreToolsMenu.close();
                        if (typeof PopoutService !== "undefined" && PopoutService && PopoutService.colorPickerModal) {
                            const picker = PopoutService.colorPickerModal;
                            picker.useOverlayLayer = true;
                            picker.selectedColor = currentColor;
                            picker.pickerTitle = I18n.trFor("quickCapture", "Choose Color");
                            picker.onColorSelectedCallback = function (selectedColor) {
                                if (window.backgroundMode === "solid") {
                                    window.backgroundSolidColor = selectedColor;
                                } else {
                                    const activeSlot = (window.toolbarItem ? window.toolbarItem.gradientActiveSlot : "start");
                                    if (activeSlot === "start") {
                                        window.backgroundGradientStart = selectedColor;
                                    } else {
                                        window.backgroundGradientEnd = selectedColor;
                                    }
                                }
                                window.hasUserCustomizedBackground = true;
                            };
                            window.shouldHaveFocus = false;
                            picker.show();
                        }
                    }
                    onBackgroundEyedropperRequested: (slot) => {
                        window.backgroundColorPickingSlot = slot;
                        window.currentTool = "colorpicker";
                    }
                    onChangeBackgroundGradientStart: (col) => {
                        window.backgroundGradientStart = col;
                        window.hasUserCustomizedBackground = true;
                    }
                    onChangeBackgroundGradientEnd: (col) => {
                        window.backgroundGradientEnd = col;
                        window.hasUserCustomizedBackground = true;
                    }
                    onChangeBackgroundGradientAngle: (angle) => {
                        window.backgroundGradientAngle = angle;
                    }
                    onChangeBackgroundPadding: (pad) => {
                        window.backgroundPadding = pad;
                    }
                    onChangeBackgroundCornerRadius: (r) => {
                        window.backgroundCornerRadius = r;
                    }
                    onChangeBackgroundShadowStrength: (s) => {
                        window.backgroundShadowStrength = s;
                    }
                    onChangeBackgroundAspectRatio: (ratio) => {
                        window.backgroundAspectRatio = ratio;
                    }
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                    }
                    onChangeBackgroundAlignment: (alignment) => {
                        window.backgroundAlignment = alignment;
                    }
                    onAutoColorBalanceRequested: {
                        window.backgroundGradientStart = window.autoBackgroundGradientStart;
                        window.backgroundGradientEnd = window.autoBackgroundGradientEnd;
                        window.backgroundSolidColor = window.autoBackgroundSolidColor;
                        window.hasUserCustomizedBackground = true;
                    }

                    onToolSelected: (tool) => {
                        window.handleToolbarToolSelected(tool, moreToolsMenu);
                    }
                    onColorSelected: (color, index) => {
                        window.handleToolbarColorSelected(color, index, moreToolsMenu);
                    }
                    onCustomColorPickerRequested: (buttonItem) => {
                        window.handleToolbarCustomColorPickerRequested(moreToolsMenu);
                    }
                    onStrokeWidthSelected: (width) => {
                        window.handleToolbarStrokeWidthSelected(width, moreToolsMenu);
                    }
                    onUndoRequested: {
                        window.runToolbarAction(window.performUndo, moreToolsMenu);
                    }
                    onRedoRequested: {
                        window.runToolbarAction(window.performRedo, moreToolsMenu);
                    }
                    onAnnotationsToggled: window.showAnnotations = !window.showAnnotations

                    onFloatRequested: {
                        window.runToolbarAction(captureActions.performFloatAction, moreToolsMenu);
                    }
                    onSaveRequested: {
                        window.runToolbarAction(captureActions.performSaveOnly, moreToolsMenu);
                    }
                    onSaveAsRequested: {
                        window.runToolbarAction(window.openSaveAsDialog, moreToolsMenu);
                    }

                    onCopyRequested: {
                        window.runToolbarAction(captureActions.performCopyOnly, moreToolsMenu);
                    }
                    onAnonymousCopyRequested: {
                        window.runToolbarAction(captureActions.performAnonymousCopy, moreToolsMenu);
                    }
                    onCopyAndSaveRequested: {
                        window.runToolbarAction(captureActions.performCopyAndSave, moreToolsMenu);
                    }
                    onCloseRequested: {
                        window.runToolbarAction(window.discardAndClose, moreToolsMenu);
                    }
                    onMoreToolsClicked: (buttonItem) => {
                        window.toggleMoreToolsMenu(buttonItem, moreToolsMenu, toolbarCard, contentRoot);
                    }
                    onBackgroundControlHovered: (type, controlItem) => {
                        let popover = null;
                        if (type === "padding") popover = backgroundPaddingPopover;
                        else if (type === "radius") popover = backgroundRadiusPopover;
                        else if (type === "shadow") popover = backgroundShadowPopover;
                        else if (type === "angle") popover = backgroundAnglePopover;
                        else if (type === "aspectRatio") popover = backgroundAspectRatioPopover;
                        else if (type === "alignment") popover = backgroundAlignmentPopover;
                        else if (type === "presets") popover = backgroundPresetsPopover;
                        else if (type === "imageDim") popover = backgroundImageDimPopover;
                        window.handleBackgroundControlHovered(popover, controlItem, toolbarCard, contentRoot);
                    }
                    onBackgroundControlExited: (type) => {
                        let popover = null;
                        if (type === "padding") popover = backgroundPaddingPopover;
                        else if (type === "radius") popover = backgroundRadiusPopover;
                        else if (type === "shadow") popover = backgroundShadowPopover;
                        else if (type === "angle") popover = backgroundAnglePopover;
                        else if (type === "aspectRatio") popover = backgroundAspectRatioPopover;
                        else if (type === "alignment") popover = backgroundAlignmentPopover;
                        else if (type === "presets") popover = backgroundPresetsPopover;
                        else if (type === "imageDim") popover = backgroundImageDimPopover;
                        window.handleBackgroundControlExited(popover);
                    }
                    onBackgroundControlWheel: (type, delta) => {
                        window.handleBackgroundControlWheel(type, delta);
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

                    ScanResultPopover {
                        id: scanResultPopover
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.spacingM
                        Component.onCompleted: window.scanResultPopoverRef = scanResultPopover
                    }

                    MouseArea {
                        id: boardBackgroundMouseArea
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        cursorShape: (window.lastPanMouse.x !== 0 || window.lastPanMouse.y !== 0) ? Qt.ClosedHandCursor : Qt.ArrowCursor

                        onPositionChanged: (mouse) => {
                            if (pressed && (mouse.buttons & Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier) && (mouse.modifiers & Qt.ShiftModifier)) {
                                const currentPt = Qt.point(mouse.x, mouse.y);
                                if (window.lastPanMouse.x === 0 && window.lastPanMouse.y === 0) {
                                    window.lastPanMouse = currentPt;
                                } else {
                                    const dx = currentPt.x - window.lastPanMouse.x;
                                    const dy = currentPt.y - window.lastPanMouse.y;
                                    window.updatePanOffset(window.userPanX + dx, window.userPanY + dy);
                                    window.lastPanMouse = currentPt;
                                }
                            }
                        }

                        onPressed: (mouse) => {
                            if ((mouse.button === Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier) && (mouse.modifiers & Qt.ShiftModifier)) {
                                window.lastPanMouse = Qt.point(mouse.x, mouse.y);
                            }
                        }

                        onReleased: (mouse) => {
                            window.lastPanMouse = Qt.point(0, 0);
                        }

                        onWheel: (wheel) => {
                            if ((wheel.modifiers & Qt.ControlModifier) && (wheel.modifiers & Qt.ShiftModifier)) {
                                const zoomStep = wheel.angleDelta.y > 0 ? 0.1 : -0.1;
                                const focusPt = Qt.point(wheel.x - boardContainer.width / 2, wheel.y - boardContainer.height / 2);
                                window.adjustUserZoom(zoomStep, focusPt);
                                wheel.accepted = true;
                                return;
                            }

                            if (wheel.modifiers & Qt.ControlModifier) {
                                const scrollDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                const panStep = scrollDelta > 0 ? 40 : -40;
                                window.updatePanOffset(window.userPanX, window.userPanY + panStep);
                                wheel.accepted = true;
                                return;
                            }

                            if (wheel.modifiers & Qt.ShiftModifier) {
                                const scrollDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                                const panStep = scrollDelta > 0 ? 40 : -40;
                                window.updatePanOffset(window.userPanX + panStep, window.userPanY);
                                wheel.accepted = true;
                                return;
                            }

                            const normalScrollDelta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                            const normalPanStep = normalScrollDelta > 0 ? 40 : -40;
                            window.updatePanOffset(window.userPanX, window.userPanY + normalPanStep);
                            wheel.accepted = true;
                        }
                    }

                    // Background Image Layer (Hardware Accelerated)
                    Item {
                        id: bgImageLayer
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.userPanX
                        anchors.verticalCenterOffset: window.userPanY
                        width: drawingCanvas.width
                        height: drawingCanvas.height
                        scale: drawingCanvas.scale
                        transformOrigin: drawingCanvas.transformOrigin
                        clip: true
                        visible: window.effectiveBackgroundMode === "none"

                        Item {
                            id: transformedBgContainer
                            readonly property bool isRotated90: (window.bgRotation === 90 || window.bgRotation === 270)
                            readonly property real rawW: window.bgImageItem ? window.bgImageItem.sourceSize.width : 1
                            readonly property real rawH: window.bgImageItem ? window.bgImageItem.sourceSize.height : 1

                            width: (isRotated90 ? rawH : rawW) * window.editScale
                            height: (isRotated90 ? rawW : rawH) * window.editScale

                            x: window.hasActiveCropSelection ? -window.cropRect.x * window.editScale : 0
                            y: window.hasActiveCropSelection ? -window.cropRect.y * window.editScale : 0

                            Image {
                                id: staticBgImage
                                source: window.bgImageSource
                                cache: false
                                smooth: true
                                mipmap: true

                                anchors.centerIn: parent
                                width: transformedBgContainer.rawW * window.editScale
                                height: transformedBgContainer.rawH * window.editScale

                                rotation: window.bgRotation
                                transform: Scale {
                                    origin.x: staticBgImage.width / 2
                                    origin.y: staticBgImage.height / 2
                                    xScale: window.bgFlipH ? -1 : 1
                                    yScale: window.bgFlipV ? -1 : 1
                                }
                            }
                        }
                    }

                    Canvas {
                        id: backgroundCanvas
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.userPanX
                        anchors.verticalCenterOffset: window.userPanY
                        scale: window.effectiveFitScale / window.editScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image
                        z: 0
                        visible: window.effectiveBackgroundMode !== "none"

                        width: window.canvasWidth * window.editScale
                        height: window.canvasHeight * window.editScale

                        layer.enabled: false

                        Component.onCompleted: {
                            window.backgroundCanvas = backgroundCanvas;
                        }

                        onImageLoaded: {
                            backgroundCanvas.requestPaint();
                        }

                        onPaint: {
                            window.renderBackgroundCanvas(backgroundCanvas, bgImage);
                        }
                    }

                    Canvas {
                        id: bakedCanvas
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.userPanX
                        anchors.verticalCenterOffset: window.userPanY
                        scale: window.effectiveFitScale / window.editScale
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
                            window.renderBakedCanvas(bakedCanvas, bgImage);
                        }
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.userPanX
                        anchors.verticalCenterOffset: window.userPanY
                        scale: window.effectiveFitScale / window.editScale
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
                            const isBackgroundActive = window.effectiveBackgroundMode !== "none";
                            window.applyEditorAnnotationTransform(ctx, isBackgroundActive);

                            if (window.showAnnotations) {
                                window.drawActiveAnnotationLayer(ctx);
                                window.drawTypingPreview(ctx);
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
                        }

                        InlineTextEditor {
                            id: inlineTextEditor
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
                        visible: (config.pluginData["showCanvasBorder"] !== undefined ? config.pluginData["showCanvasBorder"] : true) && (window.effectiveBackgroundMode === "none")
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

                    SizePreviewCard {
                        id: sizePreviewItem
                        window: rootWindow
                        drawingCanvas: drawingCanvas
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



                    BusyIndicator {
                        anchors.centerIn: parent
                        running: window.backgroundBlurLoading && window.backgroundBlurShowIndicator
                        visible: running
                        z: 100
                    }
                }

                Canvas {
                    id: exportCanvas
                    readonly property real exportDpr: Screen.devicePixelRatio || 1.0
                    property int outputPixelWidth: 1
                    property int outputPixelHeight: 1
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
                        window.renderExportCanvas(exportCanvas, bgImage);
                    }
                }

                RadialMenu {
                    id: radialMenu
                    presets: window.radialPresets
                    hoverTrigger: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverTrigger !== undefined ? window.parentWidget.pluginData.radialHoverTrigger : true
                    hoverDelay: window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialHoverDelay !== undefined ? window.parentWidget.pluginData.radialHoverDelay : 200
                    menuOpacity: (window.parentWidget && window.parentWidget.pluginData && window.parentWidget.pluginData.radialMenuOpacity !== undefined ? window.parentWidget.pluginData.radialMenuOpacity : 100) / 100
                    onPresetSelected: (preset) => {
                        window.currentTool = preset.tool;
                        window.currentColor = preset.color;
                        const meta = Constants.getToolMeta(preset.tool);
                        const clamped = Helpers.clamp(preset.thickness, meta.min, meta.max);
                        window.applyToolIntensity(preset.tool, clamped);
                        window.updateSessionToolIntensity(preset.tool, clamped);
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
                    currentShape: window.calloutShape
                    onLinkLinesSelected: (count) => window.calloutLinkLines = count
                    onShapeSelected: (shape) => window.calloutShape = shape
                }



                MoreToolsMenu {
                    id: moreToolsMenu
                    watermarkEnabled: window.watermarkEnabled
                    floatingMode: window.floatingMode
                    onRotateLeftRequested: window.rotateScreenshot("left")
                    onRotateRightRequested: window.rotateScreenshot("right")
                    onFlipHorizontalRequested: window.mirrorScreenshot("horizontal")
                    onFlipVerticalRequested: window.mirrorScreenshot("vertical")
                    onRotateRequested: window.rotateScreenshot("right")
                    onMirrorRequested: window.mirrorScreenshot("horizontal")
                    onOcrRequested: window.runOcr()
                    onQrScanRequested: window.runQrScan()
                    onEraserRequested: window.currentTool = "eraser"
                    onWatermarkToggled: (enabled) => window.setWatermarkEnabled(enabled)
                    onEditorPresentationToggled: window.togglePresentationMode()
                    onInsertImageRequested: window.openInsertImageDialog()
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
                            const val = config.pluginData[`toolbar_color_${i}`] || config.adaptiveColors[i];
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
                    id: backgroundPaddingPopover
                    allowOpen: window.currentTool === "background"
                    isVertical: toolbarCard.isVertical
                    minimum: 10
                    maximum: 150
                    value: window.backgroundPadding
                    onUserValueChanged: (val) => {
                        window.backgroundPadding = val;
                    }
                }

                HoverSliderPopover {
                    id: backgroundRadiusPopover
                    allowOpen: window.currentTool === "background"
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 60
                    stepSize: 2
                    value: window.backgroundCornerRadius
                    onUserValueChanged: (val) => {
                        window.backgroundCornerRadius = val;
                    }
                }

                HoverSliderPopover {
                    id: backgroundShadowPopover
                    allowOpen: window.currentTool === "background"
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 100
                    value: window.backgroundShadowStrength
                    onUserValueChanged: (val) => {
                        window.backgroundShadowStrength = val;
                    }
                }

                HoverSliderPopover {
                    id: backgroundAnglePopover
                    allowOpen: window.currentTool === "background"
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 360
                    stepSize: 15
                    value: window.backgroundGradientAngle
                    onUserValueChanged: (val) => {
                        window.backgroundGradientAngle = val;
                    }
                }

                HoverSliderPopover {
                    id: backgroundImageDimPopover
                    allowOpen: window.currentTool === "background"
                    isVertical: toolbarCard.isVertical
                    minimum: 0
                    maximum: 80
                    value: window.backgroundImageDimStrength
                    onUserValueChanged: (val) => window.setBackgroundImageDimStrength(val, true)
                }

                BackgroundAspectRatioPopover {
                    id: backgroundAspectRatioPopover
                    allowOpen: window.currentTool === "background"
                    backgroundAspectRatio: window.backgroundAspectRatio
                    customAspectRatio: window.customAspectRatio
                    presets: window.aspectPresets

                    // Anchor-based positioning so popover stays correctly placed
                    // when height changes (e.g. customActive toggles the slider section)
                    property real _anchorY: 0
                    property bool _anchorIsAbove: false
                    y: _anchorIsAbove ? (_anchorY - height - Theme.spacingXS) : _anchorY

                    onChangeBackgroundAspectRatio: (ratio) => {
                        window.backgroundAspectRatio = ratio;
                    }
                    onChangeCustomAspectRatio: (ratio) => {
                        window.customAspectRatio = ratio;
                    }
                }

                BackgroundAlignmentPopover {
                    id: backgroundAlignmentPopover
                    allowOpen: window.currentTool === "background"
                    backgroundAlignment: window.backgroundAlignment
                    onChangeBackgroundAlignment: (alignment) => {
                        window.backgroundAlignment = alignment;
                    }
                }

                BackgroundImagePopover {
                    id: backgroundImagePopover
                    allowOpen: window.currentTool === "background"
                    images: window.backgroundImages
                    folderPath: window.backgroundImageFolder
                    selectedPath: window.backgroundImagePath
                    loading: window.backgroundImagesLoading
                    onRefreshRequested: window.loadBackgroundImages()
                    onImageSelected: (path) => {
                        window.setBackgroundImage(path, true);
                        backgroundImagePopover.close();
                    }
                }

                BackgroundPresetsPopover {
                    id: backgroundPresetsPopover
                    allowOpen: window.currentTool === "background"
                    presetsList: window.backgroundPresets
                    onPresetSelected: (preset) => window.applyBackgroundPreset(preset)
                    onSaveCurrentAsPreset: window.saveCurrentBackgroundAsPreset()
                    onDeletePreset: (presetId) => window.deletePreset(presetId)
                    onUpdatePresetWithCurrent: (presetId) => window.updatePresetWithCurrent(presetId)
                    onRenamePreset: (presetId, newName) => window.renamePreset(presetId, newName)
                }

                Canvas {
                    id: contrastSampler
                    visible: false
                    width: 8
                    height: 8
                    onPaint: {
                        var ctx = contrastSampler.getContext("2d");
                        ctx.drawImage(bgImage, 0, 0, 8, 8, 0, 0, 8, 8);
                        var imgData = ctx.getImageData(0, 0, 8, 8);
                        if (imgData && imgData.data) {
                            var centerX = Math.floor(imgData.width / 2);
                            var centerY = Math.floor(imgData.height / 2);
                            var centerIndex = (centerY * imgData.width + centerX) * 4;
                            var r = imgData.data[centerIndex];
                            var g = imgData.data[centerIndex + 1];
                            var b = imgData.data[centerIndex + 2];
                            var brightness = Helpers.getLuminance({ r: r/255, g: g/255, b: b/255 });
                            window.isScreenshotDark = (brightness < 0.35);
                            window.hasSampledContrast = true;

                            // Extract auto-balanced colors
                            var colors = Helpers.extractDominantColors(imgData, Qt);
                            window.autoBackgroundGradientStart = colors.start;
                            window.autoBackgroundGradientEnd = colors.end;
                            window.autoBackgroundSolidColor = colors.start;
                            window.applyAdaptiveBackgroundColors();
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

    function openTypingDialog(dialog) {
        const targetDialog = dialog || textInputDialog;
        if (targetDialog) {
            targetDialog.open();
        }
    }

    function beginEditingTextStroke(stroke, dialog) {
        window.editingStroke = stroke;
        window.deselectStrokeForEditing(false);
        window.typingIsSpeechBubble = stroke.isSpeechBubble || false;

        // Store coordinates directly on the stroke to avoid cross-contamination
        // between concurrent edit sessions (multiple dialogs)
        stroke._editCoords = (stroke.isSpeechBubble && stroke.points.length >= 2)
            ? Qt.point(stroke.points[1].x, stroke.points[1].y)
            : Qt.point(stroke.points[0].x, stroke.points[0].y);
        window.typingCoords = stroke._editCoords;
        if (stroke.isSpeechBubble && stroke.points.length >= 2) {
            stroke._editTargetCoords = Qt.point(stroke.points[0].x, stroke.points[0].y);
            window.typingTargetCoords = stroke._editTargetCoords;
            window.typingHasTargetCoords = true;
        } else {
            window.typingTargetCoords = Qt.point(0, 0);
            window.typingHasTargetCoords = false;
        }

        window.currentTypingText = stroke.text;
        window.typingCursorIndex = stroke.text ? stroke.text.length : 0;
        window.isTyping = true;
        window.currentColor = stroke.color;
        window.textFontSize = stroke.width;
        window.textBold = stroke.isBold;
        window.textItalic = stroke.isItalic;
        window.textUnderline = stroke.isUnderline;
        window.textBackground = stroke.hasBackground;
        window.textCornerRadius = stroke.cornerRadius;
        window.textFontFamily = stroke.fontFamily || (Theme.fontFamily || "sans-serif");
        window.openTypingDialog(dialog);
        window.repaintActiveCanvas();
    }

    function beginNewTextStroke(stroke, dialog) {
        const hasDrag = stroke.isSpeechBubble && stroke.points.length >= 2;
        window.typingIsSpeechBubble = hasDrag;
        window.typingCoords = hasDrag
            ? Qt.point(stroke.points[1].x, stroke.points[1].y)
            : Qt.point(stroke.points[0].x, stroke.points[0].y);
        if (hasDrag) {
            window.typingTargetCoords = Qt.point(stroke.points[0].x, stroke.points[0].y);
        }
        window.typingHasTargetCoords = hasDrag;
        window.currentTypingText = "";
        window.typingCursorIndex = 0;
        window.isTyping = true;
        window.currentStroke = null;
        if (window.textInputMode === "popup") {
            window.openTypingDialog(dialog);
        }
        window.repaintActiveCanvas();
    }

    function getTypingStrokeStyle(textStr) {
        return {
            tool: "text",
            color: window.currentColor.toString(),
            width: window.textFontSize,
            fontFamily: window.textFontFamily,
            isBold: window.textBold,
            isItalic: window.textItalic,
            isUnderline: window.textUnderline,
            hasBackground: window.textBackground,
            cornerRadius: window.textCornerRadius,
            text: textStr
        };
    }

    function defaultTypingSpeechBubbleTarget() {
        const offset = Math.max(32, window.textFontSize * 2.1);
        const xOffset = offset * 0.8;
        return Qt.point(
            window.typingCoords.x - xOffset,
            window.typingCoords.y + offset * 1.15
        );
    }

    function ensureTypingSpeechBubbleTarget() {
        if (window.typingHasTargetCoords) return;
        window.typingTargetCoords = window.defaultTypingSpeechBubbleTarget();
        window.typingHasTargetCoords = true;
    }

    function toggleTypingSpeechBubble() {
        window.typingIsSpeechBubble = !window.typingIsSpeechBubble;
        if (window.typingIsSpeechBubble) {
            window.ensureTypingSpeechBubbleTarget();
        }
        window.repaintActiveCanvas();
    }

    function applyTypingStyleToStroke(stroke, textStr) {
        const style = window.getTypingStrokeStyle(textStr);
        stroke.text = style.text;
        stroke.color = style.color;
        stroke.width = style.width;
        stroke.fontFamily = style.fontFamily;
        stroke.isBold = style.isBold;
        stroke.isItalic = style.isItalic;
        stroke.isUnderline = style.isUnderline;
        stroke.hasBackground = style.hasBackground;
        stroke.cornerRadius = style.cornerRadius;
    }

    function replaceStrokeReference(stroke) {
        const idx = window.strokes.indexOf(stroke);
        if (idx !== -1) {
            const list = [...window.strokes];
            list[idx] = stroke;
            window.strokes = list;
        }
    }

    function removeTypingEditStroke() {
        const list = [...window.strokes];
        const idx = list.indexOf(window.editingStroke);
        if (idx !== -1) list.splice(idx, 1);
        window.strokes = list;
    }

    function updateTypingEditStroke(textStr) {
        const s = window.editingStroke;
        window.applyTypingStyleToStroke(s, textStr);
        s.isSpeechBubble = window.typingIsSpeechBubble;

        // Use per-stroke saved coordinates to prevent cross-contamination
        // when multiple edit dialogs are open simultaneously
        const editCoords = s._editCoords || window.typingCoords;
        const editTargetCoords = s._editTargetCoords || window.typingTargetCoords;
        if (s.isSpeechBubble && !window.typingHasTargetCoords) {
            window.ensureTypingSpeechBubbleTarget();
        }
        if (s.isSpeechBubble) {
            const targetCoords = window.typingHasTargetCoords ? window.typingTargetCoords : editTargetCoords;
            s.points = [
                Qt.point(targetCoords.x, targetCoords.y),
                Qt.point(editCoords.x, editCoords.y)
            ];
        } else {
            s.points = [Qt.point(editCoords.x, editCoords.y)];
        }

        window.replaceStrokeReference(s);
        if (window.currentTool === "select") {
            window.selectedStroke = s;
        }

        delete s._editCoords;
        delete s._editTargetCoords;
    }

    function createTypingStroke(textStr) {
        const stroke = window.getTypingStrokeStyle(textStr);
        stroke.isSpeechBubble = window.typingIsSpeechBubble;
        if (stroke.isSpeechBubble) {
            window.ensureTypingSpeechBubbleTarget();
        }
        stroke.points = window.typingIsSpeechBubble
            ? [Qt.point(window.typingTargetCoords.x, window.typingTargetCoords.y), Qt.point(window.typingCoords.x, window.typingCoords.y)]
            : [Qt.point(window.typingCoords.x, window.typingCoords.y)];
        window.pushStroke(stroke);
    }

    function finishTypingSession() {
        window.currentTypingText = "";
        window.isTyping = false;
        window.typingHasTargetCoords = false;
        window.typingTargetCoords = Qt.point(0, 0);
        window.repaintActiveCanvas();
        Qt.callLater(() => window.focusModalAfterToolbarAction());
    }

    function commitTypingText() {
        if (!window.isTyping) return;
        const textStr = window.currentTypingText.trim();
        if (window.editingStroke) {
            if (textStr.length > 0) {
                window.updateTypingEditStroke(textStr);
            } else {
                window.removeTypingEditStroke();
            }
            window.editingStroke = null;
        } else if (textStr.length > 0) {
            window.createTypingStroke(textStr);
        }
        window.finishTypingSession();
    }

    function pushStroke(stroke) {
        const list = [...window.strokes];
        list.push(stroke);
        window.strokes = list;
        window.undoneStrokes = [];
        window.repaintActiveCanvas();
    }

    function performUndo() {
        if (window.strokes.length > 0) {
            const list = [...window.strokes];
            const popped = list.pop();
            window.strokes = list;
            window.undoneStrokes = [...window.undoneStrokes, popped];
            if (window.selectedStroke === popped) {
                window.deselectStrokeForEditing(true);
            }
            window.repaintActiveCanvas();
        }
    }

    function performRedo() {
        if (window.undoneStrokes.length > 0) {
            const undoneList = [...window.undoneStrokes];
            const strokeToRedo = undoneList.pop();
            window.undoneStrokes = undoneList;
            window.strokes = [...window.strokes, strokeToRedo];

            if (window.currentTool === "select") {
                window.selectStrokeForEditing(strokeToRedo, !window.selectedStroke);
            }

            window.repaintActiveCanvas();
        }
    }

    function discardAndClose() {
        window.deselectStrokeForEditing(false);
        window.copiedStroke = null;
        window.pastePreviewActive = false;
        window.close();
    }

    onDialogClosed: {
        if (window.presentationSwitching) {
            return;
        }
        if (window.floatService) {
            window.floatService.showAllWindows();
        }
        // Reset path state here (not in onOpened) so re-fires during layout/screen changes
        // don't wipe bgImageSource before the image has a chance to render.
        window.currentCapturePath = "";
        window.restoreSource = "";
        window.bgImageSource = "";
        window.scanResultPopoverRef = null;
        window.exportCallback = null;
        window.cancelBackgroundBlurPreparation();
        window.sessionDisplayModeOverride = false;
    }

    Component.onCompleted: {
        window.loadPresetsFromPluginData();
    }

    Component.onDestruction: {
        window.cleanupBackgroundBlurCache(window.backgroundBlurredImagePath);
    }
}
