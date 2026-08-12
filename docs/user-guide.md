# User Guide

## Quick Start

| Action | Result |
| --- | --- |
| **Left Click** | Open the widget popout |
| **Middle Click** | Region capture |
| **Right Click** | Paste from clipboard |
| **Drop Image** | Drag an image onto the icon to annotate |
| **<kbd>Print</kbd>** | Capture using the default mode |

1. Trigger a capture from the bar icon, Control Center, or <kbd>Print</kbd>.
2. Drag to select an area.
3. Annotate with the toolbar, shortcuts, or radial menus.
4. Press <kbd>Enter</kbd> to finish or <kbd>Esc</kbd> to discard.

### Scrolling Capture

Select a region, press <kbd>Space</kbd> or <kbd>Enter</kbd> to confirm, scroll the content, then press <kbd>Enter</kbd> to finish stitching. Adjust the scroll interval in settings.

## Annotation Tools

### Tool Selection

| Shortcut | Tool |
| --- | --- |
| <kbd>1</kbd> | Pen |
| <kbd>2</kbd> | Line |
| <kbd>3</kbd> | Arrow |
| <kbd>4</kbd> | Rectangle |
| <kbd>Q</kbd> | Ellipse |
| <kbd>W</kbd> | Text |
| <kbd>E</kbd> | Pixelate |
| <kbd>R</kbd> | Redact |
| <kbd>A</kbd> | Stamp |
| <kbd>S</kbd> | Highlighter |
| <kbd>D</kbd> | Focus Spotlight |
| <kbd>F</kbd> | Color Picker |
| <kbd>T</kbd> | Eraser |
| <kbd>Z</kbd> | Area Zoom (Callout) |
| <kbd>B</kbd> | Background Options |
| <kbd>O</kbd> | OCR Text Recognition |
| <kbd>G</kbd> (hold) | Magnifier Lens |
| <kbd>V</kbd> | Select |
| <kbd>X</kbd> | Toggle annotations |
| <kbd>Tab</kbd> | Toggle Select and the last active tool |

### Drawing and Editing

- Scroll the mouse wheel to adjust brush or font size.
- Middle-click an element to delete it.
- Select a vector with <kbd>V</kbd>, then press <kbd>C</kbd> to duplicate it.
- Press <kbd>C</kbd> without a selection to paste the last copied vector.
- Use <kbd>Ctrl</kbd> + <kbd>Z</kbd> and <kbd>Ctrl</kbd> + <kbd>Y</kbd> for undo and redo.
- Drag with Text to create a speech bubble; a single click creates normal text.
- Drag with Stamp to create a leader line; a single click creates a normal stamp.

Hold <kbd>Shift</kbd> while drawing to constrain shapes: Pen draws straight lines; Line, Arrow, and Highlighter snap to 15-degree increments; Ellipse makes a circle; Rectangle, Redact, and Pixelate make a square.

### Popover Toolbars and Radial Menus

| Interaction | Result |
| --- | --- |
| Right-click on canvas | Open eight customizable tool presets |
| <kbd>Shift</kbd> + right-click with Stamp active | Stamp options |
| <kbd>Shift</kbd> + right-click with Text active | Text options |
| <kbd>Shift</kbd> + right-click with Line active | Line options |

### Special Tools

- Hold <kbd>G</kbd> for the magnifier lens and scroll to adjust zoom from 1.5x to 4x.
- Press <kbd>Z</kbd> to draw a callout and scroll to adjust zoom from 100% to 500%.

## Keyboard Shortcuts

| Key | Action |
| --- | --- |
| <kbd>Enter</kbd> | Done; save or copy according to settings |
| <kbd>Esc</kbd> | Discard and close |
| <kbd>Ctrl</kbd> + <kbd>Z</kbd> | Undo |
| <kbd>Ctrl</kbd> + <kbd>Y</kbd> / <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>Z</kbd> | Redo |
| <kbd>Ctrl</kbd> + <kbd>S</kbd> | Save to file |
| <kbd>Ctrl</kbd> + <kbd>C</kbd> | Copy to clipboard |
| <kbd>Ctrl</kbd> + <kbd>Shift</kbd> + <kbd>C</kbd> | Anonymous copy |
| <kbd>Ctrl</kbd> + <kbd>A</kbd> | Copy and save |
| <kbd>Ctrl</kbd> + <kbd>F</kbd> | Float image |
| <kbd>Ctrl</kbd> + <kbd>X</kbd> | Crop or resize |
| <kbd>Ctrl</kbd> + <kbd>1</kbd> to <kbd>4</kbd> | Select color slots 1 to 4 |
| <kbd>Ctrl</kbd> + <kbd>Q</kbd> to <kbd>R</kbd> | Select color slots 5 to 8 |

## Pin to Desktop

- Press <kbd>Ctrl</kbd> + <kbd>F</kbd> to export and float the image.
- Left-click the floating image to continue editing.
- Right-click it to minimize it; hover the icon to restore it.
- Middle-click the floating image to close it.

## IPC Commands

Commands that capture or open images accept `edit` or `float` as the action:

```bash
dms ipc call quickCapture <command> [arg] edit|float
dms ipc call quickCapture screenshot region edit
dms ipc call quickCapture screenshot region float
```

| Command | Arguments | Description |
| --- | --- | --- |
| `screenshot` | `region`, `full`, `all`, `output`, `window`, `last`, or `scroll`; action | Trigger capture |
| `selectFile` | action | Open the file browser |
| `fromClipboard` | action | Annotate an image from the clipboard |
| `openImage` | path, action | Open an image in the annotator |
| `close` | none | Close the annotator |
| `showHistory` | none | Open recent edits |

See the [IPC and Settings Reference](ipc-and-settings.md) for the complete command and configuration reference.

![Keybinding example](../setup_example.png)
