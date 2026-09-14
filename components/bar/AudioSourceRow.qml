import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root

    property bool active: false
    property string iconOn: "mic"
    property string iconOff: "mic_off"
    property var options: []
    property string currentValue: ""

    signal toggled
    signal valueSelected(string value)

    readonly property string currentLabel: options.find(o => o.value === currentValue)?.label ?? currentValue

    width: parent.width
    spacing: Theme.spacingS

    Rectangle {
        id: toggleBox
        width: 40
        height: 40
        radius: Theme.cornerRadius
        color: root.active ? Theme.withAlpha(Theme.primary, 0.15) : (toggleArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerLow)
        border.color: root.active ? Theme.primary : Theme.outlineVariant
        border.width: 1

        Behavior on color {
            ColorAnimation {
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.shorterDuration
                easing.type: Theme.standardEasing
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: root.active ? root.iconOn : root.iconOff
            size: Theme.iconSize
            color: root.active ? Theme.primary : Theme.surfaceVariantText
            Behavior on color {
                ColorAnimation {
                    duration: Theme.shorterDuration
                    easing.type: Theme.standardEasing
                }
            }
        }

        DankRipple {
            id: ripple
            anchors.fill: parent
            rippleColor: Theme.primary
            cornerRadius: toggleBox.radius
            clip: true
        }

        MouseArea {
            id: toggleArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
            onClicked: root.toggled()
        }
    }

    DankDropdown {
        width: parent.width - toggleBox.width - Theme.spacingS
        height: 40
        compactMode: true
        visible: root.active
        currentValue: root.currentLabel
        options: root.options.map(o => o.label)
        onValueChanged: {
            const match = root.options.find(o => o.label === value);
            if (match)
                root.valueSelected(match.value);
        }
    }
}
