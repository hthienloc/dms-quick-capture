import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: controlRoot

    property string backdropMode: "none"
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property string gradientActiveSlot: "start"
    property int itemSize: 24
    property int iconSize: 14

    signal setGradientActiveSlot(string slot)
    signal autoColorBalanceRequested()
    signal colorPickerRequested(color currentColor)

    spacing: Theme.spacingXS
    anchors.verticalCenter: parent.verticalCenter

    Rectangle {
        visible: controlRoot.backdropMode === "solid"
        width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
        color: controlRoot.backdropSolidColor
        border.color: Theme.withAlpha(Theme.outline, 0.3)
        border.width: 1
    }

    readonly property bool isGradient: backdropMode === "gradient" || backdropMode === "radial" || backdropMode === "conic"

    Row {
        visible: controlRoot.isGradient
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
            color: controlRoot.backdropGradientStart
            border.color: controlRoot.gradientActiveSlot === "start" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
            border.width: controlRoot.gradientActiveSlot === "start" ? (controlRoot.itemSize >= 24 ? 2 : 1.5) : 1
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controlRoot.setGradientActiveSlot("start")
            }
        }
        Rectangle {
            width: controlRoot.itemSize; height: controlRoot.itemSize; radius: controlRoot.itemSize / 2
            color: controlRoot.backdropGradientEnd
            border.color: controlRoot.gradientActiveSlot === "end" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
            border.width: controlRoot.gradientActiveSlot === "end" ? (controlRoot.itemSize >= 24 ? 2 : 1.5) : 1
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: controlRoot.setGradientActiveSlot("end")
            }
        }
    }

    DankActionButton {
        buttonSize: controlRoot.itemSize
        iconName: "colorize"
        iconSize: controlRoot.iconSize
        backgroundColor: "transparent"
        iconColor: Theme.primary
        onClicked: {
            let col = controlRoot.backdropMode === "solid" ? controlRoot.backdropSolidColor :
                      (controlRoot.gradientActiveSlot === "start" ? controlRoot.backdropGradientStart : controlRoot.backdropGradientEnd);
            controlRoot.colorPickerRequested(col);
        }
    }

    DankActionButton {
        buttonSize: controlRoot.itemSize
        iconName: "auto_awesome"
        iconSize: controlRoot.iconSize
        backgroundColor: "transparent"
        iconColor: Theme.primary
        onClicked: controlRoot.autoColorBalanceRequested()
    }
}
