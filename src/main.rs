mod cli;
mod commands;
mod config;
mod error;
mod index;
mod models;
mod registry;
mod store;
mod utils;

use clap::Parser;
use cli::{Cli, Commands};
use error::Result;

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize tracing
    tracing_subscriber::fmt::init();

    let cli = Cli::parse();

    match cli.command {
        Commands::Init { path } => {
            commands::init::execute(&path).await?;
        }
        Commands::New {
            r#type,
            title,
            fields,
            body,
        } => {
            commands::new::execute(&r#type, title.as_deref(), &fields, body.as_deref()).await?;
        }
        Commands::Grow { uuid, content } => {
            commands::grow::execute(&uuid, &content).await?;
        }
        Commands::Get { uuid, format } => {
            commands::get::execute(&uuid, &format).await?;
        }
        Commands::Write {
            uuid,
            r#type,
            content,
            title,
            fields,
        } => {
            commands::write::execute(
                uuid.as_deref(),
                r#type.as_deref(),
                &content,
                title.as_deref(),
                &fields,
            )
            .await?;
        }
        Commands::Doctor { fix, rebuild_index } => {
            commands::doctor::execute(fix, rebuild_index).await?;
        }
    }

    Ok(())
}
