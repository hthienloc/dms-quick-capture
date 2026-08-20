use crate::region_selector::{
    BackgroundImages, SelectOptions, Selection, SelectorError,
    select_region as backend_select_region,
    select_region_with_background as backend_select_region_with_background,
    select_scroll as backend_select_scroll,
};
use crate::selection::Rect;

/// Uses the internal Wayland region selector for interactive selection.
pub fn select_region(no_confirm: bool) -> Result<Rect, String> {
    select_region_with_options(SelectOptions {
        no_confirm,
        ..SelectOptions::default()
    })
}

pub fn select_region_with_background(
    background: BackgroundImages,
    no_confirm: bool,
    initial_selection: Option<Rect>,
) -> Result<Selection, String> {
    let result = backend_select_region_with_background(
        SelectOptions {
            no_confirm,
            initial_selection: initial_selection.map(|rect| crate::region_selector::Rect {
                x: rect.x,
                y: rect.y,
                width: rect.width as i32,
                height: rect.height as i32,
            }),
            ..SelectOptions::default()
        },
        background,
    )
    .map_err(map_selection_error)?;
    Ok(result)
}

pub fn select_scroll(
    interval_ms: u64,
    cursor: bool,
) -> Result<(Rect, crate::wayland::CapturedImage), String> {
    let (selection, image) = backend_select_scroll(SelectOptions {
        scroll: true,
        scroll_interval_ms: interval_ms,
        capture_cursor: cursor,
        ..SelectOptions::default()
    })
    .map_err(map_selection_error)?;
    Ok((rect_from_selection(selection.rect)?, image))
}

fn select_region_with_options(options: SelectOptions) -> Result<Rect, String> {
    let selection = backend_select_region(options).map_err(map_selection_error)?;
    rect_from_selection(selection.rect)
}

fn map_selection_error(error: SelectorError) -> String {
    match error {
        SelectorError::Cancelled => "selection cancelled".to_string(),
        error => format!("region selector failed: {error}"),
    }
}

fn rect_from_selection(rect: crate::region_selector::Rect) -> Result<Rect, String> {
    if rect.width <= 0 || rect.height <= 0 {
        return Err("region selector returned an invalid selection".to_string());
    }
    Ok(Rect {
        x: rect.x,
        y: rect.y,
        width: rect.width as u32,
        height: rect.height as u32,
    })
}

pub fn backgrounds_from_captures(captures: &[crate::wayland::CapturedOutput]) -> BackgroundImages {
    captures
        .iter()
        .map(|capture| {
            (
                capture.name.clone(),
                background_from_capture(&capture.image),
            )
        })
        .collect()
}

fn background_from_capture(
    capture: &crate::wayland::CapturedImage,
) -> crate::region_selector::BackgroundImage {
    let scale = crate::wayland::normalize_scale(capture.scale);
    // Fractional scales below one capture fewer physical pixels than the
    // logical selector surface. Integer scales already match the SHM buffer.
    let logical_scale = if scale < 1.0 { scale } else { 1.0 };
    let width = (capture.width as f64 / logical_scale).round().max(1.0) as u32;
    let height = (capture.height as f64 / logical_scale).round().max(1.0) as u32;
    let image = if (capture.width, capture.height) == (width, height) {
        capture.image.clone()
    } else {
        image::imageops::resize(
            &capture.image,
            width,
            height,
            image::imageops::FilterType::Triangle,
        )
    };
    let mut pixels = Vec::with_capacity(width as usize * height as usize * 4);
    for pixel in image.pixels() {
        pixels.extend_from_slice(&[pixel[2], pixel[1], pixel[0], 255]);
    }
    crate::region_selector::BackgroundImage {
        width,
        height,
        stride: image.width() as usize * 4,
        pixels,
        origin_x: capture.origin_x,
        origin_y: capture.origin_y,
    }
}

#[cfg(test)]
mod tests {
    use super::background_from_capture;
    use crate::wayland::CapturedImage;

    #[test]
    fn background_is_resampled_to_logical_dimensions() {
        let capture = CapturedImage {
            image: image::RgbaImage::from_pixel(3, 2, image::Rgba([1, 2, 3, 255])),
            width: 3,
            height: 2,
            scale: 0.75,
            origin_x: 10,
            origin_y: 20,
        };

        let background = background_from_capture(&capture);

        assert_eq!((background.width, background.height), (4, 3));
        assert_eq!(background.stride, 16);
        assert_eq!(background.pixels.len(), 4 * 3 * 4);
        assert_eq!((background.origin_x, background.origin_y), (10, 20));
    }
}
