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

---

## 5. Color Selection, Management & Verification

When working with color palette swatches, backdrop colors, or custom RGB inputs, follow these guidelines to prevent type mismatch bugs and system warnings.

### A. Saving & Formatting Custom Colors
* Custom palette colors are stored in the user settings dictionary (`pluginData`) as 6-character uppercase hex strings (e.g., `"#FF5252"`).
* **Rule**: Always convert QML color objects using `Helpers.formatHexColor(color)` before writing them to the settings storage:
  ```javascript
  const hex = Helpers.formatHexColor(colorValue).toUpperCase();
  ```

### B. Safe Color Comparison
* **Problem**: QML's V4 JS engine represents native colors as `V4ReferenceObject`. Calling string formatting like `.toString()` or `Qt.colorEqual()` directly on them can cause crashes, capitalization mismatches (`#ff5252` vs `#FF5252`), or type warnings (`[object V4ReferenceObject] is not a valid color`).
* **Rule**: **Never** compare colors using direct `===` on string representations or raw `Qt.colorEqual()`.
* **Solution**: Always use the centralized `Helpers.colorEquals(c1, c2, Qt)` function located in `components/Helpers.js`. This function normalizes all types of inputs (strings, objects, alpha channels) into 6-character lowercase strings safely before performing the comparison:
  ```qml
  border.color: Helpers.colorEquals(root.currentColor, modelData, Qt) ? Theme.primary : Theme.outline
  ```

### C. Integrating Color Picker Modal
* Rather than instantiating custom color picker menus, use DMS's native modal service: `PopoutService.colorPickerModal`.
* **Rule**: Always call the centralized `window.openColorPickerModal()` helper in `QuickCaptureModal.qml`. This function handles the DBus modal invocation and automatically falls back to the canvas eyedropper tool if the modal service is unavailable in the environment.

