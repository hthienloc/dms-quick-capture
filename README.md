# DMS Quick Capture & Annotate

Interactive Wayland-centric screen capture and instant vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="800" alt="Screenshot">

## Requirements

- DankMaterialShell >= 1.5

## Install

```bash
# Via DMS CLI
dms plugins install quickCapture

# Or manually
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

## Quick Start

| Action | Result |
|--------|--------|
| **Left Click** (bar icon) | Interactive region capture |
| **Middle Click** (bar icon) | Fullscreen capture (all monitors) |
| **Right Click** (bar icon) | Annotate image from clipboard |
| **Drop Image** (bar icon) | Drag any image onto the icon to annotate |
| **Print** (keyboard) | Capture using default mode (requires keybind setup) |

**Typical workflow:**

1. **Trigger capture** — click the bar icon, use Control Center, or press `Print`.
2. **Select area** — drag to choose the screenshot region.
3. **Annotate** — use the toolbar, keyboard shortcuts, or radial menus.
4. **Finish** — press `Enter` (action depends on settings) or `Esc` to discard.

## Annotation Tools

### Tool Selection

| Shortcut | Tool |
|----------|------|
| `1` | Pen |
| `2` | Line |
| `3` | Arrow |
| `4` | Rectangle |
| `Q` | Ellipse |
| `W` | Text |
| `E` | Pixelate |
| `R` | Redact |
| `A` | Stamp |
| `S` | Highlighter |
| `D` | Eraser |
| `F` | Spotlight |
| `Z` | Area Zoom (Callout) |
| `B` | Backdrop Options |
| `V` | Select |
| `X` | Toggle Hide/Show Annotations |
| `Tab` | Toggle between 2 latest radial presets |

### Drawing & Editing

- **Thickness:** Scroll **Mouse Wheel** to scale brush / font size.
- **Quick Erase:** **Middle-click** on any element to delete it.
- **Copy / Duplicate:** Select a vector with the **Select** tool (`V`), then press **C** to duplicate. Pressing **C** without a selection pastes the last copied vector at the cursor.
- **Undo:** `Ctrl + Z`.
- **Shift Constraint:** Hold **Shift** while drawing to constrain shapes:

  | Tool | Shift Behavior |
  |------|----------------|
  | Pen | Draws straight lines |
  | Line, Arrow, Highlighter | Snaps angle to 15° increments |
  | Ellipse | Perfect circle |
  | Rectangle, Redact, Pixelate | Perfect square |

### Radial Menus

| Interaction | Menu |
|-------------|------|
| **Right-click** on canvas | 8 customizable tool presets |
| **Shift+Right-click** (Stamp active) | Counter format: Numeric, Alphabetic, Roman |
| **Shift+Right-click** (Text active) | Toggle Bold, Italic, Underline, Background |
| **Right-click** on toolbar Stamp icon | Counter format selector |
| **Right-click** on toolbar Text icon | Text formatting toggles |

### Special Tools

- **Magnifier Lens:** Hold **G** to activate a magnifying circular lens. Scroll **Mouse Wheel** while holding **G** to adjust zoom (1.5× – 4×).
- **Area Zoom (Callout):** Press **Z** to draw a magnified callout box. Adjust zoom (100%–500%) with scroll wheel.
- **Text Tool:** Supports Bold, Italic, Underline, and auto-contrast Background via the radial menu.

## Keyboard Shortcuts

> Tool selection shortcuts (`1`, `2`, … , `V`, `Tab`) are listed in the [Annotation Tools](#annotation-tools) section above.

| Key | Action |
|-----|--------|
| `Enter` | Done (save/copy per settings) |
| `Esc` | Discard & Close |
| `Ctrl + Z` | Undo last stroke |
| `Ctrl + S` | Save to file |
| `Ctrl + C` | Copy to clipboard |
| `Ctrl + A` | Copy & Save |
| `Ctrl + F` | Float image (requires dms-floaty) |
| `Ctrl + X` | Crop / Resize |
| `Ctrl + 1 – 4` | Select color slots 1 – 4 |
| `Ctrl + Q – R` | Select color slots 5 – 8 (Q, W, E, R) |

## Pin-to-Desktop (Float)

Requires the companion [dms-floaty](https://github.com/hthienloc/dms-floaty) plugin.

- **Ctrl + F** in the annotator to export and float the image instantly.
- Left-click on any floating image in Floaty to return it to the annotator for further editing.

## IPC Commands

```bash
dms ipc call quickCapture <command> [arg]
```

| Command | Argument | Description |
|---------|----------|-------------|
| `screenshot` | `mode` | Trigger capture (`default`, `region`, `full`, `all`, `output`, `window`, `last`) |
| `selectFile` | — | Open file browser to pick an image |
| `fromClipboard` | — | Annotate image from clipboard |
| `openImage` | `path` | Open a specific image in the annotator |
| `close` | — | Close the annotator window |

### Keybinding Examples (Niri)

```kdl
binds {
    Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "default"; }
    Meta+Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "window"; }
}
```

## Roadmap

- [x] OCR (Optical Character Recognition) text scanner
- [x] QR Code Scanner
- [ ] Canvas Color Picker
- [ ] Image Filters (Grayscale, negative, brightness/contrast)
- [ ] Image Backdrop Mode: Support setting a custom image file as the screenshot background

## License

MIT
