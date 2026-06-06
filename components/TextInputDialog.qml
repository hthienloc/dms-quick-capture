import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../dms-common"

Popup {
    id: root
    width: 320
    height: 160
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    property var rootWindow
    property var modalFocusScope

    background: Rectangle {
        color: "transparent"
    }

    onOpened: {
        Qt.callLater(() => {
            textInputField.text = "";
            textInputField.forceActiveFocus();
        });
    }

    onClosed: {
        if (rootWindow && rootWindow.isTyping) {
            rootWindow.isTyping = false;
            rootWindow.currentTypingText = "";
            if (rootWindow.activeCanvas) rootWindow.activeCanvas.requestPaint();
            modalFocusScope.forceActiveFocus();
        }
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
                text: I18n.tr("Add Text Note")
                font.bold: true
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            DankTextField {
                id: textInputField
                width: parent.width
                placeholderText: I18n.tr("Type note...")
                focus: true
                onAccepted: {
                    if (rootWindow) {
                        rootWindow.currentTypingText = textInputField.text;
                        rootWindow.commitTypingText();
                    }
                    root.close();
                }
            }

            Row {
                width: parent.width
                spacing: Theme.spacingS
                layoutDirection: Qt.RightToLeft

                DankButton {
                    text: I18n.tr("Add")
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: {
                        if (rootWindow) {
                            rootWindow.currentTypingText = textInputField.text;
                            rootWindow.commitTypingText();
                        }
                        root.close();
                    }
                }

                DankButton {
                    text: I18n.tr("Cancel")
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    onClicked: {
                        root.close();
                    }
                }
            }
        }
    }
}
