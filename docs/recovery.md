# Recovery and known limitations

## Recovery paths

- Use Ctrl+Alt+F3 (or another free VT) if graphical login fails, and log in as
  `igor` with the password chosen during installation.
- Greeter runtime directories disappear when a failed greeter session exits,
  so `/run/user/<greeter-uid>/hypr/.../hyprland.log` is not a durable log.
  Read the retained logs from that VT instead:

  ```sh
  sudo journalctl -b -t greetd-greeter
  sudo journalctl -b -u greetd
  ```

  The first command contains Hyprland and Quickshell output; the second
  contains greetd's session decisions.
- Select an older NixOS generation from the boot menu after a broken rebuild.
- Press Escape while Plymouth is running to reveal boot details or a text
  prompt; press Escape again to return to the graphical splash.
- If the graphical display shows only a text disk prompt, inspect the current
  boot:

  ```sh
  cat /proc/cmdline
  sudo journalctl -b --grep='plymouth|cryptsetup'
  ```

  The command line should include `console=tty0`,
  `plymouth.ignore-serial-consoles`, `quiet`, and `splash`.
  BGRT retains a firmware logo only when the firmware supplies one. A graphical
  spinner and password prompt without a vendor logo still mean that Plymouth
  is working.
- If the firmware opens the `Shell>` UEFI prompt, it did not find an installed
  bootloader. Enter `fs0:` and then `ls EFI\BOOT`. A completed installation
  contains `BOOTX64.EFI`, which can be started with
  `EFI\BOOT\BOOTX64.EFI`. If that file is absent, reattach the installer ISO
  and rerun the installer; the previous installation did not complete.
- Boot the architecture-matching NixOS installer, unlock and mount the target,
  then rebuild from `/mnt/home/igor/dotfiles` if no installed generation
  works.
- Keep the LUKS recovery passphrase and a backup of Secure Boot keys outside
  the encrypted disk.

Do not wipe or replace a TPM slot until the recovery passphrase has been tested
with `cryptsetup open --test-passphrase`.

## Known limitations

- The committed hardware module is a generic, architecture-correct
  placeholder until the first installation commits the real scan.
- The custom Quickshell greeter and lock screen need real-hardware testing.
- The greeter currently targets one interactive surface; multi-monitor
  presentation has not been completed.
- QML authentication assumes the default password-only PAM conversation.
- Audio, a graphical polkit agent, notifications, and complete portal
  integration are follow-up workstation work.

Native x86_64 CI can build the system closure and lint the shared QML, but
it cannot validate firmware enrollment, TPM behavior, GPU initialization, or
physical recovery paths.
