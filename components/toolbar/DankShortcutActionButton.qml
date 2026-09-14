import QtQuick
import qs.Common
import qs.Widgets

DankActionButton {
    id: button

    property string shortcutText: ""
    property bool showShortcut: false

    StyledText {
        text: button.shortcutText
        font.pixelSize: Theme.fontSizeSmall - 3
        font.weight: Font.Bold
        color: button.enabled ? Theme.withAlpha(Theme.surfaceText, 0.5) : Theme.withAlpha(Theme.surfaceText, 0.25)
        anchors.bottom: button.bottom
        anchors.right: button.right
        anchors.rightMargin: 4
        anchors.bottomMargin: 2
        visible: button.shortcutText !== "" && button.showShortcut
    }
}
