{ inputs, ... }:
{
  flake.ci =
    inputs.nixpkgs.lib.genAttrs
      [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ]
      (
        system:
        let
          pkgs = inputs.nixpkgs.legacyPackages.${system};
          update-channel =
            channel:
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
        in
        {
          update-nightly = update-channel "nightly";
          update-beta = update-channel "beta";
        }
      );
}
