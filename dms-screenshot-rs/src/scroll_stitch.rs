const ACCEPT_DIFF: f32 = 9.0;
const ROW_MATCH_TOL: f32 = 4.0;
const MIN_COMPARE: usize = 50;
const MIN_ACTIVE: usize = 12;
const MIN_APPEND: usize = 15;
const PREDICT_WINDOW: i32 = 160;
const COARSE_STEP: i32 = 8;
const MIN_MATCH_MARGIN: f32 = 0.5;
const SIGNATURE_COLUMNS: usize = 18;
const SIGNATURE_ROWS: usize = 24;
const SEAM_IGNORE_TOP: f32 = 0.10;
const SEAM_IGNORE_BOTTOM: f32 = 0.08;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum StitchOutcome {
    FirstFrame { added_rows: usize },
    Appended { added_rows: usize, confidence: f32 },
    Duplicate,
    WaitingForOverlap,
    Rejected,
    Full,
}

#[derive(Debug, Clone, Copy, Default)]
struct RowSignature([f32; 8]);

pub struct ScrollStitcher {
    width: usize,
    stride: usize,
    max_rows: usize,
    canvas: Vec<u8>,
    rows: Vec<RowSignature>,
    anchor: i32,
    last_frame: Option<Vec<RowSignature>>,
    last_offset: i32,
    previous_raw_signature: Option<Vec<f32>>,
    previous_baseline: Option<f32>,
    previous_active_rows: usize,
    unmatched: bool,
}

impl ScrollStitcher {
    pub fn new(width: usize, max_canvas_bytes: usize, max_rows_cap: usize) -> Self {
        let stride = width.saturating_mul(4);
        let max_rows = if stride == 0 {
            0
        } else {
            (max_canvas_bytes / stride).min(max_rows_cap)
        };
        Self {
            width,
            stride,
            max_rows,
            canvas: Vec::new(),
            rows: Vec::new(),
            anchor: 0,
            last_frame: None,
            last_offset: 0,
            previous_raw_signature: None,
            previous_baseline: None,
            previous_active_rows: 0,
            unmatched: false,
        }
    }

    pub fn observe(&mut self, frame: &[u8], height: usize) -> StitchOutcome {
        if self.width == 0 || height == 0 || frame.len() < self.stride.saturating_mul(height) {
            return StitchOutcome::Rejected;
        }
        if self.rows.len() >= self.max_rows {
            return StitchOutcome::Full;
        }

        let features = FrameFeatures::from_rgba(frame, self.width, height);
        let duplicate = self
            .previous_raw_signature
            .as_ref()
            .is_some_and(|previous| {
                duplicate_signature(
                    previous,
                    &features.raw_signature,
                    self.previous_baseline.unwrap_or_default(),
                    features.baseline,
                    self.previous_active_rows,
                    features.active.iter().filter(|active| **active).count(),
                )
            });
        self.previous_raw_signature = Some(features.raw_signature.clone());
        self.previous_baseline = Some(features.baseline);
        self.previous_active_rows = features.active.iter().filter(|active| **active).count();

        if self.rows.is_empty() {
            let added = self.append_rows(frame, &features.rows, 0);
            self.last_frame = Some(features.rows);
            self.unmatched = false;
            return StitchOutcome::FirstFrame { added_rows: added };
        }

        if duplicate && !self.unmatched {
            return StitchOutcome::Duplicate;
        }

        let Some((position, confidence)) = self.locate_frame(&features.rows, &features.active)
        else {
            self.unmatched = true;
            return StitchOutcome::WaitingForOverlap;
        };

        let delta = position - self.anchor;
        let mut added = 0;
        let frame_len = features.rows.len();
        if position + frame_len as i32 - self.rows.len() as i32 >= MIN_APPEND as i32 {
            let overlap = (position + frame_len as i32 - self.rows.len() as i32) as usize;
            added += self.append_rows(frame, &features.rows, frame_len - overlap);
        }
        if -position >= MIN_APPEND as i32 {
            let prepend = (-position) as usize;
            added += self.prepend_rows(frame, &features.rows, prepend);
            self.anchor += prepend as i32;
        }

        self.anchor = position.max(0);
        self.last_offset = delta;
        self.last_frame = Some(features.rows);
        self.unmatched = false;

        if self.rows.len() >= self.max_rows {
            return StitchOutcome::Full;
        }
        if added == 0 {
            StitchOutcome::Duplicate
        } else {
            StitchOutcome::Appended {
                added_rows: added,
                confidence,
            }
        }
    }

    pub fn canvas(&self) -> &[u8] {
        &self.canvas
    }

    pub fn rows(&self) -> usize {
        self.rows.len()
    }

    fn locate_frame(&self, frame: &[RowSignature], active: &[bool]) -> Option<(i32, f32)> {
        let predicted = self.anchor + self.adjacent_offset(frame, active);
        self.scan_positions(frame, active, predicted, true)
            .or_else(|| self.scan_positions(frame, active, predicted, false))
    }

    fn adjacent_offset(&self, frame: &[RowSignature], active: &[bool]) -> i32 {
        let Some(previous) = self.last_frame.as_ref() else {
            return 0;
        };
        if previous.len() != frame.len() {
            return 0;
        }
        let limit = frame.len().saturating_sub(MIN_COMPARE + 1) as i32;
        let mut best = (self.last_offset, f32::MAX);
        for distance in 0..=limit {
            for offset in [self.last_offset - distance, self.last_offset + distance] {
                if offset < -limit || offset > limit {
                    continue;
                }
                let (diff, active_matches) = pair_diff(frame, previous, active, offset);
                if active_matches >= MIN_ACTIVE && diff < best.1 {
                    best = (offset, diff);
                }
                if best.1 < 0.25 {
                    return best.0;
                }
            }
        }
        best.0
    }

    fn scan_positions(
        &self,
        frame: &[RowSignature],
        active: &[bool],
        predicted: i32,
        near_only: bool,
    ) -> Option<(i32, f32)> {
        let height = frame.len() as i32;
        let canvas_len = self.rows.len() as i32;
        let min_position = MIN_COMPARE as i32 - height;
        let max_position = canvas_len - MIN_COMPARE as i32;
        if min_position > max_position {
            return None;
        }

        let mut candidates = Vec::new();
        let mut consider = |position: i32| {
            if position < min_position || position > max_position {
                return;
            }
            let (diff, count, active_matches) = self.canvas_diff(frame, active, position);
            if count < MIN_COMPARE || active_matches < MIN_ACTIVE || diff > ACCEPT_DIFF {
                return;
            }
            if !candidates
                .iter()
                .any(|(candidate, _, _)| *candidate == position)
            {
                candidates.push((position, diff, (position - predicted).abs()));
            }
        };

        if near_only {
            for position in (predicted - PREDICT_WINDOW)..=(predicted + PREDICT_WINDOW) {
                consider(position);
            }
            for position in (canvas_len - height)..=max_position {
                consider(position);
            }
            for position in min_position..=0 {
                consider(position);
            }
        } else {
            let mut position = min_position;
            while position <= max_position {
                consider(position);
                position += COARSE_STEP;
            }
            drop(consider);
            let winner = candidates
                .iter()
                .min_by_key(|(position, _, _)| *position)
                .map(|(position, _, _)| *position);
            if let Some(winner) = winner {
                for position in (winner - COARSE_STEP + 1)..winner + COARSE_STEP {
                    if position < min_position || position > max_position {
                        continue;
                    }
                    let (diff, count, active_matches) = self.canvas_diff(frame, active, position);
                    if count >= MIN_COMPARE
                        && active_matches >= MIN_ACTIVE
                        && diff <= ACCEPT_DIFF
                        && !candidates
                            .iter()
                            .any(|(candidate, _, _)| *candidate == position)
                    {
                        candidates.push((position, diff, (position - predicted).abs()));
                    }
                }
            }
        }

        let best = if near_only {
            candidates.iter().min_by(|left, right| {
                left.1
                    .total_cmp(&right.1)
                    .then_with(|| left.2.cmp(&right.2))
            })
        } else {
            candidates.iter().min_by(|left, right| {
                left.2
                    .cmp(&right.2)
                    .then_with(|| left.1.total_cmp(&right.1))
            })
        }?;
        let second_diff = candidates
            .iter()
            .filter(|candidate| (candidate.0 - best.0).abs() > 4)
            .map(|candidate| candidate.1)
            .min_by(f32::total_cmp);
        if second_diff.is_some_and(|second| second - best.1 < MIN_MATCH_MARGIN) {
            return None;
        }
        let confidence = (1.0 - best.1 / ACCEPT_DIFF).clamp(0.0, 1.0);
        Some((best.0, confidence))
    }

    fn canvas_diff(
        &self,
        frame: &[RowSignature],
        active: &[bool],
        position: i32,
    ) -> (f32, usize, usize) {
        let (top, bottom) = ignored_edges(frame.len());
        let start = top.max((-position).max(0) as usize);
        let end = (frame.len() - bottom).min((self.rows.len() as i32 - position) as usize);
        if end <= start {
            return (f32::MAX, 0, 0);
        }
        let mut sum = 0.0;
        let mut active_matches = 0;
        for index in start..end {
            let canvas_index = (position + index as i32) as usize;
            let diff = row_diff(frame[index], self.rows[canvas_index]);
            sum += diff;
            if active[index] && diff <= ROW_MATCH_TOL {
                active_matches += 1;
            }
        }
        (sum / (end - start) as f32, end - start, active_matches)
    }

    fn append_rows(&mut self, frame: &[u8], rows: &[RowSignature], from: usize) -> usize {
        let count = rows
            .len()
            .saturating_sub(from)
            .min(self.max_rows - self.rows.len());
        if count == 0 {
            return 0;
        }
        let start = from * self.stride;
        let end = start + count * self.stride;
        self.canvas.extend_from_slice(&frame[start..end]);
        self.rows.extend_from_slice(&rows[from..from + count]);
        count
    }

    fn prepend_rows(&mut self, frame: &[u8], rows: &[RowSignature], count: usize) -> usize {
        let count = count.min(self.max_rows - self.rows.len());
        if count == 0 {
            return 0;
        }
        let mut canvas = Vec::with_capacity(self.canvas.len() + count * self.stride);
        canvas.extend_from_slice(&frame[..count * self.stride]);
        canvas.extend_from_slice(&self.canvas);
        self.canvas = canvas;

        let mut signatures = Vec::with_capacity(self.rows.len() + count);
        signatures.extend_from_slice(&rows[..count]);
        signatures.extend_from_slice(&self.rows);
        self.rows = signatures;
        count
    }
}

struct FrameFeatures {
    rows: Vec<RowSignature>,
    active: Vec<bool>,
    raw_signature: Vec<f32>,
    baseline: f32,
}

impl FrameFeatures {
    fn from_rgba(data: &[u8], width: usize, height: usize) -> Self {
        let mut rows = Vec::with_capacity(height);
        for y in 0..height {
            let row = &data[y * width * 4..(y + 1) * width * 4];
            let mut bands = [0.0; 7];
            for (band, (start, end)) in [(0.08, 0.32), (0.34, 0.66), (0.68, 0.92)]
                .into_iter()
                .enumerate()
            {
                let first = (width as f32 * start) as usize;
                let last = ((width as f32 * end) as usize).max(first + 1).min(width);
                let mut total = 0.0;
                for x in first..last {
                    let offset = x * 4;
                    total += luminance(row[offset], row[offset + 1], row[offset + 2]);
                }
                bands[band] = total / (last - first) as f32;
            }
            for (sample, position) in [0.18, 0.38, 0.58, 0.78].into_iter().enumerate() {
                let x = ((width as f32 * position) as usize).min(width - 1);
                let offset = x * 4;
                bands[3 + sample] = luminance(row[offset], row[offset + 1], row[offset + 2]);
            }
            let mut signature = [0.0; 8];
            signature[..7].copy_from_slice(&bands);
            rows.push(RowSignature(signature));
        }

        let mut active = vec![false; height];
        for y in 1..height {
            active[y] = row_diff(rows[y], rows[y - 1]) > 2.0;
        }

        let mut signature = Vec::with_capacity(SIGNATURE_COLUMNS * SIGNATURE_ROWS);
        for gy in 0..SIGNATURE_ROWS {
            let y = ((2 * gy + 1) * height / (2 * SIGNATURE_ROWS)).min(height - 1);
            for gx in 0..SIGNATURE_COLUMNS {
                let x = ((2 * gx + 1) * width / (2 * SIGNATURE_COLUMNS)).min(width - 1);
                let offset = (y * width + x) * 4;
                signature.push(luminance(data[offset], data[offset + 1], data[offset + 2]));
            }
        }
        let row_baseline = rows
            .iter()
            .flat_map(|row| row.0)
            .take(rows.len() * 7)
            .sum::<f32>()
            / (rows.len() * 7) as f32;
        for row in &mut rows {
            row.0[7] = row_baseline;
        }
        let raw_signature = signature.clone();
        let signature_baseline = normalize_values(&mut signature);
        Self {
            rows,
            active,
            raw_signature,
            baseline: (row_baseline + signature_baseline) / 2.0,
        }
    }
}

fn normalize_values(values: &mut [f32]) -> f32 {
    if values.is_empty() {
        return 0.0;
    }
    let baseline = values.iter().sum::<f32>() / values.len() as f32;
    for value in values {
        *value -= baseline;
    }
    baseline
}

fn luminance(red: u8, green: u8, blue: u8) -> f32 {
    0.299 * red as f32 + 0.587 * green as f32 + 0.114 * blue as f32
}

fn row_diff(left: RowSignature, right: RowSignature) -> f32 {
    left.0[..7]
        .iter()
        .zip(&right.0[..7])
        .map(|(left_value, right_value)| {
            ((left_value - left.0[7]) - (right_value - right.0[7])).abs()
        })
        .sum::<f32>()
        / 7.0
}

fn duplicate_signature(
    left: &[f32],
    right: &[f32],
    left_baseline: f32,
    right_baseline: f32,
    left_active_rows: usize,
    right_active_rows: usize,
) -> bool {
    if left.len() != right.len() || left.is_empty() {
        return false;
    }
    let mut total = 0.0;
    let mut maximum: f32 = 0.0;
    for (a, b) in left.iter().zip(right) {
        let difference = ((a - left_baseline) - (b - right_baseline)).abs();
        total += difference;
        maximum = maximum.max(difference);
    }
    let structure_matches = total / left.len() as f32 <= 1.1 && maximum <= 4.0;
    let has_content = left_active_rows >= MIN_ACTIVE || right_active_rows >= MIN_ACTIVE;
    structure_matches && (has_content || (left_baseline - right_baseline).abs() <= 32.0)
}

fn pair_diff(
    frame: &[RowSignature],
    previous: &[RowSignature],
    active: &[bool],
    offset: i32,
) -> (f32, usize) {
    let (top, bottom) = ignored_edges(frame.len());
    let start = top.max((-offset).max(0) as usize);
    let end = (frame.len() - bottom).min((frame.len() as i32 - offset) as usize);
    if end <= start {
        return (f32::MAX, 0);
    }
    let mut total = 0.0;
    let mut active_matches = 0;
    for index in start..end {
        let difference = row_diff(frame[index], previous[(index as i32 + offset) as usize]);
        total += difference;
        if active[index] && difference <= ROW_MATCH_TOL {
            active_matches += 1;
        }
    }
    (total / (end - start) as f32, active_matches)
}

fn ignored_edges(height: usize) -> (usize, usize) {
    if height < 80 {
        return (0, 0);
    }
    (
        ((height as f32 * SEAM_IGNORE_TOP) as usize).clamp(16, height / 4),
        ((height as f32 * SEAM_IGNORE_BOTTOM) as usize).clamp(16, height / 4),
    )
}

#[cfg(test)]
mod tests {
    use super::{ScrollStitcher, StitchOutcome};

    const WIDTH: usize = 64;
    const HEIGHT: usize = 100;

    fn frame(top: usize) -> Vec<u8> {
        let mut data = vec![0; WIDTH * HEIGHT * 4];
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let value = ((top + y).wrapping_mul(1_103_515_245) ^ x.wrapping_mul(2_654_435_761))
                    .wrapping_shr(24) as u8;
                let offset = (y * WIDTH + x) * 4;
                data[offset..offset + 4].copy_from_slice(&[value, value, value, 255]);
            }
        }
        data
    }

    fn repeated_frame(top: usize) -> Vec<u8> {
        let mut data = vec![0; WIDTH * HEIGHT * 4];
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let value = (((top + y) % 24) * 9 + (x % 13) * 5) as u8;
                let offset = (y * WIDTH + x) * 4;
                data[offset..offset + 4].copy_from_slice(&[value, value, value, 255]);
            }
        }
        data
    }

    fn brighter(mut data: Vec<u8>, amount: u8) -> Vec<u8> {
        for pixel in data.chunks_exact_mut(4) {
            pixel[0] = pixel[0].saturating_add(amount);
            pixel[1] = pixel[1].saturating_add(amount);
            pixel[2] = pixel[2].saturating_add(amount);
        }
        data
    }

    fn animated(mut data: Vec<u8>) -> Vec<u8> {
        for y in 47..50 {
            for x in 24..36 {
                let offset = (y * WIDTH + x) * 4;
                data[offset..offset + 4].copy_from_slice(&[255, 255, 255, 255]);
            }
        }
        data
    }

    fn page_frame(page: &[u8], top: usize) -> Vec<u8> {
        let stride = WIDTH * 4;
        page[top * stride..(top + HEIGHT) * stride].to_vec()
    }

    fn page() -> Vec<u8> {
        let mut page = vec![0; WIDTH * 600 * 4];
        for y in 0usize..600 {
            for x in 0..WIDTH {
                let value = ((y as u32).wrapping_mul(747_796_405).rotate_left(13)
                    ^ (x as u32).wrapping_mul(2_654_435_761))
                .wrapping_mul(2_246_822_519)
                .wrapping_shr(24) as u8;
                let offset = (y * WIDTH + x) * 4;
                page[offset..offset + 4].copy_from_slice(&[value, value, value, 255]);
            }
        }
        page
    }

    #[test]
    fn appends_overlapping_frames() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        assert!(matches!(
            stitcher.observe(&frame(0), HEIGHT),
            StitchOutcome::FirstFrame { .. }
        ));
        assert!(matches!(
            stitcher.observe(&frame(30), HEIGHT),
            StitchOutcome::Appended { .. }
        ));
        assert_eq!(stitcher.rows(), 130);
        assert!(!stitcher.canvas().is_empty());
    }

    #[test]
    fn waits_when_frame_has_no_overlap() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        let first = vec![10; WIDTH * HEIGHT * 4];
        let second = vec![200; WIDTH * HEIGHT * 4];
        stitcher.observe(&first, HEIGHT);
        assert_eq!(
            stitcher.observe(&second, HEIGHT),
            StitchOutcome::WaitingForOverlap
        );
        assert_eq!(stitcher.rows(), HEIGHT);
    }

    #[test]
    fn ignores_duplicate_frames() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&frame(0), HEIGHT);
        assert_eq!(
            stitcher.observe(&frame(0), HEIGHT),
            StitchOutcome::Duplicate
        );
        assert_eq!(stitcher.rows(), HEIGHT);
    }

    #[test]
    fn prepends_when_content_moves_up() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&frame(300), HEIGHT);
        assert!(matches!(
            stitcher.observe(&frame(270), HEIGHT),
            StitchOutcome::Appended { .. }
        ));
        assert_eq!(stitcher.rows(), 130);
    }

    #[test]
    fn does_not_force_a_new_segment_when_content_is_unrelated() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&frame(0), HEIGHT);
        let unrelated = vec![200; WIDTH * HEIGHT * 4];
        for _ in 0..4 {
            assert_eq!(
                stitcher.observe(&unrelated, HEIGHT),
                StitchOutcome::WaitingForOverlap
            );
        }
        assert_eq!(stitcher.rows(), HEIGHT);
    }

    #[test]
    fn repeated_content_does_not_create_a_new_segment() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&repeated_frame(0), HEIGHT);
        let outcome = stitcher.observe(&repeated_frame(80), HEIGHT);
        assert!(matches!(
            outcome,
            StitchOutcome::Appended { .. } | StitchOutcome::WaitingForOverlap
        ));
        assert!(stitcher.rows() <= 180);
    }

    #[test]
    fn matches_frames_after_a_brightness_shift() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&frame(0), HEIGHT);
        assert!(matches!(
            stitcher.observe(&brighter(frame(30), 20), HEIGHT),
            StitchOutcome::Appended { .. }
        ));
        assert_eq!(stitcher.rows(), 130);
    }

    #[test]
    fn tolerates_a_local_animation() {
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        stitcher.observe(&frame(0), HEIGHT);
        let outcome = stitcher.observe(&animated(frame(30)), HEIGHT);
        assert!(
            matches!(outcome, StitchOutcome::Appended { .. }),
            "{outcome:?}"
        );
        assert_eq!(stitcher.rows(), 130);
    }

    #[test]
    fn stitches_a_scroll_sequence_without_duplicate_growth() {
        let source = page();
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        for top in [0, 30, 60, 90, 120] {
            let outcome = stitcher.observe(&page_frame(&source, top), HEIGHT);
            assert!(!matches!(outcome, StitchOutcome::WaitingForOverlap));
        }
        assert_eq!(stitcher.rows(), 220);
        assert_eq!(
            &stitcher.canvas()[..220 * WIDTH * 4],
            &source[..220 * WIDTH * 4]
        );
    }

    #[test]
    fn revisiting_content_does_not_extend_the_canvas() {
        let source = page();
        let mut stitcher = ScrollStitcher::new(WIDTH, 10_000_000, 10_000);
        for top in [0, 30, 60, 30, 0] {
            stitcher.observe(&page_frame(&source, top), HEIGHT);
        }
        assert_eq!(stitcher.rows(), 160);
        assert_eq!(
            &stitcher.canvas()[..160 * WIDTH * 4],
            &source[..160 * WIDTH * 4]
        );
    }
}
