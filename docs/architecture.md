# How this repository works

This document assumes no prior Nix or NixOS knowledge. Read it from top to
bottom once; afterward, use the file guide and change recipes as a reference.

## The one-sentence mental model

NixOS builds a complete operating system by merging small configuration files
called modules. This repository selects a machine, merges its host-specific
facts with shared modules, and produces one bootable system.

The main data flow is:

```mermaid
flowchart TD
    lock["flake.lock<br/>fixes dependency versions"] --> flake["flake.nix<br/>selects a host"]
    flake --> shared["shared configuration<br/>desktop, user, disk,<br/>and security policy"]
    flake --> host["hosts/&lt;name&gt;<br/>hardware, disk ID,<br/>hostname, VM support"]
    shared --> merged["one NixOS configuration"]
    host --> merged
    merged --> closure["bootable system closure"]
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
| systemd-boot | The UEFI boot menu installed and managed through Lanzaboote |
| Lanzaboote | Builds, signs, and installs the machine's boot artifacts |
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

## Why there are only two outputs

There is exactly one configuration for each machine:

| Host | Machine |
| --- | --- |
| `igor-desktop` | Physical desktop, x86_64 |
| `igor-vm` | UTM virtual machine, ARM64 |

The hostname does not contain the architecture because it names one specific
machine. Architecture is machine metadata in `flake.nix`.

The configuration does not change identity during Secure Boot setup. Instead,
Lanzaboote handles the temporary first-boot state:

1. install the final host configuration while Secure Boot is disabled;
2. boot unsigned artifacts once and generate machine-local signing keys;
3. rebuild the same configuration and verify its signatures;
4. enroll the keys in firmware;
5. verify Secure Boot;
6. enroll TPM-assisted disk unlock.

`autoGenerateKeys` makes Lanzaboote permit unsigned artifacts while its key
bundle is absent, then creates the bundle under `/var/lib/sbctl` after the
first boot. Automatic firmware enrollment stays disabled: the user must verify
the signed artifacts before changing firmware trust. The configuration retains
eight generations and measures PCRs 4 and 7 for the TPM policy.

## How a host is assembled

`flake.nix` is the entry point. For the chosen host it combines:

1. Disko's NixOS module;
2. Home Manager's NixOS module;
3. Lanzaboote's NixOS module;
4. `configuration.nix`, the shared operating-system and desktop settings;
5. `home.nix`, Igor's shared user-session settings;
6. `modules/boot/secure-boot.nix`, the shared boot policy; and
7. `hosts/<name>/default.nix`, the machine-specific facts.

The two `mkHost` calls record only the architecture and host module:

| Host | System | Host module |
| --- | --- | --- |
| `igor-desktop` | `x86_64-linux` | `hosts/igor-desktop/default.nix` |
| `igor-vm` | `aarch64-linux` | `hosts/igor-vm/default.nix` |

CI evaluates those values and rejects a host whose declared hostname or CPU
architecture does not match its matrix entry.

## Shared and host-specific configuration

Shared configuration belongs at the repository root or under `modules/`:

- `configuration.nix` configures networking, locale, the user account,
  Hyprland, greetd, Quickshell, and Nix itself.
- `home.nix` configures files and services owned by Igor rather than by the
  whole operating system.
- `modules/storage/luks-btrfs.nix` describes the disk layout.
- `modules/boot/secure-boot.nix` contains the one shared boot policy.

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
| Tracked wallpaper | Provides one background for the desktop, login, and lock screen |
| Git LFS | Keeps the installed wallpaper checkout usable |
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

The graphical ISO includes Nix but may leave its flake interfaces disabled.
The installer enables `nix-command` and `flakes` through its own process
environment, which also covers the Nix commands it starts without editing the
live system's configuration.

Before confirmation it:

1. requires root and UEFI;
2. checks that `/mnt` is unused;
3. requires a clean Git checkout and committed lock file;
4. evaluates the selected host configuration;
5. rejects a live ISO with the wrong CPU architecture;
6. lists every whole-disk `/dev/disk/by-id/...` path with identifying details;
7. asks which complete identifier to erase; and
8. rejects mounted, active, or non-disk selections.

The user must type the complete stable disk identifier as part of the
confirmation. Nothing destructive runs before that succeeds.

After confirmation it:

1. copies the exact checked-out commit to a temporary directory;
2. obtains Git LFS from the locked Nixpkgs input and downloads tracked assets;
3. writes the selected disk identifier into that copy;
4. asks the locked Disko tool to partition, encrypt, and mount the disk;
5. moves the copied repository into the target user's home;
6. generates hardware data without filesystems;
7. installs the selected host configuration;
8. sends the login password to `chpasswd` over standard input; and
9. clears temporary password variables and files.

The password, its hash, and the LUKS passphrase are never written to Git.

## Desktop and login flow

The graphical path is:

```mermaid
flowchart TD
    boot["boot"] --> greetd["greetd"]
    greetd --> greeter["temporary Hyprland greeter session"]
    greeter --> loginui["Quickshell login UI"]
    loginui --> session["normal Hyprland user session"]
    session --> bar["Quickshell bar and wallpaper"]
    session --> terminal["Ghostty terminal"]
    session --> keepassxc["KeePassXC Secret Service"]
    session --> hypridle["hypridle"] --> lock["Quickshell lock service"]
```

System-owned greeter files are installed by `configuration.nix` under
`/etc/greetd`. User-owned session files are installed by Home Manager from
`home.nix`.

The lock screen is a systemd user service. Starting an already-running service
is safe, so keyboard, idle, and suspend events can all request a lock without a
process-detection race.

## Validation and CI

`flake.nix` contains no test derivations, lint package lists, formatter, or
development shell. It describes the two machines and exposes the Disko command
used by the installer. Validation lives under `scripts/`, where it can be read
as an ordinary sequence of commands and cannot change the resulting computer.

The two architecture jobs are the same matrix job. Each calls
`scripts/check-system.sh` with a hostname and its expected Nix system. The
script performs the same work on native x86 and ARM runners:

1. evaluate the hostname and architecture;
2. build the complete system closure.

Architecture-neutral work runs once in a separate `repository-quality` job.
`scripts/check-repository.sh` obtains its tools from the locked `nixpkgs` input
and then runs `scripts/check.sh`. That script checks Nix formatting and static
analysis, shell syntax and ShellCheck, installer tests, the current tree for
secrets, and QML with `qmllint`. It continues through independent checks so one
failure does not hide the others.

Here, `nix shell` only makes those tools available for one command. It does not
install them permanently or add them to either computer's configuration.

QML is checked statically with `qmllint`. CI deliberately does not launch the
complete Quickshell configurations: their `PanelWindow` and session-lock types
need a real Wayland compositor and its protocols, while an offscreen Qt process
has no window-system backend. Starting a nested compositor merely to make that
test pass would add infrastructure without reproducing the real login or lock
environment. The native system builds already prove that each architecture can
produce the configured Quickshell package; actual bar, greeter, and lock-screen
behavior remains a VM or hardware acceptance test.

Another separate job scans the complete Git history for secrets.

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
- TPM enrollment state.

`lefthook.yml` can provide an optional local pre-commit Gitleaks scan when
`lefthook` and `gitleaks` are available. CI always scans both the current tree
and full Git history.

## File guide

| Path | Responsibility |
| --- | --- |
| `AGENTS.md` | Tool-neutral navigation and agent design rules |
| `flake.nix` | Dependencies, two system outputs, and the installer's Disko app |
| `flake.lock` | Exact dependency revisions |
| `configuration.nix` | Shared machine-wide settings |
| `home.nix` | Shared settings owned by Igor |
| `hosts/` | Per-machine facts |
| `modules/storage/` | Shared encrypted disk layout |
| `modules/boot/` | Shared Secure Boot and measured-boot policy |
| `modules/virtualisation/` | UTM guest additions |
| `templates/igor-vm.utm/` | Importable blank UTM 4.7.5 virtual machine |
| `dotfiles/hypr/` | Hyprland startup and key bindings |
| `dotfiles/quickshell/bar/` | User bar and wallpaper |
| `dotfiles/quickshell/greeter/` | Login screen |
| `dotfiles/quickshell/lockscreen/` | Lock screen |
| `dotfiles/quickshell/shared/` | Reused login and lock components |
| `wallpapers/` | Images installed by the shared system configuration |
| `install.sh` | Destructive installation workflow |
| `tests/` | Non-destructive installer unit tests |
| `scripts/check.sh` | Readable repository-level validation |
| `scripts/check-repository.sh` | Runs repository checks with locked tools |
| `scripts/check-system.sh` | Identical native validation for either host |
| `.github/workflows/ci.yml` | Native systems, repository quality, and history |
| `lefthook.yml` | Local pre-commit secret protection |
| `.gitignore` | Excludes local key files and Nix build links |
| `docs/` | Procedures and this explanation |

## Common change recipes

Add a system-wide package:

1. edit `environment.systemPackages` in `configuration.nix`;
2. run `scripts/check-repository.sh`;
3. run the matching `scripts/check-system.sh` command;
4. rebuild the intended host.

Add a user program or dotfile:

1. edit `home.nix`;
2. add its source under `dotfiles/` if necessary;
3. validate and rebuild.

Change only the VM:

1. edit `hosts/igor-vm/default.nix` or
   `modules/virtualisation/utm.nix`;
2. build `igor-vm`.

Update dependencies:

1. run `nix flake update` inside NixOS;
2. review `flake.lock`;
3. run the repository and matching system check scripts;
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
- Keep Secure Boot enrollment manual and verify signatures before changing
  firmware trust.
- Keep destructive validation explicit even when it costs more lines.
- Do not add fleet tooling for two personal machines.
- Do not install Nix on macOS; use the NixOS VM as the development environment.

Upstream references:

- [NixOS manual](https://nixos.org/manual/nixos/stable/)
- [Disko](https://github.com/nix-community/disko)
- [Home Manager](https://nix-community.github.io/home-manager/)
- [Lanzaboote](https://nix-community.github.io/lanzaboote/)
