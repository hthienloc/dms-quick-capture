import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: popoverRoot

    ToolbarConstants { id: tc }

    property string backdropAlignment: "center"
    property bool opened: false

    signal changeBackdropAlignment(string alignment)

    // 9 positions in row-major order (top → bottom, left → right)
    readonly property var _positions: [
        "top-left",    "top-center",    "top-right",
        "center-left", "center",        "center-right",
        "bottom-left", "bottom-center", "bottom-right"
    ]

    readonly property int _cellSize: 20
    readonly property int _cellSpacing: 4
    readonly property int _gridSize: 3 * _cellSize + 2 * _cellSpacing
    readonly property int _padding: 12

    width: _gridSize + _padding * 2
    height: _gridSize + _padding * 2
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
        anchors.fill: parent
        hoverEnabled: true
        onEntered: popoverRoot.open()
        onExited: popoverRoot.startCloseTimer()

        Grid {
            columns: 3
            rows: 3
            spacing: popoverRoot._cellSpacing
            anchors.centerIn: parent

            Repeater {
                model: popoverRoot._positions
                delegate: Rectangle {
                    required property string modelData
                    required property int index

                    width: popoverRoot._cellSize
                    height: popoverRoot._cellSize
                    radius: 3

                    readonly property bool active: modelData === popoverRoot.backdropAlignment

                    color: active ? Theme.primary : Theme.withAlpha(Theme.surfaceVariant, 0.4)
                    border.color: active ? "transparent" : Theme.withAlpha(Theme.outline, 0.2)
                    border.width: 1

                    // Dot indicator showing alignment anchor position
                    readonly property int _dotCol: index % 3   // 0=left 1=center 2=right
                    readonly property int _dotRow: Math.floor(index / 3) // 0=top 1=center 2=bottom
                    readonly property real _dotX: (_dotCol === 0 ? 0.2 : _dotCol === 1 ? 0.5 : 0.8)
                    readonly property real _dotY: (_dotRow === 0 ? 0.2 : _dotRow === 1 ? 0.5 : 0.8)

                    Rectangle {
                        x: parent._dotX * parent.width - width / 2
                        y: parent._dotY * parent.height - height / 2
                        width: 4
                        height: 4
                        radius: 2
                        color: parent.active ? Theme.onPrimary : Theme.surfaceVariantText
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: popoverRoot.changeBackdropAlignment(modelData)
                    }
                }
            }
        }
    }
}
