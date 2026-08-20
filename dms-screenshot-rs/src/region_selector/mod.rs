mod backend;
mod config;
mod error;
mod selection_box;
mod types;

pub(crate) use error::SelectorError;
pub(crate) use types::{BackgroundImage, BackgroundImages, Rect, SelectOptions, Selection};

pub(crate) use crate::wayland::CapturedImage;

pub(crate) fn select_region(options: SelectOptions) -> Result<Selection, SelectorError> {
    let config = config::from_options(&options)?;
    let result = backend::run(&config, None)
        .map_err(|message| SelectorError::from_backend_message(&message))?;
    Ok(Selection {
        rect: result.result.to_rect(),
        output_name: result.output_name,
    })
}

pub(crate) fn select_region_with_background(
    options: SelectOptions,
    background: BackgroundImages,
) -> Result<Selection, SelectorError> {
    let config = config::from_options(&options)?;
    let result = backend::run(&config, Some(background))
        .map_err(|message| SelectorError::from_backend_message(&message))?;
    Ok(Selection {
        rect: result.result.to_rect(),
        output_name: result.output_name,
    })
}

pub(crate) fn select_scroll(
    options: SelectOptions,
) -> Result<(Selection, CapturedImage), SelectorError> {
    let config = config::from_options(&options)?;
    let result = backend::run(&config, None)
        .map_err(|message| SelectorError::from_backend_message(&message))?;
    let image = result
        .captured
        .ok_or_else(|| SelectorError::Backend("scroll capture produced no image".to_string()))?;
    Ok((
        Selection {
            rect: result.result.to_rect(),
            output_name: result.output_name,
        },
        image,
    ))
}
