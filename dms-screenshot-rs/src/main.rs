mod cli;
mod contract;
mod niri;
mod region_selector;
mod scroll_session;
mod scroll_stitch;
mod selection;
mod selector;
mod state;
mod wayland;
mod window;

use clap::Parser;
use cli::{CaptureArgs, Cli, Command};
use contract::{CaptureError, CaptureResult, OutputList};
use image::{DynamicImage, ImageFormat};
use std::{
    fs,
    io::{self, Cursor, Write},
    path::PathBuf,
    process::{Command as ProcessCommand, Stdio},
    time::{SystemTime, UNIX_EPOCH},
};

use selection::{Rect, normalize};

fn main() {
    let cli = Cli::parse();
    let json = cli.json;
    let command = cli
        .command
        .unwrap_or_else(|| Command::Region(CaptureArgs::default()));

    if matches!(&command, Command::List) {
        let result = match wayland::list_outputs() {
            Ok(outputs) => OutputList::success(outputs),
            Err(error) => OutputList::error(error),
        };

        if json {
            println!(
                "{}",
                serde_json::to_string(&result).expect("result is serializable")
            );
        } else if let Some(outputs) = result.outputs() {
            for output in outputs {
                println!(
                    "{} {}x{} scale={}{}",
                    output.name,
                    output.width,
                    output.height,
                    output.scale,
                    output
                        .position
                        .map(|(x, y)| format!(" position={x},{y}"))
                        .unwrap_or_default()
                );
            }
        } else {
            eprintln!(
                "{}",
                result.error_message().unwrap_or("output listing failed")
            );
        }

        std::process::exit(if result.status == "success" { 0 } else { 1 });
    }

    let Some((args, target)) = capture_args(&command) else {
        let result = CaptureResult::error(CaptureError::unsupported(command.mode_name()));
        emit_capture_result(result, json);
        std::process::exit(2);
    };

    let result = if args.stdout && json {
        CaptureResult::error(CaptureError::usage(
            "--stdout cannot be combined with --json",
        ))
    } else {
        let capture = match target {
            CaptureTarget::Focused => {
                wayland::capture_output(None, matches!(args.cursor, cli::CursorMode::On))
            }
            CaptureTarget::Output(name) => {
                wayland::capture_output(Some(name), matches!(args.cursor, cli::CursorMode::On))
            }
            CaptureTarget::All => wayland::capture_all(matches!(args.cursor, cli::CursorMode::On)),
            CaptureTarget::Window => window::capture(matches!(args.cursor, cli::CursorMode::On)),
            CaptureTarget::Region(rect) => wayland::capture_output_region(
                None,
                rect,
                matches!(args.cursor, cli::CursorMode::On),
            ),
            CaptureTarget::InteractiveRegion => capture_interactive_region(
                args.reset,
                matches!(args.cursor, cli::CursorMode::On),
                args.no_confirm,
            ),
            CaptureTarget::Last => capture_last_region(
                args.reset,
                matches!(args.cursor, cli::CursorMode::On),
                args.no_confirm,
            ),
            CaptureTarget::InteractiveScroll => capture_interactive_scroll(
                args.interval,
                matches!(args.cursor, cli::CursorMode::On),
            ),
        };
        match capture {
            Ok(image) => save_capture(image, args),
            Err(error) if error == "selection cancelled" => CaptureResult::aborted(),
            Err(error) => CaptureResult::error(CaptureError::runtime(error)),
        }
    };

    let exit_code = if result.status == "success" { 0 } else { 1 };
    if !(args.stdout && result.status == "success") {
        emit_capture_result(result, json);
    }
    std::process::exit(exit_code);
}

fn capture_interactive_region(
    reset: bool,
    cursor: bool,
    no_confirm: bool,
) -> Result<wayland::CapturedImage, String> {
    let initial_selection = if reset {
        let _ = state::clear();
        None
    } else {
        state::region()
    };
    let frozen_outputs = wayland::capture_outputs(cursor)?;
    let background = selector::backgrounds_from_captures(&frozen_outputs);
    let selection =
        selector::select_region_with_background(background, no_confirm, initial_selection)?;
    let output_name = selection
        .output_name
        .ok_or_else(|| "region selector did not identify an output".to_string())?;
    let rect = Rect {
        x: selection.rect.x,
        y: selection.rect.y,
        width: selection.rect.width as u32,
        height: selection.rect.height as u32,
    };
    let _ = state::save_region(rect);
    let outputs = wayland::list_outputs()?;
    let output = outputs
        .iter()
        .find(|output| output.name == output_name)
        .ok_or_else(|| format!("output disappeared during selection: {output_name}"))?;
    // Consistent with the selector's own fallback when the compositor
    // reports no position: the selection rect was built assuming the origin.
    let (output_x, output_y) = output.position.unwrap_or((0, 0));
    let local = Rect {
        x: rect.x - output_x,
        y: rect.y - output_y,
        width: rect.width,
        height: rect.height,
    };
    if wayland::region_fits_output(output, &local) {
        let frozen_output = frozen_outputs
            .into_iter()
            .find(|output| output.name == output_name)
            .ok_or_else(|| format!("missing frozen capture for output {output_name}"))?;
        let logical_width = (output.width as f64 / output.scale).round().max(1.0);
        let effective_scale = frozen_output.image.width as f64 / logical_width;
        return wayland::crop_captured_local_region_with_scale(
            frozen_output.image,
            local,
            effective_scale,
        );
    }
    // The region spans several outputs: composite the frozen captures.
    wayland::crop_frozen_global_region(&frozen_outputs, &outputs, rect)
}

fn capture_interactive_scroll(
    interval_ms: u64,
    cursor: bool,
) -> Result<wayland::CapturedImage, String> {
    // Scroll selection must stay live. The selector supplies only a translucent
    // dim layer; frames are captured after the user confirms the region.
    let (_, image) = selector::select_scroll(interval_ms, cursor)?;
    Ok(image)
}

enum CaptureTarget<'a> {
    Focused,
    Output(&'a str),
    All,
    Window,
    Region(Rect),
    InteractiveRegion,
    InteractiveScroll,
    Last,
}

fn capture_args(command: &Command) -> Option<(&CaptureArgs, CaptureTarget<'_>)> {
    match command {
        Command::Region(args) => Some((
            args,
            match (args.x, args.y, args.width, args.height) {
                (Some(x), Some(y), Some(width), Some(height)) => CaptureTarget::Region(normalize(
                    (x, y),
                    (
                        x.saturating_add(width as i32),
                        y.saturating_add(height as i32),
                    ),
                )),
                _ => CaptureTarget::InteractiveRegion,
            },
        )),
        Command::Full(args) => Some((args, CaptureTarget::Focused)),
        Command::Output(args) => Some((
            &args.capture,
            match args.output.as_deref().or(args.name.as_deref()) {
                Some(name) => CaptureTarget::Output(name),
                None => CaptureTarget::Focused,
            },
        )),
        Command::All(args) => Some((args, CaptureTarget::All)),
        Command::Window(args) => Some((args, CaptureTarget::Window)),
        Command::Last(args) => Some((args, CaptureTarget::Last)),
        Command::Scroll(args) => Some((args, CaptureTarget::InteractiveScroll)),
        _ => None,
    }
}

fn capture_last_region(
    reset: bool,
    cursor: bool,
    no_confirm: bool,
) -> Result<wayland::CapturedImage, String> {
    if reset {
        let _ = state::clear();
    }
    match state::region() {
        Some(region) => wayland::capture_global_region(region, cursor),
        None => selector::select_region(no_confirm).and_then(|region| {
            let _ = state::save_region(region);
            wayland::capture_global_region(region, cursor)
        }),
    }
}

fn save_capture(image: wayland::CapturedImage, args: &CaptureArgs) -> CaptureResult {
    let format = output_format(args.format);
    let encoded = match encode_image(&image.image, format, args.quality) {
        Ok(encoded) => encoded,
        Err(error) => return CaptureResult::error(CaptureError::runtime(error)),
    };

    if !args.no_clipboard {
        let (clipboard_data, clipboard_mime) = if matches!(args.format, cli::ImageFormat::Ppm) {
            match encode_image(&image.image, ImageFormat::Png, args.quality) {
                Ok(data) => (data, "image/png"),
                Err(error) => return CaptureResult::error(CaptureError::runtime(error)),
            }
        } else {
            (encoded.clone(), mime_type(args.format))
        };
        if let Err(error) = copy_to_clipboard(&clipboard_data, clipboard_mime) {
            return CaptureResult::error(CaptureError::runtime(error));
        }
    }

    if args.stdout {
        if let Err(error) = io::stdout().write_all(&encoded) {
            return CaptureResult::error(CaptureError::runtime(error.to_string()));
        }
        if !args.no_notify {
            notify_capture(None, !args.no_clipboard);
        }
        return CaptureResult::success(
            "-".to_string(),
            image.width,
            image.height,
            image.scale,
            mime_type(args.format),
        );
    }

    if args.no_file {
        if !args.no_notify {
            notify_capture(None, !args.no_clipboard);
        }
        return CaptureResult::success(
            "clipboard".to_string(),
            image.width,
            image.height,
            image.scale,
            mime_type(args.format),
        );
    }

    let directory = args
        .directory
        .as_ref()
        .map(PathBuf::from)
        .unwrap_or_else(default_output_directory);
    if let Err(error) = fs::create_dir_all(&directory) {
        return CaptureResult::error(CaptureError::runtime(error.to_string()));
    }

    let filename = args
        .filename
        .clone()
        .unwrap_or_else(|| default_screenshot_filename(args.format));
    let path = directory.join(filename);
    if let Err(error) = fs::write(&path, &encoded) {
        return CaptureResult::error(CaptureError::runtime(error.to_string()));
    }
    if !args.no_notify {
        notify_capture(Some(&path), !args.no_clipboard);
    }

    CaptureResult::success(
        path.to_string_lossy().into_owned(),
        image.width,
        image.height,
        image.scale,
        mime_type(args.format),
    )
}

fn output_format(format: cli::ImageFormat) -> ImageFormat {
    match format {
        cli::ImageFormat::Png => ImageFormat::Png,
        cli::ImageFormat::Jpg => ImageFormat::Jpeg,
        cli::ImageFormat::Ppm => ImageFormat::Pnm,
    }
}

fn mime_type(format: cli::ImageFormat) -> &'static str {
    match format {
        cli::ImageFormat::Png => "image/png",
        cli::ImageFormat::Jpg => "image/jpeg",
        cli::ImageFormat::Ppm => "image/x-portable-pixmap",
    }
}

fn encode_image(
    image: &image::RgbaImage,
    format: ImageFormat,
    quality: u8,
) -> Result<Vec<u8>, String> {
    let mut encoded = Cursor::new(Vec::new());
    let dynamic = DynamicImage::ImageRgba8(image.clone());
    if format == ImageFormat::Jpeg {
        image::codecs::jpeg::JpegEncoder::new_with_quality(&mut encoded, quality)
            .encode_image(&dynamic)
            .map_err(|error| error.to_string())?;
    } else {
        dynamic
            .write_to(&mut encoded, format)
            .map_err(|error| error.to_string())?;
    }
    Ok(encoded.into_inner())
}

fn copy_to_clipboard(data: &[u8], mime: &str) -> Result<(), String> {
    let mut child = ProcessCommand::new("dms")
        .args(["cl", "copy", "--type", mime])
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| format!("start dms clipboard: {error}"))?;

    child
        .stdin
        .take()
        .ok_or_else(|| "open dms clipboard input".to_string())?
        .write_all(data)
        .map_err(|error| format!("write image to dms clipboard: {error}"))?;

    let output = child
        .wait_with_output()
        .map_err(|error| format!("wait for dms clipboard: {error}"))?;
    if output.status.success() {
        return Ok(());
    }

    let detail = String::from_utf8_lossy(&output.stderr).trim().to_string();
    Err(if detail.is_empty() {
        format!("dms clipboard exited with {}", output.status)
    } else {
        format!("dms clipboard failed: {detail}")
    })
}

fn notify_capture(path: Option<&PathBuf>, copied: bool) {
    let summary = "Screenshot captured";
    let body = path
        .map(|path| {
            let filename = path
                .file_name()
                .and_then(|name| name.to_str())
                .unwrap_or_default();
            if copied {
                format!("{filename}\nCopied to clipboard")
            } else {
                filename.to_string()
            }
        })
        .unwrap_or_else(|| {
            if copied {
                "Copied to clipboard".to_string()
            } else {
                String::new()
            }
        });

    let mut command = ProcessCommand::new("dms");
    command.args(["notify", summary, &body]);
    if let Some(path) = path {
        command.args(["--file", &path.to_string_lossy()]);
    }

    let _ = command.stdout(Stdio::null()).stderr(Stdio::null()).status();
}

fn default_output_directory() -> PathBuf {
    let pictures = std::env::var_os("XDG_PICTURES_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join("Pictures")))
        .unwrap_or_else(|| PathBuf::from("."));
    pictures.join("Screenshots")
}

fn default_screenshot_filename(format: cli::ImageFormat) -> String {
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs() as libc::time_t)
        .unwrap_or_default();
    let mut local_time = std::mem::MaybeUninit::<libc::tm>::uninit();
    let converted = unsafe { libc::localtime_r(&timestamp, local_time.as_mut_ptr()) };
    if converted.is_null() {
        return "screenshot.png".to_string();
    }
    let local_time = unsafe { local_time.assume_init() };
    let extension = match format {
        cli::ImageFormat::Png => "png",
        cli::ImageFormat::Jpg => "jpg",
        cli::ImageFormat::Ppm => "ppm",
    };
    format!(
        "screenshot_{:04}-{:02}-{:02}_{:02}-{:02}-{:02}.{extension}",
        local_time.tm_year + 1900,
        local_time.tm_mon + 1,
        local_time.tm_mday,
        local_time.tm_hour,
        local_time.tm_min,
        local_time.tm_sec,
    )
}

fn emit_capture_result(result: CaptureResult, json: bool) {
    if json {
        println!(
            "{}",
            serde_json::to_string(&result).expect("result is serializable")
        );
    } else if result.status == "success" {
        println!("{}", result.path.unwrap_or_default());
    } else {
        eprintln!("{}", result.error_message().unwrap_or("capture failed"));
    }
}
