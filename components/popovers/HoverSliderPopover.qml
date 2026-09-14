import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants
import "../core/Helpers.js" as Helpers

PopoverSurface {
    id: popoverRoot

    property int minimum: 0
    property int maximum: 100
    property int value: 0
    property int stepSize: 5
    property bool isVertical: false

    signal userValueChanged(int val)

    width: isVertical ? Constants.btnSize : Constants.customRatioPopoverHeight
    height: isVertical ? Constants.customRatioPopoverHeight : Constants.btnSize

    function valueFromRatio(ratio) {
        const rawVal = minimum + ratio * (maximum - minimum);
        const newVal = stepSize > 1 ? Math.round(rawVal / stepSize) * stepSize : Math.round(rawVal);
        return Helpers.clamp(newVal, minimum, maximum);
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: popoverRoot.open()
        onExited: popoverRoot.startCloseTimer()
        onWheel: wheel => {
            const step = wheel.angleDelta.y > 0 ? popoverRoot.stepSize : -popoverRoot.stepSize;
            popoverRoot.userValueChanged(Helpers.clamp(popoverRoot.value + step, popoverRoot.minimum, popoverRoot.maximum));
        }

        Loader {
            anchors.fill: parent
            anchors.margins: Theme.spacingS
            sourceComponent: popoverRoot.isVertical ? verticalSlider : horizontalSlider
        }
    }

    Component {
        id: horizontalSlider

        DankSlider {
            minimum: popoverRoot.minimum
            maximum: popoverRoot.maximum
            value: popoverRoot.value
            showValue: false
            onSliderValueChanged: val => popoverRoot.userValueChanged(val)
        }
    }

    Component {
        id: verticalSlider

        Item {
            id: verticalSliderContainer

            readonly property real ratio: {
                const range = popoverRoot.maximum - popoverRoot.minimum;
                return range === 0 ? 0 : (popoverRoot.value - popoverRoot.minimum) / range;
            }

            StyledRect {
                id: verticalTrack
                width: 8
                height: parent.height
                anchors.centerIn: parent
                radius: Theme.cornerRadius
                color: Theme.withAlpha(Theme.outline, Theme.popupTransparency)

                StyledRect {
                    width: parent.width
                    radius: Theme.cornerRadius
                    anchors.bottom: parent.bottom
                    height: Helpers.clamp(verticalTrack.height * verticalSliderContainer.ratio, 0, verticalTrack.height)
                    color: Theme.primary
                }

                StyledRect {
                    width: 20
                    height: 8
                    radius: Theme.cornerRadius
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Helpers.clamp((verticalTrack.height - height) * (1 - verticalSliderContainer.ratio), 0, verticalTrack.height - height)
                    color: Theme.primary
                }
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                acceptedButtons: Qt.LeftButton
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                function updateValue(mouseY) {
                    if (verticalSliderContainer.height <= 0)
                        return;
                    const newVal = popoverRoot.valueFromRatio(1 - Helpers.clamp(mouseY / verticalSliderContainer.height, 0, 1));
                    if (newVal !== popoverRoot.value)
                        popoverRoot.userValueChanged(newVal);
                }

                onPressed: mouse => updateValue(mouse.y)
                onPositionChanged: mouse => {
                    if (pressed)
                        updateValue(mouse.y);
                }
            }
        }
    }
}
