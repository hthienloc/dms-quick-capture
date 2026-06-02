import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets

Row {
    id: root
    width: parent.width
    height: 40
    spacing: Theme.spacingS

    property string title: ""
    property real volume: 1.0
    property bool isMuted: false
    property bool showStopButton: false
    property bool stopButtonEnabled: false

    signal volumeChangeRequested(real val)
    signal muteToggled()
    signal stopClicked()

    DankIcon {
        name: root.isMuted || root.volume === 0 ? "volume_off" : "volume_up"
        size: 22
        color: root.isMuted ? Theme.error : (root.stopButtonEnabled ? Theme.primary : Theme.surfaceVariantText)
        anchors.verticalCenter: parent.verticalCenter
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.muteToggled()
        }
    }

    DankSlider {
        id: volumeSlider
        value: root.volume * 100
        width: parent.width - 80
        minimum: 0
        maximum: 100
        centerMinimum: false
        unit: "%"
        showValue: true
        wheelEnabled: false
        onSliderValueChanged: v => {
            root.volumeChangeRequested(v / 100)
            if (v > 0 && root.isMuted) root.isMuted = false
        }
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onWheel: wheel => {
                var delta = wheel.angleDelta.y > 0 ? 5 : -5
                var newVol = Math.min(100, Math.max(0, root.volume * 100 + delta))
                if (newVol !== root.volume * 100) {
                    root.volume = newVol / 100
                    if (newVol > 0 && root.isMuted) root.isMuted = false
                    root.volumeChangeRequested(root.volume)
                }
            }
        }
    }

    DankIcon {
        name: "cancel"
        size: 24
        color: root.stopButtonEnabled ? Theme.error : Theme.surfaceVariantText
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showStopButton
        opacity: root.stopButtonEnabled ? 1.0 : 0.5
        MouseArea {
            anchors.fill: parent
            cursorShape: root.stopButtonEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (root.stopButtonEnabled) root.stopClicked()
        }
    }
}