//! Integration tests for the `aethel init` command

use assert_cmd::Command;
use predicates::prelude::*;
use tempfile::TempDir;

#[test]
fn test_init_current_directory() {
    let temp = TempDir::new().unwrap();

    // Run init without path argument
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("init")
        .assert()
        .success()
        .stdout(predicate::str::contains("Initialized Aethel vault at ."));

    // Verify directory structure in current directory
    assert!(temp.path().join("docs").is_dir());
    assert!(temp.path().join("packs").is_dir());
    assert!(temp.path().join(".aethel").is_dir());

    // Verify .gitkeep files
    assert!(temp.path().join("docs/.gitkeep").is_file());
    assert!(temp.path().join("packs/.gitkeep").is_file());
    assert!(temp.path().join(".aethel/.gitkeep").is_file());
}

#[test]
fn test_init_relative_path() {
    let temp = TempDir::new().unwrap();

    // Run init with relative path
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("init")
        .arg("./my-vault")
        .assert()
        .success()
        .stdout(predicate::str::contains(
            "Initialized Aethel vault at ./my-vault",
        ));

    // Verify directory structure
    let vault_path = temp.path().join("my-vault");
    assert!(vault_path.join("docs").is_dir());
    assert!(vault_path.join("packs").is_dir());
    assert!(vault_path.join(".aethel").is_dir());

    // Verify .gitkeep files
    assert!(vault_path.join("docs/.gitkeep").is_file());
    assert!(vault_path.join("packs/.gitkeep").is_file());
    assert!(vault_path.join(".aethel/.gitkeep").is_file());
}

#[test]
fn test_init_already_initialized() {
    let temp = TempDir::new().unwrap();

    // First initialization
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp).arg("init").assert().success();

    // Second initialization should detect existing vault
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("init")
        .assert()
        .success()
        .stdout(predicate::str::contains("Vault already initialized at ."));

    // Verify structure is unchanged
    assert!(temp.path().join("docs").is_dir());
    assert!(temp.path().join("packs").is_dir());
    assert!(temp.path().join(".aethel").is_dir());
}
