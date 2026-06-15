# [Plugin Name]

[A brief, clear one-sentence description of what the plugin does.]

<img src="screenshot.png" width="400" alt="Plugin Screenshot">

## Requirements
* **System packages**: `[package-name]` (e.g. `poppler-utils` for pdf rendering)
* **DMS version**: `[version]`

## Installation

### Via DMS CLI
```bash
dms plugins install [plugin-id]
```

### Manual Installation
```bash
git clone https://github.com/[username]/dms-[plugin-id] ~/.config/DankMaterialShell/plugins/[plugin-id]
```

## Plugin Specifications
* **Type:** `composite` | `daemon` | `widget` | `launcher` | `desktop`
* **Requires DMS:** `>=1.5.0`
* **Capabilities:** `["daemon", "dankbar-widget", "ipc", "desktop-widget", "launcher-action"]`

## Features
* **Feature 1** - [Short explanation of what it does]
* **Feature 2** - [Short explanation of what it does]
* **Feature 3** - [Short explanation of what it does]

## Usage

### Controls / Mouse Actions
[If the plugin has interactive components like a status bar pill or desktop widget]

| Component | Action | Result |
|-----------|--------|--------|
| Bar Pill / Widget | Left Click | [Action description] |
| Bar Pill / Widget | Middle Click | [Action description] |
| Bar Pill / Widget | Right Click | [Action description] |
| Bar Pill / Widget | Drag & Drop | [Action description] |

### Hotkeys / Gestures
* **[Shortcut]**: [Description]

## IPC Commands
[If `"ipc"` is listed in capabilities. Delete if not applicable.]

Use `dms ipc call [plugin-id] <command>` to control the plugin via terminal, scripts, or window manager keybindings.

| Command | Arguments | Description |
|---------|-----------|-------------|
| `commandName` | `arg1` (type), `arg2` (type) | [Description of what the command does] |

### Keybinding Examples

**Hyprland (`hyprland.conf`):**
```ini
bind = SUPER, [Key], exec, dms ipc call [plugin-id] [commandName]
```

**Niri (`config.kdl`):**
```kdl
bindings {
    Mod+[Key] { spawn "dms" "ipc" "call" "[plugin-id]" "[commandName]"; }
}
```

## Configuration & Settings
Describe any settings customizable via the DMS settings panel or directly in `settings` block of `plugin.json`.

* **Property Name** (`type`): [Default Value] - [Description]

## Development

1. Sync local changes to the live DMS environment:
   ```bash
   ./sync_to_runtime.sh
   ```
2. Verify QML files before committing:
   ```bash
   qmllint [Filename].qml
   ```

## Roadmap / TODO

- [ ] Future feature placeholder

## License
[License Type, e.g., GPL-3.0 / MIT]

