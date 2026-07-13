# DMS Quick Capture & Annotate

<p align="center">
  <a href="https://github.com/AvengeMedia/dms-plugin-registry/issues/432">
    <img src="https://img.shields.io/badge/Upvote%20on%20DMS%20Plugin%20Registry-%E2%86%91-blue?style=flat-square" alt="Upvote on DMS Plugin Registry"/>
  </a>
</p>

Screenshot and vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="800" alt="Screenshot">

## Requirements

- DankMaterialShell >= 1.5
- **ImageMagick** (provides `magick`/`mogrify`, required for WebP/JPEG exports, rotation/mirroring, and OCR/QR crop)
- **img2pdf** (required for PDF export)
- **tesseract** (required for OCR text scanner)
- **zbar** (provides `zbarimg`, required for QR scanner)

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
| `D` | Focus Spotlight |
| `F` | Color Picker (Ink/Eyedropper) |
| `T` | Eraser |
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

### Popover Toolbars & Radial Menus

| Interaction | Menu / Popover |
|-------------|----------------|
| **Right-click** on canvas | 8 customizable tool presets |
| **Shift+Right-click** (Stamp active) | Open Stamp Options mini-toolbar (Numeric, Alphabetic, Roman) |
| **Shift+Right-click** (Text active) | Open Text Options mini-toolbar (Bold, Italic, Underline, Background) |
| **Shift+Right-click** (Line active) | Open Line Options mini-toolbar (Solid, Dashed, Dotted) |

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
| `Ctrl + F` | Float image to always-on-top window |
| `Ctrl + X` | Crop / Resize |
| `Ctrl + 1 – 4` | Select color slots 1 – 4 |
| `Ctrl + Q – R` | Select color slots 5 – 8 (Q, W, E, R) |

## Pin-to-Desktop (Float)

- **Ctrl + F** in the annotator to export and float the image instantly.
- **Left-click** the floating image to return it to the annotator for further editing.
- **Right-click** the floating image to minimize it into a small cloud icon.
- **Hover** the cloud icon to restore the floating image.
- **Middle-click** the floating image to close it.

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
- [x] Canvas Color Picker (Eyedropper tool)
- [ ] Image Filters (Grayscale, negative, brightness/contrast)
- [ ] Image Backdrop Mode: Support setting a custom image file as the screenshot background
- [x] Expanded tool option popovers:
  - **Arrow tool**: Double-headed arrows, line styles (dashed, dotted)
  - **Line tool**: Line styles (dashed, dotted)
  - **Rectangle tool**: Border styles (dashed, dotted)
  - **Redact tool**: Clean text eraser (dominant color/gradient background matcher)
  - **Callout tool**: Ellipse callout shape support

## Credits

- **[Gradia Capture](https://github.com/AlexanderVanhee/gradia-capture)** — Inspiration for the toolbar layout and backdrop algorithms
- **[Flameshot](https://github.com/flameshot-org/flameshot)** — Inspiration for the radial menu and tool interaction patterns
- **[Snapzy](https://github.com/duongductrong/Snapzy)** — Inspiration for the float image / continue-editing workflow
- **vky** and **bodify** (Discord) — Actively reporting bugs and contributing valuable feedback to help polish and improve the plugin


## License

MIT
