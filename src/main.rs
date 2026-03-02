//! Downloads the official rust release manifests,
//! parses them and saves them as json objects.
//!
//! # Usage:
//! ```
//! rust-toolchain-manifest [CHANNEL]
//! ```
//! The channel can be either `stable`, `beta`, or `nightly`.
//!
//! For `beta` and `nightly` channels components are split up into the
//! date of the channel `[CHANNEL]/[YEAR]/[date].json`
//! and a map `[CHANNEL]/[YEAR]/since[date]-map.json`,
//! that can potentially be reused by further channel updates,
//! in order to not save unnecessary state.
//!
//! The tree of a channel will potentially look like this:
//! ```text
//!    nightly
//!    └── 2022
//!        ├── 2022-10-05.json
//!        ├── 2022-10-06.json
//!        ├── 2022-10-07.json
//!        ├── metadata.json
//!        └── since-2022-10-05-map.json
//! ```
//!
//! - `metadata.json`:
//!   Saves state about the current channel.
//! - `[date].json`:
//!   Saves state on the channel on the specified `[date]`.
//! - `since-[date]-map.json`:
//!   A helper map, that allows the `[date].json` snapshots of channels to be fairly small.
mod cli;
mod error;
mod release;

use std::{fs::File, io::Write};

use chrono::{Datelike, Utc};
use clap::Parser;

use self::{
    cli::CliArgs,
    error::RustToolchainError,
    release::{Channel, MetaData, PreRelease, PreReleaseOutputs, TargetMap},
};

const METADATA_FILENAME: &str = "metadata.json";

fn main() -> Result<(), RustToolchainError> {
    let opts = CliArgs::parse();
    let location = opts.output();
    let year = Utc::now().year();
    let channel = opts.channel();

    let resp = reqwest::blocking::get(channel.manifest_url())?.text()?;
    let serialized: PreRelease = toml::from_str(&resp)?;
    let directory = format!("{location}/{channel}/{year}", channel = channel.as_str());
    write_pre_release(serialized, &directory)?;
    Ok(())
}

pub(crate) fn write_pre_release(
    serialized: PreRelease,
    directory: &str,
) -> Result<(), RustToolchainError> {
    std::fs::create_dir_all(directory)?;
    let identifier = <PreRelease as Into<PreReleaseOutputs>>::into(serialized.clone());
    let identifier = identifier.date();
    let mut meta_data: MetaData = serialized.clone().try_into()?;

    let mut file = File::create(format!("{directory}/{identifier}.json"))?;
    let outputs = serde_json::to_string::<PreReleaseOutputs>(&serialized.clone().into())?;
    file.write_all(outputs.as_bytes())?;

    // Read Metadata -> Read Map
    let prev_map_path = MetaData::try_from_path(&format!("{directory}/{METADATA_FILENAME}"))
        // If we error out here, we assume the map has not been written yet
        .unwrap_or_else(|_| MetaData::default())
        .latest_map;
    let prev_map = prev_map_path
        .as_ref()
        .map(|p| TargetMap::try_from_path(p))
        .transpose()?;

    let new_map: TargetMap = serialized.into();
    // If maps are identical, don't produce a new result.
    if prev_map.as_ref() != Some(&new_map) {
        let map_path = format!("{directory}/since-{identifier}-map.json");
        let mut map = File::create(&map_path)?;
        let outputs = serde_json::to_string(&new_map)?;
        map.write_all(outputs.as_bytes())?;
        meta_data.set_latest_map(Some(map_path));
    } else {
        meta_data.set_latest_map(prev_map_path);
    }

    let mut meta_file = File::create(format!("{directory}/{METADATA_FILENAME}"))?;
    let outputs = serde_json::to_string(&meta_data)?;
    meta_file.write_all(outputs.as_bytes())?;
    Ok(())
}
