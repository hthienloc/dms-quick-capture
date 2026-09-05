import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Grid {
    id: controlRoot

    property string backgroundMode: "none"
    property bool isVertical: false

    signal changeBackgroundMode(string mode, var controlItem)

    rows: isVertical ? 6 : 1
    columns: isVertical ? 1 : 6
    spacing: Theme.spacingXS

    readonly property var modes: [
        { mode: "none", icon: "blur_off", tooltip: I18n.trFor("quickCapture", "No Background") },
        { mode: "solid", icon: "format_color_fill", tooltip: I18n.trFor("quickCapture", "Solid Color") },
        { mode: "radial", icon: "filter_tilt_shift", tooltip: I18n.trFor("quickCapture", "Radial Gradient") },
        { mode: "gradient", icon: "gradient", tooltip: I18n.trFor("quickCapture", "Linear Gradient") },
        { mode: "conic", icon: "timelapse", tooltip: I18n.trFor("quickCapture", "Conic Gradient") },
        { mode: "image", icon: "image", tooltip: I18n.trFor("quickCapture", "Image Background") }
    ]

    Repeater {
        model: controlRoot.modes
        delegate: DankActionButton {
            id: modeButton
            iconName: modelData.icon
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: modelData.tooltip
            backgroundColor: controlRoot.backgroundMode === modelData.mode ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
            iconColor: controlRoot.backgroundMode === modelData.mode ? Theme.primary : Theme.surfaceText
            onClicked: controlRoot.changeBackgroundMode(modelData.mode, modeButton)
        }
    }
}
