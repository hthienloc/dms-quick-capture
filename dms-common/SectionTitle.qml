import QtQuick
import qs.Common
import qs.Widgets

Row {
    id: root
    width: parent.width
    spacing: Theme.spacingS
    
    property alias text: titleText.text
    property string icon: ""

    DankIcon {
        name: root.icon
        size: 18
        color: Theme.primary
        visible: root.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
    }

    StyledText {
        id: titleText
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - (root.icon !== "" ? parent.spacing + 18 : 0)
        elide: Text.ElideRight
    }
}
