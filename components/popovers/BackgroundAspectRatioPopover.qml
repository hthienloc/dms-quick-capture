import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

PopoverSurface {
    id: popoverRoot

    property string backgroundAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property real customRatioMin: 0.50
    property real customRatioMax: 2.50
    property var presets: []
    signal changeBackgroundAspectRatio(string ratio)
    signal changeCustomAspectRatio(real ratio)

    readonly property bool customActive: backgroundAspectRatio === "custom"
    readonly property int _sliderMin: Math.round(customRatioMin * 100)
    readonly property int _sliderMax: Math.round(customRatioMax * 100)

    width: 220
    height: customActive ? Constants.customRatioPopoverHeight : Constants.popoverHeight
    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: popoverRoot.open()
        onExited: popoverRoot.startCloseTimer()

        onWheel: (wheel) => {
            if (popoverRoot.customActive) {
                let step = wheel.angleDelta.y > 0 ? 5 : -5;
                let scaled = Math.round(popoverRoot.customAspectRatio * 100) + step;
                let newVal = Math.max(popoverRoot._sliderMin, Math.min(popoverRoot._sliderMax, scaled)) / 100.0;
                popoverRoot.changeCustomAspectRatio(newVal);
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.spacingS
            width: parent.width - Theme.spacingS * 2

            Grid {
                columns: 4
                rows: 2
                spacing: Constants.gridSpacing
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: popoverRoot.presets
                    delegate: Rectangle {
                        required property var modelData
                        width: Constants.presetBtnWidth
                        height: Constants.presetBtnHeight
                        radius: Theme.cornerRadius / 2
                        color: popoverRoot.backgroundAspectRatio === modelData.value ? Theme.primary : Theme.withAlpha(Theme.surfaceVariant, 0.4)
                        border.color: popoverRoot.backgroundAspectRatio === modelData.value ? "transparent" : Theme.withAlpha(Theme.outline, 0.15)
                        border.width: 1

                        StyledText {
                            text: modelData.label
                            font.pixelSize: Constants.presetFontSize
                            font.weight: popoverRoot.backgroundAspectRatio === modelData.value ? Font.DemiBold : Font.Normal
                            color: popoverRoot.backgroundAspectRatio === modelData.value ? Theme.onPrimary : Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popoverRoot.changeBackgroundAspectRatio(modelData.value)
                        }
                    }
                }
            }


            // Slider section (Visible only when custom is active)
            Item {
                id: sliderSection
                visible: popoverRoot.customActive
                width: parent.width
                height: Math.max(ratioText.implicitHeight, slider.implicitHeight, valueText.implicitHeight)

                StyledText {
                    id: ratioText
                    text: I18n.trFor("quickCapture", "Ratio")
                    font.pixelSize: Constants.fontSizeCompact
                    color: Theme.surfaceVariantText
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    id: valueText
                    text: popoverRoot.customAspectRatio.toFixed(2)
                    font.pixelSize: Constants.fontSizeCompact
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: slider
                    minimum: popoverRoot._sliderMin
                    maximum: popoverRoot._sliderMax
                    anchors.left: ratioText.right
                    anchors.right: valueText.left
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    showValue: false
                    onSliderValueChanged: val => popoverRoot.changeCustomAspectRatio(val / 100.0)
                    anchors.verticalCenter: parent.verticalCenter

                    Binding {
                        target: slider
                        property: "value"
                        value: Math.round(popoverRoot.customAspectRatio * 100)
                    }
                }
            }
        }
    }
}
