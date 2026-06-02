import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string text: ""
    property color toneColor: Theme.primary
    property bool strong: false
    property string iconName: ""

    implicitWidth: layout.implicitWidth + Theme.spacingM * 2
    implicitHeight: 28
    radius: 14
    color: strong ? Theme.withAlpha(toneColor, 0.18) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.68)
    border.width: 1
    border.color: strong ? Theme.withAlpha(toneColor, 0.35) : Theme.outlineVariant

    Row {
        id: layout
        anchors.centerIn: parent
        spacing: 6

        DankIcon {
            visible: root.iconName !== ""
            name: root.iconName
            size: 14
            color: root.strong ? root.toneColor : Theme.surfaceVariantText
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            color: root.strong ? root.toneColor : Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall - 1
            font.weight: root.strong ? Font.DemiBold : Font.Medium
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
