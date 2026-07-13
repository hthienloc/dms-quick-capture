import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

PanelWindow {
    id: window
    color: "transparent"
    
    signal closing()
    
    property string imageSource: ""
    property bool isPinned: true 
    property int initialWidth: 400
    
    // Settings from plugin
    property var pluginData: ({})
    readonly property bool autoMinimize: pluginData.autoMinimize ?? false
    readonly property int minimizeDelay: pluginData.minimizeDelay ?? 3000
    readonly property int borderWidth: pluginData.borderWidth ?? 2
    readonly property string borderColor: pluginData.borderColor ?? "outlineVariant"
    readonly property bool transparentBg: pluginData.transparentBg ?? true
    property string spawnPosition: "bottom-left"
    property int maxHeight: 0
    property var plugin: null
    property var annotationState: null
    property var tempPaths: []

    readonly property real edgeSpacing: pluginData.edgeSpacing ?? Appearance.spacing.normal

    onPluginDataChanged: {
        if (pluginData) {
            spawnPosition = pluginData.spawnPosition || "bottom-left";
            maxHeight = pluginData.maxHeight || 0;
            updateSize();
        }
    }
    
    property bool isMinimized: false
    property real targetWidth: initialWidth
    property real targetHeight: 1
    property bool imageLoaded: false
    property bool manuallyMoved: false
    property bool isTop: false

    onTargetWidthChanged: if (!manuallyMoved) updatePosition()
    onTargetHeightChanged: if (!manuallyMoved) updatePosition()

    // Position control
    property int xPos: 400
    property int yPos: 400

    anchors { top: true; left: true }
    WlrLayershell.namespace: "dms-quick-capture-float"
    WlrLayershell.layer: {
        if (window.isPinned) {
            return isTop ? WlrLayershell.Overlay : WlrLayershell.Top;
        }
        return isTop ? WlrLayershell.Bottom : WlrLayershell.Background;
    }
    WlrLayershell.exclusiveZone: -1
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    WlrLayershell.margins {
        left: xPos
        top: yPos
    }

    implicitWidth: isMinimized ? minimizedSize : targetWidth
    implicitHeight: isMinimized ? minimizedSize : targetHeight

    Timer {
        id: minimizeTimer
        interval: window.minimizeDelay
        repeat: false
        onTriggered: window.isMinimized = true
    }

    Component.onCompleted: {
        if (window.autoMinimize) {
            minimizeTimer.start();
        }
        updatePosition();
    }

    Connections {
        target: (typeof SettingsData !== "undefined") ? SettingsData : null
        ignoreUnknownSignals: true
        function onBarConfigsChanged() { updatePosition(); }
        function onDockEnabledChanged() { updatePosition(); }
        function onDockPositionChanged() { updatePosition(); }
    }

    function getWorkArea() {
        let area = {
            x: 0,
            y: 0,
            width: window.screen.width,
            height: window.screen.height
        };

        if (typeof SettingsData === "undefined") return area;

        // Handle Bars
        if (SettingsData.barConfigs) {
            SettingsData.barConfigs.forEach(cfg => {
                if (!cfg.enabled || !cfg.visible) return;
                
                let onThisScreen = false;
                if (!cfg.screenPreferences || cfg.screenPreferences.includes("all")) {
                    onThisScreen = true;
                } else {
                    onThisScreen = cfg.screenPreferences.includes(window.screen.name);
                }
                
                if (!onThisScreen) return;

                const innerPadding = cfg.innerPadding ?? 4;
                const spacing = cfg.spacing ?? 4;
                const bottomGap = (typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (cfg.bottomGap ?? 0);
                
                let thickness = 0;
                if (SettingsData.frameEnabled) {
                    thickness = SettingsData.frameBarSize;
                } else {
                    const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
                    const barHeight = typeof Theme !== "undefined" ? Theme.barHeight : 48;
                    const effectiveBarThickness = Math.max(widgetThickness + innerPadding + 4, barHeight - 4 - (8 - innerPadding));
                    thickness = effectiveBarThickness + spacing + bottomGap;
                }
                
                // Position: 0=Top, 1=Bottom, 2=Left, 3=Right
                switch (cfg.position) {
                    case 0: area.y += thickness; area.height -= thickness; break;
                    case 1: area.height -= thickness; break;
                    case 2: area.x += thickness; area.width -= thickness; break;
                    case 3: area.width -= thickness; break;
                }
            });
        }

        // Handle Dock
        if (SettingsData.dockEnabled) {
            // Check if dock is on this screen
            // DMS usually puts dock on the primary screen (first in Quickshell.screens)
            if (window.screen === Quickshell.screens[0]) {
                const iconSize = SettingsData.dockIconSize ?? 40;
                const spacing = SettingsData.dockSpacing ?? 4;
                const borderThickness = SettingsData.dockBorderEnabled ? (SettingsData.dockBorderThickness ?? 1) : 0;
                const bodyThickness = iconSize + spacing * 2 + borderThickness * 2;
                
                const reserveOffset = SettingsData.dockBottomGap ?? 0;
                const effectiveMargin = (typeof Theme !== "undefined" && Theme.isConnectedEffect) ? 0 : (SettingsData.dockMargin ?? 0);
                
                // We add a small buffer (8px) to avoid windows being exactly flush against the dock
                const dockThickness = bodyThickness + reserveOffset + effectiveMargin + 8;
                
                switch (SettingsData.dockPosition) {
                    case 0: area.y += dockThickness; area.height -= dockThickness; break; // Top
                    case 1: area.height -= dockThickness; break; // Bottom
                    case 2: area.x += dockThickness; area.width -= dockThickness; break; // Left
                    case 3: area.width -= dockThickness; break; // Right
                }
            }
        }

        return area;
    }

    function yPosForPosition(pos, winHeight, workArea) {
        switch (pos) {
            case "top": case "top-left": case "top-right": return workArea.y + edgeSpacing;
            case "bottom": case "bottom-left": case "bottom-right": return workArea.y + workArea.height - winHeight - edgeSpacing;
            default: return workArea.y + (workArea.height - winHeight) / 2;
        }
    }

    function xPosForPosition(pos, winWidth, workArea) {
        switch (pos) {
            case "left": case "top-left": case "bottom-left": return workArea.x + edgeSpacing;
            case "right": case "top-right": case "bottom-right": return workArea.x + workArea.width - winWidth - edgeSpacing;
            default: return workArea.x + (workArea.width - winWidth) / 2;
        }
    }

    readonly property int minimizedSize: pluginData.minimizedSize ?? 40
    readonly property int resizeMin: pluginData.resizeMin ?? 100
    readonly property int resizeMax: pluginData.resizeMax ?? 2000

    function close() {
        opacityToClose.start();
    }

    function updatePosition() {
        let workArea = getWorkArea();
        let newX = xPosForPosition(spawnPosition, targetWidth, workArea);
        let newY = yPosForPosition(spawnPosition, targetHeight, workArea);

        let autoTiling = true;
        if (plugin && plugin.pluginData && plugin.pluginData.autoTiling !== undefined) {
            autoTiling = plugin.pluginData.autoTiling;
        }

        if (autoTiling && !manuallyMoved && plugin && plugin.openWindows) {
            let currentWindows = plugin.openWindows;
            let attempts = 0;
            let maxAttempts = 50; 
            
            let overlapping = true;
            while (overlapping && attempts < maxAttempts) {
                overlapping = false;
                for (let i = 0; i < currentWindows.length; i++) {
                    let other = currentWindows[i];
                    if (!other || other === window || other.isMinimized) continue;
                    
                    let ox = other.xPos;
                    let oy = other.yPos;
                    let ow = other.targetWidth;
                    let oh = other.targetHeight;

                    // Standard AABB overlap check with padding
                    let isOverlapping = !(newX + targetWidth + edgeSpacing <= ox || 
                                          newX >= ox + ow + edgeSpacing ||
                                          newY + targetHeight + edgeSpacing <= oy ||
                                          newY >= oy + oh + edgeSpacing);
                    
                    if (isOverlapping) {
                        // Vertical stacking direction depends on whether we started at top or bottom
                        if (spawnPosition.includes("bottom")) {
                            // Stack UPWARDS
                            newY = oy - targetHeight - edgeSpacing;
                            
                            // If we hit the top, move to a new column
                            if (newY < workArea.y + edgeSpacing) {
                                newY = yPosForPosition(spawnPosition, targetHeight, workArea);
                                if (spawnPosition.includes("right")) newX = ox - targetWidth - edgeSpacing;
                                else newX = ox + ow + edgeSpacing;
                            }
                        } else {
                            // Stack DOWNWARDS (default for top or center)
                            newY = oy + oh + edgeSpacing;
                            
                            // If we hit the bottom, move to a new column
                            if (newY + targetHeight > workArea.y + workArea.height - edgeSpacing) {
                                newY = yPosForPosition(spawnPosition, targetHeight, workArea);
                                if (spawnPosition.includes("right")) newX = ox - targetWidth - edgeSpacing;
                                else newX = ox + ow + edgeSpacing;
                            }
                        }
                        overlapping = true;
                        break; 
                    }
                }
                attempts++;
            }
        }

        if (window.isMinimized) {
            let centerX = newX + targetWidth / 2;
            let centerY = newY + targetHeight / 2;
            if (centerX > window.screen.width / 2) newX += (targetWidth - minimizedSize);
            if (centerY > window.screen.height / 2) newY += (targetHeight - minimizedSize);
        }

        newX = Math.max(workArea.x + edgeSpacing, Math.min(workArea.x + workArea.width - targetWidth - edgeSpacing, newX));
        newY = Math.max(workArea.y + edgeSpacing, Math.min(workArea.y + workArea.height - targetHeight - edgeSpacing, newY));

        xPos = newX;
        yPos = newY;
    }

    function updateSize() {
        if (img.status !== Image.Ready) return;

        let iw = img.implicitWidth;
        let ih = img.implicitHeight;
        if (iw <= 0 || ih <= 0) return;

        let ratio = iw / ih;
        let b = window.borderWidth;
        
        // Calculate dimensions so the INNER area matches the aspect ratio
        let w = initialWidth;
        let h = ((w - 2 * b) / ratio) + 2 * b;

        if (maxHeight > 0 && h > maxHeight) {
            h = maxHeight;
            w = (h - 2 * b) * ratio + 2 * b;
        }

        // Use Math.round to avoid sub-pixel gaps that cause "black strips"
        targetWidth = Math.round(w);
        targetHeight = Math.round(h);
        
        if (!manuallyMoved) {
            updatePosition();
        }
    }

    // The Drag Engine
    Item {
        id: dragTarget
        x: window.xPos
        y: window.yPos
        onXChanged: { 
            if (dragArea.drag.active) {
                window.xPos = x;
                window.manuallyMoved = true;
            }
        }
        onYChanged: { 
            if (dragArea.drag.active) {
                window.yPos = y;
                window.manuallyMoved = true;
            }
        }
    }

    StyledRect {
        id: container
        anchors.fill: parent
        radius: Theme.cornerRadius
        color: window.transparentBg ? "transparent" : Theme.surfaceContainer
        border.color: window.borderColor === "primary" ? Theme.primary : 
                      window.borderColor === "surfaceContainerHighest" ? Theme.surfaceContainerHighest :
                      window.borderColor === "transparent" ? "transparent" : Theme.outlineVariant
        border.width: window.borderWidth
        clip: true
        antialiasing: true

        SequentialAnimation {
            id: opacityToClose
            NumberAnimation { target: container; property: "opacity"; to: 0; duration: 150; easing.type: Easing.OutCubic }
            ScriptAction { script: { window.closing(); window.destroy(); } }
        }

        // Image View - Fills container and aligns with border
        AnimatedImage {
            id: img
            source: window.imageSource
            anchors.fill: parent
            anchors.margins: window.borderWidth
            fillMode: Image.PreserveAspectFit
            paused: window.isMinimized
            antialiasing: true
            smooth: true
            opacity: window.imageLoaded ? 1 : 0
            visible: opacity > 0

            layer.enabled: true
            layer.effect: GE.OpacityMask {
                maskSource: Rectangle {
                    width: img.width
                    height: img.height
                    radius: Math.max(0, Theme.cornerRadius - window.borderWidth)
                    visible: false
                    antialiasing: true
                }
            }

            onStatusChanged: {
                if (status === AnimatedImage.Ready) {
                    updateSize();
                    window.imageLoaded = true;
                } else if (status === AnimatedImage.Error) {
                    ToastService.showError("Failed to load image: " + window.imageSource);
                    window.closing();
                    window.destroy();
                }
            }
        }

        // Minimized Icon
        DankIcon {
            id: cloudIcon
            name: "cloud"
            anchors.centerIn: parent
            size: Theme.iconSizeSmall
            color: Theme.onPrimary
            opacity: 0
            visible: opacity > 0
        }

        // Touchpad Pinch Support
        PinchHandler {
            id: pinchHandler
            target: null
            property real startWidth: 400
            onActiveChanged: {
                if (active) startWidth = window.targetWidth;
            }
            onScaleChanged: {
                if (img.implicitWidth <= 0 || img.implicitHeight <= 0) return;
                let b = window.borderWidth;
                let ratio = img.implicitWidth / img.implicitHeight;
                let newWidth = Math.max(window.resizeMin, Math.min(window.resizeMax, startWidth * scale));
                let newHeight = ((newWidth - 2 * b) / ratio) + 2 * b;

                window.targetWidth = Math.round(newWidth);
                window.targetHeight = Math.round(newHeight);
            }
        }

        // Interactions
        MouseArea {
            id: dragArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeAllCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

            drag.target: dragTarget
            drag.axis: Drag.XAndYAxis
            drag.threshold: 0

            onEntered: {
                minimizeTimer.stop();
                window.isMinimized = false;
            }

            onExited: {
                if (window.autoMinimize && !drag.active) {
                    minimizeTimer.restart();
                }
            }

            onPressed: function(mouse) {
                if (window.plugin && typeof window.plugin.raiseWindow === "function") {
                    window.plugin.raiseWindow(window);
                }
                if (mouse.button === Qt.RightButton) {
                    window.isMinimized = !window.isMinimized;
                } else if (mouse.button === Qt.MiddleButton) {
                    opacityToClose.start();
                }
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (window.plugin && typeof window.plugin.requestRestore === "function") {
                        window.plugin.requestRestore(window.imageSource);
                    }
                    window.close();
                }
            }

            onWheel: (wheel) => {
                if (window.isMinimized || img.implicitWidth <= 0 || img.implicitHeight <= 0) return;

                let scaleFactor = Math.pow(1.1, wheel.angleDelta.y / 120.0);
                let oldWidth = window.targetWidth;
                let oldHeight = window.targetHeight;
                let b = window.borderWidth;
                let ratio = img.implicitWidth / img.implicitHeight;
                let newWidth = Math.round(Math.max(window.resizeMin, Math.min(window.resizeMax, oldWidth * scaleFactor)));
                let newHeight = Math.round(((newWidth - 2 * b) / ratio) + 2 * b);

                // Directional resize logic:
                // We keep the corner closest to the screen edge fixed.
                let centerX = window.xPos + oldWidth / 2;
                let centerY = window.yPos + oldHeight / 2;
                let screenWidth = window.screen.width;
                let screenHeight = window.screen.height;

                // Adjust X: if center is in right half, keep right edge fixed (move x left)
                if (centerX > screenWidth / 2) {
                    window.xPos -= (newWidth - oldWidth);
                } 
                // else: center is in left half, keep left edge fixed (do nothing to x)

                // Adjust Y: if center is in bottom half, keep bottom edge fixed (move y up)
                if (centerY > screenHeight / 2) {
                    window.yPos -= (newHeight - oldHeight);
                }
                // else: center is in top half, keep top edge fixed (do nothing to y)

                window.targetWidth = newWidth;
                window.targetHeight = newHeight;
            }
        }

        // Move states and transitions here
        states: [
            State {
                name: "minimized"
                when: window.isMinimized
                PropertyChanges { target: container; radius: minimizedSize / 2; color: Theme.primary; border.width: 0; opacity: 0.5 }
                PropertyChanges { target: img; opacity: 0 }
                PropertyChanges { target: cloudIcon; opacity: 1 }
            }
        ]

        transitions: [
            Transition {
                from: ""; to: "minimized"
                SequentialAnimation {
                    NumberAnimation {
                        target: container
                        property: "opacity"
                        to: 0
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                    ScriptAction {
                        script: {
                            let oldWidth = window.targetWidth;
                            let oldHeight = window.targetHeight;
                            let centerX = window.xPos + oldWidth / 2;
                            let centerY = window.yPos + oldHeight / 2;
                            let screenWidth = window.screen.width;
                            let screenHeight = window.screen.height;

                            if (centerX > screenWidth / 2) window.xPos += (oldWidth - minimizedSize);
                            if (centerY > screenHeight / 2) window.yPos += (oldHeight - minimizedSize);
                        }
                    }
                    PropertyAction { 
                        target: container
                        properties: "radius,color,border.width"
                    }
                    PropertyAction { 
                        targets: [img, cloudIcon]
                        properties: "opacity"
                    }
                    NumberAnimation {
                        target: container
                        property: "opacity"
                        from: 0
                        to: 0.5
                        duration: 80
                        easing.type: Easing.InQuad
                    }
                }
            },
            Transition {
                from: "minimized"; to: ""
                SequentialAnimation {
                    NumberAnimation {
                        target: container
                        property: "opacity"
                        to: 0
                        duration: 70
                        easing.type: Easing.OutQuad
                    }
                    ScriptAction {
                        script: {
                            let oldWidth = window.targetWidth;
                            let oldHeight = window.targetHeight;
                            let centerX = window.xPos + minimizedSize / 2;
                            let centerY = window.yPos + minimizedSize / 2;
                            let screenWidth = window.screen.width;
                            let screenHeight = window.screen.height;

                            if (centerX > screenWidth / 2) window.xPos -= (oldWidth - minimizedSize);
                            if (centerY > screenHeight / 2) window.yPos -= (oldHeight - minimizedSize);
                        }
                    }
                    PropertyAction { 
                        target: container
                        properties: "radius,color,border.width"
                    }
                    PropertyAction { 
                        targets: [img, cloudIcon]
                        properties: "opacity"
                    }
                    NumberAnimation {
                        target: container
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 80
                        easing.type: Easing.InQuad
                    }
                }
            }
        ]
    }
}
