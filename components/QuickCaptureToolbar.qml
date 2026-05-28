import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../lib"

Rectangle {
    id: root

    QuickCaptureConfig { id: config }

    property string currentTool: "crop"
    property color currentColor: Theme.primary
    property int strokeWidth: 8
    property bool canUndo: false

    signal toolSelected(string tool)
    signal colorSelected(var color)
    signal strokeWidthSelected(int width)
    signal undoRequested()
    signal saveRequested()
    signal copyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()

    width: contentRow.width + Theme.spacingM * 2
    height: 52
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingL

        Row {
            id: leftGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingM

            DankActionButton {
                iconName: "near_me"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Select & Move (V)"
                anchors.verticalCenter: parent.verticalCenter

                backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText

                onClicked: root.toolSelected("select")
            }

            DankActionButton {
                iconName: "crop"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Crop / Resize Area (P)"
                anchors.verticalCenter: parent.verticalCenter

                backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText

                onClicked: root.toolSelected("crop")
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: config.toolButtons

                    delegate: DankActionButton {
                        iconName: modelData.icon
                        buttonSize: 36
                        iconSize: 18
                        tooltipText: modelData.tooltip

                        backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                        iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText

                        onClicked: root.toolSelected(modelData.id)
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: [Theme.primary].concat(config.accentColors)

                    delegate: Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: Qt.colorEqual(root.currentColor, modelData) ? 2 : 1

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.colorSelected(modelData)
                        }
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                Text {
                    text: root.strokeWidth + "px"
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText
                    font.pixelSize: 11
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                }

                Slider {
                    id: sizeSlider
                    from: 1
                    to: 50
                    value: root.strokeWidth
                    onMoved: root.strokeWidthSelected(Math.round(value))
                    anchors.verticalCenter: parent.verticalCenter
                    width: 80

                    background: Rectangle {
                        x: sizeSlider.leftPadding
                        y: sizeSlider.topPadding + sizeSlider.availableHeight / 2 - height / 2
                        implicitWidth: 80
                        implicitHeight: 4
                        width: sizeSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: Theme.withAlpha(Theme.outline, 0.3)

                        Rectangle {
                            width: sizeSlider.visualPosition * parent.width
                            height: parent.height
                            color: Theme.primary
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: sizeSlider.leftPadding + sizeSlider.visualPosition * (sizeSlider.availableWidth - width)
                        y: sizeSlider.topPadding + sizeSlider.availableHeight / 2 - height / 2
                        implicitWidth: 12
                        implicitHeight: 12
                        radius: 6
                        color: Theme.primary
                        border.color: Theme.surface
                        border.width: 1
                    }
                }
            }

            Rectangle {
                width: 1
                height: 24
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "undo"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Undo (Ctrl+Z)"
                enabled: root.canUndo
                iconColor: root.canUndo ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.3)
                onClicked: root.undoRequested()
            }
        }

        Row {
            id: rightGroup
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "save"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Save to File (Ctrl+S)"
                onClicked: root.saveRequested()
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "content_copy"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Copy to Clipboard (Ctrl+C / Enter)"
                backgroundColor: Theme.withAlpha(Theme.primary, 0.1)
                iconColor: Theme.primary
                onClicked: root.copyRequested()
            }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "assignment_turned_in"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Copy & Save"
                backgroundColor: Theme.withAlpha(Theme.primary, 0.15)
                iconColor: Theme.primary
                onClicked: root.copyAndSaveRequested()
            }

            Item { width: Theme.spacingL; height: 1 }

            Rectangle {
                width: 1
                height: 24
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            Item { width: Theme.spacingXS; height: 1 }

            DankActionButton {
                anchors.verticalCenter: parent.verticalCenter
                iconName: "close"
                buttonSize: 36
                iconSize: 18
                tooltipText: "Discard & Close (Escape)"
                backgroundColor: Theme.withAlpha(Theme.error, 0.1)
                iconColor: Theme.error
                onClicked: root.closeRequested()
            }
        }
    }
}
