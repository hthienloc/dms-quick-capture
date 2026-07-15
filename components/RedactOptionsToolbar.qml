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

    property string currentMode: "solid"
    property string toolbarPosition: "top"

    signal modeSelected(string mode)

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

            // Group: Redact Modes (Solid, Clean)
            Repeater {
                model: [
                    { icon: "square", mode: "solid", tooltip: qsTr("Solid Fill") },
                    { icon: "auto_fix_high", mode: "clean", tooltip: qsTr("Clean Text Eraser") }
                ]

                delegate: Rectangle {
                    width: tc.subToolbarBtnSize; height: tc.subToolbarBtnSize
                    radius: Theme.cornerRadius - 2
                    color: root.currentMode === modelData.mode 
                        ? Theme.withAlpha(Theme.primary, 0.15) 
                        : (modeMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.08) : "transparent")
                    border.color: root.currentMode === modelData.mode ? Theme.primary : "transparent"
                    border.width: 1

                    DankIcon {
                        anchors.centerIn: parent
                        name: modelData.icon
                        size: tc.subToolbarIconSize
                        color: root.currentMode === modelData.mode ? Theme.primary : Theme.surfaceText
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.modeSelected(modelData.mode);
                            root.close();
                        }
                    }
                }
            }
        }
    }
}
