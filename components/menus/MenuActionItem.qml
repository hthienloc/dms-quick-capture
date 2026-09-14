import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string iconName: ""
    property string text: ""
    property string shortcut: ""
    property bool checked: false

    signal activated

    readonly property color accent: checked ? Theme.primary : Theme.surfaceText

    width: parent ? parent.width : 0
    height: 32
    radius: Theme.cornerRadius - 2
    color: checked ? Theme.withAlpha(Theme.primary, 0.15) : (mouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.1) : "transparent")

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spacingS
        anchors.right: shortcutBadge.visible ? shortcutBadge.left : parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingS

        DankIcon {
            name: root.iconName
            size: Theme.iconSizeSmall
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            text: root.text
            font.pixelSize: Theme.fontSizeSmall
            font.weight: root.checked ? Font.Bold : Font.Normal
            color: root.accent
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
        }
    }

    Rectangle {
        id: shortcutBadge
        visible: root.shortcut !== ""
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingS
        anchors.verticalCenter: parent.verticalCenter
        height: 18
        width: Math.max(18, shortcutText.implicitWidth + Theme.spacingS)
        radius: Theme.cornerRadius / 2
        color: root.checked ? Theme.withAlpha(Theme.primary, 0.25) : (mouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.8))
        border.color: Theme.withAlpha(Theme.outline, 0.2)
        border.width: 1

        StyledText {
            id: shortcutText
            anchors.centerIn: parent
            text: root.shortcut
            font.pixelSize: Theme.fontSizeSmall - 2
            font.weight: Font.Bold
            color: root.checked ? Theme.primary : Theme.surfaceVariantText
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
