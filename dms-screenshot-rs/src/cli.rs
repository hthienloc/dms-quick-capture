use clap::{Args, Parser, Subcommand, ValueEnum};

#[derive(Debug, Parser)]
#[command(
    name = "dms-screenshot-rs",
    version,
    about = "Standalone DMS screenshot backend"
)]
pub struct Cli {
    /// Emit machine-readable output for callers such as Quick Capture.
    #[arg(long, global = true)]
    pub json: bool,

    #[command(subcommand)]
    pub command: Option<Command>,
}

#[derive(Debug, Subcommand)]
pub enum Command {
    /// Select a region interactively.
    Region(CaptureArgs),
    /// Capture the focused output.
    Full(CaptureArgs),
    /// Capture a named output.
    Output(OutputArgs),
    /// Capture all outputs combined.
    All(CaptureArgs),
    /// Capture the focused window.
    Window(CaptureArgs),
    /// Capture the previously selected region.
    Last(CaptureArgs),
    /// Select a region, capture while the content scrolls, then stitch it.
    Scroll(CaptureArgs),
    /// List available outputs.
    List,
}

impl Command {
    pub fn mode_name(&self) -> &'static str {
        match self {
            Self::Region(_) => "region",
            Self::Full(_) => "full",
            Self::Output(_) => "output",
            Self::All(_) => "all",
            Self::Window(_) => "window",
            Self::Last(_) => "last",
            Self::Scroll(_) => "scroll",
            Self::List => "list",
        }
    }
}

#[derive(Debug, Clone, Args)]
pub struct CaptureArgs {
    /// Include the cursor in the captured image.
    #[arg(long, value_enum, default_value_t = CursorMode::Off)]
    pub cursor: CursorMode,

    /// Output image format.
    #[arg(short = 'f', long, value_enum, default_value_t = ImageFormat::Png)]
    pub format: ImageFormat,

    /// JPEG quality from 1 to 100.
    #[arg(short = 'q', long, default_value_t = 90, value_parser = clap::value_parser!(u8).range(1..=100))]
    pub quality: u8,

    /// Output directory.
    #[arg(short = 'd', long = "dir", visible_alias = "directory")]
    pub directory: Option<String>,

    /// Output filename.
    #[arg(long)]
    pub filename: Option<String>,

    #[arg(long)]
    pub no_clipboard: bool,
    #[arg(long)]
    pub no_file: bool,
    #[arg(long)]
    pub no_notify: bool,
    #[arg(long)]
    pub no_confirm: bool,
    #[arg(long)]
    pub reset: bool,
    #[arg(long)]
    pub stdout: bool,

    /// Capture interval in milliseconds for scroll mode.
    #[arg(long, default_value_t = 45, value_parser = clap::value_parser!(u64).range(30..=1000))]
    pub interval: u64,

    /// Region x coordinate in physical output pixels.
    #[arg(long)]
    pub x: Option<i32>,

    /// Region y coordinate in physical output pixels.
    #[arg(long)]
    pub y: Option<i32>,

    /// Region width in physical output pixels.
    #[arg(long)]
    pub width: Option<u32>,

    /// Region height in physical output pixels.
    #[arg(long)]
    pub height: Option<u32>,
}

impl Default for CaptureArgs {
    fn default() -> Self {
        Self {
            cursor: CursorMode::Off,
            format: ImageFormat::Png,
            quality: 90,
            directory: None,
            filename: None,
            no_clipboard: false,
            no_file: false,
            no_notify: false,
            no_confirm: false,
            reset: false,
            stdout: false,
            interval: 45,
            x: None,
            y: None,
            width: None,
            height: None,
        }
    }
}

#[derive(Debug, Clone, Args)]
pub struct OutputArgs {
    #[command(flatten)]
    pub capture: CaptureArgs,

    /// Output name, for example DP-1.
    #[arg(short = 'o', long)]
    pub output: Option<String>,

    /// Positional output name, for example DP-1.
    #[arg(value_name = "NAME")]
    pub name: Option<String>,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum CursorMode {
    On,
    Off,
}

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum ImageFormat {
    Png,
    #[value(alias = "jpeg")]
    Jpg,
    Ppm,
}
