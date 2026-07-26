# Secure Boot, measured boot, and TPM2

Complete these steps separately on each host. Replace `<host>` with
`igor-desktop` or `igor-vm`.

## Prepare and sign

The first installed boot deliberately happens with Secure Boot disabled.
Lanzaboote uses systemd-boot as the UEFI boot menu and permits unsigned boot
artifacts only because signing keys did not exist during installation.

Confirm UEFI, the current boot loader, TPM availability, and Secure Boot state:

```sh
bootctl status
```

The first boot starts a one-shot service that creates root-only keys. Verify
that it succeeded:

```sh
systemctl status generate-sb-keys.service
sudo test -s /var/lib/sbctl/keys/db/db.key
```

If the service has not run yet, start it and check it again:

```sh
sudo systemctl start generate-sb-keys.service
```

Rebuild the same host configuration now that the keys exist, then verify every
boot artifact:

```sh
sudo nixos-rebuild switch --flake "/etc/nixos#<host>"
sudo sbctl verify
```

Do not enroll keys unless the installed bootloader and all UKIs are reported
signed. The configuration deliberately does not enable Lanzaboote's automatic
firmware enrollment. Take a VM snapshot or physical-system backup now.

## Enroll keys

For `igor-vm`, UTM should already be in Setup Mode because its UEFI variables
were reset without preloaded keys as described in [utm-vm.md](utm-vm.md).

For `igor-desktop`, enter firmware Setup Mode using the motherboard vendor's
instructions only after signature verification.

Enroll the repository's key while retaining Microsoft certificates:

```sh
sudo sbctl enroll-keys --microsoft
```

Some physical devices also require `--firmware-builtin` to preserve vendor
firmware-update keys. Check the hardware vendor's instructions before using
that option. It is not needed for the UTM VM.

Reboot and verify:

```sh
bootctl status
sudo sbctl status
```

Both must report Secure Boot enabled before TPM enrollment.

## Enroll the LUKS volume

First prove that the independent recovery passphrase works:

```sh
sudo cryptsetup open --test-passphrase \
  /dev/disk/by-partlabel/disk-main-luks
```

Confirm Lanzaboote generated a non-empty measured-boot policy:

```sh
sudo test -s /var/lib/systemd/pcrlock.json
```

Take another VM snapshot or physical-system backup before changing the LUKS
slots.

Then enroll TPM2 against that policy:

```sh
sudo systemd-cryptenroll \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  /dev/disk/by-partlabel/disk-main-luks
```

Reboot once to test automatic unlock. Reboot again and deliberately use the
recovery passphrase before considering setup complete.

Never remove the recovery passphrase slot. Secure Boot keys under
`/var/lib/sbctl` and TPM state are machine-local and must not be committed.
