# Rust Screenshot Backend Architecture

This document describes the runtime design of `dms-screenshot-rs`. It is intended for contributors who need to add capture modes, change selector behavior, or diagnose compositor-specific failures.

## Responsibilities

The binary has four responsibilities:

1. Parse the CLI and preserve the JSON contract expected by Quick Capture.
2. Capture Wayland outputs through `wlr-screencopy-unstable-v1` and `wl_shm`.
3. Run the interactive layer-shell selector.
4. Encode, save, copy, and notify about the resulting image.

The Rust backend is a separate process. Quick Capture starts it with a mode, output path, cursor policy, and `--no-clipboard`; the editor owns the later copy and annotation workflow.

## Module Map

```text
src/main.rs                    CLI dispatch and final image output
src/cli.rs                     Clap commands and capture options
src/contract.rs                JSON success, aborted, and error payloads
src/wayland.rs                 Output discovery, screencopy, crop, composite
src/region_selector/            Layer-shell selector and pointer rendering
src/selector.rs                Selector adapter and frozen-image conversion
src/scroll_session.rs          Capture timing and session state
src/scroll_stitch.rs           Frame matching and stitched canvas
src/state.rs                   Shared last-region persistence
src/window.rs                  Focused-window adapters
src/niri.rs                    Niri ScreenshotWindow integration
```

Keep protocol ownership in the module that owns the corresponding Wayland connection. The selector should not duplicate output capture or persistence logic.

## Command Flow

`main()` maps each command to a `CaptureTarget`:

```text
full      -> focused output
output    -> named output
all       -> capture and composite all outputs
region    -> explicit crop or interactive selector
last      -> persisted global region
window    -> Niri, Hyprland, or Mango adapter
scroll    -> interactive selector followed by scroll session
```

Every successful target returns `CapturedImage`. `save_capture()` then applies the common output path:

```text
CapturedImage
    -> encode PNG/JPEG/PPM
    -> optional DMS clipboard copy
    -> optional file write or stdout
    -> optional notification
    -> JSON or human-readable result
```

Do not add mode-specific file, clipboard, or notification handling unless the output contract genuinely requires it.

## Coordinate Model

The backend uses two coordinate spaces:

### Global logical coordinates

Used for pointer state, selector geometry, saved regions, and cross-output composition. A global region has an origin relative to the compositor's logical desktop.

### Physical pixel coordinates

Used for `wl_shm` buffers, image pixels, and `wlr-screencopy` capture rectangles. Conversion depends on the output scale.

The basic conversion is:

```text
physical = round(logical * scale)
logical  = round(physical / scale)
```

Use `normalize_scale()` whenever a scale enters a calculation. It preserves positive fractional scales such as `0.75`, `1.5`, and `1.75`, while replacing invalid values with `1.0`.

Do not use `max(1.0)` as a generic scale sanitizer. It silently changes valid fractional scales and causes selection, crop, or output-composition errors.

When debugging a scale bug, inspect all of these values together:

- output physical width and height;
- output logical geometry;
- compositor-reported scale;
- SHM buffer width and height;
- requested capture rectangle;
- final image scale and origin.

## Output Discovery and Capture

`wayland::list_outputs()` discovers `wl_output` objects and enriches them with `xdg-output` and `wlr-output-management` metadata when available. The resulting `OutputInfo` contains:

- stable output name;
- physical width and height;
- normalized scale;
- global logical position.

`capture_output_with_region()` creates a fresh screencopy connection for an output capture. It receives a region in either physical or logical coordinates, converts it to the wire coordinates required by screencopy, waits for the frame events, and maps the returned SHM buffer into an `RgbaImage`.

The screencopy `Failed` event means the compositor rejected that capture request. It is not the same as a missing Wayland global. Callers that can reconstruct the image from a full-output capture should use that fallback instead of immediately failing.

## Interactive Selector

The selector in `region_selector/backend.rs` owns one layer-shell surface per output. Its state is divided into:

```text
output state       layer surface, SHM buffers, geometry, viewport
seat state         pointer, keyboard, selection, Ctrl/Shift state
selection state    current rectangle, resize/move operation, result
scroll state       capture rectangle, session, preview, pending frames
```

The normal selector flow is:

```text
discover globals
    -> discover output geometry
    -> create layer-shell surfaces
    -> synchronously render the first frame
    -> process pointer and keyboard events
    -> render only affected outputs
    -> return the selected rectangle
```

The background for a normal region selector is a frozen capture. Each output buffer caches that image. Subsequent frames restore only the previous selection area, draw the new selection, and commit the SHM buffer. This is the main reason the selector remains responsive while the desktop underneath is changing.

### Selection operations

- Drag on an empty surface to create a selection.
- Hold `Ctrl` and drag inside a selection to move it.
- Hold `Ctrl` and drag one of the four corner handles to resize it.
- Hold `Shift` while resizing to enforce a square when the mode allows it.
- `Enter` or `Space` confirms; `Esc` cancels.

Resize handles are intentionally gated by runtime state, not by the configured mode. Scroll mode still has a normal selection phase before scrolling begins, so handles are available there until `scroll_active` becomes true.

## Viewporter and Buffer Strategy

When `wp_viewporter` is available, normal frozen-background selection can keep physical pixels in the SHM buffer and let the compositor scale the surface to logical output dimensions. This avoids resampling the frozen image for every selector frame.

Scroll mode can use viewporter as well. Its selector buffer remains a full physical-output buffer while the layer surface stays in logical coordinates, so fractional scales keep the preview and selection mapping aligned even while the buffer is repainted.

The fallback without viewporter must remain functional. Never assume the protocol is present just because it exists on the development machine.

## Scroll Capture

Scroll capture has two phases.

### Phase 1: select

The user selects a normal region. The selected region is stored as `scroll_rect`.

### Phase 2: capture

After confirmation:

1. `scroll_capture_rect` is created by applying a small inset to the selected region.
2. The inset avoids capturing the white boundary between frames.
3. The selector remains live instead of using a frozen background. Scroll mode runs without a background image, so the layer only contributes the translucent dim overlay.
4. Each interval captures the global region and crops or composites it before feeding it to `ScrollCaptureSession`.
5. Accepted frames update the stitched canvas and request a repaint.
6. The preview panel displays the stitched canvas beside the capture rectangle.
7. Clicking the preview confirms; `Enter` or `Space` also confirms.

The distinction between `scroll_rect` and `scroll_capture_rect` is intentional. The first describes the user's selection; the second describes the pixels actually captured. Preview layout, preview input regions, and fallback capture must use `scroll_capture_rect` so the preview matches the output image.

Scroll deliberately uses global capture for every frame. This is more expensive than direct output-region capture, but it gives one coordinate path for single-output and cross-output regions and avoids compositor-specific clamping that can produce clipped frames or offset previews.

`ScrollCaptureSession` owns timing and in-flight capture state. `ScrollStitcher` owns frame matching, overlap detection, duplicate rejection, sticky-header handling, and the final canvas. Keep these responsibilities separate.

## Last Region

The shared state file is:

```text
$XDG_CACHE_HOME/dms/screenshot-state.json
```

It stores the last normal region in global logical coordinates. Scroll captures must not update it.

`Last Region` intentionally uses one stable path:

```text
list outputs
    -> capture intersecting full outputs
    -> composite them when necessary
    -> crop the saved global region
```

This avoids compositor differences in direct region capture and works for regions crossing output boundaries. Do not change the saved coordinates to physical pixels; that would make the state invalid when output scale changes.

## Window Capture

Window capture is compositor-specific because Wayland does not provide one portable active-window API:

- Niri uses its screenshot IPC integration.
- Hyprland queries the active window and monitor geometry through `hyprctl`.
- Mango uses `mmsg` client and monitor data.

The adapters convert compositor geometry into a logical output-local region, then reuse Wayland capture code. Keep compositor commands isolated in `window.rs` and `niri.rs`.

## Error Handling

Use these categories consistently:

- `aborted`: user cancelled an interactive operation;
- `usage`: invalid CLI combination;
- `unsupported`: unavailable command or capability;
- `runtime`: Wayland, compositor, encoding, filesystem, or clipboard failure.

Do not turn a user cancellation into a toaster error. Preserve the underlying compositor error when no fallback is possible, because `compositor failed` alone is otherwise difficult to diagnose.

## Safe Extension Rules

Before changing the backend:

1. Identify the coordinate space of every input and output.
2. Check whether the code runs before or after `scroll_active` changes.
3. Reuse `CapturedImage`, `OutputInfo`, and the existing crop/composite helpers.
4. Preserve the viewporter fallback.
5. Keep `scroll_rect` separate from `scroll_capture_rect`.
6. Keep last-region persistence limited to normal region selection.
7. Add a unit test for pure geometry, state, or stitching behavior.
8. Manually test the affected mode on the active compositor.

## Verification

Run from the repository root:

```sh
cargo fmt --manifest-path dms-screenshot-rs/Cargo.toml -- --check
cargo test --manifest-path dms-screenshot-rs/Cargo.toml --all-targets --all-features
cargo clippy --manifest-path dms-screenshot-rs/Cargo.toml --all-targets --all-features -- -D warnings
cargo build --release --manifest-path dms-screenshot-rs/Cargo.toml
```

The selector, compositor fallback, fractional-scale behavior, and window adapters require manual testing in a real Wayland session. Test at least:

- scale `1.0`, `1.5`, `1.75`, and below `1.0`;
- one and multiple outputs;
- normal region, last region, and scroll capture;
- Ctrl move and Ctrl resize;
- viewporter available and unavailable;
- direct capture failure followed by fallback.
