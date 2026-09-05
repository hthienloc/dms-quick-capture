import QtQuick
import qs.Common
import qs.Widgets
import "../core/Constants.js" as Constants

Item {
    id: control

    property var toolButtons: []
    property string currentTool: ""
    property bool showShortcutHints: false
    property bool compact: false

    signal toolSelected(string tool)
    signal moreToolsClicked(var controlItem)

    width: content.implicitWidth
    height: content.implicitHeight

    Grid {
        id: content
        columns: control.compact ? 1 : control.toolButtons.length + 1
        spacing: Theme.spacingXS
        anchors.centerIn: parent

        Repeater {
            model: control.toolButtons
            delegate: Item {
                width: Constants.btnSize
                height: Constants.btnSize

                DankShortcutActionButton {
                    anchors.fill: parent
                    iconName: modelData.icon
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: modelData.tooltip
                    backgroundColor: control.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: control.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                    shortcutText: modelData.shortcut || ""
                    showShortcut: control.showShortcutHints
                    onClicked: control.toolSelected(modelData.id)
                }
            }
        }

        DankActionButton {
            id: moreActionsButton
            iconName: control.compact ? "more_vert" : "more_horiz"
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
            tooltipText: I18n.trFor("quickCapture", "More Tools")
            onClicked: control.moreToolsClicked(moreActionsButton)
        }
    }
}
