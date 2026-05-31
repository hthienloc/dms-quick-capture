import QtQuick
import qs.Common

Column {
    id: root
    width: parent.width
    spacing: Theme.spacingS
    
    property bool showHints: true
    visible: showHints && children.length > 0
}
