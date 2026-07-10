import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: popoverRoot

    ToolbarConstants { id: tc }

    width: 120
    height: tc.btnSize
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
    z: 10001

    property int minimum: 0
    property int maximum: 100
    property int value: 0
    property int stepSize: 5
    property bool opened: false
    onValueChanged: slider.value = value

    signal userValueChanged(int val)

    visible: opacity > 0
    opacity: 0
    scale: 0.9

    states: [
        State {
            name: "visible"
            when: popoverRoot.opened
            PropertyChanges { target: popoverRoot; opacity: 1.0; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open() {
        closeTimer.stop();
        popoverRoot.opened = true;
    }

    function close() {
        popoverRoot.opened = false;
    }

    function startCloseTimer() {
        closeTimer.start();
    }

    function stopCloseTimer() {
        closeTimer.stop();
    }

    Timer {
        id: closeTimer
        interval: 200
        onTriggered: popoverRoot.close()
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: popoverRoot.open()
        onExited: popoverRoot.startCloseTimer()
        
        onWheel: (wheel) => {
            let step = wheel.angleDelta.y > 0 ? popoverRoot.stepSize : -popoverRoot.stepSize;
            let newVal = Math.max(popoverRoot.minimum, Math.min(popoverRoot.maximum, popoverRoot.value + step));
            popoverRoot.userValueChanged(newVal);
        }

        DankSlider {
            id: slider
            minimum: popoverRoot.minimum
            maximum: popoverRoot.maximum
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            value: popoverRoot.value
            showValue: false
            onSliderValueChanged: val => popoverRoot.userValueChanged(val)
        }
    }
}
