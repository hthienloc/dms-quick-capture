import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: popoverRoot

    property string backdropAspectRatio: "auto"
    property real customAspectRatio: 1.50
    property bool opened: false

    signal changeBackdropAspectRatio(string ratio)
    signal changeCustomAspectRatio(real ratio)

    readonly property bool customActive: backdropAspectRatio === "custom"

    width: customActive ? 340 : 220
    height: 72
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
    z: 10001

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
            if (popoverRoot.customActive) {
                let step = wheel.angleDelta.y > 0 ? 5 : -5;
                let newVal = Math.max(50, Math.min(250, Math.round(popoverRoot.customAspectRatio * 100) + step));
                popoverRoot.changeCustomAspectRatio(newVal / 100.0);
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.spacingM
            leftPadding: Theme.spacingS
            rightPadding: Theme.spacingS

            Grid {
                columns: 4
                rows: 2
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter

                readonly property var presets: [
                    { value: "auto", label: "AUTO" },
                    { value: "1:1", label: "1:1" },
                    { value: "16:9", label: "16:9" },
                    { value: "9:16", label: "9:16" },
                    { value: "4:3", label: "4:3" },
                    { value: "3:2", label: "3:2" },
                    { value: "21:9", label: "21:9" },
                    { value: "custom", label: "CUST" }
                ]

                Repeater {
                    model: parent.presets
                    delegate: Rectangle {
                        width: 44
                        height: 24
                        radius: Theme.cornerRadiusXS
                        color: popoverRoot.backdropAspectRatio === modelData.value ? Theme.primary : Theme.withAlpha(Theme.surfaceVariant, 0.4)
                        border.color: popoverRoot.backdropAspectRatio === modelData.value ? "transparent" : Theme.withAlpha(Theme.outline, 0.15)
                        border.width: 1

                        StyledText {
                            text: modelData.label
                            font.pixelSize: 10
                            font.weight: popoverRoot.backdropAspectRatio === modelData.value ? Font.DemiBold : Font.Normal
                            color: popoverRoot.backdropAspectRatio === modelData.value ? Theme.onPrimary : Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: popoverRoot.changeBackdropAspectRatio(modelData.value)
                        }
                    }
                }
            }

            // Separator when custom is active
            Rectangle {
                visible: popoverRoot.customActive
                width: 1
                height: 36
                color: Theme.withAlpha(Theme.outline, 0.2)
                anchors.verticalCenter: parent.verticalCenter
            }

            // Slider section (Visible only when custom is active)
            Row {
                id: sliderSection
                visible: popoverRoot.customActive
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                Column {
                    spacing: 2
                    anchors.verticalCenter: parent.verticalCenter

                    StyledText {
                        text: "Ratio"
                        font.pixelSize: 8
                        color: Theme.surfaceVariantText
                    }

                    DankSlider {
                        id: slider
                        minimum: 50
                        maximum: 250
                        width: 100
                        value: Math.round(popoverRoot.customAspectRatio * 100)
                        showValue: false
                        onSliderValueChanged: val => popoverRoot.changeCustomAspectRatio(val / 100.0)
                    }
                }

                StyledText {
                    text: popoverRoot.customAspectRatio.toFixed(2)
                    font.pixelSize: 13
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
