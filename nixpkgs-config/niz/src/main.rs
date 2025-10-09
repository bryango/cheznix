use clap::{Parser, Subcommand, value_parser};
use clap_complete::Shell;
use clap_verbosity_flag::{InfoLevel, Verbosity};
use log::debug;
use std::{
    env,
    os::unix::process::CommandExt,
    path::{Path, PathBuf},
    process::Command,
};

mod utils;

#[derive(Parser)]
struct NizCli {
    #[command(subcommand)]
    op: Operations,

    #[command(flatten)]
    verbosity: Verbosity<InfoLevel>,
}

#[derive(Subcommand)]
enum Operations {
    /// Nixpkgs git revisions & pull requests status
    Pkgs {
        /// - When there is no argument, print the current git revision of
        ///   "nixpkgs-unstable"
        ///
        /// - When there is a single argument, interpret it as a pull request
        ///   number or a git ref, and compare it with "nixpkgs-unstable"
        ///
        /// - When there are two arguments, e.g. ref1 and ref2, compare them
        ///   as "git diff ref1...ref2"
        ///
        /// The result of the comparison is a simple statement of whether
        /// ref2 is "ahead" or "behind" of ref1.
        #[arg(verbatim_doc_comment)]
        args: Vec<String>,
    },
    /// Nix build planning & execution
    Build {
        #[command(subcommand)]
        op: Build,
    },
    /// Flake metadata improved
    Flake {
        #[command(subcommand)]
        op: Flake,
    },

    /// Shell completions
    Completions {
        /// Specify shell
        #[arg(value_parser = value_parser!(Shell))]
        shell: Option<Shell>,
    },
}

#[derive(Subcommand)]
enum Build {
    /// nix build --dry-run, serialized to JSON
    Plan,
}

#[derive(Subcommand)]
enum Flake {
    /// nix flake metadata, simplified
    Tree,
}

fn main() -> anyhow::Result<()> {
    let cli = NizCli::parse();
    let _log_handle = utils::set_up_logger(cli.verbosity.log_level_filter()).start()?;

    let niz_dir = env::var("out")
        .and_then(|x| match x.trim() {
            "" => Err(env::VarError::NotPresent),
            x => {
                let scripts_head = format!("{x}/share/niz");
                if Path::new(&scripts_head).exists() {
                    Ok(scripts_head)
                } else {
                    Err(env::VarError::NotPresent)
                }
            }
        })
        .unwrap_or(env!("CARGO_MANIFEST_DIR").to_string());

    let scripts_dir = PathBuf::from(niz_dir).join("scripts");
    let exec_script = |path, args| {
        let program = scripts_dir.join(path);
        debug!("exec {}", program.to_string_lossy());
        let err = Command::new(program).args(args).exec();
        Err(err)
    };

    match cli.op {
        Operations::Pkgs { args } => {
            exec_script("pr-checker.sh", args)?;
        }
        Operations::Build { op } => match op {
            Build::Plan => {
                exec_script("build-plan.py", vec![])?;
            }
        },
        Operations::Flake { op } => match op {
            Flake::Tree => {
                exec_script("flake-tree.py", vec![])?;
            }
        },
        Operations::Completions { shell } => {
            let completions_text = utils::generate_shell_completions::<NizCli>(shell)?;
            print!("{completions_text}");
        } // _ => todo!(),
    }
    Ok(())
    // _log_handle is dropped here
}
