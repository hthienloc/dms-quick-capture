# DMS Quick Capture & Annotate

Interactive Wayland-centric screen capture and instant vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="400" alt="Screenshot">

## Install

**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

## Features

- **Hybrid Daemon-Widget Lifecycles:** Seamlessly auto-starts on boot to listen for system screenshot hotkeys.
- **Native Selection Capture:** Integrates cleanly with DMS interactive screenshot pipelines.
- **Centered Aspect-Fit Annotator:** Center-aligned modal occupying 90% width/height of the viewport with aspect-ratio locked scaling.
- **Vector Painting Board:** Multi-tool annotation workspace (Pen, Highlighter, Rectangle, Arrow, Erase, Contrast Stamp).
- **Clipboard & File Save Pipelines:** One-click copy to clipboard via `wl-clipboard` and backup file writer.
- **Hotkey Support:** Active keyboard binds (`Escape` to discard, `Ctrl+Z` to undo, `Ctrl+C`/`Enter` to copy, `Ctrl+S` to save).

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
- `dms-common`

## TODO / Roadmap

- [ ] Fix and fully enable the **Click-to-Type Text** annotation tool to reliably capture active keyboard input and support native inline text overlay typing.

## License

MIT
