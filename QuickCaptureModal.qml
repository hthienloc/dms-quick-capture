import QtQuick
import QtQuick.Controls
import QtQuick.Effects
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
    property string currentTool: "crop" // crop, pen, highlighter, rect, arrow, text, stamp, eraser
    property string currentColor: "#3b82f6" // Default to Tailwind Blue-500
    property int strokeWidth: 8
    property int stampCounter: 1
    property bool isScreenshotDark: false
    property bool hasSampledContrast: false
    property real previewX: 0
    property real previewY: 0
    property bool showSizePreview: false

    property var strokes: []
    property var currentStroke: null
    property var selectedStroke: null
    property point pressCoords: Qt.point(0, 0)
    property var originalPoints: []

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
    property var exportCanvasItem: null

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
    property string activeHandle: "none" // "tl", "tr", "bl", "br", "new", "none"
    property point selectStart: Qt.point(0, 0)
    property var exportCallback: null

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
            } else if (stroke.tool === "arrow") {
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
        window.exportCallback = callback;
        if (!window.exportCanvasItem) {
            console.warn("exportCanvasItem is not initialized yet");
            return;
        }
        if (window.hasSelection) {
            window.exportCanvasItem.width = window.cropRect.width;
            window.exportCanvasItem.height = window.cropRect.height;
        } else if (window.activeCanvas) {
            window.exportCanvasItem.width = window.activeCanvas.width;
            window.exportCanvasItem.height = window.activeCanvas.height;
        }
        window.exportCanvasItem.requestPaint();
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
        } else if (event.key === Qt.Key_Q) {
            window.currentTool = "select";
            event.accepted = true;
        } else if (event.key === Qt.Key_W) {
            window.currentTool = "pen";
            event.accepted = true;
        } else if (event.key === Qt.Key_E) {
            window.currentTool = "arrow";
            event.accepted = true;
        } else if (event.key === Qt.Key_R) {
            window.currentTool = "rect";
            event.accepted = true;
        } else if (event.key === Qt.Key_A) {
            window.currentTool = "text";
            event.accepted = true;
        } else if (event.key === Qt.Key_S) {
            window.currentTool = "pixelate";
            event.accepted = true;
        } else if (event.key === Qt.Key_D) {
            window.currentTool = "redact";
            event.accepted = true;
        } else if (event.key === Qt.Key_F) {
            window.currentTool = "stamp";
            event.accepted = true;
        } else if (event.key === Qt.Key_1) {
            window.currentTool = "highlighter";
            event.accepted = true;
        } else if (event.key === Qt.Key_2) {
            window.currentTool = "eraser";
            event.accepted = true;
        } else if (event.key === Qt.Key_3) {
            window.currentTool = "crop";
            event.accepted = true;
        }
    }

    onOpened: {
        window.currentTool = "crop";
        // Read initial settings from pluginData if available
        if (window.parentWidget && window.parentWidget.pluginData) {
            window.strokeWidth = window.parentWidget.pluginData.defaultThickness || 8;
        }
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
                    }
                }
            }

            Item {
                id: mainLayout
                anchors.fill: parent

                // 1. Top Glassmorphic Toolbar
                Rectangle {
                    id: toolbarCard
                    width: Math.min(parent.width - 32, 1100)
                    height: 52
                    radius: Theme.cornerRadius
                    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
                    border.color: Theme.withAlpha(Theme.outline, 0.15)
                    border.width: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Theme.spacingM
                    z: 100

                    // Left group: editing tools
                    Row {
                        id: leftGroup
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.spacingM

                        // Select & Move Button
                        DankActionButton {
                            iconName: "near_me"
                            buttonSize: 36
                            iconSize: 18
                            tooltipText: "Select & Move (Q)"
                            anchors.verticalCenter: parent.verticalCenter

                            backgroundColor: window.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: window.currentTool === "select" ? Theme.primary : Theme.surfaceText

                            onClicked: {
                                window.currentTool = "select";
                            }
                        }

                        // Separator between Select and other tools
                        Rectangle {
                            width: 1
                            height: 24
                            color: Theme.withAlpha(Theme.outline, 0.2)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Tool buttons
                        Row {
                            spacing: Theme.spacingXS
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: [
                                    { id: "pen", icon: "edit", tooltip: "Freehand Pen (W)" },
                                    { id: "arrow", icon: "trending_flat", tooltip: "Arrow Vector (E)" },
                                    { id: "rect", icon: "crop_square", tooltip: "Rectangle Outline (R)" },
                                    { id: "text", icon: "text_fields", tooltip: "Text Note (A)" },
                                    { id: "pixelate", icon: "blur_on", tooltip: "Pixelate / Blur (S)" },
                                    { id: "redact", icon: "square", tooltip: "Redact / Blackout (D)" },
                                    { id: "stamp", icon: "looks_one", tooltip: "Number Stamp (F)" },
                                    { id: "highlighter", icon: "border_color", tooltip: "Highlighter (1)" },
                                    { id: "eraser", icon: "auto_fix_normal", tooltip: "Eraser (2)" },
                                    { id: "crop", icon: "crop", tooltip: "Crop / Resize Area (3)" }
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
                    anchors.top: toolbarCard.bottom
                    anchors.topMargin: Theme.spacingM
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: Theme.spacingM
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spacingM
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spacingM

                    Component.onCompleted: {
                        window.boardContainerItem = boardContainer;
                    }

                    Rectangle {
                        anchors.fill: parent
                        color: "transparent"
                        border.width: 0
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

                            // 1. Draw the screenshot background first
                            if (window.bgImageItem && window.bgImageItem.status === Image.Ready) {
                                if (window.currentTool !== "crop" && window.hasSelection) {
                                    // Draw only the cropped portion
                                    ctx.drawImage(window.bgImageItem, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.cropRect.width, window.cropRect.height);
                                } else {
                                    // Draw full screen background
                                    ctx.drawImage(window.bgImageItem, 0, 0, drawingCanvas.width, drawingCanvas.height);

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
                            }

                            // 1.5. Draw Dimming Selection Overlay
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
                                    ctx.fillStyle = "rgba(0, 0, 0, 0.25)";
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

                            for (var i = 0; i < window.strokes.length; i++) {
                                drawStroke(ctx, window.strokes[i]);
                            }

                            // 3. Draw current dragging stroke
                            if (window.currentStroke) {
                                drawStroke(ctx, window.currentStroke);
                            }

                            ctx.restore();
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
                                const rx = Math.min(p0.x, p1.x);
                                const ry = Math.min(p0.y, p1.y);
                                const rw = Math.abs(p1.x - p0.x);
                                const rh = Math.abs(p1.y - p0.y);
                                const radius = Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2);

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
                                const radius = Math.min(Theme.cornerRadius, Math.min(rw, rh) / 2);

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
                                        ctx.imageSmoothingEnabled = false;

                                        // Pixelate block size factor (minimum 4px for visible block effect)
                                        const factor = Math.max(4, stroke.width);
                                        const tempW = Math.max(1, Math.round(rw / factor));
                                        const tempH = Math.max(1, Math.round(rh / factor));

                                        if (window.bgImageItem && window.bgImageItem.status === Image.Ready) {
                                            // 1. Draw cropped background downscaled onto a tiny region of the canvas
                                            ctx.drawImage(window.bgImageItem, rx, ry, rw, rh, rx, ry, tempW, tempH);
                                            // 2. Draw that downscaled canvas region scaled back up to the full bounding box
                                            ctx.drawImage(drawingCanvas, rx, ry, tempW, tempH, rx, ry, rw, rh);
                                        }

                                        // 3. Draw dynamic selection dashed outline if it is the active dragging stroke
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
                            hoverEnabled: true

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

                                    if (window.currentTool === "pen" || window.currentTool === "highlighter") {
                                        if (mouse.modifiers & Qt.ShiftModifier) {
                                            if (window.currentStroke.points.length > 1) {
                                                window.currentStroke.points = [window.currentStroke.points[0], absPt];
                                            } else {
                                                window.currentStroke.points.push(absPt);
                                            }
                                        } else {
                                            window.currentStroke.points.push(absPt);
                                        }
                                    } else if (window.currentTool === "rect" || window.currentTool === "arrow"
                                             || window.currentTool === "redact" || window.currentTool === "pixelate") {
                                        if (window.currentStroke.points.length > 1) {
                                            window.currentStroke.points[window.currentStroke.points.length - 1] = absPt;
                                        } else {
                                            window.currentStroke.points.push(absPt);
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
                                    textInputField.completeTextEntry();
                                    return;
                                }

                                const absPt = getAbsolutePoint(mouse.x, mouse.y);

                                if (window.currentTool === "select") {
                                    const strokeIdx = window.findStrokeAt(absPt.x, absPt.y);
                                    if (strokeIdx !== -1) {
                                        const stroke = window.strokes[strokeIdx];
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
                                        window.strokes.splice(found, 1);
                                        drawingCanvas.requestPaint();
                                    }
                                    return;
                                }

                                // Standard drawing stroke
                                window.currentStroke = {
                                    tool: window.currentTool,
                                    color: window.currentColor,
                                    width: window.strokeWidth,
                                    points: [getAbsolutePoint(mouse.x, mouse.y)]
                                };
                                drawingCanvas.requestPaint();
                            }

                            onReleased: (mouse) => {
                                if (window.currentTool === "select") {
                                    window.selectedStroke = null;
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
                                        points: [Qt.point(window.typingCoords.x, window.typingCoords.y)],
                                        text: textStr
                                    });
                                }
                                textInputField.text = "";
                                textInputField.visible = false;
                                window.isTyping = false;
                                window.forceActiveFocus();
                            }
                        }

                        Rectangle {
                            id: sizePreviewItem
                            visible: window.showSizePreview
                            x: window.previewX - (width / 2)
                            y: window.previewY - (height / 2)
                            width: {
                                if (window.currentTool === "highlighter") return window.strokeWidth * 4;
                                if (window.currentTool === "stamp") return window.strokeWidth * 10;
                                return window.strokeWidth;
                            }
                            height: width
                            radius: (window.currentTool === "highlighter" || window.currentTool === "pixelate") ? 0 : width / 2
                            color: "transparent"
                            border.color: Theme.primary
                            border.width: 1.5
                            z: 20
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
                        radius: Theme.cornerRadius
                        z: 10
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
                        
                        if (window.hasSelection && window.activeCanvas) {
                            if (window.activeCanvas.width === window.cropRect.width && window.activeCanvas.height === window.cropRect.height) {
                                // Already cropped! Draw it directly from 0,0
                                ctx.drawImage(window.activeCanvas, 0, 0);
                            } else {
                                // Fullscreen, draw the cropped area
                                ctx.drawImage(window.activeCanvas, window.cropRect.x, window.cropRect.y, window.cropRect.width, window.cropRect.height, 0, 0, window.cropRect.width, window.cropRect.height);
                            }
                        } else if (window.activeCanvas) {
                            ctx.drawImage(window.activeCanvas, 0, 0);
                        }

                        const tempOut = "/tmp/dms_capture_output.png";
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
        window.exportAndExecute((tempOut) => {
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
        window.exportAndExecute((tempOut) => {
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
        window.exportAndExecute((tempOut) => {
            const copyCmd = "wl-copy < " + tempOut;
            Proc.runCommand("copy-capture-clipboard", ["sh", "-c", copyCmd], (stdout, exitCode) => {
                if (exitCode === 0) {
                    const hasParent = window.parentWidget && window.parentWidget.pluginData;
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
