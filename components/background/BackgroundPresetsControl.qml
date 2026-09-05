import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: control

    signal hovered(var controlItem)
    signal exited()

    width: Constants.btnSize
    height: Constants.btnSize

    DankActionButton {
        iconName: "bookmarks"
        buttonSize: Constants.btnSize
        iconSize: Constants.iconSize
        tooltipText: I18n.trFor("quickCapture", "Background Presets")
        anchors.centerIn: parent
        onClicked: control.hovered(control)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: control.hovered(control)
        onExited: control.exited()
        onClicked: control.hovered(control)
    }
}
