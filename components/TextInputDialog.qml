import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modals.Common
import qs.Services
import "../dms-common"

Popup {
    id: textInputDialog
    width: 420
    height: Math.min(Math.max(inputBackground.height + 120, 200), 400)
    padding: 0
    modal: false
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: parent

    required property var window
    required property var modalFocusScope

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
            if (modalFocusScope) {
                modalFocusScope.forceActiveFocus();
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

            Rectangle {
                id: inputBackground
                width: parent.width
                height: Math.max(textInputField.implicitHeight + textInputField.topPadding + textInputField.bottomPadding, 72)
                radius: Theme.cornerRadiusSmall
                color: textInputField.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: textInputField.activeFocus ? Theme.primary : Theme.outlineMedium
                border.width: textInputField.activeFocus ? 2 : 1

                TextArea {
                    id: textInputField
                    anchors.fill: parent
                    anchors.margins: 1
                    placeholderText: I18n.tr("Type note...")
                    wrapMode: TextEdit.Wrap
                    focus: true
                    font.pixelSize: Theme.fontSizeNormal
                    font.family: Theme.fontFamily
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primary
                    background: null
                    topPadding: Theme.spacingS
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    bottomPadding: Theme.spacingS

                    Keys.onPressed: (event) => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & Qt.ShiftModifier)) {
                            window.currentTypingText = textInputField.text;
                            textInputDialog.close();
                            window.commitTypingText();
                            event.accepted = true;
                        }
                    }
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
