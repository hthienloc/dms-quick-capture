import QtQuick
import QtQuick.Dialogs
import qs.Common
import qs.Widgets

Item {
    id: root

    required property string settingKey
    required property string label
    property string description: ""
    property string placeholder: ""
    property string defaultValue: ""
    property string value: defaultValue
    
    // Features
    property bool isDirectory: false
    property bool isFile: false
    property var fileExtensions: ["*"]

    width: parent.width
    implicitHeight: layoutColumn.implicitHeight
    
    // Dynamic Opacity for disabled state
    opacity: enabled ? 1 : 0.5
    Behavior on opacity { NumberAnimation { duration: Theme.shortDuration } }

    property bool isInitialized: false
    readonly property bool isDirty: value !== defaultValue

    function resetToDefault() {
        console.log(`[StringSettingPlus] Resetting ${settingKey}`);
        value = defaultValue;
        textField.text = defaultValue;
    }

    onValueChanged: {
        if (!isInitialized) return;
        const settings = findSettings();
        if (settings) settings.saveValue(settingKey, value);
    }

    function loadValue() {
        const settings = findSettings();
        if (settings) {
            const pluginId = settings.pluginId;
            if (pluginId && typeof SettingsData !== "undefined") {
                const loadedValue = SettingsData.getPluginSetting(pluginId, settingKey, defaultValue);
                if (textField.activeFocus && isInitialized) return;
                value = loadedValue;
                textField.text = loadedValue;
                isInitialized = true;
            } else if (settings.pluginService) {
                const loadedValue = settings.loadValue(settingKey, defaultValue);
                if (textField.activeFocus && isInitialized) return;
                value = loadedValue;
                textField.text = loadedValue;
                isInitialized = true;
            }
        }
    }

    Component.onCompleted: Qt.callLater(loadValue);

    function commit() {
        if (!isInitialized || textField.text === value) return;
        value = textField.text;
        const settings = findSettings();
        if (settings) settings.saveValue(settingKey, value);
    }

    function findSettings() {
        let item = parent;
        while (item) {
            if (item.saveValue !== undefined && item.loadValue !== undefined) return item;
            item = item.parent;
        }
        return null;
    }

    function _cleanPath(url) {
        let path = url.toString();
        if (path.startsWith("file://")) path = path.substring(7);
        if (path.length > 1 && path.endsWith("/")) path = path.substring(0, path.length - 1);
        return path;
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
        id: layoutColumn
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

        // ── Input Row (Explicit Width Calculation) ───────────────────────────
        Row {
            width: parent.width
            spacing: Theme.spacingS

            DankTextField {
                id: textField
                width: parent.width - (pickerBtn.visible ? 42 + Theme.spacingS : 0)
                placeholderText: root.placeholder
                onEditingFinished: root.commit()
                onActiveFocusChanged: if (!activeFocus) root.commit()
            }

            DankButton {
                id: pickerBtn
                visible: root.isDirectory || root.isFile
                iconName: root.isDirectory ? "folder_open" : "file_open"
                text: ""
                width: 42
                buttonHeight: textField.height
                backgroundColor: Theme.surfaceContainerHigh
                textColor: Theme.primary
                onClicked: {
                    if (root.isDirectory) folderDialog.open();
                    else fileDialog.open();
                }
            }
        }

        DankTooltipV2 { id: sharedTooltip }

        FolderDialog {
            id: folderDialog
            title: I18n.tr("Select Directory")
            onAccepted: { textField.text = root._cleanPath(selectedFolder); root.commit(); }
        }
        
        FileDialog {
            id: fileDialog
            title: I18n.tr("Select File")
            nameFilters: root.fileExtensions
            onAccepted: { textField.text = root._cleanPath(selectedFile); root.commit(); }
        }
    }
}
