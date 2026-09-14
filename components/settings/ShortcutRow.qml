import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string keyText
    required property string actionText
    property bool isHeader: false

    width: parent.width
    height: 32

    Rectangle {
        anchors.fill: parent
        color: root.isHeader ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
        radius: Theme.cornerRadius
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingM
        anchors.rightMargin: Theme.spacingM
        spacing: Theme.spacingM

        Item {
            width: 110
            height: parent.height

            Rectangle {
                anchors.centerIn: parent
                width: Math.max(90, keyLabel.implicitWidth + Theme.spacingM)
                height: 22
                radius: Theme.cornerRadius / 2
                color: root.isHeader ? "transparent" : Theme.surfaceContainerHighest
                border.color: root.isHeader ? "transparent" : Theme.outline
                border.width: root.isHeader ? 0 : 1
                visible: root.keyText !== ""

                StyledText {
                    id: keyLabel
                    text: root.keyText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    isMonospace: true
                    color: root.isHeader ? Theme.primary : Theme.surfaceText
                    anchors.centerIn: parent
                }
            }
        }

        StyledText {
            text: root.actionText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: root.isHeader ? Font.Bold : Font.Normal
            color: root.isHeader ? Theme.primary : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            width: parent.width - 130
        }
    }
}
