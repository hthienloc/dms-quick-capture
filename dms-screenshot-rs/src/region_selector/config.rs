pub use super::types::Colors;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Config {
    pub colors: Colors,
    pub border_weight: i32,
    pub display_dimensions: bool,
    pub single_point: bool,
    pub crosshairs: bool,
    pub fixed_aspect_ratio: bool,
    pub aspect_ratio: f64,
    pub font_family: String,
    pub no_confirm: bool,
    pub initial_selection: Option<super::types::Rect>,
    pub scroll: bool,
    pub scroll_interval_ms: u64,
    pub capture_cursor: bool,
}

pub fn from_options(
    options: &super::types::SelectOptions,
) -> Result<Config, super::error::SelectorError> {
    let (fixed_aspect_ratio, aspect_ratio) = match options.aspect_ratio {
        Some((width, height)) if width > 0 && height > 0 => (true, height as f64 / width as f64),
        Some(_) => {
            return Err(super::error::SelectorError::InvalidInput(
                "aspect ratio must be positive".to_string(),
            ));
        }
        None => (false, 0.0),
    };

    Ok(Config {
        colors: options.colors.clone(),
        border_weight: options.border_weight,
        display_dimensions: options.display_dimensions,
        single_point: options.single_point,
        crosshairs: options.crosshairs,
        fixed_aspect_ratio,
        aspect_ratio,
        font_family: "sans-serif".to_string(),
        no_confirm: options.no_confirm,
        initial_selection: options.initial_selection.clone(),
        scroll: options.scroll,
        scroll_interval_ms: options.scroll_interval_ms.max(1),
        capture_cursor: options.capture_cursor,
    })
}
