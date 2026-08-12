use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::time::Duration;

use crate::wayland::CapturedImage;

pub fn capture_window(cursor: bool) -> Result<CapturedImage, String> {
    let socket = std::env::var("NIRI_SOCKET")
        .map_err(|_| "NIRI_SOCKET is not set; Niri window capture is unavailable".to_string())?;
    let path = temporary_path();
    let events = subscribe_events(&socket)?;
    request_screenshot(&socket, &path, cursor)?;
    wait_for_capture(events, &path)?;

    let result = image::open(&path)
        .map_err(|error| format!("decode Niri window screenshot: {error}"))
        .map(|image| {
            let image = image.to_rgba8();
            CapturedImage {
                width: image.width(),
                height: image.height(),
                image,
                scale: 1.0,
            }
        });
    let _ = std::fs::remove_file(&path);
    result
}

fn temporary_path() -> PathBuf {
    let directory = std::env::var_os("XDG_RUNTIME_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(std::env::temp_dir);
    directory.join(format!("dms-window-{}.png", std::process::id()))
}

fn connect(socket: &str) -> Result<UnixStream, String> {
    let stream =
        UnixStream::connect(socket).map_err(|error| format!("connect to Niri socket: {error}"))?;
    stream
        .set_read_timeout(Some(Duration::from_secs(5)))
        .map_err(|error| format!("configure Niri socket timeout: {error}"))?;
    stream
        .set_write_timeout(Some(Duration::from_secs(3)))
        .map_err(|error| format!("configure Niri socket write timeout: {error}"))?;
    Ok(stream)
}

fn subscribe_events(socket: &str) -> Result<UnixStream, String> {
    let mut stream = connect(socket)?;
    stream
        .write_all(b"\"EventStream\"\n")
        .map_err(|error| format!("subscribe to Niri events: {error}"))?;
    Ok(stream)
}

fn request_screenshot(socket: &str, path: &PathBuf, cursor: bool) -> Result<(), String> {
    let mut stream = connect(socket)?;
    let request = serde_json::json!({
        "Action": {
            "ScreenshotWindow": {
                "id": null,
                "write_to_disk": true,
                "show_pointer": cursor,
                "path": path,
            }
        }
    });
    let mut payload = serde_json::to_vec(&request)
        .map_err(|error| format!("encode Niri screenshot request: {error}"))?;
    payload.push(b'\n');
    stream
        .write_all(&payload)
        .map_err(|error| format!("send Niri screenshot request: {error}"))?;

    let mut reply = String::new();
    BufReader::new(stream)
        .read_line(&mut reply)
        .map_err(|error| format!("read Niri screenshot reply: {error}"))?;
    let reply: serde_json::Value = serde_json::from_str(&reply)
        .map_err(|error| format!("parse Niri screenshot reply: {error}"))?;
    if let Some(error) = reply.get("Err").and_then(serde_json::Value::as_str) {
        return Err(format!("Niri screenshot: {error}"));
    }
    Ok(())
}

fn wait_for_capture(mut stream: UnixStream, path: &PathBuf) -> Result<(), String> {
    let mut line = String::new();
    let mut reader = BufReader::new(&mut stream);
    loop {
        line.clear();
        if reader
            .read_line(&mut line)
            .map_err(|error| format!("read Niri screenshot event: {error}"))?
            == 0
        {
            return Err("Niri event stream closed before screenshot completed".to_string());
        }
        let event: serde_json::Value = match serde_json::from_str(&line) {
            Ok(event) => event,
            Err(_) => continue,
        };
        if event
            .get("ScreenshotCaptured")
            .and_then(|value| value.get("path"))
            .and_then(serde_json::Value::as_str)
            .map(PathBuf::from)
            .as_ref()
            == Some(path)
        {
            return Ok(());
        }
    }
}
