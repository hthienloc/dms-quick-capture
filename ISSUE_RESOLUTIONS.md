# Quick Capture Issue Resolutions (derived from screen-toolkit)

This document contains detailed technical strategies and code snippets derived from the `screen-toolkit` codebase to help resolve open issues in `dms-quick-capture`.

---

## 1. Issue #16: OCR Support
**Strategy**: Implement a multi-pass OCR logic with heavy ImageMagick preprocessing.

### Image Preprocessing (magick)
Optimize the image before Tesseract analysis:
- **Upscaling**: Tesseract performs better on high-res text. If `height < 30px`, scale 400%.
- **Grayscale & Normalization**: Convert to gray and normalize contrast.
- **Background Detection**: Calculate mean brightness; if background is dark, negate the image.
- **Noise Reduction**: Use a median filter.

### Multi-Pass Logic
Run Tesseract multiple times with different **PSM** (Page Segmentation Modes):
- **Pass 1**: PSM 3 (Auto)
- **Pass 2 (Small/Uniform)**: PSM 6
- **Pass 3 (Sparse)**: PSM 11
- **Pass 4 (Single line)**: PSM 7

### Translation
Use `trans` (Google Translate CLI) for instant results:
```bash
trans -brief -to [TARGET_LANG] '[TEXT]'
```

---

## 2. Issue #13: Floating Pinned Images
**Strategy**: Use Wayland LayerShell Top windows.

- Create a `PanelWindow` (or `DankPopoutStandalone`) with `WlrLayershell.layer: WlrLayer.Top`.
- Set `WlrLayershell.keyboardFocus: WlrKeyboardFocus.None`.
- Use a `mask: Region { ... }` to ensure the window only blocks clicks where the image is visible.
- Add a **Control Strip** (on hover) for Opacity, Fill Mode (Fit/Crop/Stretch), and Close.
- Use a `ListModel` to manage multiple pins across screens.

---

## 3. Issue #18: Link Sharing
**Strategy**: Dual-mode upload script (Anonymous + Authenticated).

- **Anonymous Backend**: `uguu.se` (128MB max, 3h retention).
- **Authenticated Backend**: `up.x02.me` (requires API Key in Settings).
- **Flattening**: Ensure annotations are merged into the background PNG before upload.
- **UX**: Show a progress state, then a popover with the URL and a "Copy" button.

---

## 4. Issue #15: Backdrop Tool
**Strategy**: Fragment Shader for high performance.

- Implement a `.frag` shader that takes `selectionRect` and `dimOpacity` as uniforms.
- Use `smoothstep` for anti-aliasing the edges of the "cutout".
- Wrap in a `ShaderEffect` covering the whole screen.
- Add `borderRadius` support to match DMS aesthetics.

---

## 5. Issue #4: Color Palette Presets
**Strategy**: ImageMagick color reduction.

### Extraction Command
```bash
magick "$FILE" -alpha off +dither -colors 8 -unique-colors txt:- | grep -oP '#[0-9a-fA-F]{6}' | head -8
```

### Presentation
- Show interactive color cards.
- Provide "Copy as CSS Variables" and "Copy as HEX List" buttons.

---

## 6. Issue #12: Curved Arrows
**Strategy**: HTML5 Canvas `quadraticCurveTo`.

Instead of a simple `lineTo` for arrows, use a 3-point calculation (Start, Control, End).

**Code Logic**:
```javascript
// Calculate arrow head at 'end' point
var dx = x2 - x1;
var dy = y2 - y1;
var angle = Math.atan2(dy, dx);
var hs = size * 4; // Head size
var hw = Math.PI / 6; // Head width angle

ctx.beginPath();
ctx.moveTo(x1, y1);
ctx.quadraticCurveTo(ctrlX, ctrlY, x2, y2); // Use a control point for curve
ctx.stroke();

// Draw head
ctx.beginPath();
ctx.moveTo(x2, y2);
ctx.lineTo(x2 - hs * Math.cos(angle - hw), y2 - hs * Math.sin(angle - hw));
ctx.lineTo(x2 - hs * Math.cos(angle + hw), y2 - hs * Math.sin(angle + hw));
ctx.closePath();
ctx.fill();
```

---

## 7. Issue #14: Move Zoom to Alt Key
**Strategy**: Keyboard Shortcut handling in QML.

- Move the "Lens" or "Zoom" tool trigger to a `Shortcut` component.
- Use `sequence: "Alt"` (or handle in `Keys.onPressed`).
- Use `Z` key for a "Quick Magnifier" (local zoom) instead of full tool.

---

## 8. Issue #21: Image Compression Settings
**Strategy**: Magick quality parameters.

Add a slider in Settings (0-100). When saving/uploading, pass the value to `magick`:
```bash
magick input.png -quality [QUALITY] output.jpg
# Or for PNG
magick input.png -define png:compression-level=[LEVEL] output.png
```

---

## 9. Issue #19: Internationalization (i18n)
**Strategy**: JSON-based translation files.

1. Create a `i18n/` directory.
2. Add `en.json`, `vi.json`, etc.
3. Use a helper function `tr(key)` in QML that loads the correct string from the JSON model based on system locale.
4. `screen-toolkit` uses a very clean pattern for this in its `Main.qml` and `i18n/` folder.
