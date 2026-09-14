import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Popup {
    id: root

    property var currentPaletteColors: []
    property var customPaletteColors: []

    signal copyAndSwitch
    signal switchOnly

    readonly property var options: [
        {
            title: I18n.trFor("quickCapture", "Copy Current Palette"),
            detail: I18n.trFor("quickCapture", "Copy and customize this preset"),
            colors: root.currentPaletteColors,
            copy: true
        },
        {
            title: I18n.trFor("quickCapture", "Use Existing Custom"),
            detail: I18n.trFor("quickCapture", "Switch to your custom preset"),
            colors: root.customPaletteColors,
            copy: false
        }
    ]

    width: 560
    height: 310
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    function choose(copy) {
        if (copy)
            root.copyAndSwitch();
        else
            root.switchOnly();
        root.close();
    }

    background: Rectangle {
        color: "transparent"
    }

    contentItem: Rectangle {
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                text: I18n.trFor("quickCapture", "Edit Color Palette")
                font.weight: Font.Bold
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.trFor("quickCapture", "This palette preset is read-only. Select one of the options below to switch to the Custom Palette and edit colors:")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM

                Repeater {
                    model: root.options

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        width: (parent.width - Theme.spacingM) / 2
                        height: 150
                        radius: Theme.cornerRadius
                        color: cardArea.containsMouse ? Theme.surfaceHover : Theme.surfaceContainerHigh
                        border.color: cardArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                        border.width: cardArea.containsMouse ? 2 : 1
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingS

                            StyledText {
                                text: card.modelData.title
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontSizeMedium
                                color: Theme.surfaceText
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            StyledText {
                                text: card.modelData.detail
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.surfaceTextMedium
                                anchors.horizontalCenter: parent.horizontalCenter
                            }

                            Grid {
                                columns: 4
                                spacing: Theme.spacingXS
                                anchors.horizontalCenter: parent.horizontalCenter

                                Repeater {
                                    model: card.modelData.colors

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: modelData
                                        border.color: Theme.withAlpha(Theme.outline, 0.2)
                                        border.width: 1
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.choose(card.modelData.copy)
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 28

                DankButton {
                    text: I18n.trFor("quickCapture", "Cancel")
                    backgroundColor: "transparent"
                    textColor: Theme.surfaceTextMedium
                    height: 28
                    anchors.right: parent.right
                    onClicked: root.close()
                }
            }
        }
    }
}
