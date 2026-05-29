# DMS Quick Capture & Annotate

Interactive Wayland-centric screen capture and instant vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="800" alt="Screenshot">

## Install

Use the DMS CLI:
```bash
dms plugins install quick-capture
```

Or manually:
```bash
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quick-capture
```

## Features

- **High-Performance Capture:** Decoupled rendering layers for smooth 60fps interaction even on 4K displays.
- **Radial Menu:** Right-click anywhere during capture to access 8 customizable tool presets instantly.
- **Rich Annotation Suite:** Pen, highlighter, lines, arrows, shapes, text notes, stamps, redaction, and pixelation.
- **Workflow Focused:** One-key tool switching, mouse-wheel thickness control, and customizable "Enter" actions.
- **Seamless Integration:** IPC, Control Center, and Niri-ready keybindings.

## Usage

1. **Trigger Capture:** Use the Control Center toggle or your configured `Print` key (via IPC).
2. **Select Region (WIP):** Drag to select a crop area or press `Enter` for full screen.
3. **Annotate:**
   - **Switch Tools:** Use the toolbar or keyboard shortcuts (**1-4**, **Q-R**, **A-D**).
   - **Radial Menu:** **Right-click** to open your custom presets circle.
   - **Thickness:** Use the **Mouse Wheel** to dynamically scale the brush size.
   - **Colors:** Click a color in the toolbar or use **Ctrl + 1-4/Q-R**.
4. **Finish:** Press **Enter** to perform your default action (Save, Copy, or Both) or **Esc** to discard.

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

## IPC Commands

Use `dms ipc call quickCapture <command>` to control the screenshot workflow.

| Command | Description |
|---------|-------------|
| `screenshot` | Trigger interactive region screenshot selection and open annotator |
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
- `wl-clipboard` (required for copying captures to system clipboard)

## Project Structure

```text
dms-quick-capture/
  plugin.json
  QuickCaptureWidget.qml       # DMS entrypoint, IPC, capture lifecycle
  QuickCaptureModal.qml        # Annotation modal and canvas coordination
  QuickCaptureSettings.qml     # Settings UI
  components/
    QuickCaptureActions.qml    # Export, copy, and save actions
    QuickCaptureToolbar.qml    # Annotation toolbar UI
  lib/
    QuickCaptureConfig.qml     # Tool, color, and shortcut config
```

## TODO / Roadmap

- [x] Vector straight-line drawing when holding `Shift` (for Pen and Highlighter).
- [x] Mouse wheel scrolling over canvas to dynamically scale stroke thickness and text font sizes.
- [x] Dynamic high-contrast canvas boundary and auto-adapting backdrop luminance for dark captures.
- [x] Disjoint Copy vs Save toolbar pipelines separating clipboard and filesystem actions.
- [ ] Fix and fully enable the **Click-to-Type Text** annotation tool to reliably capture active keyboard input and support native inline text overlay typing.

## License

MIT
