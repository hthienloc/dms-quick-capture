import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: control

    ToolbarConstants { id: tc }

    property string backdropAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property bool compact: false

    signal hovered()
    signal exited()
    signal wheeled(int delta)

    width: compact ? tc.btnSize : row.implicitWidth
    height: compact ? tc.btnSizeCompact : tc.btnSize

    Row {
        id: row
        spacing: compact ? tc.spacingCompact : Theme.spacingXS
        anchors.centerIn: compact ? parent : undefined
        anchors.verticalCenter: compact ? undefined : parent.verticalCenter

        DankIcon {
            name: "aspect_ratio"
            size: compact ? tc.iconSizeCompact : tc.backdropIconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: {
                var t;
                if (control.backdropAspectRatio === "auto") t = I18n.tr("AUTO");
                else if (control.backdropAspectRatio === "custom") t = control.customAspectRatio.toFixed(2);
                else t = control.backdropAspectRatio;
                return String(t).padStart(5);
            }
            font.family: "monospace"
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
        onWheel: (wheel) => control.wheeled(wheel.angleDelta.y)
    }
}
