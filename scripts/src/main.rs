use clap::Parser;
use eyre::Result;

mod declare;
use declare::declare;

mod deploy;
use deploy::deploy;

mod approve;
use approve::approve;

mod multisend;
use multisend::multisend;

#[derive(Debug, Parser)]
#[clap(author, version, about)]
enum Action {
    #[clap(name = "declare")]
    Declare {
        #[clap(short, long, help = "The sierra file path to declare")]
        sierra_file_path: String,
        #[clap(short, long, help = "The casm file path to declare")]
        casm_file_path: String,
    },
    #[clap(name = "deploy")]
    Deploy,
    #[clap(name = "approve")]
    Approve,
    #[clap(name = "multisend")]
    Multisend,
}

#[tokio::main]
async fn main() {
    if let Err(err) = run_command(Action::parse()).await {
        eprintln!("{}", format!("Error: {err}"));
        std::process::exit(1);
    }
}

async fn run_command(action: Action) -> Result<()> {
    match action {
        Action::Declare {
            sierra_file_path,
            casm_file_path,
        } => declare(sierra_file_path, casm_file_path).await,
        Action::Deploy => deploy().await,
        Action::Approve => approve().await,
        Action::Multisend => multisend().await,
    }
}
