# Developer & Contributor Guide

Welcome to the Quick Capture contributor guide! This document explains how the code is structured, our coding style conventions, and how to add new vector annotation tools.

---

## 1. Project Directory Structure

```
dms-quick-capture/
├── components/                 # Reusable UI widgets and custom menus
│   ├── DankActionButton.qml    # Base action button
│   ├── MoreToolsMenu.qml       # Secondary dropdown actions (Rotate/Mirror)
│   └── QuickCaptureToolbar.qml # Annotator top toolbar
├── dms-common/                 # DMS core icons and styling helpers
├── translations/               # Localization (TS/QM) files
├── CaptureConfig.qml           # In-memory session configurations
├── plugin.json                 # DMS Plugin Manifest
├── QuickCaptureDaemon.qml      # Main headless process (IPC listener)
├── QuickCaptureModal.qml       # Main canvas/drawing overlays
├── QuickCaptureSettings.qml    # Settings Manager UI panels
└── QuickCaptureWidget.qml      # Panel-Bar icon widget
```

---

## 2. QML Coding Style Conventions

- **ID Naming:** Use camelCase names ending with the component description (e.g., `moreActionsBtn`, `drawingCanvas`).
- **Property Bindings:** Ensure bindings are clean and direct. Avoid javascript heavy code inside inline bindings; delegate to helper functions if logic exceeds 3 lines.
- **Component Separation:** If a widget grows beyond 150 lines or needs to be instantiated multiple times, move it into a standalone file under `components/`.
- **Keyboard Shortcut Handling:** Intercept key actions at the root Modal level via the `Keys.onPressed` handler, checking the active tool to prevent side effects.

---

## 3. How to Add a New Annotation Tool (e.g. "Double Arrow")

Follow this step-by-step workflow to introduce a new vector drawing tool:

### Step A: Define the Tool Constant
In `CaptureConfig.qml` or at the top of `QuickCaptureModal.qml`, declare the new tool identity:
```qml
readonly property string TOOL_DOUBLE_ARROW: "double_arrow"
```

### Step B: Add Button to the Toolbar
In `components/QuickCaptureToolbar.qml`, add a new `DankActionButton` in the tools column/row:
```qml
DankActionButton {
    iconName: "double_arrow"
    tooltipText: qsTr("Double Arrow")
    isSelected: activeTool === TOOL_DOUBLE_ARROW
    onClicked: selectTool(TOOL_DOUBLE_ARROW)
}
```

### Step C: Define Drawing Logic (Coordinates Tracking)
In `QuickCaptureModal.qml`'s mouse area handlers (`onPressed`, `onPositionChanged`, `onReleased`):
```qml
if (activeTool === TOOL_DOUBLE_ARROW) {
    // Save starting point on press, update end point on drag,
    // and append finished vector parameters into drawModel on release.
}
```

### Step D: Add Painting/Drawing Logic
In the QML `Canvas` `onPaint` block, add drawing context path directives:
```qml
function drawDoubleArrow(ctx, startX, startY, endX, endY) {
    ctx.beginPath();
    // Draw the shaft
    ctx.moveTo(startX, startY);
    ctx.lineTo(endX, endY);
    ctx.stroke();
    
    // Draw arrowhead at start
    drawArrowHead(ctx, startX, startY, endX, endY);
    // Draw arrowhead at end
    drawArrowHead(ctx, endX, endY, startX, startY);
}
```

---

## 4. Debugging & Reloading

Since restarting your Linux desktop shell to test a QML modification is slow, we use dynamic reloading:

### IPC Plugin Reload
Reload the plugin dynamically using the DMS CLI:
```bash
dms plugins reload quickCapture
```

### Inspecting Console Logs
View output logs from DMS in a terminal:
```bash
journalctl --user -f -u dank-material-shell
```
Or run DMS in a verbose terminal session to capture standard output directly:
```bash
dms-session-launch --verbose
```
