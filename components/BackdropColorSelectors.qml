import QtQuick
import qs.Common
import qs.Widgets

Grid {
    id: controlRoot

    ToolbarConstants { id: tc }

    property string backdropMode: "none"
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property string gradientActiveSlot: "start"
    property int itemSize: 24
    property int iconSize: 18
    property bool isVertical: false

    signal setGradientActiveSlot(string slot)
    signal autoColorBalanceRequested()
    signal colorPickerRequested(color currentColor)
    signal eyedropperRequested(string slot)

    columns: isVertical ? 1 : 4
    spacing: isVertical ? 10 : Theme.spacingXS
    anchors.verticalCenter: isVertical ? undefined : parent.verticalCenter
    anchors.horizontalCenter: isVertical ? parent.horizontalCenter : undefined

    Item {
        visible: controlRoot.backdropMode === "solid"
        width: tc.verticalSelectorItemWidth
        height: controlRoot.itemSize

        Rectangle {
            width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
            color: controlRoot.backdropSolidColor
            border.color: Theme.withAlpha(Theme.outline, 0.3)
            border.width: 1
            anchors.centerIn: parent

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        controlRoot.eyedropperRequested("solid")
                    } else {
                        controlRoot.colorPickerRequested(controlRoot.backdropSolidColor)
                    }
                }
            }
        }
    }

    readonly property bool isGradient: backdropMode === "gradient" || backdropMode === "radial" || backdropMode === "conic"

    Item {
        visible: controlRoot.isGradient
        width: controlRoot.isVertical ? tc.verticalSelectorItemWidth : (controlRoot.itemSize * 2 + Theme.spacingXS)
        height: controlRoot.isVertical ? (controlRoot.itemSize * 2 + Theme.spacingXS) : controlRoot.itemSize

        Grid {
            columns: controlRoot.isVertical ? 1 : 2
            spacing: Theme.spacingXS
            anchors.centerIn: parent

            Rectangle {
                width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
                color: controlRoot.backdropGradientStart
                border.color: controlRoot.gradientActiveSlot === "start" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                border.width: controlRoot.gradientActiveSlot === "start" ? (controlRoot.itemSize >= 24 ? 2 : 1.5) : 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        controlRoot.setGradientActiveSlot("start")
                        if (mouse.button === Qt.RightButton) {
                            controlRoot.eyedropperRequested("start")
                        }
                    }
                }
            }
            Rectangle {
                width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
                color: controlRoot.backdropGradientEnd
                border.color: controlRoot.gradientActiveSlot === "end" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                border.width: controlRoot.gradientActiveSlot === "end" ? (controlRoot.itemSize >= 24 ? 2 : 1.5) : 1
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: (mouse) => {
                        controlRoot.setGradientActiveSlot("end")
                        if (mouse.button === Qt.RightButton) {
                            controlRoot.eyedropperRequested("end")
                        }
                    }
                }
            }
        }
    }

    Item {
        width: tc.verticalSelectorItemWidth
        height: controlRoot.itemSize

        DankActionButton {
            anchors.fill: parent
            iconName: "colorize"
            iconSize: controlRoot.iconSize
            backgroundColor: "transparent"
            iconColor: Theme.surfaceText
            tooltipText: I18n.tr("Pick Color")
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                let col = controlRoot.backdropMode === "solid" ? controlRoot.backdropSolidColor :
                          (controlRoot.gradientActiveSlot === "start" ? controlRoot.backdropGradientStart : controlRoot.backdropGradientEnd);
                let targetSlot = controlRoot.backdropMode === "solid" ? "solid" : controlRoot.gradientActiveSlot;
                if (mouse.button === Qt.RightButton) {
                    controlRoot.eyedropperRequested(targetSlot)
                } else {
                    controlRoot.colorPickerRequested(col)
                }
            }
        }
    }

    Item {
        width: tc.verticalSelectorItemWidth
        height: controlRoot.itemSize

        DankActionButton {
            buttonSize: controlRoot.itemSize
            iconName: "auto_awesome"
            iconSize: controlRoot.iconSize
            backgroundColor: "transparent"
            iconColor: Theme.surfaceText
            tooltipText: I18n.tr("Auto Balance")
            anchors.centerIn: parent
            onClicked: controlRoot.autoColorBalanceRequested()
        }
    }
}
