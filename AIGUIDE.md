# AIGUIDE.md — DMS Quick Capture Architecture Reference

> For AI agents working on this codebase. Read this before touching any file.

## Project Overview

DMS Quick Capture is a screenshot annotation plugin for [DankMaterialShell](https://github.com/hthienloc/DankMaterialShell) (Quickshell-based Linux desktop shell). It captures screenshots, opens a modal editor with drawing/crop/annotation tools, and exports results to clipboard/file.

**Plugin type**: `daemon` with `control-center` capability.

---

## File Map

| File | Lines | Role |
|------|-------|------|
| `QuickCaptureModal.qml` | ~2265 | **Core**: monolithic modal with all drawing, input, export logic |
| `QuickCaptureWidget.qml` | ~481 | Entry point: capture trigger, clipboard paste, drag-drop, IPC |
| `QuickCaptureSettings.qml` | ~2143 | Settings UI (13 sections) |
| `CaptureConfig.qml` | ~240 | Shared config: tool definitions, color palettes, shortcuts, watermark formatting |
| `components/QuickCaptureActions.qml` | ~231 | Export pipeline: save/copy/notify operations |
| `components/QuickCaptureToolbar.qml` | ~240 | Toolbar UI (horizontal/vertical), two-way binds with modal |
| `components/RadialMenu.qml` | ~300 | Right-click pie menu for preset switching |
| `plugin.json` | — | Plugin manifest: id=`quickCapture`, type=`daemon`, version=2.1.0 |

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

**Config flow**: All user settings persist via DMS `PluginService` → `pluginData` object on Widget (`root`) → passed to Modal via `parentWidget` prop → forwarded to CaptureConfig, Actions, Toolbar, RadialMenu.

---

## QuickCaptureModal.qml — Section Map

This is the main file. It is intentionally monolithic — do NOT split it into separate files. Use this map to navigate.

### Imports & Root (L1–18)

```
DankModal { id: window }
CaptureConfig { id: config }
```

All properties and functions below live on `window`.

### Image Loaders (L20–72)

- `watermarkImageLoader`: resolves watermark image with fallback chain (~/.face → AccountsService → icon theme)

### State Properties (L78–218)

| Lines | Properties | Purpose |
|-------|-----------|---------|
| 78 | `parentWidget` | Back-ref to QuickCaptureWidget |
| 80–94 | `currentTool`, `lastActiveTool`, `dpr` | Active tool state |
| 95–127 | `currentColor`, `strokeWidth` | Style state — `onChanged` handlers propagate to selectedStroke |
| 128–156 | `stampCounter`, `isZoomPressed`, `cursorX/Y`, `showAnnotations`, `copiedStroke`, `strokes`, `currentStroke`, `selectedStroke`, `preGrabStrokeWidth/Color`, `pressCoords`, `originalPoints` | Drawing/selection state |
| 157–161 | `isTyping`, `typingCoords`, `currentTypingText` | Text input state |
| 169–199 | `textFontSize`, `textBold/Italic/Underline`, `textFontFamily`, `textInputMode`, `toolbarPosition`, `configShowToolbar`, `enableMagnifier`, `toolbarVisible` | Config-derived properties (from pluginData) |
| 213–218 | `bgImageSource`, `activeCanvas`, `bgImageItem`, `boardContainerItem`, `exportCanvasItem` | Component references (set in Component.onCompleted) |
| 220–246 | `radialPresets`, `presetHistory` | Radial menu preset data |
| 317–332 | `fitScale` | Computed scale to fit image in viewport |
| 334–342 | `cropRect`, `hasSelection`, `activeHandle`, `selectStart` | Crop state |

### Helper Functions (L162–528)

| Function | Line | Signature | Purpose |
|----------|------|-----------|---------|
| `hexToRgb` | 163 | `(hex)` → `{r,g,b}` | Color conversion via Qt.color() |
| `recordPresetUsage` | 224 | `(preset)` | MRU tracking for Tab-toggle (max 2) |
| `performPasteAction` | 248 | `()` | Paste copiedStroke centered at cursor |
| `updateRadialPresets` | 296 | `()` | Read preset_0..7 from pluginData |
| `getHoveredHandle` | 351 | `(mx, my)` → `"tl"\|"tr"\|"bl"\|"br"\|"none"` | Crop corner hit-test (15px threshold) |
| `isInsideCropRect` | 365 | `(mx, my)` → `bool` | Point-in-rect test |
| `constrainSquarePoint` | 371 | `(start, point)` → `point` | Shift-constrain to square |
| `findStrokeAt` | 381 | `(mx, my)` → `int` | Hit-test all strokes, returns index or -1 |
| `exportAndExecute` | 465 | `(callback)` | Trigger export pipeline |
| `shortcutToken` | 484 | `(key)` → `string` | Qt.Key_* → "A"-"Z", "0"-"9" |
| `shortcutColor` | 526 | `(color)` → `color` | Resolve "primary" → Theme.primary |
| `handleTypingKey` | 530 | `(event)` | Inline text input: Esc/Enter/Backspace/chars |
| `handleShortcutKey` | 556 | `(event)` | Master shortcut dispatcher |
| `commitTypingText` | 2221 | `()` | Finalize text stroke |
| `pushStroke` | 2243 | `(stroke)` | Immutable append to strokes[] |
| `performUndo` | 2250 | `()` | Pop last stroke |
| `discardAndClose` | 2262 | `()` | Close modal |

### Keyboard Handling (L556–720)

**Shortcut map** (from `handleShortcutKey`):

| Key | Action |
|-----|--------|
| `Escape` | Close modal |
| `Ctrl+Z` | Undo |
| `Ctrl+C` | Copy to clipboard |
| `Enter` | Done action (configurable) |
| `Ctrl+S` | Save to file |
| `Ctrl+A` | Copy + Save |
| `Ctrl+F` | Float (picture-in-picture) |
| `Ctrl+X` | Toggle crop mode |
| `X` | Toggle annotation visibility |
| `C` | Duplicate selected stroke / paste copied |
| `V` | Select tool |
| `Tab` | Toggle between last 2 presets |
| `Z` (hold) | Magnifier loupe |
| `Ctrl+1..9` | Color shortcuts (from config) |
| `A..Z` (unmapped) | Tool shortcuts (from config) |

**Key handler flow** (`Keys.onPressed`):
1. Tab → preset toggle (skip if < 2 history)
2. Z (no Ctrl) → set `isZoomPressed = true`
3. If `isTyping` → route to `handleTypingKey`
4. Else → route to `handleShortcutKey`

### onOpened (L722–775)

Resets all state. Resolves starting tool/color/thickness from pluginData (preset mode or custom mode). Sets `bgImageSource = "file:///tmp/dms_capture_bg.png"`. Forces focus.

### Content Component — Visual Hierarchy (L777–2218)

```
FocusScope (contentRoot)
├── Image (bgImage) — hidden, source data for canvas
├── Item (mainLayout)
│   ├── QuickCaptureToolbar (toolbarCard) — z:100
│   ├── Item (boardContainer) — central area
│   │   ├── Item (bgImageLayer) — hardware-accelerated bg
│   │   │   └── Image (staticBgImage) — visible bg with crop offset
│   │   ├── Canvas (drawingCanvas) — main annotation canvas
│   │   │   ├── onPaint — render pipeline
│   │   │   ├── drawStroke() — stroke renderer
│   │   │   ├── MouseArea (drawMouseArea) — all input
│   │   │   └── Rectangle (sizePreviewItem) — width preview
│   │   ├── Rectangle (canvasBorder)
│   │   ├── Item (canvasRoundedMask)
│   │   ├── Popup (textInputDialog) — popup text input
│   │   ├── Timer (previewTimer)
│   │   └── Rectangle (magnifier) — z:200
│   │       └── Canvas (magnifierCanvas)
│   ├── Canvas (exportCanvas) — off-screen at (-9999,-9999)
│   ├── RadialMenu (radialMenu)
│   └── Canvas (contrastSampler) — 1x1 brightness detector
```

### Canvas Render Pipeline — onPaint (L932–1173)

Executed on `drawingCanvas`. Order matters:

1. **Crop overlay** (crop mode only): dim outside selection, draw border + 4 corner handles
2. **Annotations**: `ctx.save()` → translate by `-cropRect` offset (if cropped, not in crop mode) or clip to cropRect (if in crop mode with selection) → loop `drawStroke()` for all `strokes[]` + `currentStroke` → draw live typing cursor
3. **Watermark preview** (if enabled, not in crop mode): text/image/hybrid with 9-position layout

### drawStroke (L1175–1416)

Defined as `function drawStroke(ctx, stroke)` on `drawingCanvas`. Handles 11 tool types:

| Tool | Technique | Notable |
|------|-----------|---------|
| `pen` | Polyline (moveTo + lineTo) | Round caps |
| `line` | Two-point line | Round caps |
| `highlighter` | Polyline, 40% alpha, 4x width | Configurable round/square caps via `roundHighlighter` |
| `rect` | Rounded rect via arcTo | Radius = Theme.cornerRadius + strokeWidth/2, configurable via `roundRect` |
| `ellipse` | save/translate/scale/arc/restore | Non-uniform scaling pattern |
| `arrow` | Shortened shaft + triangular head | Head spread = π/7, headLength = max(15, width*4) |
| `redact` | Filled rounded rect | Same radius logic as rect |
| `pixelate` | Block-sample from bgImage | blockSize = max(8, min(36, width*3)), draws dashed border during drag |
| `stamp` | Filled circle + counter text | Contrast-aware text color (lum > 0.5 → black, else white) |
| `text` | fillText with font styling | Bold/italic/underline/fontFamily from stroke metadata |

### MouseArea — drawMouseArea (L1418–1738)

**onPositionChanged** (L1435–1545):
- Updates `cursorX/Y`
- **Select mode**: if stroke grabbed → drag by offset; else → hover highlight via `findStrokeAt`
- **Crop mode**: drag new selection or resize via active handle
- **Drawing mode**: append/update points. Shift = angle snap (45° for line/arrow/highlighter) or square constraint (rect/ellipse/redact/pixelate)

**onPressed** (L1559–1687):
- Right-click → open radial menu
- Middle-click → delete stroke under cursor
- Select mode → grab stroke (save preGrabStrokeWidth/Color, set selectedStroke)
- Crop mode → start handle drag or new selection
- Text → start typing (inline or popup)
- Stamp → immediate pushStroke with counter++
- Eraser → bounding-box hit delete
- Default → create new currentStroke

**onReleased** (L1689–1718):
- Select → release grab, restore preGrab state
- Crop → finalize selection (auto-switch to pen if > 10px)
- Default → push currentStroke

**onWheel** (L1720–1737):
- Z held → adjust magnifier zoomFactor (1.5–4.0)
- Text tool → adjust textFontSize (8–100)
- Else → adjust strokeWidth (1–50) + show preview

### Magnifier (L1898–1986)

- 140px circle, `visible` when Z held + mouse in canvas
- Positioned at cursor mapped to boardContainer coords
- Inner Canvas: clip to circle → translate(center) → scale(zoomFactor) → translate(-cursor) → draw staticBgImage + all strokes via `drawingCanvas.drawStroke()`
- Crosshair: two 16×1.5px rectangles centered
- Zoom: scroll wheel while Z held (step ±0.5)

### Export Canvas (L1989–2178)

Off-screen Canvas. Triggered by `exportAndExecute()`:
1. Scale by 1/dpr
2. Draw bgImage (full or cropped region)
3. Overlay drawingCanvas content
4. Render watermark (duplicated positioning logic from main canvas)
5. Save to `/tmp/dms_capture_<timestamp>.<format>`
6. Invoke callback(path) via Qt.callLater

---

## Stroke Object Schema

```js
{
    tool: "pen"|"line"|"arrow"|"rect"|"ellipse"|"highlighter"|"redact"|"pixelate"|"stamp"|"eraser"|"text",
    color: "#rrggbb",       // CSS hex string
    width: Number,          // stroke thickness (or font size for text)
    points: [Qt.point(x,y), ...],  // absolute image coordinates
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

Strokes use **absolute image coordinates** (not canvas/screen coords). The `getAbsolutePoint(mx, my)` helper in MouseArea adds `cropRect.x/y` offset when in annotation mode with active crop.

---

## Crop vs Annotation Mode

| Aspect | Crop mode (`currentTool === "crop"`) | Annotation mode (any other tool) |
|--------|--------------------------------------|----------------------------------|
| Canvas size | bgImage.sourceSize | cropRect.width/height (if cropped) |
| fitScale | container / bgImage.sourceSize | min(container / cropRect, 1.0) |
| bgImage position | (0, 0) | (-cropRect.x, -cropRect.y) |
| Annotation render | Clipped to cropRect | Translated by -cropRect |
| Mouse coords | Direct | +cropRect offset via getAbsolutePoint |
| Dimming overlay | Yes (outside selection) | No |

---

## CaptureConfig.qml — Key APIs

- `toolButtons[]`: 11 tool definitions `{id, icon, tooltip}` — drives toolbar repeater
- `accentColors[]`: 7-color palette resolved from preset name (adaptive/classic/nord/gruvbox/dracula/catppuccin)
- `toolShortcuts[]`: `{key, tool}` mappings
- `colorShortcuts[]`: `{key, color}` mappings
- `resolveColor(rawColor)`: `"primary"` → Theme.primary, `"slot_N"` → accentColors[N], else → Qt.color(hex)
- `formatWatermarkText(pattern)`: replaces `{user}`, `%Y/%m/%d/%H/%M/%S`, `\n`

---

## QuickCaptureWidget.qml — Entry Points

| Method | Trigger | What it does |
|--------|---------|--------------|
| `triggerCapture(mode)` | Bar click, CC, IPC | Runs `dms screenshot` → opens modal |
| `fromClipboard()` | Ctrl+V / IPC | Detects image/URL/file in clipboard → opens modal |
| `selectImageAndAnnotate()` | CC button / IPC | FileBrowserModal → opens modal |
| `handleDrop(drop)` | Drag-drop on bar | curl/cp file → opens modal |

**IPC target**: `"quickCapture"` with methods: `screenshot()`, `selectFile()`, `fromClipboard()`, `openImage(path)`, `close()`

---

## Common Pitfalls

1. **Binding context**: `drawStroke()` is defined on `drawingCanvas` (not `window`). The magnifier calls it as `drawingCanvas.drawStroke(ctx, stroke)`.
2. **Coordinate systems**: Strokes store absolute image coords. Canvas translates/clips based on crop state. Always use `getAbsolutePoint()` in MouseArea.
3. **Reactivity**: `strokes` array must be replaced immutably (`[...list]`) to trigger QML change signals. In-place mutations are invisible to the binding engine.
4. **Watermark duplication**: Watermark rendering logic exists in BOTH `drawingCanvas.onPaint` (preview) and `exportCanvas.onPaint` (final output). Changes must be applied to both.
5. **Export scaling**: exportCanvas scales by `1/dpr` to produce pixel-accurate output regardless of HiDPI.
6. **pixelate tool**: The only tool that reads from `bgImageItem` during drawStroke — it samples the original image, not the canvas.
