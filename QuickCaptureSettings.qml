import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginSettings {
    id: root

    pluginId: "quickCapture"

    readonly property var liveData: SettingsData.pluginSettings[pluginId] ?? ({})
    readonly property var daemon: PluginService.pluginDaemonInstances[pluginId] ?? null

    readonly property var tabs: [
        {
            label: I18n.trFor("quickCapture", "Capture"),
            icon: "camera",
            source: "components/settings/CaptureTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Recording"),
            icon: "videocam",
            source: "components/settings/RecordingTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Save"),
            icon: "save",
            source: "components/settings/SaveTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Toolbar"),
            icon: "dock",
            source: "components/settings/ToolbarTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Color Palette"),
            icon: "palette",
            source: "components/settings/PaletteTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Editor"),
            icon: "aspect_ratio",
            source: "components/settings/EditorTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Tools"),
            icon: "tune",
            source: "components/settings/ToolsTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Background"),
            icon: "wallpaper",
            source: "components/settings/BackgroundTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Watermark"),
            icon: "branding_watermark",
            source: "components/settings/WatermarkTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Float Window"),
            icon: "open_in_new",
            source: "components/settings/FloatWindowTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Radial Menu"),
            icon: "mouse",
            source: "components/settings/RadialMenuTab.qml"
        },
        {
            label: I18n.trFor("quickCapture", "Help"),
            icon: "menu_book",
            source: "components/settings/HelpTab.qml"
        }
    ]

    property int currentTab: 0

    CaptureConfig {
        id: captureConfig
        pluginData: root.liveData
    }

    Flow {
        width: parent.width
        spacing: Theme.spacingS

        Repeater {
            model: root.tabs

            delegate: Rectangle {
                id: chip
                required property var modelData
                required property int index
                readonly property bool active: root.currentTab === index

                height: 32
                width: chipRow.implicitWidth + Theme.spacingL * 1.5
                radius: height / 2
                color: active ? Theme.withAlpha(Theme.primary, 0.18) : (chipArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.08) : Theme.withAlpha(Theme.outline, 0.12))
                border.color: active ? Theme.primary : (chipArea.containsMouse ? Theme.withAlpha(Theme.primary, 0.6) : "transparent")
                border.width: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }
                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.shortDuration
                    }
                }

                Row {
                    id: chipRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS + 2

                    DankIcon {
                        name: chip.modelData.icon
                        size: Theme.iconSizeSmall - 1
                        color: chip.active ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: chip.modelData.label
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: chip.active ? Font.Medium : Font.Normal
                        color: chip.active ? Theme.primary : Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.currentTab = chip.index
                }
            }
        }
    }

    Loader {
        id: tabLoader
        width: parent.width
        source: Qt.resolvedUrl(root.tabs[root.currentTab].source)
        onLoaded: {
            item.config = captureConfig;
            if (item.daemon !== undefined)
                item.daemon = root.daemon;
        }

        function loadValue() {
            if (item && typeof item.loadValue === "function")
                item.loadValue();
        }
    }
}
