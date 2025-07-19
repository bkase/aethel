use crate::error::Result;
use chrono::{DateTime, Utc};
use git2::{Repository, Signature};
use std::path::Path;

pub fn get_current_timestamp() -> DateTime<Utc> {
    Utc::now()
}

pub fn generate_filename(timestamp: &DateTime<Utc>) -> String {
    timestamp.format("%Y-%m-%d-%H-%M-%S").to_string()
}

pub fn init_git_repo(path: &Path) -> Result<Repository> {
    let repo = Repository::init(path)?;
    Ok(repo)
}

#[allow(dead_code)]
pub fn commit_changes(repo: &Repository, message: &str) -> Result<()> {
    let signature = Signature::now("aethel", "aethel@localhost")?;
    let tree_id = {
        let mut index = repo.index()?;
        index.add_all(["*"].iter(), git2::IndexAddOption::DEFAULT, None)?;
        index.write()?;
        index.write_tree()?
    };

    let tree = repo.find_tree(tree_id)?;
    let parent_commit = match repo.head() {
        Ok(head) => Some(head.peel_to_commit()?),
        Err(_) => None,
    };

    let parents = parent_commit.as_ref().into_iter().collect::<Vec<_>>();
    repo.commit(
        Some("HEAD"),
        &signature,
        &signature,
        message,
        &tree,
        &parents,
    )?;

    Ok(())
}
