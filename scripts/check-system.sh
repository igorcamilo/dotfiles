#!/usr/bin/env bash

# Evaluate and build one host on its native CPU architecture.

set -euo pipefail

host=${1:?Usage: check-system.sh HOST NIX_SYSTEM}
expected_system=${2:?Usage: check-system.sh HOST NIX_SYSTEM}
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
configuration=".#nixosConfigurations.${host}.config"

cd "$repo_root"

case "$host" in
  igor-desktop | igor-vm) ;;
  *)
    printf 'Unknown host: %s\n' "$host" >&2
    exit 1
    ;;
esac

case "$expected_system" in
  x86_64-linux | aarch64-linux) ;;
  *)
    printf 'Unsupported Nix system: %s\n' "$expected_system" >&2
    exit 1
    ;;
esac

actual_host=$(nix eval --no-update-lock-file --raw \
  "${configuration}.networking.hostName")
actual_system=$(nix eval --no-update-lock-file --raw \
  "${configuration}.nixpkgs.hostPlatform.system")

if [[ $actual_host != "$host" ]]; then
  printf 'Expected hostname %s, but configuration declares %s.\n' \
    "$host" "$actual_host" >&2
  exit 1
fi

if [[ $actual_system != "$expected_system" ]]; then
  printf 'Expected %s to use %s, but it declares %s.\n' \
    "$host" "$expected_system" "$actual_system" >&2
  exit 1
fi

nix build \
  --no-update-lock-file \
  --no-link \
  --print-build-logs \
  ".#nixosConfigurations.${host}.config.system.build.toplevel"
