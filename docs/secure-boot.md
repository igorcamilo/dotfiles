# Secure Boot, measured boot, and TPM2

Complete these steps on `igor-desktop`.

## Prepare and sign

The first installed boot deliberately happens with Secure Boot disabled.
Lanzaboote uses systemd-boot as the UEFI boot menu and permits unsigned boot
artifacts only because signing keys did not exist during installation.

Confirm UEFI, the current boot loader, TPM availability, and Secure Boot state:

```sh
bootctl status
sudo /run/current-system/systemd/lib/systemd/systemd-pcrlock is-supported
```

The second command must print `yes`. Stop if it reports anything else.

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
sudo nixos-rebuild switch --flake "/etc/nixos#igor-desktop"
sudo sbctl verify
```

Do not enroll keys unless the installed bootloader and all UKIs are reported
signed. The configuration deliberately does not enable Lanzaboote's automatic
firmware enrollment. Take a full system backup now.

## Enroll keys

Enter firmware Setup Mode using the motherboard vendor's instructions only
after signature verification.

Enroll the repository's key while retaining Microsoft certificates:

```sh
sudo sbctl enroll-keys --microsoft
```

Some physical devices also require `--firmware-builtin` to preserve vendor
firmware-update keys. Check the hardware vendor's instructions before using
that option.

Reboot and verify:

```sh
bootctl status
sudo sbctl status
```

Both must report Secure Boot enabled before TPM enrollment.

## Enroll the LUKS volume

The policy generated during installation reflected the live ISO and must never
be used for enrollment. The installed system regenerates it during boot and
whenever Lanzaboote installs a new generation. Inspect the current boot's
policy-generation log:

```sh
sudo journalctl \
  --boot \
  --unit=systemd-pcrlock-make-policy.service \
  --no-pager
```

Stop if the log says that PCR 4 or PCR 7 was dropped, that no PCRs were kept,
or that the policy-generation service failed.

First prove that the independent recovery passphrase works:

```sh
sudo cryptsetup open --test-passphrase \
  /dev/disk/by-partlabel/disk-main-luks
```

Confirm that the generated policy actually protects both configured PCRs. A
non-empty file alone is insufficient: `systemd-pcrlock` can write a policy
containing no PCR protection.

```sh
sudo nix eval --impure --raw --expr '
  let
    policy = builtins.fromJSON (
      builtins.readFile "/var/lib/systemd/pcrlock.json"
    );
    protectedPcrs = builtins.map (entry: entry.pcr) policy.pcrValues;
  in
  if builtins.all (pcr: builtins.elem pcr protectedPcrs) [ 4 7 ] then
    "PCR policy protects PCRs 4 and 7.\n"
  else
    builtins.throw "PCR policy does not protect both PCR 4 and PCR 7"
'
```

Proceed only when this prints `PCR policy protects PCRs 4 and 7.`

Take another full system backup before changing the LUKS slots.

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
