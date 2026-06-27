import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: menuRoot
    width: 120
    height: menuColumn.implicitHeight + Theme.spacingS * 2
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
    z: 10000

    property bool opened: false
    visible: opacity > 0
    opacity: 0
    scale: 0.9

    signal rotateRequested()
    signal mirrorRequested()

    states: [
        State {
            name: "visible"
            when: menuRoot.opened
            PropertyChanges { target: menuRoot; opacity: 1.0; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open() {
        menuRoot.opened = true;
    }

    function close() {
        menuRoot.opened = false;
    }

    Column {
        id: menuColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingS
        spacing: 2

        // Rotate Option
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: rotateMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "rotate_right"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("Rotate")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: rotateMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.rotateRequested();
                }
            }
        }

        // Mirror Option
        Rectangle {
            width: parent.width
            height: 32
            radius: Theme.cornerRadius - 2
            color: mirrorMouseArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"

            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter

                DankIcon {
                    name: "flip"
                    size: 16
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: qsTr("Mirror")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            MouseArea {
                id: mirrorMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    menuRoot.close();
                    menuRoot.mirrorRequested();
                }
            }
        }
    }
}
