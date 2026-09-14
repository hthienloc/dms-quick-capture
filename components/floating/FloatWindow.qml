import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets
import "../core/Helpers.js" as Helpers
import "../core/Defaults.js" as Defaults

PanelWindow {
    id: window
    color: "transparent"

    signal closing

    property string imageSource: ""
    property bool isPinned: true
    property var plugin: null
    property var annotationState: null
    property var tempPaths: []

    readonly property var pluginData: plugin?.pluginData ?? ({})
    readonly property int effectiveInitialWidth: Defaults.get(pluginData, "initialWidth")
    readonly property bool autoMinimize: Defaults.get(pluginData, "autoMinimize")
    readonly property int minimizeDelay: Defaults.get(pluginData, "minimizeDelay")
    readonly property int borderWidth: Defaults.get(pluginData, "borderWidth")
    readonly property string borderColor: Defaults.get(pluginData, "borderColor")
    readonly property bool transparentBg: Defaults.get(pluginData, "transparentBg")
    readonly property string spawnPosition: Defaults.get(pluginData, "spawnPosition")
    readonly property int maxHeight: Defaults.get(pluginData, "maxHeight")
    readonly property real edgeSpacing: Defaults.get(pluginData, "edgeSpacing")
    readonly property bool autoTiling: Defaults.get(pluginData, "autoTiling")
    readonly property int minimizedSize: Defaults.get(pluginData, "minimizedSize")
    readonly property int resizeMin: Defaults.get(pluginData, "resizeMin")
    readonly property int resizeMax: Defaults.get(pluginData, "resizeMax")

    onSpawnPositionChanged: updateSize()
    onMaxHeightChanged: updateSize()

    property bool isMinimized: false
    property real targetWidth: effectiveInitialWidth
    property real targetHeight: 1
    property bool imageLoaded: false
    property bool manuallyMoved: false
    property bool isTop: false
    property bool isScaling: false
    property bool temporarilyHidden: false
    visible: !temporarilyHidden

    onTargetWidthChanged: if (!manuallyMoved)
        updatePosition()
    onTargetHeightChanged: if (!manuallyMoved)
        updatePosition()

    property int xPos: 400
    property int yPos: 400

    anchors {
        top: true
        left: true
    }
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

    Timer {
        id: scaleTimer
        interval: 200
        repeat: false
        onTriggered: window.isScaling = false
    }

    Behavior on targetWidth {
        enabled: window.isScaling
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    Behavior on targetHeight {
        enabled: window.isScaling
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    Behavior on xPos {
        enabled: window.isScaling
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }
    Behavior on yPos {
        enabled: window.isScaling
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
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
        target: SettingsData
        function onBarConfigsChanged() {
            updatePosition();
        }
        function onDockEnabledChanged() {
            updatePosition();
        }
        function onDockPositionChanged() {
            updatePosition();
        }
    }

    function getWorkArea() {
        let area = {
            x: 0,
            y: 0,
            width: window.screen.width,
            height: window.screen.height
        };

        if (SettingsData.barConfigs) {
            SettingsData.barConfigs.forEach(cfg => {
                if (!cfg.enabled || !cfg.visible)
                    return;

                let onThisScreen = false;
                if (!cfg.screenPreferences || cfg.screenPreferences.includes("all")) {
                    onThisScreen = true;
                } else {
                    onThisScreen = cfg.screenPreferences.includes(window.screen.name);
                }

                if (!onThisScreen)
                    return;

                const innerPadding = cfg.innerPadding ?? 4;
                const spacing = cfg.spacing ?? 4;
                const bottomGap = Theme.isConnectedEffect ? 0 : (cfg.bottomGap ?? 0);

                let thickness = 0;
                if (SettingsData.frameEnabled) {
                    thickness = SettingsData.frameBarSize;
                } else {
                    const widgetThickness = Math.max(20, 26 + innerPadding * 0.6);
                    const barHeight = Theme.barHeight;
                    const effectiveBarThickness = Math.max(widgetThickness + innerPadding + 4, barHeight - 4 - (8 - innerPadding));
                    thickness = effectiveBarThickness + spacing + bottomGap;
                }

                switch (cfg.position) {
                case 0:
                    area.y += thickness;
                    area.height -= thickness;
                    break;
                case 1:
                    area.height -= thickness;
                    break;
                case 2:
                    area.x += thickness;
                    area.width -= thickness;
                    break;
                case 3:
                    area.width -= thickness;
                    break;
                }
            });
        }

        if (SettingsData.dockEnabled) {
            if (window.screen === Quickshell.screens[0]) {
                const iconSize = SettingsData.dockIconSize ?? 40;
                const spacing = SettingsData.dockSpacing ?? 4;
                const borderThickness = SettingsData.dockBorderEnabled ? (SettingsData.dockBorderThickness ?? 1) : 0;
                const bodyThickness = iconSize + spacing * 2 + borderThickness * 2;

                const reserveOffset = SettingsData.dockBottomGap ?? 0;
                const effectiveMargin = Theme.isConnectedEffect ? 0 : (SettingsData.dockMargin ?? 0);

                const dockThickness = bodyThickness + reserveOffset + effectiveMargin + 8;

                switch (SettingsData.dockPosition) {
                case 0:
                    area.y += dockThickness;
                    area.height -= dockThickness;
                    break;
                case 1:
                    area.height -= dockThickness;
                    break;
                case 2:
                    area.x += dockThickness;
                    area.width -= dockThickness;
                    break;
                case 3:
                    area.width -= dockThickness;
                    break;
                }
            }
        }

        return area;
    }

    function yPosForPosition(pos, winHeight, workArea) {
        switch (pos) {
        case "top":
        case "top-left":
        case "top-right":
            return workArea.y + edgeSpacing;
        case "bottom":
        case "bottom-left":
        case "bottom-right":
            return workArea.y + workArea.height - winHeight - edgeSpacing;
        default:
            return workArea.y + (workArea.height - winHeight) / 2;
        }
    }

    function xPosForPosition(pos, winWidth, workArea) {
        switch (pos) {
        case "left":
        case "top-left":
        case "bottom-left":
            return workArea.x + edgeSpacing;
        case "right":
        case "top-right":
        case "bottom-right":
            return workArea.x + workArea.width - winWidth - edgeSpacing;
        default:
            return workArea.x + (workArea.width - winWidth) / 2;
        }
    }

    function close() {
        opacityToClose.start();
    }

    function updatePosition() {
        let workArea = getWorkArea();
        let newX = xPosForPosition(spawnPosition, targetWidth, workArea);
        let newY = yPosForPosition(spawnPosition, targetHeight, workArea);

        if (autoTiling && !manuallyMoved && plugin && plugin.openWindows) {
            let currentWindows = plugin.openWindows;
            let attempts = 0;
            let maxAttempts = 50;

            let overlapping = true;
            while (overlapping && attempts < maxAttempts) {
                overlapping = false;
                for (let i = 0; i < currentWindows.length; i++) {
                    let other = currentWindows[i];
                    if (!other || other === window || other.isMinimized)
                        continue;

                    let ox = other.xPos;
                    let oy = other.yPos;
                    let ow = other.targetWidth;
                    let oh = other.targetHeight;

                    let isOverlapping = !(newX + targetWidth + edgeSpacing <= ox || newX >= ox + ow + edgeSpacing || newY + targetHeight + edgeSpacing <= oy || newY >= oy + oh + edgeSpacing);

                    if (isOverlapping) {
                        // Vertical stacking direction depends on whether we started at top or bottom
                        if (spawnPosition.includes("bottom")) {
                            newY = oy - targetHeight - edgeSpacing;

                            if (newY < workArea.y + edgeSpacing) {
                                newY = yPosForPosition(spawnPosition, targetHeight, workArea);
                                if (spawnPosition.includes("right"))
                                    newX = ox - targetWidth - edgeSpacing;
                                else
                                    newX = ox + ow + edgeSpacing;
                            }
                        } else {
                            newY = oy + oh + edgeSpacing;

                            if (newY + targetHeight > workArea.y + workArea.height - edgeSpacing) {
                                newY = yPosForPosition(spawnPosition, targetHeight, workArea);
                                if (spawnPosition.includes("right"))
                                    newX = ox - targetWidth - edgeSpacing;
                                else
                                    newX = ox + ow + edgeSpacing;
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
            if (centerX > window.screen.width / 2)
                newX += (targetWidth - minimizedSize);
            if (centerY > window.screen.height / 2)
                newY += (targetHeight - minimizedSize);
        }

        newX = Helpers.clamp(newX, workArea.x + edgeSpacing, workArea.x + workArea.width - targetWidth - edgeSpacing);
        newY = Helpers.clamp(newY, workArea.y + edgeSpacing, workArea.y + workArea.height - targetHeight - edgeSpacing);

        xPos = newX;
        yPos = newY;
    }

    function updateSize() {
        if (img.status !== Image.Ready)
            return;

        let iw = img.implicitWidth;
        let ih = img.implicitHeight;
        if (iw <= 0 || ih <= 0)
            return;

        let ratio = iw / ih;
        let b = window.borderWidth;

        let w = effectiveInitialWidth;
        let h = ((w - 2 * b) / ratio) + 2 * b;

        if (maxHeight > 0 && h > maxHeight) {
            h = maxHeight;
            w = (h - 2 * b) * ratio + 2 * b;
        }

        targetWidth = Math.round(w);
        targetHeight = Math.round(h);

        if (!manuallyMoved) {
            updatePosition();
        }
    }

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
        border.color: {
            switch (window.borderColor) {
            case "primary":
                return Theme.primary;
            case "surfaceContainerHighest":
                return Theme.surfaceContainerHighest;
            case "transparent":
                return "transparent";
            default:
                return Theme.outlineVariant;
            }
        }
        border.width: window.borderWidth
        clip: true
        antialiasing: true

        SequentialAnimation {
            id: opacityToClose
            NumberAnimation {
                target: container
                property: "opacity"
                to: 0
                duration: 150
                easing.type: Easing.OutCubic
            }
            ScriptAction {
                script: {
                    window.closing();
                    window.destroy();
                }
            }
        }

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
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: imgMask
            }

            onStatusChanged: {
                if (status === AnimatedImage.Ready) {
                    updateSize();
                    window.imageLoaded = true;
                } else if (status === AnimatedImage.Error) {
                    ToastService.showError(I18n.trFor("quickCapture", "Failed to load image: %1").arg(window.imageSource));
                    window.closing();
                    window.destroy();
                }
            }
        }

        Rectangle {
            id: imgMask
            anchors.fill: img
            radius: Math.max(0, Theme.cornerRadius - window.borderWidth)
            visible: false
            antialiasing: true
            layer.enabled: true
        }

        DankIcon {
            id: cloudIcon
            name: "cloud"
            anchors.centerIn: parent
            size: Theme.iconSizeSmall
            color: Theme.onPrimary
            opacity: 0
            visible: opacity > 0
        }

        PinchHandler {
            id: pinchHandler
            target: null
            property real startWidth: 400
            onActiveChanged: {
                if (active)
                    startWidth = window.targetWidth;
            }
            onScaleChanged: {
                if (img.implicitWidth <= 0 || img.implicitHeight <= 0)
                    return;
                let b = window.borderWidth;
                let ratio = img.implicitWidth / img.implicitHeight;
                let newWidth = Helpers.clamp(startWidth * scale, window.resizeMin, window.resizeMax);
                let newHeight = ((newWidth - 2 * b) / ratio) + 2 * b;

                window.targetWidth = Math.round(newWidth);
                window.targetHeight = Math.round(newHeight);
            }
        }

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

            onPressed: function (mouse) {
                if (window.plugin && typeof window.plugin.raiseWindow === "function") {
                    window.plugin.raiseWindow(window);
                }
                if (mouse.button === Qt.RightButton) {
                    window.isMinimized = !window.isMinimized;
                } else if (mouse.button === Qt.MiddleButton) {
                    opacityToClose.start();
                }
            }

            onClicked: function (mouse) {
                if (mouse.button === Qt.LeftButton) {
                    if (window.plugin && typeof window.plugin.requestRestore === "function") {
                        window.plugin.requestRestore(window.imageSource);
                    }
                    window.close();
                }
            }

            onWheel: wheel => {
                if (window.isMinimized || img.implicitWidth <= 0 || img.implicitHeight <= 0)
                    return;

                window.isScaling = true;
                scaleTimer.restart();

                let scaleFactor = Math.pow(1.1, wheel.angleDelta.y / 120.0);
                let oldWidth = window.targetWidth;
                let oldHeight = window.targetHeight;
                let b = window.borderWidth;
                let ratio = img.implicitWidth / img.implicitHeight;
                let newWidth = Math.round(Helpers.clamp(oldWidth * scaleFactor, window.resizeMin, window.resizeMax));
                let newHeight = Math.round(((newWidth - 2 * b) / ratio) + 2 * b);

                let centerX = window.xPos + oldWidth / 2;
                let centerY = window.yPos + oldHeight / 2;
                let screenWidth = window.screen.width;
                let screenHeight = window.screen.height;

                if (centerX > screenWidth / 2) {
                    window.xPos -= (newWidth - oldWidth);
                }

                if (centerY > screenHeight / 2) {
                    window.yPos -= (newHeight - oldHeight);
                }

                window.targetWidth = newWidth;
                window.targetHeight = newHeight;
                window.manuallyMoved = true;
            }
        }

        states: [
            State {
                name: "minimized"
                when: window.isMinimized
                PropertyChanges {
                    target: container
                    radius: minimizedSize / 2
                    color: Theme.primary
                    border.width: 0
                    opacity: 0.5
                }
                PropertyChanges {
                    target: img
                    opacity: 0
                }
                PropertyChanges {
                    target: cloudIcon
                    opacity: 1
                }
            }
        ]

        transitions: [
            Transition {
                from: ""
                to: "minimized"
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

                            if (centerX > screenWidth / 2)
                                window.xPos += (oldWidth - minimizedSize);
                            if (centerY > screenHeight / 2)
                                window.yPos += (oldHeight - minimizedSize);
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
                from: "minimized"
                to: ""
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

                            if (centerX > screenWidth / 2)
                                window.xPos -= (oldWidth - minimizedSize);
                            if (centerY > screenHeight / 2)
                                window.yPos -= (oldHeight - minimizedSize);
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
