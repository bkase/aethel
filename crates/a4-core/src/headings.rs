use regex::Regex;
use std::sync::OnceLock;

static H1_REGEX: OnceLock<Regex> = OnceLock::new();
static H2_REGEX: OnceLock<Regex> = OnceLock::new();

pub fn ensure_h2_heading(content: &str, heading: &str) -> (String, bool) {
    let h1_re = H1_REGEX.get_or_init(|| Regex::new(r"(?m)^# (.+)$").unwrap());
    let h2_re = H2_REGEX.get_or_init(|| Regex::new(r"(?m)^## (.+)$").unwrap());

    for cap in h2_re.captures_iter(content) {
        if cap[1].trim().eq_ignore_ascii_case(heading) {
            return (content.to_string(), false);
        }
    }

    for cap in h1_re.captures_iter(content) {
        if cap[1].trim().eq_ignore_ascii_case(heading) {
            let mut result = content.to_string();

            if !result.ends_with('\n') {
                result.push('\n');
            }

            // Add double newline before heading
            result.push_str(&format!("\n## {heading}\n"));
            return (result, true);
        }
    }

    let mut result = content.to_string();

    if result.is_empty() {
        // Empty file: add double newline before heading
        result.push_str(&format!("\n\n## {heading}\n"));
    } else {
        // Has content: ensure it ends with newline, then add double newline before heading
        if !result.ends_with('\n') {
            result.push('\n');
        }
        result.push_str(&format!("\n## {heading}\n"));
    }
    (result, true)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_h2_already_exists() {
        let content = "# Title\n\n## Focus\n\nSome content";
        let (result, created) = ensure_h2_heading(content, "Focus");
        assert_eq!(result, content);
        assert!(!created);
    }

    #[test]
    fn test_h2_case_insensitive() {
        let content = "## FOCUS\n\nContent";
        let (result, created) = ensure_h2_heading(content, "focus");
        assert_eq!(result, content);
        assert!(!created);
    }

    #[test]
    fn test_h1_exists_create_h2() {
        let content = "# Focus\n\nContent";
        let (result, created) = ensure_h2_heading(content, "Focus");
        assert_eq!(result, "# Focus\n\nContent\n\n## Focus\n");
        assert!(created);
    }

    #[test]
    fn test_empty_content() {
        let content = "";
        let (result, created) = ensure_h2_heading(content, "Focus");
        assert_eq!(result, "\n\n## Focus\n");
        assert!(created);
    }

    #[test]
    fn test_no_heading_exists() {
        let content = "Some content\nMore content";
        let (result, created) = ensure_h2_heading(content, "Tasks");
        assert_eq!(result, "Some content\nMore content\n\n## Tasks\n");
        assert!(created);
    }
}
