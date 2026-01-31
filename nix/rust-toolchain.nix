{
  self,
  pkgs,
}:
let
  root = ../.;

  # Rust toolchain from rust-toolchain.toml via rust-overlay
  rustPkgs = import self.inputs.nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    overlays = [ (import self.inputs.rust-overlay) ];
  };

  rustToolchain =
    (rustPkgs.rust-bin.fromRustupToolchainFile (root + "/rust-toolchain.toml")).override
      {
        extensions = [
          "clippy"
          "rust-analysis"
          "rust-docs"
        ];
      };

  latestNightly = rustPkgs.rust-bin.selectLatestNightlyWith (toolchain: toolchain.default);
in
{
  inherit
    rustPkgs
    rustToolchain
    latestNightly
    ;
}
