import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: control

    ToolbarConstants { id: tc }

    property string backdropAlignment: "center"
    property bool compact: false

    signal hovered()
    signal exited()

    readonly property var _labelMap: ({
        "top-left": "TL", "top-center": "TC", "top-right": "TR",
        "center-left": "CL", "center": "C", "center-right": "CR",
        "bottom-left": "BL", "bottom-center": "BC", "bottom-right": "BR"
    })

    width: compact ? tc.btnSize : row.implicitWidth
    height: compact ? tc.btnSizeCompact : tc.btnSize

    Row {
        id: row
        spacing: compact ? tc.spacingCompact : Theme.spacingXS
        anchors.centerIn: compact ? parent : undefined
        anchors.verticalCenter: compact ? undefined : parent.verticalCenter

        DankIcon {
            name: "align_justify_center"
            size: compact ? tc.iconSizeCompact : tc.backdropIconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: control._labelMap[control.backdropAlignment] ?? "C"
            width: compact ? 14 : 18; horizontalAlignment: Text.AlignHCenter
            font.pixelSize: compact ? tc.fontSizeCompact : Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
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
