import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "../dms-common"

Popup {
    id: textInputDialog
    width: 320
    height: 160
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    required property var window

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
        if (window.isTyping) {
            window.isTyping = false;
            window.currentTypingText = "";
            if (window.activeCanvas) window.activeCanvas.requestPaint();
            if (window.modalFocusScope) {
                window.modalFocusScope.forceActiveFocus();
            }
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
                    window.currentTypingText = textInputField.text;
                    textInputDialog.close();
                    window.commitTypingText();
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
                        window.currentTypingText = textInputField.text;
                        textInputDialog.close();
                        window.commitTypingText();
                    }
                }

                DankButton {
                    text: I18n.tr("Cancel")
                    backgroundColor: Theme.surfaceContainerHigh
                    textColor: Theme.surfaceText
                    onClicked: {
                        textInputDialog.close();
                    }
                }
            }
        }
    }
}
