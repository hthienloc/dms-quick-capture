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

## Usage

### Bar Interactions

| Action | Result |
|--------|--------|
| **Left Click** | Trigger interactive screenshot capture |
| **Right Click** | Open file browser to select an existing image |
| **Drop Image** | Drag any image file onto the icon to annotate it |

### Capture Workflow

1. **Trigger:** Use the bar icon, Control Center, or your `Print` key.
2. **Select Area:** Drag to select the screenshot region.
3. **Annotate:**
   - **Switch Tools:** Use keyboard shortcuts (**1-4**, **Q-R**, **A-D**).
   - **Radial Menu:** **Right-click** to open custom presets.
   - **Thickness:** Use the **Mouse Wheel** to scale the brush size.
   - **Quick Erase:** **Middle-click** on any element to erase it.
4. **Finish:** Press **Enter** to save/copy or **Esc** to discard.

## Keyboard Shortcuts

| Key | Tool / Action |
|-----|---------------|
| `V` | Select / Move stroke |
| `1` - `4` | Pen, Line, Arrow, Rect |
| `Q` - `R` | Ellipse, Text, Pixelate, Redact |
| `A` - `D` | Stamp, Highlighter, Eraser |
| `P` | Crop / Resize Area |
| `Enter` | **Done** (Action based on settings) |
| `Esc` | Discard & Close |
| `Ctrl + Z` | Undo last stroke |
| `Ctrl + S` | Force Save to File |
| `Ctrl + C` | Force Copy to Clipboard |
| `Ctrl + 1` - `4` | Select Color Slots 1 - 4 |
| `Ctrl + Q` - `R` | Select Color Slots 5 - 8 (Q, W, E, R) |

## IPC Commands

Use `dms ipc call quickCapture <command>` to control the screenshot workflow.

| Command | Description |
|---------|-------------|
| `screenshot` | Trigger interactive region screenshot selection |
| `selectFile` | Open file browser to select an existing image |
| `toggle` | Toggle the quick capture annotator window |
| `close` | Close the quick capture annotator window |

### Keybinding example (Niri)

```kdl
binds {
    Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot"; }
}
```

## Requirements

- DankMaterialShell >= 1.5

## TODO / Roadmap

- [x] Vector straight-line drawing when holding `Shift` (for Pen and Highlighter).
- [x] Mouse wheel scrolling over canvas to dynamically scale stroke thickness and text font sizes.
- [x] Dynamic high-contrast canvas boundary and auto-adapting backdrop luminance for dark captures.
- [x] Disjoint Copy vs Save toolbar pipelines separating clipboard and filesystem actions.
- [ ] Fix and fully enable the **Click-to-Type Text** annotation tool to reliably capture active keyboard input and support native inline text overlay typing.

## License

MIT
