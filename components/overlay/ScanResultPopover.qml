import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Widgets
import qs.Services
import "../popovers"

PopoverSurface {
    id: root

    property string resultType: "ocr"
    property string resultText: ""
    readonly property bool isUrl: /^https?:\/\//i.test(resultText.trim())
    readonly property string titleText: resultType === "qr" ? I18n.trFor("quickCapture", "QR Result") : I18n.trFor("quickCapture", "OCR Result")

    signal closeRequested

    function show(type, text) {
        resultType = type;
        resultText = text || "";
        if (!resultText)
            return;
        open();
        startCloseTimer();
    }

    onClosed: closeRequested()

    width: Math.min(520, parent ? parent.width - Theme.spacingL * 2 : 520)
    height: Math.min(contentColumn.implicitHeight + Theme.spacingM * 2, 220)
    closedScale: 0.96
    closeInterval: resultText.length > 240 ? 16000 : 10000
    z: 20000
    clip: true

    HoverHandler {
        id: hoverHandler
        onHoveredChanged: {
            if (hovered) {
                root.stopCloseTimer();
                return;
            }
            if (root.opened)
                root.startCloseTimer();
        }
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingM * 2
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Row {
            width: parent.width
            height: 28
            spacing: Theme.spacingS

            DankIcon {
                name: root.resultType === "qr" ? "qr_code" : "document_scanner"
                size: Theme.iconSize
                color: Theme.primary
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.titleText
                width: parent.width - Theme.iconSize - closeButton.width - parent.spacing * 2
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                elide: Text.ElideRight
                anchors.verticalCenter: parent.verticalCenter
            }

            DankActionButton {
                id: closeButton
                iconName: "close"
                buttonSize: 28
                iconSize: Theme.iconSizeSmall
                tooltipText: I18n.trFor("quickCapture", "Close")
                onClicked: root.close()
            }
        }

        Rectangle {
            width: parent.width
            height: Math.min(Math.max(resultPreview.contentHeight + Theme.spacingS * 2, 54), 108)
            radius: Theme.cornerRadius / 2
            color: Theme.surfaceContainerHigh
            border.color: Theme.withAlpha(Theme.outline, 0.12)
            border.width: 1
            clip: true

            ScrollView {
                anchors.fill: parent
                anchors.margins: 1
                clip: true

                TextArea {
                    id: resultPreview
                    text: root.resultText
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    color: Theme.surfaceText
                    selectionColor: Theme.primaryContainer
                    selectedTextColor: Theme.primary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: Theme.fontFamily
                    background: null
                    topPadding: Theme.spacingS
                    leftPadding: Theme.spacingS
                    rightPadding: Theme.spacingS
                    bottomPadding: Theme.spacingS
                    onTextChanged: {
                        if (root.resultText !== text)
                            root.resultText = text;
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: Theme.spacingS

            DankButton {
                text: I18n.trFor("quickCapture", "Open")
                iconName: "open_in_new"
                visible: root.isUrl
                buttonHeight: 32
                onClicked: Quickshell.execDetached(["xdg-open", root.resultText.trim()])
            }

            DankButton {
                text: I18n.trFor("quickCapture", "Copy")
                iconName: "content_copy"
                buttonHeight: 32
                onClicked: {
                    DMSService.sendRequest("clipboard.copy", {
                        "text": resultPreview.text
                    }, () => {
                        ToastService.showInfo(I18n.trFor("quickCapture", "Copied to clipboard"));
                        root.close();
                    });
                }
            }
        }
    }
}
