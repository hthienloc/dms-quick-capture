use std::{fs, path::PathBuf};

use serde::{Deserialize, Serialize};

use crate::selection::Rect;

#[derive(Debug, Default, Deserialize, Serialize)]
pub struct PersistentState {
    #[serde(default)]
    pub last_region: SavedRegion,
}

#[derive(Debug, Default, Deserialize, Serialize)]
pub struct SavedRegion {
    #[serde(default)]
    pub x: i32,
    #[serde(default)]
    pub y: i32,
    #[serde(default)]
    pub width: i32,
    #[serde(default)]
    pub height: i32,
    #[serde(default, skip_serializing_if = "String::is_empty")]
    pub output: String,
}

fn state_path() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
        .unwrap_or_else(|| PathBuf::from("."))
        .join("dms/screenshot-state.json")
}

pub fn load() -> PersistentState {
    let Ok(data) = fs::read(state_path()) else {
        return PersistentState::default();
    };
    serde_json::from_slice(&data).unwrap_or_default()
}

pub fn save_region(region: Rect) -> Result<(), String> {
    let path = state_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|error| format!("create screenshot state dir: {error}"))?;
    }
    let state = PersistentState {
        last_region: SavedRegion {
            x: region.x,
            y: region.y,
            width: region.width as i32,
            height: region.height as i32,
            output: String::new(),
        },
    };
    let data = serde_json::to_vec_pretty(&state)
        .map_err(|error| format!("encode screenshot state: {error}"))?;
    fs::write(path, data).map_err(|error| format!("save screenshot state: {error}"))
}

pub fn clear() -> Result<(), String> {
    save_region(Rect {
        x: 0,
        y: 0,
        width: 0,
        height: 0,
    })
}

pub fn region() -> Option<Rect> {
    let saved = load().last_region;
    if saved.width <= 0 || saved.height <= 0 {
        return None;
    }
    Some(Rect {
        x: saved.x,
        y: saved.y,
        width: saved.width as u32,
        height: saved.height as u32,
    })
}
