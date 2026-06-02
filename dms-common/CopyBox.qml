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
    property bool isCopied: false

    function triggerCopy() {
        Proc.runCommand("copy-ipc", ["dms", "cl", "copy", root.text], function() {
            root.isCopied = true;
            copyTimer.restart();
            ToastService.showInfo("Copied to clipboard");
        });
    }

    Timer {
        id: copyTimer
        interval: 1500
        repeat: false
        onTriggered: {
            root.isCopied = false;
        }
    }

    StyledText {
        width: parent.width
        text: root.label
        font.pixelSize: Theme.fontSizeSmall
        font.bold: true
        color: Theme.surfaceVariantText
        visible: text !== ""
    }

    Rectangle {
        id: bgRect
        width: parent.width
        height: Math.max(40, cmdRow.implicitHeight + 16)
        color: Theme.surfaceContainerHigh
        border.color: copyMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.7) : Theme.withAlpha(Theme.primary, 0.0)
        border.width: 1
        radius: 4

        Behavior on border.color { ColorAnimation { duration: 150 } }

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
                iconName: root.isCopied ? "check" : "content_copy"
                backgroundColor: "transparent"
                textColor: root.isCopied ? Theme.success : Theme.primary
                anchors.verticalCenter: parent.verticalCenter
                onClicked: root.triggerCopy()
            }
        }

        MouseArea {
            id: copyMouseArea
            anchors.fill: parent
            hoverEnabled: true
            z: 1
            cursorShape: Qt.PointingHandCursor
            onClicked: root.triggerCopy()
        }
    }
}
