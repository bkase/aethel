//! Integration tests for the `aethel init` command

use assert_cmd::Command;
use predicates::prelude::*;
use std::fs;
use tempfile::TempDir;

#[test]
fn test_init_creates_vault_structure() {
    let temp = TempDir::new().unwrap();
    let vault_path = temp.path().join("my-vault");

    // Run init command
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("init")
        .arg(&vault_path)
        .assert()
        .success()
        .stdout(predicate::str::contains("Initialized Aethel vault at"));

    // Verify directory structure
    assert!(vault_path.join("docs").is_dir());
    assert!(vault_path.join("packs").is_dir());
    assert!(vault_path.join(".aethel").is_dir());

    // Verify .gitkeep files
    assert!(vault_path.join("docs/.gitkeep").is_file());
    assert!(vault_path.join("packs/.gitkeep").is_file());
    assert!(vault_path.join(".aethel/.gitkeep").is_file());
}

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
        .arg("./relative/path/vault")
        .assert()
        .success()
        .stdout(predicate::str::contains(
            "Initialized Aethel vault at ./relative/path/vault",
        ));

    // Verify directory structure
    let vault_path = temp.path().join("relative/path/vault");
    assert!(vault_path.join("docs").is_dir());
    assert!(vault_path.join("packs").is_dir());
    assert!(vault_path.join(".aethel").is_dir());

    // Verify .gitkeep files
    assert!(vault_path.join("docs/.gitkeep").is_file());
    assert!(vault_path.join("packs/.gitkeep").is_file());
    assert!(vault_path.join(".aethel/.gitkeep").is_file());
}

#[test]
fn test_init_absolute_path() {
    let temp = TempDir::new().unwrap();
    let vault_path = temp.path().join("absolute-vault");

    // Run init with absolute path
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.arg("init")
        .arg(&vault_path)
        .assert()
        .success()
        .stdout(predicate::str::contains(format!(
            "Initialized Aethel vault at {}",
            vault_path.display()
        )));

    // Verify directory structure
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

#[test]
fn test_init_nested_path_creation() {
    let temp = TempDir::new().unwrap();
    let vault_path = temp.path().join("deeply/nested/path/to/vault");

    // Run init with nested path that doesn't exist
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("init")
        .arg(&vault_path)
        .assert()
        .success();

    // Verify entire path was created
    assert!(vault_path.join("docs").is_dir());
    assert!(vault_path.join("packs").is_dir());
    assert!(vault_path.join(".aethel").is_dir());
}

#[test]
fn test_init_with_vault_root_flag() {
    let temp = TempDir::new().unwrap();
    let vault_path = temp.path().join("vault");
    let init_path = temp.path().join("new-vault");

    // Create a dummy vault for --vault-root
    fs::create_dir_all(vault_path.join("docs")).unwrap();
    fs::create_dir_all(vault_path.join("packs")).unwrap();

    // Run init with --vault-root flag (should be ignored by init)
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp)
        .arg("--vault-root")
        .arg(&vault_path)
        .arg("init")
        .arg(&init_path)
        .assert()
        .success()
        .stdout(predicate::str::contains(format!(
            "Initialized Aethel vault at {}",
            init_path.display()
        )));

    // Verify new vault was created at init_path, not affected by --vault-root
    assert!(init_path.join("docs").is_dir());
    assert!(init_path.join("packs").is_dir());
    assert!(init_path.join(".aethel").is_dir());
}

#[test]
fn test_init_gitkeep_files_are_empty() {
    let temp = TempDir::new().unwrap();

    // Run init
    let mut cmd = Command::cargo_bin("aethel").unwrap();
    cmd.current_dir(&temp).arg("init").assert().success();

    // Verify .gitkeep files exist and are empty
    let gitkeep_files = vec![
        temp.path().join("docs/.gitkeep"),
        temp.path().join("packs/.gitkeep"),
        temp.path().join(".aethel/.gitkeep"),
    ];

    for gitkeep in gitkeep_files {
        assert!(gitkeep.is_file());
        let contents = fs::read_to_string(&gitkeep).unwrap();
        assert_eq!(contents, "", "gitkeep file should be empty");
    }
}
