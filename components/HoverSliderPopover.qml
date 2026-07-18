import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: popoverRoot

    ToolbarConstants { id: tc }

    width: isVertical ? tc.btnSize : 120
    height: isVertical ? 120 : tc.btnSize
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
    property bool isVertical: false
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
            visible: !popoverRoot.isVertical
            minimum: popoverRoot.minimum
            maximum: popoverRoot.maximum
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            value: popoverRoot.value
            showValue: false
            onSliderValueChanged: val => {
                if (!popoverRoot.isVertical) popoverRoot.userValueChanged(val)
            }
        }

        Item {
            id: verticalSliderContainer
            visible: popoverRoot.isVertical
            anchors.fill: parent
            anchors.margins: Theme.spacingS

            StyledRect {
                id: verticalTrack
                width: 8
                height: parent.height
                anchors.centerIn: parent
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.outline, Theme.popupTransparency)
                
                StyledRect {
                    id: verticalFill
                    width: parent.width
                    radius: Theme.cornerRadius
                    anchors.bottom: parent.bottom
                    height: {
                        const range = popoverRoot.maximum - popoverRoot.minimum;
                        const ratio = range === 0 ? 0 : (popoverRoot.value - popoverRoot.minimum) / range;
                        return Math.max(0, Math.min(verticalTrack.height, verticalTrack.height * ratio));
                    }
                    color: Theme.primary
                }
                
                StyledRect {
                    id: verticalHandle
                    width: 20
                    height: 8
                    radius: Theme.cornerRadius
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: {
                        const range = popoverRoot.maximum - popoverRoot.minimum;
                        const ratio = range === 0 ? 0 : (popoverRoot.value - popoverRoot.minimum) / range;
                        const travel = verticalTrack.height - height;
                        return Math.max(0, Math.min(travel, travel * (1 - ratio)));
                    }
                    color: Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                
                function updateValue(mouseY) {
                    let ratio = 1 - Math.max(0, Math.min(1, mouseY / verticalSliderContainer.height));
                    let rawVal = popoverRoot.minimum + ratio * (popoverRoot.maximum - popoverRoot.minimum);
                    let newVal = popoverRoot.stepSize > 1 ? Math.round(rawVal / popoverRoot.stepSize) * popoverRoot.stepSize : Math.round(rawVal);
                    newVal = Math.max(popoverRoot.minimum, Math.min(popoverRoot.maximum, newVal));
                    if (newVal !== popoverRoot.value) {
                        popoverRoot.userValueChanged(newVal);
                    }
                }
                
                onPressed: mouse => updateValue(mouse.y)
                onPositionChanged: mouse => { if (pressed) updateValue(mouse.y) }
                onClicked: mouse => updateValue(mouse.y)
            }
        }
    }
}
