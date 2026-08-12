use crate::region_selector::{
    BackgroundImage, SelectOptions, SelectorError, select_region as backend_select_region,
    select_region_with_background as backend_select_region_with_background,
    select_scroll_with_background as backend_select_scroll_with_background,
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
    background: BackgroundImage,
    no_confirm: bool,
    initial_selection: Option<Rect>,
) -> Result<Rect, String> {
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
    rect_from_selection(result.rect)
}

pub fn select_scroll_with_background(
    background: BackgroundImage,
    interval_ms: u64,
    cursor: bool,
) -> Result<(Rect, crate::wayland::CapturedImage), String> {
    let (selection, image) = backend_select_scroll_with_background(
        SelectOptions {
            scroll: true,
            scroll_interval_ms: interval_ms,
            capture_cursor: cursor,
            ..SelectOptions::default()
        },
        background,
    )
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

pub fn background_from_capture(image: &crate::wayland::CapturedImage) -> BackgroundImage {
    let mut pixels = Vec::with_capacity(image.width as usize * image.height as usize * 4);
    for pixel in image.image.pixels() {
        pixels.extend_from_slice(&[pixel[2], pixel[1], pixel[0], 255]);
    }
    BackgroundImage {
        width: image.width,
        height: image.height,
        stride: image.width as usize * 4,
        pixels,
    }
}
