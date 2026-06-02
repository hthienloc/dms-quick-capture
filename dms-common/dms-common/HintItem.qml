import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root
    width: parent.width
    spacing: Theme.spacingXS

    property string icon: "lightbulb"
    property string text: ""

    DankIcon {
        id: tipIcon
        name: root.icon
        size: 14
        color: Theme.primary
        anchors.top: parent.top
        anchors.topMargin: 2
    }

    StyledText {
        width: parent.width - tipIcon.width - parent.spacing
        text: root.text
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
        opacity: 0.8
    }
}
