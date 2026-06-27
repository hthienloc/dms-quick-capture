import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import ".."

Rectangle {
    id: root

    property var pluginData: ({})
    CaptureConfig { id: config; pluginData: root.pluginData }

    property string currentTool: "crop"
    property string activeToolType: currentTool
    property color currentColor: Theme.primary
    property int strokeWidth: 8
    property bool canUndo: false
    property bool isVertical: false
    property bool showAnnotations: true

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
    
    readonly property var aspectRatios: ["auto", "1:1", "16:9", "4:3"]
    readonly property var aspectRatioLabels: ["AUTO", "1:1", "16:9", "4:3"]

    property string gradientActiveSlot: "start"

    signal changeBackdropMode(string mode)
    signal changeBackdropSolidColor(color col)
    signal changeBackdropGradientStart(color col)
    signal changeBackdropGradientEnd(color col)
    signal changeBackdropGradientAngle(int angle)
    signal changeBackdropPadding(int padding)
    signal changeBackdropCornerRadius(int radius)
    signal changeBackdropShadowStrength(int strength)
    signal changeBackdropAspectRatio(string ratio)
    signal rotateRequested()
    signal mirrorRequested()
    signal moreToolsClicked(var buttonItem)

    readonly property var toolbarPalette: {
        const p1 = root.pluginData["toolbar_color_primary"] || "primary";
        const slot1 = p1 === "primary" ? Theme.primary : p1;
        return [slot1].concat(config.accentColors);
    }

    signal toolSelected(string tool)
    signal colorSelected(var color)
    signal strokeWidthSelected(int width)
    signal undoRequested()
    signal floatRequested()
    signal saveRequested()
    signal copyRequested()
    signal copyAndSaveRequested()
    signal closeRequested()
    signal textToolRightClicked(real globalX, real globalY)
    signal stampToolRightClicked(real globalX, real globalY)
    signal annotationsToggled()

    width: isVertical ? 56 : (contentLayout.width + Theme.spacingM * 2)
    height: isVertical ? (contentLayout.height + Theme.spacingM * 2) : 56
    radius: Theme.cornerRadius

    readonly property bool showBorder: root.pluginData["showToolbarBorder"] ?? false

    color: Theme.withAlpha(Theme.surfaceContainer, 0.95)
    border.color: showBorder ? Theme.primary : Theme.withAlpha(Theme.outline, 0.15)
    border.width: showBorder ? 1.5 : 1

    Item {
        id: contentLayout
        width: toolbarLoader.item ? toolbarLoader.item.width : 0
        height: toolbarLoader.item ? toolbarLoader.item.height : 0
        anchors.centerIn: parent

        Loader {
            id: toolbarLoader
            anchors.centerIn: parent
            sourceComponent: {
                if (root.currentTool === "backdrop") {
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
                    iconName: "near_me"; buttonSize: 36; iconSize: 18; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: 36; iconSize: 18
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.annotationsToggled()
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18; tooltipText: "Crop (Ctrl+X)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Tools
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: Item {
                        width: 36
                        height: 36
                        DankActionButton {
                            anchors.fill: parent
                            iconName: modelData.icon; buttonSize: 36; iconSize: 18; tooltipText: modelData.tooltip
                            backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                            onClicked: root.toolSelected(modelData.id)
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    var pt = mapToItem(null, 18, 18);
                                    if (modelData.id === "text") {
                                        root.textToolRightClicked(pt.x, pt.y);
                                    } else if (modelData.id === "stamp") {
                                        root.stampToolRightClicked(pt.x, pt.y);
                                    }
                                }
                            }
                        }
                    }
                }
                DankActionButton {
                    id: moreActionsBtn
                    iconName: "more_horiz"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("More Tools")
                    onClicked: root.moreToolsClicked(moreActionsBtn)
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Colors
            Grid {
                rows: 2; columns: 4; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                Repeater {
                    model: root.toolbarPalette
                    delegate: Rectangle {
                        width: 20; height: 20; radius: 10; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: Qt.colorEqual(root.currentColor, modelData) ? 2 : 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

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
                    width: 32; horizontalAlignment: Text.AlignRight
                    color: Theme.surfaceText; font.pixelSize: 11; font.bold: true; anchors.verticalCenter: parent.verticalCenter
                }
                DankSlider {
                    id: hSlider
                    minimum: root.activeToolType === "pixelate" ? 2 : (root.activeToolType === "spotlight" ? 10 : (root.activeToolType === "callout" ? 100 : 1))
                    maximum: root.activeToolType === "pixelate" ? 12 : (root.activeToolType === "text" ? 120 : (root.activeToolType === "spotlight" ? 95 : (root.activeToolType === "callout" ? 500 : 50)))
                    width: 100
                    height: 36
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

            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }

            // Actions
            Row {
                spacing: Theme.spacingXS; anchors.verticalCenter: parent.verticalCenter
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; onClicked: root.undoRequested() }
                DankActionButton { iconName: "picture_in_picture"; buttonSize: 36; iconSize: 18; tooltipText: "Float Window (Ctrl+F)"; onClicked: root.floatRequested() }
                DankActionButton { iconName: "save"; buttonSize: 36; iconSize: 18; tooltipText: "Save to File (Ctrl+S)"; onClicked: root.saveRequested() }
                DankActionButton { iconName: "content_copy"; buttonSize: 36; iconSize: 18; tooltipText: "Copy to Clipboard (Ctrl+C)"; onClicked: root.copyRequested() }
                DankActionButton { iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"; backgroundColor: Theme.withAlpha(Theme.primary, 0.1); iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
                DankActionButton { iconName: "close"; buttonSize: 36; iconSize: 18; iconColor: Theme.error; onClicked: root.closeRequested() }
            }
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
                    iconName: "near_me"; buttonSize: 36; iconSize: 18; tooltipText: "Select (Tab)"
                    backgroundColor: root.currentTool === "select" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "select" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("select")
                }
                DankActionButton {
                    iconName: root.showAnnotations ? "visibility" : "visibility_off"
                    buttonSize: 36; iconSize: 18
                    tooltipText: root.showAnnotations ? "Hide Annotations (X)" : "Show Annotations (X)"
                    iconColor: root.showAnnotations ? Theme.primary : Theme.surfaceText
                    backgroundColor: "transparent"
                    onClicked: root.annotationsToggled()
                }
                DankActionButton {
                    iconName: "crop"; buttonSize: 36; iconSize: 18; tooltipText: "Crop (Ctrl+X)"
                    backgroundColor: root.currentTool === "crop" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.currentTool === "crop" ? Theme.primary : Theme.surfaceText
                    onClicked: root.toolSelected("crop")
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 1; spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: config.toolButtons
                    delegate: Item {
                        width: 36
                        height: 36
                        DankActionButton {
                            anchors.fill: parent
                            iconName: modelData.icon; buttonSize: 36; iconSize: 18
                            backgroundColor: root.currentTool === modelData.id ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                            iconColor: root.currentTool === modelData.id ? Theme.primary : Theme.surfaceText
                            onClicked: root.toolSelected(modelData.id)
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton
                            onClicked: (mouse) => {
                                if (mouse.button === Qt.RightButton) {
                                    var pt = mapToItem(null, 18, 18);
                                    if (modelData.id === "text") {
                                        root.textToolRightClicked(pt.x, pt.y);
                                    } else if (modelData.id === "stamp") {
                                        root.stampToolRightClicked(pt.x, pt.y);
                                    }
                                }
                            }
                        }
                    }
                }
                DankActionButton {
                    id: moreActionsVerticalBtn
                    iconName: "more_vert"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("More Tools")
                    onClicked: root.moreToolsClicked(moreActionsVerticalBtn)
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Grid {
                columns: 2; spacing: 6; anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    model: root.toolbarPalette
                    delegate: Rectangle {
                        width: 18; height: 18; radius: 9; color: modelData
                        border.color: Qt.colorEqual(root.currentColor, modelData) ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: 1
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorSelected(modelData) }
                    }
                }
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            // Thickness Text Only
            Text {
                text: {
                    if (root.activeToolType === "spotlight" || root.activeToolType === "callout") {
                        return root.strokeWidth + "%";
                    }
                    return root.strokeWidth + "px";
                }
                color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }

            Column {
                spacing: Theme.spacingXS; anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton { iconName: "undo"; buttonSize: 36; iconSize: 18; enabled: root.canUndo; opacity: enabled ? 1.0 : 0.4; onClicked: root.undoRequested() }
                DankActionButton { iconName: "done_all"; buttonSize: 36; iconSize: 18; tooltipText: "Copy & Save (Enter)"; backgroundColor: Theme.withAlpha(Theme.primary, 0.1); iconColor: Theme.primary; onClicked: root.copyAndSaveRequested() }
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
                buttonSize: 36
                iconSize: 18
                tooltipText: qsTr("Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }
            
            // Mode selection
            Row {
                spacing: Theme.spacingXS
                anchors.verticalCenter: parent.verticalCenter
                DankActionButton {
                    iconName: "blur_off"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("No Backdrop")
                    backgroundColor: root.backdropMode === "none" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "none" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("none")
                }
                DankActionButton {
                    iconName: "format_color_fill"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("Solid Color")
                    backgroundColor: root.backdropMode === "solid" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "solid" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("solid")
                }
                DankActionButton {
                    iconName: "gradient"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("Linear Gradient")
                    backgroundColor: root.backdropMode === "gradient" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "gradient" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("gradient")
                }
            }
            
            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }
            
            // Aspect Ratio selection (Native DankButtonGroup)
            DankButtonGroup {
                anchors.verticalCenter: parent.verticalCenter
                buttonHeight: 28
                minButtonWidth: 38
                buttonPadding: Theme.spacingS
                checkEnabled: false
                textSize: 10
                model: root.aspectRatioLabels
                currentIndex: root.aspectRatios.indexOf(root.backdropAspectRatio)
                onSelectionChanged: (index, selected) => {
                    if (selected) {
                        root.changeBackdropAspectRatio(root.aspectRatios[index]);
                    }
                }
            }
            
            Rectangle { width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter }
            
            // Sliders Row
            Row {
                spacing: Theme.spacingM
                anchors.verticalCenter: parent.verticalCenter
                
                Row {
                    spacing: Theme.spacingXS
                    Text { text: qsTr("Padding:") + " " + root.backdropPadding + "px"; color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    DankSlider {
                        minimum: 10
                        maximum: 150
                        width: 80
                        height: 36
                        value: root.backdropPadding
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropPadding(val)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Row {
                    spacing: Theme.spacingXS
                    Text { text: qsTr("Radius:") + " " + root.backdropCornerRadius + "px"; color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    DankSlider {
                        minimum: 0
                        maximum: 60
                        width: 80
                        height: 36
                        value: root.backdropCornerRadius
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropCornerRadius(val)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                
                Row {
                    spacing: Theme.spacingXS
                    Text { text: qsTr("Shadow:") + " " + root.backdropShadowStrength + "%"; color: Theme.surfaceText; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                    DankSlider {
                        minimum: 0
                        maximum: 100
                        width: 80
                        height: 36
                        value: root.backdropShadowStrength
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropShadowStrength(val)
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
            
            Rectangle { 
                visible: root.backdropMode !== "none"
                width: 1; height: 24; color: Theme.withAlpha(Theme.outline, 0.2); anchors.verticalCenter: parent.verticalCenter 
            }
            
            // Colors (Solid or Gradient)
            Row {
                visible: root.backdropMode !== "none"
                spacing: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                
                Row {
                    visible: root.backdropMode === "gradient"
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle {
                        width: 24; height: 24; radius: 4; color: root.backdropGradientStart
                        border.color: root.gradientActiveSlot === "start" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: root.gradientActiveSlot === "start" ? 2 : 1
                        MouseArea { anchors.fill: parent; onClicked: root.gradientActiveSlot = "start" }
                    }
                    Rectangle {
                        width: 24; height: 24; radius: 4; color: root.backdropGradientEnd
                        border.color: root.gradientActiveSlot === "end" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: root.gradientActiveSlot === "end" ? 2 : 1
                        MouseArea { anchors.fill: parent; onClicked: root.gradientActiveSlot = "end" }
                    }
                }
                
                Grid {
                    rows: 2; columns: 4; spacing: 4; anchors.verticalCenter: parent.verticalCenter
                    Repeater {
                        model: root.toolbarPalette
                        delegate: Rectangle {
                            width: 16; height: 16; radius: 8; color: modelData
                            border.color: Theme.withAlpha(Theme.outline, 0.3)
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.backdropMode === "solid") {
                                        root.changeBackdropSolidColor(modelData);
                                    } else if (root.backdropMode === "gradient") {
                                        if (root.gradientActiveSlot === "start") {
                                            root.changeBackdropGradientStart(modelData);
                                        } else {
                                            root.changeBackdropGradientEnd(modelData);
                                        }
                                    }
                                }
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
                buttonSize: 36
                iconSize: 18
                tooltipText: qsTr("Back to Annotation (B)")
                onClicked: root.toolSelected("back")
            }
            
            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Mode selection
            Column {
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                DankActionButton {
                    iconName: "blur_off"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("No Backdrop")
                    backgroundColor: root.backdropMode === "none" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "none" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("none")
                }
                DankActionButton {
                    iconName: "format_color_fill"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("Solid Color")
                    backgroundColor: root.backdropMode === "solid" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "solid" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("solid")
                }
                DankActionButton {
                    iconName: "gradient"
                    buttonSize: 36
                    iconSize: 18
                    tooltipText: qsTr("Linear Gradient")
                    backgroundColor: root.backdropMode === "gradient" ? Theme.withAlpha(Theme.primary, 0.15) : "transparent"
                    iconColor: root.backdropMode === "gradient" ? Theme.primary : Theme.surfaceText
                    onClicked: root.changeBackdropMode("gradient")
                }
            }
            
            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Aspect Ratio selection (Vertical Segmented Control)
            Column {
                spacing: Theme.spacingXS
                anchors.horizontalCenter: parent.horizontalCenter
                Repeater {
                    id: verticalRatioRepeater
                    model: root.aspectRatios
                    delegate: Rectangle {
                        id: verticalSegment
                        width: 36
                        height: 28
                        
                        property bool selected: root.backdropAspectRatio === modelData
                        property bool hovered: verticalMouseArea.containsMouse
                        property bool isFirst: index === 0
                        property bool isLast: index === (verticalRatioRepeater.count - 1)
                        
                        color: {
                            if (selected) {
                                if (verticalMouseArea.pressed) return Theme.buttonPressed;
                                if (verticalSegment.hovered) return Theme.buttonHover;
                                return Theme.buttonBg;
                            } else {
                                if (verticalMouseArea.pressed || verticalSegment.hovered) return Theme.surfaceTextHover;
                                return Theme.withAlpha(Theme.surfaceVariant, Theme.popupTransparency);
                            }
                        }
                        
                        radius: (selected || isFirst || isLast) ? Theme.cornerRadius : 0

                        // Mask bottom corners of the first item when not selected
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: parent.radius
                            color: parent.color
                            visible: !verticalSegment.selected && verticalSegment.isFirst && parent.radius > 0
                        }

                        // Mask top corners of the last item when not selected
                        Rectangle {
                            anchors.top: parent.top
                            width: parent.width
                            height: parent.radius
                            color: parent.color
                            visible: !verticalSegment.selected && verticalSegment.isLast && parent.radius > 0
                        }

                        StyledText {
                            text: modelData.toUpperCase()
                            font.pixelSize: 9
                            font.weight: selected ? Font.Medium : Font.Normal
                            color: selected ? Theme.buttonText : Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: verticalMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.changeBackdropAspectRatio(modelData)
                        }
                    }
                }
            }
            
            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Sliders
            Column {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                
                Column {
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: qsTr("Pad:") + " " + root.backdropPadding + "px"; color: Theme.surfaceText; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    DankSlider {
                        minimum: 10
                        maximum: 150
                        width: 42
                        height: 24
                        value: root.backdropPadding
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropPadding(val)
                    }
                }
                
                Column {
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: qsTr("Rad:") + " " + root.backdropCornerRadius + "px"; color: Theme.surfaceText; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    DankSlider {
                        minimum: 0
                        maximum: 60
                        width: 42
                        height: 24
                        value: root.backdropCornerRadius
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropCornerRadius(val)
                    }
                }
                
                Column {
                    spacing: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    Text { text: qsTr("Shd:") + " " + root.backdropShadowStrength + "%"; color: Theme.surfaceText; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                    DankSlider {
                        minimum: 0
                        maximum: 100
                        width: 42
                        height: 24
                        value: root.backdropShadowStrength
                        showValue: false
                        onSliderValueChanged: val => root.changeBackdropShadowStrength(val)
                    }
                }
            }
            
            Rectangle { 
                visible: root.backdropMode !== "none"
                width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter 
            }
            
            // Colors (Solid or Gradient)
            Column {
                visible: root.backdropMode !== "none"
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                
                Row {
                    visible: root.backdropMode === "gradient"
                    spacing: Theme.spacingXS
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Rectangle {
                        width: 18; height: 18; radius: 3; color: root.backdropGradientStart
                        border.color: root.gradientActiveSlot === "start" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: root.gradientActiveSlot === "start" ? 1.5 : 1
                        MouseArea { anchors.fill: parent; onClicked: root.gradientActiveSlot = "start" }
                    }
                    Rectangle {
                        width: 18; height: 18; radius: 3; color: root.backdropGradientEnd
                        border.color: root.gradientActiveSlot === "end" ? Theme.primary : Theme.withAlpha(Theme.outline, 0.3)
                        border.width: root.gradientActiveSlot === "end" ? 1.5 : 1
                        MouseArea { anchors.fill: parent; onClicked: root.gradientActiveSlot = "end" }
                    }
                }
                
                Grid {
                    columns: 2; spacing: 4; anchors.horizontalCenter: parent.horizontalCenter
                    Repeater {
                        model: root.toolbarPalette
                        delegate: Rectangle {
                            width: 14; height: 14; radius: 7; color: modelData
                            border.color: Theme.withAlpha(Theme.outline, 0.3)
                            border.width: 1
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (root.backdropMode === "solid") {
                                        root.changeBackdropSolidColor(modelData);
                                    } else if (root.backdropMode === "gradient") {
                                        if (root.gradientActiveSlot === "start") {
                                            root.changeBackdropGradientStart(modelData);
                                        } else {
                                            root.changeBackdropGradientEnd(modelData);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
