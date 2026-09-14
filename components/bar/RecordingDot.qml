import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool paused: false
    property bool blink: true
    property real dotSize: 8

    width: dotSize
    height: dotSize
    radius: dotSize / 2
    color: paused ? Theme.warning : Theme.error

    SequentialAnimation on opacity {
        running: root.visible && !root.paused && root.blink
        loops: Animation.Infinite
        NumberAnimation {
            to: 0.35
            duration: 800
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1.0
            duration: 800
            easing.type: Easing.InOutSine
        }
        onRunningChanged: if (!running)
            root.opacity = 1.0
    }
}
