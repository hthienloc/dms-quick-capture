# Glossary

Terms used across the plugin, codebase, and settings to avoid ambiguity.

## Annotation concepts

| Term | Meaning | Notes |
|---|---|---|
| **Tool** | Drawing / editing instrument (pen, line, arrow, rect, etc.) | `toolButtons` in CaptureConfig.qml |
| **Stroke** | A complete drawn path created by the user | Stored in strokes JSON |
| **Annotation** | All strokes + text + stamps on the canvas | Final exported image |
| **Canvas** | The main drawing surface, holds screenshot + annotations | `drawingCanvas` in QuickCaptureModal.qml |
| **Screenshot** | The original captured image (before annotation) | `bgImage`, sits beneath strokes |

## Color / Palette

| Term | Meaning | Notes |
|---|---|---|
| **Palette** | Set of 8 preset colors | Preset (Nord, Solarized, Adaptive) or Custom |
| **Preset** | Built-in color palette (Nord, Solarized, Adaptive) | Read-only, cannot edit directly |
| **Custom palette** | User-defined color palette | Each slot can be overridden |
| **Color slot** | One of 8 color positions on the toolbar | Slot 0 = primary, Slot 1-7 = accent |
| **Slot** | Short for color slot | In code: `toolbar_color_0`, `slot_1`... |
| **Accent color** | Secondary colors (slots 2-8) | As opposed to primary |
| **Primary color** | Main color (slot 1) | Default tool color |

## Toolbar

| Term | Meaning | Notes |
|---|---|---|
| **Toolbar** | Main toolbar with all tools + controls | QuickCaptureToolbar.qml |
| **Horizontal toolbar** | Toolbar at the bottom of the modal | Primary layout, fits all tools |
| **Vertical toolbar** | Toolbar on the left of the modal | Height constrained, needs 2 rows |
| **More tools** | Secondary actions menu: rotate, mirror, OCR, QR | MoreToolsMenu.qml |
| **Action button** | Non-drawing action button | Export, Copy, Float, Undo, Redo |
| **Tool button** | Drawing tool selector | Pen, Line, Arrow, Rect, etc. |

## Backdrop

| Term | Meaning | Notes |
|---|---|---|
| **Backdrop** | Background behind the screenshot | Has padding, shadow, corner radius |
| **Backdrop mode** | Backdrop style: none, solid, gradient, radial, conic | BackdropModeSelectors.qml |
| **Backdrop padding** | Gap from screenshot edge to backdrop edge | Default 40px |
| **Backdrop shadow** | Simulated drop shadow (4 layered rects) | No GPU blur yet |
| **Backdrop alignment** | Screenshot position within the backdrop frame | 9 positions (currently center only) |

## Radial menu

| Term | Meaning | Notes |
|---|---|---|
| **Radial menu** | Ring menu on right-click | RadialMenu.qml |
| **Radial preset** | One of 8 radial menu slots | Each slot: tool + color + thickness |
| **Center button** | Center of the radial menu (selects Select tool) | `centerClicked` signal |
| **Hover trigger** | Auto-select preset on hover | No click needed |
| **Sector** | One slice of the radial menu (1/8 circle) | |

## Capture / Export

| Term | Meaning | Notes |
|---|---|---|
| **Capture** | The act of taking a screenshot | `capture()` function |
| **Region capture** | Capture a selected screen region | |
| **Fullscreen capture** | Capture the entire screen | |
| **Export** | Save annotated image to file | PNG / WebP / JPEG |
| **Float** | Detach current edit into an always-on-top window | Managed by FloatService |
| **Restore from float** | Reopen a floating image for continued editing | |
| **Copy to clipboard** | Copy annotation to clipboard (no file save) | |

## Drawing tools

| Term | Meaning | Notes |
|---|---|---|
| **Pen / Freehand** | Freehand drawing with mouse | `strokeWidth` controls thickness |
| **Line** | Straight line | Click start → drag → release |
| **Arrow** | Line with arrowhead(s) | Double-headed, dashed styles |
| **Rectangle / Rect** | Rectangle shape | Border styles: dashed, dotted |
| **Ellipse** | Ellipse / circle | |
| **Text** | Text annotation | Font size = `thickness` |
| **Pixelate** | Blur a region (mosaic) | `thickness` = pixel block size |
| **Redact** | Cover a region with solid fill | Shape: rectangle (currently) |
| **Stamp** | Number stamp (1, 2, 3...) | |
| **Highlighter** | Semi-transparent highlight | |
| **Spotlight** | Darken area outside spotlight | Aka "focus spotlight" |
| **Callout** | Zoom into a screen region | Aka "area zoom" |
| **Backdrop** | Toggle backdrop mode | Not a drawing tool, it's a mode |

## Actions (non-drawing)

| Term | Meaning | Notes |
|---|---|---|
| **Select** | Select / move existing annotations | Default tool (V key) |
| **Eraser** | Delete strokes / annotations | |
| **Crop** | Crop the image | |
| **Color picker** | Pick a color from the image | Eyedropper (F key) |
| **Rotate** | Rotate image (CW / CCW) | |
| **Mirror** | Flip image (horizontal / vertical) | |
| **OCR** | Extract text from image (copy to clipboard) | |
| **Scan QR** | Scan QR code from image | |
| **Copy Color** | Copy color at click position | Eyedropper action |

## Settings / PluginData

| Term | Meaning | Notes |
|---|---|---|
| **pluginData** | Object holding all plugin settings | Key-value, persisted to file |
| **Setting** | A single configuration value | One key in pluginData |
| **Preset (tool)** | Radial preset = tool + color + thickness | |
| **Preset (palette)** | Built-in color set (Nord, Solarized...) | Context: palette preset |
| **Starting tool** | Tool selected when capture opens | Can be a specific tool or radial preset |
| **Default preset** | Default radial preset on capture | `defaultPresetIndex` (0-7) |

## Misc

| Term | Meaning | Notes |
|---|---|---|
| **Modal** | The main capture window (fullscreen) | QuickCaptureModal.qml |
| **Daemon** | Background service managing lifecycle | QuickCaptureDaemon.qml |
| **Float window** | Small always-on-top window showing annotation | Managed by FloatService |
| **IPC** | Inter-process communication | Uses `dms ipc call` |
| **Stroke state** | Annotations stored per-window in FloatWindow.annotationState | In-memory | |
