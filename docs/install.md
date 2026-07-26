# Install NixOS

This procedure erases the selected physical or virtual disk. Keep backups and
the LUKS recovery passphrase somewhere independent of the target.

## Boot the installation environment

Prepare and boot the installer matching the target:

- For `igor-desktop`, boot an x86_64 NixOS ISO on the physical desktop.
- For `igor-vm`, first [import and prepare the UTM
  template](utm-vm.md), then start it from the attached ARM64/AArch64 NixOS
  ISO.

All following commands run inside that NixOS environment, never on macOS.

## Prepare the exact source

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

The graphical live ISO may leave Nix's flake command-line interfaces disabled.
`install.sh` enables `nix-command` and `flakes` only for itself and its child
processes. You do not need to edit the ISO's Nix configuration.

The installer lists every whole disk available under `/dev/disk/by-id`, along
with its device path, model, serial number, size, transport, type, and mount
status. It then asks for the full identifier to erase.

For `igor-vm`, UTM 4.7.2 or newer automatically gives the VirtIO system disk a
fixed serial. Its entry should resemble `/dev/disk/by-id/virtio-...`. Stop if
that entry is absent: shut down the VM, update UTM if necessary, and confirm
that the non-removable system disk uses the VirtIO interface. Never substitute
the topology-dependent `/dev/vda` name.

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

Writing those two host facts deliberately makes the private installation copy
different from its Git commit. Nix may therefore warn that its Git tree is
dirty. This warning refers to the private copy being installed, not to the
clean source checkout that the installer already verified. The original
checkout in the live ISO remains unchanged.

Lanzaboote also attempts to predict measured-boot state while `nixos-install`
is still running. At that point the VM is booted from the live ISO, so messages
about unrecognized boot components, an empty PCR protection mask, or a missing
machine ID describe a provisional policy. They do not mean that installation
failed when `install.sh` subsequently prints its success message. Never enroll
TPM unlocking with this installation-time policy: the installed system
regenerates it after boot, and [secure-boot.md](secure-boot.md) verifies its
actual PCR contents before enrollment.

The installed system includes `git-lfs` because the copied repository
continues to track the wallpaper through LFS. This is unrelated to the Git
already present on the live ISO.

## Boot the installed system

After the installer finishes:

- On `igor-desktop`, shut down, remove the installation medium, and boot from
  the installed disk.
- On `igor-vm`, shut down the guest, use UTM's removable-drive control to eject
  the NixOS ISO, and start the VM from its VirtIO disk.

Plymouth's BGRT theme appears after the boot menu and asks for the LUKS
passphrase on the graphical display. Typed characters are intentionally not
shown; enter the passphrase and press Return. Press Escape to switch between
the splash and detailed boot messages.

The exact background can differ between the physical desktop and UTM because
BGRT reuses a firmware logo only when that firmware provides one. The
graphical password prompt does not depend on the two machines showing the same
logo.

The UTM template also exposes a built-in terminal connected to `ttyAMA0`,
Linux's name for the VM's first ARM serial port. If graphical login fails,
follow
[Open the recovery terminal](utm-vm.md#open-the-recovery-terminal) and log in
there to inspect or rebuild the system; no boot-menu edit is required.

If the VM fails to reach the graphical desktop, stop it and edit its display:

1. replace `virtio-gpu-gl-pci` with `virtio-ramfb`;
2. disable accelerated rendering; and
3. boot the same `igor-vm` configuration again.

This fallback changes only virtual graphics performance, not the guest's
architecture or NixOS configuration.

## First boot

Keep Secure Boot disabled. The first boot uses the final host configuration,
but its boot artifacts are initially unsigned because the machine-local keys
did not exist during installation. Lanzaboote creates those keys under
`/var/lib/sbctl` after the system starts.

Review and commit only the generated host data:

```sh
cd ~/dotfiles
git status --short -- hosts/igor-vm
git diff -- hosts/igor-vm
git add hosts/igor-vm
git commit -m "Record igor-vm hardware"
```

Replace `igor-vm` with `igor-desktop` for the physical machine. Do not enable
Secure Boot or TPM unlock yet.

For `igor-vm`, shut down after this successful first boot and take a
post-installation UTM snapshot. The snapshot supplements, but does not replace,
the LUKS recovery passphrase.

Continue with [secure-boot.md](secure-boot.md) to verify key generation,
rebuild signed boot artifacts, and enroll them deliberately.
