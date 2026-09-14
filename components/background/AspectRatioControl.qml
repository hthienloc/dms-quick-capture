import QtQuick
import qs.Common
import "../core/Constants.js" as Constants

BackgroundMetricControl {
    id: control

    property string backgroundAspectRatio: "auto"
    property real customAspectRatio: 1.50

    iconName: "aspect_ratio"
    iconSize: Constants.iconSize
    valueWidth: 46
    valueText: {
        if (backgroundAspectRatio === "auto")
            return I18n.trFor("quickCapture", "Auto").toUpperCase();
        if (backgroundAspectRatio === "custom")
            return customAspectRatio.toFixed(2);
        return backgroundAspectRatio;
    }
}
