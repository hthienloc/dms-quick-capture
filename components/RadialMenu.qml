import QtQuick
import qs.Common
import qs.Widgets
import ".."

Item {
    id: root
    visible: false
    z: 1000

    CaptureConfig { id: config }

    property var presets: []
    property int selectedIndex: -1
    property real menuRadius: 100
    property real itemRadius: 30

    signal presetSelected(var preset)

    function open(x, y) {
        root.x = x - width / 2;
        root.y = y - height / 2;
        root.visible = true;
        selectedIndex = -1;
        // Force refresh of the mouse tracking by resetting the cursor pos logic
        radialMouseArea.mouseX = width / 2;
        radialMouseArea.mouseY = height / 2;
    }

    function close() {
        root.visible = false;
    }

    width: menuRadius * 2 + itemRadius * 2
    height: width

    Rectangle {
        anchors.fill: parent
        color: "transparent"

        // Center point reference
        Rectangle {
            width: 4
            height: 4
            radius: 2
            color: Theme.primary
            anchors.centerIn: parent
            opacity: 0.5
        }

        Repeater {
            model: root.presets

            delegate: Item {
                width: root.itemRadius * 2
                height: width
                
                property real angle: (index * 360 / root.presets.length) - 90
                property real rad: angle * Math.PI / 180
                
                x: (root.width / 2) + root.menuRadius * Math.cos(rad) - root.itemRadius
                y: (root.height / 2) + root.menuRadius * Math.sin(rad) - root.itemRadius

                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: root.selectedIndex === index ? Theme.primary : Theme.surfaceContainerHigh
                    border.color: root.selectedIndex === index ? Theme.onPrimary : Theme.withAlpha(Theme.outline, 0.5)
                    border.width: root.selectedIndex === index ? 2 : 1
                    
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Behavior on scale { NumberAnimation { duration: 100 } }
                    scale: root.selectedIndex === index ? 1.1 : 1.0

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        StyledText {
                            text: (index + 1)
                            font.pixelSize: 9
                            font.bold: true
                            color: root.selectedIndex === index ? Theme.onPrimary : Theme.surfaceVariantText
                            anchors.horizontalCenter: parent.horizontalCenter
                            opacity: 0.7
                        }

                        DankIcon {
                            name: {
                                const tool = config.toolButtons.find(t => t.id === modelData.tool);
                                return tool ? tool.icon : "help";
                            }
                            size: 28
                            color: root.selectedIndex === index ? Theme.onPrimary : modelData.color
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: radialMouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: (mouse) => {
            const dx = mouse.x - width / 2;
            const dy = mouse.y - height / 2;
            const dist = Math.sqrt(dx * dx + dy * dy);
            
            if (dist < 20) {
                root.selectedIndex = -1;
                return;
            }

            let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
            if (angle < 0) angle += 360;
            
            const sectorSize = 360 / root.presets.length;
            const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);
            
            if (idx >= 0 && idx < root.presets.length) {
                root.selectedIndex = idx;
            }
        }

        onReleased: (mouse) => {
            if (root.selectedIndex !== -1) {
                root.presetSelected(root.presets[root.selectedIndex]);
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
