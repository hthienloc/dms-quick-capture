import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    required property var options
    property string defaultValue: ""
    property string value: defaultValue

    width: parent.width
    implicitHeight: layout.implicitHeight

    // Dynamic Opacity for disabled state (Original DMS feature)
    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    readonly property bool isDirty: String(value) !== String(defaultValue)

    function resetToDefault() {
        console.log(`[ButtonGroupSettingPlus] Resetting ${settingKey}`);
        value = defaultValue;
    }

    function loadValue() {
        const settings = findSettings()
        if (settings && settings.pluginService) {
            value = settings.loadValue(settingKey, defaultValue)
        }
    }

    Component.onCompleted: loadValue()

    readonly property var optionLabels: {
        const labels = []
        for (let i = 0; i < options.length; i++) {
            labels.push(options[i].label || options[i])
        }
        return labels
    }

    readonly property var valueToIndex: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') map[opt.value] = i
            else map[opt] = i
        }
        return map
    }

    readonly property var indexToValue: {
        const map = {}
        for (let i = 0; i < options.length; i++) {
            const opt = options[i]
            if (typeof opt === 'object') map[i] = opt.value
            else map[i] = opt
        }
        return map
    }

    onValueChanged: {
        const settings = findSettings()
        if (settings) settings.saveValue(settingKey, value)
    }

    function findSettings() {
        let item = parent
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) return item
            item = item.parent
        }
        return null
    }

    HoverHandler {
        id: rootHoverHandler
    }

    Rectangle {
        id: highlightBg
        anchors.fill: parent
        anchors.leftMargin: -12
        anchors.rightMargin: -12
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        radius: Theme.cornerRadius
        color: rootHoverHandler.hovered ? Theme.withAlpha(Theme.primary, 0.08) : "transparent"
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    Column {
        id: layout
        anchors.fill: parent
        spacing: Theme.spacingXS

        // ── Label Row ─────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 32

            Row {
                anchors.left: parent.left
                anchors.right: individualReset.visible ? individualReset.left : parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingXS

                StyledText {
                    text: root.label
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    width: Math.min(implicitWidth, parent.width - (infoIcon.visible ? 20 : 0))
                }

                DankIcon {
                    id: infoIcon
                    name: "info"
                    size: 16
                    color: Theme.primary
                    visible: root.description !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    opacity: 0.6
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: sharedTooltip.show(root.description, infoIcon)
                        onExited: sharedTooltip.hide()
                    }
                }
            }

            Item {
                id: individualReset
                width: 28; height: 28
                visible: root.isDirty
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: resetArea.containsMouse ? Theme.primaryHoverLight : "transparent"
                }
                DankIcon {
                    name: "restart_alt"
                    size: 16
                    color: Theme.primary
                    anchors.centerIn: parent
                    opacity: 0.8
                }
                MouseArea {
                    id: resetArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetToDefault()
                }
            }
        }

        // ── Button Group (Full Width) ─────────────────────────────────────────
        DankButtonGroup {
            id: buttonGroup
            width: parent.width
            buttonHeight: 32
            selectionMode: "single"
            model: root.optionLabels
            currentIndex: root.valueToIndex[root.value] !== undefined ? root.valueToIndex[root.value] : -1
            onSelectionChanged: (index, selected) => {
                if (selected) {
                    root.value = root.indexToValue[index]
                }
            }
        }

        DankTooltipV2 { id: sharedTooltip }
    }
}
