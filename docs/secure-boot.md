# Secure Boot, measured boot, and TPM2

The initial system uses systemd-boot because Lanzaboote needs keys that do not
exist during installation.

## Prepare and sign

Confirm the first boot is UEFI with systemd-boot:

```sh
bootctl status
```

Create root-only Secure Boot keys, then switch to the production profile:

```sh
sudo sbctl create-keys
sudo nixos-rebuild switch --flake /etc/nixos#igor-desktop
sudo sbctl verify
```

Do not continue unless the installed bootloader and UKIs are reported signed.

## Enroll keys

Put the firmware into Secure Boot Setup Mode using its vendor instructions.
Boot NixOS again and retain Microsoft certificates to support signed Option
ROMs:

```sh
sudo sbctl enroll-keys --microsoft
```

Some devices, notably some Framework models, also require
`--firmware-builtin` to preserve vendor firmware-update keys. Check the
hardware vendor instructions before enrollment.

Reboot and verify:

```sh
bootctl status
sudo sbctl status
```

Both must report Secure Boot enabled before TPM enrollment.

## Enroll the LUKS volume

First verify the recovery passphrase while the system is running:

```sh
sudo cryptsetup open --test-passphrase \
  /dev/disk/by-partlabel/disk-main-luks
```

Confirm Lanzaboote generated a non-empty measured-boot policy:

```sh
sudo test -s /var/lib/systemd/pcrlock.json
```

Then enroll TPM2 against that policy:

```sh
sudo systemd-cryptenroll \
  --wipe-slot=tpm2 \
  --tpm2-device=auto \
  --tpm2-pcrlock=/var/lib/systemd/pcrlock.json \
  /dev/disk/by-partlabel/disk-main-luks
```

Reboot once to test automatic unlock, then reboot again and force recovery
passphrase entry from the boot flow before considering setup complete.

Never remove the recovery passphrase slot. Secure Boot keys under
`/var/lib/sbctl` and TPM state are machine-local and must not be committed.
