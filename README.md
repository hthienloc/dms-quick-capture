# DMS Quick Capture & Annotate

<p align="center">
  <a href="https://github.com/AvengeMedia/dms-plugin-registry/issues/432">
    <img src="https://img.shields.io/badge/Upvote%20on%20DMS%20Plugin%20Registry-%E2%86%91-blue?style=flat-square" alt="Upvote on DMS Plugin Registry"/>
  </a>
</p>

Screenshot annotation plugin for DankMaterialShell.

<img src="screenshot.png" width="800" alt="Screenshot">

## Documentation

- **[User Guide](docs/user-guide.md)**: capture workflow, annotation tools, shortcuts, floating images, and IPC commands.
- **[Documentation Index](docs/index.md)**: architecture, annotation engine, settings reference, and contributor documentation.

## Requirements

| Dependency | Purpose |
| --- | --- |
| DankMaterialShell >= **1.5.2** | Required for scrolling capture |
| **ImageMagick** (`magick`/`mogrify`) | WebP/JPEG exports and OCR/QR crop |
| **img2pdf** | PDF export |
| **tesseract** | OCR text scanner |
| **zbar** (`zbarimg`) | QR scanner |
| **Qt5Compat GraphicalEffects** (`qt6-qt5compat`) | Floating images |
| **dms-screenshot-rs** | Required and available in `PATH` when the New Backend is selected |

## Install

Via DMS CLI:

```bash
dms plugins install quickCapture
```

Or manually:

```bash
git clone https://github.com/hthienloc/dms-quick-capture ~/.config/DankMaterialShell/plugins/quickCapture
```

For New Backend installation and development, see the [`dms-screenshot-rs` README](dms-screenshot-rs/README.md).

## Credits

- **[Gradia Capture](https://github.com/AlexanderVanhee/gradia-capture)** — Inspiration for the toolbar layout and background algorithms
- **[Flameshot](https://github.com/flameshot-org/flameshot)** — Inspiration for the radial menu and tool interaction patterns
- **[Snapzy](https://github.com/duongductrong/Snapzy)** — Inspiration for the float image / continue-editing workflow
- **vky** and **bodify** (Discord) — Bug reports and feedback that helped polish the plugin

Thanks to everyone who supported, contributed code, gave feedback, and helped the DankMaterialShell community.

## License

MIT
