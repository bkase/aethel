//! Aethel CLI - Command-line interface for Aethel document management system

mod commands;
mod error;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::path::PathBuf;
use tracing_subscriber::EnvFilter;

/// Aethel document management system CLI
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Path to vault root (defaults to current directory or parent with docs/packs)
    #[arg(long, global = true)]
    vault_root: Option<PathBuf>,

    /// Override current timestamp (only with AETHEL_TEST_MODE=1)
    #[arg(long, global = true)]
    now: Option<String>,

    /// UUID generation seed for reproducible UUIDs (only with AETHEL_TEST_MODE=1)
    #[arg(long, global = true, value_name = "hex")]
    uuid_seed: Option<String>,

    /// Disable git operations (only with AETHEL_TEST_MODE=1)
    #[arg(long, global = true, default_value = "true")]
    git: bool,

    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
enum Commands {
    /// Initialize a new Aethel vault
    Init {
        /// Path to initialize vault in (defaults to current directory)
        path: Option<PathBuf>,
    },

    /// Write a document using a patch
    #[command(name = "write")]
    WriteDoc {
        /// Read patch from stdin as JSON
        #[arg(long, value_name = "-")]
        json: Option<String>,

        /// Output format
        #[arg(long, value_enum, default_value = "human")]
        output: OutputFormat,
    },

    /// Read a document by UUID
    #[command(name = "read")]
    ReadDoc {
        /// Document UUID
        uuid: uuid::Uuid,

        /// Output format
        #[arg(long, value_enum, default_value = "md")]
        output: ReadOutputFormat,
    },

    /// Check document validity
    #[command(name = "check")]
    CheckDoc {
        /// Document UUID
        uuid: uuid::Uuid,

        /// Attempt to auto-fix minor issues
        #[arg(long)]
        autofix: bool,

        /// Output format
        #[arg(long, value_enum, default_value = "human")]
        output: OutputFormat,
    },

    /// List installed packs
    #[command(name = "list")]
    ListPacks {
        /// Output format
        #[arg(long, value_enum, default_value = "human")]
        output: OutputFormat,
    },

    /// Add a pack from a local path or URL
    #[command(name = "add")]
    AddPack {
        /// Path or URL to pack
        source: String,

        /// Output format
        #[arg(long, value_enum, default_value = "human")]
        output: OutputFormat,
    },

    /// Remove an installed pack
    #[command(name = "remove")]
    RemovePack {
        /// Pack name
        name: String,

        /// Output format
        #[arg(long, value_enum, default_value = "human")]
        output: OutputFormat,
    },
}

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
enum OutputFormat {
    Human,
    Json,
}

#[derive(Debug, Clone, Copy, clap::ValueEnum)]
enum ReadOutputFormat {
    Md,
    Json,
}

fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt()
        .with_env_filter(
            EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")),
        )
        .init();

    // Parse CLI arguments
    let cli = Cli::parse();

    // Check test mode
    let test_mode = std::env::var("AETHEL_TEST_MODE").unwrap_or_default() == "1";

    // Validate test mode flags
    if !test_mode && (cli.now.is_some() || cli.uuid_seed.is_some() || !cli.git) {
        anyhow::bail!("Test mode flags (--now, --uuid-seed, --git) require AETHEL_TEST_MODE=1");
    }

    // Set up test mode context if enabled
    if test_mode {
        aethel_core::test_mode::init_test_mode(
            cli.now.as_deref(),
            cli.uuid_seed.as_deref(),
            cli.git,
        );
    }

    // Execute command
    match &cli.command {
        Commands::Init { path } => {
            commands::init::execute(path.clone())?;
        }
        _ => {
            // All other commands need a vault root
            let vault_root = resolve_vault_root(&cli)?;

            match cli.command {
                Commands::WriteDoc { json, output } => {
                    commands::write::execute(&vault_root, json.as_deref(), output)?;
                }
                Commands::ReadDoc { uuid, output } => {
                    commands::read::execute(&vault_root, uuid, output)?;
                }
                Commands::CheckDoc {
                    uuid,
                    autofix,
                    output,
                } => {
                    commands::check::execute(&vault_root, uuid, autofix, output)?;
                }
                Commands::ListPacks { output } => {
                    commands::list::execute(&vault_root, output)?;
                }
                Commands::AddPack { source, output } => {
                    commands::add_pack::execute(&vault_root, &source, output)?;
                }
                Commands::RemovePack { name, output } => {
                    commands::remove_pack::execute(&vault_root, &name, output)?;
                }
                Commands::Init { .. } => unreachable!(),
            }
        }
    }

    Ok(())
}

/// Resolve vault root from CLI args or find it
fn resolve_vault_root(cli: &Cli) -> Result<PathBuf> {
    match &cli.vault_root {
        Some(path) => Ok(path.clone()),
        None => find_vault_root(),
    }
}

/// Find vault root by looking for docs/ and packs/ directories
fn find_vault_root() -> Result<PathBuf> {
    use crate::error::AethelCliError;
    use std::env;

    let mut current = env::current_dir()?;

    loop {
        if current.join("docs").is_dir() && current.join("packs").is_dir() {
            return Ok(current);
        }

        if let Some(parent) = current.parent() {
            current = parent.to_path_buf();
        } else {
            return Err(
                AethelCliError::VaultRootNotFound(env::current_dir().unwrap_or_default()).into(),
            );
        }
    }
}
