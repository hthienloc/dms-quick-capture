#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct BackgroundImage {
    pub width: u32,
    pub height: u32,
    pub stride: usize,
    pub pixels: Vec<u8>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Selection {
    pub rect: Rect,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Colors {
    pub background: u32,
    pub border: u32,
    pub selection: u32,
}

impl Default for Colors {
    fn default() -> Self {
        Self {
            background: 0x00000066,
            border: 0xFFFFFFFF,
            selection: 0x00000000,
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct SelectOptions {
    pub display_dimensions: bool,
    pub crosshairs: bool,
    pub colors: Colors,
    pub border_weight: i32,
    pub aspect_ratio: Option<(i32, i32)>,
    pub single_point: bool,
    pub no_confirm: bool,
    pub initial_selection: Option<Rect>,
    pub scroll: bool,
    pub scroll_interval_ms: u64,
    pub capture_cursor: bool,
}

impl Default for SelectOptions {
    fn default() -> Self {
        Self {
            display_dimensions: false,
            crosshairs: false,
            colors: Colors::default(),
            border_weight: 2,
            aspect_ratio: None,
            single_point: false,
            no_confirm: false,
            initial_selection: None,
            scroll: false,
            scroll_interval_ms: 45,
            capture_cursor: false,
        }
    }
}
