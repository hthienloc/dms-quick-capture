import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../dms-common"

Popup {
    id: warningDialog
    width: 560
    height: 310
    padding: 0
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    property var currentPaletteColors: []
    property var customPaletteColors: []

    signal copyAndSwitch()
    signal switchOnly()

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
                text: I18n.tr("Edit Color Palette")
                font.bold: true
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            StyledText {
                width: parent.width
                text: I18n.tr("This palette preset is read-only. Select one of the options below to switch to the Custom Palette and edit colors:")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceTextMedium
                wrapMode: Text.Wrap
            }

            Row {
                width: parent.width
                spacing: Theme.spacingM
                anchors.horizontalCenter: parent.horizontalCenter

                // Option 1: Copy & Switch
                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 150
                    radius: Theme.cornerRadius
                    color: opt1MouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceContainerHigh
                    border.color: opt1MouseArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                    border.width: opt1MouseArea.containsMouse ? 2 : 1
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Copy Current Palette")
                            font.bold: true
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: I18n.tr("Copy and customize this preset")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceTextMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Grid {
                            columns: 4
                            spacing: Theme.spacingXS
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: warningDialog.currentPaletteColors
                                delegate: Rectangle {
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
                        id: opt1MouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            warningDialog.copyAndSwitch();
                            warningDialog.close();
                        }
                    }
                }

                // Option 2: Switch Only
                Rectangle {
                    width: (parent.width - Theme.spacingM) / 2
                    height: 150
                    radius: Theme.cornerRadius
                    color: opt2MouseArea.containsMouse ? Theme.surfaceHover : Theme.surfaceContainerHigh
                    border.color: opt2MouseArea.containsMouse ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
                    border.width: opt2MouseArea.containsMouse ? 2 : 1
                    clip: true

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: I18n.tr("Use Existing Custom")
                            font.bold: true
                            font.pixelSize: Theme.fontSizeMedium
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: I18n.tr("Switch to your custom preset")
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.surfaceTextMedium
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Grid {
                            columns: 4
                            spacing: Theme.spacingXS
                            anchors.horizontalCenter: parent.horizontalCenter

                            Repeater {
                                model: warningDialog.customPaletteColors
                                delegate: Rectangle {
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
                        id: opt2MouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            warningDialog.switchOnly();
                            warningDialog.close();
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 28

                DankButton {
                    text: I18n.tr("Cancel")
                    backgroundColor: "transparent"
                    textColor: Theme.surfaceTextMedium
                    height: 28
                    anchors.right: parent.right
                    onClicked: {
                        warningDialog.close();
                    }
                }
            }
        }
    }
}
