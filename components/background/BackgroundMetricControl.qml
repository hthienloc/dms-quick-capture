import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: root

    property string iconName: ""
    property string valueText: ""
    property bool compact: false
    property int valueWidth: 40
    property int iconSize: compact ? Constants.iconSize : Constants.backgroundIconSize

    signal hovered(var controlItem)
    signal exited
    signal wheeled(int delta)

    implicitWidth: compact ? Constants.btnSize + 8 : layout.implicitWidth
    implicitHeight: compact ? Constants.compactControlHeight : Constants.btnSize
    width: implicitWidth
    height: implicitHeight

    Grid {
        id: layout
        columns: root.compact ? 1 : 2
        spacing: root.compact ? Constants.spacingCompact : Theme.spacingXS
        anchors.centerIn: parent
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        DankIcon {
            name: root.iconName
            size: root.iconSize
            color: Theme.surfaceText
        }

        StyledText {
            text: root.valueText
            width: root.compact ? root.width : root.valueWidth
            horizontalAlignment: root.compact ? Text.AlignHCenter : Text.AlignRight
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered(root)
        onExited: root.exited()
        onWheel: wheel => root.wheeled(wheel.angleDelta.y)
    }
}
