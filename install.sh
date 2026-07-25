#!/usr/bin/env bash
# Unattended-after-confirmation NixOS install.
#
# Partitions and formats a disk via disko, writes the account password
# secret to the target system, generates the hardware-specific module,
# copies this configuration into place, and installs.
#
# Run from the NixOS live ISO, from the directory containing flake.nix,
# disko-config.nix, configuration.nix, secrets.nix, home.nix.
#
# The LUKS passphrase is requested interactively by cryptsetup during
# partitioning and is never written to a file; see README.md.

set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_ROOT="/mnt"
HOSTNAME="igor-desktop"
USERNAME="igor"

echo "NixOS install: ${HOSTNAME}"
echo

read -rp "Target disk (e.g. /dev/disk/by-id/...): " DISK_DEVICE
if [ ! -b "$DISK_DEVICE" ]; then
  echo "Not a block device: ${DISK_DEVICE}" >&2
  exit 1
fi

read -rsp "Login password for ${USERNAME}: " USER_PASS
echo
read -rsp "Confirm password: " USER_PASS_CONFIRM
echo
if [ "$USER_PASS" != "$USER_PASS_CONFIRM" ]; then
  echo "Passwords did not match, nothing was changed." >&2
  exit 1
fi
USER_HASH="$(mkpasswd -m sha-512 "$USER_PASS")"
unset USER_PASS USER_PASS_CONFIRM

echo
echo "About to erase and partition: ${DISK_DEVICE}"
echo "Hostname: ${HOSTNAME}"
read -rp "Type 'yes' to continue: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted, nothing was changed."
  exit 1
fi

TMP_DISKO="$(mktemp)"
sed "s#/dev/disk/by-id/CHANGE-ME#${DISK_DEVICE}#" "${CONFIG_DIR}/disko-config.nix" > "$TMP_DISKO"
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko "$TMP_DISKO"
rm -f "$TMP_DISKO"

mkdir -p "${TARGET_ROOT}/etc/nixos/secrets"
printf '%s' "$USER_HASH" > "${TARGET_ROOT}/etc/nixos/secrets/igor-password.hash"
chmod 600 "${TARGET_ROOT}/etc/nixos/secrets/igor-password.hash"
unset USER_HASH

nixos-generate-config --no-filesystems --root "$TARGET_ROOT"

cp -r "${CONFIG_DIR}"/flake.nix "${CONFIG_DIR}"/disko-config.nix "${CONFIG_DIR}"/configuration.nix \
   "${CONFIG_DIR}"/secrets.nix "${CONFIG_DIR}"/home.nix "${CONFIG_DIR}"/dotfiles "${TARGET_ROOT}/etc/nixos/"

nixos-install --root "$TARGET_ROOT" --flake "${TARGET_ROOT}/etc/nixos#${HOSTNAME}" --no-root-passwd

echo
echo "Install finished. Reboot, then continue with the post-install steps in README.md."
