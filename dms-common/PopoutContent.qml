import QtQuick
import qs.Common
import qs.Widgets

StyledRect {
    id: root
    width: 320
    height: contentColumn.implicitHeight + (Theme.spacingL * 2)
    radius: Theme.cornerRadius
    color: Theme.surfaceContainer

    default property alias content: contentColumn.data
    property alias spacing: contentColumn.spacing

    Column {
        id: contentColumn
        width: parent.width - (Theme.spacingL * 2)
        anchors.centerIn: parent
        spacing: Theme.spacingM
    }
}
