mod cli;
mod env;
mod logging;

use a4_core::git_backend::{GitBackend, GixBackend};
use a4_core::{append_block, AnchorToken, AppendOptions, LocalClock, Vault};
use anyhow::Result;
use clap::Parser;
use cli::{Cli, Commands};
use std::io::{self, Read};

fn main() -> Result<()> {
    let cli = Cli::parse();

    logging::init(cli.verbose);

    let result = match cli.command {
        Commands::Today => handle_today(cli.vault),
        Commands::Append(args) => handle_append(cli.vault, args),
        Commands::Sync(args) => handle_sync(cli.vault, args),
    };

    if let Err(e) = result {
        eprintln!("Error: {e}");
        std::process::exit(1);
    }

    Ok(())
}

fn handle_today(vault_override: Option<std::path::PathBuf>) -> Result<()> {
    let (vault, _) = Vault::resolve_with_override(vault_override)?;
    let today = LocalClock::today_utc();
    let daily_path = vault.capture_day_path(today.clone());

    vault.ensure_parents(&daily_path)?;

    if !daily_path.exists() {
        let template_path = vault.template_path();

        let mut content = if template_path.exists() {
            std::fs::read_to_string(&template_path)?
        } else {
            "\n".to_string()
        };

        // Fill in template variables
        content = fill_templates(content, &today);

        std::fs::write(&daily_path, content)?;
    }

    println!("{}", daily_path.display());
    Ok(())
}

fn parse_anchor_with_auto_hhmm(anchor_str: &str) -> Result<AnchorToken> {
    // First try to parse as-is
    match AnchorToken::parse(anchor_str) {
        Ok(token) => Ok(token),
        Err(_) => {
            // If it fails, try to auto-append HHMM
            let hhmm = LocalClock::now_local_hhmm();

            // Check if the anchor has a suffix separator
            let modified_anchor = if let Some(pos) = anchor_str.find("__") {
                // Insert HHMM before the suffix
                let (prefix, suffix) = anchor_str.split_at(pos);
                format!("{prefix}-{hhmm}{suffix}")
            } else {
                // Just append HHMM
                format!("{anchor_str}-{hhmm}")
            };

            // Try to parse the modified anchor
            AnchorToken::parse(&modified_anchor).map_err(|e| {
                // If it still fails, provide a helpful error
                if anchor_str.len() < 2 || anchor_str.len() > 25 {
                    anyhow::anyhow!("Invalid anchor prefix '{}': must be between 2 and 25 characters", anchor_str)
                } else if !anchor_str.chars().next().is_some_and(|c| c.is_ascii_lowercase()) {
                    anyhow::anyhow!("Invalid anchor prefix '{}': must start with a lowercase letter", anchor_str)
                } else if !anchor_str.chars().all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-' || c == '_') {
                    anyhow::anyhow!("Invalid anchor prefix '{}': must contain only lowercase letters, digits, hyphens, and underscores", anchor_str)
                } else {
                    anyhow::anyhow!("Invalid anchor: {}", e)
                }
            })
        }
    }
}

fn fill_templates(mut content: String, today: &a4_core::date::UtcDay) -> String {
    use time::OffsetDateTime;

    // Replace {{now_utc}} with current UTC timestamp in ISO 8601 format
    let now_utc = OffsetDateTime::now_utc();
    let now_utc_str = now_utc
        .format(&time::format_description::well_known::Iso8601::DEFAULT)
        .unwrap_or_else(|_| now_utc.to_string());
    content = content.replace("{{now_utc}}", &now_utc_str);

    // Replace {{hhmm}} with current local time as HHMM
    let hhmm = LocalClock::now_local_hhmm();
    content = content.replace("{{hhmm}}", &hhmm);

    // Replace {{YYYY-MM-DD}} with today's date
    let date_str = format!("{:04}-{:02}-{:02}", today.year, today.month, today.day);
    content = content.replace("{{YYYY-MM-DD}}", &date_str);

    content
}

fn handle_append(vault_override: Option<std::path::PathBuf>, args: cli::AppendArgs) -> Result<()> {
    let (vault, _) = Vault::resolve_with_override(vault_override)?;

    let target_path = if args.today {
        let today = LocalClock::today_utc();
        vault.capture_day_path(today)
    } else if let Some(file) = args.file {
        if file.is_absolute() {
            file
        } else {
            vault.root().join(file)
        }
    } else {
        anyhow::bail!("Must specify either --file or --today");
    };

    let content = if args.stdin {
        let mut buffer = String::new();
        io::stdin().read_to_string(&mut buffer)?;
        buffer
    } else if let Some(text) = args.text {
        text
    } else {
        anyhow::bail!("Must specify either --text or --stdin");
    };

    let anchor = parse_anchor_with_auto_hhmm(&args.anchor)?;

    let opts = AppendOptions {
        heading: &args.heading,
        anchor,
        content: &content,
    };

    append_block(&vault, &target_path, opts)?;

    Ok(())
}

fn handle_sync(vault_override: Option<std::path::PathBuf>, args: cli::SyncArgs) -> Result<()> {
    let (vault, _) = Vault::resolve_with_override(vault_override)?;

    let mut backend = GixBackend::open(vault.root())?;

    // Stage and commit any local changes
    backend.stage_all()?;

    let message = args.message.as_deref().unwrap_or("a4: sync");
    let committed = backend.commit_if_needed(message)?;

    if committed {
        tracing::info!("Created commit: {}", message);
    }

    let remote = args.remote.as_deref().unwrap_or("origin");
    let branch = args.branch.as_deref();

    // Fetch latest from remote
    backend.fetch(remote, branch)?;

    let remote_ref = if let Some(branch) = branch {
        format!("refs/remotes/{remote}/{branch}")
    } else {
        let current_branch = backend.head_branch()?;
        format!("refs/remotes/{remote}/{current_branch}")
    };

    // Try fast-forward first
    let fast_forwarded = backend.fast_forward_current_branch(&remote_ref)?;

    if fast_forwarded {
        tracing::info!("Fast-forwarded to {}", remote_ref);
    } else if backend.diverged(&remote_ref)? {
        // We have diverged - try to rebase
        tracing::info!("Detected divergence, attempting automatic rebase...");

        match backend.rebase_onto(&remote_ref)? {
            a4_core::git_backend::RebaseResult::Success => {
                tracing::info!("Successfully rebased onto {}", remote_ref);
                // Force push after successful rebase
                backend.push(remote, branch, true)?;
                tracing::info!("Pushed rebased changes to {}", remote);
                return Ok(());
            }
            a4_core::git_backend::RebaseResult::Conflict => {
                // There's a conflict - inform the user
                anyhow::bail!(
                    "Rebase conflict detected when syncing with {}. \
                    Please resolve the conflicts manually:\n\
                    1. Run 'git rebase {}' in the vault directory\n\
                    2. Resolve any conflicts\n\
                    3. Run 'git rebase --continue' after resolving\n\
                    4. Run 'a4 sync' again to push changes",
                    remote_ref,
                    remote_ref
                );
            }
            a4_core::git_backend::RebaseResult::NoRebaseNeeded => {
                // We're already up to date or ahead
                tracing::info!("No rebase needed");
            }
        }
    }

    // Push changes (normal push, not force)
    backend.push(remote, branch, false)?;

    println!("Sync completed successfully");

    Ok(())
}
