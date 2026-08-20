use std::process::Command;

use serde::Deserialize;

use crate::{niri, selection::Rect, wayland::CapturedImage};

pub fn capture(cursor: bool) -> Result<CapturedImage, String> {
    if std::env::var_os("NIRI_SOCKET").is_some() {
        return niri::capture_window(cursor);
    }
    if std::env::var_os("MANGO_INSTANCE_SIGNATURE").is_some() {
        return capture_mango(cursor);
    }
    if std::env::var_os("HYPRLAND_INSTANCE_SIGNATURE").is_some() {
        return capture_hyprland(cursor);
    }
    Err("window capture requires Niri, Hyprland, or Mango".to_string())
}

#[derive(Debug, Deserialize)]
struct HyprWindow {
    at: [i32; 2],
    size: [i32; 2],
}

#[derive(Debug, Deserialize)]
struct HyprMonitor {
    name: String,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
    scale: f64,
}

fn capture_hyprland(cursor: bool) -> Result<CapturedImage, String> {
    let window: HyprWindow = command_json("hyprctl", &["-j", "activewindow"], "activewindow")?;
    let monitors: Vec<HyprMonitor> = command_json("hyprctl", &["-j", "monitors"], "monitors")?;
    let monitor = monitors
        .iter()
        .find(|monitor| contains_window(monitor, window.at, window.size))
        .ok_or_else(|| "could not find output for active Hyprland window".to_string())?;
    let scale = crate::wayland::normalize_scale(monitor.scale);
    let width = window.size[0].max(0) as u32;
    let height = window.size[1].max(0) as u32;
    if width == 0 || height == 0 {
        return Err("no active Hyprland window".to_string());
    }
    let region = Rect {
        x: window.at[0] - monitor.x,
        y: window.at[1] - monitor.y,
        width,
        height,
    };
    capture_monitor_region(&monitor.name, region, scale, cursor)
}

fn contains_window(monitor: &HyprMonitor, at: [i32; 2], size: [i32; 2]) -> bool {
    let center_x = at[0] + size[0] / 2;
    let center_y = at[1] + size[1] / 2;
    let scale = crate::wayland::normalize_scale(monitor.scale);
    let logical_width = (monitor.width as f64 / scale) as i32;
    let logical_height = (monitor.height as f64 / scale) as i32;
    center_x >= monitor.x
        && center_y >= monitor.y
        && center_x < monitor.x + logical_width
        && center_y < monitor.y + logical_height
}

#[derive(Debug, Deserialize)]
struct MangoClient {
    monitor: String,
    is_focused: bool,
    x: i32,
    y: i32,
    width: i32,
    height: i32,
}

#[derive(Debug, Deserialize)]
struct MangoClients {
    clients: Vec<MangoClient>,
}

#[derive(Debug, Deserialize)]
struct MangoMonitor {
    name: String,
    x: i32,
    y: i32,
    scale: f64,
}

#[derive(Debug, Deserialize)]
struct MangoMonitors {
    monitors: Vec<MangoMonitor>,
}

fn capture_mango(cursor: bool) -> Result<CapturedImage, String> {
    let clients: MangoClients = command_json("mmsg", &["get", "all-clients"], "all-clients")?;
    let client = clients
        .clients
        .into_iter()
        .find(|client| client.is_focused)
        .ok_or_else(|| "no focused Mango window".to_string())?;
    if client.width <= 0 || client.height <= 0 {
        return Err("no active Mango window".to_string());
    }

    let monitors: MangoMonitors = command_json("mmsg", &["get", "all-monitors"], "all-monitors")?;
    let monitor = monitors
        .monitors
        .iter()
        .find(|monitor| monitor.name == client.monitor)
        .ok_or_else(|| "could not find output for active Mango window".to_string())?;
    let region = Rect {
        x: client.x - monitor.x,
        y: client.y - monitor.y,
        width: client.width as u32,
        height: client.height as u32,
    };
    capture_monitor_region(
        &monitor.name,
        region,
        crate::wayland::normalize_scale(monitor.scale),
        cursor,
    )
}

fn capture_monitor_region(
    monitor_name: &str,
    region: Rect,
    scale: f64,
    cursor: bool,
) -> Result<CapturedImage, String> {
    crate::wayland::capture_output_region_logical(Some(monitor_name), region, cursor).map(
        |mut image| {
            image.scale = scale;
            image
        },
    )
}

fn command_json<T: for<'de> Deserialize<'de>>(
    command: &str,
    args: &[&str],
    description: &str,
) -> Result<T, String> {
    let output = Command::new(command)
        .args(args)
        .output()
        .map_err(|error| format!("run {command} {description}: {error}"))?;
    if !output.status.success() {
        return Err(format!(
            "{command} {description} failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    serde_json::from_slice(&output.stdout)
        .map_err(|error| format!("parse {command} {description}: {error}"))
}

#[cfg(test)]
mod tests {
    use super::{HyprMonitor, contains_window};

    #[test]
    fn finds_monitor_from_window_center() {
        let monitor = HyprMonitor {
            name: "DP-1".to_string(),
            x: 1920,
            y: 0,
            width: 3840,
            height: 2160,
            scale: 2.0,
        };
        assert!(contains_window(&monitor, [2200, 100], [500, 400]));
        assert!(!contains_window(&monitor, [100, 100], [500, 400]));
    }
}
