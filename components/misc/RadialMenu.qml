import QtQuick
import qs.Common
import qs.Widgets
import "../.."

Item {
    id: root
    z: 1000

    CaptureConfig { id: config }
    property var presets: []
    property int selectedIndex: -1
    
    // Hover Trigger Config
    property bool hoverTrigger: true
    property int hoverDelay: 200
    property real menuOpacity: 1.0
    
    // Premium geometry config
    readonly property real outerRadius: 130
    readonly property real innerRadius: 50
    readonly property real centerRadius: 44
    readonly property real midRadius: (innerRadius + outerRadius) / 2
    readonly property real itemRadius: 28

    signal presetSelected(var preset)
    signal centerClicked()

    property bool visibleState: false
    visible: opacity > 0
    opacity: 0
    scale: 0.8

    states: [
        State {
            name: "visible"
            when: root.visibleState
            PropertyChanges { target: root; opacity: root.menuOpacity; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 150; easing.type: Easing.OutQuad }
        }
    ]

    property bool hasDragged: false

    function open(x, y) {
        root.x = x - width / 2;
        root.y = y - height / 2;
        root.visibleState = true;
        selectedIndex = -1;
        hasDragged = false;
    }

    function close() {
        root.visibleState = false;
    }

    function updateHoverPosition(parentX, parentY) {
        if (!visibleState) return;
        const localX = parentX - root.x;
        const localY = parentY - root.y;

        const dx = localX - width / 2;
        const dy = localY - height / 2;
        const dist = Math.sqrt(dx * dx + dy * dy);

        if (dist >= 12) {
            hasDragged = true;
        }

        if (dist < root.innerRadius) {
            root.selectedIndex = -1;
            return;
        }

        let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
        if (angle < 0) angle += 360;

        const numSectors = root.presets.length || 8;
        const sectorSize = 360 / numSectors;
        const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);

        if (idx >= 0 && idx < numSectors) {
            root.selectedIndex = idx;
        }
    }

    function confirmAndClose(isRelease) {
        if (!visibleState) return;
        if (isRelease && !hasDragged) {
            // Single right-click tap: keep menu open on screen
            return;
        }
        if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
            root.presetSelected(root.presets[root.selectedIndex]);
        }
        root.close();
    }

    width: outerRadius * 2
    height: width

    onSelectedIndexChanged: {
        radialCanvas.requestPaint();
        if (root.hoverTrigger) {
            hoverTimer.stop();
            if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                hoverTimer.start();
            }
        }
    }
    
    onPresetsChanged: radialCanvas.requestPaint()

    onVisibleStateChanged: {
        if (!visibleState) {
            hoverTimer.stop();
        }
    }

    Timer {
        id: hoverTimer
        interval: root.hoverDelay
        repeat: false
        onTriggered: {
            if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                root.presetSelected(root.presets[root.selectedIndex]);
                root.close();
            }
        }
    }

    // Premium Segmented Background Canvas
    Canvas {
        id: radialCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var centerX = width / 2;
            var centerY = height / 2;
            var numSectors = root.presets.length || 8;
            var sectorAngle = 2 * Math.PI / numSectors;

            // Draw sectors
            for (var i = 0; i < numSectors; i++) {
                // Adjust by -90 deg (Math.PI/2) to start from the top
                var startAngle = i * sectorAngle - Math.PI / 2 - sectorAngle / 2;
                var endAngle = startAngle + sectorAngle;

                ctx.beginPath();
                ctx.arc(centerX, centerY, root.outerRadius, startAngle, endAngle);
                ctx.arc(centerX, centerY, root.innerRadius, endAngle, startAngle, true);
                ctx.closePath();

                // Highlight sector if hovered
                if (root.selectedIndex === i) {
                    var preset = root.presets[i];
                    ctx.fillStyle = (preset && preset.color) ? preset.color : Theme.primary;
                } else {
                    ctx.fillStyle = Theme.surfaceContainerHigh;
                }
                ctx.fill();

                // Draw delicate border lines between sectors
                var isSelected = root.selectedIndex === i;
                ctx.strokeStyle = isSelected ? Theme.onPrimary : Theme.withAlpha(Theme.outline, 0.15);
                ctx.lineWidth = isSelected ? 2.5 : 1;
                ctx.stroke();
            }
        }
    }

    // Floating Ring Outline
    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: Theme.withAlpha(Theme.outline, 0.25)
        border.width: 1.5
    }

    // Outer icons overlay
    Repeater {
        model: root.presets

        delegate: Item {
            width: root.itemRadius * 2
            height: width
            
            property real angle: (index * 360 / root.presets.length) - 90
            property real rad: angle * Math.PI / 180
            
            x: (root.width / 2) + root.midRadius * Math.cos(rad) - root.itemRadius
            y: (root.height / 2) + root.midRadius * Math.sin(rad) - root.itemRadius

            Column {
                anchors.centerIn: parent
                spacing: 1

                StyledText {
                    text: (index + 1)
                    font.pixelSize: 8
                    font.bold: true
                    color: root.selectedIndex === index ? Theme.onPrimary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.6
                }

                DankIcon {
                    name: {
                        return config.getToolIcon(modelData.tool);
                    }
                    size: 22
                    color: root.selectedIndex === index ? Theme.onPrimary : modelData.color
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Premium Center Select/Confirm Button
    Rectangle {
        id: centerButton
        width: root.centerRadius * 2
        height: width
        radius: root.centerRadius
        anchors.centerIn: parent

        // Glow matching Matugen primary / preset color
        color: {
            if (root.selectedIndex === -2) return Theme.withAlpha(Theme.primary, 0.12);
            if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                var p = root.presets[root.selectedIndex];
                return p && p.color ? Theme.withAlpha(p.color, 0.15) : Theme.withAlpha(Theme.primary, 0.15);
            }
            return Theme.surfaceContainerHighest;
        }
        border.color: {
            if (root.selectedIndex === -2) return Theme.primary;
            if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                var p = root.presets[root.selectedIndex];
                return p && p.color ? p.color : Theme.primary;
            }
            return Theme.withAlpha(Theme.outline, 0.4);
        }
        border.width: (root.selectedIndex >= 0 || root.selectedIndex === -2) ? 2.5 : 1

        scale: root.selectedIndex === -2 ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
        Behavior on border.width { NumberAnimation { duration: 100 } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            
            DankIcon {
                name: {
                    if (root.selectedIndex === -2) return "near_me";
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                        return config.getToolIcon(root.presets[root.selectedIndex].tool);
                    }
                    return "near_me"; // default idle center icon
                }
                size: 24
                color: {
                    if (root.selectedIndex === -2) return Theme.primary;
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                        return root.presets[root.selectedIndex].color;
                    }
                    return Theme.surfaceVariantText;
                }
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: {
                    if (root.selectedIndex === -2) return I18n.trFor("quickCapture", "Select");
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                        return config.getToolLabel(root.presets[root.selectedIndex].tool);
                    }
                    return I18n.trFor("quickCapture", "Select");
                }
                font.pixelSize: 8
                font.bold: true
                color: root.selectedIndex === -2 ? Theme.primary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text !== ""
            }
        }
    }

    // Unified Mouse Area for Premium Tracking
    MouseArea {
        id: radialMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: (mouse) => {
            root.updateHoverPosition(root.x + mouse.x, root.y + mouse.y);
        }

        onReleased: (mouse) => {
            root.confirmAndClose(false);
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.close();
            } else if (mouse.button === Qt.LeftButton) {
                const dx = mouse.x - width / 2;
                const dy = mouse.y - height / 2;
                const dist = Math.sqrt(dx * dx + dy * dy);
                if (dist < root.innerRadius) {
                    root.centerClicked();
                    root.close();
                } else if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                    root.presetSelected(root.presets[root.selectedIndex]);
                    root.close();
                }
            }
        }
    }
}
