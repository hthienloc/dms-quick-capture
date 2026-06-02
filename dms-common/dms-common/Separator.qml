import QtQuick
import qs.Common

Rectangle {
    width: parent.width
    height: 1
    color: Theme.outline
    opacity: 0.2 // Tăng từ 0.1 lên 0.2 để rõ ràng hơn
    
    property real leftMargin: 0
    property real rightMargin: 0
    
    anchors {
        left: parent.left
        right: parent.right
        leftMargin: leftMargin
        rightMargin: rightMargin
    }
}
