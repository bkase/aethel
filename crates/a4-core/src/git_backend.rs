use crate::error::A4Error;
use std::path::Path;

pub trait GitBackend {
    fn open(cwd: &Path) -> Result<Self, A4Error>
    where
        Self: Sized;
    fn stage_all(&mut self) -> Result<(), A4Error>;
    fn commit_if_needed(&mut self, message: &str) -> Result<bool, A4Error>;
    fn fetch(&mut self, remote: &str, branch: Option<&str>) -> Result<(), A4Error>;
    fn fast_forward_current_branch(&mut self, remote_ref: &str) -> Result<bool, A4Error>;
    fn rebase_onto(&mut self, remote_ref: &str) -> Result<RebaseResult, A4Error>;
    fn push(&mut self, remote: &str, branch: Option<&str>, force: bool) -> Result<(), A4Error>;
    fn head_branch(&self) -> Result<String, A4Error>;
    fn diverged(&self, remote_ref: &str) -> Result<bool, A4Error>;
    fn has_uncommitted_changes(&self) -> Result<bool, A4Error>;
}

#[derive(Debug, PartialEq)]
pub enum RebaseResult {
    Success,
    Conflict,
    NoRebaseNeeded,
}

pub struct GixBackend {
    repo: gix::Repository,
}

impl GitBackend for GixBackend {
    fn open(cwd: &Path) -> Result<Self, A4Error> {
        let repo = gix::discover(cwd).map_err(|_| A4Error::GitRepoNotFound {
            path: cwd.to_path_buf(),
        })?;

        Ok(GixBackend { repo })
    }

    fn stage_all(&mut self) -> Result<(), A4Error> {
        let workdir = self
            .repo
            .work_dir()
            .ok_or_else(|| A4Error::Git("No working directory".to_string()))?;

        // Use git command for staging - gix index API requires more setup
        std::process::Command::new("git")
            .arg("add")
            .arg("-A")
            .current_dir(workdir)
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to stage files: {e}")))?;

        Ok(())
    }

    fn commit_if_needed(&mut self, message: &str) -> Result<bool, A4Error> {
        // Check if there are changes to commit
        let status = std::process::Command::new("git")
            .arg("status")
            .arg("--porcelain")
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to check status: {e}")))?;

        if status.stdout.is_empty() {
            return Ok(false);
        }

        // Create commit
        std::process::Command::new("git")
            .arg("commit")
            .arg("-m")
            .arg(message)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to commit: {e}")))?;

        Ok(true)
    }

    fn fetch(&mut self, remote: &str, _branch: Option<&str>) -> Result<(), A4Error> {
        std::process::Command::new("git")
            .arg("fetch")
            .arg(remote)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to fetch: {e}")))?;

        Ok(())
    }

    fn fast_forward_current_branch(&mut self, remote_ref: &str) -> Result<bool, A4Error> {
        // Try to merge with fast-forward only
        let output = std::process::Command::new("git")
            .arg("merge")
            .arg("--ff-only")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to merge: {e}")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("Not possible to fast-forward") || stderr.contains("diverged") {
                // Don't error here, just return false to indicate fast-forward wasn't possible
                return Ok(false);
            }
            return Err(A4Error::Git(format!("Fast-forward failed: {stderr}")));
        }

        Ok(true)
    }

    fn rebase_onto(&mut self, remote_ref: &str) -> Result<RebaseResult, A4Error> {
        // Check if we're already up to date
        let merge_base = std::process::Command::new("git")
            .arg("merge-base")
            .arg("HEAD")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to find merge base: {e}")))?;

        let merge_base_sha = String::from_utf8_lossy(&merge_base.stdout)
            .trim()
            .to_string();

        // Check if HEAD is the same as remote_ref
        let head_sha = std::process::Command::new("git")
            .arg("rev-parse")
            .arg("HEAD")
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to get HEAD SHA: {e}")))?;

        let remote_sha = std::process::Command::new("git")
            .arg("rev-parse")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to get remote SHA: {e}")))?;

        let head_sha_str = String::from_utf8_lossy(&head_sha.stdout).trim().to_string();
        let remote_sha_str = String::from_utf8_lossy(&remote_sha.stdout)
            .trim()
            .to_string();

        // If HEAD is already at remote_ref, no rebase needed
        if head_sha_str == remote_sha_str {
            return Ok(RebaseResult::NoRebaseNeeded);
        }

        // If merge_base is the same as remote_ref, we're ahead - no rebase needed
        if merge_base_sha == remote_sha_str {
            return Ok(RebaseResult::NoRebaseNeeded);
        }

        // Perform the rebase
        let output = std::process::Command::new("git")
            .arg("rebase")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to rebase: {e}")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            if stderr.contains("CONFLICT") || stderr.contains("conflict") {
                // Abort the rebase to leave repository in clean state
                std::process::Command::new("git")
                    .arg("rebase")
                    .arg("--abort")
                    .current_dir(self.repo.work_dir().unwrap())
                    .output()
                    .map_err(|e| A4Error::Git(format!("Failed to abort rebase: {e}")))?;

                return Ok(RebaseResult::Conflict);
            }
            return Err(A4Error::Git(format!("Rebase failed: {stderr}")));
        }

        Ok(RebaseResult::Success)
    }

    fn push(&mut self, remote: &str, branch: Option<&str>, force: bool) -> Result<(), A4Error> {
        let mut cmd = std::process::Command::new("git");
        cmd.arg("push");

        if force {
            cmd.arg("--force-with-lease");
        }

        cmd.arg(remote);

        if let Some(branch) = branch {
            cmd.arg(branch);
        }

        let output = cmd
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to push: {e}")))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            return Err(A4Error::Git(format!("Push failed: {stderr}")));
        }

        Ok(())
    }

    fn head_branch(&self) -> Result<String, A4Error> {
        let output = std::process::Command::new("git")
            .arg("branch")
            .arg("--show-current")
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to get current branch: {e}")))?;

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    fn diverged(&self, remote_ref: &str) -> Result<bool, A4Error> {
        // Check if HEAD is an ancestor of remote_ref
        let head_ancestor = std::process::Command::new("git")
            .arg("merge-base")
            .arg("--is-ancestor")
            .arg("HEAD")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to check if HEAD is ancestor: {e}")))?;

        // Check if remote_ref is an ancestor of HEAD
        let remote_ancestor = std::process::Command::new("git")
            .arg("merge-base")
            .arg("--is-ancestor")
            .arg(remote_ref)
            .arg("HEAD")
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to check if remote is ancestor: {e}")))?;

        // We have diverged if neither is an ancestor of the other
        Ok(!head_ancestor.status.success() && !remote_ancestor.status.success())
    }

    fn has_uncommitted_changes(&self) -> Result<bool, A4Error> {
        let output = std::process::Command::new("git")
            .arg("status")
            .arg("--porcelain")
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to check status: {e}")))?;

        Ok(!output.stdout.is_empty())
    }
}
