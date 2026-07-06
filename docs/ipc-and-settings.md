# IPC Interface & Configuration Schema

This reference outlines the IPC interface, keyboard/mouse shortcut registries, and settings schemas of the Quick Capture plugin.

---

## 1. IPC (Inter-Process Communication) Interface

You can interact with Quick Capture from external scripts, keyboard shortcut managers, or status bar launchers using the DMS IPC commands:

```bash
dms ipc call quickCapture <command> [arg]
```

### Supported Commands

| Command | Argument | Description |
| :--- | :--- | :--- |
| `screenshot` | `default`, `region`, `full`, `all`, `output`, `window`, `last` | Triggers a screenshot capture using the specified mode. |
| `selectFile` | *(none)* | Opens a file picker dialog to load an image for annotation. |
| `fromClipboard` | *(none)* | Imports an image directly from the system clipboard. |
| `openImage` | `absolute_file_path` | Opens a specific local image file in the annotator. |
| `close` | *(none)* | Immediately closes the annotator interface. |

### Integration Examples

#### Hyprland Keybinds (`hyprland.conf`)
```ini
bind = , Print, exec, dms ipc call quickCapture screenshot region
bind = Shift, Print, exec, dms ipc call quickCapture screenshot full
bind = Control, Print, exec, dms ipc call quickCapture fromClipboard
```

#### Niri Window Manager Config (`config.kdl`)
```kdl
binds {
    Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "region"; }
    Meta+Print { spawn "dms" "ipc" "call" "quickCapture" "screenshot" "window"; }
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
- `Ctrl + F`: Float image (requires [dms-floaty](https://github.com/hthienloc/dms-floaty)).
- `Ctrl + X`: Interactive canvas crop.

### Interactive Modifiers
- **Mouse Scroll Wheel:** Increases/decreases brush stroke size or font size dynamically.
- **Middle-Click on Vector:** Delete clicked vector object instantly.
- **Right-Click on Canvas:** Displays the 8-preset Radial Menu for swift tool/color selection.
- **Shift + Right-Click (Stamp active):** Changes counter format (Numbers, Alphabetical, Roman numerals).
- **Shift + Right-Click (Text active):** Standard text decoration toggle (Bold, Italic, Underline, Background).
- **Shift + Right-Click (Line active):** Changes line style (Solid, Dashed, Dotted).

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
    "export_format": "png",
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
