import QtQuick
import qs.Common
import qs.Widgets
import qs.Services

Column {
    id: root
    width: parent.width
    spacing: 4

    property string label: ""
    property string text: ""

    StyledText {
        width: parent.width
        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        color: Theme.surfaceVariantText
        visible: text !== ""
    }

    Rectangle {
        width: parent.width
        height: Math.max(40, cmdRow.implicitHeight + 16)
        color: Theme.surfaceContainer
        radius: 4

        Row {
            id: cmdRow
            width: parent.width - 16
            anchors.centerIn: parent
            spacing: 8

            StyledText {
                width: parent.width - 32
                text: root.text
                font.family: "Monospace"
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondary
                wrapMode: Text.Wrap
            }

            DankButton {
                width: 24; height: 24
                iconName: "content_copy"
                backgroundColor: "transparent"
                textColor: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                onClicked: {
                    Proc.runCommand("copy-ipc", ["wl-copy", "--", root.text], function() {
                        ToastService.showInfo("Copied to clipboard");
                    });
                }
            }
        }
    }
}
