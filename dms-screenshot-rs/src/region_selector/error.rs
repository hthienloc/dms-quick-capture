use std::fmt;

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SelectorError {
    Cancelled,
    InvalidInput(String),
    Backend(String),
}

impl SelectorError {
    pub(crate) fn from_backend_message(message: &str) -> Self {
        if message == "selection cancelled" {
            Self::Cancelled
        } else {
            Self::Backend(message.to_string())
        }
    }
}

impl fmt::Display for SelectorError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Cancelled => write!(formatter, "selection cancelled"),
            Self::InvalidInput(message) | Self::Backend(message) => write!(formatter, "{message}"),
        }
    }
}

impl std::error::Error for SelectorError {}
