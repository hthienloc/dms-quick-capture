import QtQuick
import qs.Common
import qs.Widgets
import "../.."
import "../background"
import "../core/Helpers.js" as Helpers
import "../core/Constants.js" as Constants

Rectangle {
    id: root

    property var pluginData: ({})
    CaptureConfig {
        id: config
        pluginData: root.pluginData
    }

    property string currentTool: "crop"
    property string activeToolType: currentTool
    property color currentColor: Theme.primary
    property int strokeWidth: 8
    property bool canUndo: false
    property bool canRedo: false
    property bool isVertical: false
    property bool showAnnotations: true
    property var floatingWindowControls: null
    readonly property bool showShortcutHints: root.pluginData["show_shortcut_hints"] ?? false

    property string backgroundMode: "none"
    property color backgroundSolidColor: Theme.primary
    property color backgroundGradientStart: Theme.primary
    property color backgroundGradientEnd: Theme.secondary
    property int backgroundGradientAngle: 45
    property int backgroundPadding: 40
    property int backgroundCornerRadius: 12
    property int backgroundShadowStrength: 0
    property string backgroundAspectRatio: "auto"

    property real customAspectRatio: 1.50
    property string backgroundAlignment: "center"
    property bool backgroundImageBlur: false
    property bool backgroundImageDim: false
    property int backgroundImageDimStrength: 28

    property string gradientActiveSlot: "start"
    property string backgroundColorPickingSlot: "none"
    readonly property bool hasBackground: root.backgroundMode !== "none"
    readonly property bool gradientLike: ["gradient", "radial", "conic"].includes(root.backgroundMode)

    signal changeBackgroundMode(string mode, var controlItem)
    signal changeBackgroundSolidColor(color col)
    signal changeBackgroundGradientStart(color col)
    signal changeBackgroundGradientEnd(color col)
    signal moreToolsClicked(var buttonItem)
    signal moreToolsButtonReady(var buttonItem)
    property var moreToolsButton: null
    signal backgroundControlHovered(string type, var controlItem)
    signal backgroundControlExited(string type)
    signal backgroundControlWheel(string type, int delta)
    signal autoColorBalanceRequested

    readonly property var toolbarPalette: {
        const isCustom = config.selectedPreset === "custom";
        const isAdaptive = config.selectedPreset === "adaptive";
        if (isCustom || isAdaptive) {
            const p1 = isAdaptive ? "primary" : (root.pluginData["toolbar_color_primary"] || "primary");
            const slot1 = p1 === "primary" ? Theme.primary : p1;
            return [slot1].concat(config.accentColors);
        }
        return [config.defaultAccentColors[0]].concat(config.accentColors);
    }

    signal toolSelected(string tool)
    signal colorSelected(var color, int index)
    signal customColorPickerRequested(var buttonItem)
    property int activeColorSlotIndex: 0
    signal strokeWidthSelected(int width)
    signal undoRequested
    signal redoRequested
    signal floatRequested
    signal saveRequested
    signal saveAsRequested

    MouseArea {
        anchors.fill: parent
        z: -1
        visible: root.floatingWindowControls !== null
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeAllCursor
        onPressed: root.floatingWindowControls.tryStartMove()
    }
    signal copyRequested
    signal anonymousCopyRequested
    signal copyAndSaveRequested
    signal closeRequested
    signal annotationsToggled
    signal backgroundColorPickerRequested(color currentColor)
    signal backgroundEyedropperRequested(string slot)
    signal changeBackgroundImageBlur(bool enabled)
    signal changeBackgroundImageDim(bool enabled)

    readonly property color activeBackgroundColor: root.backgroundMode === "solid" ? root.backgroundSolidColor : (root.gradientActiveSlot === "start" ? root.backgroundGradientStart : root.backgroundGradientEnd)

    width: isVertical ? 56 : (contentLayout.width + Theme.spacingM * 2)
    height: isVertical ? (contentLayout.height + Theme.spacingM * 2) : 56
    radius: Theme.cornerRadius

    readonly property bool showBorder: root.pluginData["showToolbarBorder"] ?? false

    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: showBorder ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
    border.width: showBorder ? 1.5 : 1

    component ColorPaletteGrid: Grid {
        id: paletteGrid
        property var paletteModel: root.toolbarPalette
        property color activeColor: "transparent"
        property int activeSlotIndex: -1
        property int swatchSize: Constants.swatchSize
        property int swatchRadius: Constants.swatchRadius
        property int cols: 4
        property int gridSpacingValue: Constants.gridSpacing
        signal colorSelected(color col, int index)
        columns: cols
        rows: cols === 2 ? 4 : 2
        flow: cols === 2 ? Grid.TopToBottom : Grid.LeftToRight
        spacing: gridSpacingValue
        Repeater {
            model: paletteGrid.paletteModel
            delegate: Rectangle {
                width: paletteGrid.swatchSize
                height: paletteGrid.swatchSize
                radius: paletteGrid.swatchRadius
                color: modelData
                readonly property bool isActive: (paletteGrid.activeSlotIndex === -1 || paletteGrid.activeSlotIndex === index) && Helpers.colorEquals(paletteGrid.activeColor, modelData, Qt)
                border.color: isActive ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                border.width: isActive ? 2 : 1
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: paletteGrid.colorSelected(modelData, index)
                }
            }
        }
    }

    Item {
        id: contentLayout
        width: toolbarLoader.item ? toolbarLoader.item.width : 0
        height: toolbarLoader.item ? toolbarLoader.item.height : 0
        anchors.centerIn: parent

        Loader {
            id: toolbarLoader
            anchors.centerIn: parent
            sourceComponent: {
                if (root.currentTool === "background" || (root.currentTool === "colorpicker" && root.backgroundColorPickingSlot !== "none"))
                    return backgroundLayout;
                return annotationLayout;
            }
        }
    }

    component ToolbarGrid: Grid {
        property int gap: Theme.spacingL
        columns: root.isVertical ? 1 : 100
        spacing: gap
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }

    component Divider: ToolbarSeparator {
        vertical: !root.isVertical
    }

    component SplitActionButton: Item {
        property alias iconName: button.iconName
        property alias tooltipText: button.tooltipText

        signal leftClicked
        signal rightClicked

        width: Constants.btnSize
        height: Constants.btnSize

        DankActionButton {
            id: button
            anchors.fill: parent
            buttonSize: Constants.btnSize
            iconSize: Constants.iconSize
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    rightClicked();
                else
                    leftClicked();
            }
        }
    }

    Component {
        id: annotationLayout

        ToolbarGrid {
            AnnotationControls {
                compact: root.isVertical
                currentTool: root.currentTool
                showAnnotations: root.showAnnotations
                onToolSelected: tool => root.toolSelected(tool)
                onAnnotationsToggled: root.annotationsToggled()
            }

            Divider {}

            ToolButtonsControl {
                id: toolButtonsControl
                compact: root.isVertical
                toolButtons: config.toolButtons
                currentTool: root.currentTool
                showShortcutHints: root.showShortcutHints
                Component.onCompleted: {
                    root.moreToolsButton = toolButtonsControl.moreToolsButton;
                    root.moreToolsButtonReady(toolButtonsControl.moreToolsButton);
                }
                onToolSelected: tool => root.toolSelected(tool)
                onMoreToolsClicked: controlItem => {
                    root.moreToolsButton = controlItem;
                    root.moreToolsClicked(controlItem);
                }
            }

            Divider {}

            ColorPaletteGrid {
                activeColor: root.currentColor
                activeSlotIndex: root.activeColorSlotIndex
                swatchSize: root.isVertical ? Constants.swatchSizeVert : Constants.swatchSize
                swatchRadius: root.isVertical ? Constants.swatchRadiusVert : Constants.swatchRadius
                cols: root.isVertical ? 2 : 4
                gridSpacingValue: root.isVertical ? Constants.gridSpacing + 2 : Constants.gridSpacing
                onColorSelected: (col, idx) => root.colorSelected(col, idx)
            }

            ColorPickerControl {
                currentTool: root.currentTool
                onCustomPickerRequested: controlItem => root.customColorPickerRequested(controlItem)
                onDrawPickerRequested: root.toolSelected("colorpicker-draw")
            }

            Divider {
                visible: !root.isVertical
            }

            Row {
                visible: !root.isVertical
                spacing: Theme.spacingS
                readonly property var toolMeta: Constants.getToolMeta(root.activeToolType)

                StyledText {
                    text: root.strokeWidth + parent.toolMeta.unit
                    width: Constants.btnSize
                    horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }

                DankSlider {
                    id: widthSlider
                    minimum: parent.toolMeta.min
                    maximum: parent.toolMeta.max
                    step: parent.toolMeta.step
                    width: Constants.sliderWidth
                    height: Constants.btnSize
                    showValue: false
                    onSliderValueChanged: newValue => root.strokeWidthSelected(newValue)
                    anchors.verticalCenter: parent.verticalCenter

                    Binding {
                        target: widthSlider
                        property: "value"
                        value: root.strokeWidth
                    }
                }
            }

            Divider {
                visible: !root.isVertical
            }

            Row {
                visible: !root.isVertical
                spacing: Theme.spacingXS

                DankActionButton {
                    iconName: "undo"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    enabled: root.canUndo
                    opacity: enabled ? 1.0 : 0.4
                    tooltipText: I18n.trFor("quickCapture", "Undo") + " (Ctrl+Z)"
                    onClicked: root.undoRequested()
                }

                DankActionButton {
                    iconName: "redo"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    enabled: root.canRedo
                    opacity: enabled ? 1.0 : 0.4
                    tooltipText: I18n.trFor("quickCapture", "Redo") + " (Ctrl+Y / Ctrl+Shift+Z)"
                    onClicked: root.redoRequested()
                }
            }

            Divider {
                visible: !root.isVertical
            }

            Row {
                visible: !root.isVertical
                spacing: Theme.spacingXS

                DankActionButton {
                    iconName: "push_pin"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.trFor("quickCapture", "Float Window") + " (Ctrl+F)"
                    onClicked: root.floatRequested()
                }

                SplitActionButton {
                    iconName: "content_copy"
                    tooltipText: I18n.trFor("quickCapture", "Copy") + " (Ctrl+C) · " + I18n.trFor("quickCapture", "Anonymous Copy") + " (Ctrl+Shift+C)"
                    onLeftClicked: root.copyRequested()
                    onRightClicked: root.anonymousCopyRequested()
                }

                SplitActionButton {
                    iconName: "save"
                    tooltipText: I18n.trFor("quickCapture", "Save") + " (Ctrl+S) · " + I18n.trFor("quickCapture", "Save As") + " (Ctrl+Shift+S)"
                    onLeftClicked: root.saveRequested()
                    onRightClicked: root.saveAsRequested()
                }

                DankActionButton {
                    iconName: "done_all"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.trFor("quickCapture", "Copy & Save") + " (Enter)"
                    iconColor: Theme.primary
                    onClicked: root.copyAndSaveRequested()
                }
            }

            Divider {
                visible: !root.isVertical
            }

            DankActionButton {
                visible: !root.isVertical
                iconName: "close"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                iconColor: Theme.error
                tooltipText: I18n.trFor("quickCapture", "Discard & Close") + " (Esc)"
                onClicked: root.closeRequested()
            }
        }
    }

    Component {
        id: backgroundLayout

        ToolbarGrid {
            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                tooltipText: I18n.trFor("quickCapture", "Back to Annotation") + " (B)"
                onClicked: root.toolSelected("back")
            }

            Divider {}

            BackgroundPresetsControl {
                onHovered: controlItem => root.backgroundControlHovered("presets", controlItem)
                onExited: root.backgroundControlExited("presets")
            }

            Divider {}

            BackgroundModeSelectors {
                backgroundMode: root.backgroundMode
                isVertical: root.isVertical
                onChangeBackgroundMode: (mode, controlItem) => root.changeBackgroundMode(mode, controlItem)
            }

            Divider {}

            ToolbarGrid {
                gap: root.isVertical ? Theme.spacingS : Theme.spacingM

                Repeater {
                    model: [
                        {
                            type: "padding",
                            icon: "padding",
                            value: root.backgroundPadding,
                            unit: "px",
                            visible: true
                        },
                        {
                            type: "radius",
                            icon: "rounded_corner",
                            value: root.backgroundCornerRadius,
                            unit: "px",
                            visible: true
                        },
                        {
                            type: "shadow",
                            icon: "blur_on",
                            value: root.backgroundShadowStrength,
                            unit: "%",
                            visible: true
                        },
                        {
                            type: "angle",
                            icon: "rotate_right",
                            value: root.backgroundGradientAngle,
                            unit: "°",
                            visible: root.backgroundMode === "gradient" || root.backgroundMode === "conic"
                        }
                    ]

                    delegate: BackgroundMetricControl {
                        required property var modelData
                        visible: modelData.visible
                        compact: root.isVertical
                        iconName: modelData.icon
                        valueText: root.isVertical ? String(modelData.value) : modelData.value + modelData.unit
                        onHovered: controlItem => root.backgroundControlHovered(modelData.type, controlItem)
                        onExited: root.backgroundControlExited(modelData.type)
                        onWheeled: delta => root.backgroundControlWheel(modelData.type, delta)
                    }
                }

                AspectRatioControl {
                    id: aspectControl
                    backgroundAspectRatio: root.backgroundAspectRatio
                    customAspectRatio: root.customAspectRatio
                    compact: root.isVertical
                    onHovered: root.backgroundControlHovered("aspectRatio", aspectControl)
                    onExited: root.backgroundControlExited("aspectRatio")
                    onWheeled: delta => root.backgroundControlWheel("aspectRatio", delta)
                }

                AlignmentControl {
                    id: alignControl
                    backgroundAlignment: root.backgroundAlignment
                    compact: root.isVertical
                    onHovered: root.backgroundControlHovered("alignment", alignControl)
                    onExited: root.backgroundControlExited("alignment")
                }
            }

            Divider {
                opacity: root.hasBackground ? 1 : 0
                enabled: root.hasBackground
            }

            ToolbarGrid {
                id: colorGroup
                gap: Theme.spacingS
                opacity: root.hasBackground ? 1 : 0
                enabled: root.hasBackground

                BackgroundColorSelectors {
                    isVertical: root.isVertical
                    backgroundMode: root.backgroundMode
                    backgroundSolidColor: root.backgroundSolidColor
                    backgroundGradientStart: root.backgroundGradientStart
                    backgroundGradientEnd: root.backgroundGradientEnd
                    gradientActiveSlot: root.gradientActiveSlot
                    imageBlurEnabled: root.backgroundImageBlur
                    imageDimEnabled: root.backgroundImageDim
                    imageDimStrength: root.backgroundImageDimStrength
                    itemSize: 24
                    iconSize: 18
                    onSetGradientActiveSlot: slot => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
                    onColorPickerRequested: currentColor => root.backgroundColorPickerRequested(currentColor)
                    onEyedropperRequested: slot => root.backgroundEyedropperRequested(slot)
                    onImageBlurToggled: enabled => root.changeBackgroundImageBlur(enabled)
                    onImageDimToggled: enabled => root.changeBackgroundImageDim(enabled)
                    onImageDimControlHovered: controlItem => root.backgroundControlHovered("imageDim", controlItem)
                    onImageDimControlExited: root.backgroundControlExited("imageDim")
                    onImageDimControlWheel: delta => root.backgroundControlWheel("imageDim", delta)
                }

                ColorPaletteGrid {
                    visible: root.backgroundMode !== "image"
                    activeColor: root.activeBackgroundColor
                    activeSlotIndex: -1
                    swatchSize: root.isVertical ? Constants.swatchSizeVert : Constants.swatchSize
                    swatchRadius: root.isVertical ? Constants.swatchRadiusVert : Constants.swatchRadius
                    cols: root.isVertical ? 2 : 4
                    onColorSelected: col => {
                        if (root.backgroundMode === "solid") {
                            root.changeBackgroundSolidColor(col);
                            return;
                        }
                        if (!root.gradientLike)
                            return;
                        if (root.gradientActiveSlot === "start")
                            root.changeBackgroundGradientStart(col);
                        else
                            root.changeBackgroundGradientEnd(col);
                    }
                }
            }
        }
    }
}
