import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root
    width: parent.width
    height: contentColumn.implicitHeight + (Theme.spacingL * 2)
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer


    default property alias content: contentColumn.data
    property alias spacing: contentColumn.spacing

    // Called by PluginSettings.onPluginServiceChanged to reload nested settings
    function loadValue() {
        for (let i = 0; i < contentColumn.children.length; i++) {
            const child = contentColumn.children[i];
            if (child.loadValue) {
                child.loadValue();
            }
        }
    }

    Column {
        id: contentColumn
        width: parent.width - (Theme.spacingL * 2)
        anchors.centerIn: parent
        spacing: Theme.spacingM
    }
}
