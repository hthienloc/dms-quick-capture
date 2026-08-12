#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
}

pub fn normalize(anchor: (i32, i32), current: (i32, i32)) -> Rect {
    let x = anchor.0.min(current.0);
    let y = anchor.1.min(current.1);
    Rect {
        x,
        y,
        width: anchor.0.abs_diff(current.0),
        height: anchor.1.abs_diff(current.1),
    }
}

pub fn clamp(rect: Rect, bounds: Rect) -> Rect {
    let x = rect.x.max(bounds.x).min(bounds.x + bounds.width as i32);
    let y = rect.y.max(bounds.y).min(bounds.y + bounds.height as i32);
    let right = (rect.x + rect.width as i32).min(bounds.x + bounds.width as i32);
    let bottom = (rect.y + rect.height as i32).min(bounds.y + bounds.height as i32);
    Rect {
        x,
        y,
        width: right.saturating_sub(x) as u32,
        height: bottom.saturating_sub(y) as u32,
    }
}

#[cfg(test)]
mod tests {
    use super::{Rect, clamp, normalize};

    #[test]
    fn normalize_supports_dragging_in_any_direction() {
        assert_eq!(
            normalize((100, 80), (20, 30)),
            Rect {
                x: 20,
                y: 30,
                width: 80,
                height: 50
            }
        );
    }

    #[test]
    fn clamp_keeps_selection_inside_output() {
        assert_eq!(
            clamp(
                Rect {
                    x: -10,
                    y: 20,
                    width: 80,
                    height: 100
                },
                Rect {
                    x: 0,
                    y: 0,
                    width: 100,
                    height: 100
                }
            ),
            Rect {
                x: 0,
                y: 20,
                width: 70,
                height: 80
            }
        );
    }
}
