import QtQuick
import qs.Common
import qs.Widgets
import ".."

Item {
    id: root
    z: 2000
    anchors.fill: parent

    property bool visibleState: false
    visible: opacity > 0
    opacity: 0
    
    // Position of the radial menu center relative to root
    property real menuX: 0
    property real menuY: 0

    // States for options
    property bool boldActive: false
    property bool italicActive: false
    property bool underlineActive: false

    signal boldToggled()
    signal italicToggled()
    signal underlineToggled()
    signal centerClicked()

    // Geometry config
    readonly property real outerRadius: 110
    readonly property real innerRadius: 44
    readonly property real centerRadius: 38
    readonly property real midRadius: (innerRadius + outerRadius) / 2
    readonly property real itemRadius: 24

    property int selectedIndex: -1

    states: [
        State {
            name: "visible"
            when: root.visibleState
            PropertyChanges { target: root; opacity: 1.0 }
            PropertyChanges { target: menuContent; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { target: root; property: "opacity"; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: menuContent; property: "scale"; duration: 150; easing.type: Easing.OutQuad }
        }
    ]

    function open(x, y) {
        root.menuX = x;
        root.menuY = y;
        root.visibleState = true;
        selectedIndex = -1;
    }

    function close() {
        root.visibleState = false;
    }

    // Scrim overlay to dismiss when clicking outside
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            root.close();
        }
    }

    Item {
        id: menuContent
        width: outerRadius * 2
        height: width
        x: root.menuX - width / 2
        y: root.menuY - height / 2
        scale: 0.8

        onXChanged: radialCanvas.requestPaint()
        onYChanged: radialCanvas.requestPaint()

        Canvas {
            id: radialCanvas
            anchors.fill: parent
            antialiasing: true

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);

                var centerX = width / 2;
                var centerY = height / 2;
                var numSectors = 3;
                var sectorAngle = 2 * Math.PI / numSectors;

                for (var i = 0; i < numSectors; i++) {
                    var startAngle = i * sectorAngle - Math.PI / 2 - sectorAngle / 2;
                    var endAngle = startAngle + sectorAngle;

                    ctx.beginPath();
                    ctx.arc(centerX, centerY, root.outerRadius, startAngle, endAngle);
                    ctx.arc(centerX, centerY, root.innerRadius, endAngle, startAngle, true);
                    ctx.closePath();

                    var isActive = false;
                    if (i === 0) isActive = root.boldActive;
                    else if (i === 1) isActive = root.italicActive;
                    else if (i === 2) isActive = root.underlineActive;

                    // fill: active → primary; hovered-only or idle → surfaceContainerHigh
                    if (isActive) {
                        ctx.fillStyle = Theme.primary;
                    } else {
                        ctx.fillStyle = Theme.withAlpha(Theme.surfaceContainerHigh, 0.92);
                    }
                    ctx.fill();

                    // border: active → primary 3px; hovered → primary 2px; idle → faint 1px
                    if (isActive) {
                        ctx.strokeStyle = Theme.primary;
                        ctx.lineWidth = 3;
                    } else if (root.selectedIndex === i) {
                        ctx.strokeStyle = Theme.primary;
                        ctx.lineWidth = 2;
                    } else {
                        ctx.strokeStyle = Theme.withAlpha(Theme.outline, 0.15);
                        ctx.lineWidth = 1;
                    }
                    ctx.stroke();
                }
            }
        }

        Connections {
            target: root
            function onBoldActiveChanged() { radialCanvas.requestPaint(); }
            function onItalicActiveChanged() { radialCanvas.requestPaint(); }
            function onUnderlineActiveChanged() { radialCanvas.requestPaint(); }
            function onSelectedIndexChanged() { radialCanvas.requestPaint(); }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.color: Theme.withAlpha(Theme.outline, 0.25)
            border.width: 1.5
        }

        Repeater {
            model: [
                { icon: "format_bold", label: "Bold" },
                { icon: "format_italic", label: "Italic" },
                { icon: "format_underlined", label: "Underline" }
            ]

            delegate: Item {
                width: root.itemRadius * 2
                height: width
                
                property real angle: (index * 120) - 90
                property real rad: angle * Math.PI / 180
                
                x: (menuContent.width / 2) + root.midRadius * Math.cos(rad) - root.itemRadius
                y: (menuContent.height / 2) + root.midRadius * Math.sin(rad) - root.itemRadius

                Column {
                    anchors.centerIn: parent
                    spacing: 1

                    DankIcon {
                        name: modelData.icon
                        size: 22
                        color: {
                            var isActive = false;
                            if (index === 0) isActive = root.boldActive;
                            else if (index === 1) isActive = root.italicActive;
                            else if (index === 2) isActive = root.underlineActive;

                            return isActive ? Theme.onPrimary : Theme.surfaceVariantText;
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: I18n.tr(modelData.label)
                        font.pixelSize: 8
                        font.bold: true
                        color: {
                            var isActive = false;
                            if (index === 0) isActive = root.boldActive;
                            else if (index === 1) isActive = root.italicActive;
                            else if (index === 2) isActive = root.underlineActive;

                            return isActive ? Theme.onPrimary : Theme.surfaceVariantText;
                        }
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }
        }

        Rectangle {
            id: centerButton
            width: root.centerRadius * 2
            height: width
            radius: root.centerRadius
            anchors.centerIn: parent

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
                    name: "close"
                    size: 20
                    color: root.selectedIndex === -2 ? Theme.primary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.tr("Close")
                    font.pixelSize: 8
                    font.bold: true
                    color: root.selectedIndex === -2 ? Theme.primary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
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
                
                if (dist < root.innerRadius) {
                    root.selectedIndex = -2;
                    return;
                }

                if (dist > root.outerRadius) {
                    root.selectedIndex = -1;
                    return;
                }

                let angle = Math.atan2(dy, dx) * 180 / Math.PI + 90;
                if (angle < 0) angle += 360;
                
                const sectorSize = 120;
                const idx = Math.floor((angle + sectorSize / 2) % 360 / sectorSize);
                
                if (idx >= 0 && idx < 3) {
                    root.selectedIndex = idx;
                }
            }

            onPressed: (mouse) => {
                mouse.accepted = true;
            }

            onReleased: (mouse) => {
                mouse.accepted = true;
                if (root.selectedIndex === 0) {
                    root.boldToggled();
                } else if (root.selectedIndex === 1) {
                    root.italicToggled();
                } else if (root.selectedIndex === 2) {
                    root.underlineToggled();
                } else if (root.selectedIndex === -2) {
                    root.centerClicked();
                }
                root.selectedIndex = -1;
            }
            
            onClicked: (mouse) => {
                mouse.accepted = true;
                if (mouse.button === Qt.RightButton) {
                    root.close();
                }
            }
        }
    }
}
