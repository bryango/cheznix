use clap::{Parser, Subcommand, value_parser};
use clap_complete::Shell;
use clap_verbosity_flag::{InfoLevel, Verbosity};
use log::debug;
use std::{
    env, fs,
    os::unix::process::CommandExt,
    path::{Path, PathBuf},
    process::Command,
};

mod flake_tree;
mod utils;

use crate::flake_tree::FlakeLock;

#[derive(Parser)]
struct NizCli {
    #[command(subcommand)]
    op: Operations,

    #[command(flatten)]
    verbosity: Verbosity<InfoLevel>,
}

#[derive(Subcommand)]
#[command(disable_help_subcommand = true)]
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
    Tree {
        // #[arg(long)]
        // placeholder_arg: Option<String>,
    },
}

fn main() -> anyhow::Result<()> {
    let cli = NizCli::parse();
    let _log_handle = utils::set_up_logger(cli.verbosity.log_level_filter()).start()?;

    let niz_dir = option_env!("out")
        .map_or(None, |out| match out.trim() {
            "" => None,
            out => {
                let scripts_head = format!("{out}/share/niz");
                if Path::new(&scripts_head).exists() {
                    Some(scripts_head)
                } else {
                    None
                }
            }
        })
        .unwrap_or_else(|| env!("CARGO_MANIFEST_DIR").to_string());

    let scripts_dir = PathBuf::from(niz_dir).join("scripts");
    let script_command = |path, args: &[&str]| -> Command {
        let program = scripts_dir.join(path);
        let mut cmd = Command::new(program);
        cmd.args(args);
        cmd
    };
    let exec_script = |path, args| {
        let mut cmd = script_command(path, args);
        debug!("exec {}", cmd.get_program().to_string_lossy());
        let err = cmd.exec();
        Err(err)
    };

    match cli.op {
        Operations::Pkgs { args } => {
            let args: Vec<&str> = args.iter().map(String::as_str).collect();
            exec_script("pr-checker.sh", args.as_slice())?;
        }
        Operations::Build { op } => match op {
            Build::Plan => {
                exec_script("build-plan.py", &[])?;
            }
        },
        Operations::Flake { op } => match op {
            Flake::Tree {
                // placeholder_arg: _
            } => {
                let lock_file = fs::read_to_string("./flake.lock")?;
                let json: FlakeLock = serde_json::from_str(&lock_file)?;
                let tree = json.nodes.make_tree()?;
                println!("{tree}");
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
