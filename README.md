# Igor's NixOS configuration

This repository is an executable description of `igor-desktop`, Igor's
`x86_64-linux` desktop.

Plymouth provides the BGRT boot splash and graphical disk-unlock prompt. The
`hosts/igor-desktop/` directory holds the facts specific to that machine.

If Nix and NixOS are new to you, start with
[How this repository works](docs/architecture.md). It defines the terminology,
shows how the files combine, and explains the reason for each major design
choice.

Human and automated contributors should also read `AGENTS.md`. It keeps Nix
files limited to readable computer descriptions and keeps development and CI
machinery outside them.

The same configuration handles initial installation and normal operation.
Lanzaboote allows the first boot while signing keys do not yet exist, then
generates them on the installed machine. Secure Boot remains disabled until
the signed boot files have been verified and the keys are deliberately
enrolled in firmware.

## Common tasks

Run Nix commands inside NixOS, not on the macOS host.

Rebuild the installed machine:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
```

Check repository files such as Nix, shell, and QML:

```sh
scripts/check-repository.sh
```

Evaluate and build the machine:

```sh
scripts/check-system.sh igor-desktop x86_64-linux
```

The scripts fetch their tools from the `nixpkgs` revision already recorded in
`flake.lock`; no test or development environment is embedded in the machine
configuration.

Update locked dependencies from a NixOS environment:

```sh
nix flake update
scripts/check-repository.sh
scripts/check-system.sh igor-desktop x86_64-linux
git diff -- flake.lock
```

`flake.lock` must be reviewed and committed with any dependency update.

## Installation and recovery

Installation erases the selected disk. Read the relevant guide before running
the installer:

- [Install NixOS](docs/install.md)
- [Secure Boot and TPM setup](docs/secure-boot.md)
- [Recovery and known limitations](docs/recovery.md)

No Nix installation or partition integration is required on macOS. All
installation, dependency updates, formatting, and validation happen inside a
NixOS live system or the installed machine.

Generated `hardware-configuration.nix` and the stable disk identifier are
tracked because they describe the machine. Passwords, LUKS passphrases, Secure
Boot private keys, and TPM state are never stored here.
