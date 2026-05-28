# DMS Quick Capture & Annotate

Interactive Wayland-centric screen capture and instant vector annotation plugin for DankMaterialShell (DMS).

<img src="screenshot.png" width="800" alt="Screenshot">

## Install

**Required:** This plugin requires [dms-common](https://github.com/hthienloc/dms-common) to be installed.

```bash
# 1. Install shared components
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common

# 2. Install this plugin
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

## Features

- Screenshot capture with IPC and Control Center integration.
- Annotation tools for pen, highlighter, lines, arrows, shapes, text, stamps, redaction, and pixelation.
- Crop-aware editing with copy, save, and copy-and-save export actions.
- Keyboard shortcuts for fast capture cleanup and annotation.

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
    QuickCaptureConfig.js      # Tool, color, and shortcut config
```

## TODO / Roadmap

- [x] Vector straight-line drawing when holding `Shift` (for Pen and Highlighter).
- [x] Mouse wheel scrolling over canvas to dynamically scale stroke thickness and text font sizes.
- [x] Dynamic high-contrast canvas boundary and auto-adapting backdrop luminance for dark captures.
- [x] Disjoint Copy vs Save toolbar pipelines separating clipboard and filesystem actions.
- [ ] Fix and fully enable the **Click-to-Type Text** annotation tool to reliably capture active keyboard input and support native inline text overlay typing.

## License

MIT
