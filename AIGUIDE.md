# AIGUIDE.md — DMS Quick Capture Architecture Reference

> For AI agents working on this codebase. Read this before touching any file.

## Project Overview

DMS Quick Capture is a screenshot annotation plugin for [DankMaterialShell](https://github.com/hthienloc/DankMaterialShell) (Quickshell-based Linux desktop shell). It captures screenshots, opens a modal editor with drawing/crop/annotation tools, and exports results to clipboard/file.

**Plugin type**: `daemon` with `control-center` + `dankbar-widget` capabilities.  
**Version**: `2.4.0` — see `plugin.json`.

---

## File Map

| File | Lines | Role |
|------|-------|------|
| `QuickCaptureModal.qml` | ~1994 | **Core**: monolithic modal — all drawing, input, export logic |
| `QuickCaptureWidget.qml` | ~505 | Entry point: capture trigger, clipboard paste, drag-drop, IPC |
| `QuickCaptureSettings.qml` | ~2269 | Settings UI (13+ sections, radial presets, radial menu config) |
| `CaptureConfig.qml` | ~204 | Shared config: 12 tool definitions, color palettes, shortcuts, watermark formatting |
| `components/QuickCaptureActions.qml` | ~360 | Export pipeline: save/copy/notify/float operations |
| `components/QuickCaptureToolbar.qml` | ~287 | Toolbar UI (horizontal/vertical layouts), signal-based state mutations |
| `components/RadialMenu.qml` | ~297 | Right-click pie menu for drawing preset switching |
| `components/TextOptionsRadialMenu.qml` | ~301 | Right-click radial menu on text tool icon for Bold/Italic/Underline toggle |
| `plugin.json` | — | Plugin manifest: id=`quickCapture`, type=`daemon`, version=`2.4.0` |

---

## Data Flow

```
User action (bar click / keybind / IPC / drag-drop)
  → QuickCaptureWidget.triggerCapture(mode)
    → Proc.runCommand("dms screenshot ...") → /tmp/dms_capture_bg.png
    → QuickCaptureModal.open()
      → Modal reads bgImage from /tmp/dms_capture_bg.png
      → User annotates (strokes array, crop, text, etc.)
      → Export: exportAndExecute(callback)
        → exportCanvas.onPaint renders bgImage + annotations + watermark
        → Saves to /tmp/dms_capture_<timestamp>.<format>
        → callback(path) → QuickCaptureActions handles copy/save/notify
```

**Config flow**: All user settings persist via DMS `PluginService` → `pluginData` object on Widget → passed to Modal via `parentWidget` prop → forwarded to CaptureConfig, Actions, Toolbar, RadialMenus.

---

## QuickCaptureModal.qml — Section Map

This is the main file. It is intentionally monolithic — do NOT split it. Use this map to navigate.

### Root & Imports (L1–20)

```
DankModal { id: window }
CaptureConfig { id: config }
```

All properties and functions live on `window`.

### State Properties (L45–250)

| Lines | Properties | Purpose |
|-------|-----------|---------|
| 45 | `layerNamespace`, `keepPopoutsOpen` | DMS modal config |
| 49 | `parentWidget` | Back-ref to QuickCaptureWidget |
| 52–65 | `currentTool`, `lastActiveTool`, `dpr` | Active tool state |
| 68–98 | `strokeWidth`, `pixelateIntensity`, `spotlightIntensity`, `textFontSize`, `effectiveTool`, `activeIntensity` | Per-tool intensity state + `updateActiveIntensity()` |
| 100–178 | `currentColor`, `stampCounter`, `isZoomPressed`, `cursorX/Y`, `showAnnotations`, `copiedStroke`, `strokes`, `currentStroke`, `selectedStroke`, `preGrabStrokeWidth/Color`, `pressCoords`, `originalPoints` | Drawing/selection state |
| 184–213 | `isTyping`, `typingCoords`, `currentTypingText` | Text input state |
| 192 | `backgroundOpacity`, `backgroundColor` | Modal appearance |
| 195–213 | `textMonospace`, `textBold`, `textItalic`, `textUnderline`, `textFontFamily`, `textInputMode`, `toolbarPosition`, `configShowToolbar`, `toolbarVisible` | Config-derived rich text properties |
| 220–246 | `radialPresets`, `presetHistory` | Radial menu preset data |
| 317+ | `fitScale`, `cropRect`, `hasSelection`, `editScale` | Scale/crop computed properties |

### Helper Functions

| Function | Purpose |
|----------|---------|
| `hexToRgb(hex)` | Color conversion via Qt.color() |
| `recordPresetUsage(preset)` | MRU tracking for Tab-toggle (max 2) |
| `performPasteAction()` | Paste copiedStroke centered at cursor |
| `updateRadialPresets()` | Read preset_0..7 from pluginData |
| `getHoveredHandle(mx, my)` | Crop corner hit-test (15px threshold) |
| `isInsideCropRect(mx, my)` | Point-in-rect test |
| `findStrokeAt(mx, my)` | Hit-test all strokes, returns index or -1 |
| `exportAndExecute(callback)` | Trigger export pipeline |
| `getAbsolutePoint(mx, my)` | Canvas → absolute image coords (adds cropRect offset) |
| `shortcutToken(key)` | Qt.Key_* → "A"-"Z", "0"-"9" |
| `handleTypingKey(event)` | Inline text input: Esc/Enter/Backspace/chars |
| `handleShortcutKey(event)` | Master shortcut dispatcher |
| `commitTypingText()` | Finalize text stroke |
| `pushStroke(stroke)` | Immutable append to strokes[] |
| `performUndo()` | Pop last stroke |
| `discardAndClose()` | Close modal |
| `updateActiveIntensity(val)` | Routes value to correct intensity property by effectiveTool |

### Keyboard Shortcuts (`handleShortcutKey`)

| Key | Action |
|-----|--------|
| `Escape` | Close modal |
| `Ctrl+Z` | Undo |
| `Ctrl+C` | Copy to clipboard |
| `Enter` | Done (configurable: copy / save / copy+save) |
| `Ctrl+S` | Save to file |
| `Ctrl+A` | Copy + Save |
| `Ctrl+F` | Float (picture-in-picture) |
| `Ctrl+X` | Toggle crop mode |
| `X` | Toggle annotation visibility (`window.showAnnotations`) |
| `C` | Duplicate selected stroke / paste copied |
| `V` | Select tool |
| `Tab` | Toggle between last 2 presets |
| `B` (hold) | Magnifier loupe |
| `1..4, Q..R, A..F, Z` | Tool shortcuts (from `CaptureConfig.toolShortcuts`) |

### Visual Hierarchy (Content Component)

```
FocusScope (contentRoot)
├── Image (bgImage) — hidden source data for canvas
├── Item (mainLayout)
│   ├── QuickCaptureToolbar (toolbarCard, z:100)
│   ├── Item (boardContainer) — central area
│   │   ├── Item (bgImageLayer)
│   │   │   └── Image (staticBgImage) — visible bg with crop offset
│   │   ├── Canvas (drawingCanvas) — main annotation canvas
│   │   │   ├── onPaint — render pipeline
│   │   │   ├── drawStroke(ctx, stroke) — stroke renderer
│   │   │   ├── MouseArea (drawMouseArea) — all pointer input
│   │   │   └── Rectangle (sizePreviewItem) — width preview
│   │   ├── Rectangle (canvasBorder)
│   │   ├── Popup (textInputDialog) — popup text input mode
│   │   ├── Timer (previewTimer)
│   │   └── Rectangle (magnifier, z:200)
│   │       └── Canvas (magnifierCanvas)
│   ├── Canvas (exportCanvas) — off-screen at (-9999,-9999)
│   ├── RadialMenu (radialMenu) — right-click canvas preset picker
│   ├── TextOptionsRadialMenu (textOptionsRadialMenu) — right-click text icon options
│   └── Canvas (contrastSampler) — 1×1 brightness detector
```

### Canvas Render Pipeline — onPaint

Executed on `drawingCanvas`. Order:

1. **Crop overlay** (crop mode): dim outside selection, border + 4 corner handles
2. **Annotations**: `ctx.save()` → translate by `-cropRect` (annotation mode) or clip to cropRect (crop mode) → loop `drawStroke()` for all `strokes[]` + `currentStroke` → live typing cursor
3. **Watermark preview** (if enabled, not crop mode): text/image/hybrid, 9-position layout

### drawStroke — Tool Rendering

| Tool | Technique | Notable |
|------|-----------|---------|
| `pen` | Polyline (moveTo + lineTo) | Round caps |
| `line` | Two-point line | Round caps |
| `highlighter` | Polyline, 40% alpha, 4× width | `roundHighlighter` setting |
| `rect` | Rounded rect via arcTo | Radius = Theme.cornerRadius + strokeWidth/2 |
| `ellipse` | save/translate/scale/arc/restore | Non-uniform scaling |
| `arrow` | Shortened shaft + triangular head | Head spread π/7, headLength = max(15, width×4) |
| `redact` | Filled rounded rect | Same radius logic as rect |
| `pixelate` | Block-sample from bgImageItem | blockSize = max(8, min(36, width×3)), reads original pixels |
| `stamp` | Filled circle + counter text | Contrast-aware text color (lum > 0.5 → black) |
| `text` | fillText with font styling | Bold/italic/underline/fontFamily from stroke metadata |
| `spotlight` | Dark overlay + bright ellipse cutout | intensity = opacity percentage |

### MouseArea (drawMouseArea) — Input Handling

**onPressed**:
- Right-click → `radialMenu.open()` (preset picker)
- Middle-click → delete stroke under cursor
- Select mode → grab stroke, save preGrab state
- Crop mode → start handle drag or new selection
- Text → start typing (inline or popup)
- Stamp → immediate pushStroke with counter++
- Eraser → bounding-box hit delete
- Default → create new currentStroke

**onPositionChanged**: cursor tracking, stroke drag, crop resize, angle-snap (Shift)

**onReleased**: finalize currentStroke via pushStroke, release crop/select state

**onWheel**: B held → magnifier zoom (1.5–4.0); text tool → textFontSize; callout tool → calloutZoom; else → strokeWidth + preview

---

## Component Details

### QuickCaptureToolbar.qml

Props: `currentTool`, `activeToolType`, `currentColor`, `strokeWidth`, `canUndo`, `isVertical`, `showAnnotations`, `pluginData`

Signals (all mutations route upward via signals — **never set toolbar props directly from toolbar**):

| Signal | Trigger |
|--------|---------|
| `toolSelected(string)` | Tool button click |
| `colorSelected(var)` | Color swatch click |
| `strokeWidthSelected(int)` | Slider change |
| `undoRequested()` | Undo button |
| `annotationsToggled()` | Visibility button click |
| `textToolRightClicked(real, real)` | Right-click on text icon |
| `floatRequested()` | Float button |
| `saveRequested()` | Save button |
| `copyRequested()` | Copy button |
| `copyAndSaveRequested()` | Copy+Save button |
| `closeRequested()` | Close button |

> **Critical**: `showAnnotations` is a **one-way binding** from `window.showAnnotations`. The toolbar emits `annotationsToggled()` and the modal mutates `window.showAnnotations`. Never do `toolbarCard.showAnnotations = value` — it breaks the binding permanently.

### RadialMenu.qml

Right-click on canvas opens preset picker. Sectors = number of presets (up to 8). Hover highlight, center button = Select tool. `hoverTrigger` mode auto-selects on hover after `hoverDelay` ms.

Signals: `presetSelected(preset)`, `centerClicked()`

### TextOptionsRadialMenu.qml

Right-click on the **text tool icon** in toolbar opens this 3-sector radial menu.

Props: `boldActive`, `italicActive`, `underlineActive`  
Signals: `boldToggled()`, `italicToggled()`, `underlineToggled()`, `centerClicked()`

Behavior:
- Sectors toggle Bold / Italic / Underline — **menu stays open after toggle**
- Active sector: solid primary fill + 3px border, icon/label in `onPrimary`
- Hover sector: idle fill + 2px primary border only (no fill change)
- Center button: selects text tool + closes menu
- Clicking outside (scrim): closes menu without selecting

---

## Stroke Object Schema

```js
{
    tool: "pen"|"line"|"arrow"|"rect"|"ellipse"|"highlighter"|"redact"|
          "pixelate"|"stamp"|"eraser"|"text"|"spotlight",
    color: "#rrggbb",         // CSS hex string
    width: Number,            // thickness (or font size for text, intensity % for spotlight)
    points: [Qt.point(x,y)], // absolute image coordinates
    // text-only:
    text: String,
    isMonospace: bool,
    fontFamily: String,
    isBold: bool,
    isItalic: bool,
    isUnderline: bool,
    // stamp-only:
    counter: Number
}
```

Strokes use **absolute image coordinates**. Use `getAbsolutePoint(mx, my)` in MouseArea to convert canvas coords.

---

## Crop vs Annotation Mode

| Aspect | Crop mode (`currentTool === "crop"`) | Annotation mode |
|--------|--------------------------------------|-----------------|
| Canvas size | bgImage.sourceSize | cropRect.width/height |
| fitScale | container / bgImage.sourceSize | min(container / cropRect, 1.0) |
| bgImage position | (0, 0) | (-cropRect.x, -cropRect.y) |
| Annotation render | Clipped to cropRect | Translated by -cropRect |
| Mouse coords | Direct | +cropRect offset via getAbsolutePoint |
| Dimming overlay | Yes | No |

---

## CaptureConfig.qml — Key APIs

- `toolButtons[]`: 12 tool definitions `{id, icon, tooltip}` — drives toolbar and radial menu repeaters
- `accentColors[]`: 7-color palette resolved from preset (adaptive/classic/nord/gruvbox/dracula/catppuccin)
- `toolShortcuts[]` / `colorShortcuts[]`: `{key, tool|color}` mappings
- `resolveColor(rawColor)`: `"primary"` → Theme.primary, `"slot_N"` → accentColors[N-1], else → Qt.color(hex)
- `formatWatermarkText(pattern)`: replaces `{user}`, `%Y/%m/%d/%H/%M/%S`, `\n`

---

## QuickCaptureWidget.qml — Entry Points

| Method | Trigger | What it does |
|--------|---------|-------------|
| `triggerCapture(mode)` | Bar click, CC, IPC | Runs `dms screenshot` → opens modal |
| `fromClipboard()` | Ctrl+V / IPC | Detects image/URL/file in clipboard → opens modal |
| `selectImageAndAnnotate()` | CC button / IPC | FileBrowserModal → opens modal |
| `handleDrop(drop)` | Drag-drop on bar | curl/cp file → opens modal |

**IPC target**: `"quickCapture"` — methods: `screenshot()`, `selectFile()`, `fromClipboard()`, `openImage(path)`, `close()`

---

## Common Pitfalls

1. **QML binding breakage**: Any imperative assignment (`item.prop = value`) to a property that has a declarative binding (`prop: someExpression`) permanently destroys that binding. Pattern: toolbar components emit signals → parent (modal) owns all state mutations.

2. **Coordinate systems**: Strokes store absolute image coords. Canvas translates/clips based on crop state. Always use `getAbsolutePoint()` in MouseArea for press/release, not raw `mouse.x/y`.

3. **Reactivity**: `strokes` array must be replaced immutably (`[...list]`) to trigger QML change signals. In-place mutations (push/splice without reassignment) are invisible to the binding engine.

4. **drawStroke context**: `drawStroke()` is defined on `drawingCanvas`, not `window`. The magnifier calls it as `drawingCanvas.drawStroke(ctx, stroke)`.

5. **Watermark duplication**: Watermark rendering logic exists in BOTH `drawingCanvas.onPaint` (preview) and `exportCanvas.onPaint` (final output). Changes must be applied to both.

6. **Export scaling**: exportCanvas scales by `1/dpr` to produce pixel-accurate output on HiDPI displays.

7. **pixelate tool**: The only tool that samples from `bgImageItem` (original image pixels) during `drawStroke`. All other tools are purely vector.

8. **Intensity routing**: `strokeWidth`, `pixelateIntensity`, `spotlightIntensity`, `textFontSize`, `calloutZoom` are separate properties. Always use `updateActiveIntensity(val)` — it routes to the correct one based on `effectiveTool`.

9. **TextOptionsRadialMenu z-order**: Uses `anchors.fill: parent` + `z: 2000` with a full-screen scrim MouseArea. The scrim must be the *first* child so the menu content renders on top.
