import QtQuick
import "../core/Constants.js" as Constants

BackgroundMetricControl {
    id: control

    property string backgroundAlignment: "center"

    readonly property var labels: ({
            "top-left": "TL",
            "top-center": "TC",
            "top-right": "TR",
            "center-left": "CL",
            "center": "C",
            "center-right": "CR",
            "bottom-left": "BL",
            "bottom-center": "BC",
            "bottom-right": "BR"
        })

    iconName: "align_justify_center"
    iconSize: Constants.iconSize
    valueWidth: 22
    valueText: labels[backgroundAlignment] ?? "C"
}
