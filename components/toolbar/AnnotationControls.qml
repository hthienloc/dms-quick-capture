import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: control

    property string currentTool: "select"
    property bool showAnnotations: true
    property bool compact: false

    signal toolSelected(string tool)
    signal annotationsToggled

    width: content.implicitWidth
    height: content.implicitHeight

    Grid {
        id: content
        columns: control.compact ? 1 : 3
        spacing: Theme.spacingXS
        anchors.centerIn: parent

        DankActionButton {
            iconName: "near_me"
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: I18n.trFor("quickCapture", "Select") + " (Tab)"
            backgroundColor: control.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
            iconColor: control.currentTool === "select" ? Theme.primary : Theme.surfaceText
            onClicked: control.toolSelected("select")
        }

        DankActionButton {
            iconName: control.showAnnotations ? "visibility" : "visibility_off"
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: (control.showAnnotations ? I18n.trFor("quickCapture", "Hide Annotations") : I18n.trFor("quickCapture", "Show Annotations")) + " (X)"
            iconColor: control.showAnnotations ? Theme.primary : Theme.surfaceText
            backgroundColor: "transparent"
            onClicked: control.annotationsToggled()
        }

        DankActionButton {
            iconName: "crop"
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: I18n.trFor("quickCapture", "Crop / Resize") + " (Ctrl+X)"
            backgroundColor: control.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
            iconColor: control.currentTool === "crop" ? Theme.primary : Theme.surfaceText
            onClicked: control.toolSelected("crop")
        }
    }
}
