import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import ".."
import "Helpers.js" as Helpers
import "Constants.js" as Constants

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
    readonly property bool showShortcutHints: root.pluginData["show_shortcut_hints"] ?? false

    // Backdrop configuration properties
    property string backdropMode: "none"
    property color backdropSolidColor: Theme.primary
    property color backdropGradientStart: Theme.primary
    property color backdropGradientEnd: Theme.secondary
    property int backdropGradientAngle: 45
    property int backdropPadding: 40
    property int backdropCornerRadius: 12
    property int backdropShadowStrength: 50
    property string backdropAspectRatio: "auto"
    
    property real customAspectRatio: 1.50
    property string backdropAlignment: "center"

    property string gradientActiveSlot: "start"
    property string backdropColorPickingSlot: "none"

    signal changeBackdropMode(string mode)
    signal changeBackdropSolidColor(color col)
    signal changeBackdropGradientStart(color col)
    signal changeBackdropGradientEnd(color col)
    signal changeBackdropGradientAngle(int angle)
    signal changeBackdropPadding(int padding)
    signal changeBackdropCornerRadius(int radius)
    signal changeBackdropShadowStrength(int strength)
    signal changeBackdropAspectRatio(string ratio)
    signal changeCustomAspectRatio(real ratio)
    signal changeBackdropAlignment(string alignment)
    signal rotateLeftRequested()
    signal rotateRightRequested()
    signal flipHorizontalRequested()
    signal flipVerticalRequested()
    signal rotateRequested()
    signal mirrorRequested()
    signal moreToolsClicked(var buttonItem)
    signal backdropControlHovered(string type, var controlItem)
    signal backdropControlExited(string type)
    signal backdropControlWheel(string type, int delta)
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
    signal copyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()
    signal annotationsToggled()
    signal backdropColorPickerRequested(color currentColor)
    signal backdropEyedropperRequested(string slot)

    readonly property color activeBackdropColor: root.backdropMode === "solid" ?
        root.backdropSolidColor :
        (root.gradientActiveSlot === "start" ? root.backdropGradientStart : root.backdropGradientEnd)



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
                if (root.currentTool === "backdrop" || (root.currentTool === "colorpicker" && root.backdropColorPickingSlot !== "none")) {
                    return root.isVertical ? backdropVerticalLayout : backdropHorizontalLayout;
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
            
            // Left Group
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton {
                    iconName: "near_me"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: Constants.btnSize; iconSize: Constants.iconSize
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.annotationsToggled()
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Crop (Ctrl+X)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Tools
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: Item {
                        width: Constants.btnSize
                        height: Constants.btnSize
                        DankShortcutActionButton {
                            anchors.fill: parent
                            iconName: modelData.icon; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: modelData.tooltip
                            backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                            shortcutText: modelData.shortcut || ""
                            showShortcut: root.showShortcutHints
                            onClicked: root.toolSelected(modelData.id)
                        }

                    }
                }
                DankActionButton {
                    id: moreActionsBtn
                    iconName: "more_horiz"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("More Tools")
                    onClicked: root.moreToolsClicked(moreActionsBtn)
                }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

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

            Item {
                width: Constants.btnSize
                height: Constants.btnSize
                anchors.verticalCenter: parent.verticalCenter
                DankActionButton {
                    id: colorPickerButton
                    anchors.fill: parent
                    iconName: "colorize"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("Color Picker (F for RGB / Right-Click for Eyedropper)")
                    backgroundColor: root.currentTool === "colorpicker" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "colorpicker" ? Theme.primary : Theme.surfaceText
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.toolSelected("colorpicker-draw");
                        } else {
                            root.customColorPickerRequested(colorPickerButton);
                        }
                    }
                }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Thickness Section
            Row {
                spacing: Theme.spacingS; anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: {
                        if (root.activeToolType === "spotlight" || root.activeToolType === "callout") {
                            return root.strokeWidth + "%";
                        }
                        return root.strokeWidth + "px";
                    }
                    width: Constants.btnSize; horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                }
                DankSlider {
                    id: hSlider
                    minimum: root.activeToolType === "pixelate" ? 2 : (root.activeToolType === "spotlight" ? 10 : (root.activeToolType === "callout" ? 100 : 1))
                    maximum: root.activeToolType === "pixelate" ? 12 : (root.activeToolType === "text" ? 120 : (root.activeToolType === "spotlight" ? 95 : (root.activeToolType === "callout" ? 500 : 50)))
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

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // History Actions (Undo & Redo)
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "undo"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; tooltipText: I18n.tr("Undo (Ctrl+Z)"); onClicked: root.undoRequested() }
                DankActionButton { iconName: "redo"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; enabled: root.canRedo; opacity: enabled ? 1.0 : 0.4; tooltipText: I18n.tr("Redo (Ctrl+Y / Ctrl+Shift+Z)"); onClicked: root.redoRequested() }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Export Actions
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "push_pin"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Float Window (Ctrl+F)"; onClicked: root.floatRequested() }
                DankActionButton { iconName: "save"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Save (Ctrl+S)"; onClicked: root.saveRequested() }
                DankActionButton { iconName: "content_copy"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Copy (Ctrl+C)"; onClicked: root.copyRequested() }
                DankActionButton { iconName: "done_all"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Copy & Save (Enter)"; iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            DankActionButton { iconName: "close"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; iconColor: Theme.error; tooltipText: I18n.tr("Discard & Close (Esc)"); anchors.verticalCenter: parent.verticalCenter; onClicked: root.closeRequested() }
        }
    }

    Component {
        id: verticalLayout
        Column {
            id: verticalItems
            spacing: Theme.spacingL
            
            Column {
                spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton {
                    iconName: "near_me"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: Constants.btnSize; iconSize: Constants.iconSize
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.annotationsToggled()
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: "Crop (Ctrl+X)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 1; spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: Item {
                        width: Constants.btnSize
                        height: Constants.btnSize
                        DankShortcutActionButton {
                            anchors.fill: parent
                            iconName: modelData.icon; buttonSize: Constants.btnSize; iconSize: Constants.iconSize; tooltipText: modelData.tooltip
                            backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                            shortcutText: modelData.shortcut || ""
                            showShortcut: root.showShortcutHints
                            onClicked: root.toolSelected(modelData.id)
                        }

                    }
                }
                DankActionButton {
                    id: moreActionsVerticalBtn
                    iconName: "more_vert"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("More Tools")
                    onClicked: root.moreToolsClicked(moreActionsVerticalBtn)
                }
            }

            Rectangle { width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

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

            Item {
                width: Constants.btnSize
                height: Constants.btnSize
                anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton {
                    id: colorPickerVerticalButton
                    anchors.fill: parent
                    iconName: "colorize"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("Color Picker (F for RGB / Right-Click for Eyedropper)")
                    backgroundColor: root.currentTool === "colorpicker" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "colorpicker" ? Theme.primary : Theme.surfaceText
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton) {
                            root.toolSelected("colorpicker-draw");
                        } else {
                            root.customColorPickerRequested(colorPickerVerticalButton);
                        }
                    }
                }
            }
        }
    }

    Component {
        id: backdropHorizontalLayout
        Row {
            spacing: Theme.spacingL
            anchors.verticalCenter: parent.verticalCenter
            
            // Back button
            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                anchors.verticalCenter: parent.verticalCenter
                tooltipText: I18n.tr("Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }
            
            // Presets Control (Bookmarks)
            Item {
                id: presetsControl
                width: Constants.btnSize
                height: Constants.btnSize
                anchors.verticalCenter: parent.verticalCenter

                DankActionButton {
                    iconName: "bookmarks"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("Backdrop Presets")
                    anchors.centerIn: parent
                    onClicked: root.backdropControlHovered("presets", presetsControl)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.backdropControlHovered("presets", presetsControl)
                    onExited: root.backdropControlExited("presets")
                }
            }

            Rectangle { width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            BackdropModeSelectors {
                backdropMode: root.backdropMode
                isVertical: false
                onChangeBackdropMode: (mode) => root.changeBackdropMode(mode)
                anchors.verticalCenter: parent.verticalCenter
            }
            
            // Sliders Row (Hover to reveal popup controls)
            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                
                // Padding Control
                Item {
                    id: padControl
                    width: padRow.implicitWidth
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: padRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "padding"
                            size: Constants.backdropIconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropPadding + "px"
                            width: 40; horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: padMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("padding", padControl)
                        onExited: root.backdropControlExited("padding")
                        onWheel: (wheel) => root.backdropControlWheel("padding", wheel.angleDelta.y)
                    }
                }

                // Corner Radius Control
                Item {
                    id: radControl
                    width: radRow.implicitWidth
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: radRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "rounded_corner"
                            size: Constants.backdropIconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropCornerRadius + "px"
                            width: 40; horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: radMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("radius", radControl)
                        onExited: root.backdropControlExited("radius")
                        onWheel: (wheel) => root.backdropControlWheel("radius", wheel.angleDelta.y)
                    }
                }

                // Shadow Control
                Item {
                    id: shadowControl
                    width: shadowRow.implicitWidth
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: shadowRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "blur_on"
                            size: Constants.backdropIconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropShadowStrength + "%"
                            width: 40; horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: shadowMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("shadow", shadowControl)
                        onExited: root.backdropControlExited("shadow")
                        onWheel: (wheel) => root.backdropControlWheel("shadow", wheel.angleDelta.y)
                    }
                }

                // Angle Control (Linear and Conic gradients)
                Item {
                    id: angleControl
                    visible: root.backdropMode === "gradient" || root.backdropMode === "conic"
                    width: visible ? angleRow.implicitWidth : 0
                    height: Constants.btnSize
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: angleRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "rotate_right"
                            size: Constants.backdropIconSize
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropGradientAngle + "°"
                            width: 40; horizontalAlignment: Text.AlignRight
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: angleMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("angle", angleControl)
                        onExited: root.backdropControlExited("angle")
                        onWheel: (wheel) => root.backdropControlWheel("angle", wheel.angleDelta.y)
                    }
                }

                // Aspect Ratio Control (Hover to reveal preset grid + custom slider popover)
                AspectRatioControl {
                    id: aspectControl
                    backdropAspectRatio: root.backdropAspectRatio
                    customAspectRatio: root.customAspectRatio
                    compact: false
                    anchors.verticalCenter: parent.verticalCenter
                    onHovered: root.backdropControlHovered("aspectRatio", aspectControl)
                    onExited: root.backdropControlExited("aspectRatio")
                    onWheeled: (delta) => root.backdropControlWheel("aspectRatio", delta)
                }

                // Alignment Control (Hover to reveal 3x3 position grid popover)
                AlignmentControl {
                    id: alignControl
                    backdropAlignment: root.backdropAlignment
                    compact: false
                    anchors.verticalCenter: parent.verticalCenter
                    onHovered: root.backdropControlHovered("alignment", alignControl)
                    onExited: root.backdropControlExited("alignment")
                }
            }
            
            Rectangle { 
                opacity: root.backdropMode !== "none" ? 1 : 0
                enabled: root.backdropMode !== "none"
                width: Constants.separatorThickness; height: Constants.separatorLength; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter 
            }
            
            // Colors (Solid or Gradient)
            Row {
                opacity: root.backdropMode !== "none" ? 1 : 0
                enabled: root.backdropMode !== "none"
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                                 BackdropColorSelectors {
                    backdropMode: root.backdropMode
                    backdropSolidColor: root.backdropSolidColor
                    backdropGradientStart: root.backdropGradientStart
                    backdropGradientEnd: root.backdropGradientEnd
                    gradientActiveSlot: root.gradientActiveSlot
                    itemSize: 24
                    iconSize: 18
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
                    onColorPickerRequested: (currentColor) => root.backdropColorPickerRequested(currentColor)
                    onEyedropperRequested: (slot) => root.backdropEyedropperRequested(slot)
                }
                
                ColorPaletteGrid {
                    activeColor: root.activeBackdropColor
                    activeSlotIndex: -1
                    swatchSize: Constants.swatchSize
                    swatchRadius: Constants.swatchRadius
                    cols: 4
                    anchors.verticalCenter: parent.verticalCenter
                    onColorSelected: (col, idx) => {
                        if (root.backdropMode === "solid") {
                            root.changeBackdropSolidColor(col);
                        } else if (root.backdropMode === "gradient" || root.backdropMode === "radial" || root.backdropMode === "conic") {
                            if (root.gradientActiveSlot === "start") {
                                root.changeBackdropGradientStart(col);
                            } else {
                                root.changeBackdropGradientEnd(col);
                            }
                        }
                    }
                }
            }
        }
    }

    Component {
        id: backdropVerticalLayout
        Column {
            spacing: Theme.spacingL
            anchors.horizontalCenter: parent.horizontalCenter
            
            // Back button
            DankActionButton {
                iconName: "arrow_back"
                buttonSize: Constants.btnSize
                iconSize: Constants.iconSize
                tooltipText: I18n.tr("Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            Rectangle { width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Presets Control (Bookmarks)
            Item {
                id: presetsControlVert
                width: Constants.btnSize
                height: Constants.btnSize
                anchors.horizontalCenter: parent.horizontalCenter

                DankActionButton {
                    iconName: "bookmarks"
                    buttonSize: Constants.btnSize
                    iconSize: Constants.iconSize
                    tooltipText: I18n.tr("Backdrop Presets")
                    anchors.centerIn: parent
                    onClicked: root.backdropControlHovered("presets", presetsControlVert)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.backdropControlHovered("presets", presetsControlVert)
                    onExited: root.backdropControlExited("presets")
                }
            }

            Rectangle { width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            BackdropModeSelectors {
                backdropMode: root.backdropMode
                isVertical: true
                onChangeBackdropMode: (mode) => root.changeBackdropMode(mode)
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Rectangle { width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Sliders (Hover to reveal popover)
            Column {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Padding Control
                Item {
                    id: padControlVert
                    width: Constants.btnSize
                    height: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Column {
                        spacing: Constants.spacingCompact
                        anchors.centerIn: parent
                        DankIcon {
                            name: "padding"
                            size: Constants.iconSize
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.backdropPadding
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    MouseArea {
                        id: padMouseAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("padding", padControlVert)
                        onExited: root.backdropControlExited("padding")
                        onWheel: (wheel) => root.backdropControlWheel("padding", wheel.angleDelta.y)
                    }
                }

                // Corner Radius Control
                Item {
                    id: radControlVert
                    width: Constants.btnSize
                    height: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Column {
                        spacing: Constants.spacingCompact
                        anchors.centerIn: parent
                        DankIcon {
                            name: "rounded_corner"
                            size: Constants.iconSize
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.backdropCornerRadius
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    MouseArea {
                        id: radMouseAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("radius", radControlVert)
                        onExited: root.backdropControlExited("radius")
                        onWheel: (wheel) => root.backdropControlWheel("radius", wheel.angleDelta.y)
                    }
                }

                // Shadow Control
                Item {
                    id: shadowControlVert
                    width: Constants.btnSize
                    height: 40
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Column {
                        spacing: Constants.spacingCompact
                        anchors.centerIn: parent
                        DankIcon {
                            name: "blur_on"
                            size: Constants.iconSize
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.backdropShadowStrength
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    MouseArea {
                        id: shadowMouseAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("shadow", shadowControlVert)
                        onExited: root.backdropControlExited("shadow")
                        onWheel: (wheel) => root.backdropControlWheel("shadow", wheel.angleDelta.y)
                    }
                }

                // Angle Control (Linear and Conic gradients)
                Item {
                    id: angleControlVert
                    visible: root.backdropMode === "gradient" || root.backdropMode === "conic"
                    width: Constants.btnSize
                    height: visible ? 40 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Column {
                        spacing: Constants.spacingCompact
                        anchors.centerIn: parent
                        DankIcon {
                            name: "rotate_right"
                            size: Constants.iconSize
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        StyledText {
                            text: root.backdropGradientAngle
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                    MouseArea {
                        id: angleMouseAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("angle", angleControlVert)
                        onExited: root.backdropControlExited("angle")
                        onWheel: (wheel) => root.backdropControlWheel("angle", wheel.angleDelta.y)
                    }
                }

                // Custom Aspect Ratio Control
                AspectRatioControl {
                    id: aspectControlVert
                    backdropAspectRatio: root.backdropAspectRatio
                    customAspectRatio: root.customAspectRatio
                    compact: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    onHovered: root.backdropControlHovered("aspectRatio", aspectControlVert)
                    onExited: root.backdropControlExited("aspectRatio")
                    onWheeled: (delta) => root.backdropControlWheel("aspectRatio", delta)
                }

                // Alignment Control
                AlignmentControl {
                    id: alignControlVert
                    backdropAlignment: root.backdropAlignment
                    compact: true
                    anchors.horizontalCenter: parent.horizontalCenter
                    onHovered: root.backdropControlHovered("alignment", alignControlVert)
                    onExited: root.backdropControlExited("alignment")
                }
            }
            
            Rectangle { 
                opacity: root.backdropMode !== "none" ? 1 : 0
                enabled: root.backdropMode !== "none"
                width: Constants.separatorLength; height: Constants.separatorThickness; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter 
            }
            
            // Colors (Solid or Gradient)
            Column {
                opacity: root.backdropMode !== "none" ? 1 : 0
                enabled: root.backdropMode !== "none"
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                                 BackdropColorSelectors {
                    isVertical: true
                    backdropMode: root.backdropMode
                    backdropSolidColor: root.backdropSolidColor
                    backdropGradientStart: root.backdropGradientStart
                    backdropGradientEnd: root.backdropGradientEnd
                    gradientActiveSlot: root.gradientActiveSlot
                    itemSize: 24
                    iconSize: 18
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
                    onColorPickerRequested: (currentColor) => root.backdropColorPickerRequested(currentColor)
                    onEyedropperRequested: (slot) => root.backdropEyedropperRequested(slot)
                }
                
                ColorPaletteGrid {
                    activeColor: root.activeBackdropColor
                    activeSlotIndex: -1
                    swatchSize: Constants.swatchSizeVert
                    swatchRadius: Constants.swatchRadiusVert
                    cols: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    onColorSelected: (col, idx) => {
                        if (root.backdropMode === "solid") {
                            root.changeBackdropSolidColor(col);
                        } else if (root.backdropMode === "gradient" || root.backdropMode === "radial" || root.backdropMode === "conic") {
                            if (root.gradientActiveSlot === "start") {
                                root.changeBackdropGradientStart(col);
                            } else {
                                root.changeBackdropGradientEnd(col);
                            }
                        }
                    }
                }
            }
        }
    }
}
