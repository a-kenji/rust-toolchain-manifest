{
  self,
  lib,
  pkgs,
}:
let
  root = ../.;
  cargoTOML = builtins.fromTOML (builtins.readFile (root + "/Cargo.toml"));
  inherit (cargoTOML.package) version name;
  pname = name;
  gitDate = "${builtins.substring 0 4 self.lastModifiedDate}-${
    builtins.substring 4 2 self.lastModifiedDate
  }-${builtins.substring 6 2 self.lastModifiedDate}";
  gitRev = self.shortRev or self.dirtyShortRev;
  meta = import ./meta.nix { inherit lib; };

  rustToolchain = (import ./rust-toolchain.nix { inherit self pkgs; }).rustToolchain;
  craneLib = (self.inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;

  fileset = lib.fileset.unions [
    (root + "/Cargo.toml")
    (root + "/Cargo.lock")
    (root + "/src")
  ];
  buildInputs = with pkgs; [ openssl ];
  nativeBuildInputs = with pkgs; [ pkg-config ];
  commonArgs = {
    inherit
      version
      name
      pname
      buildInputs
      nativeBuildInputs
      ;
    src = lib.fileset.toSource {
      inherit root fileset;
    };
  };
  cargoArtifacts = craneLib.buildDepsOnly commonArgs;
  cargoClippy = craneLib.cargoClippy (commonArgs // { inherit cargoArtifacts; });
  cargoDeny = craneLib.cargoDeny (
    commonArgs
    // {
      inherit cargoArtifacts;
      cargoDenyChecks = "sources";
    }
  );
  cargoTarpaulin = craneLib.cargoTarpaulin (commonArgs // { inherit cargoArtifacts; });
  cargoDoc = craneLib.cargoDoc (commonArgs // { inherit cargoArtifacts; });
  cargoTest = craneLib.cargoNextest (commonArgs // { inherit cargoArtifacts; });
in
{
  rust-toolchain-manifest = craneLib.buildPackage (
    commonArgs
    // {
      cargoExtraArgs = "-p ${name}";
      env = {
        GIT_DATE = gitDate;
        GIT_REV = gitRev;
      };
      doCheck = false;
      version = version + "-unstable-" + gitDate;
      inherit
        name
        pname
        cargoArtifacts
        meta
        ;
    }
  );
  inherit
    cargoClippy
    cargoArtifacts
    cargoDeny
    cargoTarpaulin
    cargoDoc
    cargoTest
    ;
}
