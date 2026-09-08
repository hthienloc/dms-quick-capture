# DMS Quick Capture & Annotate

<p align="center">
  <a href="https://github.com/AvengeMedia/dms-plugin-registry/issues/432">
    <img src="https://img.shields.io/badge/Upvote%20on%20DMS%20Plugin%20Registry-%E2%86%91-blue?style=flat-square" alt="Upvote on DMS Plugin Registry"/>
  </a>
</p>

Screenshot annotation and screen recording plugin for DankMaterialShell.

<img src="screenshot.png" width="800" alt="Screenshot">

## Documentation

- **[User Guide](docs/user-guide.md)**: capture workflow, annotation tools, shortcuts, floating images, and IPC commands.
- **[Documentation Index](docs/index.md)**: architecture, annotation engine, settings reference, and contributor documentation.

## Requirements

| Dependency | Purpose |
| --- | --- |
| DankMaterialShell >= **1.6.0** | Required for floating window and scrolling capture |
| **gpu-screen-recorder** | Screen recording backend |
| **ffmpeg** | Video thumbnail generation |
| **ImageMagick** (`magick`/`mogrify`) | WebP/JPEG exports and OCR/QR crop |
| **img2pdf** | PDF export |
| **tesseract** | OCR text scanner |
| **zbar** (`zbarimg`) | QR scanner |

## Install

Via DMS CLI:

```bash
dms plugins install quickCapture
```

Or manually:

```bash
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

## Translations

Quick Capture supports native DMS 1.6+ sideload translations located in `translations/<locale>.json`. Contributions and improvements to translations are welcome!

<!-- TRANSLATIONS_TABLE_START -->
| Language | Locale | Progress | Coverage | Status |
| :--- | :--- | :---: | :---: | :---: |
| Arabic | `ar` | 466/479 | 97.3% | 🟡 In Progress |
| Bulgarian | `bg` | 68/479 | 14.2% | 🟡 In Progress |
| German | `de` | 83/479 | 17.3% | 🟡 In Progress |
| Esperanto | `eo` | 63/479 | 13.2% | 🟡 In Progress |
| Spanish | `es` | 82/479 | 17.1% | 🟡 In Progress |
| Persian | `fa` | 58/479 | 12.1% | 🟡 In Progress |
| French | `fr` | 70/479 | 14.6% | 🟡 In Progress |
| Hebrew | `he` | 67/479 | 14.0% | 🟡 In Progress |
| Hungarian | `hu` | 68/479 | 14.2% | 🟡 In Progress |
| Italian | `it` | 466/479 | 97.3% | 🟡 In Progress |
| Japanese | `ja` | 80/479 | 16.7% | 🟡 In Progress |
| Korean | `ko` | 80/479 | 16.7% | 🟡 In Progress |
| Dutch | `nl` | 67/479 | 14.0% | 🟡 In Progress |
| Polish | `pl` | 64/479 | 13.4% | 🟡 In Progress |
| Portuguese | `pt` | 67/479 | 14.0% | 🟡 In Progress |
| Russian | `ru` | 82/479 | 17.1% | 🟡 In Progress |
| Swedish | `sv` | 55/479 | 11.5% | 🟡 In Progress |
| Turkish | `tr` | 43/479 | 9.0% | 🟡 In Progress |
| Ukrainian | `uk` | 68/479 | 14.2% | 🟡 In Progress |
| Vietnamese | `vi` | 82/479 | 17.1% | 🟡 In Progress |
| Chinese (Simplified) | `zh-CN` | 82/479 | 17.1% | 🟡 In Progress |
| Chinese (Traditional) | `zh-TW` | 62/479 | 12.9% | 🟡 In Progress |
<!-- TRANSLATIONS_TABLE_END -->

### Contributing Translations

1. Extract the latest translatable strings:
   ```bash
   python3 scripts/i18n.py extract
   ```
2. Edit your language file under `translations/<locale>.json` (or add a new language with `python3 scripts/i18n.py add-lang <locale>`).
3. Check translation coverage and update the table:
   ```bash
   python3 scripts/i18n.py status --readme
   ```

## Credits

- **[Gradia Capture](https://github.com/AlexanderVanhee/gradia-capture)** — Inspiration for the toolbar layout and background algorithms
- **[Flameshot](https://github.com/flameshot-org/flameshot)** — Inspiration for the radial menu and tool interaction patterns
- **[Snapzy](https://github.com/duongductrong/Snapzy)** — Inspiration for the float image / continue-editing workflow
- **vky** and **bodify** (Discord) — Bug reports and feedback that helped polish the plugin

Thanks to everyone who supported, contributed code, gave feedback, and helped the DankMaterialShell community.

## License

MIT
