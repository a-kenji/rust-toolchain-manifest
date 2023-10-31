alias uf := update-flake-dependencies
alias uc := update-cargo-dependencies
alias f := fmt
alias l := lint
alias d := doc
alias r := run
alias b := build

_default:
    just --choose

actionlint:
	nix develop --command actionlint --ignore 'SC2002'
fmt:
	nix develop .#fmtShell --command treefmt
lint:
    cargo clippy
    -nix run nixpkgs#typos
    cargo udeps
    cargo diet
    lychee README.md

# Update and then commit the `Cargo.lock` file
update-cargo-dependencies:
	cargo update
	git add Cargo.lock
	git commit Cargo.lock -m "update(cargo): Cargo.lock"

update-flake-dependencies:
	nix flake update --commit-lock-file

doc:
    cargo doc --open --offline --document-private-items
run:
    cargo run
build:
    cargo build

# Future incompatibility report, run regularly
cargo-future:
    cargo check --future-incompat-report
