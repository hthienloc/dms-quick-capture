import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Modals.Common
import qs.Services
import qs.Widgets
import "../dms-common"

DankModal {
    id: window

    layerNamespace: "dms:plugins:quickCapture"
    keepPopoutsOpen: true

    // Parent communication reference
    property var parentWidget: null

    // State Variables
    property string currentTool: "pen" // pen, highlighter, rect, arrow, text, stamp, eraser
    property string currentColor: "#3b82f6" // Default to Tailwind Blue-500
    property int strokeWidth: 4
    property int stampCounter: 1
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false

    property var strokes: []
    property var currentStroke: null

    // Text Input Management
    property bool isTyping: false
    property point typingCoords: Qt.point(0,0)

    // Helper to decode hex color to RGB
    function hexToRgb(hex) {
        if (!hex || hex.length < 7) return { r: 0.2, g: 0.5, b: 1 };
        return {
            r: parseInt(hex.slice(1, 3), 16) / 255,
            g: parseInt(hex.slice(3, 5), 16) / 255,
            b: parseInt(hex.slice(5, 7), 16) / 255
        };
    }

    backgroundOpacity: 0.6
    backgroundColor: Theme.withAlpha(Theme.surfaceContainer, Theme.popupTransparency)

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

    // Reactive aspect-fit scale computation
    property real fitScale: {
        if (!activeCanvas || !bgImageItem || !boardContainerItem) return 1.0;
        const maxW = boardContainerItem.width - 32;
        const maxH = boardContainerItem.height - 32;
        if (bgImageItem.sourceSize.width <= 0 || bgImageItem.sourceSize.height <= 0) return 1.0;
        const scaleX = maxW / bgImageItem.sourceSize.width;
        const scaleY = maxH / bgImageItem.sourceSize.height;
        return Math.min(1.0, Math.min(scaleX, scaleY));
    }

    onBackgroundClicked: () => discardAndClose()

    // Keyboard Shortcuts Support
    modalFocusScope.Keys.onPressed: (event) => {
        if (window.isTyping) return; // Ignore hotkeys while typing text
        
        if (event.key === Qt.Key_Escape) {
            window.discardAndClose();
            event.accepted = true;
        } else if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)) {
            window.performUndo();
            event.accepted = true;
        } else if ((event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) || event.key === Qt.Key_Return) {
            window.performCopyOnly();
            event.accepted = true;
        } else if (event.key === Qt.Key_S && (event.modifiers & Qt.ControlModifier)) {
            window.performSaveOnly();
            event.accepted = true;
        }
    }

    onOpened: {
        // Read initial settings from pluginData if available
        if (window.parentWidget && window.parentWidget.pluginData) {
            window.currentTool = window.parentWidget.pluginData.defaultTool || "pen";
            window.strokeWidth = window.parentWidget.pluginData.defaultThickness || 4;
        }
        window.strokes = [];
        window.stampCounter = 1;
        window.bgImageSource = "";
        window.bgImageSource = "file:///tmp/dms_capture_bg.png";
        window.isScreenshotDark = false;
        window.hasSampledContrast = false;
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
                            window.activeCanvas.width = sourceSize.width;
                            window.activeCanvas.height = sourceSize.height;
                            window.activeCanvas.loadImage(source);
                        }
                    }
                }
            }

            Column {
                id: mainColumn
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                // 1. Top Glassmorphic Toolbar
                Rectangle {
                    id: toolbarCard
                    width: parent.width
                    height: 52
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
                    border.color: Theme.withAlpha(Theme.outline, 0.15)
                    border.width: 1

                    // Left group: editing tools
                    Row {
                        id: leftGroup
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        // Tool buttons
                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [
                                    { id: "pen", icon: "edit", tooltip: "Freehand Pen" },
                                    { id: "highlighter", icon: "border_color", tooltip: "Highlighter" },
                                    { id: "rect", icon: "check_box_outline_blank", tooltip: "Rectangle" },
                                    { id: "redact", icon: "stop", tooltip: "Redact (Filled Box)" },
                                    { id: "pixelate", icon: "blur_on", tooltip: "Pixelate / Blur" },
                                    { id: "arrow", icon: "trending_flat", tooltip: "Arrow" },
                                    { id: "text", icon: "text_fields", tooltip: "Text" },
                                    { id: "stamp", icon: "looks_one", tooltip: "Number Stamp" },
                                    { id: "eraser", icon: "auto_fix_normal", tooltip: "Eraser" }
                                ]

                                delegate: DankActionButton {
                                    iconName: modelData.icon
                                    buttonSize: 36
                                    iconSize: 18
                                    tooltipText: modelData.tooltip

                                    backgroundColor: window.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                                    iconColor: window.currentTool === modelData.id ? Theme.primary : Theme.surfaceText

                                    onClicked: {
                                        window.currentTool = modelData.id;
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: 1
                            height: 24
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Color picker
                        Row {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [
                                    "#3b82f6",
                                    "#ef4444",
                                    "#22c55e",
                                    "#eab308",
                                    "#ffffff",
                                    "#000000"
                                ]

                                delegate: Rectangle {
                                    width: 24
                                    height: 24
                                    radius: 12
                                    color: modelData
                                    border.color: window.currentColor === modelData ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                                    border.width: window.currentColor === modelData ? 2 : 1

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            window.currentColor = modelData;
                                        }
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: 1
                            height: 24
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Size Slider
                        Row {
                            spacing: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            
                            Text {
                                text: window.strokeWidth + "px"
                                color: Theme.surfaceText
                                font.pixelSize: 11
                                font.bold: true
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Slider {
                                id: sizeSlider
                                from: 1
                                to: 50
                                value: window.strokeWidth
                                onMoved: {
                                    window.strokeWidth = Math.round(value);
                                }
                                anchors.verticalCenter: parent.verticalCenter
                                width: 80
                                
                                background: Rectangle {
                                    x: sizeSlider.leftPadding
                                    y: sizeSlider.topPadding + sizeSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 80
                                    implicitHeight: 4
                                    width: sizeSlider.availableWidth
                                    height: implicitHeight
                                    radius: 2
                                    color: Theme.withAlpha(Theme.outline, 0.3)

                                    Rectangle {
                                        width: sizeSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: Theme.primary
                                        radius: 2
                                    }
                                }

                                handle: Rectangle {
                                    x: sizeSlider.leftPadding + sizeSlider.visualPosition * (sizeSlider.availableWidth - width)
                                    y: sizeSlider.topPadding + sizeSlider.availableHeight / 2 - height / 2
                                    implicitWidth: 12
                                    implicitHeight: 12
                                    radius: 6
                                    color: Theme.primary
                                    border.color: Theme.surface
                                    border.width: 1
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            width: 1
                            height: 24
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Undo
                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "undo"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Undo (Ctrl+Z)"
                            enabled: window.strokes.length > 0
                            iconColor: window.strokes.length > 0 ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.3)
                            onClicked: window.performUndo()
                        }
                    }

                    // Right group: save + copy | close
                    Row {
                        id: rightGroup
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingXS

                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "save"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Save to File (Ctrl+S)"
                            onClicked: window.performSaveOnly()
                        }

                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "content_copy"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Copy to Clipboard (Ctrl+C / Enter)"
                            backgroundColor: Theme.withAlpha(Theme.primary, 0.1)
                            iconColor: Theme.primary
                            onClicked: window.performCopyOnly()
                        }

                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "assignment_turned_in"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Copy & Save"
                            backgroundColor: Theme.withAlpha(Theme.primary, 0.15)
                            iconColor: Theme.primary
                            onClicked: window.performCopyAndSave()
                        }

                        // Separator gap before close
                        Item { width: Theme.spacingL; height: 1 }

                        Rectangle {
                            width: 1
                            height: 24
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: Theme.spacingXS; height: 1 }

                        DankActionButton {
                            anchors.verticalCenter: parent.verticalCenter
                            iconName: "close"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Discard & Close (Escape)"
                            backgroundColor: Theme.withAlpha(Theme.error, 0.1)
                            iconColor: Theme.error
                            onClicked: window.discardAndClose()
                        }
                    }
                }

                // 2. Centered Canvas Board
                Item {
                    id: boardContainer
                    width: parent.width
                    height: parent.height - toolbarCard.height - Theme.spacingM

                    Component.onCompleted: {
                        window.boardContainerItem = boardContainer;
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: window.isScreenshotDark ? Theme.surfaceContainerHighest : Theme.withAlpha(Theme.surfaceContainerHighest, 0.3)
                        border.color: Theme.withAlpha(Theme.outline, 0.1)
                        border.width: 1
                        radius: Theme.cornerRadius
                    }

                    Canvas {
                        id: drawingCanvas
                        anchors.centerIn: parent
                        scale: window.fitScale
                        transformOrigin: Item.Center
                        renderTarget: Canvas.Image

                        Component.onCompleted: {
                            window.activeCanvas = drawingCanvas;
                        }

                        onImageLoaded: {
                            drawingCanvas.requestPaint();
                        }

                        onPaint: {
                            var ctx = drawingCanvas.getContext("2d");
                            ctx.clearRect(0, 0, drawingCanvas.width, drawingCanvas.height);

                            // 1. Draw the screenshot background first
                            if (drawingCanvas.isImageLoaded("file:///tmp/dms_capture_bg.png")) {
                                ctx.drawImage("file:///tmp/dms_capture_bg.png", 0, 0, drawingCanvas.width, drawingCanvas.height);

                                if (!window.hasSampledContrast) {
                                    try {
                                        var imgData = ctx.getImageData(0, 0, 1, 1);
                                        if (imgData && imgData.data) {
                                            var r = imgData.data[0];
                                            var g = imgData.data[1];
                                            var b = imgData.data[2];
                                            var brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
                                            window.isScreenshotDark = (brightness < 0.35);
                                            window.hasSampledContrast = true;
                                        }
                                    } catch (e) {
                                        // Ignore
                                    }
                                }
                            }

                            // 2. Draw all committed annotations
                            for (var i = 0; i < window.strokes.length; i++) {
                                drawStroke(ctx, window.strokes[i]);
                            }

                            // 3. Draw the current active stroke (if dragging)
                            if (window.currentStroke) {
                                drawStroke(ctx, window.currentStroke);
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

                            } else if (stroke.tool === "highlighter") {
                                ctx.strokeStyle = Qt.rgba(rgb.r, rgb.g, rgb.b, 0.4);
                                ctx.lineWidth = stroke.width * 4;
                                ctx.lineCap = "square";
                                ctx.lineJoin = "miter";
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
                                ctx.beginPath();
                                ctx.rect(Math.min(p0.x, p1.x), Math.min(p0.y, p1.y), Math.abs(p1.x - p0.x), Math.abs(p1.y - p0.y));
                                ctx.stroke();

                            } else if (stroke.tool === "arrow") {
                                ctx.strokeStyle = stroke.color;
                                ctx.fillStyle = stroke.color;
                                ctx.lineWidth = stroke.width;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";
                                const p0 = stroke.points[0];
                                const p1 = stroke.points[stroke.points.length - 1];

                                // Draw shaft
                                ctx.beginPath();
                                ctx.moveTo(p0.x, p0.y);
                                ctx.lineTo(p1.x, p1.y);
                                ctx.stroke();

                                // Draw head (vector trigonometry)
                                const angle = Math.atan2(p1.y - p0.y, p1.x - p0.x);
                                const spread = Math.PI / 7;
                                const size = stroke.width * 5;
                                ctx.beginPath();
                                ctx.moveTo(p1.x, p1.y);
                                ctx.lineTo(p1.x - size * Math.cos(angle - spread), p1.y - size * Math.sin(angle - spread));
                                ctx.lineTo(p1.x - size * Math.cos(angle + spread), p1.y - size * Math.sin(angle + spread));
                                ctx.closePath();
                                ctx.fill();

                            } else if (stroke.tool === "redact") {
                                const p0 = stroke.points[0];
                                const p1 = stroke.points[stroke.points.length - 1];
                                ctx.fillStyle = stroke.color;
                                ctx.fillRect(Math.min(p0.x, p1.x), Math.min(p0.y, p1.y), Math.abs(p1.x - p0.x), Math.abs(p1.y - p0.y));

                            } else if (stroke.tool === "pixelate") {
                                // Draw pre-computed pixel blocks (sampled at commit time)
                                if (stroke.pixelBlocks && stroke.pixelBlocks.length > 0) {
                                    for (let i = 0; i < stroke.pixelBlocks.length; i++) {
                                        const blk = stroke.pixelBlocks[i];
                                        ctx.fillStyle = blk.color;
                                        ctx.fillRect(blk.x, blk.y, blk.w, blk.h);
                                    }
                                } else if (stroke.points.length >= 2) {
                                    // Drag preview: dashed selection rect
                                    const p0 = stroke.points[0];
                                    const p1 = stroke.points[stroke.points.length - 1];
                                    ctx.save();
                                    ctx.strokeStyle = "rgba(255,255,255,0.8)";
                                    ctx.lineWidth = 1.5;
                                    ctx.setLineDash([6, 4]);
                                    ctx.strokeRect(Math.min(p0.x, p1.x), Math.min(p0.y, p1.y), Math.abs(p1.x - p0.x), Math.abs(p1.y - p0.y));
                                    ctx.restore();
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
                                ctx.font = Math.round(stroke.width * 3.5) + "px sans-serif";
                                ctx.textAlign = "left";
                                ctx.textBaseline = "top";
                                ctx.fillText(stroke.text, pt.x, pt.y);
                            }
                        }

                        // Mouse Drawing & Action Capture
                        MouseArea {
                            id: drawMouseArea
                            anchors.fill: parent
                            hoverEnabled: false

                            onPressed: (mouse) => {
                                if (window.isTyping) {
                                    textInputField.completeTextEntry();
                                    return;
                                }

                                if (window.currentTool === "text") {
                                    window.typingCoords = Qt.point(mouse.x, mouse.y);
                                    window.isTyping = true;
                                    textInputField.text = "";
                                    textInputField.x = mouse.x;
                                    textInputField.y = mouse.y;
                                    textInputField.visible = true;
                                    Qt.callLater(() => {
                                        textInputField.forceActiveFocus();
                                    });
                                    return;
                                }

                                if (window.currentTool === "stamp") {
                                    window.pushStroke({
                                        tool: "stamp",
                                        color: window.currentColor,
                                        width: window.strokeWidth,
                                        points: [Qt.point(mouse.x, mouse.y)],
                                        counter: window.stampCounter
                                    });
                                    window.stampCounter++;
                                    return;
                                }

                                if (window.currentTool === "eraser") {
                                    // Simple hit testing to remove clicked vector strokes
                                    const sx = mouse.x;
                                    const sy = mouse.y;
                                    let found = -1;
                                    for (let i = window.strokes.length - 1; i >= 0; i--) {
                                        const stroke = window.strokes[i];
                                        if (stroke.points.length === 0) continue;
                                        
                                        // Approximate bounding check
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
                                        window.strokes.splice(found, 1);
                                        drawingCanvas.requestPaint();
                                    }
                                    return;
                                }

                                // Standard vector strokes
                                window.currentStroke = {
                                    tool: window.currentTool,
                                    color: window.currentColor,
                                    width: window.strokeWidth,
                                    points: [Qt.point(mouse.x, mouse.y)]
                                };
                                drawingCanvas.requestPaint();
                            }

                            onPositionChanged: (mouse) => {
                                if (!window.currentStroke) return;

                                if (window.currentTool === "pen" || window.currentTool === "highlighter") {
                                    if (mouse.modifiers & Qt.ShiftModifier) {
                                        if (window.currentStroke.points.length > 1) {
                                            window.currentStroke.points = [window.currentStroke.points[0], Qt.point(mouse.x, mouse.y)];
                                        } else {
                                            window.currentStroke.points.push(Qt.point(mouse.x, mouse.y));
                                        }
                                    } else {
                                        window.currentStroke.points.push(Qt.point(mouse.x, mouse.y));
                                    }
                                } else if (window.currentTool === "rect" || window.currentTool === "arrow"
                                         || window.currentTool === "redact" || window.currentTool === "pixelate") {
                                    // Update end coordinate
                                    if (window.currentStroke.points.length > 1) {
                                        window.currentStroke.points[window.currentStroke.points.length - 1] = Qt.point(mouse.x, mouse.y);
                                    } else {
                                        window.currentStroke.points.push(Qt.point(mouse.x, mouse.y));
                                    }
                                }
                                drawingCanvas.requestPaint();
                            }

                            onReleased: (mouse) => {
                                if (!window.currentStroke) return;

                                // Pre-compute pixelate blocks from current canvas state before pushing
                                if (window.currentStroke.tool === "pixelate" && window.currentStroke.points.length >= 2) {
                                    const stroke = window.currentStroke;
                                    const p0 = stroke.points[0];
                                    const p1 = stroke.points[stroke.points.length - 1];
                                    const rx = Math.floor(Math.min(p0.x, p1.x));
                                    const ry = Math.floor(Math.min(p0.y, p1.y));
                                    const rw = Math.floor(Math.abs(p1.x - p0.x));
                                    const rh = Math.floor(Math.abs(p1.y - p0.y));
                                    if (rw > 2 && rh > 2) {
                                        const blockSize = Math.max(8, Math.round(Math.min(rw, rh) / 20));
                                        const ctx2d = drawingCanvas.getContext("2d");
                                        const imageData = ctx2d.getImageData(0, 0, drawingCanvas.width, drawingCanvas.height);
                                        const data = imageData.data;
                                        const stride = imageData.width;
                                        const dpr = stride / drawingCanvas.width;
                                        const blocks = [];
                                        for (let by = 0; by < rh; by += blockSize) {
                                            for (let bx = 0; bx < rw; bx += blockSize) {
                                                let r = 0, g = 0, b = 0, count = 0;
                                                const bw = Math.min(blockSize, rw - bx);
                                                const bh = Math.min(blockSize, rh - by);
                                                const pxStart = Math.round((rx + bx) * dpr);
                                                const pyStart = Math.round((ry + by) * dpr);
                                                const pxEnd = Math.min(Math.round((rx + bx + bw) * dpr), stride);
                                                const pyEnd = Math.min(Math.round((ry + by + bh) * dpr), imageData.height);
                                                for (let py = pyStart; py < pyEnd; py++) {
                                                    for (let px = pxStart; px < pxEnd; px++) {
                                                        const idx = (py * stride + px) * 4;
                                                        r += data[idx];
                                                        g += data[idx + 1];
                                                        b += data[idx + 2];
                                                        count++;
                                                    }
                                                }
                                                if (count > 0) {
                                                    blocks.push({
                                                        x: rx + bx, y: ry + by, w: bw, h: bh,
                                                        color: "rgb(" + Math.round(r/count) + "," + Math.round(g/count) + "," + Math.round(b/count) + ")"
                                                    });
                                                }
                                            }
                                        }
                                        stroke.pixelBlocks = blocks;
                                    }
                                }

                                window.pushStroke(window.currentStroke);
                                window.currentStroke = null;
                            }

                            onWheel: (wheel) => {
                                const step = wheel.angleDelta.y > 0 ? 1 : -1;
                                window.strokeWidth = Math.max(1, Math.min(50, window.strokeWidth + step));
                                window.previewX = wheel.x;
                                window.previewY = wheel.y;
                                window.showSizePreview = true;
                                previewTimer.restart();
                                wheel.accepted = true;
                            }
                        }

                        // Overlay Text Input Field
                        TextField {
                            id: textInputField
                            visible: false
                            width: 250
                            placeholderText: "Type text..."
                            color: window.currentColor
                            font.pixelSize: Math.round(window.strokeWidth * 3.5)
                            
                            background: Rectangle {
                                color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.85)
                                border.color: window.currentColor
                                border.width: 1
                                radius: 4
                            }

                            onAccepted: completeTextEntry()

                            Keys.onEscapePressed: (event) => {
                                textInputField.visible = false;
                                window.isTyping = false;
                                textInputField.text = "";
                                window.forceActiveFocus();
                                event.accepted = true;
                            }

                            function completeTextEntry() {
                                const textStr = textInputField.text.trim();
                                if (textStr.length > 0) {
                                    window.pushStroke({
                                        tool: "text",
                                        color: window.currentColor,
                                        width: window.strokeWidth,
                                        points: [window.typingCoords],
                                        text: textStr
                                    });
                                }
                                textInputField.text = "";
                                textInputField.visible = false;
                                window.isTyping = false;
                                window.forceActiveFocus();
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
                        border.color: window.isScreenshotDark ? "rgba(255, 255, 255, 0.4)" : "rgba(0, 0, 0, 0.4)"
                        border.width: 1
                        z: 10
                    }

                    Rectangle {
                        id: sizePreviewItem
                        visible: window.showSizePreview
                        x: (window.previewX * drawingCanvas.scale) + drawingCanvas.x - (width / 2)
                        y: (window.previewY * drawingCanvas.scale) + drawingCanvas.y - (height / 2)
                        width: {
                            if (window.currentTool === "highlighter") return window.strokeWidth * 4 * drawingCanvas.scale;
                            if (window.currentTool === "stamp") return window.strokeWidth * 10 * drawingCanvas.scale;
                            return window.strokeWidth * drawingCanvas.scale;
                        }
                        height: width
                        radius: window.currentTool === "highlighter" ? 0 : width / 2
                        color: "transparent"
                        border.color: Theme.primary
                        border.width: 1.5
                        z: 20
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
                }
            }
        }
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

    function performSaveOnly() {
        // Save the merged canvas
        const tempOut = "/tmp/dms_capture_output.png";
        if (window.activeCanvas) window.activeCanvas.save(tempOut);
        
        // Wait 100ms for QML canvas save thread to finish writing
        Qt.callLater(() => {
            const hasParent = window.parentWidget && window.parentWidget.pluginData;
            const saveDir = hasParent ? (window.parentWidget.pluginData.saveDirectory || "~/Pictures/Screenshots") : "~/Pictures/Screenshots";
            const cleanDir = saveDir.replace("~", "$HOME");
            const filename = "Screenshot_" + Date.now() + ".png";
            const saveCmd = "mkdir -p " + cleanDir + " && cp " + tempOut + " " + cleanDir + "/" + filename;
            
            Proc.runCommand("save-capture-file", ["sh", "-c", saveCmd], (stdout, exitCode) => {
                if (exitCode === 0) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showInfo("Screenshot saved to " + saveDir + "/" + filename);
                    }
                    window.discardAndClose();
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to save screenshot file.");
                    }
                }
            }, 0, 5000);
        });
    }

    function performCopyOnly() {
        // Save the merged canvas
        const tempOut = "/tmp/dms_capture_output.png";
        if (window.activeCanvas) window.activeCanvas.save(tempOut);

        // Wait 100ms for QML canvas save thread to finish writing
        Qt.callLater(() => {
            // Clipboard copy pipeline
            const copyCmd = "wl-copy < " + tempOut;
            Proc.runCommand("copy-capture-clipboard", ["sh", "-c", copyCmd], (stdout, exitCode) => {
                if (exitCode === 0) {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showInfo("Screenshot copied to clipboard.");
                    }
                    window.discardAndClose();
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to copy screenshot to clipboard. Install 'wl-clipboard'.");
                    }
                    window.discardAndClose();
                }
            }, 0, 5000);
        });
    }

    function performCopyAndSave() {
        // Save the merged canvas
        const tempOut = "/tmp/dms_capture_output.png";
        if (window.activeCanvas) window.activeCanvas.save(tempOut);

        // Wait 100ms for QML canvas save thread to finish writing
        Qt.callLater(() => {
            const hasParent = window.parentWidget && window.parentWidget.pluginData;
            
            // Clipboard copy pipeline
            const copyCmd = "wl-copy < " + tempOut;
            Proc.runCommand("copy-capture-clipboard", ["sh", "-c", copyCmd], (stdout, exitCode) => {
                if (exitCode === 0) {
                    const saveDir = hasParent ? (window.parentWidget.pluginData.saveDirectory || "~/Pictures/Screenshots") : "~/Pictures/Screenshots";
                    const cleanDir = saveDir.replace("~", "$HOME");
                    const filename = "Screenshot_" + Date.now() + ".png";
                    const saveCmd = "mkdir -p " + cleanDir + " && cp " + tempOut + " " + cleanDir + "/" + filename;
                    
                    Proc.runCommand("save-capture-file", ["sh", "-c", saveCmd], (saveOut, saveCode) => {
                        if (saveCode === 0) {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                    ToastService.showInfo("Screenshot copied to clipboard and saved to " + saveDir);
                            }
                        } else {
                            if (typeof ToastService !== "undefined" && ToastService) {
                                ToastService.showWarning("Screenshot copied to clipboard but failed to save file.");
                            }
                        }
                        window.discardAndClose();
                    }, 0, 5000);
                } else {
                    if (typeof ToastService !== "undefined" && ToastService) {
                        ToastService.showError("Failed to copy screenshot to clipboard. Install 'wl-clipboard'.");
                    }
                    window.discardAndClose();
                }
            }, 0, 5000);
        });
    }
}
