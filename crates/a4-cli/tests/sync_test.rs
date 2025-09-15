use a4_core::git_backend::{GitBackend, GixBackend, RebaseResult};
use std::fs;
use std::path::Path;
use tempfile::TempDir;

fn init_test_repo(dir: &Path) -> Result<(), Box<dyn std::error::Error>> {
    std::process::Command::new("git")
        .arg("init")
        .arg("-b")
        .arg("main") // Explicitly set the default branch name
        .current_dir(dir)
        .output()?;

    std::process::Command::new("git")
        .arg("config")
        .arg("user.email")
        .arg("test@example.com")
        .current_dir(dir)
        .output()?;

    std::process::Command::new("git")
        .arg("config")
        .arg("user.name")
        .arg("Test User")
        .current_dir(dir)
        .output()?;

    Ok(())
}

fn create_commit(
    dir: &Path,
    file: &str,
    content: &str,
    message: &str,
) -> Result<(), Box<dyn std::error::Error>> {
    fs::write(dir.join(file), content)?;

    std::process::Command::new("git")
        .arg("add")
        .arg(file)
        .current_dir(dir)
        .output()?;

    std::process::Command::new("git")
        .arg("commit")
        .arg("-m")
        .arg(message)
        .current_dir(dir)
        .output()?;

    Ok(())
}

#[test]
fn test_rebase_with_no_conflicts() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let repo_path = temp_dir.path();

    // Initialize repository
    init_test_repo(repo_path)?;

    // Create initial commit
    create_commit(repo_path, "file1.txt", "initial content", "Initial commit")?;

    // Create a branch from the initial commit to simulate remote
    std::process::Command::new("git")
        .arg("checkout")
        .arg("-b")
        .arg("remote-branch")
        .current_dir(repo_path)
        .output()?;

    // Make a change on remote branch
    create_commit(repo_path, "file3.txt", "remote content", "Remote commit")?;

    // Switch back to main branch
    std::process::Command::new("git")
        .arg("checkout")
        .arg("main")
        .current_dir(repo_path)
        .output()?;

    // Make a local change (non-conflicting)
    create_commit(repo_path, "file2.txt", "local content", "Local commit")?;

    // Now test the rebase
    let mut backend = GixBackend::open(repo_path)?;
    let result = backend.rebase_onto("remote-branch")?;

    assert_eq!(result, RebaseResult::Success);

    // Verify that both changes are present
    assert!(repo_path.join("file2.txt").exists());
    assert!(repo_path.join("file3.txt").exists());

    Ok(())
}

#[test]
fn test_rebase_with_conflicts() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let repo_path = temp_dir.path();

    // Initialize repository
    init_test_repo(repo_path)?;

    // Create initial commit
    create_commit(repo_path, "file.txt", "initial content", "Initial commit")?;

    // Create a branch from the initial commit to simulate remote
    std::process::Command::new("git")
        .arg("checkout")
        .arg("-b")
        .arg("remote-branch")
        .current_dir(repo_path)
        .output()?;

    // Make a conflicting change on remote branch
    create_commit(repo_path, "file.txt", "remote change", "Remote commit")?;

    // Switch back to main branch
    std::process::Command::new("git")
        .arg("checkout")
        .arg("main")
        .current_dir(repo_path)
        .output()?;

    // Make a local change to the same file (conflicting)
    create_commit(repo_path, "file.txt", "local change", "Local commit")?;

    // Now test the rebase - should detect conflict
    let mut backend = GixBackend::open(repo_path)?;
    let result = backend.rebase_onto("remote-branch")?;

    assert_eq!(result, RebaseResult::Conflict);

    // Verify that the repository is still in a clean state (rebase was aborted)
    let status_output = std::process::Command::new("git")
        .arg("status")
        .arg("--porcelain")
        .current_dir(repo_path)
        .output()?;

    assert!(
        status_output.stdout.is_empty(),
        "Repository should be in clean state after conflict"
    );

    Ok(())
}

#[test]
fn test_divergence_detection() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let repo_path = temp_dir.path();

    // Initialize repository
    init_test_repo(repo_path)?;

    // Create initial commit
    create_commit(repo_path, "file1.txt", "initial content", "Initial commit")?;

    // Create a branch from the initial commit to simulate remote
    std::process::Command::new("git")
        .arg("checkout")
        .arg("-b")
        .arg("remote-branch")
        .current_dir(repo_path)
        .output()?;

    // Make a change on remote branch
    create_commit(repo_path, "file3.txt", "remote content", "Remote commit")?;

    // Switch back to main branch
    std::process::Command::new("git")
        .arg("checkout")
        .arg("main")
        .current_dir(repo_path)
        .output()?;

    // Make a local change (creates divergence)
    create_commit(repo_path, "file2.txt", "local content", "Local commit")?;

    // Test divergence detection
    let backend = GixBackend::open(repo_path)?;
    let has_diverged = backend.diverged("remote-branch")?;

    assert!(has_diverged, "Should detect divergence between branches");

    Ok(())
}

#[test]
fn test_no_divergence_when_ahead() -> Result<(), Box<dyn std::error::Error>> {
    let temp_dir = TempDir::new()?;
    let repo_path = temp_dir.path();

    // Initialize repository
    init_test_repo(repo_path)?;

    // Create initial commit
    create_commit(repo_path, "file1.txt", "initial content", "Initial commit")?;

    // Create a branch to simulate remote (stays at initial commit)
    std::process::Command::new("git")
        .arg("branch")
        .arg("remote-branch")
        .current_dir(repo_path)
        .output()?;

    // Make a local change (we're ahead of remote)
    create_commit(repo_path, "file2.txt", "local content", "Local commit")?;

    // Test divergence detection
    let backend = GixBackend::open(repo_path)?;
    let has_diverged = backend.diverged("remote-branch")?;

    assert!(
        !has_diverged,
        "Should not detect divergence when we're ahead"
    );

    Ok(())
}
