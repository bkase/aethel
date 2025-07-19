use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(name = "aethel")]
#[command(about = "A Git-native data vault with plugin-based architecture", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Initialize a new Aethel vault
    Init {
        /// Path to create the vault
        path: String,
    },


    /// Retrieve an artifact
    Get {
        /// UUID of the artifact
        #[arg(long)]
        uuid: String,

        /// Output format
        #[arg(long, default_value = "markdown")]
        format: OutputFormat,
    },

    /// Write content to an artifact (create new or append to existing)
    Write {
        /// UUID of existing artifact (if appending)
        #[arg(long)]
        uuid: Option<String>,

        /// Type of artifact to create (required for new artifacts)
        #[arg(long, short = 't')]
        r#type: Option<String>,

        /// Content to write
        #[arg(long)]
        content: String,

        /// Title for the artifact (new artifacts only)
        #[arg(long)]
        title: Option<String>,

        /// Additional fields as key=value pairs
        #[arg(long = "field", short = 'f', value_parser = parse_key_val)]
        fields: Vec<(String, String)>,
    },

    /// Validate and optionally fix the vault
    Doctor {
        /// Fix issues automatically
        #[arg(long)]
        fix: bool,

        /// Rebuild the artifact index
        #[arg(long)]
        rebuild_index: bool,
    },
}

#[derive(Clone, Debug, clap::ValueEnum)]
pub enum OutputFormat {
    Markdown,
    Json,
}

fn parse_key_val(s: &str) -> Result<(String, String), String> {
    let pos = s
        .find('=')
        .ok_or_else(|| format!("no `=` found in `{s}`"))?;
    Ok((s[..pos].to_string(), s[pos + 1..].to_string()))
}
