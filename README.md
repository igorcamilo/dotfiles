# NixOS configuration

`igor-desktop` is an x86_64 desktop with an AMD RX 9070 XT, an encrypted btrfs
root, Secure Boot through Lanzaboote, and KDE Plasma 6.

Rebuild the installed machine with `nh os switch`, or:

```sh
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
```

## Install

This erases the target disk. Boot a UEFI NixOS ISO with Secure Boot disabled
in firmware and run everything below as root.

```sh
export NIX_CONFIG="extra-experimental-features = nix-command flakes"
nix-shell -p git --run 'git clone https://github.com/igorcamilo/nixos-config /tmp/nixos-config'
cd /tmp/nixos-config
```

Confirm which disk to erase, and edit `nixos-config.storage.installDisk` in
`hosts/igor-desktop/default.nix` if it differs:

```sh
ls -l /dev/disk/by-id/
lsblk -o PATH,MODEL,SERIAL,SIZE,TYPE
nano hosts/igor-desktop/default.nix
```

Partition, encrypt, format, and mount. This is the destructive step, and it
asks twice for the LUKS passphrase:

```sh
nix run .#disko -- --mode destroy,format,mount --flake .#igor-desktop
```

Scan the hardware. Disko owns the filesystems, so leave them out:

```sh
nixos-generate-config --no-filesystems --root /mnt --dir /tmp/hw
cp /tmp/hw/hardware-configuration.nix hosts/igor-desktop/hardware-configuration.nix
```

Install, then move the checkout to its permanent home at
`~/Developer/nixos-config` and point `/etc/nixos` at it:

```sh
nixos-install --root /mnt --flake .#igor-desktop --no-root-passwd

mkdir -p /mnt/home/igor/Developer
cp -r /tmp/nixos-config /mnt/home/igor/Developer/nixos-config
ln -s /home/igor/Developer/nixos-config /mnt/etc/nixos
nixos-enter --root /mnt -c 'chown -R igor:users /home/igor/Developer'
nixos-enter --root /mnt -c 'passwd igor'
reboot
```

Nix warns that the Git tree is dirty because two tracked files were edited.
That is expected; those edits are what gets installed.

## Capture Plasma settings and update

Change what you want in System Settings, then:

```sh
config-sync
```

That runs `rc2nix` into `plasma-generated.nix`, updates every flake input, and
rebuilds. Review and commit both files afterwards:

```sh
git -C /etc/nixos diff -- plasma-generated.nix flake.lock
```

`rc2nix` rewrites `plasma-generated.nix` wholesale, so never edit that file.
Hand-written Plasma settings go in `plasma.nix`, which also has to hold
anything `rc2nix` deliberately drops as uninteresting state — the global
theme, colour scheme and Plasma theme among them.

`--update` refreshes every flake input and writes `flake.lock`, which is what
pins all packages. It runs as your user, and `/etc/nixos` is a symlink into
your own checkout, so it can write the lock. Note that the lock is updated
before the build, so a failed build still leaves it changed.

Two things Nix does not pin: the Firefox extensions, which Firefox updates
itself from addons.mozilla.org, and the llama.cpp model, which is fetched at
first start and cached under `/var/cache/llama-cpp`.

## Local model in VS Code

`llama-server` runs the model; wiring it into Copilot Chat is manual. Run
**Chat: Manage Language Models** → Add Models → Custom Endpoint → Chat
Completions, with URL `http://127.0.0.1:8080/v1/chat/completions` and model id
`qwen3-coder-30b-a3b`. In the `chatLanguageModels.json` that VS Code opens, set
`"toolCalling": true` on that model, or Copilot offers it in Ask mode only.

The first start downloads about 15GB, so the service takes a while to come up.

## Secure Boot

Lanzaboote creates the signing keys on the first boot of the installed system,
so its boot artifacts are unsigned until the next rebuild. Keep Secure Boot
disabled in firmware until the end of this section.

```sh
systemctl status generate-sb-keys.service
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
sudo sbctl verify
```

Continue only if `sbctl verify` reports the bootloader and every UKI as signed.
Take a full backup, put the firmware into Setup Mode, then enroll the machine's
own key while keeping the Microsoft certificates:

```sh
sudo sbctl enroll-keys --microsoft
sudo reboot
```

Some boards also need `--firmware-builtin` to keep their firmware-update keys.
Re-enable Secure Boot in firmware during that reboot, then confirm both report
it as enabled:

```sh
bootctl status
sudo sbctl status
```

## Passwordless unlock (TPM2)

Only with Secure Boot actually enabled. The policy generated during
installation described the live ISO; the installed system regenerates it on
every boot and whenever Lanzaboote installs a new generation.

```sh
sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
sudo journalctl -b -u systemd-pcrlock-make-policy.service --no-pager
```

The first command must print `yes`. Stop if the log says PCR 4 or PCR 7 was
dropped, that no PCRs were kept, or that the service failed.

Prove the recovery passphrase still works, take another backup, then bind the
volume to the TPM:

```sh
sudo cryptsetup open --test-passphrase /dev/disk/by-partlabel/disk-main-luks
sudo systemd-cryptenroll \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  /dev/disk/by-partlabel/disk-main-luks
```

Reboot once to test the automatic unlock, then reboot again and deliberately
use the recovery passphrase before considering this done.

Never remove the passphrase slot. A firmware update changes the measured PCRs
and the TPM slot stops unlocking; the passphrase is the only way back in.
