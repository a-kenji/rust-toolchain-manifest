use std::path::PathBuf;

use clap::Parser;

use crate::Channel;

#[derive(Parser)]
#[command(author, version = CliArgs::unstable_version(), about, long_about = None)]
#[command(next_line_help = true)]
pub(crate) struct CliArgs {
    channel: Channel,
    /// The output directory
    #[clap(long, value_parser, default_value = "./outputs")]
    output: Option<PathBuf>,
}

impl CliArgs {
    /// Surface current version together with the current git revision and date, if available
    fn unstable_version() -> &'static str {
        const VERSION: &str = env!("CARGO_PKG_VERSION");
        let date = option_env!("GIT_DATE").unwrap_or("no_date");
        let rev = option_env!("GIT_REV").unwrap_or("no_rev");
        // This is a memory leak, only use sparingly.
        Box::leak(format!("{VERSION} - {date} - {rev}").into_boxed_str())
    }

    /// The output directory, defaults to `[./outputs]`
    pub(crate) fn output(&self) -> String {
        self.output
            .clone()
            .unwrap_or_else(|| std::path::PathBuf::from("outputs"))
            .into_os_string()
            .into_string()
            .unwrap()
    }

    /// The current channel that should get updated
    pub(crate) fn channel(&self) -> &Channel {
        &self.channel
    }
}
