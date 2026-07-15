import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root
    z: 2000
    anchors.fill: parent

    ToolbarConstants { id: tc }

    property bool visibleState: false
    visible: opacity > 0
    opacity: 0

    property real menuX: 0
    property real menuY: 0

    property string currentStyle: "solid"
    property string toolbarPosition: "top"

    signal styleSelected(string style)

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
        height: tc.subToolbarHeight
        x: Math.max(10, Math.min(root.width - width - 10, root.menuX - width / 2))
        y: root.toolbarPosition === "bottom"
            ? Math.max(10, Math.min(root.height - height - 10, root.menuY - height - 20))
            : Math.max(10, Math.min(root.height - height - 10, root.menuY + 20))
        scale: 0.95

        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1
        radius: Theme.cornerRadius
        
        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            // Group: Line Styles (Solid, Dashed, Dotted)
            Repeater {
                model: [
                    { icon: "line_weight", style: "solid", tooltip: qsTr("Solid Line") },
                    { icon: "border_style", style: "dashed", tooltip: qsTr("Dashed Line") },
                    { icon: "more_horiz", style: "dotted", tooltip: qsTr("Dotted Line") }
                ]

                delegate: Rectangle {
                    width: tc.subToolbarBtnSize; height: tc.subToolbarBtnSize
                    radius: Theme.cornerRadius - 2
                    color: root.currentStyle === modelData.style 
                        ? Theme.withAlpha(Theme.primary, 0.15) 
                        : (styleMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                    border.color: root.currentStyle === modelData.style ? Theme.primary : "transparent"
                    border.width: 1

                    DankIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: tc.subToolbarIconSize
                        color: root.currentStyle === modelData.style ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: styleMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.styleSelected(modelData.style);
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
