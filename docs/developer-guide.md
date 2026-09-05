# Developer & Contributor Guide

Welcome to the Quick Capture contributor guide. This document covers the actual file layout, coding conventions, and step-by-step instructions for adding a new annotation tool.

---

## 1. Project Directory Structure

```
dms-quick-capture/
├── components/
│   ├── core/                        # Canvas, render, export, constants, helpers
│   ├── toolbar/                     # Main toolbar and reusable toolbar controls
│   │   └── options/                 # Per-tool sub-toolbars
│   ├── background/                  # Background mode controls
│   ├── popovers/                    # Floating menus, sliders, dialogs
│   ├── floating/                    # Float window service and window instance
│   ├── history/                     # Recent edits carousel
│   └── misc/                        # Radial menu, magnifier, warning dialog
├── dms-common/                      # Shared DMS UI primitives (sliders, toggles, settings cards)
├── docs/                            # Documentation
├── scripts/                         # Dev utilities (palette generator, i18n extractor)
├── translations/                    # Localization files
├── CaptureConfig.qml                # Tool list, shortcut table, color palette data, i18n strings
├── QuickCaptureDaemon.qml           # Background daemon — IPC listener, screenshot portal
├── QuickCaptureModal.qml            # Main editor window — canvas layers, state, keyboard handler
├── QuickCaptureSettings.qml         # DMS Settings panel UI
├── QuickCaptureWidget.qml           # DankBar widget — click/drag triggers
└── plugin.json                      # DMS plugin manifest
```

---

## 2. Where To Find Things (Quick Reference)

| What you want to change | Where to look |
|---|---|
| Add/rename a tool | `CaptureConfig.qml` → `toolButtons` array |
| Tool slider range / step / unit | `components/core/Constants.js` → `ToolMetadata` |
| Add a keyboard shortcut | `CaptureConfig.qml` → shortcut table + `QuickCaptureModal.qml` → `handleShortcutKey()` |
| Drawing logic for a tool | `components/core/DrawingRenderer.js` → `drawStroke()` |
| Mouse press/drag/release behavior | `components/core/DrawMouseArea.qml` |
| Hit-testing / selection geometry | `components/core/Helpers.js` → `findStrokeAt()`, `getStrokeHandleAt()` |
| Stroke bounding box | `components/core/Helpers.js` → `getStrokeBBox()` |
| Export / copy / save pipeline | `components/core/QuickCaptureActions.qml` |
| Color utilities | `components/core/Helpers.js` → `formatHexColor()`, `colorEquals()`, `getContrastingColor()` |
| Shared layout/sizing constants | `components/core/Constants.js` |
| Add a toolbar button | `components/toolbar/QuickCaptureToolbar.qml` |
| Per-tool sub-toolbar (options) | `components/toolbar/options/*OptionsToolbar.qml` |
| i18n string | `CaptureConfig.qml` or component → wrap with `I18n.trFor("quickCapture", ...)` |

---

## 3. Key Architectural Patterns

### The `window` prefix in JS files

All `.js` library files (Helpers, DrawingRenderer, DrawMouseArea) use `.pragma library`, which means they are stateless singletons — they have no access to QML context. State is passed in explicitly via function arguments, typically as a `window` object reference or a `config` object.

When you see `window.currentTool` or `window.strokes` in DrawMouseArea.qml, `window` is a `required property var window` pointing to the root `QuickCaptureModal.qml` item. Never access parent properties by traversing up the tree — always pass them explicitly.

### Immutable array updates

QML's engine cannot detect in-place mutations on lists. Always reassign the array to trigger reactive updates:

```js
// ✅ correct
window.strokes = [...window.strokes, newStroke];

// ❌ wrong — no change notification fired
window.strokes.push(newStroke);
```

### Signal-up, never write-down

Children must not mutate parent state directly. Instead, emit a signal and let the root Modal handle it:

```qml
// ❌ wrong — breaks QML binding
toolbarCard.showAnnotations = false;

// ✅ correct — child signals, parent handles
onAnnotationsToggled: window.showAnnotations = !window.showAnnotations
```

### Popout clipping

Floating overlays (menus, popovers) must be instantiated as direct children of the fullscreen `contentRoot`, not inside a toolbar button. Use `mapToItem(contentRoot, 0, 0)` to position them relative to the trigger button.

---

## 4. QML Coding Style

- **IDs:** camelCase, descriptive noun (`drawingCanvas`, `moreActionsBtn`, `previewTimer`)
- **Property bindings:** Keep inline bindings simple. If logic exceeds 3 lines, move it to a named function.
- **Component size:** If a component grows past ~150 lines or is reused, extract it to `components/`.
- **Keyboard handling:** All key events are intercepted at the root Modal via `modalFocusScope.Keys.onPressed` → `handleShortcutKey()`. Do not add `Keys.onPressed` handlers in child components.
- **Colors:** Always use `Helpers.formatHexColor()` before storing colors to `pluginData`. Always use `Helpers.colorEquals(c1, c2, Qt)` for comparison — never raw `===` on color objects.

---

## 5. How To Add a New Annotation Tool

This is the canonical flow. Follow every step in order.

### Step 1 — Register the tool in `CaptureConfig.qml`

Add an entry to the `toolButtons` array. The `id` is the string used everywhere as the tool identifier:

```qml
// CaptureConfig.qml — toolButtons array
{ id: "double_arrow", icon: "sync_alt", shortcut: "X", tooltip: I18n.trFor("quickCapture", "Double Arrow (X)") }
```

### Step 2 — Define slider metadata in `Constants.js`

Every tool that has a thickness/intensity slider needs an entry in `ToolMetadata`. If your tool reuses an existing behavior (e.g. thickness like a pen), copy an existing entry:

```js
// components/core/Constants.js — ToolMetadata object
double_arrow: { min: 1, max: 50, step: 1, unit: "px", defaultValue: 8, label: "Thickness", previewType: "thickness" },
```

### Step 3 — Add the drawing logic in `DrawingRenderer.js`

Inside `drawStroke()`, add a new `else if` branch for your tool. The function receives `ctx` (Canvas 2D context), `stroke` (the stroke data object), and a `config` object with all render-time state:

```js
// components/core/DrawingRenderer.js — inside drawStroke()
} else if (stroke.tool === "double_arrow") {
    // stroke.points[0] = start, stroke.points[last] = end
    const p0 = stroke.points[0];
    const p1 = stroke.points[stroke.points.length - 1];
    ctx.beginPath();
    ctx.moveTo(p0.x, p0.y);
    ctx.lineTo(p1.x, p1.y);
    ctx.strokeStyle = stroke.color;
    ctx.lineWidth = stroke.width;
    ctx.stroke();
    drawArrowHead(ctx, p0, p1, stroke);
    drawArrowHead(ctx, p1, p0, stroke);
}
```

### Step 4 — Handle mouse input in `DrawMouseArea.qml`

The mouse area already handles start/drag/release generically for two-point tools (line, arrow, rect, etc.). If your tool follows the same two-point pattern, it may work automatically. If it needs custom drag behavior, add a branch in `onPositionChanged` and `onReleased`.

Also add your tool's ID to the `effectiveTool` computed property guard in `QuickCaptureModal.qml` if it needs special cursor or preview treatment.

### Step 5 — Define hit-testing in `Helpers.js`

For the Select tool to work with your new stroke, add a branch in `getStrokeBBox()` and `findStrokeAt()` so the user can click and select it:

```js
// components/core/Helpers.js — inside getStrokeBBox()
if (stroke.tool === "double_arrow") {
    // same as arrow bounding box
    return getArrowBBox(stroke);
}
```

### Step 6 — Add a toolbar button in `QuickCaptureToolbar.qml`

Find the tools section in the toolbar and add a `DankActionButton`. The toolbar reads tool metadata from `CaptureConfig.toolButtons`, so in many cases just adding the `CaptureConfig` entry (Step 1) is enough if the toolbar iterates the array. Check whether the toolbar uses the array directly or has hardcoded entries.

### Step 7 — (Optional) Add a per-tool options sub-toolbar

If your tool has style variants (e.g. dashed/dotted, head shapes), create a new `components/toolbar/options/YourToolOptionsToolbar.qml` following the pattern of `ArrowOptionsToolbar.qml`. Mount it in `QuickCaptureToolbar.qml` and show/hide it based on `effectiveTool`.

---

## 6. Debugging & Reloading

### Reload the plugin without restarting the shell

```bash
dms plugins reload quickCapture
```

### View live logs

```bash
journalctl --user -f -u dank-material-shell
```

Or in a verbose DMS session:

```bash
dms-session-launch --verbose
```

### Common mistakes

| Symptom | Likely cause |
|---|---|
| New tool draws nothing | Missing branch in `DrawingRenderer.drawStroke()` |
| Select tool can't grab new strokes | Missing branch in `Helpers.findStrokeAt()` or `getStrokeBBox()` |
| Slider doesn't appear for new tool | Missing entry in `Constants.ToolMetadata` |
| Tool button not in toolbar | `CaptureConfig.toolButtons` entry missing, or toolbar doesn't iterate the array |
| Shortcut key does nothing | Not added to `handleShortcutKey()` in `QuickCaptureModal.qml` |
| Canvas doesn't update after state change | Array was mutated in-place — use spread: `[...arr, newItem]` |
