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

    Item {
        id: contentLayout
        width: isVertical ? verticalItems.width : horizontalItems.width
        height: isVertical ? verticalItems.height : horizontalItems.height
        anchors.centerIn: parent

        Loader {
            anchors.centerIn: parent
            sourceComponent: root.isVertical ? verticalLayout : horizontalLayout
        }
    }

    Component {
        id: horizontalLayout
        Row {
            id: horizontalItems
            spacing: Theme.spacingL
            
            Row {
                spacing: Theme.spacingM; anchors.verticalCenter: parent.verticalCenter
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

            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: DankActionButton {
                        iconName: modelData.icon; buttonSize: 36; iconSize: 18; tooltipText: modelData.tooltip
                        backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                        iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                        onClicked: root.toolSelected(modelData.id)
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
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

            Row {
                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: root.strokeWidth + "px"; width: 32; horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                }
                Slider {
                    id: hSlider; from: 1; to: 50; value: root.strokeWidth; width: 80; anchors.verticalCenter: parent.verticalCenter
                    onMoved: root.strokeWidthSelected(Math.round(value))
                    background: Rectangle {
                        implicitWidth: 80; implicitHeight: 4; radius: 2; color: Theme.withAlpha(Theme.outline, 0.3)
                        Rectangle { width: hSlider.visualPosition * parent.width; height: parent.height; color: Theme.primary; radius: 2 }
                    }
                    handle: Rectangle {
                        implicitWidth: 12; implicitHeight: 12; radius: 6; color: Theme.primary; border.color: Theme.surface; border.width: 1
                        x: hSlider.visualPosition * (hSlider.availableWidth - width)
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; onClicked: root.undoRequested() }
                
                Item {
                    id: hActionCombo
                    width: expanded ? (36 * 3 + 8) : 36
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property bool expanded: hComboMouseArea.containsMouse
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    
                    Row {
                        anchors.right: parent.right; spacing: 4
                        DankActionButton {
                            iconName: "save"; buttonSize: 36; iconSize: 18; tooltipText: "Save to File (Ctrl+S)"
                            visible: hActionCombo.expanded; opacity: hActionCombo.expanded ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: root.saveRequested()
                        }
                        DankActionButton {
                            iconName: "content_copy"; buttonSize: 36; iconSize: 18; tooltipText: "Copy to Clipboard (Ctrl+C)"
                            visible: hActionCombo.expanded; opacity: hActionCombo.expanded ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: root.copyRequested()
                        }
                        DankActionButton {
                            iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"
                            backgroundColor: Theme.withAlpha(Theme.primary, 0.15); iconColor: Theme.primary
                            onClicked: root.copyAndSaveRequested()
                        }
                    }
                    MouseArea { id: hComboMouseArea; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true; onClicked: m => m.accepted = false }
                }

                DankActionButton { iconName: "close"; buttonSize: 36; iconSize: 18; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
        }
    }

    Component {
        id: verticalLayout
        Column {
            id: verticalItems
            spacing: Theme.spacingL
            
            Column {
                spacing: Theme.spacingM; anchors.horizontalCenter: parent.horizontalCenter
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
                columns: 1; spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: DankActionButton {
                        iconName: modelData.icon; buttonSize: 36; iconSize: 18
                        backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                        iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                        onClicked: root.toolSelected(modelData.id)
                    }
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 2; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
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

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Column {
                spacing: Theme.spacingS; anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: root.strokeWidth + "px"; color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter
                }
                Slider {
                    id: vSlider; from: 1; to: 50; value: root.strokeWidth; width: 44; height: 80; orientation: Qt.Vertical
                    onMoved: root.strokeWidthSelected(Math.round(value))
                    background: Rectangle {
                        implicitWidth: 4; implicitHeight: 80; radius: 2; color: Theme.withAlpha(Theme.outline, 0.3); anchors.horizontalCenter: parent.horizontalCenter
                        Rectangle { width: parent.width; height: vSlider.visualPosition * parent.height; color: Theme.primary; radius: 2; anchors.bottom: parent.bottom }
                    }
                    handle: Rectangle {
                        implicitWidth: 12; implicitHeight: 12; radius: 6; color: Theme.primary; border.color: Theme.surface; border.width: 1
                        y: vSlider.visualPosition * (vSlider.availableHeight - height)
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Column {
                spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; onClicked: root.undoRequested() }
                
                Item {
                    id: vActionCombo
                    width: 36
                    height: expanded ? (36 * 3 + 8) : 36
                    anchors.horizontalCenter: parent.horizontalCenter
                    readonly property bool expanded: vComboMouseArea.containsMouse
                    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutQuad } }
                    
                    Column {
                        anchors.bottom: parent.bottom; spacing: 4
                        DankActionButton {
                            iconName: "save"; buttonSize: 36; iconSize: 18; tooltipText: "Save to File (Ctrl+S)"
                            visible: vActionCombo.expanded; opacity: vActionCombo.expanded ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: root.saveRequested()
                        }
                        DankActionButton {
                            iconName: "content_copy"; buttonSize: 36; iconSize: 18; tooltipText: "Copy to Clipboard (Ctrl+C)"
                            visible: vActionCombo.expanded; opacity: vActionCombo.expanded ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            onClicked: root.copyRequested()
                        }
                        DankActionButton {
                            iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"
                            backgroundColor: Theme.withAlpha(Theme.primary, 0.15); iconColor: Theme.primary
                            onClicked: root.copyAndSaveRequested()
                        }
                    }
                    MouseArea { id: vComboMouseArea; anchors.fill: parent; hoverEnabled: true; propagateComposedEvents: true; onClicked: m => m.accepted = false }
                }

                DankActionButton { iconName: "close"; buttonSize: 36; iconSize: 18; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
        }
    }
}
