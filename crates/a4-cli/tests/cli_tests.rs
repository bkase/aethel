use assert_cmd::Command;
use tempfile::TempDir;

#[test]
fn test_root_command_outputs_vault_path() {
    let temp_dir = TempDir::new().unwrap();
    let expected_path = std::fs::canonicalize(temp_dir.path()).unwrap();

    let mut cmd = Command::cargo_bin("a4").unwrap();
    let output = cmd
        .env("A4_VAULT_DIR", temp_dir.path())
        .arg("root")
        .output()
        .unwrap();

    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    let stdout = String::from_utf8_lossy(&output.stdout);
    assert_eq!(stdout.trim(), expected_path.to_str().unwrap());
}

#[test]
fn test_append_with_text_starting_with_dash() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // This should work but currently fails if text starts with a dash
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Tasks")
        .arg("--anchor")
        .arg("task-1000")
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("- Fix the bug in parser");

    let output = cmd.output().unwrap();

    // Should succeed
    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Check the file content
    let content = std::fs::read_to_string(&test_file).unwrap();
    assert!(content.contains("- Fix the bug in parser"));
}

#[test]
fn test_append_with_text_double_dash() {
    let temp_dir = TempDir::new().unwrap();
    let test_file = temp_dir.path().join("test.md");

    // Test with -- prefix
    let mut cmd = Command::cargo_bin("a4").unwrap();
    cmd.env("A4_VAULT_DIR", temp_dir.path())
        .arg("append")
        .arg("--heading")
        .arg("Notes")
        .arg("--anchor")
        .arg("note-1100")
        .arg("--file")
        .arg(test_file.to_str().unwrap())
        .arg("--text")
        .arg("-- Remember to check this");

    let output = cmd.output().unwrap();

    // Should succeed
    assert!(
        output.status.success(),
        "Command failed with output: {:?}",
        String::from_utf8_lossy(&output.stderr)
    );

    // Check the file content
    let content = std::fs::read_to_string(&test_file).unwrap();
    assert!(content.contains("-- Remember to check this"));
}
