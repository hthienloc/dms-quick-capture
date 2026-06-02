import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets

StyledRect {
    id: root

    property string label: ""
    property string value: ""
    property string iconName: ""
    property color accentColor: Theme.primary
    property bool interactive: false

    signal clicked()

    implicitHeight: layout.implicitHeight + Theme.spacingM * 2
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainerHighest, 0.4)
    border.width: 1
    border.color: Theme.withAlpha(root.accentColor, 0.18)

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.iconName !== ""

            DankIcon {
                name: root.iconName
                size: 14
                color: root.accentColor
                opacity: 0.8
            }

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall - 1
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.iconName === ""
            Layout.fillWidth: true
            text: root.label
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall - 1
            elide: Text.ElideRight
        }

        StyledText {
            Layout.fillWidth: true
            text: root.value
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
