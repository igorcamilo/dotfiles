# Fresh installation

This procedure erases the selected disk. Keep backups and the LUKS recovery
passphrase somewhere independent of the machine.

## Prepare

1. Boot the NixOS installer in UEFI mode.
2. Connect to the network.
3. Clone and review the exact configuration to install:

   ```sh
   git clone https://github.com/igorcamilo/dotfiles.git
   cd dotfiles
   git log -1 --oneline
   git status --short
   ```

4. Identify a stable whole-disk path:

   ```sh
   ls -l /dev/disk/by-id/
   lsblk -o NAME,PATH,MODEL,SIZE,TYPE,FSTYPE,MOUNTPOINTS
   ```

## Install

Run from a clean checkout:

```sh
sudo ./install.sh
```

The installer:

1. verifies root, UEFI mode, an empty `/mnt`, and required commands;
2. accepts only a whole-disk `/dev/disk/by-id/...` path;
3. refuses disks with mounted or active children;
4. requires confirmation containing the exact selected path;
5. installs the exact checked-out Git commit;
6. writes the selected disk identity into the tracked host configuration;
7. partitions and mounts with the Disko revision from `flake.lock`;
8. generates a tracked hardware module with `--no-filesystems`;
9. installs `igor-desktop-bootstrap` with systemd-boot; and
10. sends the login password directly to `chpasswd` inside the target.

Disko/cryptsetup asks separately for the LUKS passphrase. It becomes the
recovery credential once TPM unlock is configured.

Use `sudo ./install.sh --dry-run` to exercise environment and disk validation
without changing the disk.

## First boot

The target checkout intentionally contains two non-secret changes. Review and
commit them so future clean clones describe the real machine:

```sh
cd ~/dotfiles
git diff -- hosts/igor-desktop
git add hosts/igor-desktop
git commit -m "Record igor-desktop hardware"
git push
```

Do not enable firmware Secure Boot yet. Continue with
[secure-boot.md](secure-boot.md).
