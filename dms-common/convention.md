# DMS Plugin Development Conventions

This document outlines the standard patterns and structural requirements for Dank Material Shell plugins to ensure consistency across the ecosystem.

## 1. Directory Structure
- Plugin folders must be **camelCase** (e.g., `ambientSound`, `qrGenerator`).
- Repository names should be **kebab-case** with a `dms-` prefix (e.g., `dms-ambient-sound`).
- Local `components` directories are **deprecated**. Use `import "../dms-common"` for shared UI components.

## 2. Settings Layout (`PluginSettings.qml`)
To maintain a consistent user experience, the settings page should follow this order:

1.  **PluginHeader**: Title of the settings page.
2.  **Usage Guide**: A `SettingsCard` containing the `UsageGuide` component. This must be the **first** section after the header so users know how to use the plugin immediately.
3.  **General Settings**: Main functional toggles and configurations.
4.  **Appearance/Display**: UI-related settings (e.g., icon only mode, date formats).
5.  **Feedback/Notifications**: Sound, haptics, and toast settings.
6.  **Advanced**: Rarely used or complex configurations.

### Example:
```qml
PluginSettings {
    id: root
    pluginId: "myPlugin"

    PluginHeader { title: "My Plugin Settings" }

    // ALWAYS AT THE TOP
    SettingsCard {
        SectionTitle { text: "Usage Guide" }
        UsageGuide {
            items: [
                "Feature 1: How to use it.",
                "Shortcuts: Keyboard bindings."
            ]
        }
    }

    SettingsCard {
        SectionTitle { text: "General" }
        // ... settings ...
    }
}
```

## 3. Component Usage
- Use **`UsageGuide`** from `dms-common` instead of hardcoded bullet points in `InfoText`.
- Avoid `import qs.Services` unless explicitly required and tested.
- Standard imports:
  ```qml
  import QtQuick
  import QtQuick.Controls
  import qs.Common
  import qs.Widgets
  import qs.Modules.Plugins
  import "../dms-common"
  ```

## 4. Documentation
- `README.md` must include an **Installation** section with instructions to clone `dms-common`.
- `README.md` should briefly explain the plugin's purpose and key features.
