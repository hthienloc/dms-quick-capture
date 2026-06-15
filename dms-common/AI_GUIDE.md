# DMS Developer & AI Agent Guide: System Theme & Colors

To maintain a cohesive look and feel across the Dank Material Shell (DMS) desktop environment, all custom components and plugins **must** adhere strictly to the system's dynamic design tokens. This guide explains how to integrate the dynamic theme and avoid hardcoded colors/dimensions.

---

## 1. Importing the Theme Singleton
All theme values are provided by the `Theme` singleton, which must be imported from the `qs.Common` module:

```qml
import QtQuick
import qs.Common

Item {
    // Access properties like Theme.primary, Theme.surfaceContainer, etc.
}
```

---

## 2. Strict Theme Rules
- **No Hex Colors:** Never use hex strings (e.g., `#FF1744`, `#1A1A1A`) or browser color names (e.g., `"white"`, `"blue"`).
- **No Hardcoded Sizes:** Do not hardcode font sizes, padding/margins, corner radii, or icon sizes. Always map them to the corresponding `Theme` properties.
- **Support Light/Dark Mode:** Dynamic colors adjust automatically. Using hardcoded values will break layouts when switching modes.

---

## 3. Reference Tokens

### A. Semantic & Accent Colors
Use these to color key interactive elements, states, or categorized items:
- `Theme.primary`: Main accent color (respects user selection).
- `Theme.secondary`: Secondary accent color (subtle actions).
- `Theme.error`: For destructive actions, errors, or critical alerts (e.g., PDFs).
- `Theme.warning`: For warnings, pending actions, or archives (e.g., Zip files).
- `Theme.success`: For completed actions, checkmarks, or positive states.

### B. Surface & Text Colors
- `Theme.surface`: Default base surface.
- `Theme.surfaceContainer`: Standard container background (cards, panels).
- `Theme.surfaceContainerHigh`: Slightly lighter/elevated container.
- `Theme.surfaceText` (or `Theme.onSurface`): Color for primary text.
- `Theme.surfaceVariantText` (or `Theme.onSurfaceVariant`): Color for secondary/muted text or labels.
- `Theme.outline`: Standard boundary, border, or divider color.

### C. Spacing, Font Sizes, and Radii
- **Margins & Padding:** `Theme.spacingXS`, `Theme.spacingS`, `Theme.spacingM`, `Theme.spacingL`, `Theme.spacingXL`
- **Font Sizes:** `Theme.fontSizeSmall`, `Theme.fontSizeMedium`, `Theme.fontSizeLarge`, `Theme.fontSizeXLarge`
- **Corner Radii:** `Theme.cornerRadiusSmall`, `Theme.cornerRadius`, `Theme.cornerRadiusLarge`
- **Icon Sizes:** `Theme.iconSizeSmall` (16px), `Theme.iconSize` (24px), `Theme.iconSizeLarge` (32px)

---

## 4. Best Practices & Common Patterns

### A. Implementing Transparency & Alpha Blends
Never hardcode transparent hex values (like `#12ThemePrimary`). Use `Theme.withAlpha()` to create semi-transparent color variants dynamically:

```qml
Rectangle {
    anchors.fill: parent
    // Use 8% opacity of the system accent color for grouped backgrounds
    color: Theme.withAlpha(Theme.primary, 0.08)
    // Use 25% opacity for boundaries
    border.color: Theme.withAlpha(Theme.primary, 0.25)
    border.width: 1
    radius: Theme.cornerRadius
}
```

### B. Interactive/Hover States
Use `Theme.withAlpha` or `Qt.lighter` for hover backgrounds to ensure compatibility with light/dark modes:

```qml
Rectangle {
    id: button
    color: mouseArea.containsMouse 
        ? Theme.withAlpha(Theme.primary, 0.2) 
        : "transparent"
    radius: Theme.cornerRadiusSmall

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
    }
}
```

### C. Standard Card Container
Use a nested structure of surface container and outline colors:

```qml
Rectangle {
    color: Theme.surfaceContainer
    border.color: Theme.withAlpha(Theme.outline, 0.15)
    border.width: 1
    radius: Theme.cornerRadius
}

---

## 5. Development & Validation Workflow

To ensure high-quality code and minimize runtime errors, AI agents **must** follow this strict validation and debugging process before delivering changes.

### A. Proactive Syntax Validation
Before finalizing any QML file, always run `qmllint` to catch basic syntax errors like missing braces `}`, semicolons, or invalid property assignments.

```bash
# General usage
qmllint YourFile.qml

# If running on Fedora/DMS environment with Qt6
/usr/lib64/qt6/bin/qmllint YourFile.qml
```
*Note: Ignore warnings about missing module imports (like `qs.*`) if `qmllint` is running outside the DMS runtime environment, but **never** ignore "syntax" or "Expected token" errors.*

### B. IPC Integration Checklist
When adding IPC commands (`IpcHandler`), verify the following:
1. **Manifest Capability**: Ensure `"ipc"` is added to the `capabilities` array in `plugin.json`.
2. **Permissions**: If the plugin executes shell commands or uses specialized services, ensure corresponding permissions (e.g., `"process"`) are in `plugin.json`.
3. **Placement**: Place the `IpcHandler` block near the top of the root component for reliable parsing.
4. **Scoping**: Use qualified lookups (e.g., `root.property`) inside `IpcHandler` functions if `pragma ComponentBehavior: Bound` is enabled.

### C. Troubleshooting "Component Fails to Load"
If a plugin loads but its Settings or Popout fails to open:
1. **Check for missing components**: Ensure all custom components used (e.g., `SettingsDivider`) exist in the plugin's `dms-common` directory.
2. **Update qmldir**: Any new `.qml` file added to `dms-common` **must** be declared in its `qmldir` file.
3. **Inspect Runtime Logs**: Use `journalctl -u dms --since "2 minutes ago"` to identify specific QML type resolution or runtime errors.

### D. Syncing to System
Always use the established sync script to test changes in the live environment:
```bash
./sync_to_runtime.sh
```

---

## 6. DMS 1.5+ Plugin Migration (Composite API)

In DMS 1.5.0, the plugin manifest schema has changed to natively support multiple surfaces (e.g., running a background service while simultaneously offering a panel widget).

### A. The Change
- **Legacy Format:** Used `component` (string) and classified the plugin's role under `type` (e.g., `daemon`, `widget`, `launcher`, `desktop`).
- **New Format:** Uses `type: "composite"` and a `components` object mapping specific surfaces (`daemon`, `widget`, `launcher`, `desktop`) to their QML components.

> [!WARNING]
> If a plugin is marked as `"type": "daemon"` with legacy `"capabilities": ["dankbar-widget"]`, the shell's legacy classifier only indexes it as a daemon, making it **unsearchable** in the settings widget list. You must migrate it to the composite format.

### B. Migration Example

#### Before (Legacy `plugin.json`):
```json
{
  "id": "floaty",
  "name": "Floaty",
  "type": "daemon",
  "capabilities": [
    "dankbar-widget",
    "ipc"
  ],
  "component": "./FloatyPlugin.qml",
  "settings": "./FloatySettings.qml"
}
```

#### After (DMS 1.5+ `plugin.json`):
```json
{
  "id": "floaty",
  "name": "Floaty",
  "type": "composite",
  "capabilities": [
    "daemon",
    "dankbar-widget",
    "ipc"
  ],
  "components": {
    "daemon": "./FloatyDaemon.qml",
    "widget": "./FloatyWidget.qml"
  },
  "settings": "./FloatySettings.qml",
  "requires_dms": ">=1.5.0"
}
```

---

## 7. Standardized Plugin Documentation
Every new plugin should include a standardized README file to clearly document its installation, controls, capabilities, and IPC commands. Refer to [README_TEMPLATE.md](file:///home/loccun/Documents/GitHub/dms-common/README_TEMPLATE.md) for the official template layout.

---

## 8. Native DMS Services vs External Dependencies
To ensure portability and consistent user notifications, dynamic styling, and configuration:
- **Prioritize Native APIs:** Always prioritize DMS's built-in clipboard and screenshot mechanisms before falling back to external command-line tools.
- **Clipboard:** DMS provides native clipboard handling for text and image formats. Avoid spawning processes like `wl-paste`, `wl-copy`, `xclip`, or `xsel` directly unless handling unsupported mime-types.
- **Screenshots:** Use the native shell screenshot triggers (e.g. `dms screenshot region` or `dms screenshot full`) instead of raw system tools like `grim` or `slurp`. This allows the shell to manage overlays, focus grabbing, and screenshot notifications natively.


