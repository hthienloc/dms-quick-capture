import QtQuick
import qs.Common
import qs.Widgets
import "../popovers"
import "../core/Constants.js" as Constants
import "../core/Helpers.js" as Helpers

Item {
    id: root

    required property var window
    property string toolbarPosition: "top"
    property string tool: ""
    property bool opened: false
    property real menuX: 0
    property real menuY: 0

    readonly property var lineStyles: [
        {
            icon: "line_weight",
            value: "solid",
            tooltip: I18n.trFor("quickCapture", "Solid Line")
        },
        {
            icon: "border_style",
            value: "dashed",
            tooltip: I18n.trFor("quickCapture", "Dashed Line")
        },
        {
            icon: "more_horiz",
            value: "dotted",
            tooltip: I18n.trFor("quickCapture", "Dotted Line")
        }
    ]

    readonly property var groups: {
        switch (root.tool) {
        case "line":
            return [
                {
                    key: "activeLineStyle",
                    options: lineStyles
                }
            ];
        case "arrow":
            return [
                {
                    key: "activeArrowHeadStyle",
                    options: [
                        {
                            icon: "trending_flat",
                            value: "single-filled"
                        },
                        {
                            icon: "chevron_right",
                            value: "single-open"
                        },
                        {
                            icon: "swap_horiz",
                            value: "double-filled"
                        }
                    ]
                },
                {
                    key: "activeArrowLineStyle",
                    options: lineStyles
                }
            ];
        case "stamp":
            return [
                {
                    key: "stampCounterFormat",
                    options: [
                        {
                            icon: "looks_one",
                            value: "numeric"
                        },
                        {
                            icon: "title",
                            value: "alpha"
                        },
                        {
                            icon: "tag",
                            value: "roman"
                        }
                    ]
                }
            ];
        case "text":
            return [
                {
                    toggle: true,
                    options: [
                        {
                            icon: "format_bold",
                            key: "textBold"
                        },
                        {
                            icon: "format_italic",
                            key: "textItalic"
                        },
                        {
                            icon: "format_underlined",
                            key: "textUnderline"
                        },
                        {
                            icon: "layers",
                            key: "textBackground"
                        }
                    ]
                }
            ];
        case "redact":
            return [
                {
                    key: "activeRedactMode",
                    options: [
                        {
                            icon: "square",
                            value: "solid",
                            tooltip: I18n.trFor("quickCapture", "Solid Fill")
                        },
                        {
                            icon: "auto_fix_high",
                            value: "clean",
                            tooltip: I18n.trFor("quickCapture", "Clean Text Eraser")
                        }
                    ]
                },
                {
                    key: "activeRedactShape",
                    options: [
                        {
                            icon: "crop_square",
                            value: "rect",
                            tooltip: I18n.trFor("quickCapture", "Rectangle")
                        },
                        {
                            icon: "rounded_corner",
                            value: "roundRect",
                            tooltip: I18n.trFor("quickCapture", "Rounded Rectangle")
                        },
                        {
                            icon: "circle",
                            value: "ellipse",
                            tooltip: I18n.trFor("quickCapture", "Ellipse")
                        }
                    ]
                }
            ];
        case "callout":
            return [
                {
                    key: "calloutShape",
                    options: [
                        {
                            icon: "crop_square",
                            value: "rect",
                            tooltip: I18n.trFor("quickCapture", "Rectangle")
                        },
                        {
                            icon: "circle",
                            value: "ellipse",
                            tooltip: I18n.trFor("quickCapture", "Ellipse")
                        }
                    ]
                },
                {
                    key: "calloutLinkLines",
                    options: [
                        {
                            icon: "remove",
                            value: 1,
                            tooltip: I18n.trFor("quickCapture", "1 Connecting Line")
                        },
                        {
                            icon: "density_medium",
                            value: 2,
                            tooltip: I18n.trFor("quickCapture", "2 Connecting Lines")
                        }
                    ]
                }
            ];
        default:
            return [];
        }
    }

    z: 2000
    anchors.fill: parent
    visible: panel.visible

    function openFor(tool, x, y) {
        root.tool = tool;
        if (root.groups.length === 0)
            return false;
        root.menuX = x;
        root.menuY = y;
        panel.open();
        return true;
    }

    function close() {
        panel.close();
    }

    function isActive(group, option) {
        if (group.toggle)
            return root.window[option.key] === true;
        return root.window[group.key] === option.value;
    }

    function select(group, option) {
        if (group.toggle) {
            root.window[option.key] = !root.window[option.key];
            return;
        }
        root.window[group.key] = option.value;
        close();
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: mouse => {
            root.close();
            mouse.accepted = false;
        }
    }

    PopoverSurface {
        id: panel
        closedScale: 0.95
        width: content.implicitWidth + Theme.spacingM * 2
        height: content.implicitHeight + Theme.spacingM * 2
        x: Helpers.popoverX(root.width, width, root.menuX)
        y: Helpers.popoverY(root.height, height, root.menuY, root.toolbarPosition)

        Column {
            id: content
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Repeater {
                model: root.groups

                delegate: Row {
                    id: groupRow
                    required property var modelData
                    spacing: Theme.spacingS

                    Repeater {
                        model: groupRow.modelData.options

                        delegate: DankActionButton {
                            required property var modelData
                            readonly property bool active: root.isActive(groupRow.modelData, modelData)
                            iconName: modelData.icon
                            buttonSize: Constants.subToolbarBtnSize
                            iconSize: Constants.subToolbarIconSize
                            tooltipText: modelData.tooltip ?? null
                            backgroundColor: active ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: active ? Theme.primary : Theme.surfaceText
                            onClicked: root.select(groupRow.modelData, modelData)
                        }
                    }
                }
            }
        }
    }
}
