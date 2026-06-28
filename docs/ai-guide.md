# AI Architecture & Implementation Guide

This guide is structured for AI coding agents developing on the DMS Quick Capture codebase. Review this before proposing or applying code modifications.

---

## 1. Project Overview & File Map

DMS Quick Capture is an interactive vector annotation and screenshot utility for DankMaterialShell (DMS). 

- **Plugin ID:** `quickCapture`
- **Plugin Type:** `composite` (bundles background daemon, bar widget, settings UI)
- **Current Version:** `2.7.1` (see [plugin.json](file:///home/loccun/Documents/GitHub/dms-quick-capture/plugin.json))

### Core Components Map

| File Path | Description | Role |
| :--- | :--- | :--- |
| [QuickCaptureModal.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/QuickCaptureModal.qml) | Fullscreen annotation interface | Main drawing canvas, mouse tracking, keyboard shortcut handlers, cropping math. |
| [QuickCaptureWidget.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/QuickCaptureWidget.qml) | DMS Bar Widget | Capture triggers, clipboard pastes, drag-drop handling, IPC endpoint registry. |
| [QuickCaptureDaemon.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/QuickCaptureDaemon.qml) | Background daemon | Listens to IPC requests, triggers screenshot portal capture, saves backdrop configs. |
| [QuickCaptureSettings.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/QuickCaptureSettings.qml) | Settings Panel UI | Visual settings for brushes, watermarks, radial menus, and preset bindings. |
| [CaptureConfig.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/CaptureConfig.qml) | Configuration model | Defines tool properties, keyboard shortcuts, color palette mappings, watermark templates. |
| [components/QuickCaptureActions.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/components/QuickCaptureActions.qml) | Export action processor | Coordinates file saving, clipboard copy, desktop floating, and system notifications. |
| [components/QuickCaptureToolbar.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/components/QuickCaptureToolbar.qml) | Editor toolbar card | Layout buttons for selected drawing tools, colors, sliders. Supports vertical/horizontal views. |
| [components/MoreToolsMenu.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/components/MoreToolsMenu.qml) | Secondary actions menu | Provides quick controls for Rotate and Mirror operations. |
| [components/RadialMenu.qml](file:///home/loccun/Documents/GitHub/dms-quick-capture/components/RadialMenu.qml) | Pie preset menu | Canvas right-click menu to instantly switch drawing style presets. |

---

## 2. Canvas & Coordinates Coordinate Systems

Annotations are drawn inside a QML `Canvas` object. Coordinate tracking differs between Crop mode and Annotation mode:

- **Absolute Coordinates:** Vector coordinates (stored in `strokes` array) are always relative to the raw screenshot image (`bgImage.sourceSize`).
- **Annotation Mode:** The canvas view is translated by `-cropRect.x` and `-cropRect.y`.
- **Crop Mode:** The canvas renders the full screenshot background but dims areas outside `cropRect`.
- **Mapping Helper:** Mouse positions are mapped to absolute coordinates using `getAbsolutePoint(mx, my)`.

---

## 3. Keyboard Shortcut Dispatcher

Key events are intercepted at the root Modal level via `modalFocusScope.Keys.onPressed` and routed to:
1. `handleTypingKey(event)` if inline text input is active.
2. `handleShortcutKey(event)` for drawing tools and action triggers.

### Complete Tool Mapping Table

| Shortcut Key | Activated Tool / Action | Modifier Constraint |
| :--- | :--- | :--- |
| `1`–`4` | Pen, Line, Arrow, Rectangle | Selects tool |
| `Q`, `W`, `E`, `R` | Ellipse, Text, Pixelate, Redact | Selects tool |
| `A`, `S`, `D`, `F`, `Z` | Stamp, Highlighter, Eraser, Spotlight, Callout | Selects tool |
| `B` | Backdrop Options Toggle | Selects backdrop panel |
| `V` | Select / Move Tool | Selects tool |
| `G` (Hold) | Magnifier Loupe | Enables circular magnifying zoom |
| `Tab` | Presets Toggle | Swaps between 2 latest presets |
| `Esc` | Discard & Close | Closes modal editor |
| `Enter` / `Return` | Done | Triggers save/copy pipeline |
| `Ctrl+Z` | Undo | Reverts last vector stroke |
| `Ctrl+C` | Copy | Copies canvas to clipboard |
| `Ctrl+S` | Save | Saves canvas as file |
| `Ctrl+A` | Copy & Save | Copy and save concurrently |
| `Ctrl+F` | Float | Pins capture on desktop |
| `Ctrl+X` | Crop Mode | Toggles crop frame view |
| `X` | Visibility Toggle | Hides/shows annotation layer |
| `C` | Duplicate / Paste | Clones selection or pastes stroke |

---

## 4. Architecture Constraints & Common Pitfalls

### QML Binding Preservation
To prevent destroying reactive QML property bindings:
- **Rule:** Never assign property values directly from child widgets (e.g. do not write `toolbarCard.showAnnotations = false`).
- **Pattern:** Children must emit action signals (e.g., `annotationsToggled()`) and let the root `QuickCaptureModal` handle the state mutation.

### Reactivity of Arrays
The QML engine cannot detect in-place push or splice operations on lists.
- **Rule:** When modifying the `strokes` array, assign it immutably to trigger update notifications:
  ```js
  window.strokes = [...window.strokes, newStroke];
  ```

### Drawing Context Execution
- The `drawStroke()` function is bound to the `drawingCanvas` context.
- When drawing from outside components (e.g. Magnifier Canvas), call it through the canvas id:
  ```js
  drawingCanvas.drawStroke(ctx, stroke);
  ```

### Popout Clipping Avoidance
To avoid events being clipped by QML layout boundaries, floating dialogs (like `MoreToolsMenu` or text presets) must be instantiated as direct children of the fullscreen root container (`contentRoot`) and aligned dynamically using `mapToItem()`.
