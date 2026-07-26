# Install NixOS

This procedure erases the selected disk. Keep backups and the LUKS recovery
passphrase somewhere independent of the target.

## Boot the installation environment

Boot an x86_64 NixOS ISO on the desktop. All following commands run
inside that NixOS environment, never on macOS.

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

## Install

Run from a clean checkout:

```sh
sudo ./install.sh --host igor-desktop
```

Use `--dry-run` to exercise validation and exact disk confirmation without
changing the disk:

```sh
sudo ./install.sh --host igor-desktop --dry-run
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
the login password directly to `chpasswd`.

The installer interactively asks twice for the login password and twice for
the separate LUKS recovery passphrase. Input is hidden. It supplies the
confirmed LUKS passphrase to Disko over standard input, never as a
command-line argument or persistent file, and clears it from the shell after
Disko finishes.

The installer has already required the full `ERASE /dev/disk/by-id/...`
confirmation before it invokes Disko's non-interactive wipe mode. That flag
removes only Disko's duplicate `yes` prompt; it does not weaken the installer's
device checks or exact confirmation.

The script immediately says which host it is validating. During installation,
the terminal shows five stage descriptions and one short progress row. That
row is continually replaced with the latest subcommand output, then replaced
by the stage's completion message. Complete output from Nix, Git LFS, Disko,
hardware scanning, and `nixos-install` remains in the log. Installation has
succeeded only if the final `INSTALLATION SUCCEEDED` banner appears. A shell
prompt, closed terminal, or reboot before that banner means the target may
contain partitions but is not safe to boot.

The root-only live-session log remains at
`/tmp/nixos-install-<host>.*/install.log` after a failure. On success it is
also copied to `/var/log/dotfiles-install.log` in the installed system.
Passwords and passphrases are not echoed into the log.

Writing those two host facts deliberately makes the private installation copy
different from its Git commit. Nix may therefore warn that its Git tree is
dirty. This warning refers to the private copy being installed, not to the
clean source checkout that the installer already verified. The original
checkout in the live ISO remains unchanged.

The detailed log can contain Lanzaboote's attempt to predict measured-boot
state while `nixos-install` is still running. At that point the machine is
booted from the live ISO, so messages about unrecognized boot components, an empty
PCR protection mask, or a missing machine ID describe a provisional policy.
They do not mean that installation failed when `install.sh` subsequently
prints its success banner. Never enroll TPM unlocking with this
installation-time policy: the installed system regenerates it after boot, and
[secure-boot.md](secure-boot.md) verifies its actual PCR contents before
enrollment.

The installed system includes `git-lfs` because the copied repository
continues to track the wallpaper through LFS. This is unrelated to the Git
already present on the live ISO.

## Boot the installed system

Only after the installer prints its success banner: shut down, remove the
installation medium, and boot from the installed disk.

Plymouth's BGRT theme appears after the boot menu and asks for the LUKS
passphrase on the graphical display. Typed characters are intentionally not
shown; enter the passphrase and press Return. Press Escape to switch between
the splash and detailed boot messages. BGRT reuses the firmware's boot logo
only when the firmware provides one; a graphical spinner and password prompt
without a vendor logo still means Plymouth is working.

If graphical login fails, see [recovery.md](recovery.md) for how to reach a
terminal and inspect or rebuild the system.

## First boot

Keep Secure Boot disabled. The first boot uses the final host configuration,
but its boot artifacts are initially unsigned because the machine-local keys
did not exist during installation. Lanzaboote creates those keys under
`/var/lib/sbctl` after the system starts.

Review and commit only the generated host data:

```sh
cd ~/dotfiles
git status --short -- hosts/igor-desktop
git diff -- hosts/igor-desktop
git add hosts/igor-desktop
git commit -m "Record igor-desktop hardware"
```

Do not enable Secure Boot or TPM unlock yet.

Continue with [secure-boot.md](secure-boot.md) to verify key generation,
rebuild signed boot artifacts, and enroll them deliberately.
