alias uf := update-flake-dependencies
alias uc := update-cargo-dependencies
alias f := fmt
alias l := lint

actionlint:
	nix develop --command actionlint --ignore 'SC2002'
fmt:
	nix develop .#fmtShell --command treefmt --config-file ./.treefmt.toml --tree-root ./.
lint:
    cargo clippy
    nix run nixpkgs#typos
    cargo udeps

# Update and then commit the `Cargo.lock` file
update-cargo-dependencies:
	cargo update
	git add Cargo.lock
	git commit Cargo.lock -m "update(cargo): `Cargo.lock`"

update-flake-dependencies:
	nix flake update --commit-lock-file
