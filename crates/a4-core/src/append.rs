use crate::anchors::AnchorToken;
use crate::error::A4Error;
use crate::headings::ensure_h2_heading;
use crate::notes::{join_front_matter, read_note, write_note};
use crate::vault::Vault;
use std::path::Path;

pub struct AppendOptions<'a> {
    pub heading: &'a str,
    pub anchor: AnchorToken,
    pub content: &'a str,
}

pub fn append_block(vault: &Vault, file: &Path, opts: AppendOptions) -> Result<(), A4Error> {
    vault.ensure_parents(file)?;

    let (front_matter, mut body) = if file.exists() {
        let note = read_note(file)?;
        (note.front_matter, note.body)
    } else {
        (None, String::new())
    };

    let (updated_body, _) = ensure_h2_heading(&body, opts.heading);
    body = updated_body;

    // Ensure the body ends with exactly one newline
    if !body.is_empty() && !body.ends_with('\n') {
        body.push('\n');
    }

    // Always add double newline before anchor
    body.push('\n');

    // Interpret escape sequences in content
    let interpreted_content = opts
        .content
        .replace("\\n", "\n")
        .replace("\\t", "\t")
        .replace("\\r", "\r")
        .replace("\\\\", "\\");

    // Add anchor with double newline after it, then content
    body.push_str(&format!(
        "{}\n\n{}\n",
        opts.anchor.to_marker(),
        interpreted_content
    ));

    let final_content = join_front_matter(front_matter.as_deref(), &body);
    write_note(file, &final_content)?;

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::vault::VaultOpts;
    use tempfile::TempDir;

    #[test]
    fn test_append_to_empty_file() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        let anchor = AnchorToken::parse("focus-0930").unwrap();
        let opts = AppendOptions {
            heading: "Focus",
            anchor,
            content: "Test content",
        };

        append_block(&vault, &file, opts).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        // Should be: \n\n## Focus\n\n^focus-0930\n\nTest content\n
        assert_eq!(content, "\n\n## Focus\n\n^focus-0930\n\nTest content\n");
    }

    #[test]
    fn test_append_preserves_order() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        let anchor1 = AnchorToken::parse("focus-0930").unwrap();
        let opts1 = AppendOptions {
            heading: "Focus",
            anchor: anchor1,
            content: "First block",
        };
        append_block(&vault, &file, opts1).unwrap();

        let anchor2 = AnchorToken::parse("focus-1030").unwrap();
        let opts2 = AppendOptions {
            heading: "Focus",
            anchor: anchor2,
            content: "Second block",
        };
        append_block(&vault, &file, opts2).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        let first_pos = content.find("First block").unwrap();
        let second_pos = content.find("Second block").unwrap();
        assert!(first_pos < second_pos);

        // Also check exact format after two appends
        assert_eq!(
            content,
            "\n\n## Focus\n\n^focus-0930\n\nFirst block\n\n^focus-1030\n\nSecond block\n"
        );
    }

    #[test]
    fn test_append_adds_heading_with_existing_content() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        // Create file with existing content
        std::fs::write(&file, "# My Document\n\nSome existing content").unwrap();

        let anchor = AnchorToken::parse("focus-0930").unwrap();
        let opts = AppendOptions {
            heading: "Focus",
            anchor,
            content: "New content",
        };

        append_block(&vault, &file, opts).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        // Should add double newline before heading, then heading, then double newline, then anchor, then double newline, then content
        assert_eq!(
            content,
            "# My Document\n\nSome existing content\n\n## Focus\n\n^focus-0930\n\nNew content\n"
        );
    }

    #[test]
    fn test_append_to_existing_heading() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        // Create file with existing heading
        std::fs::write(&file, "## Focus\nExisting content").unwrap();

        let anchor = AnchorToken::parse("focus-0930").unwrap();
        let opts = AppendOptions {
            heading: "Focus",
            anchor,
            content: "New content",
        };

        append_block(&vault, &file, opts).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        // Should not add new heading, just append to existing one with double newlines
        assert_eq!(
            content,
            "## Focus\nExisting content\n\n^focus-0930\n\nNew content\n"
        );
    }

    #[test]
    fn test_append_interprets_newlines_in_content() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        let anchor = AnchorToken::parse("task-1000").unwrap();
        let opts = AppendOptions {
            heading: "Tasks",
            anchor,
            content: "Line one\\nLine two\\n\\nLine three with double newline before",
        };

        append_block(&vault, &file, opts).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        // The \n in content should be interpreted as actual newlines
        assert_eq!(
            content,
            "\n\n## Tasks\n\n^task-1000\n\nLine one\nLine two\n\nLine three with double newline before\n"
        );
    }

    #[test]
    fn test_append_handles_escaped_backslash() {
        let temp_dir = TempDir::new().unwrap();
        let vault = Vault::open(temp_dir.path(), VaultOpts::default()).unwrap();
        let file = temp_dir.path().join("test.md");

        let anchor = AnchorToken::parse("note-1100").unwrap();
        let opts = AppendOptions {
            heading: "Notes",
            anchor,
            content: "Path: C:\\\\Users\\\\Documents\\nTab here:\\tvalue",
        };

        append_block(&vault, &file, opts).unwrap();

        let content = std::fs::read_to_string(&file).unwrap();
        // \\ should become \, \n should become newline, \t should become tab
        assert_eq!(
            content,
            "\n\n## Notes\n\n^note-1100\n\nPath: C:\\Users\\Documents\nTab here:\tvalue\n"
        );
    }
}
