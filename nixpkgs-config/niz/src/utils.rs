//! Utilities for main.rs

use anyhow::anyhow;
use clap::Parser;
use clap_complete::Shell;
use flexi_logger::{Logger, filter::LogLineFilter};
use yansi::{Color, Paint};

fn log_format(
    w: &mut dyn std::io::Write,
    _now: &mut flexi_logger::DeferredNow,
    record: &log::Record,
) -> Result<(), std::io::Error> {
    let level = record.level();
    let color = match level {
        log::Level::Error => Color::Red,
        log::Level::Warn => Color::Yellow,
        _ => Color::default(),
    };
    let level = format!("{level}:").to_lowercase();
    let module = record.module_path().unwrap_or_default();
    let main_module = env!("CARGO_CRATE_NAME");
    write!(
        w,
        "{} {}{}",
        level.fg(color).bold(),
        (!module.starts_with(main_module))
            .then_some(format!("[{module}] "))
            .unwrap_or_default(),
        &record.args()
    )
}

struct LogFilter;
impl LogLineFilter for LogFilter {
    fn write(
        &self,
        now: &mut flexi_logger::DeferredNow,
        record: &log::Record,
        log_line_writer: &dyn flexi_logger::filter::LogLineWriter,
    ) -> std::io::Result<()> {
        let module = record.module_path().unwrap_or_default();
        let blacklist = ["selectors", "html5ever"];
        if blacklist.iter().any(|x| module.starts_with(x)) && record.level() != log::Level::Trace {
            return Ok(()); // skip log
        }
        log_line_writer.write(now, record)
    }
}

pub(super) fn set_up_logger(logspec: impl Into<flexi_logger::LogSpecification>) -> Logger {
    Logger::with(logspec)
        .format(log_format)
        .filter(Box::new(LogFilter))
}

pub(super) fn generate_shell_completions<T: Parser>(
    shell: Option<Shell>,
) -> anyhow::Result<String> {
    let mut cmd = T::command();
    let bin_name = cmd.get_name().to_string();

    let shell = shell.or_else(Shell::from_env).ok_or_else(|| {
        anyhow!("could not detect the current shell, please specify --shell explicitly")
    })?;

    let mut buf = Vec::new();
    clap_complete::generate(shell, &mut cmd, bin_name, &mut buf);
    let completion_text = String::from_utf8(buf)?;
    Ok(completion_text)
}
