# igor-desktop NixOS configuration

Single-host NixOS configuration for an encrypted Btrfs workstation:

- Disko-managed GPT, LUKS2, and Btrfs subvolumes
- systemd-boot for the first boot, then Lanzaboote UKIs and Secure Boot
- measured boot with TPM2-backed disk unlock
- Hyprland, Quickshell, greetd, and Home Manager

The production configuration is `.#igor-desktop`. The installer deliberately
uses `.#igor-desktop-bootstrap` so the machine boots with systemd-boot before
Secure Boot keys exist.

## Repository layout

- `hosts/igor-desktop/` — tracked disk identity, Disko layout, and generated
  hardware configuration
- `modules/boot/` — separate bootstrap and production boot policies
- `configuration.nix` — shared system configuration
- `home.nix` and `dotfiles/` — user session and Quickshell configuration
- `install.sh` — destructive local installer

## Normal use

Apply the production configuration:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
```

Validate changes before switching:

```sh
nix flake check --no-update-lock-file
```

Enter the development shell to install the repository hook and obtain the
formatter, static checks, ShellCheck, and gitleaks:

```sh
nix develop
nix fmt
```

## Installation and security

Read these before changing a disk or firmware:

- [Fresh installation](docs/install.md)
- [Secure Boot, measured boot, and TPM2](docs/secure-boot.md)
- [Recovery and known limitations](docs/recovery.md)

The generated `hardware-configuration.nix` and selected disk identifier are
tracked because they describe the host; they are not secrets. Secure Boot
private keys, login passwords, and the LUKS passphrase are never stored in this
repository.
