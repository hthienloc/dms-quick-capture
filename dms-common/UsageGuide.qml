import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root
    width: parent.width
    spacing: expanded ? Theme.spacingS : 0 // Giảm spacing khi đóng để tránh khựng
    property alias items: repeater.model

    property bool expanded: true

    clip: true
    height: expanded ? implicitHeight : 0
    visible: height > 0

    opacity: expanded ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: Appearance.anim.durations.quick }
    }

    Repeater {
        id: repeater
        delegate: Row {
            width: parent.width
            spacing: Theme.spacingS
            
            StyledText {
                id: bullet
                text: "•"
                color: Theme.primary
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Bold
                anchors.top: textContent.top
                anchors.topMargin: 0
            }

            StyledText {
                id: textContent
                width: root.width - (bullet.width + parent.spacing + (Theme.spacingS * 2))
                text: modelData.replace(/\n/g, "<br/>")
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WordWrap
                textFormat: Text.StyledText
            }
        }
    }
}
