#!/usr/bin/env python3
"""
i18n.py — Translation tooling for dms-quick-capture (DMS 1.6+ sideload translations).

Usage:
  python3 scripts/i18n.py extract          # Extract strings from QML files into translations/<lang>.json
  python3 scripts/i18n.py status           # Show translation coverage per language
  python3 scripts/i18n.py status --readme  # Update translation status table in README.md

Format is 2-level context bucket JSON required by DMS 1.6+:
{
  "English term": {
    "English term": "Translated term"
  }
}
"""

import re
import sys
import json
import argparse
from pathlib import Path


# ── Paths ──────────────────────────────────────────────────────────────────────
REPO_ROOT        = Path(__file__).parent.parent
TRANSLATIONS_DIR = REPO_ROOT / "translations"
POEXPORTS_DIR    = TRANSLATIONS_DIR / "poexports"

# ── Target languages ───────────────────────────────────────────────────────────
LANGUAGES = {
    "vi":    {"name": "Vietnamese",            "file": "vi.json"},
    "ja":    {"name": "Japanese",              "file": "ja.json"},
    "zh-CN": {"name": "Chinese (Simplified)",  "file": "zh_CN.json"},
    "ko":    {"name": "Korean",                "file": "ko.json"},
    "fr":    {"name": "French",                "file": "fr.json"},
    "de":    {"name": "German",                "file": "de.json"},
    "es":    {"name": "Spanish",               "file": "es.json"},
    "ru":    {"name": "Russian",               "file": "ru.json"},
}

README_FILE = REPO_ROOT / "README.md"
TABLE_START = "<!-- TRANSLATIONS_TABLE_START -->"
TABLE_END   = "<!-- TRANSLATIONS_TABLE_END -->"

# ── Helpers ────────────────────────────────────────────────────────────────────
def info(msg):    print(f"\033[94m{msg}\033[0m")
def success(msg): print(f"\033[92m{msg}\033[0m")
def warn(msg):    print(f"\033[93mWarning: {msg}\033[0m", file=sys.stderr)
def error(msg):   print(f"\033[91mError: {msg}\033[0m", file=sys.stderr); sys.exit(1)

# Matches both I18n.trFor("quickCapture", "...") and I18n.tr("...")
_TR_FOR_RE = re.compile(r'I18n\.trFor\(\s*["\']quickCapture["\']\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)')
_TR_RE     = re.compile(r'I18n\.tr\(\s*"((?:[^"\\]|\\.)*)"\s*\)')

def _clean_str(s: str) -> str:
    return s.replace(r'\"', '"').replace(r'\\', '\\').replace(r'\n', '\n')

def extract_strings() -> list[str]:
    """Scan all plugin QML files (excluding dms-common) and return sorted unique source strings."""
    strings: set[str] = set()
    for qml_file in sorted(REPO_ROOT.rglob("*.qml")):
        if "dms-common" in qml_file.parts or ".git" in qml_file.parts:
            continue
        text = qml_file.read_text(encoding="utf-8", errors="replace")
        for m in _TR_FOR_RE.finditer(text):
            raw = _clean_str(m.group(1))
            if raw.strip():
                strings.add(raw)
        for m in _TR_RE.finditer(text):
            raw = _clean_str(m.group(1))
            if raw.strip():
                strings.add(raw)
    return sorted(strings)

def _read_translations(path: Path) -> dict[str, str]:
    """Read a translations JSON file into a flat dict {term: translation} regardless of 1-level or 2-level structure."""
    if not path.exists():
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        result: dict[str, str] = {}
        for k, v in data.items():
            if isinstance(v, dict):
                val = v.get(k, "")
                result[k] = val if isinstance(val, str) else ""
            elif isinstance(v, str):
                result[k] = v
        return result
    except Exception as e:
        warn(f"Failed to read {path}: {e}")
        return {}

def _write_translations(path: Path, flat_map: dict[str, str]):
    """Write translations to file in DMS 1.6 2-level context bucket JSON format."""
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {}
    for k in sorted(flat_map.keys()):
        val = flat_map[k]
        payload[k] = {k: val}
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")

def cmd_extract(_args):
    strings = extract_strings()
    if not strings:
        warn("No translatable strings found.")
        return

    TRANSLATIONS_DIR.mkdir(parents=True, exist_ok=True)

    for code, info_dict in LANGUAGES.items():
        filename = info_dict["file"]
        out_path = TRANSLATIONS_DIR / filename
        old_po_path = POEXPORTS_DIR / filename

        existing = _read_translations(old_po_path)
        existing.update(_read_translations(out_path))

        merged: dict[str, str] = {}
        for s in strings:
            merged[s] = existing.get(s, "")

        _write_translations(out_path, merged)
        translated_count = sum(1 for v in merged.values() if v.strip())
        info(f"[{code}] {filename}: {len(strings)} terms ({translated_count} translated)")

    success(f"Extracted {len(strings)} unique strings into {TRANSLATIONS_DIR}")

def _generate_markdown_table(stats: list[dict], total: int) -> str:
    lines = [
        "| Language | Locale | Progress | Coverage | Status |",
        "| :--- | :--- | :---: | :---: | :---: |",
    ]
    for s in stats:
        pct_str = f"{s['pct']:.1f}%"
        if s["pct"] >= 100.0:
            badge = "🟢 Complete"
        elif s["pct"] > 0.0:
            badge = "🟡 In Progress"
        else:
            badge = "⚪ Not Started"
        lines.append(f"| {s['name']} | `{s['code']}` | {s['done']}/{total} | {pct_str} | {badge} |")
    return "\n".join(lines)

def cmd_status(args):
    strings = extract_strings()
    total = len(strings)
    if total == 0:
        warn("No strings found in QML files.")
        return

    stats = []
    print(f"\n{'Language':<22} {'Locale':<8} {'File':<15} {'Done':>6} {'Missing':>8} {'Coverage':>10}")
    print("-" * 75)

    for code, info_dict in LANGUAGES.items():
        name = info_dict["name"]
        filename = info_dict["file"]
        path = TRANSLATIONS_DIR / filename
        existing = _read_translations(path)
        done = sum(1 for s in strings if existing.get(s, "").strip())
        missing = total - done
        pct = (done / total * 100) if total else 0
        status_icon = "✓" if missing == 0 else ("~" if done > 0 else "✗")
        stats.append({
            "name": name,
            "code": code,
            "filename": filename,
            "done": done,
            "missing": missing,
            "pct": pct,
        })
        print(f"{name:<22} {code:<8} {filename:<15} {done:>6} {missing:>8}   {pct:>7.1f}%  {status_icon}")
    print()

    if getattr(args, "readme", False):
        if not README_FILE.exists():
            error(f"{README_FILE} not found.")
        content = README_FILE.read_text(encoding="utf-8")
        if TABLE_START not in content or TABLE_END not in content:
            error(f"Missing {TABLE_START} and {TABLE_END} markers in {README_FILE}")
        table_md = _generate_markdown_table(stats, total)
        pattern = re.compile(f"{re.escape(TABLE_START)}.*?{re.escape(TABLE_END)}", re.DOTALL)
        new_content = pattern.sub(f"{TABLE_START}\n{table_md}\n{TABLE_END}", content)
        README_FILE.write_text(new_content, encoding="utf-8")
        success(f"Updated translation status table in {README_FILE.relative_to(REPO_ROOT)}")

def cmd_add_lang(args):
    code = args.code.strip()
    name = args.name.strip() if args.name else code
    filename = f"{code.replace('-', '_')}.json"
    out_path = TRANSLATIONS_DIR / filename
    if out_path.exists():
        warn(f"{filename} already exists.")
        return
    strings = extract_strings()
    payload = {s: {s: ""} for s in strings}
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    success(f"Created {filename} for '{name}' with {len(strings)} terms ready to translate.")

def main():
    parser = argparse.ArgumentParser(
        description="i18n tooling for dms-quick-capture (DMS 1.6+)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("extract", help="Extract strings from QML files into translations/*.json")

    p_status = sub.add_parser("status", help="Show translation coverage per language")
    p_status.add_argument("--readme", action="store_true", help="Update translation status table in README.md")

    p_add = sub.add_parser("add-lang", help="Scaffold a new translation file for a language")
    p_add.add_argument("code", help="Language code / locale (e.g. it, pt_BR, pl)")
    p_add.add_argument("--name", help="Human-readable language name (e.g. Italian, Polish)")

    args = parser.parse_args()
    {"extract": cmd_extract, "status": cmd_status, "add-lang": cmd_add_lang}[args.command](args)

if __name__ == "__main__":
    main()
