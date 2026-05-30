import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../lib"

Rectangle {
    id: root

    QuickCaptureConfig { id: config }

    property string currentTool: "crop"
    property color currentColor: Theme.primary
    property int strokeWidth: 8
    property bool canUndo: false
    property bool isVertical: false

    signal toolSelected(string tool)
    signal colorSelected(var color)
    signal strokeWidthSelected(int width)
    signal undoRequested()
    signal saveRequested()
    signal copyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()

    width: isVertical ? 56 : (contentLayout.width + Theme.spacingM * 2)
    height: isVertical ? (contentLayout.height + Theme.spacingM * 2) : 56
    radius: Theme.cornerRadius
    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1

    // Main Layout (Vertical or Horizontal)
    Column {
        id: contentLayout
        anchors.centerIn: parent
        spacing: Theme.spacingL
        rotation: root.isVertical ? 0 : -90 // We rotate the whole thing? No, better use Column vs Row

        visible: false // Helper for measuring
    }
    
    // We use a simple conditional wrapper
    Item {
        anchors.fill: parent
        
        Loader {
            anchors.centerIn: parent
            sourceComponent: root.isVertical ? verticalItems : horizontalItems
        }
    }

    Component {
        id: horizontalItems
        Row {
            spacing: Theme.spacingL
            
            // Left Group
            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                DankActionButton {
                    iconName: "near_me"; buttonSize: 36; iconSize: 18; tooltipText: "Select (V)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18; tooltipText: "Crop (P)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Tools
            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: DankActionButton {
                        iconName: modelData.icon; buttonSize: 32; iconSize: 16; tooltipText: modelData.tooltip
                        backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                        iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                        onClicked: root.toolSelected(modelData.id)
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Colors
            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: [Theme.primary].concat(config.accentColors)
                    delegate: Rectangle {
                        width: 24; height: 24; radius: 12; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: Qt.colorEqual(root.currentColor, modelData) ? 2 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Actions
            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "undo"; buttonSize: 32; enabled: root.canUndo; onClicked: root.undoRequested() }
                DankActionButton { iconName: "save"; buttonSize: 32; onClicked: root.saveRequested() }
                DankActionButton { iconName: "content_copy"; buttonSize: 32; onClicked: root.copyRequested() }
                DankActionButton { iconName: "close"; buttonSize: 32; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
        }
    }

    Component {
        id: verticalItems
        Column {
            spacing: Theme.spacingL
            
            Column {
                spacing: Theme.spacingM
                anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton {
                    iconName: "near_me"; buttonSize: 36; iconSize: 18
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 1; spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: DankActionButton {
                        iconName: modelData.icon; buttonSize: 28; iconSize: 14
                        backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                        iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                        onClicked: root.toolSelected(modelData.id)
                    }
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 2; spacing: 6
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: [Theme.primary].concat(config.accentColors)
                    delegate: Rectangle {
                        width: 18; height: 18; radius: 9; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Column {
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton { iconName: "undo"; buttonSize: 32; enabled: root.canUndo; onClicked: root.undoRequested() }
                DankActionButton { iconName: "save"; buttonSize: 32; onClicked: root.saveRequested() }
                DankActionButton { iconName: "content_copy"; buttonSize: 32; onClicked: root.copyRequested() }
                DankActionButton { iconName: "close"; buttonSize: 32; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
        }
    }
}
