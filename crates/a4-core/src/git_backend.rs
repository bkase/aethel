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
    fn push(&mut self, remote: &str, branch: Option<&str>) -> Result<(), A4Error>;
    fn head_branch(&self) -> Result<String, A4Error>;
    fn diverged(&self, remote_ref: &str) -> Result<bool, A4Error>;
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
                // Get the SHAs for error message
                let local_sha = std::process::Command::new("git")
                    .arg("rev-parse")
                    .arg("--short")
                    .arg("HEAD")
                    .current_dir(self.repo.work_dir().unwrap())
                    .output()
                    .map_err(|e| A4Error::Git(format!("Failed to get local SHA: {e}")))?;

                let remote_sha = std::process::Command::new("git")
                    .arg("rev-parse")
                    .arg("--short")
                    .arg(remote_ref)
                    .current_dir(self.repo.work_dir().unwrap())
                    .output()
                    .map_err(|e| A4Error::Git(format!("Failed to get remote SHA: {e}")))?;

                return Err(A4Error::GitDivergence {
                    local_sha: String::from_utf8_lossy(&local_sha.stdout)
                        .trim()
                        .to_string(),
                    remote_sha: String::from_utf8_lossy(&remote_sha.stdout)
                        .trim()
                        .to_string(),
                });
            }
            return Ok(false);
        }

        Ok(true)
    }

    fn push(&mut self, remote: &str, branch: Option<&str>) -> Result<(), A4Error> {
        let mut cmd = std::process::Command::new("git");
        cmd.arg("push").arg(remote);

        if let Some(branch) = branch {
            cmd.arg(branch);
        }

        cmd.current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to push: {e}")))?;

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
        let output = std::process::Command::new("git")
            .arg("merge-base")
            .arg("--is-ancestor")
            .arg("HEAD")
            .arg(remote_ref)
            .current_dir(self.repo.work_dir().unwrap())
            .output()
            .map_err(|e| A4Error::Git(format!("Failed to check divergence: {e}")))?;

        Ok(!output.status.success())
    }
}
