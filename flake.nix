{
  description = "update-rust-action";

  inputs.rust-overlay = {
    url = "github:oxalica/rust-overlay";
    inputs.nixpkgs.follows = "nixpkgs";
    inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    rust-overlay,
  }:
    flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      overlays = [(import rust-overlay)];
      rustPkgs = import nixpkgs {
        inherit system overlays;
      };
      src = self;
      RUST_TOOLCHAIN = src + "/rust-toolchain.toml";
      cargoTOML = builtins.fromTOML (builtins.readFile (src + "/Cargo.toml"));
      inherit (cargoTOML.package) name version;
      rustToolchainTOML = rustPkgs.rust-bin.fromRustupToolchainFile RUST_TOOLCHAIN;
      rustToolchainDevTOML = rustToolchainTOML.override {
        extensions = ["rustfmt" "clippy" "rust-analysis" "rust-docs"];
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

      buildInputs = [
        pkgs.openssl
      ];
      nativeBuildInputs = [
        pkgs.pkg-config
      ];
      devInputs = [
        rustToolchainDevTOML
        pkgs.cargo-deny
        (pkgs.symlinkJoin {
          name = "cargo-udeps-wrapped";
          paths = [pkgs.cargo-udeps];
          nativeBuildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/cargo-udeps \
              --prefix PATH : ${pkgs.lib.makeBinPath [
              (rustPkgs.rust-bin.selectLatestNightlyWith
                (toolchain: toolchain.default))
            ]}
          '';
        })
      ];
      shellInputs = [
        pkgs.shellcheck
        pkgs.actionlint
      ];
      fmtInputs = [
        pkgs.alejandra
        pkgs.treefmt
      ];
      editorConfigInputs = [
        pkgs.editorconfig-checker
      ];
      actionlintInputs = [
        pkgs.actionlint
      ];
      update-channel = channel:
        pkgs.writeScriptBin "update-${channel}" ''
          set -x
           git config --local user.name "github-actions[bot]"
           nix run -L github:$GITHUB_REPOSITORY \
             --no-write-lock-file \
             -- \
             --output ./outputs \
             ${channel}
           git add .
           git commit -m "$(date)"
           git push
        '';
    in {
      devShells = {
        default = pkgs.mkShell {
          name = "rust-toolchain-manifest-env";
          buildInputs = shellInputs ++ fmtInputs ++ devInputs ++ buildInputs ++ nativeBuildInputs;
        };
        editorConfigShell = pkgs.mkShell {
          buildInputs = editorConfigInputs;
        };
        actionlintShell = pkgs.mkShell {
          buildInputs = actionlintInputs;
        };
        fmtShell = pkgs.mkShell {
          buildInputs = fmtInputs;
        };
      };
      packages = {
        default =
          (
            pkgs.makeRustPlatform {
              inherit cargo rustc;
            }
          )
          .buildRustPackage {
            cargoDepsName = name;
            GIT_DATE = gitDate;
            GIT_REV = gitRev;
            inherit name version src nativeBuildInputs buildInputs cargoLock;
          };
      };
      ci = {
        update-nightly = update-channel "nightly";
        update-beta = update-channel "beta";
      };

      formatter = pkgs.alejandra;
    });
}
