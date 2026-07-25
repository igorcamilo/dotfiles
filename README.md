# Igor's NixOS configurations

Two encrypted NixOS workstation hosts share one desktop and user configuration:

| Host | Platform | Environment |
| --- | --- | --- |
| `igor-desktop` | `x86_64-linux` | Physical desktop |
| `igor-vm` | `aarch64-linux` | UTM/QEMU on Apple Silicon |

Each host has a bootstrap profile using systemd-boot and a production profile
using Lanzaboote, measured boot, and TPM2:

- `.#igor-desktop` and `.#igor-desktop-bootstrap`
- `.#igor-vm` and `.#igor-vm-bootstrap`

The hostname identifies a machine, not its CPU architecture. Architecture is
declared and checked in the flake's host registry.

## Repository layout

- `hosts/<host>/` — hostname, disk identity, and generated hardware scan
- `modules/storage/` — shared GPT, LUKS2, and Btrfs Disko layout
- `modules/boot/` — bootstrap and production boot policies
- `modules/virtualisation/` — UTM/QEMU guest integration
- `configuration.nix` — shared workstation configuration
- `home.nix` and `dotfiles/` — shared user session
- `install.sh` — destructive, host-explicit installer

## Normal use

Rebuild the current host by selecting it explicitly:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
sudo nixos-rebuild switch --flake /etc/nixos#igor-vm
```

Validate locked inputs without modifying `flake.lock`:

```sh
nix flake check --no-update-lock-file
```

The formatter, development shell, and Disko app are exposed for both
`x86_64-linux` and `aarch64-linux`. CI builds each host natively.

## Installation and security

Read the relevant procedures before changing a virtual or physical disk:

- [Fresh installation](docs/install.md)
- [UTM VM on Apple Silicon](docs/utm-vm.md)
- [Secure Boot, measured boot, and TPM2](docs/secure-boot.md)
- [Recovery and known limitations](docs/recovery.md)

No Nix installation is needed on macOS. For the VM workflow, all Nix commands
run inside the NixOS ARM live environment or installed guest.

Generated `hardware-configuration.nix` files and disk identifiers are tracked
because they describe their hosts. Secure Boot private keys, login passwords,
LUKS passphrases, and TPM state are never stored in this repository.
