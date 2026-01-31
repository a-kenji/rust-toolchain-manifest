_: {
  perSystem =
    { self', ... }:
    {
      packages = rec {
        default = rust-toolchain-manifest;
        inherit (self'.checks)
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
