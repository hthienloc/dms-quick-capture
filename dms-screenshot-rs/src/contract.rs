use serde::Serialize;

#[derive(Debug, Serialize)]
pub struct CaptureResult {
    pub status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub path: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub width: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub height: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub scale: Option<f64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub mime: Option<&'static str>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct OutputList {
    pub status: &'static str,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub outputs: Option<Vec<OutputInfo>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct OutputInfo {
    pub name: String,
    pub width: i32,
    pub height: i32,
    pub scale: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub position: Option<(i32, i32)>,
}

impl OutputList {
    pub fn success(outputs: Vec<OutputInfo>) -> Self {
        Self {
            status: "success",
            outputs: Some(outputs),
            error: None,
        }
    }

    pub fn error(error: String) -> Self {
        Self {
            status: "error",
            outputs: None,
            error: Some(error),
        }
    }

    pub fn outputs(&self) -> Option<&[OutputInfo]> {
        self.outputs.as_deref()
    }

    pub fn error_message(&self) -> Option<&str> {
        self.error.as_deref()
    }
}

impl CaptureResult {
    pub fn aborted() -> Self {
        Self {
            status: "aborted",
            path: None,
            width: None,
            height: None,
            scale: None,
            mime: None,
            error: None,
        }
    }

    pub fn error(error: CaptureError) -> Self {
        Self {
            status: "error",
            path: None,
            width: None,
            height: None,
            scale: None,
            mime: None,
            error: Some(error.to_string()),
        }
    }

    pub fn success(path: String, width: u32, height: u32, scale: f64, mime: &'static str) -> Self {
        Self {
            status: "success",
            path: Some(path),
            width: Some(width),
            height: Some(height),
            scale: Some(scale),
            mime: Some(mime),
            error: None,
        }
    }

    pub fn error_message(&self) -> Option<&str> {
        self.error.as_deref()
    }
}

#[derive(Debug)]
pub enum CaptureError {
    Usage(&'static str),
    Unsupported(&'static str),
    Runtime(String),
}

impl CaptureError {
    pub fn usage(message: &'static str) -> Self {
        Self::Usage(message)
    }

    pub fn unsupported(mode: &'static str) -> Self {
        Self::Unsupported(mode)
    }

    pub fn runtime(message: String) -> Self {
        Self::Runtime(message)
    }
}

impl std::fmt::Display for CaptureError {
    fn fmt(&self, formatter: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Usage(message) => write!(formatter, "usage error: {message}"),
            Self::Unsupported(mode) => {
                write!(formatter, "capture mode is not implemented yet: {mode}")
            }
            Self::Runtime(message) => write!(formatter, "capture failed: {message}"),
        }
    }
}
