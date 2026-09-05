import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

PopoverSurface {
    id: popoverRoot

    property var images: []
    property string folderPath: ""
    property string selectedPath: ""
    property bool loading: false

    signal imageSelected(string path)
    signal refreshRequested()

    width: 380
    height: 330
    border.color: Theme.withAlpha(Theme.outline, 0.2)

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Theme.spacingS

        Item {
            width: parent.width
            height: 36

            Column {
                anchors.left: parent.left
                anchors.right: headerActions.left
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                StyledText {
                    text: I18n.trFor("quickCapture", "Background Images")
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    color: Theme.surfaceText
                }

                StyledText {
                    width: parent.width
                    text: popoverRoot.folderPath
                    font.pixelSize: Theme.fontSizeSmall - 2
                    color: Theme.surfaceVariantText
                    elide: Text.ElideMiddle
                }
            }

            Row {
                id: headerActions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                DankActionButton {
                    iconName: "refresh"
                    buttonSize: 28
                    iconSize: 16
                    tooltipText: I18n.trFor("quickCapture", "Refresh")
                    onClicked: popoverRoot.refreshRequested()
                }

                DankActionButton {
                    iconName: "close"
                    buttonSize: 28
                    iconSize: 16
                    tooltipText: I18n.trFor("quickCapture", "Close")
                    onClicked: popoverRoot.close()
                }
            }
        }

        Item {
            width: parent.width
            height: parent.height - 36 - Theme.spacingS

            BusyIndicator {
                anchors.centerIn: parent
                running: popoverRoot.loading
                visible: running
            }

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingXS
                visible: !popoverRoot.loading && popoverRoot.images.length === 0

                DankIcon {
                    name: "image_not_supported"
                    size: 30
                    color: Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: I18n.trFor("quickCapture", "No supported images found")
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }

            GridView {
                anchors.fill: parent
                visible: !popoverRoot.loading && popoverRoot.images.length > 0
                clip: true
                cellWidth: 118
                cellHeight: 92
                model: popoverRoot.images
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    width: 108
                    height: 82
                    radius: Theme.cornerRadiusSmall
                    color: Theme.surfaceContainerHigh
                    border.color: popoverRoot.selectedPath === modelData.path ? Theme.primary : Theme.withAlpha(Theme.outline, 0.2)
                    border.width: popoverRoot.selectedPath === modelData.path ? 2 : 1
                    clip: true

                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: modelData.path.indexOf("/") === 0 ? `file://${modelData.path}` : modelData.path
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 22
                        color: Theme.withAlpha(Theme.surfaceContainer, 0.86)

                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 5
                            anchors.rightMargin: 5
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.name
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popoverRoot.imageSelected(modelData.path)
                    }
                }
            }
        }
    }
}
