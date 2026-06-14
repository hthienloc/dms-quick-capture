# DMS Quick Capture & Annotate

Interactive Wayland-centric screen capture and instant vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="800" alt="Screenshot">

## Install

Use the DMS CLI:
```bash
dms plugins install quickCapture
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

## Features

- **High-Performance Capture:** Decoupled rendering layers for smooth 60fps interaction even on 4K displays.
- **Radial Menu:** Right-click anywhere during capture to access 8 customizable tool presets instantly.
- **Rich Annotation Suite:** Pen, highlighter, lines, arrows, shapes, text notes, stamps, redaction, and pixelation.
- **Workflow Focused:** One-key tool switching, mouse-wheel thickness control, and customizable "Enter" actions.
- **Seamless Integration:** IPC, Control Center, and Niri-ready keybindings.

### Bar Interactions

| Action | Result |
|--------|--------|
| **Left Click** | Trigger interactive screenshot capture |
| **Middle Click** | Capture fullscreen (all monitors) instantly |
| **Right Click** | Annotate image from clipboard (supports raw images, paths, and URLs) |
| **Drop Image** | Drag any image file onto the icon to annotate it |

### Capture Workflow

1. **Trigger:** Use the bar icon, Control Center, or your `Print` key.
2. **Select Area:** Drag to select the screenshot region.
3. **Annotate:**
   - **Switch Tools:** Use keyboard shortcuts (**1-4**, **Q-R**, **A-F**, **V** for Select, or **Tab** to toggle latest presets).
   - **Copy/Duplicate Vector:** Press **V** to switch to the select tool, click a vector to grab it, then press **C** to duplicate it instantly. Pressing **C** without a selection will paste the last copied vector at the cursor position.
   - **Radial Menu:** **Right-click** on the canvas to open custom presets.
   - **Text Options:** **Right-click** on the Text tool icon in the toolbar to toggle **Bold**, **Italic**, **Underline**, and **Background** (with automatic high-contrast coloring).
   - **Stamp Options:** **Right-click** on the Stamp tool icon in the toolbar to switch between **Numeric** (1, 2, 3), **Alphabetic** (A, B, C), and **Roman** (I, II, III) formats.
   - **Thickness:** Use the **Mouse Wheel** to scale the brush size.
   - **Zoom / Magnify:** Hold **Z** to activate the magnifying circular lens under the cursor, and scroll the **Mouse Wheel** while holding **Z** to adjust the zoom factor (1.5x - 4x).
   - **Quick Erase:** **Middle-click** on any element to erase it.
   - **Shift Constraint:** Hold **Shift** while drawing to modify vector output:
     - **Pen**: Draws straight lines instead of freeform drawings.
     - **Highlighter, Line, Arrow**: Locks and snaps the drawing angle to 45-degree increments.
     - **Ellipse**: Constrains the shape to draw a perfect circle.
     - **Rectangle, Redact, Pixelate**: Constrains the shape to draw a perfect square.
4. **Finish:**
   - Press **Ctrl + S** to force save, **Ctrl + C** to copy to clipboard, or **Ctrl + A** to copy and save simultaneously.
   - Press **Ctrl + F** to float the image on your desktop.
   - Press **Ctrl + X** to enter crop / resize mode.
   - Press **Enter** to save/copy (based on settings) or **Esc** to discard.

### Pin-to-Desktop (Float Screen)

To pin your captured and annotated screenshots as borderless, floating desktop widgets (always-on-top picture-in-picture windows), you can use the companion [dms-floaty](https://github.com/hthienloc/dms-floaty) plugin. Floaty integrates seamlessly with `dms-quick-capture` out-of-the-box, allowing you to reference your screenshots side-by-side while writing code or designing.

- Press **Ctrl + F** in the annotator to export and float the image instantly.
- Left-click on any floating image in Floaty to return it to the `dms-quick-capture` annotator interface for further editing.

## Keyboard Shortcuts

| Key | Tool / Action |
|-----|---------------|
| `Tab` | Toggle between 2 latest radial presets |
| `Z` | Hold Zoom / Magnify under cursor |
| `X` | Toggle Hide/Show Annotations |
| `V` | Switch to Select Tool |
| `C` | Copy vector / Paste / Duplicate |
| `1` - `4` | Pen, Line, Arrow, Rect |
| `Q` - `R` | Ellipse, Text, Pixelate, Redact |
| `A` - `F` | Stamp, Highlighter, Eraser, Spotlight |
| `Enter` | **Done** (Action based on settings) |
| `Esc` | Discard & Close |
| `Ctrl + Z` | Undo last stroke |
| `Ctrl + S` | Force Save to File |
| `Ctrl + C` | Force Copy to Clipboard |
| `Ctrl + A` | Force Copy & Save |
| `Ctrl + F` | Float Image (via Floaty companion) |
| `Ctrl + X` | Crop / Resize Area |
| `Ctrl + 1` - `4` | Select Color Slots 1 - 4 |
| `Ctrl + Q` - `R` | Select Color Slots 5 - 8 (Q, W, E, R) |

## IPC Commands

Use `dms ipc call quickCapture <command> [arg]` to control the screenshot workflow.

| Command | Argument | Description |
|---------|----------|-------------|
| `screenshot` | `mode` | Trigger capture (modes: `default`, `region`, `full`, `all`, `output`, `window`, `last`) |
| `selectFile` | - | Open file browser to select an existing image |
| `fromClipboard` | - | Annotate image from clipboard (supports raw images, local file paths, and URLs) |
| `openImage` | `path` | Copy/download and open a specific image path in the annotator |
| `close` | - | Close the quick capture annotator window |

### Keybinding examples (Niri)

```kdl
binds {
    // Capture using default configured mode
    Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "default"; }
    // Capture specific window mode directly
    Meta+Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "window"; }
}
```

## Requirements

- DankMaterialShell >= 1.5

## TODO / Roadmap

- [x] Vector straight-line drawing when holding `Shift` (for Pen and Highlighter).
- [x] Mouse wheel scrolling over canvas to dynamically scale stroke thickness and text font sizes.
- [x] Dynamic high-contrast canvas boundary and auto-adapting backdrop luminance for dark captures.
- [x] Disjoint Copy vs Save toolbar pipelines separating clipboard and filesystem actions.
- [x] Fix and fully enable the **Click-to-Type Text** annotation tool to reliably capture active keyboard input and support native inline text overlay typing.
- [x] Magnifying Glass (Loupe) for pixel-perfect placement and crop alignment (hold Z to activate, mouse wheel while holding Z to adjust zoom).
- [x] Custom Text/Image Watermark or signature overlay stamp with adjustable opacity.
- [x] Support picture-in-picture screenshot pinning (pin-to-desktop) documentation.
- [x] Text formatting radial menu (Bold / Italic / Underline / Background) accessible via right-click on the Text tool icon.
- [x] Adjustable text background roundness (Settings -> Shapes).
- [x] Alternative Counter formats (Numeric, Alphabetic, Roman) for the Stamp tool via right-click radial menu.

## License

MIT
