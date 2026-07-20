import QtQuick
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Item {
    id: root
    z: 2000
    anchors.fill: parent

    property bool visibleState: false
    visible: opacity > 0
    opacity: 0

    property real menuX: 0
    property real menuY: 0

    // States for options
    property bool boldActive: false
    property bool italicActive: false
    property bool underlineActive: false
    property bool backgroundActive: false
    property string toolbarPosition: "top"

    signal boldToggled()
    signal italicToggled()
    signal underlineToggled()
    signal backgroundToggled()

    states: [
        State {
            name: "visible"
            when: root.visibleState
            PropertyChanges { target: root; opacity: 1.0 }
            PropertyChanges { target: menuContent; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { target: root; property: "opacity"; duration: 120; easing.type: Easing.OutQuad }
            NumberAnimation { target: menuContent; property: "scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open(x, y) {
        root.menuX = x;
        root.menuY = y;
        root.visibleState = true;
    }

    function close() {
        root.visibleState = false;
    }

    // Scrim overlay to dismiss when clicking outside
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: (mouse) => {
            root.close();
            mouse.accepted = false;
        }
    }

    Rectangle {
        id: menuContent
        width: contentRow.implicitWidth + Theme.spacingM * 2
        height: Constants.subToolbarHeight
        x: Math.max(10, Math.min(root.width - width - 10, root.menuX - width / 2))
        y: {
            if (root.toolbarPosition === "bottom") {
                return Math.max(10, Math.min(root.height - height - 10, root.menuY - height - 20));
            } else {
                return Math.max(10, Math.min(root.height - height - 10, root.menuY + 20));
            }
        }
        scale: 0.95

        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1
        radius: Theme.cornerRadius
        
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Repeater {
                model: [
                    { icon: "format_bold", active: root.boldActive, tag: "bold" },
                    { icon: "format_italic", active: root.italicActive, tag: "italic" },
                    { icon: "format_underlined", active: root.underlineActive, tag: "underline" },
                    { icon: "layers", active: root.backgroundActive, tag: "bg" }
                ]

                delegate: Rectangle {
                    width: Constants.subToolbarBtnSize
                    height: Constants.subToolbarBtnSize
                    radius: Theme.cornerRadius - 2
                    color: modelData.active 
                        ? Theme.withAlpha(Theme.primary, 0.15) 
                        : (itemMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                    border.color: modelData.active ? Theme.primary : "transparent"
                    border.width: 1

                    DankIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: Constants.subToolbarIconSize
                        color: modelData.active ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (modelData.tag === "bold") root.boldToggled();
                            else if (modelData.tag === "italic") root.italicToggled();
                            else if (modelData.tag === "underline") root.underlineToggled();
                            else if (modelData.tag === "bg") root.backgroundToggled();
                        }
                    }
                }
            }
        }
    }
}
