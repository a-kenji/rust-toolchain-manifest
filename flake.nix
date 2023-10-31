{
  description = "rust-toolchain-manifest";

  inputs.rust-overlay = {
    url = "github:oxalica/rust-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  inputs.crane = {
    url = "github:ipetkov/crane";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        stdenv =
          if pkgs.stdenv.isLinux
          then pkgs.stdenvAdapters.useMoldLinker pkgs.stdenv
          else pkgs.stdenv;

        overlays = [(import rust-overlay)];
        rustPkgs = import nixpkgs {inherit system overlays;};
        src = self;
        RUST_TOOLCHAIN = src + "/rust-toolchain.toml";
        RUSTFMT_TOOLCHAIN = src + "/.rustfmt-toolchain.toml";
        rustFmtToolchainTOML =
          rustPkgs.rust-bin.fromRustupToolchainFile
          RUSTFMT_TOOLCHAIN;

        cargoTOML = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
        inherit (cargoTOML.package) name version;
        rustToolchainTOML = rustPkgs.rust-bin.fromRustupToolchainFile RUST_TOOLCHAIN;
        rustToolchainDevTOML = rustToolchainTOML.override {
          extensions = [
            "clippy"
            "rust-analysis"
            "rust-docs"
          ];
          targets = [];
        };
        gitDate = self.lastModifiedDate;
        gitRev = self.shortRev or "Not committed yet.";
        cargoLock = {
          lockFile = builtins.path {
            path = self + "/Cargo.lock";
            name = "Cargo.lock";
          };
        };
        rustc = rustToolchainTOML;
        cargo = rustToolchainTOML;

        buildInputs = [pkgs.openssl];
        nativeBuildInputs = [pkgs.pkg-config];
        devInputs = [
          rustToolchainDevTOML
          rustFmtToolchainTOML
          pkgs.cargo-deny
          pkgs.cargo-diet
          pkgs.lychee
          (pkgs.symlinkJoin {
            name = "cargo-udeps-wrapped";
            paths = [pkgs.cargo-udeps];
            nativeBuildInputs = [pkgs.makeWrapper];
            postBuild = ''
              wrapProgram $out/bin/cargo-udeps \
                --prefix PATH : ${
                pkgs.lib.makeBinPath [
                  (rustPkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default))
                ]
              }
            '';
          })
          pkgs.cargo-rdme
        ];
        shellInputs = [
          pkgs.shellcheck
          pkgs.actionlint
        ];
        fmtInputs = [
          rustFmtToolchainTOML
          pkgs.alejandra
          pkgs.treefmt
          pkgs.taplo
        ];
        editorConfigInputs = [pkgs.editorconfig-checker];
        actionlintInputs = [pkgs.actionlint];
        update-channel = channel:
          pkgs.writeScriptBin "update-${channel}" ''
            set -x
             git config user.name "github-actions[bot]"
             git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
             nix run -L github:$GITHUB_REPOSITORY \
               --no-write-lock-file \
               -- \
               --output ./outputs \
               ${channel}
             git add .
             git commit -m "$(date)"
             git push
          '';
        commonArgs = {
          inherit
            src
            buildInputs
            nativeBuildInputs
            stdenv
            version
            name
            ;
          pname = name;
        };
        craneLib = (crane.mkLib pkgs).overrideToolchain rustToolchainTOML;
        cranePackage = craneLib.buildPackage (commonArgs // {});
        cargoArtifacts = craneLib.buildDepsOnly commonArgs;
        cargoDoc = craneLib.cargoDoc (commonArgs // {inherit cargoArtifacts;});
        cargoClippy = craneLib.cargoClippy (
          commonArgs
          // {
            inherit cargoArtifacts;
            nativeBuildInputs = nativeBuildInputs ++ [rustToolchainDevTOML];
          }
        );
        cargoDeny = craneLib.cargoDeny (
          commonArgs
          // {
            inherit cargoArtifacts;
            cargoDenyChecks = "licenses sources";
          }
        );
        cargoTarpaulin = craneLib.cargoTarpaulin (
          commonArgs // {inherit cargoArtifacts;}
        );
      in {
        devShells = {
          default = (pkgs.mkShell.override {inherit stdenv;}) {
            name = "rust-toolchain-manifest";
            buildInputs =
              shellInputs ++ devInputs ++ fmtInputs ++ buildInputs ++ nativeBuildInputs;
          };
          editorConfigShell = pkgs.mkShell {buildInputs = editorConfigInputs;};
          actionlintShell = pkgs.mkShell {buildInputs = actionlintInputs;};
          fmtShell = pkgs.mkShell {buildInputs = fmtInputs;};
        };
        packages = rec {
          default = rust-toolchain-manifest;
          rust-toolchain-manifest = cranePackage;
          # Uses nixpkgs native builder
          upstream = (pkgs.makeRustPlatform {inherit cargo rustc;}).buildRustPackage {
            cargoDepsName = name;
            GIT_DATE = gitDate;
            GIT_REV = gitRev;
            inherit
              name
              version
              src
              stdenv
              nativeBuildInputs
              buildInputs
              cargoLock
              ;
          };
          inherit
            cargoArtifacts
            cargoClippy
            cargoDoc
            cargoDeny
            cargoTarpaulin
            ;
        };
        ci = {
          update-nightly = update-channel "nightly";
          update-beta = update-channel "beta";
        };

        formatter = pkgs.alejandra;
      }
    );
}
