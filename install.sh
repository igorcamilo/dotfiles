#!/usr/bin/env bash
# Destructive local installer for a host declared by this flake.
#
# Run this script as root from a clean, reviewed Git checkout on the NixOS
# installer. It installs the exact checked-out commit, not a moving remote
# branch. Passwords are read interactively and never passed as command-line
# arguments.

set -euo pipefail

# Do not let an inherited or command-line xtrace setting expose passwords.
set +x

TARGET_ROOT="/mnt"
USERNAME="igor"
REPO_DEST="${TARGET_ROOT}/home/${USERNAME}/dotfiles"
TARGET_HOST=""
HOST_RELATIVE_PATH=""
EXPECTED_SYSTEM=""

INSTALL_TMP_ROOT=""
INSTALL_LOG=""
USER_PASS=""
USER_PASS_CONFIRM=""
LUKS_PASS=""
LUKS_PASS_CONFIRM=""

enable_required_nix_features() {
  local required_setting="extra-experimental-features = nix-command flakes"

  # Live ISOs include Nix but may not enable the flake command-line interface.
  # Keep the override local to this installer and the commands it starts.
  if [[ -n ${NIX_CONFIG:-} ]]; then
    NIX_CONFIG="${NIX_CONFIG}"$'\n'"${required_setting}"
  else
    NIX_CONFIG="$required_setting"
  fi
  export NIX_CONFIG
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

cleanup() {
  unset USER_PASS USER_PASS_CONFIRM LUKS_PASS LUKS_PASS_CONFIRM

  if [[ -n "${INSTALL_TMP_ROOT:-}" && "$INSTALL_TMP_ROOT" == /tmp/nixos-install.* ]]; then
    rm -rf -- "$INSTALL_TMP_ROOT"
  fi
}

finish() {
  local status=$1

  cleanup

  if ((status != 0)); then
    echo >&2
    echo "INSTALLATION FAILED (exit ${status})." >&2
    echo "Do not boot from the target disk; it may be only partly formatted." >&2
    if [[ -n "${INSTALL_LOG:-}" ]]; then
      echo "The live-session log is still available at ${INSTALL_LOG}." >&2
    fi
  fi
}

start_install_log() {
  local log_directory

  log_directory=$(mktemp -d "/tmp/nixos-install-${TARGET_HOST}.XXXXXX")
  INSTALL_LOG="${log_directory}/install.log"
  (
    umask 077
    printf 'Detailed installer output for %s\n' "$TARGET_HOST" > "$INSTALL_LOG"
  )
}

run_logged() {
  "$@" >> "$INSTALL_LOG" 2>&1
}

partition_and_mount_disk() {
  local staged_repo=$1
  local target_host=$2

  # The caller has already required the exact stable disk identifier.
  printf '%s\n%s\n' "$LUKS_PASS" "$LUKS_PASS" \
    | nix run "${staged_repo}#disko" -- \
      --mode destroy,format,mount \
      --yes-wipe-all-disks \
      --flake "${staged_repo}#${target_host}" \
      >> "$INSTALL_LOG" 2>&1
}

validate_host_name() {
  local host_name=$1

  [[ "$host_name" =~ ^[a-z0-9][a-z0-9-]*$ ]] \
    || fail "host names may contain only lowercase letters, numbers, and hyphens"
}

validate_disk_path() {
  local disk_device=$1

  [[ "$disk_device" =~ ^/dev/disk/by-id/[A-Za-z0-9._:+-]+$ ]] \
    || fail "use a whole-disk /dev/disk/by-id/... path containing no whitespace"
}

validate_passwords() {
  local description=$1
  local password=$2
  local confirmation=$3

  [[ -n "$password" ]] || fail "the ${description} cannot be empty"
  [[ "$password" == "$confirmation" ]] || fail "${description} entries did not match"
}

write_disk_device() {
  local disk_device=$1
  local destination=$2

  validate_disk_path "$disk_device"
  printf '%s\n' "$disk_device" > "$destination"
}

machine_to_nix_system() {
  case "$1" in
    x86_64)
      printf '%s\n' "x86_64-linux"
      ;;
    aarch64 | arm64)
      printf '%s\n' "aarch64-linux"
      ;;
    *)
      fail "unsupported installer architecture: $1"
      ;;
  esac
}

system_to_efi_architecture() {
  case "$1" in
    x86_64-linux)
      printf '%s\n' "x64"
      ;;
    aarch64-linux)
      printf '%s\n' "aa64"
      ;;
    *)
      fail "unsupported EFI architecture for Nix system: $1"
      ;;
  esac
}

system_to_efi_fallback_filename() {
  case "$1" in
    x86_64-linux)
      printf '%s\n' "BOOTX64.EFI"
      ;;
    aarch64-linux)
      printf '%s\n' "BOOTAA64.EFI"
      ;;
    *)
      fail "unsupported EFI fallback filename for Nix system: $1"
      ;;
  esac
}

validate_host_architecture() {
  local expected_system=$1
  local installer_system=$2

  [[ "$expected_system" == "$installer_system" ]] \
    || fail "host requires ${expected_system}, but this installer is ${installer_system}"
}

target_mounts_are_ready() {
  local target_root=$1
  local mount_path

  for mount_path in \
    "$target_root" \
    "${target_root}/boot" \
    "${target_root}/home" \
    "${target_root}/nix"; do
    mountpoint -q "$mount_path" || return 1
  done
}

installed_system_is_bootable() {
  local target_root=$1
  local expected_system=$2
  local efi_architecture
  local efi_fallback_filename

  efi_architecture=$(system_to_efi_architecture "$expected_system")
  efi_fallback_filename=$(system_to_efi_fallback_filename "$expected_system")

  [[ -L "${target_root}/nix/var/nix/profiles/system" ]] \
    && [[ -s "${target_root}/boot/EFI/BOOT/${efi_fallback_filename}" ]] \
    && [[ -s "${target_root}/boot/EFI/systemd/systemd-boot${efi_architecture}.efi" ]] \
    && [[ -d "${target_root}/boot/EFI/Linux" ]] \
    && find "${target_root}/boot/EFI/Linux" \
      -maxdepth 1 \
      -type f \
      -name '*.efi' \
      -print -quit \
      | grep -q .
}

hardware_config_is_valid() {
  local hardware_file=$1
  local expected_system=$2

  [[ -s "$hardware_file" ]] \
    && grep -q 'boot\.initrd\.availableKernelModules' "$hardware_file" \
    && grep -Eq "nixpkgs\\.hostPlatform.*\"${expected_system}\"" "$hardware_file" \
    && ! grep -q 'fileSystems\.' "$hardware_file"
}

require_commands() {
  local command_name

  for command_name in \
    find findmnt git grep install lsblk mktemp mountpoint nix nixos-enter \
    nixos-generate-config nixos-install readlink sync uname; do
    command -v "$command_name" >/dev/null \
      || fail "required command is missing: ${command_name}"
  done
}

validate_flake_host() {
  local source_root=$1
  local target_host=$2
  local expected_system

  validate_host_name "$target_host"
  [[ -d "${source_root}/hosts/${target_host}" ]] \
    || fail "host directory does not exist: hosts/${target_host}"
  [[ -f "${source_root}/flake.lock" ]] \
    || fail "flake.lock is required; generate and commit it from a NixOS environment"

  expected_system=$(nix eval \
    --no-update-lock-file \
    --raw \
    "${source_root}#nixosConfigurations.${target_host}.config.nixpkgs.hostPlatform.system") \
    || fail "could not evaluate host: ${target_host}"

  nix eval \
    --no-update-lock-file \
    --raw \
    "${source_root}#nixosConfigurations.${target_host}.config.system.build.toplevel.drvPath" \
    >/dev/null \
    || fail "configuration does not evaluate: ${target_host}"

  printf '%s\n' "$expected_system"
}

validate_environment() {
  [[ ${EUID} -eq 0 ]] || fail "run this installer as root (sudo ./install.sh)"
  [[ -d /sys/firmware/efi ]] || fail "the installer was not booted in UEFI mode"

  require_commands

  if mountpoint -q "$TARGET_ROOT"; then
    fail "${TARGET_ROOT} is already a mount point; unmount the previous target first"
  fi

  if [[ -d "$TARGET_ROOT" ]] && find "$TARGET_ROOT" -mindepth 1 -maxdepth 1 -print -quit | grep -q .; then
    fail "${TARGET_ROOT} is not empty"
  fi
}

list_disks_by_id() {
  local by_id_directory=${1:-/dev/disk/by-id}
  local canonical_device
  local device_type
  local disk_found=false
  local id_path
  local status

  [[ -d "$by_id_directory" ]] \
    || fail "disk identifier directory does not exist: ${by_id_directory}"

  echo "Whole disks available by stable identifier:"

  for id_path in "$by_id_directory"/*; do
    [[ -L "$id_path" ]] || continue

    canonical_device=$(readlink -f -- "$id_path" 2>/dev/null) || continue
    device_type=$(lsblk -dnro TYPE "$canonical_device" 2>/dev/null) || continue
    [[ "$device_type" == "disk" ]] || continue

    disk_found=true

    if lsblk -nrpo MOUNTPOINTS "$canonical_device" | grep -q '[^[:space:]]'; then
      status="mounted or active (cannot be selected)"
    else
      status="not mounted"
    fi

    echo
    echo "Identifier: ${id_path}"
    lsblk -d -o PATH,MODEL,SERIAL,SIZE,TRAN,TYPE "$canonical_device"
    echo "Status: ${status}"
  done

  [[ "$disk_found" == "true" ]] \
    || fail "no whole disks found under ${by_id_directory}"
}

resolve_and_validate_disk() {
  local requested_device=$1
  local canonical_device
  local device_type

  validate_disk_path "$requested_device"
  [[ -b "$requested_device" ]] || fail "not a block device: ${requested_device}"

  canonical_device=$(readlink -f -- "$requested_device")
  [[ -b "$canonical_device" ]] || fail "could not resolve block device: ${requested_device}"

  device_type=$(lsblk -ndo TYPE "$canonical_device")
  [[ "$device_type" == "disk" ]] || fail "target must be a whole disk, not a partition"

  if lsblk -nrpo MOUNTPOINTS "$canonical_device" | grep -q '[^[:space:]]'; then
    fail "the target disk or one of its children is mounted or active"
  fi

  printf '%s\n' "$canonical_device"
}

hydrate_lfs_checkout() {
  local checkout=$1

  echo "Downloading Git LFS files for the installation checkout."

  (
    cd "$checkout"

    nix shell \
      --no-update-lock-file \
      --inputs-from . \
      nixpkgs#git-lfs \
      --command git-lfs install --local

    nix shell \
      --no-update-lock-file \
      --inputs-from . \
      nixpkgs#git-lfs \
      --command git-lfs pull
  ) || fail "could not download the repository's Git LFS files"
}

prepare_exact_checkout() {
  local source_root=$1
  local staged_repo=$2
  local source_remote

  GIT_LFS_SKIP_SMUDGE=1 \
    git clone --quiet --no-hardlinks "$source_root" "$staged_repo"

  source_remote=$(git -C "$source_root" config --get remote.origin.url || true)
  if [[ -n "$source_remote" ]]; then
    git -C "$staged_repo" remote set-url origin "$source_remote"
  fi

  hydrate_lfs_checkout "$staged_repo"
}

run_install() {
  local dry_run=$1
  local source_root
  local source_commit
  local installer_system
  local requested_device
  local canonical_device
  local confirmation
  local staged_repo
  local generated_hardware_dir
  local generated_hardware

  validate_environment
  start_install_log

  source_root=$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel 2>/dev/null) \
    || fail "run install.sh from a Git checkout"

  [[ -z "$(git -C "$source_root" status --porcelain --untracked-files=all)" ]] \
    || fail "the source checkout is dirty; review and commit or stash it before installing"

  source_commit=$(git -C "$source_root" rev-parse HEAD)
  if ! EXPECTED_SYSTEM=$(validate_flake_host \
    "$source_root" \
    "$TARGET_HOST" \
    2>> "$INSTALL_LOG"); then
    fail "could not validate ${TARGET_HOST}; see ${INSTALL_LOG}"
  fi
  installer_system=$(machine_to_nix_system "$(uname -m)")
  validate_host_architecture "$EXPECTED_SYSTEM" "$installer_system"

  echo "NixOS install: ${TARGET_HOST}"
  echo "Target platform: ${EXPECTED_SYSTEM}"
  echo "Source commit: ${source_commit}"
  echo
  list_disks_by_id
  echo

  read -r -p "Enter the full identifier of the disk to erase: " requested_device
  canonical_device=$(resolve_and_validate_disk "$requested_device")

  echo
  echo "Selected disk:"
  lsblk -o NAME,PATH,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS "$canonical_device"
  echo
  echo "All data on ${requested_device} (${canonical_device}) will be erased."
  read -r -p "Type 'ERASE ${requested_device}' to continue: " confirmation
  [[ "$confirmation" == "ERASE ${requested_device}" ]] || fail "confirmation did not match"

  if [[ "$dry_run" == "true" ]]; then
    echo "Dry run complete: validation passed; no changes were made."
    echo "Detailed log: ${INSTALL_LOG}"
    return
  fi

  read -r -s -p "Login password for ${USERNAME}: " USER_PASS
  echo
  read -r -s -p "Confirm login password: " USER_PASS_CONFIRM
  echo
  validate_passwords "login password" "$USER_PASS" "$USER_PASS_CONFIRM"
  unset USER_PASS_CONFIRM

  read -r -s -p "LUKS recovery passphrase: " LUKS_PASS
  echo
  read -r -s -p "Confirm LUKS recovery passphrase: " LUKS_PASS_CONFIRM
  echo
  validate_passwords \
    "LUKS recovery passphrase" \
    "$LUKS_PASS" \
    "$LUKS_PASS_CONFIRM"
  unset LUKS_PASS_CONFIRM

  INSTALL_TMP_ROOT=$(mktemp -d /tmp/nixos-install.XXXXXX)
  staged_repo="${INSTALL_TMP_ROOT}/dotfiles"
  generated_hardware_dir="${INSTALL_TMP_ROOT}/hardware"
  echo
  echo "STEP 1/5: Prepare the exact checkout and Git LFS files."
  run_logged prepare_exact_checkout "$source_root" "$staged_repo"
  mkdir -p "$generated_hardware_dir"
  echo "STEP 1/5 complete."

  write_disk_device "$requested_device" "${staged_repo}/${HOST_RELATIVE_PATH}/disk-device"

  echo
  echo "STEP 2/5: Partition, encrypt, and mount the target disk."
  if ! partition_and_mount_disk "$staged_repo" "$TARGET_HOST"; then
    fail "Disko failed while partitioning, encrypting, or mounting the target"
  fi
  unset LUKS_PASS
  target_mounts_are_ready "$TARGET_ROOT" \
    || fail "Disko returned without mounting /mnt, /mnt/boot, /mnt/home, and /mnt/nix"
  echo "STEP 2/5 complete: the encrypted filesystems are mounted."

  [[ ! -e "$REPO_DEST" ]] || fail "target repository already exists: ${REPO_DEST}"
  mkdir -p "$(dirname "$REPO_DEST")"
  mv "$staged_repo" "$REPO_DEST"

  echo
  echo "STEP 3/5: Scan the machine hardware."
  run_logged nixos-generate-config \
    --no-filesystems \
    --root "$TARGET_ROOT" \
    --dir "$generated_hardware_dir" \
    || fail "nixos-generate-config failed"

  generated_hardware="${generated_hardware_dir}/hardware-configuration.nix"
  hardware_config_is_valid "$generated_hardware" "$EXPECTED_SYSTEM" \
    || fail "generated hardware configuration has filesystems or the wrong platform/initrd settings"
  install -m 0644 "$generated_hardware" \
    "${REPO_DEST}/${HOST_RELATIVE_PATH}/hardware-configuration.nix"
  echo "STEP 3/5 complete: the hardware scan is valid."

  mkdir -p "${TARGET_ROOT}/etc"
  [[ ! -e "${TARGET_ROOT}/etc/nixos" && ! -L "${TARGET_ROOT}/etc/nixos" ]] \
    || fail "${TARGET_ROOT}/etc/nixos already exists"
  ln -s "/home/${USERNAME}/dotfiles" "${TARGET_ROOT}/etc/nixos"

  echo
  echo "STEP 4/5: Build and install NixOS and its EFI bootloader."
  echo "This is normally the longest step."
  run_logged nixos-install \
    --root "$TARGET_ROOT" \
    --flake "${REPO_DEST}#${TARGET_HOST}" \
    --no-root-passwd \
    || fail "nixos-install failed; the target is not bootable"

  installed_system_is_bootable "$TARGET_ROOT" "$EXPECTED_SYSTEM" \
    || fail "nixos-install returned without a system profile, fallback bootloader, or NixOS boot image"
  echo "STEP 4/5 complete: the system and fallback EFI bootloader are present."

  echo
  echo "STEP 5/5: Set the login password and finalize the installation."
  printf '%s:%s\n' "$USERNAME" "$USER_PASS" \
    | nixos-enter --root "$TARGET_ROOT" -c 'chpasswd' \
      >> "$INSTALL_LOG" 2>&1 \
    || fail "could not set the login password"
  unset USER_PASS

  run_logged nixos-enter --root "$TARGET_ROOT" \
    -c "chown -R ${USERNAME}:users /home/${USERNAME}/dotfiles" \
    || fail "could not assign the installed checkout to ${USERNAME}"

  mkdir -p "${TARGET_ROOT}/var/log"
  install -m 0600 "$INSTALL_LOG" \
    "${TARGET_ROOT}/var/log/dotfiles-install.log"
  sync
  echo "STEP 5/5 complete: files have been flushed to the target disk."

  echo
  echo "============================================================"
  echo "INSTALLATION SUCCEEDED: ${TARGET_HOST} is ready to boot."
  echo "============================================================"
  echo "The live ISO checkout remains unchanged. After reboot, ~/dotfiles is the"
  echo "installed checkout and contains the generated host data."
  echo "After reboot, review and commit the generated host data:"
  echo "  git -C ~/dotfiles diff -- hosts/${TARGET_HOST}"
  echo "  git -C ~/dotfiles add hosts/${TARGET_HOST}"
  echo "  git -C ~/dotfiles commit -m 'Record ${TARGET_HOST} hardware'"
  echo
  echo "Secure Boot is not ready yet. The first boot generates signing keys."
  echo "Keep Secure Boot disabled and then follow docs/secure-boot.md."
  echo
  echo "Detailed log before reboot: ${TARGET_ROOT}/var/log/dotfiles-install.log"
  echo "Detailed log after reboot: /var/log/dotfiles-install.log"
}

main() {
  local dry_run=false

  enable_required_nix_features

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        [[ $# -ge 2 ]] || fail "--host requires a value"
        [[ -z "$TARGET_HOST" ]] || fail "--host may be specified only once"
        TARGET_HOST=$2
        shift 2
        ;;
      --dry-run)
        dry_run=true
        shift
        ;;
      *)
        fail "usage: sudo ./install.sh --host HOST [--dry-run]"
        ;;
    esac
  done

  [[ -n "$TARGET_HOST" ]] || fail "usage: sudo ./install.sh --host HOST [--dry-run]"
  validate_host_name "$TARGET_HOST"
  HOST_RELATIVE_PATH="hosts/${TARGET_HOST}"

  trap 'finish "$?"' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  run_install "$dry_run"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
