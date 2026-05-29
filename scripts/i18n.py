#!/usr/bin/env python3
"""
i18n.py — Translation automation for dms-stopwatch.

Usage:
  python3 scripts/i18n.py extract          # Extract I18n.tr() strings → translations/en.json
  python3 scripts/i18n.py translate        # Auto-translate missing strings via Google Translate
  python3 scripts/i18n.py translate --lang vi,ja   # Translate specific languages only
  python3 scripts/i18n.py status           # Show translation coverage per language

Translation files are written to translations/poexports/<lang>.json.
Format is flat key_value_json: { "English string": "Translated string" }
compatible with DMS I18n.qml.

Strings already translated (non-empty) are preserved; only missing/new
strings are auto-translated, so manual corrections are safe.
"""

import re
import sys
import json
import time
import argparse
import urllib.request
import urllib.parse
from pathlib import Path

# ── Paths ──────────────────────────────────────────────────────────────────────
REPO_ROOT    = Path(__file__).parent.parent
QML_DIRS     = [REPO_ROOT]          # Directories to scan for *.qml files
EN_JSON      = REPO_ROOT / "translations" / "en.json"
POEXPORTS    = REPO_ROOT / "translations" / "poexports"

# ── Target languages ───────────────────────────────────────────────────────────
# key = BCP-47 code used by Google Translate
# value = output filename under translations/poexports/
LANGUAGES = {
    "vi":    "vi.json",
    "ja":    "ja.json",
    "zh-CN": "zh_CN.json",
    "ko":    "ko.json",
    "fr":    "fr.json",
    "de":    "de.json",
    "es":    "es.json",
    "ru":    "ru.json",
}

# ── Helpers ────────────────────────────────────────────────────────────────────
def info(msg):    print(f"\033[94m{msg}\033[0m")
def success(msg): print(f"\033[92m{msg}\033[0m")
def warn(msg):    print(f"\033[93mWarning: {msg}\033[0m", file=sys.stderr)
def error(msg):   print(f"\033[91mError: {msg}\033[0m", file=sys.stderr); sys.exit(1)

# ── Extract ────────────────────────────────────────────────────────────────────
# Matches I18n.tr("...") including strings that span via escaped quotes.
_TR_RE = re.compile(r'I18n\.tr\(\s*"((?:[^"\\]|\\.)*)"\s*\)')

def extract_strings() -> list[str]:
    """Scan all QML files and return sorted unique I18n.tr() source strings."""
    strings: set[str] = set()
    for qml_dir in QML_DIRS:
        for qml_file in sorted(qml_dir.rglob("*.qml")):
            text = qml_file.read_text(encoding="utf-8", errors="replace")
            for m in _TR_RE.finditer(text):
                # Unescape basic escape sequences
                raw = m.group(1).replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")
                if raw.strip():
                    strings.add(raw)
    return sorted(strings)

def cmd_extract(_args):
    strings = extract_strings()
    if not strings:
        warn("No I18n.tr() strings found — check QML_DIRS in the script.")
        return

    EN_JSON.parent.mkdir(parents=True, exist_ok=True)
    # Flat key_value_json: { "source": "source" } — source == translation for English
    data = {s: s for s in strings}
    _write_json(EN_JSON, data)
    success(f"Extracted {len(strings)} strings → {EN_JSON.relative_to(REPO_ROOT)}")

# ── Google Translate (free, unofficial) ────────────────────────────────────────
_GT_URL = "https://translate.googleapis.com/translate_a/single"

def _google_translate(text: str, target_lang: str) -> str | None:
    """Translate a single string using the free Google Translate endpoint.
    Returns None on failure."""
    params = urllib.parse.urlencode({
        "client": "gtx",
        "sl":     "en",
        "tl":     target_lang,
        "dt":     "t",
        "q":      text,
    })
    url = f"{_GT_URL}?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            # Response structure: [ [ ["translated", "original", ...], ... ], ... ]
            parts = [seg[0] for seg in data[0] if seg[0]]
            return "".join(parts)
    except Exception as e:
        warn(f"Google Translate failed for '{text[:40]}': {e}")
        return None

def _write_json(path: Path, data: dict):
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")

def _read_json(path: Path) -> dict:
    if not path.exists():
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)

def cmd_translate(args):
    if not EN_JSON.exists():
        info("en.json not found — running extract first...")
        cmd_extract(args)

    source: dict = _read_json(EN_JSON)
    if not source:
        error("en.json is empty. Run 'extract' first.")

    # Filter languages if --lang given
    langs = LANGUAGES
    if args.lang:
        requested = {l.strip() for l in args.lang.split(",")}
        langs = {k: v for k, v in LANGUAGES.items() if k in requested or v.replace(".json","") in requested}
        if not langs:
            error(f"None of the requested languages found: {args.lang}\nAvailable: {', '.join(LANGUAGES)}")

    POEXPORTS.mkdir(parents=True, exist_ok=True)
    delay = 0.3  # seconds between requests to avoid rate-limiting

    for gt_lang, filename in langs.items():
        out_path = POEXPORTS / filename
        existing: dict = _read_json(out_path)

        # Find strings missing or empty in the existing translation
        missing = {k: v for k, v in source.items() if not existing.get(k)}

        if not missing:
            info(f"[{gt_lang}] {filename}: already complete ({len(existing)} strings)")
            continue

        info(f"[{gt_lang}] {filename}: translating {len(missing)}/{len(source)} missing strings...")

        translated = dict(existing)  # preserve existing manual translations
        failed = 0

        for i, (src_key, _) in enumerate(missing.items(), 1):
            result = _google_translate(src_key, gt_lang)
            if result:
                translated[src_key] = result
            else:
                translated[src_key] = ""  # leave blank so user can fill in
                failed += 1

            # Progress indicator every 10 strings
            if i % 10 == 0 or i == len(missing):
                print(f"  {i}/{len(missing)}", end="\r", flush=True)

            time.sleep(delay)

        print()  # newline after progress

        # Also carry over any source strings not yet in translated (new additions)
        for k in source:
            if k not in translated:
                translated[k] = ""

        _write_json(out_path, translated)

        ok = len(missing) - failed
        if failed:
            warn(f"[{gt_lang}] {ok} translated, {failed} failed (left blank) → {filename}")
        else:
            success(f"[{gt_lang}] {ok} strings translated → {filename}")

# ── Status ─────────────────────────────────────────────────────────────────────
def cmd_status(_args):
    if not EN_JSON.exists():
        error("en.json not found. Run 'extract' first.")

    source = _read_json(EN_JSON)
    total = len(source)
    if total == 0:
        warn("en.json is empty.")
        return

    print(f"\n{'Language':<12} {'File':<20} {'Done':>6} {'Missing':>8} {'Coverage':>10}")
    print("-" * 62)
    for gt_lang, filename in LANGUAGES.items():
        path = POEXPORTS / filename
        existing = _read_json(path)
        done    = sum(1 for k in source if existing.get(k))
        missing = total - done
        pct     = done / total * 100
        status  = "✓" if missing == 0 else ("~" if done > 0 else "✗")
        print(f"{gt_lang:<12} {filename:<20} {done:>6} {missing:>8}   {pct:>7.1f}%  {status}")
    print()

# ── CLI ────────────────────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        description="i18n automation for dms-stopwatch",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("extract", help="Extract I18n.tr() strings from QML files")

    p_trans = sub.add_parser("translate", help="Auto-translate missing strings via Google Translate")
    p_trans.add_argument("--lang", metavar="LANG[,LANG]", default="",
                         help="Comma-separated language codes to translate (default: all)")

    sub.add_parser("status", help="Show translation coverage per language")

    args = parser.parse_args()

    {"extract": cmd_extract, "translate": cmd_translate, "status": cmd_status}[args.command](args)

if __name__ == "__main__":
    main()
