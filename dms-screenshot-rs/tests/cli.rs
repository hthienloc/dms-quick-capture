use std::process::Command;

fn binary() -> Command {
    Command::new(env!("CARGO_BIN_EXE_dms-screenshot-rs"))
}

#[test]
fn accepts_json_after_capture_mode() {
    let output = binary()
        .args(["full", "--no-clipboard", "--json"])
        .output()
        .expect("binary should run");

    assert!(matches!(output.status.code(), Some(0) | Some(1)));
    let result: serde_json::Value =
        serde_json::from_slice(&output.stdout).expect("valid JSON output");
    assert!(matches!(
        result["status"].as_str(),
        Some("success") | Some("error")
    ));
    if result["status"] == "error" {
        assert!(result["error"].as_str().is_some());
    }
}

#[test]
fn output_accepts_positional_name() {
    let output = binary()
        .args(["output", "--help"])
        .output()
        .expect("binary should run");

    assert!(output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("[NAME]"));
}

#[test]
fn exposes_scroll_as_a_json_capture_mode() {
    let output = binary()
        .args(["scroll", "--help"])
        .output()
        .expect("binary should run");

    assert!(output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("capture while the content scrolls"));
}
