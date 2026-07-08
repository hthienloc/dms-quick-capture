import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: menuRoot

    ToolbarConstants { id: tc }

    width: 140
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
        spacing: tc.spacingCompact

        // ── Quick action row: Rotate | Mirror ─────────────────────────────
        Row {
            width: parent.width
            height: 52
            spacing: tc.spacingCompact

            // Rotate button
            Rectangle {
                width: (parent.width - tc.spacingCompact) / 2
                height: parent.height
                radius: Theme.cornerRadius - 2
                color: rotateMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                border.width: 0

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    DankIcon {
                        name: "rotate_right"
                        size: 18
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: qsTr("Rotate")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: rotateMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Keep menu open — rotate is a repeatable action
                        menuRoot.rotateRequested();
                    }
                }
            }

            // Mirror button
            Rectangle {
                width: (parent.width - tc.spacingCompact) / 2
                height: parent.height
                radius: Theme.cornerRadius - 2
                color: mirrorMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                border.width: 0

                Column {
                    anchors.centerIn: parent
                    spacing: 3

                    DankIcon {
                        name: "flip"
                        size: 18
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    StyledText {
                        text: qsTr("Mirror")
                        font.pixelSize: Theme.fontSizeSmall - 1
                        color: Theme.surfaceText
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                MouseArea {
                    id: mirrorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Keep menu open — mirror is a repeatable action
                        menuRoot.mirrorRequested();
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
