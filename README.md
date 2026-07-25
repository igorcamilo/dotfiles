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
- `install.sh` - install script (partition, clone this repository to
  the target, write secrets, install).
- `lefthook.yml` - pre-commit secret scanning, see "Secrets" below.
- `hardware-configuration.nix` - generated locally, not included here.
  See "Tracking changes after install" for how a relative,
  gitignored import still resolves once this directory is a real git
  working tree.

## Install

1. Boot the NixOS live ISO. Confirm networking: `ping nixos.org` (run
   `nmtui` first on Wi-Fi).
2. Get `install.sh` onto the live system - it's the only file that
   needs to be there locally; it clones the rest of this repository
   fresh from GitHub itself. Copying the whole repository (e.g. to
   `/tmp/nixconfig/`) also works and is simplest if that's already how
   it got there (USB drive, `scp`, etc.).
3. Identify the target disk: `lsblk`. A `/dev/disk/by-id/...` path is
   preferred over `/dev/sda`, which can shift between boots.
4. Run `install.sh` (adjust the path to wherever step 2 put it):
   ```
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

## Tracking changes after install

`install.sh` clones this repository directly to
`/home/igor/dotfiles` on the target disk and points `/etc/nixos` at it
via a symlink - there's no separate migration step, and no plain
one-time copy to outgrow. From the first boot onward:

- Edit inside `~/dotfiles`, commit, and `git push` as normal.
- Apply changes with
  `sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop` (or
  `--flake ~/dotfiles#igor-desktop` - identical, since one is a
  symlink to the other).
- To pull changes made elsewhere: `git -C ~/dotfiles pull`, then
  rebuild as above.

`hardware-configuration.nix` and `secrets/` stay gitignored (see
"Secrets") - machine-specific, not meant to be committed - but once
this directory is a real git working tree, Nix only sees files
tracked in git's index when evaluating `flake.nix`'s relative imports.
`install.sh` reconciles this with `git add --intent-to-add --force`
right after generating them: that stages their *path*, so the flake
can find them, without staging their *content* for a future commit.
`lefthook.yml`'s pre-commit hook additionally refuses to let either
path actually get committed, as a second layer in case that ever gets
undone locally. This exact interaction - relative import, real git
tree, gitignored file - is also why CI stubs a throwaway
`hardware-configuration.nix` and stages it the same way before
`nix flake check` can run.

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

## CI

`.github/workflows/ci.yml` runs on every push and pull request:
- `nix flake check`, plus a `--dry-run` build of the full system
  closure, against a stub `hardware-configuration.nix` generated in
  the workflow (the real one is machine-specific and gitignored - see
  "Layout" - so CI has to fabricate a throwaway one just to let the
  flake evaluate; it is never used anywhere else).
- `shellcheck` on `install.sh`.
- `gitleaks`, the same scan `lefthook` runs locally pre-commit.
- `qmllint` over `dotfiles/quickshell/**/*.qml`, marked
  `continue-on-error`: resolving Quickshell's own QML modules inside a
  headless nix shell is somewhat fragile, so this job is advisory
  rather than a hard gate - worth a manual look if it goes red, not
  necessarily a blocker.

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
session) and `dotfiles/quickshell/{bar,lockscreen,shared}` (see
"Desktop" below). The greeter runs as a separate system user with no
home-manager-managed home directory, so its own Hyprland config and
its copy of `dotfiles/quickshell/{greeter,shared}` are published via
`environment.etc` in `configuration.nix` instead - `shared/` ends up
deployed twice, once per user, since the two Quickshell processes
never share a filesystem view.

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

**Terminal.** `programs.ghostty.enable = true;` (home-manager) installs
Ghostty; `SUPER+Return` opens one.

**Bar and wallpaper.** `dotfiles/quickshell/bar/shell.qml` is the
default Quickshell config: one full-screen background layer-shell
surface per monitor for the wallpaper, and one top-anchored bar
showing the current date and time. No wallpaper image is committed;
the `Image` source everywhere in this config (bar, greeter, lock
screen) is the fixed path `/etc/wallpaper.jpg`, which the machine
owner drops into place after install, e.g.
`sudo install -m 644 ~/Pictures/mine.jpg /etc/wallpaper.jpg`. It has to
be world-readable and outside any one user's home directory because
the greeter authenticates as its own unprivileged system user, not
`igor`, and can't read into `/home/igor` at all. There is no separate
wallpaper daemon (no swww/awww/hyprpaper) - Quickshell draws the
wallpaper itself as a background layer-shell surface. (Quickshell can
drive video wallpapers too, e.g. via an `mpv`-backed item, if a static
image stops being enough - not attempted here.)

**Login and lock screen.** Both are built from the same parameterized
QML components in `dotfiles/quickshell/shared/`, rather than two
separate UIs that happen to look alike:
- `SystemUsers.qml` reads `/etc/passwd` directly (world-readable, needs
  nothing beyond `cat`) for real local accounts - UID 1000-59999, a
  real shell - so new users added to `configuration.nix` show up on
  the login screen automatically, with no QML changes.
- `UserAvatar.qml` shows `/var/lib/AccountsService/icons/<username>`
  (the convention GDM/lightdm/regreet also use) if present, falling
  back to a plain initial-letter circle otherwise; no avatar files are
  required or committed.
- `AuthCard.qml` is the avatar/name/password card itself, reused
  as-is by both screens with different data and a different submit
  handler.

`dotfiles/quickshell/greeter/shell.qml` shows a macOS-style picker -
one avatar per account, from `SystemUsers` - that reveals an
`AuthCard` on click and submits to `Quickshell.Services.Greetd`.
`dotfiles/quickshell/lockscreen/LockSurface.qml` skips the picker,
since there's only ever one session to unlock, and shows a single
`AuthCard` for the current user, submitting through `LockContext.qml`
to `Quickshell.Services.Pam`. `SUPER+L` locks on demand
(`quickshell -c lockscreen`); `services.hypridle` (home-manager) locks
automatically after 5 minutes idle, blanks the display 30 seconds
after that, and locks again before suspend regardless of idle time.
It does not yet route through `loginctl lock-session`, so anything
that locks the session by another means won't reach this lock screen.

Not included yet: the matugen templates that translate a wallpaper's
palette into GTK, Qt, and Quickshell theme files. matugen supports
templates for both toolkits directly, the same mechanism
DankMaterialShell itself is built on, without requiring the rest of
that shell.

**A caution on the greeter and lock screen:** both are new,
hand-written against Quickshell's greetd/PAM APIs, and have not yet
been exercised on real hardware. Two independent safety nets while
testing:
- **A plain TTY.** Ctrl+Alt+F3 (or F4, F5...) switches to a text
  console (`agetty`) that runs completely independently of
  Hyprland/greetd; log in there with the normal password for a rescue
  shell. Ctrl+Alt+F1 (or wherever greetd/Hyprland actually landed)
  switches back.
- **An older boot generation.** `configurationLimit = 8;` in
  `configuration.nix` keeps the last 8 `nixos-rebuild` generations
  selectable from the boot menu, each a complete working system from
  before whatever change broke things - NixOS's standard rollback
  path, unrelated to this change specifically.

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

**Greeter/lock screen: Quickshell's own services, not a separate
backend.** DankMaterialShell (see "Prior art") pairs Quickshell with a
Go backend (`dms`) and a standalone `dank-greeter` binary for
session/greetd handling. This repository instead calls
`Quickshell.Services.Greetd` and `Quickshell.Services.Pam` directly
from QML, and uses `hypridle` (a small, independent, off-the-shelf
binary) for idle handling - fewer moving parts and no second language
in the stack, at the cost of the extras a whole second project buys
DMS: a session/session-type picker, fingerprint auth, a plugin system.

## Prior art

Structure and specific choices in this repository were informed by
looking at several other public NixOS configurations, in particular:

- [gvolpe/nix-config](https://github.com/gvolpe/nix-config)
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)
- [sioodmy/dotfiles](https://github.com/sioodmy/dotfiles)
- [XNM1/linux-nixos-hyprland-config-dotfiles](https://github.com/XNM1/linux-nixos-hyprland-config-dotfiles)

None of these are dependencies of this configuration; they are cited
for reference.

The Quickshell side (bar, greeter, lock screen) additionally drew on
[AvengeMedia/DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell) -
a complete Quickshell-based desktop shell, different in kind from the
NixOS configs above. Its wallpaper-driven matugen theming (mentioned
under "Desktop" above) and its use of Quickshell's Wayland-protocol
types are the parts most relevant here; its greetd/session handling
is not, per the design note above.
