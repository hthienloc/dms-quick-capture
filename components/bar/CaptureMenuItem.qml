import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    required property string icon
    required property string text
    property bool highlighted: false
    property bool showPin: true
    property string rightClickAction: "copy"

    signal triggered(string action)

    readonly property bool hovered: itemMouse.containsMouse || pinArea.containsMouse

    width: parent.width
    height: 36
    radius: Theme.cornerRadius
    color: hovered ? Theme.primaryHoverLight : "transparent"
    scale: (itemMouse.pressed || pinArea.pressed) ? 0.98 : 1.0

    Behavior on color {
        ColorAnimation {
            duration: Theme.shorterDuration
            easing.type: Theme.standardEasing
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.shorterDuration
            easing.type: Theme.standardEasing
        }
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingM
        anchors.right: parent.right
        anchors.rightMargin: root.showPin ? pinArea.width + Theme.spacingS : Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankIcon {
            name: root.icon
            size: Theme.iconSizeSmall
            anchors.verticalCenter: parent.verticalCenter
            color: root.highlighted ? Theme.primary : Theme.surfaceText
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeMedium
            font.weight: root.highlighted ? Font.Bold : Font.Normal
            color: root.highlighted ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    DankRipple {
        id: ripple
        anchors.fill: parent
        rippleColor: Theme.primary
        cornerRadius: root.radius
        clip: true
    }

    DankIcon {
        visible: root.showPin
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        name: "push_pin"
        size: Theme.iconSizeSmall - 2
        opacity: root.hovered ? 1 : 0
        color: pinArea.containsMouse ? Theme.primary : Theme.surfaceText
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shorterDuration
            }
        }
    }

    MouseArea {
        id: itemMouse
        anchors.fill: parent
        anchors.rightMargin: root.showPin ? pinArea.width : 0
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: mouse => root.triggered(mouse.button === Qt.RightButton ? root.rightClickAction : "edit")
    }

    MouseArea {
        id: pinArea
        visible: root.showPin
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 28
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => ripple.trigger(mouse.x + parent.width - width, mouse.y)
        onClicked: root.triggered("float")
    }
}
