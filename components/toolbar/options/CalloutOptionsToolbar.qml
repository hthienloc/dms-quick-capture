import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    property int currentLinkLines: 1
    property string currentShape: "rect"

    signal linkLinesSelected(int count)
    signal shapeSelected(string shape)

    panelWidth: contentColumn.implicitWidth + Theme.spacingM * 2
    panelHeight: contentColumn.implicitHeight + Theme.spacingM * 2

    Column {
        id: contentColumn
        anchors.centerIn: parent
        spacing: Theme.spacingS

        // Row 1: Shape (Rectangle, Ellipse)
        Row {
            id: shapeRow
            spacing: Theme.spacingS
            Repeater {
                model: [
                    { icon: "crop_square", shape: "rect", tooltip: I18n.trFor("quickCapture", "Rectangle") },
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

        // Row 2: Connecting Lines (1 Line, 2 Lines)
        Row {
            id: linesRow
            spacing: Theme.spacingS
            Repeater {
                model: [
                    { icon: "remove", count: 1, tooltip: I18n.trFor("quickCapture", "1 Connecting Line") },
                    { icon: "density_medium", count: 2, tooltip: I18n.trFor("quickCapture", "2 Connecting Lines") }
                ]
                delegate: OptionToolbarButton {
                    iconName: modelData.icon
                    active: root.currentLinkLines === modelData.count
                    onClicked: {
                        root.linkLinesSelected(modelData.count);
                        root.close();
                    }
                }
            }
        }
    }
}
