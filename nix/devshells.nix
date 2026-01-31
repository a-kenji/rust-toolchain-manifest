{ self, ... }:
{
  perSystem =
    {
      pkgs,
      self',
      ...
    }:
    let
      env = import ./env.nix { inherit pkgs; };
      rustToolchain = import ./rust-toolchain.nix { inherit self pkgs; };
    in
    {
      devShells = {
        default = pkgs.mkShellNoCC {
          name = "rust-toolchain-manifest";
          inputsFrom = [ self'.packages.default ];
          packages = [
            rustToolchain.rustToolchain
            pkgs.rust-analyzer
            self'.formatter.outPath
          ];
          inherit env;
        };
        full = pkgs.mkShellNoCC {
          name = "rust-toolchain-manifest-full";
          inputsFrom = [ self'.devShells.default ];
          packages = [
            pkgs.cargo-deny
            pkgs.cargo-diet
            pkgs.cargo-rdme
            pkgs.cargo-tarpaulin
            pkgs.lychee
            pkgs.shellcheck
            pkgs.actionlint
            (pkgs.symlinkJoin {
              name = "cargo-udeps-wrapped";
              paths = [ pkgs.cargo-udeps ];
              nativeBuildInputs = [ pkgs.makeWrapper ];
              postBuild = ''
                wrapProgram $out/bin/cargo-udeps \
                  --prefix PATH : ${pkgs.lib.makeBinPath [ rustToolchain.latestNightly ]}
              '';
            })
          ];
          inherit env;
        };
      };
    };
}
