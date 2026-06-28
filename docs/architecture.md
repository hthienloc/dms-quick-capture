# System Architecture

DMS Quick Capture is designed as a **Composite Plugin** for DankMaterialShell (DMS). This document explains the system architecture, component lifecycles, and window management under Wayland.

---

## 1. Plugin Lifecycle & Composite Model

DMS supports different plugin types (widget, daemon, launcher, desktop). Quick Capture is a **composite plugin**, meaning it bundles multiple execution entry points into a single package.

The configuration in `plugin.json` specifies:
- `daemon`: `./QuickCaptureDaemon.qml` (runs continuously in the background).
- `widget`: `./QuickCaptureWidget.qml` (loaded by DankBar).
- `settings`: `./QuickCaptureSettings.qml` (rendered in the DMS Settings Center).

---

## 2. Core Components

### A. QuickCaptureDaemon
Runs as a headless background daemon in DMS.
- **IPC Interface:** Exposes the `quickCapture` IPC name, allowing other scripts or shell actions to trigger commands like `screenshot`, `fromClipboard`, etc.
- **Screenshot Backend:** Uses Wayland portal mechanisms (or fallback command line utils) to capture display outputs.
- **State Management:** Coordinates the opening and closing of the annotator window.

### B. QuickCaptureWidget
Integrates directly into the DankBar panel.
- **Interactions:**
  - **Left Click:** Launches region capture.
  - **Middle Click:** Triggers a quick full-screen capture.
  - **Right Click:** Annotates the current image in the clipboard.
  - **Drag and Drop:** Accepts image file drops to open them directly in the annotator.

### C. QuickCaptureModal
The main user interface for drawing annotations.
- **Fullscreen Overlay:** Uses `Quickshell.PanelWindow` or fullscreen shell containers.
- **Input Grabbing:** Commands focus immediately upon opening to ensure all key events (`1`–`9`, `Ctrl+Z`, `Enter`, `Esc`) are intercepted by the drawing engine rather than passing through to system applications.
- **Layers:**
  1. **Background Layer:** Screen/Image capture backdrop (supports solid color, gradients, and custom paddings).
  2. **Canvas Layer:** An interactive HTML5-like canvas for vector paths and text boxes.
  3. **Control Overlays:** Toolbars, magnifier lens, callout zoom boxes, and radial presets.

---

## 3. Window & Coordinate Mapping (Wayland)

Under Wayland, absolute window positioning is generally restricted. However, Quickshell permits panel windows to specify anchors, layers, and coordinate mapping.

### Floating Toolbar and Menus (Popout Clipping Fix)
In earlier versions, pop-up menus (like the "More Tools" menu) were declared inside small, local button items (e.g. `36x36px` buttons). Because QML restricts click actions to the bounding box of the parent component, clicking options outside the button coordinates was ignored.

We solved this by elevating the `MoreToolsMenu` to the **Modal Level** (root window) and mapping coordinates dynamically:

```qml
// Triggered on button click inside the toolbar
onMoreToolsClicked: (buttonItem) => {
    // Map the button's (0,0) coordinate to the root content area
    var pt = buttonItem.mapToItem(contentRoot, 0, 0);
    
    // Position the menu dynamically based on toolbar layout orientation
    if (toolbarCard.isVertical) {
        moreToolsMenu.x = pt.x + buttonItem.width + Theme.spacingS;
        moreToolsMenu.y = pt.y;
    } else {
        moreToolsMenu.x = pt.x;
        moreToolsMenu.y = pt.y + buttonItem.height + Theme.spacingS;
    }
    moreToolsMenu.open();
}
```

This architecture ensures menus are rendered on top of all canvas layers and receive all mouse events properly.
