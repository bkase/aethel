use crate::error::A4Error;
use fs_err as fs;
use std::path::{Path, PathBuf};

pub struct Note {
    pub path: PathBuf,
    pub body: String,
    pub front_matter: Option<String>,
}

pub fn read_note(path: &Path) -> Result<Note, A4Error> {
    let raw = fs::read_to_string(path)?;
    let (front_matter, body) = split_front_matter(&raw);

    Ok(Note {
        path: path.to_path_buf(),
        body: body.to_string(),
        front_matter: front_matter.map(|s| s.to_string()),
    })
}

pub fn write_note(path: &Path, body: &str) -> Result<(), A4Error> {
    let parent = path.parent().ok_or_else(|| A4Error::InvalidVaultPath {
        path: path.to_path_buf(),
    })?;

    fs::create_dir_all(parent)?;

    let temp_path = path.with_extension("tmp");
    fs::write(&temp_path, body)?;
    fs::rename(&temp_path, path)?;

    Ok(())
}

pub fn split_front_matter(raw: &str) -> (Option<&str>, &str) {
    if !raw.starts_with("---\n") && !raw.starts_with("---\r\n") {
        return (None, raw);
    }

    let mut lines = raw.lines();
    lines.next();

    let mut end_index = None;
    let mut current_pos = raw.find('\n').unwrap_or(3) + 1;

    for line in lines {
        if line == "---" {
            end_index = Some(current_pos + 3);
            break;
        }
        current_pos += line.len() + 1;
    }

    if let Some(end) = end_index {
        let front_matter = &raw[0..end];
        let body_start = if raw[end..].starts_with('\n') {
            end + 1
        } else if raw[end..].starts_with("\r\n") {
            end + 2
        } else {
            end
        };
        (Some(front_matter), &raw[body_start..])
    } else {
        (None, raw)
    }
}

pub fn join_front_matter(fm: Option<&str>, body: &str) -> String {
    match fm {
        Some(fm) => {
            let mut result = fm.to_string();
            if !fm.ends_with('\n') {
                result.push('\n');
            }
            result.push_str(body);
            result
        }
        None => body.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_split_no_front_matter() {
        let raw = "# Title\n\nContent";
        let (fm, body) = split_front_matter(raw);
        assert_eq!(fm, None);
        assert_eq!(body, raw);
    }

    #[test]
    fn test_split_with_front_matter() {
        let raw = "---\ntitle: Test\n---\n# Content";
        let (fm, body) = split_front_matter(raw);
        assert_eq!(fm, Some("---\ntitle: Test\n---"));
        assert_eq!(body, "# Content");
    }

    #[test]
    fn test_join_front_matter() {
        let fm = Some("---\ntitle: Test\n---");
        let body = "# Content";
        let result = join_front_matter(fm, body);
        assert_eq!(result, "---\ntitle: Test\n---\n# Content");
    }
}
