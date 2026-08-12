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
use wayland_protocols_wlr::screencopy::v1::client::{
    zwlr_screencopy_frame_v1, zwlr_screencopy_manager_v1,
};

use crate::contract::OutputInfo;
use crate::selection::{Rect, clamp};

#[derive(Default)]
struct OutputState {
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
    };
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("discover Wayland outputs: {error}"))?;
    event_queue
        .roundtrip(&mut state)
        .map_err(|error| format!("read Wayland output metadata: {error}"))?;

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
            scale: output.scale.max(1.0),
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
        if let wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            if interface == "wl_output" {
                let index = state.next_output;
                state.next_output += 1;
                state.outputs.insert(index, OutputState::default());
                registry.bind::<wl_output::WlOutput, _, _>(
                    name,
                    version.min(4),
                    queue_handle,
                    index,
                );
            }
        }
    }
}

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
    let selected = state
        .outputs
        .iter()
        .filter(|(_, output)| {
            name.map(|wanted| output.info.name == wanted)
                .or_else(|| {
                    focused_name
                        .as_deref()
                        .map(|wanted| output.info.name == wanted)
                })
                .unwrap_or(true)
        })
        .min_by_key(|(_, output)| output.info.name.clone());
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
        clamp(
            region,
            output_bounds.unwrap_or(Rect {
                x: 0,
                y: 0,
                width: u32::MAX,
                height: u32::MAX,
            }),
        )
    });
    if let Some(region) = region {
        let logical_x = if region_is_logical {
            region.x
        } else {
            (region.x as f64 / output_scale).round() as i32
        };
        let logical_y = if region_is_logical {
            region.y
        } else {
            (region.y as f64 / output_scale).round() as i32
        };
        let logical_width = if region_is_logical {
            region.width as i32
        } else {
            (region.width as f64 / output_scale).round().max(1.0) as i32
        };
        let logical_height = if region_is_logical {
            region.height as i32
        } else {
            (region.height as f64 / output_scale).round().max(1.0) as i32
        };
        state.frame = Some(manager.capture_output_region(
            i32::from(cursor),
            &output,
            logical_x,
            logical_y,
            logical_width,
            logical_height,
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
    })
}

pub fn capture_all(cursor: bool) -> Result<CapturedImage, String> {
    let outputs = list_outputs()?;
    if outputs.is_empty() {
        return Err("Wayland compositor exposed no outputs".to_string());
    }

    let mut captures = Vec::with_capacity(outputs.len());
    let mut min_x = i64::MAX;
    let mut min_y = i64::MAX;
    let mut max_x = i64::MIN;
    let mut max_y = i64::MIN;
    let mut composite_scale: f64 = 1.0;

    for output in outputs {
        let name = output.name.clone();
        let position = output
            .position
            .ok_or_else(|| format!("output has no position: {name}"))?;
        let image = capture_output(Some(&name), cursor)?;
        let x = (position.0 as f64 * image.scale).round() as i64;
        let y = (position.1 as f64 * image.scale).round() as i64;
        min_x = min_x.min(x);
        min_y = min_y.min(y);
        max_x = max_x.max(x + image.width as i64);
        max_y = max_y.max(y + image.height as i64);
        composite_scale = composite_scale.max(image.scale);
        captures.push((image.image, x, y));
    }

    let width = u32::try_from(max_x - min_x)
        .map_err(|_| "combined output width is out of range".to_string())?;
    let height = u32::try_from(max_y - min_y)
        .map_err(|_| "combined output height is out of range".to_string())?;
    let mut image = image::RgbaImage::from_pixel(width, height, image::Rgba([0, 0, 0, 255]));
    for (capture, x, y) in captures {
        image::imageops::overlay(&mut image, &capture, x - min_x, y - min_y);
    }

    Ok(CapturedImage {
        width,
        height,
        image,
        scale: composite_scale,
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
/// while `zwlr_screencopy` receives coordinates relative to one output.
pub fn capture_global_region(requested: Rect, cursor: bool) -> Result<CapturedImage, String> {
    let (output_name, local) = resolve_global_region(requested)?;
    capture_output_region_logical(Some(&output_name), local, cursor)
}

pub fn resolve_global_region(requested: Rect) -> Result<(String, Rect), String> {
    let outputs = list_outputs()?;
    let center_x = requested.x + requested.width as i32 / 2;
    let center_y = requested.y + requested.height as i32 / 2;
    let output = outputs
        .iter()
        .find(|output| {
            let Some((x, y)) = output.position else {
                return false;
            };
            let scale = output.scale.max(1.0);
            let width = (output.width as f64 / scale).round() as i32;
            let height = (output.height as f64 / scale).round() as i32;
            center_x >= x && center_y >= y && center_x < x + width && center_y < y + height
        })
        .ok_or_else(|| "region does not intersect a Wayland output".to_string())?;
    let (output_x, output_y) = output
        .position
        .ok_or_else(|| format!("output has no position: {}", output.name))?;
    Ok((
        output.name.clone(),
        Rect {
            x: requested.x - output_x,
            y: requested.y - output_y,
            width: requested.width,
            height: requested.height,
        },
    ))
}

pub fn crop_captured_region(
    image: CapturedImage,
    requested: Rect,
) -> Result<CapturedImage, String> {
    let scale = image.scale.max(1.0);
    let x = (requested.x.max(0) as f64 * scale).round() as u32;
    let y = (requested.y.max(0) as f64 * scale).round() as u32;
    let width = (requested.width as f64 * scale).round().max(1.0) as u32;
    let height = (requested.height as f64 * scale).round().max(1.0) as u32;
    if x >= image.width || y >= image.height {
        return Err("region is outside the frozen capture".to_string());
    }
    let width = width.min(image.width - x);
    let height = height.min(image.height - y);
    let cropped = image::imageops::crop_imm(&image.image, x, y, width, height).to_image();
    Ok(CapturedImage {
        width,
        height,
        image: cropped,
        scale,
    })
}

fn focused_output_name() -> Option<String> {
    if std::env::var_os("NIRI_SOCKET").is_some() {
        if let Some(name) = focused_from_json_command("niri", &["msg", "-j", "workspaces"]) {
            return Some(name);
        }
    }
    if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() {
        if let Some(name) = focused_from_json_command("hyprctl", &["-j", "monitors"]) {
            return Some(name);
        }
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
