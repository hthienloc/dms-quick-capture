// PluginHeader.qml
import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root
    width: parent.width
    spacing: 4

    property string title: ""
    property string description: ""

    StyledText {
        width: parent.width
        text: root.title
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.primary
    }

    StyledText {
        width: parent.width
        text: root.description
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        visible: text !== ""
    }
}
