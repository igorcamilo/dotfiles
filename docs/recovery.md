# Recovery and known limitations

## Recovery paths

- Use Ctrl+Alt+F3 (or another free VT) if greetd or Quickshell fails.
- Select an older NixOS generation from the boot menu after a broken rebuild.
- Boot the NixOS installer, unlock and mount the target, then rebuild from
  `/mnt/home/igor/dotfiles` if no installed generation works.
- Keep the LUKS recovery passphrase and a backup of Secure Boot keys outside
  the encrypted disk.

Do not wipe or replace a TPM slot until the recovery passphrase has been tested
with `cryptsetup open --test-passphrase`.

## Known limitations

- The committed hardware module is a generic bootstrap placeholder until the
  first installation generates and commits the real scan.
- The custom Quickshell greeter and lock screen need real-hardware testing.
- The greeter currently targets one interactive surface; multi-monitor
  presentation has not been completed.
- QML authentication assumes the default password-only PAM conversation.
- Audio, a graphical polkit agent, notifications, and complete portal
  integration are follow-up workstation work.
- `/etc/wallpaper.jpg` is still a machine-local asset; a missing file falls
  back to the configured dark background.

CI can build both system closures and lint the QML, but it cannot validate
firmware enrollment, TPM behavior, GPU initialization, or physical recovery
paths.
