# Annotation & Rendering Engine

This document details the rendering architecture of the annotation canvas, vector shapes management, and specialized visual tools inside DMS Quick Capture.

---

## 1. The Canvas Pipeline

Annotations are rendered dynamically using a QML `Canvas` component. Rather than drawing statically on a raster surface, the engine maintains an array model of **Vector Objects**.

### Rendering Lifecycle
1. When a user draws or edits a shape, a new element is appended or updated in the `drawModel` array.
2. The canvas requests a redraw via `canvas.requestPaint()`.
3. The `onPaint` handler clears the context, redraws the background image, applies the backdrop style, and loops through all active model shapes to draw them in sequence.

```
[User Action] ➔ [Update Shape Model] ➔ [requestPaint()] ➔ [onPaint() Redraw Loop] ➔ [Screen Output]
```

---

## 2. Drawing Constraint Engine (Shift Modifier)

To draw precise geometric shapes, the engine implements a Constraint Helper. When `Shift` is held down during dragging, the ending coordinate (`endX`, `endY`) is mathematically adjusted:

| Tool | Constraint Math | Output |
| :--- | :--- | :--- |
| **Pen** | Disables curved tracking, draws a single line segment | Straight line |
| **Line / Arrow** | Snaps the angle to the nearest multiple of 45° | Angular line |
| **Rectangle / Blur** | Sets `width` equal to `height` (`Math.min(dx, dy)`) | Square |
| **Ellipse** | Sets vertical radius equal to horizontal radius | Circle |

---

## 3. Magnifier Lens & Area Zoom (Callout)

### Magnifier Lens (Hold B)
The Magnifier Lens renders a magnified view of the cursor's current position:
- **Concept:** It captures the raw screenshot canvas area around the mouse, scales it by a zoom factor (configurable via mouse wheel, 1.5× to 4.0×), and draws it in a floating circular component centered on the cursor.
- **Auto-Contrast Circle:** The outer ring of the lens adjusts its border color dynamically based on the pixel colors under the cursor to remain visible.

### Area Zoom Callout (Z Key)
Allows highlighting and enlarging a specific rectangular area:
- **Draw Phase:** The user presses `Z` and drags a rectangle on the canvas.
- **Math Mapping:** The region boundary `(x1, y1, w1, h1)` is mapped into a source coordinate for a sub-render item. The target box `(x2, y2, w2, h2)` is rendered on top, displaying the scaled-up source pixels (100% to 500% zoom).

---

## 4. Backdrop Layout Wrapping

When a backdrop mode (Solid or Gradient) is active, the screenshot is wrapped within a padded canvas container:

```
+-------------------------------------------------------+
|  Backdrop Background (Solid / Gradient / Image)       |
|                                                       |
|     +-------------------------------------------+     |
|     |  Padded Margins (Adjustable)              |     |
|     |                                           |     |
|     |     +-------------------------------+     |     |
|     |     |  Raw Screenshot Area          |     |     |
|     |     |  (Optional Rounded Corners)   |     |     |
|     |     |  (Drop Shadow Applied)        |     |     |
|     |     +-------------------------------+     |     |
|     +-------------------------------------------+     |
+-------------------------------------------------------+
```

### Key Backdrop Properties
- **Padding:** Outer margins separating the screenshot edge from the backdrop canvas boundary.
- **Corner Radius:** Applies a smooth clipping path on the screenshot image.
- **Drop Shadow:** Emulates depth around the screenshot frame using multi-pass blur shaders or shadow container margins.
- **Aspect Ratio:** Resizes the background wrapper to match "1:1", "16:9", "4:3", or "Auto" (fitting exactly to the screenshot).
