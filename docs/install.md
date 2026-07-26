# Fresh installation

This procedure erases the selected physical or virtual disk. Keep backups and
the LUKS recovery passphrase somewhere independent of the target.

## Prepare the exact source

Boot the NixOS installer matching the target:

- `x86_64-linux` for `igor-desktop`
- ARM64/AArch64 for `igor-vm`

Clone and review the configuration:

```sh
git clone https://github.com/igorcamilo/dotfiles.git
cd dotfiles
git log -1 --oneline
git status --short
```

The ISO's Git is sufficient for cloning and running the installer; do not
install another copy. The wallpaper is stored with Git LFS, which is a separate
tool. The installer obtains the locked `git-lfs` package temporarily, downloads
the image into its private installation checkout, and stops before changing the
disk if that download fails. No manual Git LFS setup is required on the ISO.

The installer requires the tracked `flake.lock` and never updates it. If a
checkout does not contain that file, restore it from Git before continuing.
Dependency updates are a maintenance task performed inside NixOS with
`nix flake update`; they are never part of installation. Do not install Nix on
macOS for this procedure.

The installer lists every whole disk available under `/dev/disk/by-id`, along
with its device path, model, serial number, size, transport, type, and mount
status. It then asks for the full identifier to erase. UTM users should fix the
virtual disk serial in UTM before proceeding so that identifier remains stable.

## Install

Run from a clean checkout, selecting exactly one host:

```sh
sudo ./install.sh --host igor-desktop
sudo ./install.sh --host igor-vm
```

Use `--dry-run` to exercise validation and exact disk confirmation without
changing the disk:

```sh
sudo ./install.sh --host igor-vm --dry-run
```

Before destructive confirmation, the installer:

1. verifies root, UEFI mode, an empty `/mnt`, and required commands;
2. requires `flake.lock` and a clean Git checkout;
3. evaluates the selected host configuration without updating the lock;
4. rejects a live installer whose architecture differs from the host;
5. lists the stable identifiers and details for every whole disk;
6. asks for one complete `/dev/disk/by-id/...` path; and
7. accepts it only when it resolves to an unused whole disk.

After exact confirmation, it creates a private copy of the exact checked-out
commit, hydrates its LFS files, and only then starts Disko. It writes the
selected host's disk identity and hardware scan, installs `<host>`, and sends
the login password directly to `chpasswd`. Disko/cryptsetup separately requests
the LUKS recovery passphrase.

The installed system includes `git-lfs` because the copied repository
continues to track the wallpaper through LFS. This is unrelated to the Git
already present on the live ISO.

## First boot

Keep Secure Boot disabled. The first boot uses the final host configuration,
but its boot artifacts are initially unsigned because the machine-local keys
did not exist during installation. Lanzaboote creates those keys under
`/var/lib/sbctl` after the system starts.

Review and commit only the generated host data:

```sh
cd ~/dotfiles
git diff -- hosts/igor-vm
git add hosts/igor-vm
git commit -m "Record igor-vm hardware"
```

Replace `igor-vm` with `igor-desktop` for the physical machine. Do not enable
Secure Boot or TPM unlock yet. Continue with
[secure-boot.md](secure-boot.md) to verify key generation, rebuild signed boot
artifacts, and enroll them deliberately.
