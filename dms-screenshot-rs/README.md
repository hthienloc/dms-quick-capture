# dms-screenshot-rs

Standalone Rust screenshot backend for DankMaterialShell and DMS Quick Capture. It owns Wayland capture, interactive region selection, image encoding, clipboard integration, and the JSON result contract in one binary.

The backend lives in this repository so it can evolve together with Quick Capture, but it is built and installed independently as `dms-screenshot-rs`.

## Quick Start

From the repository root:

```sh
sudo dnf install cairo-devel libXcursor-devel rust cargo
cargo build --release --manifest-path dms-screenshot-rs/Cargo.toml
./dms-screenshot-rs/target/release/dms-screenshot-rs full --no-clipboard --json
```

For a user-local installation:

```sh
cargo install --path dms-screenshot-rs --root "$HOME/.local"
command -v dms-screenshot-rs
```

Quick Capture resolves `dms-screenshot-rs` through `PATH` when the New Backend is selected in settings.

## Uninstall

Remove the user-local binary:

```sh
rm -f "$HOME/.local/bin/dms-screenshot-rs"
```

When the backend was installed with `cargo install`, the same command removes the installed binary.
To also remove local build artifacts from this repository:

```sh
rm -rf dms-screenshot-rs/target
```

Finally, select the Old Backend in Quick Capture settings or remove the plugin if it is no longer needed.
The backend does not create a separate persistent configuration directory.

## Commands

| Command | Description |
| --- | --- |
| `full` | Capture the focused output |
| `output` | Capture a named output with `--output NAME` or `NAME` |
| `all` | Capture and composite all outputs |
| `region` | Select a region interactively, or use explicit coordinates |
| `window` | Capture the focused window through compositor-specific integration |
| `last` | Capture the previously saved region |
| `scroll` | Select a region, capture while content scrolls, and stitch the result |
| `list` | List Wayland outputs and their geometry |

Examples:

```sh
dms-screenshot-rs list --json
dms-screenshot-rs full --no-clipboard --dir /tmp --filename full.png --json
dms-screenshot-rs output DP-1 --no-clipboard
dms-screenshot-rs region --no-clipboard --json
dms-screenshot-rs region --x 100 --y 100 --width 800 --height 600 --no-clipboard --json
dms-screenshot-rs scroll --no-clipboard --interval 45 --json
```

Interactive region capture confirms with `Enter` or `Space` and cancels with `Esc`. Scroll capture confirms the initial region, leaves the screen live while the user scrolls, then finishes stitching with `Enter` or cancels with `Esc`.

### Selector Performance

The selector intentionally uses a frozen screenshot as its background so the image being selected cannot change underneath the pointer. Each SHM buffer caches that background and later frames update only the previous and current selection regions. This keeps selection responsive while avoiding the complexity of a separate live overlay surface. A small amount of pointer latency can remain compared with `slurp`, which renders only a translucent overlay over the live desktop and therefore does less work.

## Common Options

| Option | Description |
| --- | --- |
| `--json` | Emit machine-readable success or error metadata |
| `--cursor on|off` | Include or exclude the cursor in captured images |
| `--format png|jpg|jpeg|ppm` | Output image format |
| `--quality 1-100` | JPEG quality, default `90` |
| `--dir`, `--directory` | Output directory |
| `--filename` | Output filename |
| `--no-clipboard` | Do not copy the captured PNG |
| `--no-notify` | Do not send a desktop notification |
| `--no-file` | Skip the output file; useful with clipboard or `--stdout` |
| `--stdout` | Write encoded image bytes to stdout; cannot be combined with `--json` |
| `--no-confirm` | Finish normal region selection on mouse release |
| `--reset` | Clear the saved last-region selection |
| `--interval MS` | Scroll capture interval, from 30 to 1000 milliseconds |

The default command is `region`. PNG, JPEG (`jpg`/`jpeg`), and PPM output are supported. PPM captures are copied to the clipboard as PNG because DMS clipboard integration expects a raster image MIME type.

When `--filename` is omitted, files use the DMS-compatible local-time format `screenshot_YYYY-MM-DD_HH-MM-SS.<extension>`.

## Clipboard

Clipboard output uses the DMS clipboard service:

```sh
dms-screenshot-rs full
dms-screenshot-rs full --no-clipboard
```

Without `--no-clipboard`, the backend encodes the image as PNG and pipes it to:

```sh
dms cl copy --type image/png
```

This keeps clipboard behavior consistent with DMS and avoids a separate `wl-copy` dependency. The `dms` command must be available in `PATH` when clipboard output is enabled. Quick Capture passes `--no-clipboard` during capture and performs clipboard copying only when the user selects a copy action in the editor.

Unless `--no-notify` is provided, the backend sends a `Screenshot captured` notification through `dms notify`. Notification failures do not fail an otherwise successful capture. Quick Capture passes `--no-notify` because its editor workflow handles feedback separately.

## Output Contract

With `--json`, successful file captures return:

```json
{"status":"success","path":"/tmp/capture.png","width":1920,"height":1080,"scale":1.0,"mime":"image/png"}
```

Cancelled interactive selections return `status: "aborted"`. Runtime, usage, and unsupported operations return `status: "error"` with an `error` field. Exit code `0` indicates success, while capture failures return a non-zero exit code.

## Architecture

```text
dms-screenshot-rs/
├── src/cli.rs                 # Clap CLI and shared capture options
├── src/contract.rs            # JSON success, aborted, and error payloads
├── src/main.rs                # Command dispatch, encoding, files, clipboard
├── src/wayland.rs             # wl_output and wlr-screencopy capture
├── src/window.rs              # Compositor-specific focused-window capture
├── src/niri.rs                # Niri ScreenshotWindow integration
├── src/selector.rs            # Selector adapter and coordinate conversion
├── src/region_selector/       # Internal layer-shell region selector
├── src/scroll_stitch.rs       # Frame matching and canvas stitching
├── src/scroll_session.rs      # Scroll capture state machine
├── src/state.rs               # Shared last-region persistence
└── benchmarks/compare.sh      # Old/New non-interactive latency comparison
```

The selector is an internal implementation derived from the interaction model of [`slurp-rs`](https://docs.rs/slurp-rs/latest/slurp_rs/), which follows [`emersion/slurp`](https://github.com/emersion/slurp). No selector crate or external selector process is required.

The capture path uses `wlr-screencopy-unstable-v1` and `wl_shm`. Interactive selection uses `zwlr-layer-shell-v1`. Window capture uses Niri's IPC when `NIRI_SOCKET` is available, and compositor-specific geometry adapters for Hyprland and Mango.

Niri's `ScreenshotWindow` IPC currently does not expose a `no-notify` option, so Niri may show its own screenshot notification. Track [niri PR #1795](https://github.com/niri-wm/niri/pull/1795) for the upstream change.

## Development

Run from the repository root:

```sh
cargo check --manifest-path dms-screenshot-rs/Cargo.toml
cargo fmt --manifest-path dms-screenshot-rs/Cargo.toml -- --check
cargo test --manifest-path dms-screenshot-rs/Cargo.toml --offline
cargo build --release --manifest-path dms-screenshot-rs/Cargo.toml
```

The selector and scroll stitcher require a real graphical Wayland session for manual testing. Unit and CLI tests do not require a compositor.

## Benchmarking

The existing benchmark compares the Old and New backends for non-interactive PNG capture, including process startup, Wayland capture, and file output:

```sh
cargo build --release --manifest-path dms-screenshot-rs/Cargo.toml
./dms-screenshot-rs/benchmarks/compare.sh
```

Configure the run with `WARMUPS`, `ITERATIONS`, `MODE`, and `OUTPUT_DIR`. `MODE=last` measures the saved-region path only. Interactive selector smoothness is not included because it depends on pointer input and compositor frame scheduling.

### Reference Results

The following local `full` capture benchmark used three measured iterations and one warmup on 2026-08-12.

| Backend | Min (ms) | Median (ms) | Average (ms) |
| --- | ---: | ---: | ---: |
| Old backend (`dms`) | 1039.10 | 1122.89 | 1162.94 |
| New backend (`dms-screenshot-rs`) | 346.77 | 461.49 | 436.85 |

The new backend was approximately 2.43x faster by median latency and 2.66x faster by average latency in this run.
These results are indicative only and vary with compositor, display resolution, hardware, and system load.

## Runtime Requirements

| Requirement | Used for |
| --- | --- |
| Fedora `cairo-devel` | Cairo-backed selector rendering |
| Fedora `libXcursor-devel` | Cursor theme rendering fallback |
| Wayland compositor with `wlr-screencopy` | Screen capture |
| Wayland compositor with layer-shell | Interactive selector |
| DMS in `PATH` | Image clipboard output |

The backend currently targets the Wayland environments used by DMS. Niri window capture is implemented directly; Hyprland and Mango use compositor geometry adapters. Window capture support and scroll behavior still require manual verification across compositors before the backend replaces every Go path in Quick Capture.

## License

See `Cargo.toml` for the backend package license.
