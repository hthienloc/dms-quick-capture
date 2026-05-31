import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    property string title: ""
    property bool showCloseButton: true

    signal closeClicked()

    width: parent.width
    height: Math.max(titleText.implicitHeight, closeButton.implicitHeight)

    StyledText {
        id: titleText
        text: root.title
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Medium
        color: Theme.surfaceText
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    DankActionButton {
        id: closeButton
        visible: root.showCloseButton
        iconName: "close"
        iconSize: Theme.iconSize - 4
        iconColor: Theme.surfaceText
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        onClicked: root.closeClicked()
    }
}