# Igor's NixOS configuration

This repository is an executable description of two computers:

| Host | CPU architecture | Machine |
| --- | --- | --- |
| `igor-desktop` | `x86_64-linux` | Physical desktop |
| `igor-vm` | `aarch64-linux` | UTM virtual machine on Apple Silicon |

Both machines use the same desktop, user account, encrypted disk layout, and
security policy. A host directory contains only the facts that differ between
the two machines.

If Nix and NixOS are new to you, start with
[How this repository works](docs/architecture.md). It defines the terminology,
shows how the files combine, and explains the reason for each major design
choice.

## The two configurations

| Configuration | Purpose |
| --- | --- |
| `igor-desktop` | Install and operate the physical desktop |
| `igor-vm` | Install and operate the ARM virtual machine |

The same configuration handles initial installation and normal operation.
Lanzaboote allows the first boot while signing keys do not yet exist, then
generates them on the installed machine. Secure Boot remains disabled until
the signed boot files have been verified and the keys are deliberately
enrolled in firmware.

## Common tasks

Run Nix commands inside NixOS, not on the macOS host.

Rebuild an installed machine:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
sudo nixos-rebuild switch --flake /etc/nixos#igor-vm
```

Check repository files such as Nix, shell, and QML:

```sh
scripts/check-repository.sh
```

Evaluate and build the machine matching the current CPU:

```sh
scripts/check-system.sh igor-desktop x86_64-linux
scripts/check-system.sh igor-vm aarch64-linux
```

Run only the matching command. The scripts fetch their tools from the
`nixpkgs` revision already recorded in `flake.lock`; no test or development
environment is embedded in the machine configuration.

Update locked dependencies from the NixOS VM:

```sh
nix flake update
scripts/check-repository.sh
scripts/check-system.sh igor-vm aarch64-linux
git diff -- flake.lock
```

Replace the final command with the desktop variant when working on the
desktop. CI builds the other architecture. `flake.lock` must be reviewed and
committed with any dependency update.

## Installation and recovery

Installation erases the selected disk. Read the relevant guide before running
the installer:

- [Fresh installation](docs/install.md)
- [UTM VM setup](docs/utm-vm.md)
- [Secure Boot and TPM setup](docs/secure-boot.md)
- [Recovery and known limitations](docs/recovery.md)

No Nix installation or partition integration is required on macOS. All VM
installation, dependency updates, formatting, and validation happen inside the
ARM NixOS live system or installed guest.

Generated `hardware-configuration.nix` files and stable disk identifiers are
tracked because they describe a machine. Passwords, LUKS passphrases, Secure
Boot private keys, and TPM state are never stored here.
