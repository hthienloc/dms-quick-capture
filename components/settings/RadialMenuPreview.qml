import QtQuick
import qs.Common
import qs.Widgets
import "../core/Helpers.js" as Helpers

Item {
    id: root

    required property QtObject config
    property var presets: []
    property int activeIndex: 0
    property real menuOpacity: 1

    readonly property real outerRadius: 110
    readonly property real innerRadius: 40
    readonly property real midRadius: (innerRadius + outerRadius) / 2
    readonly property real itemRadius: 22
    readonly property real centerRadius: 34
    readonly property var activePreset: presets[activeIndex] ?? null

    width: 240
    height: 240
    opacity: menuOpacity

    onActiveIndexChanged: sectors.requestPaint()
    onPresetsChanged: sectors.requestPaint()

    Canvas {
        id: sectors
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            const ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            const centerX = width / 2;
            const centerY = height / 2;
            const numSectors = 8;
            const sectorAngle = 2 * Math.PI / numSectors;

            for (let i = 0; i < numSectors; i++) {
                const startAngle = i * sectorAngle - Math.PI / 2 - sectorAngle / 2;
                const endAngle = startAngle + sectorAngle;
                const isActive = root.activeIndex === i;

                ctx.beginPath();
                ctx.arc(centerX, centerY, root.outerRadius, startAngle, endAngle);
                ctx.arc(centerX, centerY, root.innerRadius, endAngle, startAngle, true);
                ctx.closePath();
                ctx.fillStyle = isActive ? Theme.primary : Theme.withAlpha(Theme.surfaceContainerHigh, 0.88);
                ctx.fill();
                ctx.strokeStyle = isActive ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15);
                ctx.lineWidth = isActive ? 2 : 1;
                ctx.stroke();
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: Theme.withAlpha(Theme.outline, 0.25)
        border.width: 1.5
    }

    Repeater {
        model: root.presets

        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            readonly property real rad: ((index * 360 / 8) - 90) * Math.PI / 180
            readonly property bool active: root.activeIndex === index

            width: root.itemRadius * 2
            height: width
            x: root.width / 2 + root.midRadius * Math.cos(rad) - root.itemRadius
            y: root.height / 2 + root.midRadius * Math.sin(rad) - root.itemRadius

            Column {
                anchors.centerIn: parent
                spacing: 1

                StyledText {
                    text: slot.index + 1
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Bold
                    color: slot.active ? Theme.onPrimary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                    opacity: 0.6
                }

                DankIcon {
                    name: root.config.getToolIcon(slot.modelData.tool)
                    size: Theme.iconSizeSmall + 2
                    color: {
                        if (slot.active)
                            return Theme.onPrimary;
                        if (slot.modelData.tool === "none")
                            return Theme.withAlpha(Theme.surfaceVariantText, 0.3);
                        return root.config.resolveColor(slot.modelData.color);
                    }
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Rectangle {
        width: root.centerRadius * 2
        height: width
        radius: root.centerRadius
        anchors.centerIn: parent
        color: Theme.surfaceContainerHighest
        border.color: Theme.withAlpha(Theme.outline, 0.4)
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 1

            DankIcon {
                readonly property bool enabled: root.activePreset && root.activePreset.tool !== "none"
                name: enabled ? root.config.getToolIcon(root.activePreset.tool) : "block"
                size: Theme.iconSize
                color: enabled ? root.config.resolveColor(root.activePreset.color) : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: I18n.trFor("quickCapture", "Preset %1").arg(root.activeIndex + 1)
                font.pixelSize: Theme.fontSizeSmall - 2
                font.weight: Font.Bold
                color: Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        function select(mouse) {
            const idx = Helpers.sectorIndexAt(mouse.x - width / 2, mouse.y - height / 2, 8, root.innerRadius, root.outerRadius);
            if (idx >= 0)
                root.activeIndex = idx;
        }

        onPositionChanged: mouse => select(mouse)
        onClicked: mouse => select(mouse)
    }
}
