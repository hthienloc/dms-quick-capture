import QtQuick
import qs.Common
import qs.Widgets
import ".."

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

    property string currentLineStyle: "solid"
    property string currentHeadStyle: "single-filled"
    property string toolbarPosition: "top"

    signal lineStyleSelected(string style)
    signal headStyleSelected(string style)

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
        width: contentColumn.implicitWidth + Theme.spacingM * 2
        height: contentColumn.implicitHeight + Theme.spacingM * 2
        x: Math.max(10, Math.min(root.width - width - 10, root.menuX - width / 2))
        y: root.toolbarPosition === "bottom"
            ? Math.max(10, Math.min(root.height - height - 10, root.menuY - height - 20))
            : Math.max(10, Math.min(root.height - height - 10, root.menuY + 20))
        scale: 0.95

        color: Theme.surfaceContainer
        border.color: Theme.withAlpha(Theme.outline, 0.15)
        border.width: 1
        radius: Theme.cornerRadius
        
        Column {
            id: contentColumn
            anchors.centerIn: parent
            spacing: Theme.spacingS

            // Top Row: Arrow Head Styles (Filled, Open, Double)
            Row {
                id: headRow
                spacing: Theme.spacingS
                Repeater {
                    model: [
                        { icon: "trending_flat", style: "single-filled" },
                        { icon: "chevron_right", style: "single-open" },
                        { icon: "swap_horiz", style: "double-filled" }
                    ]

                    delegate: Rectangle {
                        width: tc.subToolbarBtnSize; height: tc.subToolbarBtnSize
                        radius: Theme.cornerRadius - 2
                        color: root.currentHeadStyle === modelData.style 
                            ? Theme.withAlpha(Theme.primary, 0.15) 
                            : (headMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                        border.color: root.currentHeadStyle === modelData.style ? Theme.primary : "transparent"
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: tc.subToolbarIconSize
                            color: root.currentHeadStyle === modelData.style ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: headMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.headStyleSelected(modelData.style);
                                root.close();
                            }
                        }
                    }
                }
            }

            // Horizontal Separator
            Rectangle {
                width: headRow.implicitWidth; height: 1
                color: Theme.withAlpha(Theme.outline, 0.15)
            }

            // Bottom Row: Line Styles (Solid, Dashed, Dotted)
            Row {
                id: lineRow
                spacing: Theme.spacingS
                Repeater {
                    model: [
                        { icon: "line_weight", style: "solid" },
                        { icon: "border_style", style: "dashed" },
                        { icon: "more_horiz", style: "dotted" }
                    ]

                    delegate: Rectangle {
                        width: tc.subToolbarBtnSize; height: tc.subToolbarBtnSize
                        radius: Theme.cornerRadius - 2
                        color: root.currentLineStyle === modelData.style 
                            ? Theme.withAlpha(Theme.primary, 0.15) 
                            : (lineMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                        border.color: root.currentLineStyle === modelData.style ? Theme.primary : "transparent"
                        border.width: 1

                        DankIcon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: tc.subToolbarIconSize
                            color: root.currentLineStyle === modelData.style ? Theme.primary : Theme.surfaceText
                        }

                        MouseArea {
                            id: lineMouse
                            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.lineStyleSelected(modelData.style);
                                root.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
