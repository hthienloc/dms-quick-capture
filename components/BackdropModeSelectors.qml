import QtQuick
import qs.Common
import qs.Widgets

Grid {
    id: controlRoot

    property string backdropMode: "none"
    property bool isVertical: false

    signal changeBackdropMode(string mode)

    ToolbarConstants { id: tc }

    rows: isVertical ? 5 : 1
    columns: isVertical ? 1 : 5
    spacing: Theme.spacingXS

    readonly property var modes: [
        { mode: "none", icon: "blur_off", tooltip: qsTr("No Backdrop") },
        { mode: "solid", icon: "format_color_fill", tooltip: qsTr("Solid Color") },
        { mode: "radial", icon: "filter_tilt_shift", tooltip: qsTr("Radial Gradient") },
        { mode: "gradient", icon: "gradient", tooltip: qsTr("Linear Gradient") },
        { mode: "conic", icon: "timelapse", tooltip: qsTr("Conic Gradient") }
    ]

    Repeater {
        model: controlRoot.modes
        delegate: DankActionButton {
            iconName: modelData.icon
            buttonSize: tc.btnSize
            iconSize: tc.iconSize
            tooltipText: modelData.tooltip
            backgroundColor: controlRoot.backdropMode === modelData.mode ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
            iconColor: controlRoot.backdropMode === modelData.mode ? Theme.primary : Theme.surfaceText
            onClicked: controlRoot.changeBackdropMode(modelData.mode)
        }
    }
}
