use std::ffi::CString;
use std::os::fd::{AsFd, AsRawFd};
use std::os::raw::{c_char, c_double, c_int};
use std::slice;
use std::time::{Duration, Instant};

use memmap2::{MmapMut, MmapOptions};
use tempfile::tempfile;
use wayland_client::protocol::wl_buffer::WlBuffer;
use wayland_client::protocol::wl_callback::WlCallback;
use wayland_client::protocol::wl_compositor::WlCompositor;
use wayland_client::protocol::wl_keyboard::{KeyState as WlKeyState, WlKeyboard};
use wayland_client::protocol::wl_output::{Mode as WlOutputMode, WlOutput};
use wayland_client::protocol::wl_pointer::{ButtonState as WlButtonState, WlPointer};
use wayland_client::protocol::wl_region::WlRegion;
use wayland_client::protocol::wl_registry::WlRegistry;
use wayland_client::protocol::wl_seat::{Capability as WlSeatCapability, WlSeat};
use wayland_client::protocol::wl_shm::Format as WlShmFormat;
use wayland_client::protocol::wl_shm::WlShm;
use wayland_client::protocol::wl_shm_pool::WlShmPool;
use wayland_client::protocol::wl_surface::WlSurface;
use wayland_client::protocol::wl_touch::WlTouch;
use wayland_client::{Connection, Dispatch, EventQueue, QueueHandle, WEnum, delegate_noop};
use wayland_protocols::wp::cursor_shape::v1::client::wp_cursor_shape_device_v1::{
    Shape as CursorShape, WpCursorShapeDeviceV1,
};
use wayland_protocols::wp::cursor_shape::v1::client::wp_cursor_shape_manager_v1::WpCursorShapeManagerV1;
use wayland_protocols::wp::viewporter::client::wp_viewport::WpViewport;
use wayland_protocols::wp::viewporter::client::wp_viewporter::WpViewporter;
use wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_manager_v1::ZxdgOutputManagerV1;
use wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_v1::ZxdgOutputV1;
use wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_shell_v1::{
    Layer, ZwlrLayerShellV1,
};
use wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_surface_v1::{
    Anchor, KeyboardInteractivity, ZwlrLayerSurfaceV1,
};

use super::config::Config;
use super::selection_box::SelectionBox;
use super::types::{BackgroundImage, BackgroundImages};
use crate::scroll_session::{ScrollCaptureSession, SessionEvent};
use crate::selection::Rect as CaptureRect;
use crate::wayland::CapturedImage;

// Keep the selector border out of the frames used by the scroll stitcher.
const SCROLL_CAPTURE_INSET: u32 = 2;

#[link(name = "cairo")]
unsafe extern "C" {
    fn cairo_image_surface_create_for_data(
        data: *mut u8,
        format: c_int,
        width: c_int,
        height: c_int,
        stride: c_int,
    ) -> *mut CairoSurface;
    fn cairo_surface_destroy(surface: *mut CairoSurface);
    fn cairo_surface_mark_dirty(surface: *mut CairoSurface);
    fn cairo_create(surface: *mut CairoSurface) -> *mut CairoContext;
    fn cairo_destroy(cr: *mut CairoContext);
    fn cairo_set_operator(cr: *mut CairoContext, op: c_int);
    fn cairo_set_source_rgba(
        cr: *mut CairoContext,
        red: c_double,
        green: c_double,
        blue: c_double,
        alpha: c_double,
    );
    fn cairo_select_font_face(
        cr: *mut CairoContext,
        family: *const c_char,
        slant: c_int,
        weight: c_int,
    );
    fn cairo_set_font_size(cr: *mut CairoContext, size: c_double);
    fn cairo_move_to(cr: *mut CairoContext, x: c_double, y: c_double);
    fn cairo_show_text(cr: *mut CairoContext, utf8: *const c_char);
    fn cairo_set_antialias(cr: *mut CairoContext, antialias: c_int);
    fn cairo_rectangle(
        cr: *mut CairoContext,
        x: c_double,
        y: c_double,
        width: c_double,
        height: c_double,
    );
    fn cairo_arc(
        cr: *mut CairoContext,
        xc: c_double,
        yc: c_double,
        radius: c_double,
        angle1: c_double,
        angle2: c_double,
    );
    fn cairo_close_path(cr: *mut CairoContext);
    fn cairo_fill(cr: *mut CairoContext);
    fn cairo_set_line_width(cr: *mut CairoContext, width: c_double);
    fn cairo_stroke(cr: *mut CairoContext);
    fn cairo_identity_matrix(cr: *mut CairoContext);
    fn cairo_scale(cr: *mut CairoContext, sx: c_double, sy: c_double);
    fn cairo_translate(cr: *mut CairoContext, tx: c_double, ty: c_double);
    fn cairo_paint(cr: *mut CairoContext);
}

#[link(name = "Xcursor")]
unsafe extern "C" {
    fn XcursorLibraryLoadImage(
        library: *const c_char,
        theme: *const c_char,
        size: c_int,
    ) -> *mut XcursorImage;
    fn XcursorImageDestroy(image: *mut XcursorImage);
}

#[repr(C)]
struct CairoSurface {
    _private: [u8; 0],
}

#[repr(C)]
struct CairoContext {
    _private: [u8; 0],
}

#[repr(C)]
struct XcursorImage {
    version: u32,
    size: u32,
    width: u32,
    height: u32,
    xhot: u32,
    yhot: u32,
    delay: u32,
    pixels: *mut u32,
}

const CAIRO_FORMAT_ARGB32: c_int = 0;
const CAIRO_OPERATOR_CLEAR: c_int = 0;
const CAIRO_OPERATOR_SOURCE: c_int = 1;
const CAIRO_OPERATOR_OVER: c_int = 2;
const CAIRO_FONT_SLANT_NORMAL: c_int = 0;
const CAIRO_FONT_WEIGHT_NORMAL: c_int = 0;
const CAIRO_ANTIALIAS_DEFAULT: c_int = 0;
const CAIRO_ANTIALIAS_NONE: c_int = 1;

const BTN_LEFT: u32 = 272;
const TOUCH_ID_EMPTY: i32 = -1;
const KEY_ESCAPE: u32 = 1;
const KEY_ENTER: u32 = 28;
const KEY_SPACE: u32 = 57;
const KEY_KP_ENTER: u32 = 96;
const KEY_SHIFT_LEFT: u32 = 42;
const KEY_SHIFT_RIGHT: u32 = 54;
const KEY_CTRL_LEFT: u32 = 29;
const KEY_CTRL_RIGHT: u32 = 97;
const RESIZE_HANDLE_RADIUS: i32 = 12;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct OutputKey(usize);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct SeatKey(usize);

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
struct BufferKey {
    output_idx: usize,
    buffer_idx: usize,
}

#[derive(Clone, Debug, Default)]
struct Selection {
    current_output: Option<usize>,
    x: i32,
    y: i32,
    anchor_x: i32,
    anchor_y: i32,
    selection: SelectionBox,
    has_selection: bool,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum ResizeHandle {
    TopLeft,
    TopRight,
    BottomLeft,
    BottomRight,
}

#[derive(Default)]
struct OutputEntry {
    wl_output: Option<WlOutput>,
    xdg_output: Option<ZxdgOutputV1>,
    geometry: SelectionBox,
    logical_geometry: SelectionBox,
    scale: i32,
    name: Option<String>,
    surface: Option<WlSurface>,
    viewport: Option<WpViewport>,
    layer_surface: Option<ZwlrLayerSurfaceV1>,
    configured: bool,
    closed: bool,
    layer_width: u32,
    layer_height: u32,
    buffers: Vec<ShmBuffer>,
    cursor_buffer: Option<CursorBuffer>,
    frame_callback: Option<WlCallback>,
    dirty: bool,
    initial_render_done: bool,
}

struct ShmBuffer {
    width: u32,
    height: u32,
    stride: usize,
    busy: bool,
    background_initialized: bool,
    rendered_selection: Option<SelectionBox>,
    mmap: MmapMut,
    _file: std::fs::File,
    buffer: WlBuffer,
    surface: *mut CairoSurface,
    cairo: *mut CairoContext,
}

impl Drop for ShmBuffer {
    fn drop(&mut self) {
        unsafe {
            if !self.cairo.is_null() {
                cairo_destroy(self.cairo);
            }
            if !self.surface.is_null() {
                cairo_surface_destroy(self.surface);
            }
        }
    }
}

struct CursorBuffer {
    scale: i32,
    width: u32,
    height: u32,
    stride: usize,
    hotspot_x: i32,
    hotspot_y: i32,
    mmap: MmapMut,
    _file: std::fs::File,
    buffer: WlBuffer,
}

struct SeatEntry {
    _wl_seat: Option<WlSeat>,
    wl_pointer: Option<WlPointer>,
    wl_keyboard: Option<WlKeyboard>,
    wl_touch: Option<WlTouch>,
    cursor_surface: Option<WlSurface>,
    pointer_selection: Selection,
    touch_selection: Selection,
    button_state: WlButtonState,
    touch_id: i32,
    cursor_serial: u32,
    cursor_over_scroll_preview: Option<bool>,
    cursor_over_resize_handle: Option<ResizeHandle>,
    ctrl_pressed: bool,
    moving_selection: bool,
    move_offset_x: i32,
    move_offset_y: i32,
    resizing_handle: Option<ResizeHandle>,
}

impl Default for SeatEntry {
    fn default() -> Self {
        Self {
            _wl_seat: None,
            wl_pointer: None,
            wl_keyboard: None,
            wl_touch: None,
            cursor_surface: None,
            pointer_selection: Selection::default(),
            touch_selection: Selection::default(),
            button_state: WlButtonState::Released,
            touch_id: TOUCH_ID_EMPTY,
            cursor_serial: 0,
            cursor_over_scroll_preview: None,
            cursor_over_resize_handle: None,
            ctrl_pressed: false,
            moving_selection: false,
            move_offset_x: 0,
            move_offset_y: 0,
            resizing_handle: None,
        }
    }
}

#[derive(Default)]
struct SelectorState {
    compositor: Option<WlCompositor>,
    shm: Option<WlShm>,
    layer_shell: Option<ZwlrLayerShellV1>,
    xdg_output_manager: Option<ZxdgOutputManagerV1>,
    cursor_shape_manager: Option<WpCursorShapeManagerV1>,
    viewporter: Option<WpViewporter>,
    outputs: Vec<OutputEntry>,
    seats: Vec<SeatEntry>,

    config: Config,
    running: bool,
    repaint_pending: bool,
    pending_outputs: Vec<bool>,
    resizing_selection: bool,
    result: Option<SelectionBox>,
    result_output_name: Option<String>,
    cancelled: bool,
    cursor_size: i32,
    cursor_theme: Option<String>,
    background: Option<BackgroundImages>,
    scroll_active: bool,
    scroll_rect: Option<CaptureRect>,
    scroll_capture_rect: Option<CaptureRect>,
    scroll_session: Option<ScrollCaptureSession>,
    scroll_next_capture: Option<Instant>,
    scroll_captured: Option<CapturedImage>,
    scroll_width: u32,
    scroll_scale: f64,
}

delegate_noop!(SelectorState: ignore WlRegion);
delegate_noop!(SelectorState: ignore WpViewport);
delegate_noop!(SelectorState: ignore WpViewporter);

pub struct RunResult {
    pub result: SelectionBox,
    pub output_name: Option<String>,
    pub captured: Option<CapturedImage>,
}

pub(crate) fn run(
    config: &Config,
    background: Option<BackgroundImages>,
) -> Result<RunResult, String> {
    let conn = Connection::connect_to_env().map_err(|_| "failed to create display".to_string())?;
    let mut event_queue: EventQueue<SelectorState> = conn.new_event_queue();
    let qh = event_queue.handle();

    let display = conn.display();
    let _registry = display.get_registry(&qh, ());

    let mut state = SelectorState {
        config: config.clone(),
        running: false,
        cursor_size: 24,
        cursor_theme: None,
        background,
        ..SelectorState::default()
    };

    event_queue
        .roundtrip(&mut state)
        .map_err(|_| "failed to create display".to_string())?;

    validate_globals(&state)?;
    populate_xdg_outputs(&mut state, &mut event_queue, &qh)?;
    validate_backgrounds(&state)?;
    apply_initial_selection(&mut state);
    if state.cursor_shape_manager.is_none() {
        state.cursor_size = cursor_size_from_env()?;
        state.cursor_theme = std::env::var("XCURSOR_THEME")
            .ok()
            .filter(|s| !s.is_empty());
    }

    setup_layer_surfaces(&mut state, &qh)?;
    event_queue
        .roundtrip(&mut state)
        .map_err(|_| "failed to create display".to_string())?;
    setup_cursor_surfaces(&mut state, &qh)?;
    request_render_all(&mut state, &qh);
    let _ = conn.flush();

    state.running = true;
    while state.running {
        if state.scroll_active {
            scroll_tick(&mut state, &qh);
            if state.repaint_pending {
                request_render_pending(&mut state, &qh);
                state.repaint_pending = false;
                let _ = conn.flush();
            }
            let mut poll_fd = libc::pollfd {
                fd: conn.as_fd().as_raw_fd(),
                events: libc::POLLIN,
                revents: 0,
            };
            let poll_result = unsafe { libc::poll(&mut poll_fd, 1, 5) };
            if poll_result < 0
                && std::io::Error::last_os_error().kind() != std::io::ErrorKind::Interrupted
            {
                teardown_state(&mut state, &conn);
                return Err("failed to poll Wayland events".to_string());
            }
            if poll_result == 0 {
                continue;
            }
        }

        if event_queue.blocking_dispatch(&mut state).is_err() {
            teardown_state(&mut state, &conn);
            return Err("failed to create display".to_string());
        }
        if state.repaint_pending {
            request_render_pending(&mut state, &qh);
            state.repaint_pending = false;
            let _ = conn.flush();
        }
    }

    teardown_state(&mut state, &conn);

    if state.cancelled || state.result.is_none() {
        return Err("selection cancelled".to_string());
    }

    Ok(RunResult {
        result: state.result.expect("checked above"),
        output_name: state.result_output_name,
        captured: state.scroll_captured,
    })
}

fn validate_backgrounds(state: &SelectorState) -> Result<(), String> {
    let Some(backgrounds) = state.background.as_ref() else {
        return Ok(());
    };
    if state.config.scroll {
        return Ok(());
    }
    for output in &state.outputs {
        let name = output
            .name
            .as_deref()
            .ok_or_else(|| "selector output has no stable name".to_string())?;
        let background = backgrounds
            .get(name)
            .ok_or_else(|| format!("missing frozen capture for output {name}"))?;
        if background.width == 0 || background.height == 0 {
            return Err(format!("frozen capture for output {name} is empty"));
        }
    }
    Ok(())
}

fn scroll_tick(state: &mut SelectorState, qh: &QueueHandle<SelectorState>) {
    if !state.scroll_active {
        return;
    }
    let now = Instant::now();
    if state.scroll_next_capture.is_some_and(|next| next > now) {
        return;
    }
    let Some(rect) = state.scroll_capture_rect else {
        state.cancelled = true;
        state.running = false;
        return;
    };

    let interval = Duration::from_millis(state.config.scroll_interval_ms.max(1));
    let image = match crate::wayland::capture_global_region(rect, state.config.capture_cursor) {
        Ok(image) => image,
        Err(_) => {
            state.scroll_next_capture = Some(now + interval);
            return;
        }
    };
    if state.scroll_session.is_none() {
        let mut session = ScrollCaptureSession::new(
            image.width as usize,
            Duration::from_millis(state.config.scroll_interval_ms.max(1)),
            256 << 20,
            30_000,
        );
        let _ = session.start(now);
        state.scroll_session = Some(session);
    }
    if let Some(session) = state.scroll_session.as_mut() {
        let _ = session.begin_capture(now);
        let event = session.frame_ready(image.image.as_raw(), image.height as usize, now);
        if matches!(event, SessionEvent::FrameAccepted(_)) {
            state.scroll_width = image.width;
            state.scroll_scale = image.scale;
            state.pending_outputs.resize(state.outputs.len(), false);
            state.pending_outputs.fill(true);
            update_scroll_preview_input_regions(state, qh);
            state.repaint_pending = true;
        }
    }
    state.scroll_next_capture = Some(now + interval);
}

fn inset_scroll_capture_rect(rect: CaptureRect) -> CaptureRect {
    let horizontal = SCROLL_CAPTURE_INSET.min(rect.width.saturating_sub(1) / 2);
    let vertical = SCROLL_CAPTURE_INSET.min(rect.height.saturating_sub(1) / 2);
    CaptureRect {
        x: rect.x.saturating_add(horizontal as i32),
        y: rect.y.saturating_add(vertical as i32),
        width: rect.width.saturating_sub(horizontal * 2),
        height: rect.height.saturating_sub(vertical * 2),
    }
}

fn finish_scroll(state: &mut SelectorState) {
    let Some(session) = state.scroll_session.as_mut() else {
        state.cancelled = true;
        state.result = None;
        state.running = false;
        return;
    };
    if session.finish() == SessionEvent::Completed && state.scroll_width > 0 {
        let width = state.scroll_width;
        let height = session.rows() as u32;
        if let Some(image) = image::RgbaImage::from_raw(width, height, session.canvas().to_vec()) {
            state.scroll_captured = Some(CapturedImage {
                width,
                height,
                image,
                scale: crate::wayland::normalize_scale(state.scroll_scale),
                origin_x: 0,
                origin_y: 0,
            });
            state.running = false;
            return;
        }
    }
    state.cancelled = true;
    state.result = None;
    state.running = false;
}

fn cancel_scroll(state: &mut SelectorState) {
    if let Some(session) = state.scroll_session.as_mut() {
        let _ = session.cancel();
    }
    state.scroll_active = false;
    state.scroll_captured = None;
    state.result = None;
    state.cancelled = true;
    state.running = false;
}

fn enter_scroll_phase(
    state: &mut SelectorState,
    selection: SelectionBox,
    output_idx: Option<usize>,
    qh: &QueueHandle<SelectorState>,
) {
    state.result = Some(selection.clone());
    state.result_output_name = output_idx
        .and_then(|index| state.outputs.get(index))
        .and_then(|output| output.name.clone());
    state.scroll_rect = Some(CaptureRect {
        x: selection.x,
        y: selection.y,
        width: selection.width.max(1) as u32,
        height: selection.height.max(1) as u32,
    });
    state.scroll_capture_rect = state.scroll_rect.map(inset_scroll_capture_rect);
    state.scroll_active = true;
    // Let the newly committed scroll overlay reach the compositor before the
    // first frame is captured.
    state.scroll_next_capture = Some(Instant::now() + Duration::from_millis(16));
    for output in &state.outputs {
        if let (Some(surface), Some(compositor)) =
            (output.surface.as_ref(), state.compositor.as_ref())
        {
            let region: WlRegion = compositor.create_region(qh, ());
            surface.set_input_region(Some(&region));
            region.destroy();
        }
    }
}

fn update_scroll_preview_input_regions(state: &mut SelectorState, qh: &QueueHandle<SelectorState>) {
    let Some(selection) = state.scroll_capture_rect.as_ref() else {
        return;
    };
    let Some(session) = state.scroll_session.as_ref() else {
        return;
    };
    let Some(compositor) = state.compositor.as_ref().cloned() else {
        return;
    };
    for output in &state.outputs {
        let Some(surface) = output.surface.as_ref() else {
            continue;
        };
        let region: WlRegion = compositor.create_region(qh, ());
        if let Some(panel) = scroll_preview_panel(
            &output.logical_geometry,
            selection,
            state.scroll_width,
            session.rows(),
        ) {
            region.add(
                panel.x - output.logical_geometry.x,
                panel.y - output.logical_geometry.y,
                panel.width,
                panel.height,
            );
        }
        surface.set_input_region(Some(&region));
        region.destroy();
    }
}

fn teardown_state(state: &mut SelectorState, conn: &Connection) {
    for output in &mut state.outputs {
        for buf in output.buffers.drain(..) {
            buf.buffer.destroy();
        }
        if let Some(cursor) = output.cursor_buffer.take() {
            cursor.buffer.destroy();
        }
        if let Some(layer) = output.layer_surface.take() {
            layer.destroy();
        }
        if let Some(viewport) = output.viewport.take() {
            viewport.destroy();
        }
        if let Some(xdg) = output.xdg_output.take() {
            xdg.destroy();
        }
        if let Some(surface) = output.surface.take() {
            surface.destroy();
        }
        if let Some(wl_output) = output.wl_output.take() {
            wl_output.release();
        }
    }

    for seat in &mut state.seats {
        let _ = seat.wl_pointer.take();
        let _ = seat.wl_keyboard.take();
        let _ = seat.wl_touch.take();
        if let Some(surface) = seat.cursor_surface.take() {
            surface.destroy();
        }
        let _ = seat._wl_seat.take();
    }

    if let Some(manager) = state.cursor_shape_manager.take() {
        manager.destroy();
    }
    if let Some(manager) = state.viewporter.take() {
        manager.destroy();
    }
    if let Some(xdg_mgr) = state.xdg_output_manager.take() {
        xdg_mgr.destroy();
    }
    if let Some(layer_shell) = state.layer_shell.take() {
        layer_shell.destroy();
    }
    let _ = state.shm.take();
    let _ = state.compositor.take();

    let _ = conn.flush();
}

fn validate_globals(state: &SelectorState) -> Result<(), String> {
    if state.compositor.is_none() {
        return Err("compositor doesn't support wl_compositor".to_string());
    }
    if state.shm.is_none() {
        return Err("compositor doesn't support wl_shm".to_string());
    }
    if state.layer_shell.is_none() {
        return Err("compositor doesn't support zwlr_layer_shell_v1".to_string());
    }
    if state.outputs.is_empty() {
        return Err("no wl_output".to_string());
    }
    Ok(())
}

fn populate_xdg_outputs(
    state: &mut SelectorState,
    event_queue: &mut EventQueue<SelectorState>,
    qh: &QueueHandle<SelectorState>,
) -> Result<(), String> {
    if state.xdg_output_manager.is_none() {
        eprintln!(
            "compositor doesn't support xdg-output. Guessing geometry from physical output size."
        );
        for output in &mut state.outputs {
            output.logical_geometry = output.geometry.clone();
            if output.scale > 1 {
                output.logical_geometry.width /= output.scale;
                output.logical_geometry.height /= output.scale;
            }
        }
        return Ok(());
    }

    let manager = state
        .xdg_output_manager
        .as_ref()
        .expect("checked above")
        .clone();
    for (idx, output) in state.outputs.iter_mut().enumerate() {
        let Some(wl_output) = output.wl_output.as_ref() else {
            continue;
        };
        let xdg_output = manager.get_xdg_output(wl_output, qh, OutputKey(idx));
        output.xdg_output = Some(xdg_output);
    }

    event_queue
        .roundtrip(state)
        .map_err(|_| "failed to create display".to_string())?;
    Ok(())
}

fn cursor_size_from_env() -> Result<i32, String> {
    let Ok(value) = std::env::var("XCURSOR_SIZE") else {
        return Ok(24);
    };
    parse_cursor_size(&value)
}

pub(crate) fn parse_cursor_size(value: &str) -> Result<i32, String> {
    let parsed = value
        .parse::<i32>()
        .map_err(|_| "invalid XCURSOR_SIZE value".to_string())?;
    if parsed <= 0 {
        return Err("invalid XCURSOR_SIZE value".to_string());
    }
    Ok(parsed)
}

fn setup_layer_surfaces(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
) -> Result<(), String> {
    let compositor = state
        .compositor
        .as_ref()
        .ok_or_else(|| "compositor doesn't support wl_compositor".to_string())?
        .clone();
    let layer_shell = state
        .layer_shell
        .as_ref()
        .ok_or_else(|| "compositor doesn't support zwlr_layer_shell_v1".to_string())?
        .clone();
    let viewporter = state.viewporter.as_ref().cloned();

    for (idx, output) in state.outputs.iter_mut().enumerate() {
        let Some(wl_output) = output.wl_output.as_ref() else {
            continue;
        };
        let surface = compositor.create_surface(qh, ());
        let layer_surface = layer_shell.get_layer_surface(
            &surface,
            Some(wl_output),
            Layer::Overlay,
            "selection".to_string(),
            qh,
            OutputKey(idx),
        );
        let viewport = viewporter
            .as_ref()
            .map(|manager| manager.get_viewport(&surface, qh, ()));
        layer_surface.set_anchor(Anchor::Top | Anchor::Bottom | Anchor::Left | Anchor::Right);
        layer_surface.set_keyboard_interactivity(KeyboardInteractivity::Exclusive);
        layer_surface.set_exclusive_zone(-1);
        surface.commit();

        // A freshly created surface has never committed a buffer, so its first
        // frame must be drawn synchronously (see request_render).
        output.initial_render_done = false;
        output.surface = Some(surface);
        output.viewport = viewport;
        output.layer_surface = Some(layer_surface);
    }

    Ok(())
}

fn setup_cursor_surfaces(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
) -> Result<(), String> {
    let compositor = state
        .compositor
        .as_ref()
        .ok_or_else(|| "compositor doesn't support wl_compositor".to_string())?
        .clone();

    for seat in &mut state.seats {
        if seat.cursor_surface.is_none() {
            seat.cursor_surface = Some(compositor.create_surface(qh, ()));
        }
    }
    Ok(())
}

fn output_from_surface(outputs: &[OutputEntry], surface: &WlSurface) -> Option<usize> {
    outputs.iter().position(|output| {
        output
            .surface
            .as_ref()
            .is_some_and(|output_surface| output_surface == surface)
    })
}

fn set_result(state: &mut SelectorState, selection: SelectionBox, output_idx: Option<usize>) {
    state.result = Some(selection);
    state.result_output_name = output_idx
        .and_then(|index| state.outputs.get(index))
        .and_then(|output| output.name.clone());
}

fn apply_initial_selection(state: &mut SelectorState) {
    let Some(rect) = state.config.initial_selection.clone() else {
        return;
    };
    let selection = SelectionBox::from_rect(&rect);
    let Some(output_idx) = state
        .outputs
        .iter()
        .position(|output| SelectionBox::intersect(&output.logical_geometry, &selection))
    else {
        return;
    };

    for seat in &mut state.seats {
        seat.pointer_selection.current_output = Some(output_idx);
        seat.pointer_selection.x = selection.x + selection.width;
        seat.pointer_selection.y = selection.y + selection.height;
        seat.pointer_selection.anchor_x = selection.x;
        seat.pointer_selection.anchor_y = selection.y;
        seat.pointer_selection.selection = selection.clone();
        seat.pointer_selection.has_selection = true;
    }
}

fn selection_from_mut(seat: &mut SeatEntry) -> &mut Selection {
    if seat.touch_selection.has_selection {
        &mut seat.touch_selection
    } else {
        &mut seat.pointer_selection
    }
}

fn move_selection(
    outputs: &[OutputEntry],
    selection: &mut Selection,
    surface_x: f64,
    surface_y: f64,
) {
    let Some(output_idx) = selection.current_output else {
        return;
    };
    let output = &outputs[output_idx];
    let x = surface_x as i32 + output.logical_geometry.x;
    let y = surface_y as i32 + output.logical_geometry.y;

    selection.x = x;
    selection.y = y;
}

fn handle_active_selection_motion(
    config: &Config,
    resizing_selection: &mut bool,
    selection: &mut Selection,
) {
    *resizing_selection = true;

    let anchor_x = selection.anchor_x;
    let anchor_y = selection.anchor_y;
    let dist_x = selection.x - anchor_x;
    let dist_y = selection.y - anchor_y;

    selection.has_selection = true;
    let mut width = dist_x.abs() + 1;
    let mut height = dist_y.abs() + 1;

    if config.aspect_ratio != 0.0 {
        width = width.max((height as f64 / config.aspect_ratio) as i32);
        height = height.max((width as f64 * config.aspect_ratio) as i32);
    }

    selection.selection.x = if dist_x > 0 {
        anchor_x
    } else {
        anchor_x - (width - 1)
    };
    selection.selection.y = if dist_y > 0 {
        anchor_y
    } else {
        anchor_y - (height - 1)
    };
    selection.selection.width = width;
    selection.selection.height = height;
}

fn translated_selection(
    selection: &SelectionBox,
    pointer_x: i32,
    pointer_y: i32,
    offset_x: i32,
    offset_y: i32,
) -> SelectionBox {
    SelectionBox {
        x: pointer_x.saturating_sub(offset_x),
        y: pointer_y.saturating_sub(offset_y),
        width: selection.width,
        height: selection.height,
        label: selection.label.clone(),
    }
}

fn clamp_selection_to_outputs(selection: &SelectionBox, outputs: &[OutputEntry]) -> SelectionBox {
    let Some((min_x, min_y, max_x, max_y)) = outputs
        .iter()
        .filter_map(|output| {
            let geometry = &output.logical_geometry;
            (geometry.width > 0 && geometry.height > 0).then_some((
                geometry.x,
                geometry.y,
                geometry.x.saturating_add(geometry.width),
                geometry.y.saturating_add(geometry.height),
            ))
        })
        .reduce(|bounds, geometry| {
            (
                bounds.0.min(geometry.0),
                bounds.1.min(geometry.1),
                bounds.2.max(geometry.2),
                bounds.3.max(geometry.3),
            )
        })
    else {
        return selection.clone();
    };

    let max_selection_x = max_x.saturating_sub(selection.width);
    let max_selection_y = max_y.saturating_sub(selection.height);
    SelectionBox {
        x: selection.x.clamp(min_x, max_selection_x.max(min_x)),
        y: selection.y.clamp(min_y, max_selection_y.max(min_y)),
        ..selection.clone()
    }
}

fn move_active_selection(
    outputs: &[OutputEntry],
    selection: &mut Selection,
    offset_x: i32,
    offset_y: i32,
) {
    let translated = translated_selection(
        &selection.selection,
        selection.x,
        selection.y,
        offset_x,
        offset_y,
    );
    selection.selection = clamp_selection_to_outputs(&translated, outputs);
}

fn resize_handle_center(selection: &SelectionBox, handle: ResizeHandle) -> (i32, i32) {
    match handle {
        ResizeHandle::TopLeft => (selection.x, selection.y),
        ResizeHandle::TopRight => (selection.x + selection.width, selection.y),
        ResizeHandle::BottomLeft => (selection.x, selection.y + selection.height),
        ResizeHandle::BottomRight => (
            selection.x + selection.width,
            selection.y + selection.height,
        ),
    }
}

fn resize_handle_at(selection: &SelectionBox, x: i32, y: i32) -> Option<ResizeHandle> {
    let radius = RESIZE_HANDLE_RADIUS + 4;
    [
        ResizeHandle::TopLeft,
        ResizeHandle::TopRight,
        ResizeHandle::BottomLeft,
        ResizeHandle::BottomRight,
    ]
    .into_iter()
    .find(|handle| {
        let (center_x, center_y) = resize_handle_center(selection, *handle);
        (x - center_x).pow(2) + (y - center_y).pow(2) <= radius.pow(2)
    })
}

fn begin_selection_resize(seat: &mut SeatEntry, handle: ResizeHandle) -> bool {
    if !seat.pointer_selection.has_selection {
        return false;
    }

    let selection = &seat.pointer_selection.selection;
    let (anchor_x, anchor_y) = match handle {
        ResizeHandle::TopLeft => (
            selection.x + selection.width,
            selection.y + selection.height,
        ),
        ResizeHandle::TopRight => (selection.x, selection.y + selection.height),
        ResizeHandle::BottomLeft => (selection.x + selection.width, selection.y),
        ResizeHandle::BottomRight => (selection.x, selection.y),
    };
    seat.pointer_selection.anchor_x = anchor_x;
    seat.pointer_selection.anchor_y = anchor_y;
    seat.resizing_handle = Some(handle);
    true
}

fn begin_selection_move(seat: &mut SeatEntry) -> bool {
    if !seat.pointer_selection.has_selection {
        return false;
    }

    seat.moving_selection = true;
    seat.move_offset_x = seat.pointer_selection.x - seat.pointer_selection.selection.x;
    seat.move_offset_y = seat.pointer_selection.y - seat.pointer_selection.selection.y;
    true
}

fn handle_selection_start(config: &Config, selection: &mut Selection) -> Option<SelectionBox> {
    if config.single_point {
        return Some(SelectionBox {
            x: selection.x,
            y: selection.y,
            width: 1,
            height: 1,
            label: None,
        });
    } else {
        selection.anchor_x = selection.x;
        selection.anchor_y = selection.y;
    }
    None
}

fn handle_selection_end(
    config: &Config,
    resizing_selection: &mut bool,
    selection: &mut Selection,
) -> Option<SelectionBox> {
    if config.single_point {
        return None;
    }

    if selection.has_selection {
        *resizing_selection = false;
        Some(selection.selection.clone())
    } else {
        *resizing_selection = false;
        Some(SelectionBox {
            x: selection.x,
            y: selection.y,
            width: 1,
            height: 1,
            label: None,
        })
    }
}

pub(crate) fn should_finish_pointer_selection(
    config: &Config,
    button_state: WlButtonState,
) -> bool {
    match button_state {
        WlButtonState::Pressed => config.single_point,
        WlButtonState::Released => true,
        _ => false,
    }
}

fn handle_selection_cancelled(state: &mut SelectorState, seat_idx: usize) {
    if let Some(seat) = state.seats.get_mut(seat_idx) {
        seat.pointer_selection.has_selection = false;
        seat.touch_selection.has_selection = false;
        seat.moving_selection = false;
        seat.move_offset_x = 0;
        seat.move_offset_y = 0;
        seat.resizing_handle = None;
    }
    state.cancelled = true;
    state.running = false;
}

fn recompute_selection(state: &mut SelectorState, seat_idx: usize) {
    let has = {
        let seat = &state.seats[seat_idx];
        if seat.touch_selection.has_selection {
            seat.touch_selection.has_selection
        } else {
            seat.pointer_selection.has_selection
        }
    };
    if !has {
        return;
    }

    let config = state.config.clone();
    let resizing = &mut state.resizing_selection;
    let seat = &mut state.seats[seat_idx];
    let current = selection_from_mut(seat);
    handle_active_selection_motion(&config, resizing, current);
}

#[derive(Clone)]
struct SeatSnapshot {
    has_selection: bool,
    selection: SelectionBox,
    x: i32,
    y: i32,
    ctrl_pressed: bool,
}

fn collect_seat_snapshots(state: &SelectorState) -> Vec<SeatSnapshot> {
    state
        .seats
        .iter()
        .map(|seat| {
            let current = if seat.touch_selection.has_selection {
                &seat.touch_selection
            } else {
                &seat.pointer_selection
            };
            SeatSnapshot {
                has_selection: current.has_selection,
                selection: current.selection.clone(),
                x: current.x,
                y: current.y,
                ctrl_pressed: seat.ctrl_pressed,
            }
        })
        .collect()
}

fn mark_outputs_for_seat(state: &mut SelectorState, seat_idx: usize) {
    let Some(seat) = state.seats.get(seat_idx) else {
        return;
    };
    if state.pending_outputs.len() < state.outputs.len() {
        state.pending_outputs.resize(state.outputs.len(), false);
    }

    let current = if seat.touch_selection.has_selection {
        &seat.touch_selection
    } else {
        &seat.pointer_selection
    };
    for (idx, output) in state.outputs.iter().enumerate() {
        let geometry = &output.logical_geometry;
        if SelectionBox::intersect(geometry, &current.selection)
            || (state.config.crosshairs && SelectionBox::contains(geometry, current.x, current.y))
        {
            state.pending_outputs[idx] = true;
        }
    }
}

fn has_pending_outputs(state: &SelectorState) -> bool {
    state.pending_outputs.iter().any(|pending| *pending)
}

fn color_rgba(color: u32) -> (u8, u8, u8, u8) {
    (
        ((color >> 24) & 0xFF) as u8,
        ((color >> 16) & 0xFF) as u8,
        ((color >> 8) & 0xFF) as u8,
        (color & 0xFF) as u8,
    )
}

fn premultiply_rgba(r: u8, g: u8, b: u8, a: u8) -> (u8, u8, u8, u8) {
    let a32 = a as u32;
    let pr = ((r as u32 * a32 + 127) / 255) as u8;
    let pg = ((g as u32 * a32 + 127) / 255) as u8;
    let pb = ((b as u32 * a32 + 127) / 255) as u8;
    (pr, pg, pb, a)
}

fn write_pixel_source(dst: &mut [u8], idx: usize, r: u8, g: u8, b: u8, a: u8) {
    let (sr, sg, sb, sa) = premultiply_rgba(r, g, b, a);
    dst[idx] = sb;
    dst[idx + 1] = sg;
    dst[idx + 2] = sr;
    dst[idx + 3] = sa;
}

fn fill_buffer(data: &mut [u8], color: u32) {
    let (r, g, b, a) = color_rgba(color);
    let (r, g, b, a) = premultiply_rgba(r, g, b, a);
    let mut i = 0usize;
    while i + 3 < data.len() {
        data[i] = b;
        data[i + 1] = g;
        data[i + 2] = r;
        data[i + 3] = a;
        i += 4;
    }
}

fn draw_rect_px(
    data: &mut [u8],
    stride: usize,
    buf_width: i32,
    buf_height: i32,
    rect: &SelectionBox,
    color: u32,
) {
    if rect.width <= 0 || rect.height <= 0 {
        return;
    }
    let x0 = rect.x.max(0).min(buf_width);
    let y0 = rect.y.max(0).min(buf_height);
    let x1 = (rect.x + rect.width).max(0).min(buf_width);
    let y1 = (rect.y + rect.height).max(0).min(buf_height);
    if x1 <= x0 || y1 <= y0 {
        return;
    }
    let (r, g, b, a) = color_rgba(color);
    for y in y0..y1 {
        let row = y as usize * stride;
        for x in x0..x1 {
            let idx = row + x as usize * 4;
            write_pixel_source(data, idx, r, g, b, a);
        }
    }
}

fn draw_border_px(
    data: &mut [u8],
    stride: usize,
    buf_width: i32,
    buf_height: i32,
    rect: &SelectionBox,
    thickness: i32,
    color: u32,
) {
    if thickness <= 0 {
        return;
    }
    let top = SelectionBox {
        x: rect.x,
        y: rect.y,
        width: rect.width,
        height: thickness,
        label: None,
    };
    let bottom = SelectionBox {
        x: rect.x,
        y: rect.y + rect.height - thickness,
        width: rect.width,
        height: thickness,
        label: None,
    };
    let left = SelectionBox {
        x: rect.x,
        y: rect.y,
        width: thickness,
        height: rect.height,
        label: None,
    };
    let right = SelectionBox {
        x: rect.x + rect.width - thickness,
        y: rect.y,
        width: thickness,
        height: rect.height,
        label: None,
    };
    draw_rect_px(data, stride, buf_width, buf_height, &top, color);
    draw_rect_px(data, stride, buf_width, buf_height, &bottom, color);
    draw_rect_px(data, stride, buf_width, buf_height, &left, color);
    draw_rect_px(data, stride, buf_width, buf_height, &right, color);
}

const FONT_5X7: [[u8; 7]; 11] = [
    [
        0b01110, 0b10001, 0b10011, 0b10101, 0b11001, 0b10001, 0b01110,
    ], // 0
    [
        0b00100, 0b01100, 0b00100, 0b00100, 0b00100, 0b00100, 0b01110,
    ], // 1
    [
        0b01110, 0b10001, 0b00001, 0b00110, 0b01000, 0b10000, 0b11111,
    ], // 2
    [
        0b11110, 0b00001, 0b00001, 0b01110, 0b00001, 0b00001, 0b11110,
    ], // 3
    [
        0b00010, 0b00110, 0b01010, 0b10010, 0b11111, 0b00010, 0b00010,
    ], // 4
    [
        0b11111, 0b10000, 0b10000, 0b11110, 0b00001, 0b00001, 0b11110,
    ], // 5
    [
        0b01110, 0b10000, 0b10000, 0b11110, 0b10001, 0b10001, 0b01110,
    ], // 6
    [
        0b11111, 0b00001, 0b00010, 0b00100, 0b01000, 0b01000, 0b01000,
    ], // 7
    [
        0b01110, 0b10001, 0b10001, 0b01110, 0b10001, 0b10001, 0b01110,
    ], // 8
    [
        0b01110, 0b10001, 0b10001, 0b01111, 0b00001, 0b00001, 0b01110,
    ], // 9
    [
        0b10001, 0b01010, 0b00100, 0b01010, 0b10001, 0b00000, 0b00000,
    ], // x
];

fn glyph_for_char(c: char) -> Option<&'static [u8; 7]> {
    match c {
        '0' => Some(&FONT_5X7[0]),
        '1' => Some(&FONT_5X7[1]),
        '2' => Some(&FONT_5X7[2]),
        '3' => Some(&FONT_5X7[3]),
        '4' => Some(&FONT_5X7[4]),
        '5' => Some(&FONT_5X7[5]),
        '6' => Some(&FONT_5X7[6]),
        '7' => Some(&FONT_5X7[7]),
        '8' => Some(&FONT_5X7[8]),
        '9' => Some(&FONT_5X7[9]),
        'x' | 'X' => Some(&FONT_5X7[10]),
        _ => None,
    }
}

struct PixelCanvas<'a> {
    data: &'a mut [u8],
    stride: usize,
    width: i32,
    height: i32,
}

struct TextRenderSpec<'a> {
    x: i32,
    y: i32,
    font_size: i32,
    text: &'a str,
    font_family: &'a str,
    color: u32,
}

struct RenderParams<'a> {
    logical_geometry: &'a SelectionBox,
    layer_width: u32,
    layer_height: u32,
    output_scale: f64,
    seats: &'a [SeatSnapshot],
    config: &'a Config,
    background: Option<&'a BackgroundImage>,
    transparent_overlay: bool,
    background_prepared: bool,
    previous_selection: Option<&'a SelectionBox>,
}

fn draw_text_5x7(canvas: &mut PixelCanvas<'_>, x: i32, y: i32, scale: i32, text: &str, color: u32) {
    if scale <= 0 {
        return;
    }
    let (r, g, b, a) = color_rgba(color);
    let mut pen_x = x;
    for ch in text.chars() {
        if let Some(glyph) = glyph_for_char(ch) {
            for (row, row_mask) in glyph.iter().enumerate() {
                for col in 0..5 {
                    if (row_mask & (1 << (4 - col))) == 0 {
                        continue;
                    }
                    let px = pen_x + col * scale;
                    let py = y + row as i32 * scale;
                    let rect = SelectionBox {
                        x: px,
                        y: py,
                        width: scale,
                        height: scale,
                        label: None,
                    };
                    let x0 = rect.x.max(0).min(canvas.width);
                    let y0 = rect.y.max(0).min(canvas.height);
                    let x1 = (rect.x + rect.width).max(0).min(canvas.width);
                    let y1 = (rect.y + rect.height).max(0).min(canvas.height);
                    for yy in y0..y1 {
                        let base = yy as usize * canvas.stride;
                        for xx in x0..x1 {
                            let idx = base + xx as usize * 4;
                            write_pixel_source(canvas.data, idx, r, g, b, a);
                        }
                    }
                }
            }
        }
        pen_x += 6 * scale;
    }
}

fn draw_text_cairo(canvas: &mut PixelCanvas<'_>, spec: &TextRenderSpec<'_>) -> bool {
    let Ok(text_c) = CString::new(spec.text) else {
        return false;
    };
    let Ok(font_c) = CString::new(spec.font_family) else {
        return false;
    };

    let (r, g, b, a) = color_rgba(spec.color);
    let cr;
    let surface;
    unsafe {
        surface = cairo_image_surface_create_for_data(
            canvas.data.as_mut_ptr(),
            CAIRO_FORMAT_ARGB32,
            canvas.width as c_int,
            canvas.height as c_int,
            canvas.stride as c_int,
        );
        if surface.is_null() {
            return false;
        }
        cr = cairo_create(surface);
        if cr.is_null() {
            cairo_surface_destroy(surface);
            return false;
        }

        cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
        cairo_set_source_rgba(
            cr,
            r as f64 / 255.0,
            g as f64 / 255.0,
            b as f64 / 255.0,
            a as f64 / 255.0,
        );
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT);
        cairo_select_font_face(
            cr,
            font_c.as_ptr(),
            CAIRO_FONT_SLANT_NORMAL,
            CAIRO_FONT_WEIGHT_NORMAL,
        );
        cairo_set_font_size(cr, spec.font_size as f64);
        cairo_move_to(cr, spec.x as f64, spec.y as f64);
        cairo_show_text(cr, text_c.as_ptr());

        cairo_destroy(cr);
        cairo_surface_destroy(surface);
    }
    true
}

fn logical_to_surface_rect(
    logical_geometry: &SelectionBox,
    layer_width: u32,
    layer_height: u32,
    scale: f64,
    rect: &SelectionBox,
) -> Option<SelectionBox> {
    let ow = layer_width as i32;
    let oh = layer_height as i32;
    if ow <= 0 || oh <= 0 {
        return None;
    }

    let x0 = (rect.x - logical_geometry.x).max(0).min(ow);
    let y0 = (rect.y - logical_geometry.y).max(0).min(oh);
    let x1 = (rect.x + rect.width - logical_geometry.x).max(0).min(ow);
    let y1 = (rect.y + rect.height - logical_geometry.y).max(0).min(oh);
    if x1 <= x0 || y1 <= y0 {
        return None;
    }

    let scale = crate::wayland::normalize_scale(scale);
    Some(SelectionBox {
        x: (x0 as f64 * scale).round() as i32,
        y: (y0 as f64 * scale).round() as i32,
        width: ((x1 - x0) as f64 * scale).round() as i32,
        height: ((y1 - y0) as f64 * scale).round() as i32,
        label: None,
    })
}

fn cairo_set_source_u32(cr: *mut CairoContext, color: u32) {
    let (r, g, b, a) = color_rgba(color);
    unsafe {
        cairo_set_source_rgba(
            cr,
            r as f64 / 255.0,
            g as f64 / 255.0,
            b as f64 / 255.0,
            a as f64 / 255.0,
        );
    }
}

fn background_matches_buffer(
    background: &BackgroundImage,
    width: u32,
    height: u32,
    stride: usize,
    pixel_len: usize,
) -> bool {
    background.width == width
        && background.height == height
        && background.stride == stride
        && background.pixels.len() == pixel_len
}

fn resize_background(
    background: &BackgroundImage,
    width: u32,
    height: u32,
) -> Option<BackgroundImage> {
    let image = image::RgbaImage::from_raw(
        background.width,
        background.height,
        background.pixels.clone(),
    )?;
    let image =
        image::imageops::resize(&image, width, height, image::imageops::FilterType::Triangle);
    Some(BackgroundImage {
        width,
        height,
        stride: width as usize * 4,
        pixels: image.into_raw(),
        origin_x: background.origin_x,
        origin_y: background.origin_y,
    })
}

fn restore_background_region(
    canvas: &mut PixelCanvas<'_>,
    background: &BackgroundImage,
    params: &RenderParams<'_>,
    selection: &SelectionBox,
) {
    let Some(region) = logical_to_surface_rect(
        params.logical_geometry,
        params.layer_width,
        params.layer_height,
        params.output_scale,
        selection,
    ) else {
        return;
    };
    let x = region.x.max(0) as usize;
    let y = region.y.max(0) as usize;
    let width = region.width.max(0) as usize;
    let height = region.height.max(0) as usize;
    if x + width > background.width as usize
        || y + height > background.height as usize
        || x + width > canvas.width as usize
        || y + height > canvas.height as usize
    {
        return;
    }
    for row in 0..height {
        let source_start = (y + row) * background.stride + x * 4;
        let target_start = (y + row) * canvas.stride + x * 4;
        let source = &background.pixels[source_start..source_start + width * 4];
        canvas.data[target_start..target_start + width * 4].copy_from_slice(source);
    }
}

fn expand_selection(selection: &SelectionBox, amount: i32) -> SelectionBox {
    let amount = amount.max(0);
    SelectionBox {
        x: selection.x - amount,
        y: selection.y - amount,
        width: selection.width + amount * 2,
        height: selection.height + amount * 2,
        label: None,
    }
}

fn dim_background_region(
    cr: *mut CairoContext,
    canvas: &mut PixelCanvas<'_>,
    background: &BackgroundImage,
    params: &RenderParams<'_>,
    selection: &SelectionBox,
) {
    restore_background_region(canvas, background, params, selection);
    unsafe {
        cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
        cairo_set_source_u32(cr, params.config.colors.background);
        cairo_rectangle(
            cr,
            selection.x as f64,
            selection.y as f64,
            selection.width as f64,
            selection.height as f64,
        );
        cairo_fill(cr);
    }
}

fn render_overlay_cairo(
    cr: *mut CairoContext,
    surface: *mut CairoSurface,
    canvas: &mut PixelCanvas<'_>,
    params: &RenderParams<'_>,
) -> bool {
    if cr.is_null() {
        return false;
    }
    unsafe {
        cairo_identity_matrix(cr);
        cairo_scale(cr, params.output_scale, params.output_scale);
        cairo_translate(
            cr,
            -(params.logical_geometry.x as f64),
            -(params.logical_geometry.y as f64),
        );
        cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE);

        if !params.background_prepared {
            if params.transparent_overlay {
                cairo_set_source_rgba(cr, 0.0, 0.0, 0.0, 0.0);
                cairo_paint(cr);
                cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
                cairo_set_source_u32(cr, params.config.colors.background);
            } else {
                cairo_set_operator(
                    cr,
                    if params.background.is_some() {
                        CAIRO_OPERATOR_OVER
                    } else {
                        CAIRO_OPERATOR_SOURCE
                    },
                );
                cairo_set_source_u32(cr, params.config.colors.background);
            }
            cairo_paint(cr);
        }

        if params.background_prepared
            && let (Some(background), Some(previous)) =
                (params.background, params.previous_selection)
        {
            let expanded = expand_selection(
                previous,
                params.config.border_weight + RESIZE_HANDLE_RADIUS + 2,
            );
            dim_background_region(cr, canvas, background, params, &expanded);
            cairo_surface_mark_dirty(surface);
        }

        let font_c = CString::new(params.config.font_family.as_str()).ok();
        for seat in params.seats {
            if !seat.has_selection
                && params.config.crosshairs
                && SelectionBox::contains(params.logical_geometry, seat.x, seat.y)
            {
                cairo_set_source_u32(cr, params.config.colors.border);
                cairo_rectangle(
                    cr,
                    params.logical_geometry.x as f64,
                    seat.y as f64,
                    params.logical_geometry.width as f64,
                    1.0,
                );
                cairo_fill(cr);
                cairo_rectangle(
                    cr,
                    seat.x as f64,
                    params.logical_geometry.y as f64,
                    1.0,
                    params.logical_geometry.height as f64,
                );
                cairo_fill(cr);
            }

            if !seat.has_selection
                || !SelectionBox::intersect(params.logical_geometry, &seat.selection)
            {
                continue;
            }
            let sel = &seat.selection;

            if params.transparent_overlay {
                cairo_set_operator(cr, CAIRO_OPERATOR_CLEAR);
                cairo_rectangle(
                    cr,
                    sel.x as f64,
                    sel.y as f64,
                    sel.width as f64,
                    sel.height as f64,
                );
                cairo_fill(cr);
                cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
            } else if let Some(background) = params.background {
                restore_background_region(canvas, background, params, sel);
                cairo_surface_mark_dirty(surface);
            }

            if !params.transparent_overlay {
                cairo_set_source_u32(cr, params.config.colors.selection);
                cairo_rectangle(
                    cr,
                    sel.x as f64,
                    sel.y as f64,
                    sel.width as f64,
                    sel.height as f64,
                );
                cairo_fill(cr);
            }

            cairo_set_source_u32(cr, params.config.colors.border);
            cairo_stroke_selection_rect(
                cr,
                sel,
                params.config.border_weight,
                params.output_scale,
                params.transparent_overlay,
            );
            if !params.transparent_overlay && seat.ctrl_pressed {
                cairo_draw_resize_handles(cr, sel);
            }

            if params.config.display_dimensions {
                cairo_set_source_u32(cr, params.config.colors.border);
                if let Some(font_c) = &font_c {
                    let text = format!("{}x{}", sel.width, sel.height);
                    if let Ok(text_c) = CString::new(text) {
                        cairo_set_antialias(cr, CAIRO_ANTIALIAS_DEFAULT);
                        cairo_select_font_face(
                            cr,
                            font_c.as_ptr(),
                            CAIRO_FONT_SLANT_NORMAL,
                            CAIRO_FONT_WEIGHT_NORMAL,
                        );
                        cairo_set_font_size(cr, 14.0);
                        cairo_move_to(
                            cr,
                            (sel.x + sel.width + 10) as f64,
                            (sel.y + sel.height + 20) as f64,
                        );
                        cairo_show_text(cr, text_c.as_ptr());
                        cairo_set_antialias(cr, CAIRO_ANTIALIAS_NONE);
                    }
                }
            }
        }
    }
    true
}

fn cairo_stroke_selection_rect(
    cr: *mut CairoContext,
    sel: &SelectionBox,
    border_weight: i32,
    output_scale: f64,
    outside: bool,
) {
    let lw = border_weight.max(1) as f64 / crate::wayland::normalize_scale(output_scale);
    let offset = if outside { -lw / 2.0 } else { 0.0 };
    let width = (sel.width as f64 + if outside { lw } else { 0.0 }).max(1.0);
    let height = (sel.height as f64 + if outside { lw } else { 0.0 }).max(1.0);

    unsafe {
        cairo_set_line_width(cr, lw);
        cairo_rectangle(
            cr,
            sel.x as f64 + offset,
            sel.y as f64 + offset,
            width,
            height,
        );
        cairo_stroke(cr);
    }
}

fn cairo_draw_resize_handle(cr: *mut CairoContext, selection: &SelectionBox, handle: ResizeHandle) {
    let (center_x, center_y) = resize_handle_center(selection, handle);
    let (start_angle, end_angle) = match handle {
        ResizeHandle::TopLeft => (std::f64::consts::FRAC_PI_2, std::f64::consts::TAU),
        ResizeHandle::TopRight => (std::f64::consts::PI, std::f64::consts::PI * 2.5),
        ResizeHandle::BottomLeft => (0.0, std::f64::consts::FRAC_PI_2 * 3.0),
        ResizeHandle::BottomRight => (
            std::f64::consts::FRAC_PI_2 * 3.0,
            std::f64::consts::PI * 3.0,
        ),
    };
    unsafe {
        cairo_move_to(cr, center_x as f64, center_y as f64);
        cairo_arc(
            cr,
            center_x as f64,
            center_y as f64,
            RESIZE_HANDLE_RADIUS as f64,
            start_angle,
            end_angle,
        );
        cairo_close_path(cr);
        cairo_fill(cr);
    }
}

fn cairo_draw_resize_handles(cr: *mut CairoContext, selection: &SelectionBox) {
    for handle in [
        ResizeHandle::TopLeft,
        ResizeHandle::TopRight,
        ResizeHandle::BottomLeft,
        ResizeHandle::BottomRight,
    ] {
        cairo_draw_resize_handle(cr, selection, handle);
    }
}

fn handle_quadrant_contains(handle: ResizeHandle, dx: i32, dy: i32) -> bool {
    match handle {
        ResizeHandle::TopLeft => !(dx >= 0 && dy >= 0),
        ResizeHandle::TopRight => !(dx <= 0 && dy >= 0),
        ResizeHandle::BottomLeft => !(dx >= 0 && dy <= 0),
        ResizeHandle::BottomRight => !(dx <= 0 && dy <= 0),
    }
}

fn draw_resize_handle_px(
    canvas: &mut PixelCanvas<'_>,
    geometry: &SelectionBox,
    scale: i32,
    selection: &SelectionBox,
    handle: ResizeHandle,
    color: u32,
) {
    let (logical_x, logical_y) = resize_handle_center(selection, handle);
    let center_x = (logical_x - geometry.x) * scale;
    let center_y = (logical_y - geometry.y) * scale;
    let radius = RESIZE_HANDLE_RADIUS * scale;
    let radius_squared = radius * radius;
    for y in center_y - radius..=center_y + radius {
        for x in center_x - radius..=center_x + radius {
            let dx = x - center_x;
            let dy = y - center_y;
            if dx * dx + dy * dy > radius_squared || !handle_quadrant_contains(handle, dx, dy) {
                continue;
            }
            if x < 0 || y < 0 || x >= canvas.width || y >= canvas.height {
                continue;
            }
            let idx = y as usize * canvas.stride + x as usize * 4;
            let (r, g, b, a) = color_rgba(color);
            write_pixel_source(canvas.data, idx, r, g, b, a);
        }
    }
}

fn draw_resize_handles_px(
    canvas: &mut PixelCanvas<'_>,
    geometry: &SelectionBox,
    scale: i32,
    selection: &SelectionBox,
    color: u32,
) {
    for handle in [
        ResizeHandle::TopLeft,
        ResizeHandle::TopRight,
        ResizeHandle::BottomLeft,
        ResizeHandle::BottomRight,
    ] {
        draw_resize_handle_px(canvas, geometry, scale, selection, handle, color);
    }
}

fn render_overlay_software(canvas: &mut PixelCanvas<'_>, params: &RenderParams<'_>) {
    fill_buffer(canvas.data, params.config.colors.background);

    for seat in params.seats {
        if !seat.has_selection
            && params.config.crosshairs
            && SelectionBox::contains(params.logical_geometry, seat.x, seat.y)
        {
            let lx =
                ((seat.x - params.logical_geometry.x) as f64 * params.output_scale).round() as i32;
            let ly =
                ((seat.y - params.logical_geometry.y) as f64 * params.output_scale).round() as i32;
            let h = SelectionBox {
                x: 0,
                y: ly,
                width: (params.layer_width as f64 * params.output_scale).round() as i32,
                height: params.output_scale.round().max(1.0) as i32,
                label: None,
            };
            let v = SelectionBox {
                x: lx,
                y: 0,
                width: params.output_scale.round().max(1.0) as i32,
                height: (params.layer_height as f64 * params.output_scale).round() as i32,
                label: None,
            };
            draw_rect_px(
                canvas.data,
                canvas.stride,
                canvas.width,
                canvas.height,
                &h,
                params.config.colors.border,
            );
            draw_rect_px(
                canvas.data,
                canvas.stride,
                canvas.width,
                canvas.height,
                &v,
                params.config.colors.border,
            );
        }

        if !seat.has_selection || !SelectionBox::intersect(params.logical_geometry, &seat.selection)
        {
            continue;
        }
        if let Some(rect) = logical_to_surface_rect(
            params.logical_geometry,
            params.layer_width,
            params.layer_height,
            params.output_scale,
            &seat.selection,
        ) {
            if params.transparent_overlay {
                draw_rect_px(
                    canvas.data,
                    canvas.stride,
                    canvas.width,
                    canvas.height,
                    &rect,
                    0x00000000,
                );
            } else {
                draw_rect_px(
                    canvas.data,
                    canvas.stride,
                    canvas.width,
                    canvas.height,
                    &rect,
                    params.config.colors.selection,
                );
            }
            let border_rect = if params.transparent_overlay {
                let thickness = params.config.border_weight.max(1);
                SelectionBox {
                    x: rect.x - thickness,
                    y: rect.y - thickness,
                    width: rect.width + thickness * 2,
                    height: rect.height + thickness * 2,
                    label: None,
                }
            } else {
                rect.clone()
            };
            draw_border_px(
                canvas.data,
                canvas.stride,
                canvas.width,
                canvas.height,
                &border_rect,
                params.config.border_weight,
                params.config.colors.border,
            );
            if !params.transparent_overlay && seat.ctrl_pressed {
                draw_resize_handles_px(
                    canvas,
                    params.logical_geometry,
                    params.output_scale.round().max(1.0) as i32,
                    &seat.selection,
                    params.config.colors.border,
                );
            }
            if params.config.display_dimensions {
                let text = format!("{}x{}", seat.selection.width, seat.selection.height);
                let scale_px = params.output_scale.round().max(1.0) as i32;
                let tx = rect.x + rect.width + 10 * scale_px;
                let ty = rect.y + rect.height + 20 * scale_px;
                let text_spec = TextRenderSpec {
                    x: tx,
                    y: ty,
                    font_size: 14 * scale_px,
                    text: &text,
                    font_family: &params.config.font_family,
                    color: params.config.colors.border,
                };
                let drawn = draw_text_cairo(canvas, &text_spec);
                if !drawn {
                    draw_text_5x7(canvas, tx, ty, scale_px, &text, params.config.colors.border);
                }
            }
        }
    }
}

fn scroll_preview_panel(
    geometry: &SelectionBox,
    selection: &CaptureRect,
    source_width: u32,
    source_rows: usize,
) -> Option<SelectionBox> {
    if source_width == 0 || source_rows == 0 {
        return None;
    }

    const MARGIN: i32 = 16;
    const PADDING: i32 = 6;
    const MIN_IMAGE_WIDTH: i32 = 80;
    const MAX_IMAGE_WIDTH: i32 = 240;
    const MAX_IMAGE_HEIGHT: i32 = 360;
    let selection_width = selection.width as i32;
    let selection_height = selection.height as i32;

    let left_gap = selection.x.saturating_sub(geometry.x);
    let right_gap = geometry
        .x
        .saturating_add(geometry.width)
        .saturating_sub(selection.x.saturating_add(selection_width));
    let (side_gap, on_left) = if left_gap >= right_gap {
        (left_gap, true)
    } else {
        (right_gap, false)
    };
    let max_height = MAX_IMAGE_HEIGHT.min(geometry.height.saturating_sub(MARGIN * 2));
    let available_width = side_gap.saturating_sub(MARGIN * 2 + PADDING * 2);
    if max_height <= 0 || available_width < MIN_IMAGE_WIDTH {
        return None;
    }

    let aspect = source_width as f64 / source_rows as f64;
    let image_width = ((max_height as f64 * aspect).round() as i32)
        .min(MAX_IMAGE_WIDTH)
        .min(available_width);
    if image_width < MIN_IMAGE_WIDTH {
        return None;
    }
    let image_height = ((image_width as f64 / aspect).round() as i32).max(1);
    let panel_width = image_width + PADDING * 2;
    let panel_height = image_height + PADDING * 2;
    let panel_x = if on_left {
        selection.x - MARGIN - panel_width
    } else {
        selection.x + selection_width + MARGIN
    };
    let panel_y = (selection.y + (selection_height - panel_height) / 2).clamp(
        geometry.y + MARGIN,
        geometry.y + geometry.height - MARGIN - panel_height,
    );
    Some(SelectionBox {
        x: panel_x,
        y: panel_y,
        width: panel_width,
        height: panel_height,
        label: None,
    })
}

fn draw_scroll_preview(
    canvas: &mut PixelCanvas<'_>,
    geometry: &SelectionBox,
    output_scale: f64,
    selection: &CaptureRect,
    source_width: u32,
    source_rows: usize,
    source: &[u8],
) {
    if source_width == 0
        || source_rows == 0
        || source.len() < source_width as usize * source_rows * 4
    {
        return;
    }
    let Some(panel_logical) = scroll_preview_panel(geometry, selection, source_width, source_rows)
    else {
        return;
    };
    const PADDING: i32 = 6;
    let image_width = panel_logical.width - PADDING * 2;
    let image_height = panel_logical.height - PADDING * 2;
    let to_surface = |value: i32| (value as f64 * output_scale).round() as i32;
    let panel = SelectionBox {
        x: to_surface(panel_logical.x - geometry.x),
        y: to_surface(panel_logical.y - geometry.y),
        width: to_surface(panel_logical.width),
        height: to_surface(panel_logical.height),
        label: None,
    };
    draw_rect_px(
        canvas.data,
        canvas.stride,
        canvas.width,
        canvas.height,
        &panel,
        0x101010E6,
    );

    let image_x = panel.x + to_surface(PADDING);
    let image_y = panel.y + to_surface(PADDING);
    let image_width_px = to_surface(image_width).max(1) as usize;
    let image_height_px = to_surface(image_height).max(1) as usize;
    for y in 0..image_height_px {
        let source_y = y * source_rows / image_height_px;
        for x in 0..image_width_px {
            let source_x = x * source_width as usize / image_width_px;
            let source_idx = (source_y * source_width as usize + source_x) * 4;
            let target_x = image_x + x as i32;
            let target_y = image_y + y as i32;
            if target_x < 0 || target_y < 0 || target_x >= canvas.width || target_y >= canvas.height
            {
                continue;
            }
            let target_idx = target_y as usize * canvas.stride + target_x as usize * 4;
            write_pixel_source(
                canvas.data,
                target_idx,
                source[source_idx],
                source[source_idx + 1],
                source[source_idx + 2],
                source[source_idx + 3],
            );
        }
    }
    draw_border_px(
        canvas.data,
        canvas.stride,
        canvas.width,
        canvas.height,
        &panel,
        output_scale.round().max(1.0) as i32,
        0xFFFFFFFF,
    );
}

fn draw_cursor_crosshair(buffer: &mut CursorBuffer) {
    fill_buffer(&mut buffer.mmap, 0x00000000);

    let w = buffer.width as i32;
    let h = buffer.height as i32;
    let cx = w / 2;
    let cy = h / 2;

    let full_v = SelectionBox {
        x: (cx - 1).max(0),
        y: 0,
        width: 3.min(w),
        height: h,
        label: None,
    };
    let full_h = SelectionBox {
        x: 0,
        y: (cy - 1).max(0),
        width: w,
        height: 3.min(h),
        label: None,
    };
    draw_rect_px(&mut buffer.mmap, buffer.stride, w, h, &full_v, 0x000000FF);
    draw_rect_px(&mut buffer.mmap, buffer.stride, w, h, &full_h, 0x000000FF);

    let center_v = SelectionBox {
        x: cx,
        y: 0,
        width: 1,
        height: h,
        label: None,
    };
    let center_h = SelectionBox {
        x: 0,
        y: cy,
        width: w,
        height: 1,
        label: None,
    };
    draw_rect_px(&mut buffer.mmap, buffer.stride, w, h, &center_v, 0xFFFFFFFF);
    draw_rect_px(&mut buffer.mmap, buffer.stride, w, h, &center_h, 0xFFFFFFFF);
}

struct LoadedCursor {
    width: u32,
    height: u32,
    hotspot_x: i32,
    hotspot_y: i32,
    pixels: Vec<u32>,
}

fn load_xcursor_image(theme: Option<&str>, name: &str, size: i32) -> Option<LoadedCursor> {
    let Ok(name_c) = CString::new(name) else {
        return None;
    };
    let theme_c = theme.and_then(|t| CString::new(t).ok());
    let theme_ptr = theme_c.as_ref().map_or(std::ptr::null(), |t| t.as_ptr());

    let image = unsafe { XcursorLibraryLoadImage(name_c.as_ptr(), theme_ptr, size as c_int) };
    if image.is_null() {
        return None;
    }

    unsafe {
        let img = &*image;
        if img.width == 0 || img.height == 0 || img.pixels.is_null() {
            XcursorImageDestroy(image);
            return None;
        }

        let len = (img.width as usize).checked_mul(img.height as usize)?;
        let src = slice::from_raw_parts(img.pixels, len);
        let pixels = src.to_vec();
        let out = LoadedCursor {
            width: img.width,
            height: img.height,
            hotspot_x: img.xhot as i32,
            hotspot_y: img.yhot as i32,
            pixels,
        };
        XcursorImageDestroy(image);
        Some(out)
    }
}

fn load_cursor_from_theme(theme: Option<&str>, size: i32) -> Option<LoadedCursor> {
    load_xcursor_image(theme, "crosshair", size)
        .or_else(|| load_xcursor_image(theme, "left_ptr", size))
}

fn create_shm_buffer(
    shm: &WlShm,
    qh: &QueueHandle<SelectorState>,
    key: BufferKey,
    width: u32,
    height: u32,
) -> Result<ShmBuffer, String> {
    let stride = width as usize * 4;
    let size = stride
        .checked_mul(height as usize)
        .ok_or_else(|| "buffer size overflow".to_string())?;

    let file = tempfile().map_err(|_| "failed to create shm file".to_string())?;
    file.set_len(size as u64)
        .map_err(|_| "failed to allocate shm file".to_string())?;

    let mmap = unsafe { MmapOptions::new().len(size).map_mut(&file) }
        .map_err(|_| "failed to mmap shm file".to_string())?;
    let surface = unsafe {
        cairo_image_surface_create_for_data(
            mmap.as_ptr() as *mut u8,
            CAIRO_FORMAT_ARGB32,
            width as c_int,
            height as c_int,
            stride as c_int,
        )
    };
    if surface.is_null() {
        return Err("failed to create Cairo surface".to_string());
    }
    let cairo = unsafe { cairo_create(surface) };
    if cairo.is_null() {
        unsafe { cairo_surface_destroy(surface) };
        return Err("failed to create Cairo context".to_string());
    }
    let pool = shm.create_pool(file.as_fd(), size as i32, qh, ());
    let buffer = pool.create_buffer(
        0,
        width as i32,
        height as i32,
        stride as i32,
        WlShmFormat::Argb8888,
        qh,
        key,
    );
    pool.destroy();

    Ok(ShmBuffer {
        width,
        height,
        stride,
        busy: false,
        background_initialized: false,
        rendered_selection: None,
        mmap,
        _file: file,
        buffer,
        surface,
        cairo,
    })
}

fn create_cursor_buffer(
    shm: &WlShm,
    qh: &QueueHandle<SelectorState>,
    key: BufferKey,
    cursor_theme: Option<&str>,
    cursor_size: i32,
    scale: i32,
) -> Result<CursorBuffer, String> {
    let scaled = cursor_size
        .checked_mul(scale.max(1))
        .ok_or_else(|| "cursor size overflow".to_string())?;
    let themed = load_cursor_from_theme(cursor_theme, scaled.max(1));
    let (width, height, hotspot_x, hotspot_y, themed_pixels) = if let Some(cursor) = themed {
        (
            cursor.width.max(1),
            cursor.height.max(1),
            cursor.hotspot_x.max(0),
            cursor.hotspot_y.max(0),
            Some(cursor.pixels),
        )
    } else {
        let side = scaled.max(1) as u32;
        (side, side, side as i32 / 2, side as i32 / 2, None)
    };

    let stride = width as usize * 4;
    let size = stride
        .checked_mul(height as usize)
        .ok_or_else(|| "cursor buffer size overflow".to_string())?;

    let file = tempfile().map_err(|_| "failed to create shm file".to_string())?;
    file.set_len(size as u64)
        .map_err(|_| "failed to allocate shm file".to_string())?;

    let mmap = unsafe { MmapOptions::new().len(size).map_mut(&file) }
        .map_err(|_| "failed to mmap shm file".to_string())?;
    let pool = shm.create_pool(file.as_fd(), size as i32, qh, ());
    let buffer = pool.create_buffer(
        0,
        width as i32,
        height as i32,
        stride as i32,
        WlShmFormat::Argb8888,
        qh,
        key,
    );
    pool.destroy();

    let mut cursor = CursorBuffer {
        scale,
        width,
        height,
        stride,
        hotspot_x,
        hotspot_y,
        mmap,
        _file: file,
        buffer,
    };
    if let Some(pixels) = themed_pixels {
        fill_buffer(&mut cursor.mmap, 0x00000000);
        let max_px = (cursor.width as usize)
            .checked_mul(cursor.height as usize)
            .ok_or_else(|| "cursor pixel size overflow".to_string())?;
        let count = pixels.len().min(max_px);
        for (idx, pixel) in pixels.iter().take(count).enumerate() {
            let off = idx * 4;
            let bytes = pixel.to_ne_bytes();
            cursor.mmap[off..off + 4].copy_from_slice(&bytes);
        }
    } else {
        draw_cursor_crosshair(&mut cursor);
    }
    Ok(cursor)
}

fn ensure_cursor_buffer(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
    output_idx: usize,
    scale: i32,
) -> Result<(), String> {
    let shm = state
        .shm
        .as_ref()
        .ok_or_else(|| "compositor doesn't support wl_shm".to_string())?
        .clone();
    let cursor_size = state.cursor_size;
    let cursor_theme = state.cursor_theme.as_deref();
    let output = &mut state.outputs[output_idx];
    let needs_recreate = match output.cursor_buffer.as_ref() {
        Some(buffer) => buffer.scale != scale,
        None => true,
    };
    if !needs_recreate {
        return Ok(());
    }

    if let Some(old) = output.cursor_buffer.take() {
        old.buffer.destroy();
    }

    let key = BufferKey {
        output_idx,
        buffer_idx: usize::MAX,
    };
    output.cursor_buffer = Some(create_cursor_buffer(
        &shm,
        qh,
        key,
        cursor_theme,
        cursor_size,
        scale,
    )?);
    Ok(())
}

fn ensure_buffer(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
    output_idx: usize,
    buffer_idx: usize,
    width: u32,
    height: u32,
) -> Result<(), String> {
    let shm = state
        .shm
        .as_ref()
        .ok_or_else(|| "compositor doesn't support wl_shm".to_string())?
        .clone();
    let output = &mut state.outputs[output_idx];

    if buffer_idx < output.buffers.len() {
        let needs_recreate = output.buffers[buffer_idx].width != width
            || output.buffers[buffer_idx].height != height;
        if !needs_recreate {
            return Ok(());
        }
        output.buffers[buffer_idx].buffer.destroy();
        output.buffers.remove(buffer_idx);
    }

    let buf = create_shm_buffer(
        &shm,
        qh,
        BufferKey {
            output_idx,
            buffer_idx,
        },
        width,
        height,
    )?;
    if buffer_idx <= output.buffers.len() {
        output.buffers.insert(buffer_idx, buf);
    } else {
        output.buffers.push(buf);
    }
    Ok(())
}

fn next_buffer_index(output: &OutputEntry) -> Option<usize> {
    let mut idx = None;
    for (i, buffer) in output.buffers.iter().enumerate() {
        if !buffer.busy {
            idx = Some(i);
        }
    }
    idx
}

fn render_output(state: &mut SelectorState, qh: &QueueHandle<SelectorState>, output_idx: usize) {
    if output_idx >= state.outputs.len() {
        return;
    }
    if !state.outputs[output_idx].configured || state.outputs[output_idx].closed {
        return;
    }

    let scale = state.outputs[output_idx].scale.max(1);
    let viewport_enabled =
        state.viewporter.is_some() && state.outputs[output_idx].viewport.is_some();
    let output = &state.outputs[output_idx];
    let background_size = output
        .name
        .as_deref()
        .and_then(|name| state.background.as_ref()?.get(name))
        .map(|background| (background.width, background.height));
    let default_size =
        if viewport_enabled && output.geometry.width > 0 && output.geometry.height > 0 {
            (output.geometry.width as u32, output.geometry.height as u32)
        } else {
            (
                output.layer_width * scale as u32,
                output.layer_height * scale as u32,
            )
        };
    let (bw, bh) = if viewport_enabled {
        background_size.unwrap_or(default_size)
    } else {
        default_size
    };
    if bw == 0 || bh == 0 {
        return;
    }

    if state.outputs[output_idx].buffers.len() < 2 {
        if ensure_buffer(state, qh, output_idx, 0, bw, bh).is_err() {
            return;
        }
        if ensure_buffer(state, qh, output_idx, 1, bw, bh).is_err() {
            return;
        }
    }

    let Some(buffer_idx) = next_buffer_index(&state.outputs[output_idx]) else {
        return;
    };
    if ensure_buffer(state, qh, output_idx, buffer_idx, bw, bh).is_err() {
        return;
    }

    let seats = collect_seat_snapshots(state);
    let config = &state.config;
    let scroll_preview = if state.scroll_active {
        state
            .scroll_session
            .as_ref()
            .map(|session| (state.scroll_width, session.rows(), session.canvas()))
    } else {
        None
    };
    let scroll_rect = state.scroll_capture_rect.as_ref();

    let (
        output_name,
        logical_geometry,
        layer_width,
        layer_height,
        output_scale,
        buf_width,
        buf_height,
        viewport,
    ) = {
        let output = &state.outputs[output_idx];
        let buffer = &output.buffers[buffer_idx];
        (
            output.name.clone(),
            output.logical_geometry.clone(),
            output.layer_width,
            output.layer_height,
            if viewport_enabled {
                buffer.width as f64 / output.layer_width.max(1) as f64
            } else {
                output.scale.max(1) as f64
            },
            buffer.width,
            buffer.height,
            output.viewport.as_ref().cloned(),
        )
    };
    if let Some(name) = output_name.as_deref()
        && let Some(background) = state
            .background
            .as_ref()
            .and_then(|backgrounds| backgrounds.get(name))
        && (background.width != buf_width
            || background.height != buf_height
            || background.stride != buf_width as usize * 4)
        && let Some(resized) = resize_background(background, buf_width, buf_height)
        && let Some(backgrounds) = state.background.as_mut()
    {
        backgrounds.insert(name.to_string(), resized);
    }
    let background = state.background.as_ref().and_then(|backgrounds| {
        output_name
            .as_deref()
            .and_then(|name| backgrounds.get(name))
    });

    let output = &mut state.outputs[output_idx];
    let Some(surface) = output.surface.as_ref().cloned() else {
        return;
    };
    let buffer = &mut output.buffers[buffer_idx];
    let buf_width = buf_width as i32;
    let buf_height = buf_height as i32;

    let has_static_background = background.is_some() && !state.scroll_active;
    let background_matches = background.is_some_and(|background| {
        background_matches_buffer(
            background,
            buffer.width,
            buffer.height,
            buffer.stride,
            buffer.mmap.len(),
        )
    });
    let background_prepared =
        has_static_background && background_matches && buffer.background_initialized;
    let mut background_copied = background_prepared;
    if has_static_background
        && background_matches
        && !background_prepared
        && let Some(background) = background
    {
        buffer.mmap.copy_from_slice(&background.pixels);
        background_copied = true;
        unsafe { cairo_surface_mark_dirty(buffer.surface) };
    }
    if !background_copied {
        buffer.background_initialized = false;
        buffer.rendered_selection = None;
    }
    let render_background = if has_static_background && background_matches {
        background
    } else {
        None
    };
    let previous_selection = buffer.rendered_selection.as_ref();
    let params = RenderParams {
        logical_geometry: &logical_geometry,
        layer_width,
        layer_height,
        output_scale,
        seats: &seats,
        config,
        background: render_background,
        transparent_overlay: state.scroll_active,
        background_prepared,
        previous_selection,
    };
    let mut canvas = PixelCanvas {
        data: &mut buffer.mmap,
        stride: buffer.stride,
        width: buf_width,
        height: buf_height,
    };

    if !render_overlay_cairo(buffer.cairo, buffer.surface, &mut canvas, &params) {
        render_overlay_software(&mut canvas, &params);
    }
    if let (Some((width, rows, pixels)), Some(rect)) = (scroll_preview, scroll_rect) {
        draw_scroll_preview(
            &mut canvas,
            &logical_geometry,
            output_scale,
            rect,
            width,
            rows,
            pixels,
        );
    }

    buffer.background_initialized = has_static_background && background_copied;
    buffer.rendered_selection = if buffer.background_initialized {
        seats
            .iter()
            .find(|seat| seat.has_selection)
            .map(|seat| seat.selection.clone())
    } else {
        None
    };

    buffer.busy = true;
    surface.attach(Some(&buffer.buffer), 0, 0);
    surface.damage(0, 0, layer_width as i32, layer_height as i32);
    if let Some(viewport) = viewport {
        viewport.set_source(0.0, 0.0, buf_width as f64, buf_height as f64);
        viewport.set_destination(layer_width as i32, layer_height as i32);
        surface.set_buffer_scale(1);
    } else {
        surface.set_buffer_scale(scale);
    }
    surface.commit();
    output.dirty = false;
    output.initial_render_done = true;
}

fn pointer_is_over_scroll_preview(state: &SelectorState, seat_idx: usize) -> bool {
    let Some(seat) = state.seats.get(seat_idx) else {
        return false;
    };
    let Some(output_idx) = seat.pointer_selection.current_output else {
        return false;
    };
    let Some(selection) = state.scroll_capture_rect.as_ref() else {
        return false;
    };
    let Some(session) = state.scroll_session.as_ref() else {
        return false;
    };
    let Some(panel) = scroll_preview_panel(
        &state.outputs[output_idx].logical_geometry,
        selection,
        state.scroll_width,
        session.rows(),
    ) else {
        return false;
    };
    SelectionBox::contains(&panel, seat.pointer_selection.x, seat.pointer_selection.y)
}

fn request_render_all(state: &mut SelectorState, qh: &QueueHandle<SelectorState>) {
    for idx in 0..state.outputs.len() {
        request_render(state, qh, idx);
    }
}

fn request_render_pending(state: &mut SelectorState, qh: &QueueHandle<SelectorState>) {
    for idx in 0..state.outputs.len() {
        if state.pending_outputs.get(idx).copied().unwrap_or(false) {
            request_render(state, qh, idx);
            state.pending_outputs[idx] = false;
        }
    }
}

fn request_render(state: &mut SelectorState, qh: &QueueHandle<SelectorState>, output_idx: usize) {
    // Decide whether this output still needs a synchronous first render. The
    // borrow ends here so render_output can take &mut state below.
    let needs_direct_render = {
        let Some(output) = state.outputs.get_mut(output_idx) else {
            return;
        };
        if !output.configured || output.closed {
            return;
        }
        output.dirty = true;
        if output.frame_callback.is_some() || output.surface.is_none() {
            return;
        }
        !output.initial_render_done
    };

    if needs_direct_render {
        // Some compositors (e.g. Hyprland >= 0.56) never fire wl_surface.frame
        // callbacks for a layer surface that has not committed a buffer yet,
        // which deadlocks the selector before its first frame. Draw the first
        // frame synchronously instead of waiting for a callback.
        render_output(state, qh, output_idx);
        return;
    }

    let Some(output) = state.outputs.get_mut(output_idx) else {
        return;
    };
    let Some(surface) = output.surface.as_ref().cloned() else {
        return;
    };
    output.frame_callback = Some(surface.frame(qh, OutputKey(output_idx)));
    surface.commit();
}

fn set_pointer_cursor(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
    seat_idx: usize,
    output_idx: usize,
    serial: u32,
    over_scroll_preview: bool,
) {
    let Some(pointer) = state
        .seats
        .get(seat_idx)
        .and_then(|seat| seat.wl_pointer.as_ref().cloned())
    else {
        return;
    };

    let ctrl_pressed = state
        .seats
        .get(seat_idx)
        .is_some_and(|seat| seat.ctrl_pressed);
    let grabbing_selection = state
        .seats
        .get(seat_idx)
        .is_some_and(|seat| seat.moving_selection && seat.button_state == WlButtonState::Pressed);
    let resize_handle = state.seats.get(seat_idx).and_then(|seat| {
        if !seat.ctrl_pressed || state.scroll_active || !seat.pointer_selection.has_selection {
            return None;
        }
        resize_handle_at(
            &seat.pointer_selection.selection,
            seat.pointer_selection.x,
            seat.pointer_selection.y,
        )
    });

    if let Some(manager) = state.cursor_shape_manager.as_ref().cloned() {
        let device = manager.get_pointer(&pointer, qh, ());
        device.set_shape(
            serial,
            if grabbing_selection {
                CursorShape::Grabbing
            } else if let Some(handle) = resize_handle {
                match handle {
                    ResizeHandle::TopLeft | ResizeHandle::BottomRight => CursorShape::NwseResize,
                    ResizeHandle::TopRight | ResizeHandle::BottomLeft => CursorShape::NeswResize,
                }
            } else if ctrl_pressed {
                CursorShape::Grab
            } else if over_scroll_preview {
                CursorShape::Pointer
            } else {
                CursorShape::Crosshair
            },
        );
        device.destroy();
        return;
    }

    let Some(cursor_surface) = state
        .seats
        .get(seat_idx)
        .and_then(|seat| seat.cursor_surface.as_ref().cloned())
    else {
        return;
    };
    let scale = state
        .outputs
        .get(output_idx)
        .map(|output| output.scale.max(1))
        .unwrap_or(1);
    if ensure_cursor_buffer(state, qh, output_idx, scale).is_err() {
        return;
    }
    let Some(cursor_buffer) = state
        .outputs
        .get(output_idx)
        .and_then(|output| output.cursor_buffer.as_ref())
    else {
        return;
    };

    cursor_surface.set_buffer_scale(scale);
    cursor_surface.attach(Some(&cursor_buffer.buffer), 0, 0);
    pointer.set_cursor(
        serial,
        Some(&cursor_surface),
        cursor_buffer.hotspot_x / scale,
        cursor_buffer.hotspot_y / scale,
    );
    cursor_surface.commit();
}

fn refresh_pointer_cursor(
    state: &mut SelectorState,
    qh: &QueueHandle<SelectorState>,
    seat_idx: usize,
) {
    let Some((output_idx, serial)) = state
        .seats
        .get(seat_idx)
        .and_then(|seat| Some((seat.pointer_selection.current_output?, seat.cursor_serial)))
    else {
        return;
    };
    if serial == 0 {
        return;
    }
    let over_scroll_preview =
        state.scroll_active && pointer_is_over_scroll_preview(state, seat_idx);
    set_pointer_cursor(state, qh, seat_idx, output_idx, serial, over_scroll_preview);
}

impl Dispatch<WlRegistry, ()> for SelectorState {
    fn event(
        state: &mut Self,
        registry: &WlRegistry,
        event: wayland_client::protocol::wl_registry::Event,
        _: &(),
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if let wayland_client::protocol::wl_registry::Event::Global {
            name,
            interface,
            version,
        } = event
        {
            match interface.as_str() {
                "wl_compositor" => {
                    state.compositor = Some(registry.bind(name, version.min(4), qh, ()));
                }
                "wl_shm" => {
                    state.shm = Some(registry.bind(name, version.min(1), qh, ()));
                }
                "zwlr_layer_shell_v1" => {
                    state.layer_shell = Some(registry.bind(name, version.min(1), qh, ()));
                }
                "wl_seat" => {
                    let idx = state.seats.len();
                    let wl_seat = registry.bind(name, version.min(1), qh, SeatKey(idx));
                    state.seats.push(SeatEntry {
                        _wl_seat: Some(wl_seat),
                        touch_id: TOUCH_ID_EMPTY,
                        button_state: WlButtonState::Released,
                        ..SeatEntry::default()
                    });
                }
                "wl_output" => {
                    let idx = state.outputs.len();
                    let wl_output = registry.bind(name, version.min(3), qh, OutputKey(idx));
                    state.outputs.push(OutputEntry {
                        wl_output: Some(wl_output),
                        scale: 1,
                        ..OutputEntry::default()
                    });
                }
                "zxdg_output_manager_v1" => {
                    state.xdg_output_manager = Some(registry.bind(name, version.min(2), qh, ()));
                }
                "wp_cursor_shape_manager_v1" => {
                    state.cursor_shape_manager = Some(registry.bind(name, version.min(1), qh, ()));
                }
                "wp_viewporter" => {
                    state.viewporter = Some(registry.bind(name, version.min(1), qh, ()));
                }
                _ => {}
            }
        }
    }
}

impl Dispatch<WlOutput, OutputKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlOutput,
        event: wayland_client::protocol::wl_output::Event,
        data: &OutputKey,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(data.0) else {
            return;
        };

        match event {
            wayland_client::protocol::wl_output::Event::Geometry { x, y, .. } => {
                output.geometry.x = x;
                output.geometry.y = y;
            }
            wayland_client::protocol::wl_output::Event::Mode {
                flags,
                width,
                height,
                ..
            } => {
                let is_current = match flags {
                    WEnum::Value(f) => f.contains(WlOutputMode::Current),
                    WEnum::Unknown(_) => false,
                };
                if is_current {
                    output.geometry.width = width;
                    output.geometry.height = height;
                }
            }
            wayland_client::protocol::wl_output::Event::Scale { factor } => {
                output.scale = factor.max(1);
            }
            _ => {}
        }
    }
}

impl Dispatch<ZxdgOutputV1, OutputKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &ZxdgOutputV1,
        event: wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_v1::Event,
        data: &OutputKey,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(data.0) else {
            return;
        };

        match event {
            wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_v1::Event::LogicalPosition {
                x,
                y,
            } => {
                output.logical_geometry.x = x;
                output.logical_geometry.y = y;
            }
            wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_v1::Event::LogicalSize {
                width,
                height,
            } => {
                output.logical_geometry.width = width;
                output.logical_geometry.height = height;
            }
            wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_v1::Event::Name { name } => {
                output.name = Some(name.clone());
                output.logical_geometry.label = Some(name);
            }
            _ => {}
        }
    }
}

impl Dispatch<WlSeat, SeatKey> for SelectorState {
    fn event(
        state: &mut Self,
        seat: &WlSeat,
        event: wayland_client::protocol::wl_seat::Event,
        data: &SeatKey,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let Some(seat_entry) = state.seats.get_mut(data.0) else {
            return;
        };

        if let wayland_client::protocol::wl_seat::Event::Capabilities {
            capabilities: WEnum::Value(capabilities),
        } = event
        {
            if capabilities.contains(WlSeatCapability::Pointer) && seat_entry.wl_pointer.is_none() {
                seat_entry.wl_pointer = Some(seat.get_pointer(qh, *data));
                if seat_entry.cursor_surface.is_none()
                    && let Some(compositor) = state.compositor.as_ref().cloned()
                {
                    seat_entry.cursor_surface = Some(compositor.create_surface(qh, ()));
                }
            }
            if capabilities.contains(WlSeatCapability::Keyboard) && seat_entry.wl_keyboard.is_none()
            {
                seat_entry.wl_keyboard = Some(seat.get_keyboard(qh, *data));
            }
            if capabilities.contains(WlSeatCapability::Touch) && seat_entry.wl_touch.is_none() {
                seat_entry.wl_touch = Some(seat.get_touch(qh, *data));
            }
        }
    }
}

impl Dispatch<WlPointer, SeatKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlPointer,
        event: wayland_client::protocol::wl_pointer::Event,
        data: &SeatKey,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let seat_idx = data.0;
        if state.seats.get(seat_idx).is_none() {
            return;
        }
        mark_outputs_for_seat(state, seat_idx);
        let mut repaint = false;

        match event {
            wayland_client::protocol::wl_pointer::Event::Enter {
                serial,
                surface,
                surface_x,
                surface_y,
                ..
            } => {
                let Some(output_idx) = output_from_surface(&state.outputs, &surface) else {
                    return;
                };
                let outputs = &state.outputs;
                let config = &state.config;
                let resizing = &mut state.resizing_selection;
                let seat = &mut state.seats[seat_idx];
                seat.cursor_serial = serial;
                seat.pointer_selection.current_output = Some(output_idx);
                move_selection(outputs, &mut seat.pointer_selection, surface_x, surface_y);

                match seat.button_state {
                    WlButtonState::Released => {}
                    WlButtonState::Pressed if seat.resizing_handle.is_some() => {
                        handle_active_selection_motion(
                            config,
                            resizing,
                            &mut seat.pointer_selection,
                        )
                    }
                    WlButtonState::Pressed if seat.moving_selection => move_active_selection(
                        outputs,
                        &mut seat.pointer_selection,
                        seat.move_offset_x,
                        seat.move_offset_y,
                    ),
                    WlButtonState::Pressed => handle_active_selection_motion(
                        config,
                        resizing,
                        &mut seat.pointer_selection,
                    ),
                    _ => {}
                }

                let over_scroll_preview =
                    state.scroll_active && pointer_is_over_scroll_preview(state, seat_idx);
                let resize_handle = if state.scroll_active || !state.seats[seat_idx].ctrl_pressed {
                    None
                } else {
                    resize_handle_at(
                        &state.seats[seat_idx].pointer_selection.selection,
                        state.seats[seat_idx].pointer_selection.x,
                        state.seats[seat_idx].pointer_selection.y,
                    )
                };
                state.seats[seat_idx].cursor_over_scroll_preview = Some(over_scroll_preview);
                state.seats[seat_idx].cursor_over_resize_handle = resize_handle;
                set_pointer_cursor(state, qh, seat_idx, output_idx, serial, over_scroll_preview);
                repaint = true;
            }
            wayland_client::protocol::wl_pointer::Event::Leave { .. } => {
                let seat = &mut state.seats[seat_idx];
                seat.pointer_selection.current_output = None;
                seat.cursor_over_scroll_preview = None;
                seat.cursor_over_resize_handle = None;
                repaint = true;
            }
            wayland_client::protocol::wl_pointer::Event::Motion {
                surface_x,
                surface_y,
                ..
            } => {
                let outputs = &state.outputs;
                let config = &state.config;
                let resizing = &mut state.resizing_selection;
                let (output_idx, dragging) = {
                    let seat = &mut state.seats[seat_idx];
                    if seat.pointer_selection.current_output.is_none() {
                        return;
                    }
                    move_selection(outputs, &mut seat.pointer_selection, surface_x, surface_y);
                    match seat.button_state {
                        WlButtonState::Released => {}
                        WlButtonState::Pressed if seat.resizing_handle.is_some() => {
                            handle_active_selection_motion(
                                config,
                                resizing,
                                &mut seat.pointer_selection,
                            )
                        }
                        WlButtonState::Pressed if seat.moving_selection => move_active_selection(
                            outputs,
                            &mut seat.pointer_selection,
                            seat.move_offset_x,
                            seat.move_offset_y,
                        ),
                        WlButtonState::Pressed => handle_active_selection_motion(
                            config,
                            resizing,
                            &mut seat.pointer_selection,
                        ),
                        _ => {}
                    }
                    (
                        seat.pointer_selection.current_output,
                        seat.button_state == WlButtonState::Pressed,
                    )
                };
                let over_scroll_preview =
                    state.scroll_active && pointer_is_over_scroll_preview(state, seat_idx);
                let resize_handle = if state.scroll_active || !state.seats[seat_idx].ctrl_pressed {
                    None
                } else {
                    resize_handle_at(
                        &state.seats[seat_idx].pointer_selection.selection,
                        state.seats[seat_idx].pointer_selection.x,
                        state.seats[seat_idx].pointer_selection.y,
                    )
                };
                let cursor_changed = state.seats[seat_idx].cursor_over_scroll_preview
                    != Some(over_scroll_preview)
                    || state.seats[seat_idx].cursor_over_resize_handle != resize_handle;
                if cursor_changed {
                    state.seats[seat_idx].cursor_over_scroll_preview = Some(over_scroll_preview);
                    state.seats[seat_idx].cursor_over_resize_handle = resize_handle;
                }
                if cursor_changed && let Some(output_idx) = output_idx {
                    let serial = state.seats[seat_idx].cursor_serial;
                    if serial != 0 {
                        set_pointer_cursor(
                            state,
                            qh,
                            seat_idx,
                            output_idx,
                            serial,
                            over_scroll_preview,
                        );
                    }
                }
                repaint = dragging || state.config.crosshairs;
            }
            wayland_client::protocol::wl_pointer::Event::Button {
                button,
                state: button_state,
                ..
            } => {
                if state.seats[seat_idx].touch_selection.has_selection {
                    return;
                }

                let button_state = match button_state {
                    WEnum::Value(v) => v,
                    WEnum::Unknown(_) => return,
                };

                state.seats[seat_idx].button_state = button_state;
                if button == BTN_LEFT {
                    if state.scroll_active
                        && button_state == WlButtonState::Pressed
                        && pointer_is_over_scroll_preview(state, seat_idx)
                    {
                        finish_scroll(state);
                    } else {
                        let action = {
                            let seat = &mut state.seats[seat_idx];
                            match button_state {
                                WlButtonState::Pressed => {
                                    let handle = if seat.ctrl_pressed && !state.scroll_active {
                                        resize_handle_at(
                                            &seat.pointer_selection.selection,
                                            seat.pointer_selection.x,
                                            seat.pointer_selection.y,
                                        )
                                    } else {
                                        None
                                    };
                                    if let Some(handle) = handle
                                        && begin_selection_resize(seat, handle)
                                    {
                                        state.resizing_selection = true;
                                        None
                                    } else if seat.ctrl_pressed && begin_selection_move(seat) {
                                        state.resizing_selection = false;
                                        None
                                    } else {
                                        handle_selection_start(
                                            &state.config,
                                            &mut seat.pointer_selection,
                                        )
                                    }
                                }
                                WlButtonState::Released
                                    if seat.resizing_handle.take().is_some() =>
                                {
                                    state.resizing_selection = false;
                                    Some(seat.pointer_selection.selection.clone())
                                }
                                WlButtonState::Released if seat.moving_selection => {
                                    seat.moving_selection = false;
                                    state.resizing_selection = false;
                                    Some(seat.pointer_selection.selection.clone())
                                }
                                WlButtonState::Released => handle_selection_end(
                                    &state.config,
                                    &mut state.resizing_selection,
                                    &mut seat.pointer_selection,
                                ),
                                _ => None,
                            }
                        };
                        if let Some(result) = action {
                            let output_idx = state.seats[seat_idx].pointer_selection.current_output;
                            set_result(state, result, output_idx);
                            if !state.config.scroll
                                && state.config.no_confirm
                                && should_finish_pointer_selection(&state.config, button_state)
                            {
                                state.running = false;
                            }
                        }
                    }
                } else {
                    handle_selection_cancelled(state, seat_idx);
                }
                refresh_pointer_cursor(state, qh, seat_idx);
                repaint = true;
            }
            _ => {}
        }

        mark_outputs_for_seat(state, seat_idx);
        if repaint && has_pending_outputs(state) {
            state.repaint_pending = true;
        }
    }
}

impl Dispatch<WlKeyboard, SeatKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlKeyboard,
        event: wayland_client::protocol::wl_keyboard::Event,
        data: &SeatKey,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let seat_idx = data.0;
        mark_outputs_for_seat(state, seat_idx);
        let mut repaint = false;
        match event {
            wayland_client::protocol::wl_keyboard::Event::Leave { .. } => {
                if let Some(seat) = state.seats.get_mut(seat_idx) {
                    seat.ctrl_pressed = false;
                }
            }
            wayland_client::protocol::wl_keyboard::Event::Key {
                key,
                state: key_state,
                ..
            } => {
                let key_state = match key_state {
                    WEnum::Value(v) => v,
                    WEnum::Unknown(_) => return,
                };

                match key_state {
                    WlKeyState::Pressed => match key {
                        KEY_CTRL_LEFT | KEY_CTRL_RIGHT => {
                            state.seats[seat_idx].ctrl_pressed = true;
                            refresh_pointer_cursor(state, qh, seat_idx);
                            repaint = true;
                        }
                        KEY_ESCAPE => {
                            if state.scroll_active {
                                cancel_scroll(state);
                            } else {
                                handle_selection_cancelled(state, seat_idx);
                            }
                            repaint = true;
                        }
                        KEY_ENTER | KEY_SPACE | KEY_KP_ENTER => {
                            if state.scroll_active {
                                finish_scroll(state);
                                return;
                            }
                            let selection = state.seats.get(seat_idx).and_then(|seat| {
                                let current = if seat.touch_selection.has_selection {
                                    &seat.touch_selection
                                } else {
                                    &seat.pointer_selection
                                };
                                current
                                    .has_selection
                                    .then(|| (current.selection.clone(), current.current_output))
                            });
                            if let Some((selection, output_idx)) = selection {
                                if state.config.scroll {
                                    enter_scroll_phase(state, selection, output_idx, qh);
                                } else {
                                    set_result(state, selection, output_idx);
                                    state.running = false;
                                }
                                repaint = true;
                            }
                        }
                        KEY_SHIFT_LEFT | KEY_SHIFT_RIGHT if !state.config.fixed_aspect_ratio => {
                            state.config.aspect_ratio = 1.0;
                            if state.resizing_selection {
                                recompute_selection(state, seat_idx);
                                repaint = true;
                            }
                        }
                        _ => {}
                    },
                    WlKeyState::Released => match key {
                        KEY_CTRL_LEFT | KEY_CTRL_RIGHT => {
                            state.seats[seat_idx].ctrl_pressed = false;
                            refresh_pointer_cursor(state, qh, seat_idx);
                            repaint = true;
                        }
                        KEY_SPACE => {
                            repaint = true;
                        }
                        KEY_SHIFT_LEFT | KEY_SHIFT_RIGHT if !state.config.fixed_aspect_ratio => {
                            state.config.aspect_ratio = 0.0;
                            if state.resizing_selection {
                                recompute_selection(state, seat_idx);
                                repaint = true;
                            }
                        }
                        _ => {}
                    },
                    _ => {}
                }
            }
            _ => {}
        }
        mark_outputs_for_seat(state, seat_idx);
        if repaint && has_pending_outputs(state) {
            state.repaint_pending = true;
        }
    }
}

impl Dispatch<WlTouch, SeatKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlTouch,
        event: wayland_client::protocol::wl_touch::Event,
        data: &SeatKey,
        _: &Connection,
        _qh: &QueueHandle<Self>,
    ) {
        let seat_idx = data.0;
        if state.seats.get(seat_idx).is_none() {
            return;
        }
        mark_outputs_for_seat(state, seat_idx);
        let mut repaint = false;

        match event {
            wayland_client::protocol::wl_touch::Event::Down {
                surface, id, x, y, ..
            } => {
                if state.seats[seat_idx].pointer_selection.has_selection {
                    return;
                }
                if state.seats[seat_idx].touch_id != TOUCH_ID_EMPTY {
                    return;
                }

                let current_output = output_from_surface(&state.outputs, &surface);
                let outputs = &state.outputs;
                let action = {
                    let seat = &mut state.seats[seat_idx];
                    seat.touch_id = id;
                    seat.touch_selection.current_output = current_output;
                    move_selection(outputs, &mut seat.touch_selection, x, y);
                    handle_selection_start(&state.config, &mut seat.touch_selection)
                };
                if let Some(result) = action {
                    set_result(state, result, current_output);
                    state.running = false;
                }
                repaint = true;
            }
            wayland_client::protocol::wl_touch::Event::Up { id, .. } => {
                if state.seats[seat_idx].touch_id != id {
                    return;
                }

                let output_idx = state.seats[seat_idx].touch_selection.current_output;
                let action = {
                    let seat = &mut state.seats[seat_idx];
                    let action = handle_selection_end(
                        &state.config,
                        &mut state.resizing_selection,
                        &mut seat.touch_selection,
                    );
                    seat.touch_id = TOUCH_ID_EMPTY;
                    seat.touch_selection.current_output = None;
                    action
                };
                if let Some(result) = action {
                    set_result(state, result, output_idx);
                    state.running = false;
                }
                repaint = true;
            }
            wayland_client::protocol::wl_touch::Event::Motion { id, x, y, .. } => {
                if state.seats[seat_idx].touch_id != id {
                    return;
                }

                let outputs = &state.outputs;
                let config = &state.config;
                let resizing = &mut state.resizing_selection;
                let seat = &mut state.seats[seat_idx];
                move_selection(outputs, &mut seat.touch_selection, x, y);
                handle_active_selection_motion(config, resizing, &mut seat.touch_selection);
                repaint = true;
            }
            wayland_client::protocol::wl_touch::Event::Cancel => {
                let seat = &mut state.seats[seat_idx];
                seat.touch_id = TOUCH_ID_EMPTY;
                seat.touch_selection.current_output = None;
                repaint = true;
            }
            _ => {}
        }
        mark_outputs_for_seat(state, seat_idx);
        if repaint && has_pending_outputs(state) {
            state.repaint_pending = true;
        }
    }
}

impl Dispatch<WlCompositor, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WlCompositor,
        _: wayland_client::protocol::wl_compositor::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlSurface, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WlSurface,
        _: wayland_client::protocol::wl_surface::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlShm, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WlShm,
        _: wayland_client::protocol::wl_shm::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlShmPool, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WlShmPool,
        _: wayland_client::protocol::wl_shm_pool::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WlBuffer, BufferKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlBuffer,
        event: wayland_client::protocol::wl_buffer::Event,
        data: &BufferKey,
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
        if let wayland_client::protocol::wl_buffer::Event::Release = event
            && let Some(output) = state.outputs.get_mut(data.output_idx)
            && let Some(buffer) = output.buffers.get_mut(data.buffer_idx)
        {
            buffer.busy = false;
        }
    }
}

impl Dispatch<ZwlrLayerShellV1, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &ZwlrLayerShellV1,
        _: wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_shell_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZxdgOutputManagerV1, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &ZxdgOutputManagerV1,
        _: wayland_protocols::xdg::xdg_output::zv1::client::zxdg_output_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ZwlrLayerSurfaceV1, OutputKey> for SelectorState {
    fn event(
        state: &mut Self,
        layer_surface: &ZwlrLayerSurfaceV1,
        event: wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_surface_v1::Event,
        data: &OutputKey,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        let Some(output) = state.outputs.get_mut(data.0) else {
            return;
        };

        match event {
            wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_surface_v1::Event::Configure {
                serial,
                width,
                height,
            } => {
                layer_surface.ack_configure(serial);
                output.configured = true;
                output.layer_width = width;
                output.layer_height = height;
            }
            wayland_protocols_wlr::layer_shell::v1::client::zwlr_layer_surface_v1::Event::Closed => {
                output.closed = true;
                output.configured = false;
            }
            _ => {}
        }
        request_render(state, qh, data.0);
    }
}

impl Dispatch<WlCallback, OutputKey> for SelectorState {
    fn event(
        state: &mut Self,
        _: &WlCallback,
        event: wayland_client::protocol::wl_callback::Event,
        data: &OutputKey,
        _: &Connection,
        qh: &QueueHandle<Self>,
    ) {
        if !matches!(
            event,
            wayland_client::protocol::wl_callback::Event::Done { .. }
        ) {
            return;
        }
        let Some(output) = state.outputs.get_mut(data.0) else {
            return;
        };
        output.frame_callback = None;
        if output.dirty {
            render_output(state, qh, data.0);
        }
    }
}

impl Dispatch<WpCursorShapeManagerV1, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WpCursorShapeManagerV1,
        _: wayland_protocols::wp::cursor_shape::v1::client::wp_cursor_shape_manager_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<WpCursorShapeDeviceV1, ()> for SelectorState {
    fn event(
        _: &mut Self,
        _: &WpCursorShapeDeviceV1,
        _: wayland_protocols::wp::cursor_shape::v1::client::wp_cursor_shape_device_v1::Event,
        _: &(),
        _: &Connection,
        _: &QueueHandle<Self>,
    ) {
    }
}

#[cfg(test)]
mod tests {
    use super::{
        OutputEntry, SelectionBox, clamp_selection_to_outputs, logical_to_surface_rect,
        translated_selection,
    };

    #[test]
    fn translated_selection_preserves_size_and_grab_offset() {
        let selection = SelectionBox {
            x: 100,
            y: 200,
            width: 300,
            height: 150,
            label: Some("selection".to_string()),
        };

        let moved = translated_selection(&selection, 250, 300, 50, 25);

        assert_eq!(moved.x, 200);
        assert_eq!(moved.y, 275);
        assert_eq!(moved.width, selection.width);
        assert_eq!(moved.height, selection.height);
        assert_eq!(moved.label, selection.label);
    }

    #[test]
    fn translated_selection_supports_negative_coordinates() {
        let selection = SelectionBox {
            x: 100,
            y: 100,
            width: 40,
            height: 30,
            label: None,
        };

        let moved = translated_selection(&selection, -20, -30, 10, 15);

        assert_eq!(moved.x, -30);
        assert_eq!(moved.y, -45);
        assert_eq!((moved.width, moved.height), (40, 30));
    }

    #[test]
    fn clamp_selection_keeps_moved_region_inside_virtual_desktop() {
        let outputs = vec![OutputEntry {
            logical_geometry: SelectionBox {
                x: -1920,
                y: 0,
                width: 3840,
                height: 2160,
                ..SelectionBox::default()
            },
            ..OutputEntry::default()
        }];
        let selection = SelectionBox {
            x: 1800,
            y: 2100,
            width: 300,
            height: 200,
            label: None,
        };

        let clamped = clamp_selection_to_outputs(&selection, &outputs);

        assert_eq!((clamped.x, clamped.y), (1620, 1960));
        assert_eq!((clamped.width, clamped.height), (300, 200));
    }

    #[test]
    fn resize_handle_hit_test_uses_selection_corners() {
        let selection = SelectionBox {
            x: 100,
            y: 200,
            width: 300,
            height: 150,
            label: None,
        };

        assert_eq!(
            super::resize_handle_at(&selection, 100, 200),
            Some(super::ResizeHandle::TopLeft)
        );
        assert_eq!(
            super::resize_handle_at(&selection, 400, 350),
            Some(super::ResizeHandle::BottomRight)
        );
        assert_eq!(super::resize_handle_at(&selection, 250, 275), None);
    }

    #[test]
    fn logical_rect_preserves_fractional_surface_scale() {
        let geometry = SelectionBox {
            x: 0,
            y: 0,
            width: 1000,
            height: 800,
            label: None,
        };
        let selection = SelectionBox {
            x: 100,
            y: 200,
            width: 400,
            height: 200,
            label: None,
        };

        let surface = logical_to_surface_rect(&geometry, 1000, 800, 0.75, &selection)
            .expect("selection should map to the surface");

        assert_eq!((surface.x, surface.y), (75, 150));
        assert_eq!((surface.width, surface.height), (300, 150));
    }
}
