use std::time::{Duration, Instant};

use crate::scroll_stitch::{ScrollStitcher, StitchOutcome};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    Selecting,
    Capturing,
    Completed,
    Cancelled,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum SessionEvent {
    Started,
    CaptureRequested,
    FrameAccepted(StitchOutcome),
    WaitingForOverlap,
    FrameIgnored,
    Completed,
    Cancelled,
}

pub struct ScrollCaptureSession {
    state: SessionState,
    interval: Duration,
    next_capture: Instant,
    in_flight: bool,
    stitcher: ScrollStitcher,
}

impl ScrollCaptureSession {
    pub fn new(width: usize, interval: Duration, max_canvas_bytes: usize, max_rows: usize) -> Self {
        Self {
            state: SessionState::Selecting,
            interval,
            next_capture: Instant::now(),
            in_flight: false,
            stitcher: ScrollStitcher::new(width, max_canvas_bytes, max_rows),
        }
    }

    pub fn start(&mut self, now: Instant) -> SessionEvent {
        if self.state != SessionState::Selecting {
            return SessionEvent::FrameIgnored;
        }
        self.state = SessionState::Capturing;
        self.next_capture = now;
        SessionEvent::Started
    }

    pub fn can_capture(&self, now: Instant) -> bool {
        self.state == SessionState::Capturing && !self.in_flight && now >= self.next_capture
    }

    pub fn begin_capture(&mut self, now: Instant) -> SessionEvent {
        if !self.can_capture(now) {
            return SessionEvent::FrameIgnored;
        }
        self.in_flight = true;
        self.next_capture = now + self.interval;
        SessionEvent::CaptureRequested
    }

    pub fn frame_ready(&mut self, frame: &[u8], height: usize, now: Instant) -> SessionEvent {
        if self.state != SessionState::Capturing || !self.in_flight {
            return SessionEvent::FrameIgnored;
        }
        self.in_flight = false;
        self.next_capture = now + self.interval;
        match self.stitcher.observe(frame, height) {
            StitchOutcome::WaitingForOverlap => SessionEvent::WaitingForOverlap,
            outcome => SessionEvent::FrameAccepted(outcome),
        }
    }

    pub fn finish(&mut self) -> SessionEvent {
        if self.state != SessionState::Capturing || self.stitcher.rows() == 0 {
            return SessionEvent::FrameIgnored;
        }
        self.in_flight = false;
        self.state = SessionState::Completed;
        SessionEvent::Completed
    }

    pub fn cancel(&mut self) -> SessionEvent {
        if matches!(
            self.state,
            SessionState::Completed | SessionState::Cancelled
        ) {
            return SessionEvent::FrameIgnored;
        }
        self.in_flight = false;
        self.state = SessionState::Cancelled;
        SessionEvent::Cancelled
    }

    pub fn canvas(&self) -> &[u8] {
        self.stitcher.canvas()
    }

    pub fn rows(&self) -> usize {
        self.stitcher.rows()
    }
}

#[cfg(test)]
mod tests {
    use super::{ScrollCaptureSession, SessionEvent};
    use crate::scroll_stitch::StitchOutcome;
    use std::time::{Duration, Instant};

    const WIDTH: usize = 64;
    const HEIGHT: usize = 100;

    fn frame(top: u8) -> Vec<u8> {
        let mut data = vec![0; WIDTH * HEIGHT * 4];
        for y in 0..HEIGHT {
            for x in 0..WIDTH {
                let value = top.wrapping_add((y * 17 + x * 31) as u8);
                let offset = (y * WIDTH + x) * 4;
                data[offset..offset + 4].copy_from_slice(&[value, value, value, 255]);
            }
        }
        data
    }

    #[test]
    fn only_one_capture_can_be_in_flight() {
        let start = Instant::now();
        let mut session =
            ScrollCaptureSession::new(WIDTH, Duration::from_millis(45), 10_000_000, 10_000);
        assert_eq!(session.start(start), SessionEvent::Started);
        assert_eq!(session.begin_capture(start), SessionEvent::CaptureRequested);
        assert_eq!(session.begin_capture(start), SessionEvent::FrameIgnored);
        assert!(matches!(
            session.frame_ready(&frame(0), HEIGHT, start),
            SessionEvent::FrameAccepted(StitchOutcome::FirstFrame { .. })
        ));
        assert!(!session.can_capture(start));
        assert!(session.can_capture(start + Duration::from_millis(45)));
    }

    #[test]
    fn reports_unmatched_frames_without_stitching_them() {
        let start = Instant::now();
        let mut session = ScrollCaptureSession::new(WIDTH, Duration::ZERO, 10_000_000, 10_000);
        session.start(start);
        session.begin_capture(start);
        session.frame_ready(&frame(0), HEIGHT, start);
        session.begin_capture(start);
        let unrelated = vec![200; WIDTH * HEIGHT * 4];
        assert_eq!(
            session.frame_ready(&unrelated, HEIGHT, start),
            SessionEvent::WaitingForOverlap
        );
        assert_eq!(session.rows(), HEIGHT);
    }

    #[test]
    fn accepts_multiple_frames_after_each_capture_is_started() {
        let start = Instant::now();
        let mut session = ScrollCaptureSession::new(WIDTH, Duration::ZERO, 10_000_000, 10_000);
        session.start(start);
        session.begin_capture(start);
        assert!(matches!(
            session.frame_ready(&frame(0), HEIGHT, start),
            SessionEvent::FrameAccepted(StitchOutcome::FirstFrame { .. })
        ));
        session.begin_capture(start);
        assert!(matches!(
            session.frame_ready(&frame(30), HEIGHT, start),
            SessionEvent::FrameAccepted(StitchOutcome::Appended { .. })
        ));
        assert!(session.rows() > HEIGHT);
    }

    #[test]
    fn done_and_cancel_are_terminal() {
        let start = Instant::now();
        let mut session = ScrollCaptureSession::new(WIDTH, Duration::ZERO, 10_000_000, 10_000);
        session.start(start);
        session.begin_capture(start);
        session.frame_ready(&frame(0), HEIGHT, start);
        assert_eq!(session.finish(), SessionEvent::Completed);
        assert_eq!(session.cancel(), SessionEvent::FrameIgnored);

        let mut cancelled = ScrollCaptureSession::new(WIDTH, Duration::ZERO, 10_000_000, 10_000);
        cancelled.start(start);
        assert_eq!(cancelled.cancel(), SessionEvent::Cancelled);
        assert_eq!(cancelled.finish(), SessionEvent::FrameIgnored);
    }
}
