import QtQuick
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Item {
    id: control

    property string backdropAlignment: "center"
    property bool compact: false

    signal hovered()
    signal exited()

    readonly property var _labelMap: ({
        "top-left": "TL", "top-center": "TC", "top-right": "TR",
        "center-left": "CL", "center": "C", "center-right": "CR",
        "bottom-left": "BL", "bottom-center": "BC", "bottom-right": "BR"
    })

    width: compact ? (Constants.btnSize + 8) : row.implicitWidth
    height: compact ? Constants.compactControlHeight : Constants.btnSize

    Row {
        id: row
        visible: !control.compact
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: "align_justify_center"
            size: Constants.iconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: control._labelMap[control.backdropAlignment] ?? "C"
            width: 22; horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: col
        visible: control.compact
        width: parent.width
        spacing: Constants.spacingCompact
        anchors.centerIn: parent

        DankIcon {
            name: "align_justify_center"
            size: Constants.iconSize
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
        StyledText {
            text: control._labelMap[control.backdropAlignment] ?? "C"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: control.hovered()
        onExited: control.exited()
    }
}
