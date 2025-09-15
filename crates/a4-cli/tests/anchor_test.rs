use assert_cmd::Command;
use tempfile::TempDir;

#[test]
fn test_append_auto_adds_hhmm_to_anchor() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // Test with just a prefix - should auto-append HHMM
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Journal")
        .arg("--anchor")
        .arg("jrnl") // Just the prefix, no HHMM
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("- This is a journal entry");

    let output = cmd.output().unwrap();

    // Should succeed
    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Check the file content - should have the anchor with HHMM appended
    let content = std::fs::read_to_string(&test_file).unwrap();

    // Should contain the heading
    assert!(content.contains("## Journal"));

    // Should contain an anchor marker with jrnl-HHMM pattern
    let anchor_regex = regex::Regex::new(r"\^jrnl-\d{4}").unwrap();
    assert!(
        anchor_regex.is_match(&content),
        "Content should contain anchor with auto-added HHMM: {content}"
    );

    // Should contain the text
    assert!(content.contains("- This is a journal entry"));
}

#[test]
fn test_append_preserves_full_anchor_format() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // Test with full anchor format - should be preserved as-is
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Tasks")
        .arg("--anchor")
        .arg("task-1234") // Full format with HHMM
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("- Complete the feature");

    let output = cmd.output().unwrap();

    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Check the file content
    let content = std::fs::read_to_string(&test_file).unwrap();

    // Should have the exact anchor we provided
    assert!(
        content.contains("^task-1234"),
        "Should preserve the full anchor format"
    );
}

#[test]
fn test_append_with_anchor_suffix() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // Test with anchor that has a suffix - should auto-add HHMM between prefix and suffix
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Notes")
        .arg("--anchor")
        .arg("note__meeting") // Prefix with suffix separator
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("Discussion points");

    let output = cmd.output().unwrap();

    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    let content = std::fs::read_to_string(&test_file).unwrap();

    // Should have anchor with HHMM inserted before the suffix
    let anchor_regex = regex::Regex::new(r"\^note-\d{4}__meeting").unwrap();
    assert!(
        anchor_regex.is_match(&content),
        "Should insert HHMM before suffix: {content}"
    );
}

#[test]
fn test_append_validates_invalid_prefix() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // Test with invalid prefix (too short)
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Test")
        .arg("--anchor")
        .arg("x") // Too short
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("Test content");

    let output = cmd.output().unwrap();

    // Should fail validation
    assert!(!output.status.success(), "Should fail with invalid prefix");

    let stderr = String::from_utf8_lossy(&output.stderr);
    assert!(
        stderr.contains("Invalid anchor") || stderr.contains("must be between 2 and 25 characters"),
        "Should show validation error"
    );
}
