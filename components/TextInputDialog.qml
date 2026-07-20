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
    height: Math.min(contentColumn.implicitHeight + Theme.spacingM * 2, 400)
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
            if (window) {
                textInputField.text = window.currentTypingText;
            }
            textInputField.forceActiveFocus();
            textInputField.cursorPosition = textInputField.length;
        });
    }

    onClosed: {
        if (window && window.isTyping) {
            window.isTyping = false;
            window.currentTypingText = "";
            window.editingStroke = null;
            if (window.activeCanvas) window.activeCanvas.requestPaint();
        }
        if (modalFocusScope) {
            modalFocusScope.forceActiveFocus();
        }
    }

    contentItem: Rectangle {
        color: Theme.surfaceContainer
        radius: Theme.cornerRadius
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1

        Column {
            id: contentColumn
            width: parent.width - Theme.spacingM * 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.spacingM
            spacing: Theme.spacingM

            StyledText {
                text: window && window.editingStroke ? I18n.tr("Edit Text Note") : I18n.tr("Add Text Note")
                font.bold: true
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceText
            }

            Rectangle {
                id: inputBackground
                width: parent.width
                height: Math.min(Math.max(textInputField.implicitHeight, 72), 240)
                radius: Theme.cornerRadius / 2
                color: textInputField.activeFocus ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                border.color: textInputField.activeFocus ? Theme.primary : Theme.outlineMedium
                border.width: textInputField.activeFocus ? 2 : 1
                clip: true

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
                            if (window) {
                                window.currentTypingText = textInputField.text;
                                window.commitTypingText();
                            }
                            textInputDialog.close();
                            event.accepted = true;
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: 32

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    Repeater {
                        model: [
                            { icon: "format_bold", active: window && window.textBold, tag: "bold" },
                            { icon: "format_italic", active: window && window.textItalic, tag: "italic" },
                            { icon: "format_underlined", active: window && window.textUnderline, tag: "underline" },
                            { icon: "layers", active: window && window.textBackground, tag: "bg" }
                        ]

                        delegate: Rectangle {
                            width: 28
                            height: 28
                            radius: Theme.cornerRadius / 2
                            color: modelData.active 
                                ? Theme.withAlpha(Theme.primary, 0.15) 
                                : (toggleMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                            border.color: modelData.active ? Theme.primary : "transparent"
                            border.width: 1

                            DankIcon {
                                anchors.centerIn: parent
                                name: modelData.icon
                                size: 18
                                color: modelData.active ? Theme.primary : Theme.surfaceText
                            }

                            MouseArea {
                                id: toggleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!window) return;
                                    if (modelData.tag === "bold") window.textBold = !window.textBold;
                                    else if (modelData.tag === "italic") window.textItalic = !window.textItalic;
                                    else if (modelData.tag === "underline") window.textUnderline = !window.textUnderline;
                                    else if (modelData.tag === "bg") window.textBackground = !window.textBackground;
                                }
                            }
                        }
                    }
                }

                DankButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: window && window.editingStroke ? I18n.tr("Save") : I18n.tr("Add")
                    backgroundColor: Theme.primary
                    textColor: Theme.primaryText
                    onClicked: {
                        if (window) {
                            window.currentTypingText = textInputField.text;
                            window.commitTypingText();
                        }
                        textInputDialog.close();
                    }
                }
            }
        }
    }
}
