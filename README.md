# igor-desktop NixOS configuration

Single-OS NixOS install: LUKS2 + Btrfs (via disko), UKI + Secure Boot
(via lanzaboote), TPM2 auto-unlock, zram swap, unfree software allowed,
Hyprland + Quickshell as the desktop shell.

## Layout

- `flake.nix` - inputs, system definition, and a development shell for
  working on this repository (secret scanning).
- `disko-config.nix` - disk layout.
- `configuration.nix` - system configuration.
- `secrets.nix` - references to secret files kept outside the repository.
- `home.nix` - user-level (home-manager) configuration.
- `install.sh` - install script (partition, write secrets, install).
- `lefthook.yml` - pre-commit secret scanning, see "Secrets" below.
- `hardware-configuration.nix` - generated locally, not included here.

## Install

1. Boot the NixOS live ISO. Confirm networking: `ping nixos.org` (run
   `nmtui` first on Wi-Fi).
2. Copy this directory onto the live system, e.g. to `/tmp/nixconfig/`.
3. Identify the target disk: `lsblk`. A `/dev/disk/by-id/...` path is
   preferred over `/dev/sda`, which can shift between boots.
4. Run:
   ```
   cd /tmp/nixconfig
   ./install.sh
   ```
   The script asks for the target disk and a login password, shows a
   summary, and requires typing `yes` before doing anything destructive.
   During partitioning, cryptsetup prompts for a LUKS passphrase
   directly; the script does not handle or store it. That passphrase
   becomes the recovery key once TPM unlock is configured in the next
   section, and should be kept in a password manager.
5. Reboot.

## After the first successful boot (one-time, cannot be declarative)

1. Secure Boot keys, using sbctl:
   ```
   sudo sbctl create-keys
   sudo sbctl enroll-keys      # firmware must be in "Setup Mode" first
   sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
   ```
   The rebuild step is what makes lanzaboote sign a UKI with the new
   keys.
2. TPM2-bind the LUKS volume, matching the PCRs `measuredBoot` uses in
   configuration.nix:
   ```
   sudo systemd-cryptenroll --wipe-slot=tpm2 --tpm2-device=auto \
     --tpm2-pcrs=4+7 /dev/disk/by-id/YOUR-LUKS-PARTITION
   ```
   A firmware or bootloader update that changes PCR 4 or 7 disables TPM
   unlock until re-enrollment; the recovery passphrase from the install
   step is the only way back in until then.
3. Set the login password directly if it needs to change: `passwd`

## Secrets

- **Login password**: not embedded in any committed file. `install.sh`
  hashes it and writes it to `/etc/nixos/secrets/igor-password.hash`,
  outside version control; `secrets.nix` only holds a path reference to
  that file.
- **LUKS passphrase**: never written to a file, handled by cryptsetup's
  own interactive prompt during install. With TPM2 covering day-to-day
  unlock, this passphrase functions as a recovery key rather than
  something needed for routine automation.
- **Pre-commit scanning**: `lefthook.yml` runs gitleaks against staged
  changes before each commit, as a second layer beyond `.gitignore`.
  Available via `nix develop`, which also installs the hook. Worth
  knowing: gitleaks' original author has since started a
  Betterleaks project as its actively developed successor, with
  gitleaks itself now in a feature-complete/maintenance state;
  the two use compatible configuration and CLI flags, so switching
  later is a small change if Betterleaks packaging becomes convenient.

Committing a password hash is not equivalent to plaintext, but a
weak-to-medium password can still be cracked offline by anyone able to
read the repository. A committed LUKS passphrase or key file is a
different category of risk entirely: full plaintext access to the disk
for anyone who reads the repository and also obtains the drive. Neither
is stored here.

For secrets management beyond "keep them out of the repository and
scan for accidents," the standard approach in the NixOS ecosystem is
**sops-nix** or **agenix**: both allow an *encrypted* blob to be
committed and decrypted only on the target machine, using a key that
never leaves that machine (typically its SSH host key). Worth adopting
once more than a couple of secrets are involved.

## Locale

English UI (`en_US.UTF-8`) with German formatting (`de_DE.UTF-8`) for
the rest, via `i18n.extraLocaleSettings`. glibc/CLDR does not ship a
combined English-language/German-format locale as a single name, which
is why this relies on per-category `LC_*` overrides rather than one
locale string. `en_DK.UTF-8` is a commonly used substitute for the
affected categories if a given application handles the mixed locale
poorly.

## Wi-Fi

NetworkManager is enabled with its default backend (wpa_supplicant).

`networking.networkmanager.wifi.backend = "iwd";` is present but
commented out in configuration.nix. Setting NetworkManager to use iwd
as its Wi-Fi backend is a supported, documented configuration, distinct
from running iwd as a second, competing network manager (which is the
scenario that actually causes conflicts). Current caveats to weigh
before enabling it:
- NixOS's own wiki describes the iwd backend as experimental and not at
  feature parity with wpa_supplicant.
- MAC address randomization is silently disabled under this backend
  unless configured separately through iwd itself.
- An open nixpkgs issue (filed against 25.11/unstable) reports
  intermittent connection drops specifically with this combination.

The default backend is left in place here; the commented line documents
how to switch.

No Wi-Fi password is stored in this configuration. NetworkManager
persists connection profiles under
`/etc/NetworkManager/system-connections/`, outside the Nix store, once
a network is joined interactively (`nmcli` or `nmtui`).

## Secret Service (KeePassXC)

`home.nix` enables KeePassXC with Secret Service integration
(`FdoSecrets.Enabled = true`) and autostart, following the
configuration documented on the NixOS wiki's Secret Service page.
Autostart matters here: KeePassXC's Secret Service integration only
responds while the application is already running; it is not
D-Bus-activated the way gnome-keyring is by default.

Once active, applications that request secrets through the standard
`org.freedesktop.secrets` interface - including NetworkManager, when a
connection is joined with an agent-owned secret rather than a
profile-embedded one - are served by KeePassXC rather than a separate
keyring. This is confirmed to work with `nm-applet`; it has not been
separately verified against a Quickshell-only setup with no D-Bus
secret agent running.

For a vault file synced across Windows, macOS, and iOS without relying
on a US-based cloud provider, a self-hosted Nextcloud instance syncing
the `.kdbx` file is a reasonable option: the Nextcloud desktop client on
Windows/macOS, and a Nextcloud-capable KeePass client on iOS (Strongbox
or KeePassium, both support WebDAV/Nextcloud directly).

One caveat worth noting before combining "synced vault" with "Secret
Service provider" on the same database: some entries a Secret Service
integration creates are effectively machine- or session-specific.
Syncing a database that mixes those with general-purpose passwords can
create conflicts between devices. A second, local-only database for
Secret Service use avoids this if it becomes an issue.

## Dotfiles

`home.nix` declares dotfiles as links to files kept in this repository,
e.g.:
```
home.file.".config/hypr/hyprland.conf".source = ./dotfiles/hypr/hyprland.conf;
```
This is one of at least three approaches used in NixOS configurations
generally - see "Design notes" below.

Currently tracked this way: `dotfiles/hypr/hyprland.conf` (the normal
session) and `dotfiles/quickshell/{bar,lockscreen}` (see "Desktop"
below). The greeter's copy of the Quickshell config is published via
`environment.etc` in `configuration.nix` instead, since it runs as a
separate system user with no home-manager-managed home directory.

## Desktop: Hyprland + Quickshell

`programs.hyprland.enable = true;` is set, and `quickshell` and
`matugen` are installed system-wide. `qt.enable` and
`programs.dconf.enable` are set so Qt and GTK applications pick up a
consistent theme outside a full desktop environment.

**Session start.** `services.greetd` provides the graphical login: on
boot it launches a throwaway Hyprland instance
(`dotfiles/hypr/greeter.conf`) running only a Quickshell login UI
(`dotfiles/quickshell/greeter/shell.qml`), which authenticates over
greetd's own IPC protocol (`Quickshell.Services.Greetd`) rather than
PAM directly - this is the standard division of responsibility for
greetd greeters. On success it hands off to the user's normal Hyprland
session, which starts Quickshell via `exec-once` in
`dotfiles/hypr/hyprland.conf`.

**Bar and wallpaper.** `dotfiles/quickshell/bar/shell.qml` is the
default Quickshell config: one full-screen background layer-shell
surface per monitor for the wallpaper, and one top-anchored bar
showing the current date and time. No wallpaper image is committed;
the `Image` source is a placeholder path (`~/Pictures/wallpaper.jpg`)
that needs to point at a real file. There is no separate wallpaper
daemon (no swww/awww/hyprpaper) - Quickshell draws the wallpaper
itself, since its layer-shell support makes that a background surface
like any other.

**Lock screen.** `SUPER+L` runs `quickshell -c lockscreen`
(`dotfiles/quickshell/lockscreen/`), which locks the session via the
`ext-session-lock-v1` protocol (`WlSessionLock`) and authenticates
against PAM directly (`Quickshell.Services.Pam`) - independent of
greetd, which is only involved at initial login. This is deliberately
minimal: no idle-timeout auto-lock (e.g. via `hypridle`) and no
`loginctl lock-session` integration, so things like suspend or
lid-close won't trigger it yet.

Not included yet: a terminal or app-launcher keybind (no terminal
emulator is installed, so `hyprland.conf` currently has no way to open
one), and the matugen templates that translate a wallpaper's palette
into GTK, Qt, and Quickshell theme files. matugen supports templates
for both toolkits directly, the same mechanism DankMaterialShell
itself is built on, without requiring the rest of that shell.

**A caution on the greeter and lock screen:** both are new,
hand-written against Quickshell's greetd/PAM APIs, and have not yet
been exercised on real hardware. Keep a way to reach a plain TTY (e.g.
Ctrl+Alt+F2) before relying on either as the only way into the
machine - a broken greeter config can otherwise lock out graphical
login entirely.

## Design notes

**Home-manager.** Kept, rather than dropped in favor of hand-wrapping
packages. Reasoning: among widely used, actively maintained NixOS
configurations (see "Prior art"), it is the majority approach among the
largest and longest-running examples, used for both system-level and
cross-platform (Linux/macOS) home configuration. Where it is dropped,
that appears tied to a broader preference for avoiding abstraction
layers in general (also dropping flake-parts, impermanence, and similar
tools in the same configuration) rather than a specific, demonstrated
technical shortcoming. A plain-file dotfile tree, copied into place
manually rather than declared, is also a real and simpler alternative,
at the cost of losing build-time reproducibility for that part of the
system.

**Secure Boot: lanzaboote over Limine's native option.** Limine's own
Secure Boot support does not currently build a Unified Kernel Image,
which is what makes TPM PCR binding meaningful beyond the base secure
boot policy state; lanzaboote does, and is the more established of the
two options for this combination today.

**Partitioning: disko over manual partitioning.** Chosen for the same
reason the rest of this configuration is declarative: the disk layout
is version-controlled and reproducible rather than a one-time manual
step that has to be redone from memory.

## Prior art

Structure and specific choices in this repository were informed by
looking at several other public NixOS configurations, in particular:

- [gvolpe/nix-config](https://github.com/gvolpe/nix-config)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)
- [sioodmy/dotfiles](https://github.com/sioodmy/dotfiles)
- [XNM1/linux-nixos-hyprland-config-dotfiles](https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles)

None of these are dependencies of this configuration; they are cited
for reference.
