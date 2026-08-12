use super::types::Rect;

#[derive(Clone, Debug, Default, Eq, PartialEq)]
pub struct SelectionBox {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    pub label: Option<String>,
}

impl SelectionBox {
    pub fn intersect(a: &Self, b: &Self) -> bool {
        a.x < b.x + b.width && a.x + a.width > b.x && a.y < b.y + b.height && a.height + a.y > b.y
    }

    pub fn contains(box_: &Self, x: i32, y: i32) -> bool {
        box_.x <= x && box_.x + box_.width > x && box_.y <= y && box_.y + box_.height > y
    }

    pub fn from_rect(rect: &Rect) -> Self {
        Self {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
            label: None,
        }
    }

    pub fn to_rect(&self) -> Rect {
        Rect {
            x: self.x,
            y: self.y,
            width: self.width,
            height: self.height,
        }
    }
}

impl From<Rect> for SelectionBox {
    fn from(value: Rect) -> Self {
        Self::from_rect(&value)
    }
}

impl From<&Rect> for SelectionBox {
    fn from(value: &Rect) -> Self {
        Self::from_rect(value)
    }
}
