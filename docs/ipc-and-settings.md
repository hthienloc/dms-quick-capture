# IPC Interface & Configuration Schema

This reference outlines the IPC interface, keyboard/mouse shortcut registries, and settings schemas of the Quick Capture plugin.

---

## 1. IPC (Inter-Process Communication) Interface

You can interact with Quick Capture from external scripts, keyboard shortcut managers, or status bar launchers using the DMS IPC commands:

```bash
dms ipc call quickCapture <command> [arg] edit|float
```

### Supported Commands

All commands accept an `action` parameter (`edit` / `float`) — use `float` to spawn an always-on-top window instead of the editor.

| Command | Arguments | Description |
| :--- | :--- | :--- |
| `screenshot` | `mode` (`default`, `region`, `full`, `all`, `output`, `window`, `last`) | Triggers a screenshot. |
| `selectFile` | `action` (`edit` / `float`) | Opens file picker. |
| `fromClipboard` | `action` (`edit` / `float`) | Imports image from clipboard. |
| `openImage` | `path`, `action` (`edit` / `float`) | Opens a local image file. |
| `close` | *(none)* | Closes the annotator. |

```bash
dms ipc call quickCapture screenshot region edit    # open editor
dms ipc call quickCapture screenshot region float   # float directly
```

### Integration Examples

#### Hyprland Keybinds (`hyprland.conf`)
```ini
bind = , Print, exec, dms ipc call quickCapture screenshot region edit
bind = Shift, Print, exec, dms ipc call quickCapture screenshot full edit
bind = Control, Print, exec, dms ipc call quickCapture fromClipboard edit
# Float without editor:
# bind = , Print, exec, dms ipc call quickCapture screenshot region float
```

#### Niri Window Manager Config (`config.kdl`)
```kdl
binds {
    Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "region" "edit"; }
    Meta+Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "window" "edit"; }
}
```

---

## 2. Keyboard & Mouse Shortcut Registry

To facilitate swift editing, Quick Capture implements a comprehensive hotkey mapping.

### Drawing Tool Selection
Pressing these keys changes the active tool:
- `1`: Pen (Freehand drawing)
- `2`: Line
- `3`: Arrow
- `4`: Rectangle
- `S`: Highlighter (Alpha brush)
- `Q`: Ellipse
- `W`: Text Box
- `E`: Pixelate (Redaction blur)
- `R`: Redact (Solid block covering)
- `A`: Stamp (Incremental counters)
- `D`: Spotlight (Darken background outside selection)
- `F`: Color Picker (Ink/Eyedropper)
- `T`: Eraser (Individual vector click eraser)
- `Z`: Area Zoom / Callout box
- `V`: Select / Move tool
- `B`: Backdrop options
- `G` (hold): Magnifier Lens (Cursor zoom)
- `Tab`: Swap between the two most recently used tool presets.

### Action Controls
- `Enter`: Complete and save/copy (depends on preferences).
- `Esc`: Cancel, discard changes, and close.
- `Ctrl + Z`: Undo the latest vector stroke.
- `Ctrl + C`: Copy the current canvas to the clipboard.
- `Ctrl + S`: Save the canvas directly as a file.
- `Ctrl + A`: Copy to clipboard and save as file simultaneously.
- `Ctrl + F`: Float image to always-on-top window.
- `Ctrl + X`: Interactive canvas crop.

### Interactive Modifiers
- **Mouse Scroll Wheel:** Increases/decreases brush stroke size or font size dynamically.
- **Middle-Click on Vector:** Delete clicked vector object instantly.
- **Right-Click on Canvas:** Displays the 8-preset Radial Menu for swift tool/color selection.
- **Shift + Right-Click (Stamp active):** Changes counter format (Numbers, Alphabetical, Roman numerals).
- **Shift + Right-Click (Text active):** Standard text decoration toggle (Bold, Italic, Underline, Background).
- **Shift + Right-Click (Line active):** Changes line style (Solid, Dashed, Dotted).
- **Shift + Right-Click (Arrow active):** Changes arrow line style (Solid, Dashed, Dotted) and head style (Single/Double, Filled/Outline).
- **Shift + Right-Click (Redact active):** Changes redact mode (Solid Fill, Clean Text Eraser).

---

## 3. Configuration & State Schema (`plugin.json`)

The following settings are registered inside DMS settings manager and stored in `~/.config/DankMaterialShell/settings/quickCapture.json`:

```json
{
  "requires_dms": ">=1.5.0",
  "permissions": [
    "settings_read",
    "settings_write",
    "shell_execute"
  ],
  "settings": {
    "exit_method": "confirm",
    "screenshot_folder": "/home/user/Pictures/Screenshots",
    "export_format": "png", // options: png, webp, jpg, pdf, ppm
    "export_compress": true,
    "delete_screenshots_on_close": false,
    "image_padding": 40,
    "image_corner_radius": 12,
    "image_shadow_strength": 50,
    "backdrop_mode": "gradient"
  }
}
```
*(Values can be customized via the Quick Capture Settings tab in DMS panel settings).*
