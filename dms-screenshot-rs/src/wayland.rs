use std::collections::HashMap;
use std::os::fd::AsFd;
use std::process::Command;

use memmap2::MmapMut;
use tempfile::tempfile;
use wayland_client::WEnum;
use wayland_client::{
    Connection, Dispatch, QueueHandle, delegate_noop,
    protocol::{wl_buffer, wl_output, wl_registry, wl_shm, wl_shm_pool},
};
use wayland_protocols::xdg::xdg_output::zv1::client::{zxdg_output_manager_v1, zxdg_output_v1};
use wayland_protocols_wlr::output_management::v1::client::{
    zwlr_output_head_v1, zwlr_output_manager_v1, zwlr_output_mode_v1,
};
use wayland_protocols_wlr::screencopy::v1::client::{
    zwlr_screencopy_frame_v1, zwlr_screencopy_manager_v1,
};

use crate::contract::OutputInfo;
use crate::selection::{Rect, clamp};

pub(crate) fn normalize_scale(scale: f64) -> f64 {
    if scale.is_finite() && scale > 0.0 {
        scale
    } else {
        1.0
    }
}

#[derive(Default)]
struct OutputState {
    proxy: Option<wl_output::WlOutput>,
    name: String,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    scale: f64,
}

struct State {
    outputs: HashMap<usize, OutputState>,
    next_output: usize,
    xdg_output_manager: Option<zxdg_output_manager_v1::ZxdgOutputManagerV1>,
    xdg_outputs: Vec<zxdg_output_v1::ZxdgOutputV1>,
    wlr_output_manager: Option<zwlr_output_manager_v1::ZwlrOutputManagerV1>,
    wlr_heads: Vec<WlrHeadState>,
}

struct WlrHeadState {
    proxy: zwlr_output_head_v1::ZwlrOutputHeadV1,
    name: String,
    x: i32,
    y: i32,
    scale: f64,
}

pub fn list_outputs() -> Result<Vec<OutputInfo>, String> {
    let connection =
        Connection::connect_to_env().map_err(|error| format!("connect to Wayland: {error}"))?;
    let mut event_queue = connection.new_event_queue();
    let queue_handle = event_queue.handle();
    let display = connection.display();
    display.get_registry(&queue_handle, ());

    let mut state = State {
        outputs: HashMap::new(),
        next_output: 0,
        xdg_output_manager: None,
        xdg_outputs: Vec::new(),
        wlr_output_manager: None,
        wlr_heads: Vec::new(),
    };
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("discover Wayland outputs: {error}"))?;
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("read Wayland output metadata: {error}"))?;

    if let Some(manager) = state.xdg_output_manager.as_ref().cloned() {
        let mut xdg_outputs = Vec::new();
        for (index, output) in &state.outputs {
            let Some(proxy) = output.proxy.as_ref() else {
                continue;
            };
            xdg_outputs.push(manager.get_xdg_output(proxy, &event_queue.handle(), *index));
        }
        state.xdg_outputs = xdg_outputs;
        event_queue
            .roundtrip(&mut state)
            .map_err(|error| format!("read logical Wayland output metadata: {error}"))?;
    }

    for head in &state.wlr_heads {
        if let Some(output) = state
            .outputs
            .values_mut()
            .find(|output| output.name == head.name)
        {
            output.x = head.x;
            output.y = head.y;
            if head.scale > 0.0 {
                output.scale = head.scale;
            }
        }
    }

    if state.outputs.is_empty() {
        return Err("Wayland compositor exposed no outputs".to_string());
    }

    let mut outputs: Vec<_> = state
        .outputs
        .into_values()
        .filter(|output| output.width > 0 && output.height > 0)
        .map(|output| OutputInfo {
            name: if output.name.is_empty() {
                "unknown".to_string()
            } else {
                output.name
            },
            width: output.width,
            height: output.height,
            scale: normalize_scale(output.scale),
            position: Some((output.x, output.y)),
        })
        .collect();
    outputs.sort_by(|left, right| left.name.cmp(&right.name));
    Ok(outputs)
}

impl Dispatch<wl_registry::WlRegistry, ()> for State {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        queue_handle: &QueueHandle<Self>,
    ) {
        let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        else {
            return;
        };
        match interface.as_str() {
            "wl_output" => {
                let index = state.next_output;
                state.next_output += 1;
                state.outputs.insert(index, OutputState::default());
                let proxy = registry.bind::<wl_output::WlOutput, _, _>(
                    name,
                    version.min(4),
                    queue_handle,
                    index,
                );
                state.outputs.get_mut(&index).unwrap().proxy = Some(proxy);
            }
            "zxdg_output_manager_v1" => {
                state.xdg_output_manager = Some(
                    registry.bind::<zxdg_output_manager_v1::ZxdgOutputManagerV1, _, _>(
                        name,
                        version.min(3),
                        queue_handle,
                        (),
                    ),
                );
            }
            "zwlr_output_manager_v1" => {
                state.wlr_output_manager = Some(
                    registry.bind::<zwlr_output_manager_v1::ZwlrOutputManagerV1, _, _>(
                        name,
                        version.min(4),
                        queue_handle,
                        (),
                    ),
                );
            }
            _ => {}
        }
    }
}

impl Dispatch<zwlr_output_manager_v1::ZwlrOutputManagerV1, ()> for State {
    fn event(
        state: &mut Self,
        _: &zwlr_output_manager_v1::ZwlrOutputManagerV1,
        event: zwlr_output_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let zwlr_output_manager_v1::Event::Head { head } = event {
            state.wlr_heads.push(WlrHeadState {
                proxy: head,
                name: String::new(),
                x: 0,
                y: 0,
                scale: 1.0,
            });
        }
    }

    wayland_client::event_created_child!(
        State,
        zwlr_output_manager_v1::ZwlrOutputManagerV1,
        [zwlr_output_manager_v1::EVT_HEAD_OPCODE => (zwlr_output_head_v1::ZwlrOutputHeadV1, ())]
    );
}

impl Dispatch<zwlr_output_head_v1::ZwlrOutputHeadV1, ()> for State {
    fn event(
        state: &mut Self,
        proxy: &zwlr_output_head_v1::ZwlrOutputHeadV1,
        event: zwlr_output_head_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(head) = state.wlr_heads.iter_mut().find(|head| head.proxy == *proxy) else {
            return;
        };
        match event {
            zwlr_output_head_v1::Event::Name { name } => head.name = name,
            zwlr_output_head_v1::Event::Position { x, y } => {
                head.x = x;
                head.y = y;
            }
            zwlr_output_head_v1::Event::Scale { scale } => head.scale = scale,
            _ => {}
        }
    }

    wayland_client::event_created_child!(
        State,
        zwlr_output_head_v1::ZwlrOutputHeadV1,
        [zwlr_output_head_v1::EVT_MODE_OPCODE => (zwlr_output_mode_v1::ZwlrOutputModeV1, ())]
    );
}

delegate_noop!(State: ignore zwlr_output_mode_v1::ZwlrOutputModeV1);

impl Dispatch<zxdg_output_v1::ZxdgOutputV1, usize> for State {
    fn event(
        state: &mut Self,
        _: &zxdg_output_v1::ZxdgOutputV1,
        event: zxdg_output_v1::Event,
        index: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(index) else {
            return;
        };
        if let zxdg_output_v1::Event::LogicalPosition { x, y } = event {
            output.x = x;
            output.y = y;
        }
    }
}

delegate_noop!(State: ignore zxdg_output_v1::ZxdgOutputV1);
delegate_noop!(State: ignore zxdg_output_manager_v1::ZxdgOutputManagerV1);

impl Dispatch<wl_output::WlOutput, usize> for State {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        index: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(index) else {
            return;
        };

        match event {
            wl_output::Event::Geometry { x, y, .. } => {
                output.x = x;
                output.y = y;
            }
            wl_output::Event::Mode {
                width,
                height,
                flags,
                ..
            } => {
                let is_current = match flags {
                    WEnum::Value(wl_output::Mode::Current) => true,
                    WEnum::Unknown(value) => value & 1 != 0,
                    _ => false,
                };
                if is_current || output.width == 0 {
                    output.width = width;
                    output.height = height;
                }
            }
            wl_output::Event::Scale { factor } => output.scale = factor as f64,
            wl_output::Event::Name { name } => output.name = name,
            _ => {}
        }
    }
}

delegate_noop!(State: ignore wl_output::WlOutput);

pub struct CapturedImage {
    pub image: image::RgbaImage,
    pub width: u32,
    pub height: u32,
    pub scale: f64,
    /// Physical-pixel origin of this image in the compositor-global space.
    pub origin_x: i64,
    pub origin_y: i64,
}

pub struct CapturedOutput {
    pub name: String,
    pub image: CapturedImage,
}

struct CaptureOutputState {
    proxy: wl_output::WlOutput,
    info: OutputState,
}

struct CaptureState {
    outputs: HashMap<usize, CaptureOutputState>,
    next_output: usize,
    shm: Option<wl_shm::WlShm>,
    manager: Option<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1>,
    frame: Option<zwlr_screencopy_frame_v1::ZwlrScreencopyFrameV1>,
    pool: Option<wl_shm_pool::WlShmPool>,
    buffer: Option<wl_buffer::WlBuffer>,
    file: Option<std::fs::File>,
    mmap: Option<MmapMut>,
    width: u32,
    height: u32,
    stride: u32,
    format: Option<wl_shm::Format>,
    ready: bool,
    error: Option<String>,
}

pub fn capture_output(name: Option<&str>, cursor: bool) -> Result<CapturedImage, String> {
    capture_output_with_region(name, None, false, cursor)
}

pub fn capture_outputs(cursor: bool) -> Result<Vec<CapturedOutput>, String> {
    list_outputs()?
        .into_iter()
        .map(|output| {
            let name = output.name;
            let image = capture_output(Some(&name), cursor)
                .map_err(|error| format!("capture output {name}: {error}"))?;
            Ok(CapturedOutput { name, image })
        })
        .collect()
}

fn capture_output_with_region(
    name: Option<&str>,
    requested_region: Option<Rect>,
    region_is_logical: bool,
    cursor: bool,
) -> Result<CapturedImage, String> {
    let connection =
        Connection::connect_to_env().map_err(|error| format!("connect to Wayland: {error}"))?;
    let mut event_queue = connection.new_event_queue();
    let queue_handle = event_queue.handle();
    connection.display().get_registry(&queue_handle, ());

    let mut state = CaptureState {
        outputs: HashMap::new(),
        next_output: 0,
        shm: None,
        manager: None,
        frame: None,
        pool: None,
        buffer: None,
        file: None,
        mmap: None,
        width: 0,
        height: 0,
        stride: 0,
        format: None,
        ready: false,
        error: None,
    };
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("discover screencopy globals: {error}"))?;
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("read screencopy output metadata: {error}"))?;

    let focused_name = name.is_none().then(focused_output_name).flatten();
    let selected = if let Some(wanted) = name {
        state
            .outputs
            .iter()
            .find(|(_, output)| output.info.name == wanted)
    } else if let Some(focused) = focused_name.as_deref() {
        state
            .outputs
            .iter()
            .find(|(_, output)| output.info.name == focused)
    } else {
        state
            .outputs
            .iter()
            .min_by_key(|(_, output)| output.info.name.clone())
    };
    let output_scale = selected.map(|(_, output)| output.info.scale).unwrap_or(1.0);
    let output_bounds = selected.map(|(_, output)| Rect {
        x: 0,
        y: 0,
        width: output.info.width.max(0) as u32,
        height: output.info.height.max(0) as u32,
    });
    let output = selected
        .map(|(_, output)| output.proxy.clone())
        .ok_or_else(|| match name {
            Some(name) => format!("output not found: {name}"),
            None => "Wayland compositor exposed no outputs".to_string(),
        })?;
    let manager = state
        .manager
        .as_ref()
        .ok_or_else(|| "compositor does not support wlr-screencopy-unstable-v1".to_string())?;
    if state.shm.is_none() {
        return Err("compositor does not support wl_shm".to_string());
    }

    let region = requested_region.map(|region| {
        let bounds = output_bounds.unwrap_or(Rect {
            x: 0,
            y: 0,
            width: u32::MAX,
            height: u32::MAX,
        });
        let bounds = if region_is_logical {
            Rect {
                width: (bounds.width as f64 / output_scale).round().max(1.0) as u32,
                height: (bounds.height as f64 / output_scale).round().max(1.0) as u32,
                ..bounds
            }
        } else {
            bounds
        };
        clamp(region, bounds)
    });
    if let Some(region) = region {
        let capture_x = if region_is_logical {
            (region.x as f64 * output_scale).round() as i32
        } else {
            (region.x as f64 / output_scale).round() as i32
        };
        let capture_y = if region_is_logical {
            (region.y as f64 * output_scale).round() as i32
        } else {
            (region.y as f64 / output_scale).round() as i32
        };
        let capture_width = if region_is_logical {
            (region.width as f64 * output_scale).round().max(1.0) as i32
        } else {
            (region.width as f64 / output_scale).round().max(1.0) as i32
        };
        let capture_height = if region_is_logical {
            (region.height as f64 * output_scale).round().max(1.0) as i32
        } else {
            (region.height as f64 / output_scale).round().max(1.0) as i32
        };
        state.frame = Some(manager.capture_output_region(
            i32::from(cursor),
            &output,
            capture_x,
            capture_y,
            capture_width,
            capture_height,
            &queue_handle,
            (),
        ));
    } else {
        state.frame = Some(manager.capture_output(i32::from(cursor), &output, &queue_handle, ()));
    }
    while !state.ready && state.error.is_none() {
        event_queue
            .blocking_dispatch(&mut state)
            .map_err(|error| format!("capture dispatch: {error}"))?;
    }
    if let Some(error) = state.error {
        return Err(error);
    }

    let width = state.width;
    let height = state.height;
    let stride = state.stride as usize;
    let format = state
        .format
        .ok_or_else(|| "screencopy did not provide a buffer format".to_string())?;
    let mmap = state
        .mmap
        .as_ref()
        .ok_or_else(|| "screencopy buffer was not created".to_string())?;
    let mut rgba = vec![0u8; width as usize * height as usize * 4];
    for y in 0..height as usize {
        for x in 0..width as usize {
            let source = y * stride + x * 4;
            let target = (y * width as usize + x) * 4;
            let pixel = mmap
                .get(source..source + 4)
                .ok_or_else(|| "screencopy returned an invalid buffer".to_string())?;
            match format {
                wl_shm::Format::Argb8888 | wl_shm::Format::Xrgb8888 => {
                    rgba[target..target + 4].copy_from_slice(&[pixel[2], pixel[1], pixel[0], 255]);
                }
                wl_shm::Format::Abgr8888 | wl_shm::Format::Xbgr8888 => {
                    rgba[target..target + 4].copy_from_slice(&[pixel[0], pixel[1], pixel[2], 255]);
                }
                _ => return Err(format!("unsupported wl_shm format: {format:?}")),
            }
        }
    }

    let image = image::RgbaImage::from_raw(width, height, rgba)
        .ok_or_else(|| "failed to construct captured image".to_string())?;
    Ok(CapturedImage {
        image,
        width,
        height,
        scale: output_scale,
        origin_x: 0,
        origin_y: 0,
    })
}

pub fn capture_all(cursor: bool) -> Result<CapturedImage, String> {
    let outputs = list_outputs()?;
    if outputs.is_empty() {
        return Err("Wayland compositor exposed no outputs".to_string());
    }

    let mut pending = Vec::with_capacity(outputs.len());
    let mut max_scale: f64 = 1.0;

    for output in outputs {
        let name = output.name.clone();
        let position = output
            .position
            .ok_or_else(|| format!("output has no position: {name}"))?;
        let image = capture_output(Some(&name), cursor)?;
        let scale = normalize_scale(output.scale);
        max_scale = max_scale.max(scale);
        pending.push((image.image, position.0 as f64, position.1 as f64, scale));
    }

    if pending.len() == 1 {
        let (image, _, _, scale) = pending.pop().expect("one pending capture");
        return Ok(CapturedImage {
            width: image.width(),
            height: image.height(),
            image,
            scale,
            origin_x: 0,
            origin_y: 0,
        });
    }

    let mut entries = Vec::with_capacity(pending.len());
    let mut min_x = i64::MAX;
    let mut min_y = i64::MAX;
    let mut max_x = i64::MIN;
    let mut max_y = i64::MIN;
    for (image, log_x, log_y, scale) in pending {
        let x = (log_x * max_scale).round() as i64;
        let y = (log_y * max_scale).round() as i64;
        let width = (image.width() as f64 * max_scale / scale).round() as i64;
        let height = (image.height() as f64 * max_scale / scale).round() as i64;
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + width);
        max_y = max_y.max(y + height);
        entries.push((image, x, y, width, height));
    }

    let width = u32::try_from(max_x - min_x)
        .map_err(|_| "combined output width is out of range".to_string())?;
    let height = u32::try_from(max_y - min_y)
        .map_err(|_| "combined output height is out of range".to_string())?;
    let mut image = image::RgbaImage::from_pixel(width, height, image::Rgba([0, 0, 0, 255]));
    for (capture, x, y, width, height) in entries {
        let resized = image::imageops::resize(
            &capture,
            u32::try_from(width).map_err(|_| "output width is out of range")?,
            u32::try_from(height).map_err(|_| "output height is out of range")?,
            image::imageops::FilterType::Nearest,
        );
        image::imageops::overlay(&mut image, &resized, x - min_x, y - min_y);
    }

    Ok(CapturedImage {
        width,
        height,
        image,
        scale: max_scale,
        origin_x: min_x,
        origin_y: min_y,
    })
}

pub fn capture_output_region(
    name: Option<&str>,
    requested: Rect,
    cursor: bool,
) -> Result<CapturedImage, String> {
    let capture = capture_output_with_region(name, Some(requested), false, cursor)?;
    if capture.width == 0 || capture.height == 0 {
        return Err("region is outside the captured output".to_string());
    }
    Ok(capture)
}

pub fn capture_output_region_logical(
    name: Option<&str>,
    requested: Rect,
    cursor: bool,
) -> Result<CapturedImage, String> {
    let capture = capture_output_with_region(name, Some(requested), true, cursor)?;
    if capture.width == 0 || capture.height == 0 {
        return Err("region is outside the captured output".to_string());
    }
    Ok(capture)
}

/// Captures a region expressed in the compositor's global logical coordinates.
///
/// Interactive selection and the shared last-region state use global positions,
/// The intersecting outputs are captured and composited before cropping so
/// this path behaves consistently across compositors.
pub fn capture_global_region(requested: Rect, cursor: bool) -> Result<CapturedImage, String> {
    let outputs = list_outputs()?;
    let mut captured = Vec::new();
    for output in outputs.iter() {
        let Some(bounds) = output_logical_bounds(output) else {
            continue;
        };
        if !bounds_intersect(&requested, &bounds) {
            continue;
        }
        let name = output.name.clone();
        let mut image = capture_output(Some(&name), cursor)?;
        // The screencopy frame is authoritative for physical dimensions. A
        // compositor can report metadata that differs from the actual frame.
        if let Some(logical_width) = output_logical_width(output) {
            image.scale = normalize_scale(image.width as f64 / logical_width);
        }
        captured.push(CapturedOutput { name, image });
    }
    crop_frozen_global_region(&captured, &outputs, requested)
}

/// Whether an output-local region lies entirely within the output.
pub fn region_fits_output(output: &OutputInfo, local: &Rect) -> bool {
    let scale = normalize_scale(output.scale);
    let logical_width = (output.width as f64 / scale).round() as i32;
    let logical_height = (output.height as f64 / scale).round() as i32;
    local.x >= 0
        && local.y >= 0
        && local.x.saturating_add(local.width as i32) <= logical_width
        && local.y.saturating_add(local.height as i32) <= logical_height
}

/// The output's bounds in the compositor's global logical coordinates.
fn output_logical_bounds(output: &OutputInfo) -> Option<Rect> {
    let (x, y) = output.position?;
    let scale = normalize_scale(output.scale);
    Some(Rect {
        x,
        y,
        width: output_logical_width(output)?.round() as u32,
        height: (output.height as f64 / scale).round() as u32,
    })
}

fn output_logical_width(output: &OutputInfo) -> Option<f64> {
    let scale = normalize_scale(output.scale);
    let width = output.width as f64 / scale;
    (width.is_finite() && width > 0.0).then_some(width)
}

fn bounds_intersect(a: &Rect, b: &Rect) -> bool {
    a.x < b.x + b.width as i32
        && b.x < a.x + a.width as i32
        && a.y < b.y + b.height as i32
        && b.y < a.y + a.height as i32
}

/// Crops a global-logical region from per-output captures, compositing across
/// outputs when the region spans more than one.
///
/// The result is scaled to the output containing the region's center; pieces
/// from outputs at a different scale are resampled into the canvas.
pub fn crop_frozen_global_region(
    captured: &[CapturedOutput],
    outputs: &[OutputInfo],
    requested: Rect,
) -> Result<CapturedImage, String> {
    #[derive(Clone, Copy)]
    struct Piece {
        output: usize,
        global: Rect,
    }

    let center_x = requested.x + requested.width as i32 / 2;
    let center_y = requested.y + requested.height as i32 / 2;
    let mut pieces: Vec<Piece> = Vec::new();
    for (idx, capture) in captured.iter().enumerate() {
        let Some(bounds) = outputs
            .iter()
            .find(|output| output.name == capture.name)
            .and_then(output_logical_bounds)
        else {
            continue;
        };
        let x0 = requested.x.max(bounds.x);
        let y0 = requested.y.max(bounds.y);
        let x1 = (requested.x + requested.width as i32).min(bounds.x + bounds.width as i32);
        let y1 = (requested.y + requested.height as i32).min(bounds.y + bounds.height as i32);
        if x1 <= x0 || y1 <= y0 {
            continue;
        }
        pieces.push(Piece {
            output: idx,
            global: Rect {
                x: x0,
                y: y0,
                width: (x1 - x0) as u32,
                height: (y1 - y0) as u32,
            },
        });
    }

    let Some(&Piece {
        output: primary, ..
    }) = pieces
        .iter()
        .find(|piece| {
            center_x >= piece.global.x
                && center_y >= piece.global.y
                && center_x < piece.global.x + piece.global.width as i32
                && center_y < piece.global.y + piece.global.height as i32
        })
        .or_else(|| pieces.first())
    else {
        return Err("region does not intersect a Wayland output".to_string());
    };
    let scale = normalize_scale(captured[primary].image.scale);

    let width = (requested.width as f64 * scale).round().max(1.0) as u32;
    let height = (requested.height as f64 * scale).round().max(1.0) as u32;
    let mut canvas = image::RgbaImage::from_pixel(width, height, image::Rgba([0, 0, 0, 255]));

    for Piece { output, global } in pieces {
        let capture = &captured[output];
        let Some(info) = outputs.iter().find(|output| output.name == capture.name) else {
            continue;
        };
        let (output_x, output_y) = info
            .position
            .ok_or_else(|| format!("output has no position: {}", info.name))?;
        let out_scale = normalize_scale(capture.image.scale);
        let x = ((global.x - output_x) as f64 * out_scale).round() as u32;
        let y = ((global.y - output_y) as f64 * out_scale).round() as u32;
        let x = x.min(capture.image.width.saturating_sub(1));
        let y = y.min(capture.image.height.saturating_sub(1));
        let w = ((global.width as f64 * out_scale).round() as u32)
            .min(capture.image.width.saturating_sub(x));
        let h = ((global.height as f64 * out_scale).round() as u32)
            .min(capture.image.height.saturating_sub(y));
        if w == 0 || h == 0 {
            continue;
        }
        let cropped = image::imageops::crop_imm(&capture.image.image, x, y, w, h).to_image();
        let target_w = (global.width as f64 * scale).round().max(1.0) as u32;
        let target_h = (global.height as f64 * scale).round().max(1.0) as u32;
        let piece_image = if (cropped.width(), cropped.height()) == (target_w, target_h) {
            cropped
        } else {
            image::imageops::resize(
                &cropped,
                target_w,
                target_h,
                image::imageops::FilterType::Triangle,
            )
        };
        let dx = ((global.x - requested.x) as f64 * scale).round() as u32;
        let dy = ((global.y - requested.y) as f64 * scale).round() as u32;
        image::imageops::overlay(&mut canvas, &piece_image, dx as i64, dy as i64);
    }

    Ok(CapturedImage {
        width,
        height,
        image: canvas,
        scale,
        origin_x: 0,
        origin_y: 0,
    })
}

pub fn crop_captured_local_region_with_scale(
    image: CapturedImage,
    requested: Rect,
    scale: f64,
) -> Result<CapturedImage, String> {
    crop_captured_region_with_scale(image, requested, normalize_scale(scale))
}

fn crop_captured_region_with_scale(
    image: CapturedImage,
    requested: Rect,
    scale: f64,
) -> Result<CapturedImage, String> {
    let requested_x = requested.x as f64 * scale - image.origin_x as f64;
    let requested_y = requested.y as f64 * scale - image.origin_y as f64;
    let requested_right =
        (requested.x + requested.width as i32) as f64 * scale - image.origin_x as f64;
    let requested_bottom =
        (requested.y + requested.height as i32) as f64 * scale - image.origin_y as f64;
    let x = requested_x.round().max(0.0) as u32;
    let y = requested_y.round().max(0.0) as u32;
    let right = requested_right.round().min(image.width as f64) as u32;
    let bottom = requested_bottom.round().min(image.height as f64) as u32;
    if x >= right || y >= bottom || x >= image.width || y >= image.height {
        return Err("region is outside the frozen capture".to_string());
    }
    let width = right - x;
    let height = bottom - y;
    let cropped = image::imageops::crop_imm(&image.image, x, y, width, height).to_image();
    Ok(CapturedImage {
        width,
        height,
        image: cropped,
        scale,
        origin_x: 0,
        origin_y: 0,
    })
}

fn focused_output_name() -> Option<String> {
    if std::env::var_os("NIRI_SOCKET").is_some()
        && let Some(name) = focused_from_json_command("niri", &["msg", "-j", "workspaces"])
    {
        return Some(name);
    }
    if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some()
        && let Some(name) = focused_from_json_command("hyprctl", &["-j", "monitors"])
    {
        return Some(name);
    }
    if std::env::var_os("SWAYSOCK").is_some() {
        return focused_from_json_command("swaymsg", &["-t", "get_workspaces"]);
    }
    None
}

fn focused_from_json_command(program: &str, args: &[&str]) -> Option<String> {
    let output = Command::new(program).args(args).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).ok()?;
    for entry in value.as_array()? {
        let focused = entry
            .get("is_focused")
            .or_else(|| entry.get("focused"))
            .and_then(serde_json::Value::as_bool)
            .unwrap_or(false);
        if !focused {
            continue;
        }
        if let Some(name) = entry.get("output").and_then(serde_json::Value::as_str) {
            return Some(name.to_string());
        }
        if let Some(name) = entry.get("name").and_then(serde_json::Value::as_str) {
            return Some(name.to_string());
        }
    }
    None
}

impl Dispatch<wl_registry::WlRegistry, ()> for CaptureState {
    fn event(
        state: &mut Self,
        registry: &wl_registry::WlRegistry,
        event: wl_registry::Event,
        _: &(),
        _: &Connection,
        queue_handle: &QueueHandle<Self>,
    ) {
        if let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            match interface.as_str() {
                "wl_output" => {
                    let index = state.next_output;
                    state.next_output += 1;
                    let proxy = registry.bind::<wl_output::WlOutput, _, _>(
                        name,
                        version.min(4),
                        queue_handle,
                        index,
                    );
                    state.outputs.insert(
                        index,
                        CaptureOutputState {
                            proxy,
                            info: OutputState::default(),
                        },
                    );
                }
                "wl_shm" => {
                    state.shm = Some(registry.bind::<wl_shm::WlShm, _, _>(
                        name,
                        version.min(1),
                        queue_handle,
                        (),
                    ));
                }
                "zwlr_screencopy_manager_v1" => {
                    state.manager = Some(
                        registry.bind::<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1, _, _>(
                            name,
                            version.min(3),
                            queue_handle,
                            (),
                        ),
                    );
                }
                _ => {}
            }
        }
    }
}

impl Dispatch<wl_output::WlOutput, usize> for CaptureState {
    fn event(
        state: &mut Self,
        _: &wl_output::WlOutput,
        event: wl_output::Event,
        index: &usize,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(index) else {
            return;
        };
        match event {
            wl_output::Event::Geometry { x, y, .. } => {
                output.info.x = x;
                output.info.y = y;
            }
            wl_output::Event::Mode {
                width,
                height,
                flags,
                ..
            } => {
                let is_current = match flags {
                    WEnum::Value(wl_output::Mode::Current) => true,
                    WEnum::Unknown(value) => value & 1 != 0,
                    _ => false,
                };
                if is_current || output.info.width == 0 {
                    output.info.width = width;
                    output.info.height = height;
                }
            }
            wl_output::Event::Scale { factor } => output.info.scale = factor as f64,
            wl_output::Event::Name { name } => output.info.name = name,
            _ => {}
        }
    }
}

impl Dispatch<wl_shm::WlShm, ()> for CaptureState {
    fn event(
        _: &mut Self,
        _: &wl_shm::WlShm,
        _: wl_shm::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1, ()> for CaptureState {
    fn event(
        _: &mut Self,
        _: &zwlr_screencopy_manager_v1::ZwlrScreencopyManagerV1,
        _: zwlr_screencopy_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<zwlr_screencopy_frame_v1::ZwlrScreencopyFrameV1, ()> for CaptureState {
    fn event(
        state: &mut Self,
        frame: &zwlr_screencopy_frame_v1::ZwlrScreencopyFrameV1,
        event: zwlr_screencopy_frame_v1::Event,
        _: &(),
        _: &Connection,
        queue_handle: &QueueHandle<Self>,
    ) {
        match event {
            zwlr_screencopy_frame_v1::Event::Buffer {
                format,
                width,
                height,
                stride,
            } => {
                let format = match format {
                    WEnum::Value(format) => format,
                    WEnum::Unknown(value) => {
                        state.error = Some(format!("unsupported wl_shm format: {value}"));
                        return;
                    }
                };
                let size = stride as u64 * height as u64;
                let Ok(file) = tempfile() else {
                    state.error = Some("create screencopy SHM file".to_string());
                    return;
                };
                if file.set_len(size).is_err() {
                    state.error = Some("resize screencopy SHM file".to_string());
                    return;
                }
                let Ok(mmap) = (unsafe { MmapMut::map_mut(&file) }) else {
                    state.error = Some("map screencopy SHM file".to_string());
                    return;
                };
                let Some(shm) = state.shm.as_ref() else {
                    state.error = Some("wl_shm unavailable".to_string());
                    return;
                };
                let pool = shm.create_pool(file.as_fd(), size as i32, queue_handle, ());
                let buffer = pool.create_buffer(
                    0,
                    width as i32,
                    height as i32,
                    stride as i32,
                    format,
                    queue_handle,
                    (),
                );
                state.width = width;
                state.height = height;
                state.stride = stride;
                state.format = Some(format);
                state.file = Some(file);
                state.mmap = Some(mmap);
                state.pool = Some(pool);
                state.buffer = Some(buffer);
            }
            zwlr_screencopy_frame_v1::Event::BufferDone => {
                if let Some(buffer) = state.buffer.as_ref() {
                    frame.copy(buffer);
                } else {
                    state.error = Some("screencopy did not provide a usable buffer".to_string());
                }
            }
            zwlr_screencopy_frame_v1::Event::Ready { .. } => {
                state.ready = true;
                frame.destroy();
            }
            zwlr_screencopy_frame_v1::Event::Failed => {
                state.error = Some("compositor failed to capture the output".to_string());
                frame.destroy();
            }
            _ => {}
        }
    }
}

delegate_noop!(CaptureState: ignore wl_output::WlOutput);
delegate_noop!(CaptureState: ignore wl_shm_pool::WlShmPool);
delegate_noop!(CaptureState: ignore wl_buffer::WlBuffer);
