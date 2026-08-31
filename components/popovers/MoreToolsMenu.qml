import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

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
    property bool watermarkEnabled: false
    property bool floatingMode: false
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
    signal watermarkToggled(bool enabled)
    signal editorPresentationToggled()
    signal insertImageRequested()

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

    // Keep the pointer cursor across separators and spacing between actions.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
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
                            text: I18n.tr("Rotate L")
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
                            text: I18n.tr("Rotate R")
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
                            text: I18n.tr("Flip Horiz")
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
                            text: I18n.tr("Flip Vert")
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

        // ── Watermark ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 36
            radius: Theme.cornerRadius - 2
            color: menuRoot.watermarkEnabled ? Theme.withAlpha(Theme.primary, 0.15) :
                   (watermarkMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.10) : "transparent")

            DankIcon {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                name: "branding_watermark"
                size: 16
                color: menuRoot.watermarkEnabled ? Theme.primary : Theme.surfaceText
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS + 16 + Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Watermark")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: menuRoot.watermarkEnabled ? Font.Bold : Font.Normal
                color: menuRoot.watermarkEnabled ? Theme.primary : Theme.surfaceText
            }

            Rectangle {
                id: watermarkBadge
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                height: 18
                width: Math.max(18, watermarkShortcutText.implicitWidth + 8)
                radius: 4
                color: menuRoot.watermarkEnabled ? Theme.withAlpha(Theme.primary, 0.25) : (watermarkMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.20) : Theme.withAlpha(Theme.surfaceContainerHighest, 0.8))
                border.color: Theme.withAlpha(Theme.outline, 0.2)
                border.width: 1

                StyledText {
                    id: watermarkShortcutText
                    anchors.centerIn: parent
                    text: "M"
                    font.pixelSize: Theme.fontSizeSmall - 2
                    font.weight: Font.Bold
                    color: menuRoot.watermarkEnabled ? Theme.primary : Theme.surfaceVariantText
                }
            }

            MouseArea {
                id: watermarkMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: menuRoot.watermarkToggled(!menuRoot.watermarkEnabled)
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        MenuActionItem {
            iconName: menuRoot.floatingMode ? "picture_in_picture_alt" : "open_in_new"
            text: menuRoot.floatingMode ? I18n.tr("Use Modal Editor") : I18n.tr("Use Floating Editor")
            onActivated: {
                menuRoot.close();
                menuRoot.editorPresentationToggled();
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.withAlpha(Theme.outline, 0.15)
        }

        MenuActionItem {
            iconName: "add_photo_alternate"
            text: I18n.tr("Insert Image")
            shortcut: "I"
            onActivated: {
                menuRoot.close();
                menuRoot.insertImageRequested();
            }
        }

        MenuActionItem {
            iconName: "document_scanner"
            text: I18n.tr("OCR")
            shortcut: "O"
            onActivated: {
                menuRoot.close();
                menuRoot.ocrRequested();
            }
        }

        MenuActionItem {
            iconName: "qr_code"
            text: I18n.tr("Scan QR")
            onActivated: {
                menuRoot.close();
                menuRoot.qrScanRequested();
            }
        }

        MenuActionItem {
            iconName: "auto_fix_normal"
            text: I18n.tr("Eraser")
            shortcut: "T"
            onActivated: {
                menuRoot.close();
                menuRoot.eraserRequested();
            }
        }

        MenuActionItem {
            iconName: "colorize"
            text: I18n.tr("Copy Color")
            onActivated: {
                menuRoot.close();
                menuRoot.copyColorRequested();
            }
        }
    }
}
