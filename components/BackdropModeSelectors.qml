import QtQuick
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Grid {
    id: controlRoot

    property string backdropMode: "none"
    property bool isVertical: false

    signal changeBackdropMode(string mode)

    rows: isVertical ? 5 : 1
    columns: isVertical ? 1 : 5
    spacing: Theme.spacingXS

    readonly property var modes: [
        { mode: "none", icon: "blur_off", tooltip: I18n.tr("No Backdrop") },
        { mode: "solid", icon: "format_color_fill", tooltip: I18n.tr("Solid Color") },
        { mode: "radial", icon: "filter_tilt_shift", tooltip: I18n.tr("Radial Gradient") },
        { mode: "gradient", icon: "gradient", tooltip: I18n.tr("Linear Gradient") },
        { mode: "conic", icon: "timelapse", tooltip: I18n.tr("Conic Gradient") }
    ]

    Repeater {
        model: controlRoot.modes
        delegate: DankActionButton {
            iconName: modelData.icon
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: modelData.tooltip
            backgroundColor: controlRoot.backdropMode === modelData.mode ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
            iconColor: controlRoot.backdropMode === modelData.mode ? Theme.primary : Theme.surfaceText
            onClicked: controlRoot.changeBackdropMode(modelData.mode)
        }
    }
}
