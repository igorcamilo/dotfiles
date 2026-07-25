# Fresh installation

This procedure erases the selected physical or virtual disk. Keep backups and
the LUKS recovery passphrase somewhere independent of the target.

## Prepare the exact source

Boot the NixOS installer matching the target:

- `x86_64-linux` for `igor-desktop`
- ARM64/AArch64 for `igor-vm`

Clone and review the configuration:

```sh
git clone https://github.com/igorcamilo/dotfiles.git
cd dotfiles
git log -1 --oneline
git status --short
```

The installer requires a committed `flake.lock` and never updates it. If the
lock is not present, use the read-only **Generate flake lock** workflow in
GitHub Actions:

1. Open **Actions → Generate flake lock → Run workflow** and select the exact
   branch to install.
2. Wait for the native ARM job to finish, then download its
   `flake-lock-<source revision>` artifact from the workflow summary.
3. Extract the artifact outside the repository and verify it on macOS:

   ```sh
   LOCK_ARTIFACT=/path/to/extracted/artifact
   (cd "$LOCK_ARTIFACT" && shasum -a 256 -c flake.lock.sha256)
   test "$(<"$LOCK_ARTIFACT/SOURCE_REVISION")" = "$(git rev-parse HEAD)"
   cp "$LOCK_ARTIFACT/flake.lock" ./flake.lock
   git add flake.lock
   git commit -m "Lock Nix inputs"
   git push
   ```

The workflow has read-only repository access and cannot commit the result.
It validates locked metadata and both ARM host profiles before completing.
Once a NixOS environment is available, `nix flake lock` there remains the
normal alternative. Do not install Nix on macOS for this procedure.

Identify a stable whole-disk path:

```sh
ls -l /dev/disk/by-id/
lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE,FSTYPE,MOUNTPOINTS
```

Do not continue without a `/dev/disk/by-id/...` entry for the intended whole
disk. UTM users should fix the virtual disk serial in UTM before proceeding.

## Install

Run from a clean checkout, selecting exactly one host:

```sh
sudo ./install.sh --host igor-desktop
sudo ./install.sh --host igor-vm
```

Use `--dry-run` to exercise validation and exact disk confirmation without
changing the disk:

```sh
sudo ./install.sh --host igor-vm --dry-run
```

Before destructive confirmation, the installer:

1. verifies root, UEFI mode, an empty `/mnt`, and required commands;
2. requires `flake.lock` and a clean Git checkout;
3. evaluates the selected production and bootstrap configurations without
   updating the lock;
4. rejects a live installer whose architecture differs from the host;
5. accepts only an unused whole-disk `/dev/disk/by-id/...` path; and
6. displays its model, serial, size, filesystems, and mount state.

After exact confirmation, it uses the locked Disko app, writes only the
selected host's disk identity and hardware scan, installs
`<host>-bootstrap`, and sends the login password directly to `chpasswd`.
Disko/cryptsetup separately requests the LUKS recovery passphrase.

## First boot

Review and commit only the generated host data:

```sh
cd ~/dotfiles
git diff -- hosts/igor-vm
git add hosts/igor-vm
git commit -m "Record igor-vm hardware"
```

Replace `igor-vm` with `igor-desktop` for the physical machine. Do not enable
Secure Boot or TPM unlock until the bootstrap profile has booted successfully.
Continue with [secure-boot.md](secure-boot.md).
