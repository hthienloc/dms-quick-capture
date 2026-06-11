import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import ".."

Rectangle {
    id: root

    property var pluginData: ({})
    CaptureConfig { id: config; pluginData: root.pluginData }

    property string currentTool: "crop"
    property string activeToolType: currentTool
    property color currentColor: Theme.primary
    property int strokeWidth: 8
    property bool canUndo: false
    property bool isVertical: false
    property bool showAnnotations: true

    readonly property var toolbarPalette: {
        const p1 = root.pluginData["toolbar_color_primary"] || "primary";
        const slot1 = p1 === "primary" ? Theme.primary : p1;
        return [slot1].concat(config.accentColors);
    }

    signal toolSelected(string tool)
    signal colorSelected(var color)
    signal strokeWidthSelected(int width)
    signal undoRequested()
    signal floatRequested()
    signal saveRequested()
    signal copyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()

    width: isVertical ? 56 : (contentLayout.width + Theme.spacingM * 2)
    height: isVertical ? (contentLayout.height + Theme.spacingM * 2) : 56
    radius: Theme.cornerRadius

    readonly property bool showBorder: root.pluginData["showToolbarBorder"] ?? false

    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: showBorder ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
    border.width: showBorder ? 2 : 1

    Item {
        id: contentLayout
        width: toolbarLoader.item ? toolbarLoader.item.width : 0
        height: toolbarLoader.item ? toolbarLoader.item.height : 0
        anchors.centerIn: parent

        Loader {
            id: toolbarLoader
            anchors.centerIn: parent
            sourceComponent: root.isVertical ? verticalLayout : horizontalLayout
        }
    }

    Component {
        id: horizontalLayout
        Row {
            id: horizontalItems
            spacing: Theme.spacingL
            
            // Left Group
            Row {
                spacing: Theme.spacingM; anchors.verticalCenter: parent.verticalCenter
                DankActionButton {
                    iconName: "near_me"; buttonSize: 36; iconSize: 18; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: 36; iconSize: 18
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.showAnnotations = !root.showAnnotations
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18; tooltipText: "Crop (Ctrl+X)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Tools
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

            // Colors
            Grid {
                rows: 2; columns: 4; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: root.toolbarPalette
                    delegate: Rectangle {
                        width: 20; height: 20; radius: 10; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: Qt.colorEqual(root.currentColor, modelData) ? 2 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Thickness Section
            Row {
                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: {
                        if (root.activeToolType === "spotlight") {
                            const op = Math.round((Math.min(0.9, 0.2 + (root.strokeWidth / 50.0) * 0.65)) * 100);
                            return op + "%";
                        }
                        return root.strokeWidth + "px";
                    }
                    width: 32; horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                }
                DankSlider {
                    id: hSlider
                    minimum: root.activeToolType === "pixelate" ? 2 : 1
                    maximum: root.activeToolType === "pixelate" ? 12 : (root.activeToolType === "text" ? 72 : 50)
                    width: 100
                    height: 36
                    showValue: false
                    onSliderValueChanged: newValue => root.strokeWidthSelected(newValue)
                    anchors.verticalCenter: parent.verticalCenter

                    Binding {
                        target: hSlider
                        property: "value"
                        value: root.strokeWidth
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Actions
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; onClicked: root.undoRequested() }
                DankActionButton { iconName: "picture_in_picture"; buttonSize: 36; iconSize: 18; tooltipText: "Float Window (Ctrl+F)"; onClicked: root.floatRequested() }
                DankActionButton { iconName: "save"; buttonSize: 36; iconSize: 18; tooltipText: "Save to File (Ctrl+S)"; onClicked: root.saveRequested() }
                DankActionButton { iconName: "content_copy"; buttonSize: 36; iconSize: 18; tooltipText: "Copy to Clipboard (Ctrl+C)"; onClicked: root.copyRequested() }
                DankActionButton { iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"; backgroundColor: Theme.withAlpha(Theme.primary, 0.1); iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
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
                    iconName: "near_me"; buttonSize: 36; iconSize: 18; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: 36; iconSize: 18
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.showAnnotations = !root.showAnnotations
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18; tooltipText: "Crop (Ctrl+X)"
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
                    model: root.toolbarPalette
                    delegate: Rectangle {
                        width: 18; height: 18; radius: 9; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            // Thickness Text Only
            Text {
                text: {
                    if (root.activeToolType === "spotlight") {
                        const op = Math.round((Math.min(0.9, 0.2 + (root.strokeWidth / 50.0) * 0.65)) * 100);
                        return op + "%";
                    }
                    return root.strokeWidth + "px";
                }
                color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Column {
                spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; onClicked: root.undoRequested() }
                DankActionButton { iconName: "picture_in_picture"; buttonSize: 36; iconSize: 18; tooltipText: "Float Window (Ctrl+F)"; onClicked: root.floatRequested() }
                DankActionButton { iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"; backgroundColor: Theme.withAlpha(Theme.primary, 0.1); iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
                DankActionButton { iconName: "close"; buttonSize: 36; iconSize: 18; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
        }
    }
}
