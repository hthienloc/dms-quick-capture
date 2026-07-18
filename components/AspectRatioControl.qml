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
    height: compact ? 40 : tc.btnSize

    Row {
        id: row
        visible: !control.compact
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: "aspect_ratio"
            size: tc.iconSize
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
        StyledText {
            text: {
                if (control.backdropAspectRatio === "auto") return I18n.tr("AUTO");
                if (control.backdropAspectRatio === "custom") return control.customAspectRatio.toFixed(2);
                return control.backdropAspectRatio;
            }
            width: 46; horizontalAlignment: Text.AlignLeft
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Column {
        id: col
        visible: control.compact
        width: parent.width
        spacing: tc.spacingCompact
        anchors.centerIn: parent

        DankIcon {
            name: "aspect_ratio"
            size: tc.iconSize
            color: Theme.surfaceText
            anchors.horizontalCenter: parent.horizontalCenter
        }
        StyledText {
            text: {
                if (control.backdropAspectRatio === "auto") return I18n.tr("AUTO");
                if (control.backdropAspectRatio === "custom") return control.customAspectRatio.toFixed(2);
                return control.backdropAspectRatio;
            }
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
        onWheel: (wheel) => control.wheeled(wheel.angleDelta.y)
    }
}
