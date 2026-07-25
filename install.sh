#!/usr/bin/env bash
# Unattended-after-confirmation NixOS install.
#
# Partitions and formats a disk via disko, clones this repository
# directly to the target's /home/igor/dotfiles (the canonical,
# committed state - not whatever local copy is running this script),
# points /etc/nixos at it via symlink, writes the account password
# secret, generates the hardware-specific module, and installs.
#
# This script itself is the only thing that needs to be present
# locally to run it; everything else comes from REPO_URL below.
#
# The LUKS passphrase is requested interactively by cryptsetup during
# partitioning and is never written to a file; see README.md.

set -euo pipefail

TARGET_ROOT="/mnt"
HOSTNAME="igor-desktop"
USERNAME="igor"
REPO_URL="https://github.com/igorcamilo/dotfiles.git"
REPO_DEST="${TARGET_ROOT}/home/${USERNAME}/dotfiles"

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

# Cloned to a temporary directory first: disko-config.nix has to come
# from somewhere before disko has formatted and mounted the target
# disk, so the final destination under /mnt doesn't exist yet.
TMP_CLONE="$(mktemp -d)"
nix --experimental-features "nix-command flakes" run nixpkgs#git -- \
  clone "$REPO_URL" "$TMP_CLONE"

TMP_DISKO="$(mktemp)"
sed "s#/dev/disk/by-id/CHANGE-ME#${DISK_DEVICE}#" "${TMP_CLONE}/disko-config.nix" > "$TMP_DISKO"
nix --experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode disko "$TMP_DISKO"
rm -f "$TMP_DISKO"

mkdir -p "$(dirname "$REPO_DEST")"
mv "$TMP_CLONE" "$REPO_DEST"

mkdir -p "${REPO_DEST}/secrets"
printf '%s' "$USER_HASH" > "${REPO_DEST}/secrets/igor-password.hash"
chmod 600 "${REPO_DEST}/secrets/igor-password.hash"
unset USER_HASH

nixos-generate-config --no-filesystems --root "$TARGET_ROOT"
mv "${TARGET_ROOT}/etc/nixos/hardware-configuration.nix" "${REPO_DEST}/hardware-configuration.nix"
rm -rf "${TARGET_ROOT}/etc/nixos"
ln -s "/home/${USERNAME}/dotfiles" "${TARGET_ROOT}/etc/nixos"

# hardware-configuration.nix and secrets/ are gitignored on purpose
# (see README's "Secrets"), but this is now a real git working tree,
# and Nix only sees files tracked in git's index when evaluating a
# flake out of one. --intent-to-add stages their *path* (so the flake
# can find them) without staging their *content* for a future commit.
git -C "$REPO_DEST" add --intent-to-add --force \
  hardware-configuration.nix secrets/igor-password.hash

nixos-install --root "$TARGET_ROOT" --flake "${REPO_DEST}#${HOSTNAME}" --no-root-passwd

nixos-enter --root "$TARGET_ROOT" -c "chown -R ${USERNAME}:users /home/${USERNAME}/dotfiles"

echo
echo "Install finished. Reboot, then continue with the post-install steps in README.md."
