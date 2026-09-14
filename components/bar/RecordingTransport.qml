import QtQuick
import qs.Common
import qs.Widgets

Grid {
    id: root

    property var recorder: null
    property bool vertical: false
    property int buttonSize: 34
    property int iconSize: 18
    property bool filled: false
    property bool showCancel: true
    readonly property bool paused: recorder?.isPaused ?? false

    signal actionTriggered(string action)

    columns: vertical ? 1 : 3
    spacing: filled ? Theme.spacingXS : Theme.spacingM
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    DankActionButton {
        visible: root.recorder?.isPauseSupported ?? true
        iconName: root.paused ? "play_arrow" : "pause"
        buttonSize: root.buttonSize
        iconSize: root.iconSize
        backgroundColor: root.filled ? (root.paused ? Theme.withAlpha(Theme.primary, 0.1) : Theme.primary) : "transparent"
        iconColor: root.filled && !root.paused ? Theme.background : Theme.primary
        tooltipText: root.paused ? I18n.trFor("quickCapture", "Resume") : I18n.trFor("quickCapture", "Pause")
        onClicked: {
            root.actionTriggered("pause");
            root.recorder?.pauseRecording();
        }
    }

    DankActionButton {
        iconName: "stop"
        buttonSize: root.buttonSize
        iconSize: root.iconSize
        backgroundColor: root.filled ? Theme.error : "transparent"
        iconColor: root.filled ? Theme.background : Theme.error
        tooltipText: I18n.trFor("quickCapture", "Stop & Save")
        onClicked: {
            root.actionTriggered("stop");
            root.recorder?.stopRecording();
        }
    }

    DankActionButton {
        visible: root.showCancel
        iconName: "close"
        buttonSize: root.buttonSize
        iconSize: root.iconSize
        iconColor: Theme.surfaceVariantText
        tooltipText: I18n.trFor("quickCapture", "Cancel")
        onClicked: {
            root.actionTriggered("cancel");
            root.recorder?.cancelRecording();
        }
    }
}
