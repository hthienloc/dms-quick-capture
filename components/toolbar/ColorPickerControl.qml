import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: control

    property string currentTool: ""

    signal customPickerRequested(var controlItem)
    signal drawPickerRequested()

    width: Constants.btnSize
    height: Constants.btnSize

    DankActionButton {
        anchors.fill: parent
        iconName: "colorize"
        buttonSize: Constants.btnSize
        iconSize: Constants.iconSize
        tooltipText: I18n.trFor("quickCapture", "Color Picker (F for RGB | Eyedropper)")
        backgroundColor: control.currentTool === "colorpicker" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
        iconColor: control.currentTool === "colorpicker" ? Theme.primary : Theme.surfaceText
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                control.drawPickerRequested();
            } else {
                control.customPickerRequested(control);
            }
        }
    }
}
