import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    property string currentMode: "solid"
    property string currentShape: "rect"

    signal modeSelected(string mode)
    signal shapeSelected(string shape)

    panelWidth: Math.max(modeRow.implicitWidth, shapeRow.implicitWidth) + Theme.spacingM * 2
    panelHeight: Constants.subToolbarHeight * 2 + Theme.spacingS

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS

        Row {
            id: modeRow
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { icon: "square", mode: "solid", tooltip: I18n.trFor("quickCapture", "Solid Fill") },
                    { icon: "auto_fix_high", mode: "clean", tooltip: I18n.trFor("quickCapture", "Clean Text Eraser") }
                ]

                delegate: OptionToolbarButton {
                    iconName: modelData.icon
                    active: root.currentMode === modelData.mode
                    onClicked: {
                        root.modeSelected(modelData.mode);
                        root.close();
                    }
                }
            }
        }

        Row {
            id: shapeRow
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { icon: "crop_square", shape: "rect", tooltip: I18n.trFor("quickCapture", "Rectangle") },
                    { icon: "rounded_corner", shape: "roundRect", tooltip: I18n.trFor("quickCapture", "Rounded Rectangle") },
                    { icon: "circle", shape: "ellipse", tooltip: I18n.trFor("quickCapture", "Ellipse") }
                ]

                delegate: OptionToolbarButton {
                    iconName: modelData.icon
                    active: root.currentShape === modelData.shape
                    onClicked: {
                        root.shapeSelected(modelData.shape);
                        root.close();
                    }
                }
            }
        }
    }
}
