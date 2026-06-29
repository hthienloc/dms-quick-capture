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
    
    property real customAspectRatio: 1.50

    readonly property var aspectRatios: ["auto", "1:1", "16:9", "9:16", "4:3", "3:2", "21:9", "custom"]
    readonly property var aspectRatioLabels: ["AUTO", "1:1", "16:9", "9:16", "4:3", "3:2", "21:9", "CUSTOM"]

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
    signal changeCustomAspectRatio(real ratio)
    signal rotateRequested()
    signal mirrorRequested()
    signal moreToolsClicked(var buttonItem)
    signal backdropControlHovered(string type, var controlItem)
    signal backdropControlExited(string type)
    signal backdropControlWheel(string type, int delta)
    signal autoColorBalanceRequested()

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
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: padRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "padding"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropPadding + "px"
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
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: radRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "rounded_corner"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropCornerRadius + "px"
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
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: shadowRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "blur_on"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropShadowStrength + "%"
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
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: angleRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "rotate_right"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropGradientAngle + "°"
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
                Item {
                    id: aspectControl
                    width: aspectRow.implicitWidth
                    height: 36
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Row {
                        id: aspectRow
                        spacing: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        DankIcon {
                            name: "aspect_ratio"
                            size: 16
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: {
                                if (root.backdropAspectRatio === "custom") {
                                    return root.customAspectRatio.toFixed(2);
                                }
                                return root.backdropAspectRatio.toUpperCase();
                            }
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: aspectMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("aspectRatio", aspectControl)
                        onExited: root.backdropControlExited("aspectRatio")
                        onWheel: (wheel) => root.backdropControlWheel("aspectRatio", wheel.angleDelta.y)
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
                
                BackdropColorSelectors {
                    backdropMode: root.backdropMode
                    backdropSolidColor: root.backdropSolidColor
                    backdropGradientStart: root.backdropGradientStart
                    backdropGradientEnd: root.backdropGradientEnd
                    gradientActiveSlot: root.gradientActiveSlot
                    itemSize: 24
                    iconSize: 14
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
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
                                    } else if (root.backdropMode === "gradient" || root.backdropMode === "radial" || root.backdropMode === "conic") {
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
            
            BackdropModeSelectors {
                backdropMode: root.backdropMode
                isVertical: true
                onChangeBackdropMode: (mode) => root.changeBackdropMode(mode)
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            Rectangle { width: 24; height: 1; color: Theme.withAlpha(Theme.outline, 0.2); anchors.horizontalCenter: parent.horizontalCenter }
            
            // Sliders (Hover to reveal popover)
            Column {
                spacing: Theme.spacingS
                anchors.horizontalCenter: parent.horizontalCenter
                
                // Padding Control
                Item {
                    id: padControlVert
                    width: 36
                    height: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        spacing: 2
                        anchors.centerIn: parent
                        DankIcon {
                            name: "padding"
                            size: 14
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropPadding
                            font.pixelSize: 9
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
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
                    width: 36
                    height: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        spacing: 2
                        anchors.centerIn: parent
                        DankIcon {
                            name: "rounded_corner"
                            size: 14
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropCornerRadius
                            font.pixelSize: 9
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
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
                    width: 36
                    height: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        spacing: 2
                        anchors.centerIn: parent
                        DankIcon {
                            name: "blur_on"
                            size: 14
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropShadowStrength
                            font.pixelSize: 9
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
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
                    width: 36
                    height: visible ? 28 : 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        spacing: 2
                        anchors.centerIn: parent
                        DankIcon {
                            name: "rotate_right"
                            size: 14
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropGradientAngle
                            font.pixelSize: 9
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
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
                Item {
                    id: aspectControlVert
                    width: 36
                    height: 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Row {
                        spacing: 2
                        anchors.centerIn: parent
                        DankIcon {
                            name: "aspect_ratio"
                            size: 14
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        StyledText {
                            text: root.backdropAspectRatio === "custom" ? root.customAspectRatio.toFixed(2) : root.backdropAspectRatio.toUpperCase()
                            font.pixelSize: 9
                            color: Theme.surfaceText
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: aspectMouseAreaVert
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.backdropControlHovered("aspectRatio", aspectControlVert)
                        onExited: root.backdropControlExited("aspectRatio")
                        onWheel: (wheel) => root.backdropControlWheel("aspectRatio", wheel.angleDelta.y)
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
                
                BackdropColorSelectors {
                    backdropMode: root.backdropMode
                    backdropSolidColor: root.backdropSolidColor
                    backdropGradientStart: root.backdropGradientStart
                    backdropGradientEnd: root.backdropGradientEnd
                    gradientActiveSlot: root.gradientActiveSlot
                    itemSize: 18
                    iconSize: 10
                    onSetGradientActiveSlot: (slot) => root.gradientActiveSlot = slot
                    onAutoColorBalanceRequested: root.autoColorBalanceRequested()
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
                                    } else if (root.backdropMode === "gradient" || root.backdropMode === "radial" || root.backdropMode === "conic") {
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
