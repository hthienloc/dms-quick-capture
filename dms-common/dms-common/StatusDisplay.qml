import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root
    
    property string iconName: ""
    property string title: ""
    property string subtitle: ""
    property string infoText: ""
    property bool active: false
    property real progress: -1 // -1 means hidden
    property bool compact: true
    property bool large: false
    
    width: parent.width
    height: large ? 150 : (compact ? 50 : 110)
    radius: Theme.cornerRadius
    color: active ? Theme.primary : Theme.surfaceContainerHigh
    
    Behavior on color { ColorAnimation { duration: 200 } }

    // Use a Loader to switch between layouts. 
    // This ensures that when there is no icon, the layout is 100% clean 
    // and matches the stable centering logic from commit 775e344.
    
    Loader {
        anchors.centerIn: parent
        sourceComponent: (root.iconName && root.iconName !== "") ? iconLayout : textOnlyLayout
    }

    Component {
        id: textOnlyLayout
        Column {
            spacing: 2
            
            StyledText {
                text: root.title
                font.pixelSize: root.large ? 18 : (root.compact ? 12 : 14)
                font.weight: Font.Bold
                opacity: 0.8
                color: root.active ? Theme.onPrimary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
            }

            StyledText {
                text: root.subtitle
                visible: !root.compact || root.large
                font.pixelSize: root.large ? 64 : 32
                font.weight: Font.Bold
                color: root.active ? Theme.onPrimary : Theme.surfaceText
                anchors.horizontalCenter: parent.horizontalCenter
                isMonospace: true
            }

            StyledText {
                text: root.infoText
                visible: text !== "" && !root.compact
                font.pixelSize: 12
                color: root.active ? Theme.onPrimary : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    Component {
        id: iconLayout
        Row {
            spacing: root.large ? Theme.spacingL * 2 : Theme.spacingM
            
            DankIcon {
                name: root.iconName
                size: root.large ? 64 : (root.compact ? 24 : 48)
                color: root.active ? Theme.onPrimary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                
                StyledText {
                    text: root.title
                    font.pixelSize: root.large ? 18 : (root.compact ? 12 : 14)
                    font.weight: Font.Bold
                    opacity: 0.8
                    color: root.active ? Theme.onPrimary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.subtitle
                    visible: !root.compact || root.large
                    font.pixelSize: root.large ? 48 : 32
                    font.weight: Font.Bold
                    color: root.active ? Theme.onPrimary : Theme.surfaceText
                    anchors.horizontalCenter: parent.horizontalCenter
                    isMonospace: true
                }

                StyledText {
                    text: root.infoText
                    visible: text !== "" && !root.compact
                    font.pixelSize: 12
                    color: root.active ? Theme.onPrimary : Theme.surfaceVariantText
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    // Bottom progress bar (shown when compact or as a second option)
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, root.progress))
        height: 4
        color: root.active ? Theme.onPrimary : Theme.primary
        visible: root.progress >= 0 && (root.compact || !root.large)
        opacity: 0.8
        radius: 2
    }
}
