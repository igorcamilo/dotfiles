# How this repository works

This document assumes no prior Nix or NixOS knowledge. Read it from top to
bottom once; afterward, use the file guide and change recipes as a reference.

## The one-sentence mental model

NixOS builds a complete operating system by merging small configuration files
called modules. This repository selects a machine, merges its host-specific
facts with shared modules, and produces one bootable system.

The main data flow is:

```text
flake.lock fixes dependency versions
                 │
                 ▼
flake.nix selects a host and a boot mode
                 │
        ┌────────┴────────┐
        ▼                 ▼
shared configuration   hosts/<name>
desktop, user, disk    hardware, disk ID,
and security policy    hostname, VM support
        └────────┬────────┘
                 ▼
      one NixOS configuration
                 ▼
       bootable system closure
```

A “closure” is the complete set of files required by a built system. Building a
closure proves that every referenced package and configuration can be produced;
it does not install or boot the result.

## Vocabulary

| Term | Meaning in this repository |
| --- | --- |
| Nix | The package manager and configuration language |
| NixOS | Linux whose operating-system configuration is built by Nix |
| Flake | The repository entry point, its dependencies, and its named outputs |
| Input | An external dependency such as Nixpkgs, Disko, or Home Manager |
| `flake.lock` | Exact revisions of every input |
| Module | A Nix file that declares part of the desired system |
| Host | One machine with a hostname and architecture |
| Nixpkgs | The package collection and NixOS module library |
| Disko | The module and tool that partitions, encrypts, and mounts disks |
| Home Manager | The module that configures Igor's user session |
| systemd-boot | The ordinary bootloader used for the first boot |
| Lanzaboote | The Secure Boot integration used after keys exist |
| UEFI | The firmware interface that starts the bootloader |
| TPM | Hardware or virtual hardware that can unlock LUKS after trusted boot |

## How to read the Nix files

Most files in this repository are NixOS modules with this shape:

```nix
{ pkgs, ... }:

{
  programs.example.enable = true;
  environment.systemPackages = [ pkgs.example ];
}
```

The first `{ ... }:` receives values supplied by NixOS. The second attribute
set declares the desired settings. Useful syntax:

| Syntax | Meaning |
| --- | --- |
| `name = value;` | Assign an option; every assignment ends with `;` |
| `[ a b ]` | A list |
| `{ a = 1; }` | An attribute set, similar to a dictionary |
| `./file.nix` | A path relative to the current file |
| `imports = [ ... ];` | Merge other modules into this one |
| `${value}` | Insert a Nix value into a string |
| `# comment` | An explanation ignored by Nix |
| `lib.mkDefault` | Provide a value that a more specific module may override |
| `lib.mkForce` | Deliberately override another module's value |

Dots in an option name describe nesting. For example,
`networking.networkmanager.enable = true` enables the `enable` option inside
the `networkmanager` section inside `networking`.

Multiple modules may set different parts of the same section. NixOS merges
those declarations and reports conflicts rather than silently choosing based
on file order.

## Why there are four outputs

There are two machines and two boot modes:

```text
igor-desktop ───────────── production, x86_64
igor-desktop-bootstrap ─── first boot, x86_64
igor-vm ────────────────── production, ARM64
igor-vm-bootstrap ──────── first boot, ARM64
```

The hostname does not contain the architecture because it names one specific
machine. Architecture is machine metadata in `flake.nix`.

The bootstrap/production split is a safety sequence:

1. install and boot with ordinary systemd-boot;
2. create Secure Boot keys;
3. build the production configuration and verify its signatures;
4. enroll the keys in firmware;
5. verify Secure Boot;
6. enroll TPM-assisted disk unlock.

This prevents a new machine from depending on keys that do not exist yet.
Both boot modes retain eight generations so an older configuration remains
selectable. Production signs with keys under `/var/lib/sbctl` and measures PCRs
4 and 7 for the TPM policy.

## How a host is assembled

`flake.nix` is the entry point. For the chosen host it combines:

1. Disko's NixOS module;
2. Home Manager's NixOS module;
3. `configuration.nix`, the shared operating-system and desktop settings;
4. `home.nix`, Igor's shared user-session settings;
5. `hosts/<name>/default.nix`, the machine-specific facts; and
6. one boot module: bootstrap or production.

The host registry records only two facts:

| Host | System | Host module |
| --- | --- | --- |
| `igor-desktop` | `x86_64-linux` | `hosts/igor-desktop/default.nix` |
| `igor-vm` | `aarch64-linux` | `hosts/igor-vm/default.nix` |

Assertions stop evaluation if a host module sets the wrong hostname or CPU
architecture.

## Shared and host-specific configuration

Shared configuration belongs at the repository root or under `modules/`:

- `configuration.nix` configures networking, locale, the user account,
  Hyprland, greetd, Quickshell, and Nix itself.
- `home.nix` configures files and services owned by Igor rather than by the
  whole operating system.
- `modules/storage/luks-btrfs.nix` describes the disk layout.
- `modules/boot/` contains the two boot policies.

Only facts about one machine belong under `hosts/<name>/`:

- hostname;
- target architecture;
- stable installation-disk identifier;
- generated kernel and hardware information; and
- VM guest support for `igor-vm`.

This boundary answers the usual placement question: if both computers should
receive a change, it is shared; if only one computer should receive it, it is
host-specific.

The shared system settings are:

| Setting | What it does |
| --- | --- |
| NetworkManager | Manages wired and wireless networking |
| Europe/Berlin timezone | Sets the system clock presentation |
| English/German locale mix | Uses English text and German regional formats |
| Unfree packages | Allows packages whose licenses Nixpkgs marks unfree |
| User `igor` | Creates the user in `wheel` and `networkmanager` groups |
| zram swap | Uses compressed RAM as swap before relying on disk |
| Hyprland, Qt, and dconf | Provides the Wayland desktop foundations |
| greetd and Quickshell | Provides the graphical login flow |
| Nix flakes | Enables the command and flake interfaces used here |
| `stateVersion` | Keeps compatibility defaults stable across upgrades |

Home Manager owns:

| Setting | What it does |
| --- | --- |
| Hyprland and Quickshell files | Installs the user's desktop files |
| Quickshell lock service | Gives every lock request one idempotent service |
| KeePassXC | Starts automatically and provides the Secret Service API |
| Ghostty | Provides the configured terminal |
| hypridle | Locks after 5 minutes and blanks displays 30 seconds later |

The VM adds only hardware graphics, the QEMU guest agent, and the SPICE agent.
Everything else is shared with the desktop.

## Storage and hardware

Each host tracks two machine facts:

- `disk-device` is the stable `/dev/disk/by-id/...` path used only when Disko
  partitions that machine.
- `hardware-configuration.nix` is generated by
  `nixos-generate-config --no-filesystems`.

The `--no-filesystems` rule is important. Disko is the only owner of
partitions, filesystems, and mount points, so generated hardware data cannot
silently disagree with the declared layout.

The shared layout is:

| Layer | Result |
| --- | --- |
| GPT partition table | One EFI partition and one encrypted partition |
| EFI partition | 1 GiB FAT filesystem mounted at `/boot` |
| LUKS2 partition | Encrypted container named `cryptroot` |
| Btrfs | Separate `/`, `/home`, and `/nix` subvolumes |

The EFI filesystem uses `umask=0077` so ordinary users cannot read its files.
Btrfs uses Zstandard compression and `noatime` to reduce space and metadata
writes. LUKS permits discards so SSD and sparse-VM storage can reclaim unused
blocks; the tradeoff is that the storage layer may reveal which encrypted
blocks are unused.

The two placeholder hardware files make a fresh checkout evaluable. The
installer replaces only the selected host's placeholder with the real scan.

## What the installer does

`install.sh` is intentionally more defensive than the rest of the repository
because it destroys a disk. Its work is divided by the confirmation boundary.

Before confirmation it:

1. requires root and UEFI;
2. checks that `/mnt` is unused;
3. requires a clean Git checkout and committed lock file;
4. evaluates both configurations for the selected host;
5. rejects a live ISO with the wrong CPU architecture;
6. accepts only a whole-disk `/dev/disk/by-id/...` path;
7. rejects mounted or active disks; and
8. shows the disk model, size, filesystems, and mounts.

The user must type the complete stable disk identifier as part of the
confirmation. Nothing destructive runs before that succeeds.

After confirmation it:

1. copies the exact checked-out commit to a temporary directory;
2. writes the selected disk identifier into that copy;
3. asks the locked Disko tool to partition, encrypt, and mount the disk;
4. moves the copied repository into the target user's home;
5. generates hardware data without filesystems;
6. installs the bootstrap configuration;
7. sends the login password to `chpasswd` over standard input; and
8. clears temporary password variables and files.

The password, its hash, and the LUKS passphrase are never written to Git.

## Desktop and login flow

The graphical path is:

```text
boot
 └─ greetd
     └─ temporary Hyprland greeter session
         └─ Quickshell login UI
             └─ normal Hyprland user session
                 ├─ Quickshell bar and wallpaper
                 ├─ Ghostty terminal
                 ├─ KeePassXC Secret Service
                 └─ hypridle → Quickshell lock service
```

System-owned greeter files are installed by `configuration.nix` under
`/etc/greetd`. User-owned session files are installed by Home Manager from
`home.nix`.

The lock screen is a systemd user service. Starting an already-running service
is safe, so keyboard, idle, and suspend events can all request a lock without a
process-detection race.

## Validation and CI

There is one GitHub Actions workflow:

- an x86 runner evaluates and builds both `igor-desktop` configurations;
- an ARM runner evaluates and builds both `igor-vm` configurations;
- the x86 runner also runs `scripts/check.sh`; and
- a separate job scans the entire Git history for secrets.

`scripts/check.sh` runs every repository-level check even if an earlier one
fails. It covers Nix formatting, dead-code analysis, Nix static analysis,
ShellCheck, Bash syntax, installer tests, current-tree secret scanning, and QML
linting.

`nix flake check --keep-going` also keeps independent system builds running
after a failed check. Together, these rules produce one complete failure report
instead of revealing errors one push at a time.

CI cannot test firmware menus, Secure Boot enrollment, TPM behavior, GPU
initialization, or recovery passphrases. Those require the acceptance steps in
the installation and security guides.

## Secrets and generated state

Tracked:

- `flake.lock`;
- `hosts/*/disk-device`;
- `hosts/*/hardware-configuration.nix`.

Never tracked:

- login passwords or hashes;
- LUKS passphrases;
- Secure Boot private keys under `/var/lib/sbctl`;
- TPM enrollment state;
- files under `secrets/`.

Run `lefthook install` once after entering `nix develop` to enable a local
pre-commit Gitleaks scan. CI also scans the current tree and full Git history.

## File guide

| Path | Responsibility |
| --- | --- |
| `flake.nix` | Dependencies, four system outputs, tools, and checks |
| `flake.lock` | Exact dependency revisions |
| `configuration.nix` | Shared machine-wide settings |
| `home.nix` | Shared settings owned by Igor |
| `hosts/` | Per-machine facts |
| `modules/storage/` | Shared encrypted disk layout |
| `modules/boot/` | Bootstrap and production boot policies |
| `modules/virtualisation/` | UTM guest additions |
| `dotfiles/hypr/` | Hyprland startup and key bindings |
| `dotfiles/quickshell/bar/` | User bar and wallpaper |
| `dotfiles/quickshell/greeter/` | Login screen |
| `dotfiles/quickshell/lockscreen/` | Lock screen |
| `dotfiles/quickshell/shared/` | Reused login and lock components |
| `install.sh` | Destructive installation workflow |
| `tests/` | Non-destructive installer unit tests |
| `scripts/check.sh` | Readable repository-level validation |
| `.github/workflows/ci.yml` | Native x86, ARM, and history validation |
| `lefthook.yml` | Local pre-commit secret protection |
| `.gitignore` | Excludes secrets, keys, and local Nix build links |
| `docs/` | Procedures and this explanation |

## Common change recipes

Add a system-wide package:

1. edit `environment.systemPackages` in `configuration.nix`;
2. run `nix flake check --no-update-lock-file --keep-going`;
3. rebuild the intended host.

Add a user program or dotfile:

1. edit `home.nix`;
2. add its source under `dotfiles/` if necessary;
3. validate and rebuild.

Change only the VM:

1. edit `hosts/igor-vm/default.nix` or
   `modules/virtualisation/utm.nix`;
2. build `igor-vm` and `igor-vm-bootstrap`.

Update dependencies:

1. run `nix flake update` inside NixOS;
2. review `flake.lock`;
3. run the full flake check;
4. commit `flake.lock` with the input change.

Change the disk layout:

1. edit `modules/storage/luks-btrfs.nix`;
2. understand that the change affects both hosts;
3. test in a disposable VM before touching the desktop.

## Design rules

- Prefer shared modules until a real host difference exists.
- Keep host facts next to that host.
- Keep one owner for each concern: Disko owns filesystems, hardware scans own
  detected hardware, and boot modules own boot policy.
- Preserve the bootstrap-before-Secure-Boot sequence.
- Keep destructive validation explicit even when it costs more lines.
- Do not add fleet tooling for two personal machines.
- Do not install Nix on macOS; use the NixOS VM as the development environment.

Upstream references:

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Lanzaboote](https://nix-community.github.io/lanzaboote/)
