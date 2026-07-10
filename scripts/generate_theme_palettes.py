#!/usr/bin/env python3
"""
Generate CaptureConfig.qml palette entries from dms-plugin-registry theme JSONs.
Usage:
    python3 scripts/generate_theme_palettes.py
Output: QML code blocks ready to insert into CaptureConfig.qml
"""

import json
import os
import sys

THEMES_DIR = os.path.join(os.path.dirname(__file__), "../../dms-plugin-registry/themes")
COLOR_KEYS = ["primary", "error", "warning", "info", "secondary", "primaryContainer", "surfaceText", "surface"]

# Catppuccin flavors: mocha & macchiato & frappe are dark, latte is light
CATPPUCCIN_DARK_FLAVORS = {"mocha", "macchiato", "frappe"}


def to_prop_name(theme_id: str, suffix: str = "") -> str:
    """Convert theme id to a QML property name like tokyoNightColors."""
    return theme_id + suffix + "Colors"


def extract_palette(colors: dict) -> list[str]:
    """Extract 8 colors in order of COLOR_KEYS, fallback to #ffffff."""
    return [colors.get(k, "#ffffff") for k in COLOR_KEYS]


def render_qml_property(prop_name: str, palette: list[str], comment_keys: bool = True) -> str:
    lines = [f"    readonly property var {prop_name}: ["]
    for i, (key, color) in enumerate(zip(COLOR_KEYS, palette)):
        comma = "," if i < 7 else ""
        comment = f"  // {key}" if comment_keys else ""
        lines.append(f'        "{color}"{comma}{comment}')
    lines.append("    ]")
    return "\n".join(lines)


def main():
    if not os.path.isdir(THEMES_DIR):
        print(f"ERROR: themes dir not found: {THEMES_DIR}", file=sys.stderr)
        sys.exit(1)

    simple_themes = []
    catppuccin_data = None

    for theme_dir in sorted(os.listdir(THEMES_DIR)):
        theme_json_path = os.path.join(THEMES_DIR, theme_dir, "theme.json")
        if not os.path.isfile(theme_json_path):
            continue

        with open(theme_json_path) as f:
            data = json.load(f)

        theme_id = data["id"]
        theme_name = data.get("name", theme_id)

        if theme_id == "catppuccin":
            catppuccin_data = data
            continue

        dark_colors = data.get("dark", {})
        light_colors = data.get("light", {})

        palette_dark = extract_palette(dark_colors)
        palette_light = extract_palette(light_colors)

        has_dark = bool(dark_colors)
        has_light = bool(light_colors)

        if has_dark and has_light:
            prop_dark = to_prop_name(theme_id, "Dark")
            prop_light = to_prop_name(theme_id, "Light")
        elif has_dark:
            prop_dark = to_prop_name(theme_id)
            prop_light = None
        else:
            prop_dark = None
            prop_light = to_prop_name(theme_id)

        simple_themes.append({
            "id": theme_id,
            "name": theme_name,
            "prop_dark": prop_dark,
            "prop_light": prop_light,
            "palette_dark": palette_dark,
            "palette_light": palette_light,
            "has_dark": has_dark,
            "has_light": has_light,
        })

    # ── Output ────────────────────────────────────────────────────────────────

    print("// ═══════════════════════════════════════════════════════════════════")
    print("// AUTO-GENERATED from dms-plugin-registry — DO NOT EDIT MANUALLY")
    print("// Run: python3 scripts/generate_theme_palettes.py")
    print("// Color order: primary, error, warning, info, secondary, primaryContainer, surfaceText, surface")
    print("// ═══════════════════════════════════════════════════════════════════")
    print()

    for t in simple_themes:
        print(f"    // ── {t['name']} ──")
        if t["prop_dark"]:
            print(render_qml_property(t["prop_dark"], t["palette_dark"]))
        if t["prop_light"]:
            print(render_qml_property(t["prop_light"], t["palette_light"]))
        print()

    # Catppuccin multi-flavor — each flavor outputs one array (no separate dark/light)
    if catppuccin_data:
        variants_info = catppuccin_data.get("variants", {})
        flavors = variants_info.get("flavors", [])
        accents = variants_info.get("accents", [])
        defaults = variants_info.get("defaults", {})

        print("    // ── Catppuccin (multi-flavor) ──")

        for flavor in flavors:
            fid = flavor["id"]
            is_dark = fid in CATPPUCCIN_DARK_FLAVORS
            variant_key = "dark" if is_dark else "light"
            colors = flavor.get(variant_key, {})

            if not colors:
                continue

            default_key = variant_key
            default_accent = defaults.get(default_key, {}).get("accent", "mauve") if isinstance(defaults.get(default_key), dict) else "mauve"
            fallback = "#cba6f7" if is_dark else "#8839ef"

            accent_color = fallback
            if accents:
                for acc in accents:
                    if acc.get("id") == default_accent:
                        accent_color = acc.get(variant_key, {}).get(fid, fallback)
                        break

            full_colors = dict(colors)
            full_colors.setdefault("primary", accent_color)
            full_colors.setdefault("secondary", accent_color)
            palette = extract_palette(full_colors)
            prop = f"catppuccin{fid.capitalize()}Colors"
            print(render_qml_property(prop, palette))

        print()

    # ── Switch case summary ───────────────────────────────────────────────────
    print()
    print("// ═══════════════ defaultAccentColors switch cases ═══════════════")
    for t in simple_themes:
        if t["has_dark"] and t["has_light"]:
            print(f'            case "{t["id"]}": return registryThemeVariant === "light" ? {t["prop_light"]} : {t["prop_dark"]};')
        elif t["has_dark"]:
            print(f'            case "{t["id"]}": return {t["prop_dark"]};')
        else:
            print(f'            case "{t["id"]}": return {t["prop_light"]};')

    if catppuccin_data:
        flavors = catppuccin_data.get("variants", {}).get("flavors", [])
        print('            case "catppuccin": {')
        print('                switch (selectedCatppuccinFlavor) {')
        for f in flavors:
            fid = f["id"]
            cap = fid.capitalize()
            print(f'                    case "{fid}": return catppuccin{cap}Colors;')
        print('                    default: return catppuccinMochaColors;')
        print('                }')
        print('            }')


if __name__ == "__main__":
    main()
