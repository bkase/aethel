use crate::error::A4Error;
use regex::Regex;
use std::sync::OnceLock;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct AnchorToken {
    pub prefix: String,
    pub hhmm: String,
    pub suffix: Option<String>,
}

static ANCHOR_REGEX: OnceLock<Regex> = OnceLock::new();

impl AnchorToken {
    pub fn parse(token: &str) -> Result<Self, A4Error> {
        let re = ANCHOR_REGEX
            .get_or_init(|| Regex::new(r"^([a-z][a-z0-9-]{1,24})-(\d{4})(?:__(.+))?$").unwrap());

        let token_without_caret = token.strip_prefix('^').unwrap_or(token);

        let caps = re.captures(token_without_caret).ok_or_else(|| {
            A4Error::InvalidAnchorToken {
                token: token.to_string(),
                reason: "Token must match pattern: <prefix>-<HHMM>[__<suffix>] where prefix is lowercase alphanumeric with hyphens (2-25 chars), HHMM is 4 digits".to_string(),
            }
        })?;

        let prefix = caps[1].to_string();
        let hhmm = caps[2].to_string();
        let suffix = caps.get(3).map(|m| m.as_str().to_string());

        let hour: u32 = hhmm[0..2]
            .parse()
            .map_err(|_| A4Error::InvalidAnchorToken {
                token: token.to_string(),
                reason: "Invalid hour in HHMM".to_string(),
            })?;

        let minute: u32 = hhmm[2..4]
            .parse()
            .map_err(|_| A4Error::InvalidAnchorToken {
                token: token.to_string(),
                reason: "Invalid minute in HHMM".to_string(),
            })?;

        if hour > 23 {
            return Err(A4Error::InvalidAnchorToken {
                token: token.to_string(),
                reason: format!("Hour {hour} must be 00-23"),
            });
        }

        if minute > 59 {
            return Err(A4Error::InvalidAnchorToken {
                token: token.to_string(),
                reason: format!("Minute {minute} must be 00-59"),
            });
        }

        Ok(AnchorToken {
            prefix,
            hhmm,
            suffix,
        })
    }

    pub fn to_marker(&self) -> String {
        match &self.suffix {
            Some(s) => format!("^{}-{}__{}", self.prefix, self.hhmm, s),
            None => format!("^{}-{}", self.prefix, self.hhmm),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_anchors() {
        let token = AnchorToken::parse("focus-0930").unwrap();
        assert_eq!(token.prefix, "focus");
        assert_eq!(token.hhmm, "0930");
        assert_eq!(token.suffix, None);

        let token = AnchorToken::parse("jrnl-0812__iphone").unwrap();
        assert_eq!(token.prefix, "jrnl");
        assert_eq!(token.hhmm, "0812");
        assert_eq!(token.suffix, Some("iphone".to_string()));

        let token = AnchorToken::parse("^focus-2359").unwrap();
        assert_eq!(token.prefix, "focus");
        assert_eq!(token.hhmm, "2359");
    }

    #[test]
    fn test_invalid_anchors() {
        assert!(AnchorToken::parse("FOCUS-0930").is_err());
        assert!(AnchorToken::parse("2460").is_err());
        assert!(AnchorToken::parse("focus-093").is_err());
        assert!(AnchorToken::parse("focus-09300").is_err());
        assert!(AnchorToken::parse("focus-2460").is_err());
        assert!(AnchorToken::parse("focus-0960").is_err());
        assert!(AnchorToken::parse("-0930").is_err());
        assert!(AnchorToken::parse("0930").is_err());
    }

    #[test]
    fn test_to_marker() {
        let token = AnchorToken {
            prefix: "focus".to_string(),
            hhmm: "0930".to_string(),
            suffix: None,
        };
        assert_eq!(token.to_marker(), "^focus-0930");

        let token = AnchorToken {
            prefix: "jrnl".to_string(),
            hhmm: "0812".to_string(),
            suffix: Some("iphone".to_string()),
        };
        assert_eq!(token.to_marker(), "^jrnl-0812__iphone");
    }
}
