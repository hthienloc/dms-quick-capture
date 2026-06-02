# DMS Common Components

Shared UI components for **Dank Material Shell (DMS)** plugins. This library provides a unified design system to ensure a consistent, premium user experience across all DMS plugins.

## Installation

To use these components, this repository must be cloned into your DMS plugins directory:

```bash
git clone https://github.com/hthienloc/dms-common ~/.config/DankMaterialShell/plugins/dms-common
```

## Usage for Developers

### 1. Importing components
In your plugin's QML files (e.g., `PluginWidget.qml` or `PluginSettings.qml`), import the common directory:

```qml
import "../dms-common"
```

*Note: Since dms-common is usually a sibling directory to your plugin, `../dms-common` is the standard relative path.*

### 2. Basic Example
```qml
import QtQuick
import qs.Modules.Plugins
import "../dms-common"

PluginSettings {
    id: root
    
    PluginHeader {
        title: "My Awesome Plugin"
    }

    SettingsCard {
        SectionTitle { text: "Instructions" }
        
        UsageGuide {
            items: [
                "<b>Left-click</b> to trigger the primary action.",
                "<b>Right-click</b> to open settings or reset."
            ]
        }
    }
}
```

## Component Reference

| Component | Description |
|-----------|-------------|
| **PluginHeader** | Standard header with title and consistent styling. |
| **SettingsCard** | A container for grouping related settings with a subtle background and padding. |
| **SectionTitle** | Styled text for labeling sections within a card. |
| **UsageGuide** | Automatically formatted list of instructions with bullet points. |
| **ActionTile** | Interactive tile for executing commands or opening links. |
| **InfoTile** | Display tile for showing data (e.g., system stats, weather). |
| **CopyBox** | A text field accompanied by a "Copy" button for easy clipboard access. |
| **StatusDisplay** | A complex component for showing multiple status fields with icons and labels. |
| **OutlineButton** | A modern, transparent button with an outline, perfect for secondary actions. |
| **TagChip** | Small, rounded badges for categories or status indicators. |
| **HintSection** | A standardized way to show tips at the bottom of a popout. |
| **MediaHeader** | Specialized header for plugins that handle media (e.g., sound, music). |

## Contributing
If you create a reusable UI pattern that could benefit other plugins, feel free to submit a pull request to add it to `dms-common`.

## License
GPL-3.0

## Roadmap / TODO

- [ ] **Animation Wrappers**: Standardized QML components for consistent transitions (Fade, Slide, Scale).
- [ ] **IPC Utility Suite**: More robust and type-safe wrappers for common `DMSService` calls.
- [ ] **Adaptive Layouts**: Helpers for building responsive UI that works across different bar positions and widths.
- [ ] **State Persistence Helpers**: Standardized methods for caching and syncing UI state between widget instances.
- [ ] **Expanded Component Kit**: Richer widgets like TabBars, ProgressBars, and unified ScrollView wrappers.
