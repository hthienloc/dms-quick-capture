import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "Constants.js" as Constants

Rectangle {
    id: popoverRoot

    property var presetsList: []
    property bool opened: false
    property bool editMode: false

    signal presetSelected(var preset)
    signal saveCurrentAsPreset()
    signal deletePreset(string presetId)
    signal updatePresetWithCurrent(string presetId)
    signal renamePreset(string presetId, string newName)

    width: 260
    height: Math.min(320, contentColumn.implicitHeight + Theme.spacingS * 2)
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
    z: 10001

    visible: opacity > 0
    opacity: 0
    scale: 0.9

    states: [
        State {
            name: "visible"
            when: popoverRoot.opened
            PropertyChanges { target: popoverRoot; opacity: 1.0; scale: 1.0 }
        }
    ]

    transitions: [
        Transition {
            NumberAnimation { properties: "opacity,scale"; duration: 120; easing.type: Easing.OutQuad }
        }
    ]

    function open() {
        closeTimer.stop();
        popoverRoot.opened = true;
    }

    function close() {
        popoverRoot.editMode = false;
        popoverRoot.opened = false;
    }

    function startCloseTimer() {
        closeTimer.start();
    }

    function stopCloseTimer() {
        closeTimer.stop();
    }

    Timer {
        id: closeTimer
        interval: 300
        onTriggered: popoverRoot.close()
    }

    HoverHandler {
        id: popoverHoverHandler
        onHoveredChanged: {
            if (hovered) {
                popoverRoot.stopCloseTimer();
            } else {
                popoverRoot.startCloseTimer();
            }
        }
    }

    Column {
        id: contentColumn
        width: parent.width - Theme.spacingS * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Theme.spacingS
        spacing: Theme.spacingS

        // Header Row
        Item {
            width: parent.width
            height: 24

            StyledText {
                text: qsTr("Backdrop Presets")
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                color: Theme.surfaceText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Constants.spacingCompact

                // Edit Mode Toggle Button
                Rectangle {
                    width: 24
                    height: 22
                    radius: Theme.cornerRadius / 2
                    color: popoverRoot.editMode 
                        ? Theme.withAlpha(Theme.error, 0.25) 
                        : (editMouse.containsMouse ? Theme.withAlpha(Theme.surfaceText, 0.1) : "transparent")
                    border.color: popoverRoot.editMode ? Theme.error : "transparent"
                    border.width: 1

                    DankIcon {
                        name: "edit"
                        size: 13
                        color: popoverRoot.editMode ? Theme.error : Theme.surfaceText
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: editMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popoverRoot.editMode = !popoverRoot.editMode;
                        }
                    }
                }

                // Save Current Preset Button
                Rectangle {
                    width: 60
                    height: 22
                    radius: Theme.cornerRadius / 2
                    color: saveMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.2) : Theme.withAlpha(Theme.primary, 0.1)
                    border.color: Theme.primary
                    border.width: 1

                    Row {
                        anchors.centerIn: parent
                        spacing: 2

                        DankIcon {
                            name: "add"
                            size: 12
                            color: Theme.primary
                        }

                        StyledText {
                            text: qsTr("Save")
                            font.pixelSize: Theme.fontSizeSmall - 2
                            color: Theme.primary
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: saveMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            popoverRoot.saveCurrentAsPreset();
                        }
                    }
                }
            }
        }

        // Scrollable list of preset cards
        ScrollView {
            width: parent.width
            height: Math.min(240, presetsColumn.implicitHeight)
            clip: true

            Column {
                id: presetsColumn
                width: parent.width
                spacing: Constants.spacingCompact

                Repeater {
                    model: popoverRoot.presetsList
                    delegate: Rectangle {
                        width: presetsColumn.width
                        height: 38
                        radius: Theme.cornerRadius - 2
                        color: popoverRoot.editMode 
                            ? Theme.withAlpha(Theme.error, 0.08) 
                            : (cardMouse.containsMouse ? Theme.withAlpha(Theme.primary, 0.12) : Theme.withAlpha(Theme.surfaceText, 0.04))
                        border.color: popoverRoot.editMode ? Theme.error : (cardMouse.containsMouse ? Theme.primary : "transparent")
                        border.width: popoverRoot.editMode ? 1.5 : 1

                        Item {
                            anchors.fill: parent
                            anchors.margins: 6

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS

                                // Dual Swatches (2 Color Circles)
                                Item {
                                    width: 30
                                    height: 20
                                    anchors.verticalCenter: parent.verticalCenter

                                    // Color Slot 1 (Primary / Start / Solid)
                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        x: 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: modelData.mode === "solid" ? (modelData.solidColor || Theme.primary) : (modelData.gradientStart || Theme.primary)
                                        border.color: Theme.withAlpha(Theme.outline, 0.3)
                                        border.width: 1
                                        z: 1
                                    }

                                    // Color Slot 2 (Secondary / End / Empty for Solid)
                                    Rectangle {
                                        width: 18
                                        height: 18
                                        radius: 9
                                        x: 12
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: (modelData.mode === "gradient" || modelData.mode === "radial" || modelData.mode === "conic")
                                               ? (modelData.gradientEnd || Theme.secondary)
                                               : "transparent"
                                        border.color: Theme.withAlpha(Theme.outline, 0.3)
                                        border.width: 1
                                        z: 0

                                        DankIcon {
                                            name: "close"
                                            size: 10
                                            color: Theme.withAlpha(Theme.surfaceText, 0.25)
                                            anchors.centerIn: parent
                                            visible: modelData.mode === "solid"
                                        }
                                    }
                                }

                                // Preset Name & Info
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    TextInput {
                                        visible: popoverRoot.editMode
                                        text: modelData.name || "Preset"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.bold: true
                                        color: Theme.error
                                        selectByMouse: true
                                        onEditingFinished: {
                                            popoverRoot.renamePreset(modelData.id, text);
                                        }
                                    }

                                    StyledText {
                                        visible: !popoverRoot.editMode
                                        text: modelData.name || "Preset"
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        font.bold: true
                                        color: Theme.surfaceText
                                    }

                                    StyledText {
                                        text: (modelData.mode || "solid").toUpperCase() + " • " + (modelData.aspectRatio || "auto").toUpperCase()
                                        font.pixelSize: Theme.fontSizeSmall - 3
                                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                                    }
                                }
                            }

                            // Edit Actions Row (visible in Edit Mode)
                            Row {
                                visible: popoverRoot.editMode === true
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4
                                z: 10

                                // Overwrite / Update Button
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 4
                                    color: updateMouse.containsMouse ? Theme.primary : Theme.withAlpha(Theme.primary, 0.2)
                                    border.color: Theme.primary
                                    border.width: 1

                                    DankIcon {
                                        name: "refresh"
                                        size: 14
                                        color: updateMouse.containsMouse ? "#ffffff" : Theme.primary
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: updateMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popoverRoot.updatePresetWithCurrent(modelData.id);
                                        }
                                    }
                                }

                                // Delete Button
                                Rectangle {
                                    width: 22
                                    height: 22
                                    radius: 4
                                    color: delMouse.containsMouse ? Theme.error : Theme.withAlpha(Theme.error, 0.2)
                                    border.color: Theme.error
                                    border.width: 1

                                    DankIcon {
                                        name: "delete"
                                        size: 14
                                        color: delMouse.containsMouse ? "#ffffff" : Theme.error
                                        anchors.centerIn: parent
                                    }

                                    MouseArea {
                                        id: delMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            popoverRoot.deletePreset(modelData.id);
                                        }
                                    }
                                }
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            enabled: !popoverRoot.editMode
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                popoverRoot.presetSelected(modelData);
                                popoverRoot.close();
                            }
                        }
                    }
                }
            }
        }
    }
}
