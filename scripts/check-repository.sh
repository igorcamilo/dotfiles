#!/usr/bin/env bash

# Run architecture-neutral repository checks with tools from locked Nixpkgs.

set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

if ! command -v nix >/dev/null; then
  printf 'Nix is required. Run this script inside NixOS.\n' >&2
  exit 1
fi

exec nix shell \
  --no-update-lock-file \
  --inputs-from "$repo_root" \
  nixpkgs#bash \
  nixpkgs#coreutils \
  nixpkgs#deadnix \
  nixpkgs#diffutils \
  nixpkgs#findutils \
  nixpkgs#gitleaks \
  nixpkgs#gnugrep \
  nixpkgs#nixfmt \
  nixpkgs#qt6.qtdeclarative \
  nixpkgs#quickshell \
  nixpkgs#shellcheck \
  nixpkgs#statix \
  --command bash scripts/check.sh
