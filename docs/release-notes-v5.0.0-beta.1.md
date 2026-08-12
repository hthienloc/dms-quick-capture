# Quick Capture v5.0.0-beta.1

This beta introduces the new Rust screenshot backend as an opt-in replacement for the existing backend.

## Highlights

- Adds native Wayland capture, interactive region selection, window capture, and scrolling capture through `dms-screenshot-rs`.
- Adds Old Backend and New Backend selection in Quick Capture settings.
- Improves capture latency and selector responsiveness in local testing.
- Prevents scrolling capture from changing the saved Last Region.
- Adds a live scrolling preview that can be clicked to finish capture.

## Beta Installation

Clone the `beta/rust-backend` branch into the DMS plugin directory:

```sh
git clone -b beta/rust-backend https://github.com/hthienloc/dms-quick-capture "$HOME/.config/DankMaterialShell/plugins/quickCapture"
```

Build and install the Rust backend as described in [`dms-screenshot-rs/README.md`](../dms-screenshot-rs/README.md).

Select **New Backend** in Quick Capture settings after `dms-screenshot-rs` is available in `PATH`.

Select **Old Backend** to return to the stable screenshot path if the beta backend does not work correctly on your compositor.

This is a prerelease and behavior may vary across compositors, display layouts, and system configurations.
