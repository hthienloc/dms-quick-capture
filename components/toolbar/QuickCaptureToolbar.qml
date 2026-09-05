import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import "../.."
import "../background"
import "../popovers"
import "../core/Helpers.js" as Helpers
import "../core/Constants.js" as Constants

Rectangle {
    id: root

    property var pluginData: ({})
    CaptureConfig { id: config; pluginData: root.pluginData }

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

    // Background configuration properties
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

    signal changeBackgroundMode(string mode, var controlItem)
    signal changeBackgroundSolidColor(color col)
    signal changeBackgroundGradientStart(color col)
    signal changeBackgroundGradientEnd(color col)
    signal changeBackgroundGradientAngle(int angle)
    signal changeBackgroundPadding(int padding)
    signal changeBackgroundCornerRadius(int radius)
    signal changeBackgroundShadowStrength(int strength)
    signal changeBackgroundAspectRatio(string ratio)
    signal changeCustomAspectRatio(real ratio)
    signal changeBackgroundAlignment(string alignment)
    signal rotateLeftRequested()
    signal rotateRightRequested()
    signal flipHorizontalRequested()
    signal flipVerticalRequested()
    signal rotateRequested()
    signal mirrorRequested()
    signal moreToolsClicked(var buttonItem)
    signal backgroundControlHovered(string type, var controlItem)
    signal backgroundControlExited(string type)
    signal backgroundControlWheel(string type, int delta)
    signal autoColorBalanceRequested()

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
    signal undoRequested()
    signal redoRequested()
    signal floatRequested()
    signal saveRequested()
    signal saveAsRequested()

    // Empty toolbar areas can start a DMS floating-window move without
    // intercepting clicks handled by the toolbar's child controls.
    MouseArea {
        anchors.fill: parent
        z: -1
        visible: root.floatingWindowControls !== null
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.SizeAllCursor
        onPressed: root.floatingWindowControls.tryStartMove()
    }
    signal copyRequested()
    signal anonymousCopyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()
    signal annotationsToggled()
    signal backgroundColorPickerRequested(color currentColor)
    signal backgroundEyedropperRequested(string slot)
    signal changeBackgroundImageBlur(bool enabled)
    signal changeBackgroundImageDim(bool enabled)

    readonly property color activeBackgroundColor: root.backgroundMode === "solid" ?
        root.backgroundSolidColor :
        (root.gradientActiveSlot === "start" ? root.backgroundGradientStart : root.backgroundGradientEnd)



    width: isVertical ? 56 : (contentLayout.width + Theme.spacingM * 2)
    height: isVertical ? (contentLayout.height + Theme.spacingM * 2) : 56
    radius: Theme.cornerRadius

    readonly property bool showBorder: root.pluginData["showToolbarBorder"] ?? false

    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: showBorder ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
    border.width: showBorder ? 1.5 : 1

    component ColorPaletteGrid : Grid {
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
                width: paletteGrid.swatchSize; height: paletteGrid.swatchSize; radius: paletteGrid.swatchRadius; color: modelData
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
                if (root.currentTool === "background" || (root.currentTool === "colorpicker" && root.backgroundColorPickingSlot !== "none")) {
                    return root.isVertical ? backgroundVerticalLayout : backgroundHorizontalLayout;
                }
                return root.isVertical ? verticalLayout : horizontalLayout;
            }
        }
    }

    Component {
        id: horizontalLayout
        Row {
            id: horizontalItems
            spacing: Theme.spacingL
            
            AnnotationControls {
                anchors.verticalCenter: parent.verticalCenter
                currentTool: root.currentTool
                showAnnotations: root.showAnnotations
                onToolSelected: (tool) => root.toolSelected(tool)
                onAnnotationsToggled: root.annotationsToggled()
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            ToolButtonsControl {
                anchors.verticalCenter: parent.verticalCenter
                toolButtons: config.toolButtons
                currentTool: root.currentTool
                showShortcutHints: root.showShortcutHints
                onToolSelected: (tool) => root.toolSelected(tool)
                onMoreToolsClicked: (controlItem) => root.moreToolsClicked(controlItem)
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            // Colors
            ColorPaletteGrid {
                activeColor: root.currentColor
                activeSlotIndex: root.activeColorSlotIndex
                swatchSize: Constants.swatchSize
                swatchRadius: Constants.swatchRadius
                cols: 4
                anchors.verticalCenter: parent.verticalCenter
                onColorSelected: (col, idx) => root.colorSelected(col, idx)
            }

            ColorPickerControl {
                anchors.verticalCenter: parent.verticalCenter
                currentTool: root.currentTool
                onCustomPickerRequested: (controlItem) => root.customColorPickerRequested(controlItem)
                onDrawPickerRequested: root.toolSelected("colorpicker-draw")
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            // Thickness Section
            Row {
                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                readonly property var toolMeta: Constants.getToolMeta(root.activeToolType)
                Text {
                    text: root.strokeWidth + parent.toolMeta.unit
                    width: Constants.btnSize; horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                }
                DankSlider {
                    id: hSlider
                    minimum: parent.toolMeta.min
                    maximum: parent.toolMeta.max
                    step: parent.toolMeta.step
                    width: Constants.sliderWidth
                    height: Constants.btnSize
                    showValue: false
                    onSliderValueChanged: newValue => root.strokeWidthSelected(newValue)
                    anchors.verticalCenter: parent.verticalCenter

                    Binding {
                        target: hSlider
                        property: "value"
                        value: root.strokeWidth
                    }
                }
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            // History Actions (Undo & Redo)
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "undo"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; tooltipText: I18n.trFor("quickCapture", "Undo (Ctrl+Z)"); onClicked: root.undoRequested() }
                DankActionButton { iconName: "redo"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; enabled: root.canRedo; opacity: enabled ? 1.0 : 0.4; tooltipText: I18n.trFor("quickCapture", "Redo (Ctrl+Y / Ctrl+Shift+Z)"); onClicked: root.redoRequested() }
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            // Export Actions
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "push_pin"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Float Window (Ctrl+F)"; onClicked: root.floatRequested() }
                Item {
                    width: Constants.btnSize
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    DankActionButton {
                        anchors.fill: parent
                        iconName: "save"
                        buttonSize: Constants.btnSize
                        iconSize: Constants.iconSize
                        tooltipText: I18n.trFor("quickCapture", "Save (Ctrl+S) | Save As (Ctrl+Shift+S)")
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                root.saveAsRequested();
                            } else {
                                root.saveRequested();
                            }
                        }
                    }
                }
                Item {
                    width: Constants.btnSize
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    DankActionButton {
                        id: copyButton
                        anchors.fill: parent
                        iconName: "content_copy"
                        buttonSize: Constants.btnSize
                        iconSize: Constants.iconSize
                        tooltipText: I18n.trFor("quickCapture", "Copy (Ctrl+C) | Anonymous Copy (Ctrl+Shift+C)")
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                root.anonymousCopyRequested();
                            } else {
                                root.copyRequested();
                            }
                        }
                    }
                }
                DankActionButton { iconName: "done_all"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Copy & Save (Enter)"; iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            DankActionButton { iconName: "close"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; iconColor: Theme.error; tooltipText: I18n.trFor("quickCapture", "Discard & Close (Esc)"); anchors.verticalCenter: parent.verticalCenter; onClicked: root.closeRequested() }
        }
    }

    Component {
        id: verticalLayout
        Column {
            id: verticalItems
            spacing: Theme.spacingL
            
            AnnotationControls {
                anchors.horizontalCenter: parent.horizontalCenter
                compact: true
                currentTool: root.currentTool
                showAnnotations: root.showAnnotations
                onToolSelected: (tool) => root.toolSelected(tool)
                onAnnotationsToggled: root.annotationsToggled()
            }

            ToolbarSeparator { anchors.horizontalCenter: parent.horizontalCenter }

            ToolButtonsControl {
                anchors.horizontalCenter: parent.horizontalCenter
                compact: true
                toolButtons: config.toolButtons
                currentTool: root.currentTool
                showShortcutHints: root.showShortcutHints
                onToolSelected: (tool) => root.toolSelected(tool)
                onMoreToolsClicked: (controlItem) => root.moreToolsClicked(controlItem)
            }

            ToolbarSeparator { anchors.horizontalCenter: parent.horizontalCenter }

            ColorPaletteGrid {
                activeColor: root.currentColor
                activeSlotIndex: root.activeColorSlotIndex
                swatchSize: Constants.swatchSizeVert
                swatchRadius: Constants.swatchRadiusVert
                cols: 2
                gridSpacingValue: Constants.gridSpacing + 2
                anchors.horizontalCenter: parent.horizontalCenter
                onColorSelected: (col, idx) => root.colorSelected(col, idx)
            }

            ColorPickerControl {
                anchors.horizontalCenter: parent.horizontalCenter
                currentTool: root.currentTool
                onCustomPickerRequested: (controlItem) => root.customColorPickerRequested(controlItem)
                onDrawPickerRequested: root.toolSelected("colorpicker-draw")
            }
        }
    }

    Component {
        id: backgroundHorizontalLayout
        Row {
            spacing: Theme.spacingL
            anchors.verticalCenter: parent.verticalCenter
            
            // Back button
            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                anchors.verticalCenter: parent.verticalCenter
                tooltipText: I18n.trFor("quickCapture", "Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }
            
            BackgroundPresetsControl {
                id: presetsControl
                anchors.verticalCenter: parent.verticalCenter
                onHovered: (controlItem) => root.backgroundControlHovered("presets", controlItem)
                onExited: root.backgroundControlExited("presets")
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }

            BackgroundModeSelectors {
                backgroundMode: root.backgroundMode
                isVertical: false
                onChangeBackgroundMode: (mode, controlItem) => root.changeBackgroundMode(mode, controlItem)
                anchors.verticalCenter: parent.verticalCenter
            }

            ToolbarSeparator { vertical: true; anchors.verticalCenter: parent.verticalCenter }
            
            // Sliders Row (Hover to reveal popup controls)
            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                
                BackgroundMetricControl {
                    id: padControl
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "padding"
                    valueText: root.backgroundPadding + "px"
                    onHovered: (controlItem) => root.backgroundControlHovered("padding", controlItem)
                    onExited: root.backgroundControlExited("padding")
                    onWheeled: (delta) => root.backgroundControlWheel("padding", delta)
                }

                BackgroundMetricControl {
                    id: radControl
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "rounded_corner"
                    valueText: root.backgroundCornerRadius + "px"
                    onHovered: (controlItem) => root.backgroundControlHovered("radius", controlItem)
                    onExited: root.backgroundControlExited("radius")
                    onWheeled: (delta) => root.backgroundControlWheel("radius", delta)
                }

                BackgroundMetricControl {
                    id: shadowControl
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "blur_on"
                    valueText: root.backgroundShadowStrength + "%"
                    onHovered: (controlItem) => root.backgroundControlHovered("shadow", controlItem)
                    onExited: root.backgroundControlExited("shadow")
                    onWheeled: (delta) => root.backgroundControlWheel("shadow", delta)
                }

                BackgroundMetricControl {
                    id: angleControl
                    visible: root.backgroundMode === "gradient" || root.backgroundMode === "conic"
                    width: visible ? implicitWidth : 0
                    anchors.verticalCenter: parent.verticalCenter
                    iconName: "rotate_right"
                    valueText: root.backgroundGradientAngle + "°"
                    onHovered: (controlItem) => root.backgroundControlHovered("angle", controlItem)
                    onExited: root.backgroundControlExited("angle")
                    onWheeled: (delta) => root.backgroundControlWheel("angle", delta)
                }

                // Aspect Ratio Control (Hover to reveal preset grid + custom slider popover)
                AspectRatioControl {
                    id: aspectControl
                    backgroundAspectRatio: root.backgroundAspectRatio
                    customAspectRatio: root.customAspectRatio
                    compact: false
                    anchors.verticalCenter: parent.verticalCenter
                    onHovered: root.backgroundControlHovered("aspectRatio", aspectControl)
                    onExited: root.backgroundControlExited("aspectRatio")
                    onWheeled: (delta) => root.backgroundControlWheel("aspectRatio", delta)
                }

                // Alignment Control (Hover to reveal 3x3 position grid popover)
                AlignmentControl {
                    id: alignControl
                    backgroundAlignment: root.backgroundAlignment
                    compact: false
                    anchors.verticalCenter: parent.verticalCenter
                    onHovered: root.backgroundControlHovered("alignment", alignControl)
                    onExited: root.backgroundControlExited("alignment")
                }
            }
            
            ToolbarSeparator {
                opacity: root.backgroundMode !== "none" ? 1 : 0
                enabled: root.backgroundMode !== "none"
                vertical: true
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Colors (Solid or Gradient)
            Row {
                opacity: root.backgroundMode !== "none" ? 1 : 0
                enabled: root.backgroundMode !== "none"
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                                 BackgroundColorSelectors {
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
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
                    onColorPickerRequested: (currentColor) => root.backgroundColorPickerRequested(currentColor)
                    onEyedropperRequested: (slot) => root.backgroundEyedropperRequested(slot)
                    onImageBlurToggled: (enabled) => root.changeBackgroundImageBlur(enabled)
                    onImageDimToggled: (enabled) => root.changeBackgroundImageDim(enabled)
                    onImageDimControlHovered: (controlItem) => root.backgroundControlHovered("imageDim", controlItem)
                    onImageDimControlExited: root.backgroundControlExited("imageDim")
                    onImageDimControlWheel: (delta) => root.backgroundControlWheel("imageDim", delta)
                }
                
                ColorPaletteGrid {
                    visible: root.backgroundMode !== "image"
                    activeColor: root.activeBackgroundColor
                    activeSlotIndex: -1
                    swatchSize: Constants.swatchSize
                    swatchRadius: Constants.swatchRadius
                    cols: 4
                    anchors.verticalCenter: parent.verticalCenter
                    onColorSelected: (col, idx) => {
                        if (root.backgroundMode === "solid") {
                            root.changeBackgroundSolidColor(col);
                        } else if (root.backgroundMode === "gradient" || root.backgroundMode === "radial" || root.backgroundMode === "conic") {
                            if (root.gradientActiveSlot === "start") {
                                root.changeBackgroundGradientStart(col);
                            } else {
                                root.changeBackgroundGradientEnd(col);
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: backgroundVerticalLayout
        Column {
            spacing: Theme.spacingL
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Back button
            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                anchors.horizontalCenter: parent.horizontalCenter
                tooltipText: I18n.trFor("quickCapture", "Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            ToolbarSeparator { anchors.horizontalCenter: parent.horizontalCenter }
            
            BackgroundPresetsControl {
                id: presetsControlVert
                anchors.horizontalCenter: parent.horizontalCenter
                onHovered: (controlItem) => root.backgroundControlHovered("presets", controlItem)
                onExited: root.backgroundControlExited("presets")
            }

            ToolbarSeparator { anchors.horizontalCenter: parent.horizontalCenter }

            BackgroundModeSelectors {
                backgroundMode: root.backgroundMode
                isVertical: true
                onChangeBackgroundMode: (mode, controlItem) => root.changeBackgroundMode(mode, controlItem)
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            ToolbarSeparator { anchors.horizontalCenter: parent.horizontalCenter }
            
            // Sliders (Hover to reveal popover)
            Column {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                
                BackgroundMetricControl {
                    id: padControlVert
                    anchors.horizontalCenter: parent.horizontalCenter
                    compact: true
                    iconName: "padding"
                    valueText: root.backgroundPadding
                    onHovered: (controlItem) => root.backgroundControlHovered("padding", controlItem)
                    onExited: root.backgroundControlExited("padding")
                    onWheeled: (delta) => root.backgroundControlWheel("padding", delta)
                }

                BackgroundMetricControl {
                    id: radControlVert
                    anchors.horizontalCenter: parent.horizontalCenter
                    compact: true
                    iconName: "rounded_corner"
                    valueText: root.backgroundCornerRadius
                    onHovered: (controlItem) => root.backgroundControlHovered("radius", controlItem)
                    onExited: root.backgroundControlExited("radius")
                    onWheeled: (delta) => root.backgroundControlWheel("radius", delta)
                }

                BackgroundMetricControl {
                    id: shadowControlVert
                    anchors.horizontalCenter: parent.horizontalCenter
                    compact: true
                    iconName: "blur_on"
                    valueText: root.backgroundShadowStrength
                    onHovered: (controlItem) => root.backgroundControlHovered("shadow", controlItem)
                    onExited: root.backgroundControlExited("shadow")
                    onWheeled: (delta) => root.backgroundControlWheel("shadow", delta)
                }

                BackgroundMetricControl {
                    id: angleControlVert
                    visible: root.backgroundMode === "gradient" || root.backgroundMode === "conic"
                    height: visible ? implicitHeight : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    compact: true
                    iconName: "rotate_right"
                    valueText: root.backgroundGradientAngle
                    onHovered: (controlItem) => root.backgroundControlHovered("angle", controlItem)
                    onExited: root.backgroundControlExited("angle")
                    onWheeled: (delta) => root.backgroundControlWheel("angle", delta)
                }

                // Custom Aspect Ratio Control
                AspectRatioControl {
                    id: aspectControlVert
                    backgroundAspectRatio: root.backgroundAspectRatio
                    customAspectRatio: root.customAspectRatio
                    compact: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    onHovered: root.backgroundControlHovered("aspectRatio", aspectControlVert)
                    onExited: root.backgroundControlExited("aspectRatio")
                    onWheeled: (delta) => root.backgroundControlWheel("aspectRatio", delta)
                }

                // Alignment Control
                AlignmentControl {
                    id: alignControlVert
                    backgroundAlignment: root.backgroundAlignment
                    compact: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    onHovered: root.backgroundControlHovered("alignment", alignControlVert)
                    onExited: root.backgroundControlExited("alignment")
                }
            }
            
            ToolbarSeparator {
                opacity: root.backgroundMode !== "none" ? 1 : 0
                enabled: root.backgroundMode !== "none"
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Colors (Solid or Gradient)
            Column {
                opacity: root.backgroundMode !== "none" ? 1 : 0
                enabled: root.backgroundMode !== "none"
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                                 BackgroundColorSelectors {
                    isVertical: true
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
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
                    onColorPickerRequested: (currentColor) => root.backgroundColorPickerRequested(currentColor)
                    onEyedropperRequested: (slot) => root.backgroundEyedropperRequested(slot)
                    onImageBlurToggled: (enabled) => root.changeBackgroundImageBlur(enabled)
                    onImageDimToggled: (enabled) => root.changeBackgroundImageDim(enabled)
                    onImageDimControlHovered: (controlItem) => root.backgroundControlHovered("imageDim", controlItem)
                    onImageDimControlExited: root.backgroundControlExited("imageDim")
                    onImageDimControlWheel: (delta) => root.backgroundControlWheel("imageDim", delta)
                }
                
                ColorPaletteGrid {
                    visible: root.backgroundMode !== "image"
                    activeColor: root.activeBackgroundColor
                    activeSlotIndex: -1
                    swatchSize: Constants.swatchSizeVert
                    swatchRadius: Constants.swatchRadiusVert
                    cols: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    onColorSelected: (col, idx) => {
                        if (root.backgroundMode === "solid") {
                            root.changeBackgroundSolidColor(col);
                        } else if (root.backgroundMode === "gradient" || root.backgroundMode === "radial" || root.backgroundMode === "conic") {
                            if (root.gradientActiveSlot === "start") {
                                root.changeBackgroundGradientStart(col);
                            } else {
                                root.changeBackgroundGradientEnd(col);
                            }
                        }
                    }
                }
            }
        }
    }
}
