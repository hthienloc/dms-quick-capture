import QtQuick
import qs.Common
import qs.Widgets

SettingsCard {
    id: root
    property string title: I18n.tr("Note")
    property string text: ""
    property string icon: "info"
    property color iconColor: Theme.primary

    SectionTitle {
        text: root.title
        icon: root.icon
    }

    StyledText {
        width: parent.width
        text: root.text
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.Wrap
    }
}
