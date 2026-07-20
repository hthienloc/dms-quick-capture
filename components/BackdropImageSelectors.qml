import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Row {
    id: controlRoot

    property var modal: null
    property string backdropImagePath: ""
    property real backdropImageBlur: 0
    property real backdropImageDim: 0.2
    property bool isVertical: false

    spacing: Theme.spacingS
    anchors.verticalCenter: isVertical ? undefined : parent.verticalCenter
    anchors.horizontalCenter: isVertical ? parent.horizontalCenter : undefined

    readonly property var presets: [
        { label: "Preset 1", path: Qt.resolvedUrl("../backdrops/preset1.jpg") },
        { label: "Preset 2", path: Qt.resolvedUrl("../backdrops/preset2.jpg") }
    ]

    // Presets Row
    Row {
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: controlRoot.presets
            delegate: Rectangle {
                width: 32
                height: 24
                radius: 4
                border.color: (controlRoot.backdropImagePath === modelData.path || (controlRoot.backdropImagePath === "" && index === 0)) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                border.width: (controlRoot.backdropImagePath === modelData.path || (controlRoot.backdropImagePath === "" && index === 0)) ? 2 : 1
                clip: true

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: modelData.path
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (controlRoot.modal) {
                            controlRoot.modal.backdropImagePath = modelData.path;
                            if (controlRoot.modal.activeCanvas) controlRoot.modal.activeCanvas.requestPaint();
                        }
                    }
                }
            }
        }
    }

    // Browse Button (Opens DMS FileBrowserModal)
    DankButton {
        text: qsTr("Browse...")
        iconName: "folder_open"
        horizontalPadding: Theme.spacingM
        anchors.verticalCenter: parent.verticalCenter
        onClicked: {
            if (controlRoot.modal && controlRoot.modal.backdropImageBrowserModal) {
                controlRoot.modal.backdropImageBrowserModal.open();
            }
        }
    }

    // Blur Slider
    Row {
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: "blur_on"
            size: 16
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Slider {
            from: 0
            to: 30
            value: controlRoot.backdropImageBlur
            stepSize: 1
            width: 80
            anchors.verticalCenter: parent.verticalCenter
            onValueChanged: {
                if (controlRoot.modal) {
                    controlRoot.modal.backdropImageBlur = value;
                    if (controlRoot.modal.activeCanvas) controlRoot.modal.activeCanvas.requestPaint();
                }
            }
        }
    }

    // Dim Slider
    Row {
        spacing: Theme.spacingXS
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            name: "brightness_medium"
            size: 16
            color: Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }

        Slider {
            from: 0
            to: 0.8
            value: controlRoot.backdropImageDim
            stepSize: 0.05
            width: 80
            anchors.verticalCenter: parent.verticalCenter
            onValueChanged: {
                if (controlRoot.modal) {
                    controlRoot.modal.backdropImageDim = value;
                    if (controlRoot.modal.activeCanvas) controlRoot.modal.activeCanvas.requestPaint();
                }
            }
        }
    }
}
