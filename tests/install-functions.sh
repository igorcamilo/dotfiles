#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=SCRIPTDIR/../install.sh
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

test_temp_dir=$(mktemp -d /tmp/nixos-install-tests.XXXXXX)
trap 'rm -rf -- "$test_temp_dir"' EXIT

assert_succeeds validate_host_name "igor-desktop"
assert_succeeds validate_host_name "igor-vm"
assert_fails validate_host_name "../igor-vm"
assert_fails validate_host_name "IGOR-VM"

assert_succeeds validate_disk_path "/dev/disk/by-id/nvme-example_123"
assert_fails validate_disk_path "/dev/nvme0n1"
assert_fails validate_disk_path "/dev/disk/by-id/device with spaces"
assert_fails validate_disk_path "/dev/disk/by-id/../../sda"

assert_succeeds validate_passwords "correct horse battery staple" "correct horse battery staple"
assert_fails validate_passwords "" ""
assert_fails validate_passwords "one" "two"

[[ $(machine_to_nix_system x86_64) == "x86_64-linux" ]]
[[ $(machine_to_nix_system aarch64) == "aarch64-linux" ]]
[[ $(machine_to_nix_system arm64) == "aarch64-linux" ]]
assert_fails machine_to_nix_system riscv64
assert_succeeds validate_host_architecture "aarch64-linux" "aarch64-linux"
assert_fails validate_host_architecture "aarch64-linux" "x86_64-linux"

mkdir -p "${test_temp_dir}/hosts/igor-desktop" "${test_temp_dir}/hosts/igor-vm"
write_disk_device \
  "/dev/disk/by-id/wwn-desktop" \
  "${test_temp_dir}/hosts/igor-desktop/disk-device"
write_disk_device \
  "/dev/disk/by-id/wwn-vm" \
  "${test_temp_dir}/hosts/igor-vm/disk-device"
[[ $(<"${test_temp_dir}/hosts/igor-desktop/disk-device") == "/dev/disk/by-id/wwn-desktop" ]]
[[ $(<"${test_temp_dir}/hosts/igor-vm/disk-device") == "/dev/disk/by-id/wwn-vm" ]]
assert_fails validate_flake_host "$test_temp_dir" "igor-vm"
assert_fails validate_flake_host "$test_temp_dir" "unknown-host"

mock_bin="${test_temp_dir}/bin"
mkdir -p "$mock_bin"
[[ ${BASH:-} == /* && -x ${BASH:-} ]] \
  || fail "tests require an absolute, executable Bash interpreter path"
{
  printf '#!%s\n' "$BASH"
  cat <<'EOF'
set -euo pipefail

flake_ref=${*: -1}
case "$flake_ref" in
  *nixosConfigurations.igor-vm.config.nixpkgs.hostPlatform.system)
    printf '%s' "aarch64-linux"
    ;;
  *nixosConfigurations.igor-vm.config.system.build.toplevel.drvPath)
    printf '%s' "/nix/store/igor-vm.drv"
    ;;
  *)
    exit 1
    ;;
esac
EOF
} > "${mock_bin}/nix"
chmod +x "${mock_bin}/nix"
printf '%s\n' '{ "nodes": {}, "root": "root", "version": 7 }' > "${test_temp_dir}/flake.lock"

with_mock_nix() {
  PATH="${mock_bin}:${PATH}" "$@"
}

assert_succeeds with_mock_nix validate_flake_host "$test_temp_dir" "igor-vm"
mkdir -p "${test_temp_dir}/hosts/unknown-output"
assert_fails with_mock_nix validate_flake_host "$test_temp_dir" "unknown-output"

printf '%s\n' \
  '{ lib, ... }: {' \
  '  boot.initrd.availableKernelModules = [ "nvme" ];' \
  '  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";' \
  '}' > "${test_temp_dir}/hardware-good.nix"
printf '%s\n' \
  '{ lib, ... }: {' \
  '  boot.initrd.availableKernelModules = [ "virtio_pci" ];' \
  '  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";' \
  '}' > "${test_temp_dir}/hardware-arm-good.nix"
printf '%s\n' \
  '{ lib, ... }: {' \
  '  boot.initrd.availableKernelModules = [ "virtio_pci" ];' \
  '  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";' \
  '  fileSystems."/" = { device = "/dev/vda"; };' \
  '}' > "${test_temp_dir}/hardware-filesystems.nix"
printf '%s\n' '{ }' > "${test_temp_dir}/hardware-bad.nix"

assert_succeeds hardware_config_is_valid \
  "${test_temp_dir}/hardware-good.nix" \
  "x86_64-linux"
assert_succeeds hardware_config_is_valid \
  "${test_temp_dir}/hardware-arm-good.nix" \
  "aarch64-linux"
assert_fails hardware_config_is_valid \
  "${test_temp_dir}/hardware-good.nix" \
  "aarch64-linux"
assert_fails hardware_config_is_valid \
  "${test_temp_dir}/hardware-filesystems.nix" \
  "aarch64-linux"
assert_fails hardware_config_is_valid \
  "${test_temp_dir}/hardware-bad.nix" \
  "x86_64-linux"

echo "Installer function tests passed."
