import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Rectangle {
    id: root

    property string currentRatio: "" // "" = Free, "1:1", "4:3", "16:9", "3:2"

    signal ratioSelected(string ratio)
    signal resetRequested()
    signal cancelRequested()
    signal doneRequested()

    implicitHeight: 44
    implicitWidth: mainRow.implicitWidth + 24
    radius: 22
    color: Qt.rgba(Theme.surfaceContainerHigh.r, Theme.surfaceContainerHigh.g, Theme.surfaceContainerHigh.b, 0.95)
    border.color: Qt.rgba(Theme.outlineVariant.r, Theme.outlineVariant.g, Theme.outlineVariant.b, 0.35)
    border.width: 1

    // Prevent clicks from falling through to canvas
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: {}
    }

    RowLayout {
        id: mainRow
        anchors.centerIn: parent
        spacing: 6

        // Aspect ratio pills
        Repeater {
            model: [
                { label: I18n.trFor("quickCapture", "Free"), value: "" },
                { label: "1:1", value: "1:1" },
                { label: "4:3", value: "4:3" },
                { label: "16:9", value: "16:9" },
                { label: "3:2", value: "3:2" }
            ]

            delegate: Rectangle {
                id: pillRect
                implicitHeight: 30
                implicitWidth: pillText.implicitWidth + 18
                radius: 15
                readonly property bool isSelected: root.currentRatio === modelData.value
                color: isSelected ? Theme.primary : (pillMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")

                Text {
                    id: pillText
                    anchors.centerIn: parent
                    text: modelData.label
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: pillRect.isSelected ? Font.Bold : Font.Medium
                    color: pillRect.isSelected ? Theme.surfaceContainerHigh : Theme.surfaceText
                }

                MouseArea {
                    id: pillMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.ratioSelected(modelData.value)
                }
            }
        }

        // Divider
        Rectangle {
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            width: 1
            height: 20
            color: Theme.outlineVariant
            opacity: 0.35
        }

        // Reset button
        Rectangle {
            implicitHeight: 30
            implicitWidth: resetRow.implicitWidth + 14
            radius: 15
            color: resetMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"

            RowLayout {
                id: resetRow
                anchors.centerIn: parent
                spacing: 4

                DankIcon {
                    name: "refresh"
                    size: 16
                    color: Theme.surfaceText
                }

                Text {
                    text: I18n.trFor("quickCapture", "Reset")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.resetRequested()
            }
        }

        // Divider
        Rectangle {
            Layout.leftMargin: 2
            Layout.rightMargin: 2
            width: 1
            height: 20
            color: Theme.outlineVariant
            opacity: 0.35
        }

        // Cancel button
        Rectangle {
            implicitHeight: 30
            implicitWidth: cancelText.implicitWidth + 18
            radius: 15
            color: cancelMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent"

            Text {
                id: cancelText
                anchors.centerIn: parent
                text: I18n.trFor("quickCapture", "Cancel")
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: Theme.surfaceVariantText
            }

            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.cancelRequested()
            }
        }

        // Done button
        Rectangle {
            implicitHeight: 30
            implicitWidth: doneRow.implicitWidth + 16
            radius: 15
            color: doneMouse.containsMouse ? Qt.darker(Theme.primary, 1.1) : Theme.primary

            RowLayout {
                id: doneRow
                anchors.centerIn: parent
                spacing: 4

                DankIcon {
                    name: "check"
                    size: 16
                    color: Theme.surfaceContainerHigh
                }

                Text {
                    text: I18n.trFor("quickCapture", "Done")
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    color: Theme.surfaceContainerHigh
                }
            }

            MouseArea {
                id: doneMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.doneRequested()
            }
        }
    }
}
