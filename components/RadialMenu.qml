import QtQuick
import qs.Common
import qs.Widgets
import ".."

Item {
    id: root
    z: 1000

    CaptureConfig { id: config }

    property var presets: []
    property int selectedIndex: -1
    
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
            PropertyChanges { target: root; opacity: 1; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 150; easing.type: Easing.OutQuad }
        }
    ]

    function open(x, y) {
        root.x = x - width / 2;
        root.y = y - height / 2;
        root.visibleState = true;
        selectedIndex = -1;
        radialMouseArea.mouseX = width / 2;
        radialMouseArea.mouseY = height / 2;
    }

    function close() {
        root.visibleState = false;
    }

    width: outerRadius * 2
    height: width

    onSelectedIndexChanged: radialCanvas.requestPaint()
    onPresetsChanged: radialCanvas.requestPaint()

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
                    ctx.fillStyle = Theme.primary;
                } else {
                    ctx.fillStyle = Theme.withAlpha(Theme.surfaceContainerHigh, 0.88);
                }
                ctx.fill();

                // Draw delicate border lines between sectors
                ctx.strokeStyle = root.selectedIndex === i ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15);
                ctx.lineWidth = root.selectedIndex === i ? 2 : 1;
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
                        const tool = config.toolButtons.find(t => t.id === modelData.tool);
                        return tool ? tool.icon : "help";
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

        // Glow matching Matugen primary
        color: root.selectedIndex === -2 ? Theme.withAlpha(Theme.primary, 0.12) : Theme.surfaceContainerHighest
        border.color: root.selectedIndex === -2 ? Theme.primary : Theme.withAlpha(Theme.outline, 0.4)
        border.width: root.selectedIndex === -2 ? 2.5 : 1

        scale: root.selectedIndex === -2 ? 1.05 : 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
        Behavior on border.width { NumberAnimation { duration: 100 } }

        Column {
            anchors.centerIn: parent
            spacing: 2
            
            DankIcon {
                name: {
                    if (root.selectedIndex === -2) return "check";
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                        const tool = config.toolButtons.find(t => t.id === root.presets[root.selectedIndex].tool);
                        return tool ? tool.icon : "check";
                    }
                    return "photo_camera"; // default idle center icon
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
                    if (root.selectedIndex === -2) return I18n.tr("Select");
                    if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                        const tool = config.toolButtons.find(t => t.id === root.presets[root.selectedIndex].tool);
                        return tool ? tool.tooltip.split(" (")[0] : "";
                    }
                    return I18n.tr("Capture");
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
            const dx = mouse.x - width / 2;
            const dy = mouse.y - height / 2;
            const dist = Math.sqrt(dx * dx + dy * dy);
            
            // Mouse inside center button -> select center
            if (dist < root.innerRadius) {
                root.selectedIndex = -2;
                return;
            }

            // Mouse outside outer boundary -> no selection
            if (dist > root.outerRadius) {
                root.selectedIndex = -1;
                return;
            }

            // Calculate sector index
            let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
            if (angle < 0) angle += 360;
            
            const numSectors = root.presets.length || 8;
            const sectorSize = 360 / numSectors;
            // Shift angle to align sector boundaries correctly
            const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);
            
            if (idx >= 0 && idx < numSectors) {
                root.selectedIndex = idx;
            }
        }

        onReleased: (mouse) => {
            if (root.selectedIndex >= 0 && root.selectedIndex < root.presets.length) {
                root.presetSelected(root.presets[root.selectedIndex]);
            } else if (root.selectedIndex === -2) {
                // Clicked center
                root.centerClicked();
            }
            root.close();
        }
        
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                root.close();
            }
        }
    }
}
