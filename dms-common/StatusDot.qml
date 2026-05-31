import QtQuick
import qs.Common

Rectangle {
    id: root

    property bool active: false
    property color activeColor: Theme.success
    property color inactiveColor: Theme.surfaceVariant

    width: 8
    height: 8
    radius: 4
    color: root.active ? activeColor : inactiveColor
}