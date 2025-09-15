use assert_cmd::Command;
use tempfile::TempDir;

#[test]
fn test_today_command_fills_templates() {
    let temp_dir = TempDir::new().unwrap();
    // Match the actual vault structure: routines/templates/daily.md
    let template_path = temp_dir
        .path()
        .join("routines")
        .join("templates")
        .join("daily.md");

    // Create parent directory for template
    std::fs::create_dir_all(template_path.parent().unwrap()).unwrap();

    // Use the actual template from the real A4 core
    let template_content = r#"---
kind: capture.day
created: {{now_utc}}
tags: [daily]
---
# Daily Note {{YYYY-MM-DD}}

## Intention
^intent-{{hhmm}}

## End of Day
^eod-{{hhmm}}
"#;

    std::fs::write(&template_path, template_content).unwrap();

    // Run the today command
    let mut cmd = Command::cargo_bin("a4").unwrap();
    let output = cmd
        .env("A4_VAULT_DIR", temp_dir.path())
        .arg("today")
        .output()
        .unwrap();

    assert!(output.status.success());

    // Get the output path from stdout
    let stdout = String::from_utf8_lossy(&output.stdout);
    let daily_path = stdout.trim();

    // Read the created file
    let content = std::fs::read_to_string(daily_path).unwrap();

    // Check that templates were replaced
    assert!(
        !content.contains("{{YYYY-MM-DD}}"),
        "Template {{YYYY-MM-DD}} should have been replaced"
    );
    assert!(
        !content.contains("{{hhmm}}"),
        "Template {{hhmm}} should have been replaced"
    );
    assert!(
        !content.contains("{{now_utc}}"),
        "Template {{now_utc}} should have been replaced"
    );

    // Check that a date pattern exists (YYYY-MM-DD format)
    let date_regex = regex::Regex::new(r"\d{4}-\d{2}-\d{2}").unwrap();
    assert!(
        date_regex.is_match(&content),
        "Should contain a date in YYYY-MM-DD format"
    );

    // Check that time patterns exist (we can't check exact values due to timing)
    // Check for hhmm pattern (4 digits)
    let hhmm_regex = regex::Regex::new(r"\d{4}").unwrap();
    assert!(
        hhmm_regex.is_match(&content),
        "Should contain a 4-digit time (hhmm)"
    );

    // Check for ISO 8601 timestamp pattern
    let timestamp_regex = regex::Regex::new(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}").unwrap();
    assert!(
        timestamp_regex.is_match(&content),
        "Should contain an ISO 8601 timestamp"
    );
}

#[test]
fn test_today_command_fills_multiple_occurrences() {
    let temp_dir = TempDir::new().unwrap();
    let template_path = temp_dir
        .path()
        .join("routines")
        .join("templates")
        .join("daily.md");

    // Create parent directory for template
    std::fs::create_dir_all(template_path.parent().unwrap()).unwrap();

    // Create template with multiple occurrences of the same template
    let template_content = r#"# {{YYYY-MM-DD}} - Daily Note

Start: {{hhmm}}
End: {{hhmm}}

First timestamp: {{now_utc}}
Second timestamp: {{now_utc}}

Date again: {{YYYY-MM-DD}}
"#;

    std::fs::write(&template_path, template_content).unwrap();

    // Run the today command
    let mut cmd = Command::cargo_bin("a4").unwrap();
    let output = cmd
        .env("A4_VAULT_DIR", temp_dir.path())
        .arg("today")
        .output()
        .unwrap();

    assert!(output.status.success());

    // Get the output path from stdout
    let stdout = String::from_utf8_lossy(&output.stdout);
    let daily_path = stdout.trim();

    // Read the created file
    let content = std::fs::read_to_string(daily_path).unwrap();

    // Check that no templates remain
    assert!(
        !content.contains("{{"),
        "No template markers should remain in the file"
    );
    assert!(
        !content.contains("}}"),
        "No template markers should remain in the file"
    );
}
