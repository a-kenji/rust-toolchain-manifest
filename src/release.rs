use std::{
    collections::{BTreeMap, HashMap},
    fs::File,
    io::Read,
};

use serde::{Deserialize, Serialize, Serializer};

use crate::error::RustToolchainError;

#[derive(Debug, Clone, Deserialize)]
pub(crate) struct PreRelease {
    date: String,
    pkg: HashMap<String, Component>,
    renames: HashMap<String, Rename>,
    // profiles: Option<HashMap<String, Vec<String>>>,
}

#[derive(Debug, Clone, Deserialize)]
pub(crate) struct Component {
    version: String,
    // git_commit_hash: Option<String>,
    target: HashMap<String, Target>,
}

#[derive(Debug, Clone, Deserialize)]
pub(crate) struct Target {
    available: bool,
    // url: Option<String>,
    // hash: Option<String>,
    // xz_url: Option<String>,
    // xz_hash: Option<String>,
}
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq, Default)]
pub(crate) struct Rename {
    to: String,
}

#[derive(Debug, Deserialize, Serialize)]
pub(crate) struct PreReleaseOutputs {
    date: String,
    version: String,
    #[serde(serialize_with = "ordered_map")]
    components: HashMap<String, Vec<usize>>,
}

///  A helper function that converts HashMap values into an Ordered Json map upon serialization
fn ordered_map<K: Ord + Serialize, V: Serialize, S>(
    value: &HashMap<K, V>,
    serializer: S,
) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let ordered: BTreeMap<_, _> = value.iter().collect();
    ordered.serialize(serializer)
}

impl PreReleaseOutputs {
    pub(crate) fn date(&self) -> &str {
        self.date.as_ref()
    }
}

#[derive(Debug, Deserialize, Serialize, PartialEq, Default)]
pub(crate) struct TargetMap {
    #[serde(flatten)]
    #[serde(serialize_with = "ordered_map")]
    components: HashMap<String, Vec<String>>,
    #[serde(serialize_with = "ordered_map")]
    renames: HashMap<String, Rename>,
}

impl TargetMap {
    pub(crate) fn try_from_path(path: &str) -> Result<TargetMap, RustToolchainError> {
        let mut file = File::open(path)?;
        let mut data = String::new();
        file.read_to_string(&mut data)?;
        serde_json::from_str(&data).map_err(|e| e.into())
    }
}

#[derive(Debug, Deserialize, Serialize, PartialEq)]
pub(crate) struct MetaData {
    latest_version: semver::Version,
    latest_date: String,
    pub(crate) latest_map: Option<String>,
}

impl Default for MetaData {
    fn default() -> Self {
        Self::new(semver::Version::new(0, 0, 0), String::new())
    }
}

impl MetaData {
    fn new(latest_version: semver::Version, latest_date: String) -> Self {
        Self {
            latest_version,
            latest_date,
            latest_map: None,
        }
    }

    pub(crate) fn try_from_path(path: &str) -> Result<MetaData, RustToolchainError> {
        let mut file = File::open(path)?;
        let mut data = String::new();
        file.read_to_string(&mut data)?;
        serde_json::from_str(&data).map_err(|e| e.into())
    }

    pub(crate) fn set_latest_map(&mut self, latest_map: Option<String>) {
        self.latest_map = latest_map;
    }
}

impl TryFrom<PreRelease> for MetaData {
    type Error = semver::Error;

    fn try_from(pre_release: PreRelease) -> Result<Self, Self::Error> {
        let version = pre_release
            .pkg
            .get("rust")
            .unwrap()
            .version
            .to_owned()
            .split_once(' ')
            .unwrap()
            .0
            .to_owned();
        let version = semver::Version::parse(&version)?;
        let date = pre_release.date;
        Ok(Self::new(version, date))
    }
}

#[derive(Debug, Clone)]
pub(crate) enum Channel {
    Nightly,
    Beta,
    Stable,
}

impl std::str::FromStr for Channel {
    type Err = RustToolchainError;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "nightly" => Ok(Self::Nightly),
            "beta" => Ok(Self::Beta),
            "stable" => Ok(Self::Stable),
            _ => Err(RustToolchainError::IncorrectChannel(
                "Please use one of 'nightly', 'beta', or 'stable'".to_owned(),
            )),
        }
    }
}

impl From<PreRelease> for PreReleaseOutputs {
    fn from(input: PreRelease) -> Self {
        let date = input.date;
        let version = input
            .pkg
            .get("rust")
            .unwrap()
            .version
            .to_owned()
            .split_once(' ')
            .unwrap()
            .0
            .to_owned();
        let mut components = HashMap::new();
        for (k, component) in input.pkg {
            let mut targets = Vec::new();
            let mut keys: Vec<String> = component.target.keys().map(|k| k.to_owned()).collect();
            keys.sort();
            for (i, v) in keys.into_iter().enumerate() {
                if let Some(target) = component.target.get(&v) {
                    if target.available {
                        targets.push(i);
                    }
                }
            }
            components.insert(k, targets);
        }
        Self {
            date,
            version,
            components,
        }
    }
}
impl From<PreRelease> for TargetMap {
    fn from(input: PreRelease) -> Self {
        let mut components = HashMap::new();
        for (k, component) in input.pkg {
            let mut keys: Vec<String> = component.target.keys().map(|k| k.to_owned()).collect();
            keys.sort();
            components.insert(k, keys);
        }
        Self {
            components,
            renames: input.renames,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn rename_input() -> &'static str {
        r#"
        [rust-analyzer]
        to = "rust-analyzer-preview"
        [rust-docs-json]
        to = "rust-docs-json-preview"
        "#
    }
    fn target_input() -> &'static str {
        r#"
        [aarch64-pc-windows-msvc]
        available = true
        url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-pc-windows-msvc.tar.gz"
        hash = "29445be91e4c1efc6cf2a7444aecafd930d64b5f9d94986bea58cec3b7f2497b"
        xz_url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-pc-windows-msvc.tar.xz"
        xz_hash = "a7ef27e516d802c9427c2596149ef44d5ac876f97d57bdb063123011a01964a5"
        "#
    }
    fn target_inputs() -> &'static str {
        r#"
        [aarch64-pc-windows-msvc]
        available = true
        url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-pc-windows-msvc.tar.gz"
        hash = "29445be91e4c1efc6cf2a7444aecafd930d64b5f9d94986bea58cec3b7f2497b"
        xz_url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-pc-windows-msvc.tar.xz"
        xz_hash = "a7ef27e516d802c9427c2596149ef44d5ac876f97d57bdb063123011a01964a5"
        [mipsisa64r6el-unknown-linux-gnuabi64]
        available = false
        "#
    }
    fn component_inputs() -> &'static str {
        r#"
        [cargo]
        version = "0.66.0-nightly (73ba3f35e 2022-09-18)"
        git_commit_hash = "3f83906b30798bf61513fa340524cebf6676f9db"

        [cargo.target.armv7-unknown-linux-gnueabihf]
        available = true
        url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-armv7-unknown-linux-gnueabihf.tar.gz"
        hash = "a798ab508b69ee163382716d2c084dd9fcc90cd8078b3d79f29e3eead771f899"
        xz_url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-armv7-unknown-linux-gnueabihf.tar.xz"
        xz_hash = "dbc63ad7f20340a48e71efe7505709785bfaae382846e22eef8bf676353f5ad5"

        [cargo.target.i686-apple-darwin]
        available = false

        [cargo.target.i686-pc-windows-gnu]
        available = true
        url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-i686-pc-windows-gnu.tar.gz"
        hash = "970bd239c328795fd117e428c4e1dd1fa3c518beebc848807615413a7b28902d"
        xz_url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-i686-pc-windows-gnu.tar.xz"
        xz_hash = "31c0959dc715d99f4b1581b0168922cecb99c62775af2d07837f385df00e80ca"
        "#
    }
    fn release_inputs() -> &'static str {
        r#"
        manifest-version = "2"
        date = "2022-09-25"
        [pkg.cargo]
        version = "0.66.0-nightly (73ba3f35e 2022-09-18)"
        git_commit_hash = "3f83906b30798bf61513fa340524cebf6676f9db"
        [pkg.cargo.target.aarch64-apple-darwin]
        available = true
        url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-apple-darwin.tar.gz"
        hash = "5dffd1d0a447f029c141bf8906e46c8f444847df802b5c92ddf8f3ed08268b86"
        xz_url = "https://static.rust-lang.org/dist/2022-09-25/cargo-nightly-aarch64-apple-darwin.tar.xz"
        xz_hash = "a870c680bc452c5fae498a4aba7a184d1e18fb6f46611ac68d790ae72c18adf9"
        [pkg.cargo.target.i686-apple-darwin]
        available = false
        [renames.rust-docs-json]
        to = "rust-docs-json-preview"

        [renames.rustfmt]
        to = "rustfmt-preview"
        "#
    }

    #[test]
    fn renames_parsed_is_ok() {
        let _serialised: HashMap<String, Rename> = toml::from_str(rename_input()).unwrap();
    }
    #[test]
    fn target_parsed_is_ok() {
        let _serialised: HashMap<String, Target> = toml::from_str(target_input()).unwrap();
    }
    #[test]
    fn targets_parsed_is_ok() {
        let _serialised: HashMap<String, Target> = toml::from_str(target_inputs()).unwrap();
    }
    #[test]
    fn components_parsed_is_ok() {
        let _serialised: HashMap<String, Component> = toml::from_str(component_inputs()).unwrap();
    }
    #[test]
    fn release_parsed_is_ok() {
        let _serialised: PreRelease = toml::from_str(release_inputs()).unwrap();
    }
}
