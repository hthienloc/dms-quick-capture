import QtQuick
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Rectangle {
    id: menuRoot

    width: 160
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
    z: 10000

    property bool opened: false
    visible: opacity > 0
    opacity: 0
    scale: 0.9

    signal rotateLeftRequested()
    signal rotateRightRequested()
    signal flipHorizontalRequested()
    signal flipVerticalRequested()
    signal rotateRequested()
    signal mirrorRequested()
    signal ocrRequested()
    signal qrScanRequested()
    signal copyColorRequested()
    signal eraserRequested()

    states: [
        State {
            name: "visible"
            when: menuRoot.opened
            PropertyChanges { target: menuRoot; opacity: 1.0; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open() {
        menuRoot.opened = true;
    }

    function close() {
        menuRoot.opened = false;
    }

    Column {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: Constants.spacingCompact

        // ── Quick action grid: Rotate (L/R) | Flip (H/V) ───────────────────
        Column {
            width: parent.width
            spacing: Constants.spacingCompact

            // Row 1: Rotate Left | Rotate Right
            Row {
                width: parent.width
                height: 44
                spacing: Constants.spacingCompact

                // Rotate Left button
                Rectangle {
                    width: (parent.width - Constants.spacingCompact) / 2
                    height: parent.height
                    radius: Theme.cornerRadius - 2
                    color: rotateLeftMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: "rotate_left"
                            size: 16
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: qsTr("Rotate L")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: rotateLeftMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRoot.rotateLeftRequested();
                        }
                    }
                }

                // Rotate Right button
                Rectangle {
                    width: (parent.width - Constants.spacingCompact) / 2
                    height: parent.height
                    radius: Theme.cornerRadius - 2
                    color: rotateRightMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: "rotate_right"
                            size: 16
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: qsTr("Rotate R")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: rotateRightMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRoot.rotateRightRequested();
                        }
                    }
                }
            }

            // Row 2: Flip Horiz | Flip Vert
            Row {
                width: parent.width
                height: 44
                spacing: Constants.spacingCompact

                // Flip Horizontal button
                Rectangle {
                    width: (parent.width - Constants.spacingCompact) / 2
                    height: parent.height
                    radius: Theme.cornerRadius - 2
                    color: flipHMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: "flip"
                            size: 16
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: qsTr("Flip Horiz")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: flipHMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRoot.flipHorizontalRequested();
                            menuRoot.mirrorRequested();
                        }
                    }
                }

                // Flip Vertical button
                Rectangle {
                    width: (parent.width - Constants.spacingCompact) / 2
                    height: parent.height
                    radius: Theme.cornerRadius - 2
                    color: flipVMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

                    Column {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: "swap_vert"
                            size: 16
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        StyledText {
                            text: qsTr("Flip Vert")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }

                    MouseArea {
                        id: flipVMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            menuRoot.flipVerticalRequested();
                        }
                    }
                }
            }
        }

        // ── Separator ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        // ── OCR ───────────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: ocrMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "document_scanner"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("OCR (O)")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: ocrMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.ocrRequested();
                }
            }
        }

        // ── Scan QR ───────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: qrMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "qr_code"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("Scan QR")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: qrMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.qrScanRequested();
                }
            }
        }

        // ── Eraser ────────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: eraserMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "auto_fix_normal"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("Eraser (T)")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: eraserMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.eraserRequested();
                }
            }
        }

        // ── Copy Color ────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: copyColorMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "colorize"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("Copy Color")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: copyColorMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.copyColorRequested();
                }
            }
        }
    }
}
