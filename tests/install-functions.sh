#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=../install.sh
source "$(dirname "${BASH_SOURCE[0]}")/../install.sh"

assert_fails() {
  if ("$@" >/dev/null 2>&1); then
    echo "Expected failure: $*" >&2
    exit 1
  fi
}

assert_succeeds() {
  "$@" >/dev/null
}

test_temp_dir=$(mktemp -d /tmp/igor-desktop-install-tests.XXXXXX)
trap 'rm -rf -- "$test_temp_dir"' EXIT

assert_succeeds validate_disk_path "/dev/disk/by-id/nvme-example_123"
assert_fails validate_disk_path "/dev/nvme0n1"
assert_fails validate_disk_path "/dev/disk/by-id/device with spaces"
assert_fails validate_disk_path "/dev/disk/by-id/../../sda"

assert_succeeds validate_passwords "correct horse battery staple" "correct horse battery staple"
assert_fails validate_passwords "" ""
assert_fails validate_passwords "one" "two"

write_disk_device "/dev/disk/by-id/wwn-0x1234" "${test_temp_dir}/disk-device"
[[ $(<"${test_temp_dir}/disk-device") == "/dev/disk/by-id/wwn-0x1234" ]]

printf '%s\n' \
  '{ lib, ... }: {' \
  '  boot.initrd.availableKernelModules = [ "nvme" ];' \
  '  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";' \
  '}' > "${test_temp_dir}/hardware-good.nix"
printf '%s\n' '{ }' > "${test_temp_dir}/hardware-bad.nix"

assert_succeeds hardware_config_is_valid "${test_temp_dir}/hardware-good.nix"
assert_fails hardware_config_is_valid "${test_temp_dir}/hardware-bad.nix"

echo "Installer function tests passed."
