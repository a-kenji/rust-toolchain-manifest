# rust-toolchain-manifest
<p align="center">
  <a href="https://crates.io/crates/rust-toolchain-manifest"><img alt="rust-toolchain-manifest Version Information" src="https://img.shields.io/crates/v/rust-toolchain-manifest?style=flat-square"</a>
</p>

Query the official rust release manifests

# Install
```
cargo install --locked rust-toolchain-manifest
```

<!-- cargo-rdme start -->

Downloads the official rust release manifests,
parses them and saves them as json objects.

## Usage:
```rust
rust-toolchain-manifest [CHANNEL]
```
The channel can be either `stable`, `beta`, or `nightly`.

For `beta` and `nightly` channels components are split up into the
date of the channel `[CHANNEL]/[YEAR]/[date].json`
and a map `[CHANNEL]/[YEAR]/since[date]-map.json`,
that can potentially be reused by further channel updates,
in order to not save unnecessary state.

The tree of a channel will potentially look like this:
```text
   nightly
   └── 2022
       ├── 2022-10-05.json
       ├── 2022-10-06.json
       ├── 2022-10-07.json
       ├── metadata.json
       └── since-2022-10-05-map.json
```

- `metadata.json`:
Saves state about the current channel.
- `[date].json`:
Saves state on the channel on the specified `[date]`.
- `since-[date]-map.json`:
A helper map, that allows the `[date].json` snapshots of channels to be fairly small.

<!-- cargo-rdme end -->
