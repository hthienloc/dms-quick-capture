import QtQuick
import qs.Common
import qs.Widgets
import "../core/Helpers.js" as Helpers

Column {
    id: root

    property var slotColors: []
    property string value: "primary"
    property color customColor: "transparent"
    property string customLabel: ""

    signal valueSelected(string value)
    signal customRequested

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS

    Row {
        width: parent.width
        spacing: Theme.spacingS

        Row {
            spacing: Theme.spacingXS
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: root.slotColors
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: 28
                    height: 28
                    radius: 14
                    color: modelData
                    property bool isSelected: root.value === "slot_" + (index + 1)
                    border.width: isSelected ? 2 : 1
                    border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.4)
                    scale: hoverArea.containsMouse ? 1.1 : 1.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 100
                        }
                    }

                    DankIcon {
                        anchors.centerIn: parent
                        name: "check"
                        size: 14
                        color: Helpers.getContrastingColorFromRgb(parent.color)
                        visible: parent.isSelected
                    }

                    MouseArea {
                        id: hoverArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.valueSelected("slot_" + (index + 1))
                    }
                }
            }
        }

        Rectangle {
            width: 1
            height: 20
            color: Theme.withAlpha(Theme.outline, 0.2)
            anchors.verticalCenter: parent.verticalCenter
        }

        Rectangle {
            width: 28
            height: 28
            radius: 14
            property bool isSelected: !root.value.startsWith("slot_")
            color: isSelected ? root.customColor : Theme.surfaceContainerHighest
            border.width: isSelected ? 2 : 1
            border.color: isSelected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.4)
            scale: customHover.containsMouse ? 1.1 : 1.0
            Behavior on scale {
                NumberAnimation {
                    duration: 100
                }
            }

            DankIcon {
                anchors.centerIn: parent
                name: "palette"
                size: 14
                color: parent.isSelected ? Helpers.getContrastingColorFromRgb(parent.color) : Theme.surfaceText
            }

            MouseArea {
                id: customHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!parent.isSelected)
                        root.valueSelected("primary");
                }
            }
        }

        Rectangle {
            width: 110
            height: 28
            visible: !root.value.startsWith("slot_")
            color: root.customColor
            border.color: Theme.withAlpha(Theme.surfaceText, 0.15)
            border.width: 1

            StyledText {
                anchors.centerIn: parent
                text: root.customLabel
                font.pixelSize: Theme.fontSizeSmall - 1
                font.weight: Font.Bold
                isMonospace: true
                color: Helpers.getContrastingColorFromRgb(parent.color)
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.customRequested()
            }
        }
    }
}
