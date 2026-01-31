{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      checks = {
        inherit ((pkgs.callPackage ./crane.nix { inherit self; }))
          rust-toolchain-manifest
          cargoArtifacts
          cargoClippy
          cargoDoc
          cargoTest
          cargoDeny
          cargoTarpaulin
          ;
      };
    };
}
