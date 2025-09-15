use clap::{Parser, Subcommand};
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "a4")]
#[command(about = "A4 personal knowledge base", long_about = None)]
pub struct Cli {
    #[arg(long, value_name = "PATH", env = "A4_VAULT_DIR")]
    pub vault: Option<PathBuf>,

    #[arg(short = 'v', long, action = clap::ArgAction::Count)]
    pub verbose: u8,

    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    #[command(about = "Resolve path to today's daily note; create from template if absent")]
    Today,

    #[command(about = "Append block under anchor; create heading if missing")]
    Append(AppendArgs),

    #[command(about = "Sync vault with remote (fetch, commit, push)")]
    Sync(SyncArgs),
}

#[derive(Parser)]
pub struct AppendArgs {
    #[arg(long, value_name = "HEADING")]
    pub heading: String,

    #[arg(long, value_name = "TOKEN")]
    pub anchor: String,

    #[arg(long, value_name = "PATH", conflicts_with = "today")]
    pub file: Option<PathBuf>,

    #[arg(long, conflicts_with = "file")]
    pub today: bool,

    #[arg(
        long,
        value_name = "TEXT",
        conflicts_with = "stdin",
        allow_hyphen_values = true
    )]
    pub text: Option<String>,

    #[arg(long, conflicts_with = "text")]
    pub stdin: bool,
}

#[derive(Parser)]
pub struct SyncArgs {
    #[arg(long, value_name = "MSG")]
    pub message: Option<String>,

    #[arg(long, value_name = "NAME", default_value = "origin")]
    pub remote: Option<String>,

    #[arg(long, value_name = "NAME")]
    pub branch: Option<String>,

    #[arg(long, default_value = "true")]
    pub ff_only: bool,
}
