import QtQuick
import qs.Common
import "../../core/Constants.js" as Constants

OptionToolbarPopup {
    id: root

    property string currentStyle: "solid"

    signal styleSelected(string style)

    panelWidth: contentRow.implicitWidth + Theme.spacingM * 2
    panelHeight: Constants.subToolbarHeight

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Theme.spacingS

        // Group: Line Styles (Solid, Dashed, Dotted)
        Repeater {
            model: [
                { icon: "line_weight", style: "solid", tooltip: I18n.trFor("quickCapture", "Solid Line") },
                { icon: "border_style", style: "dashed", tooltip: I18n.trFor("quickCapture", "Dashed Line") },
                { icon: "more_horiz", style: "dotted", tooltip: I18n.trFor("quickCapture", "Dotted Line") }
            ]

            delegate: OptionToolbarButton {
                iconName: modelData.icon
                active: root.currentStyle === modelData.style
                onClicked: {
                    root.styleSelected(modelData.style);
                    root.close();
                }
            }
        }
    }
}
