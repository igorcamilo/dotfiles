# Recovery and known limitations

## Recovery paths

- In UTM, use
  [the built-in recovery terminal](utm-vm.md#open-the-recovery-terminal) if
  greetd, Hyprland, or Quickshell fails. It is a separate UTM window connected
  to `ttyAMA0`, the VM's first emulated ARM serial port. Press Return, then log
  in as `igor` with the password chosen during installation.
- Greeter runtime directories disappear when a failed greeter session exits,
  so `/run/user/<greeter-uid>/hypr/.../hyprland.log` is not a durable log.
  Read the retained logs from the recovery terminal instead:

  ```sh
  sudo journalctl -b -t greetd-greeter
  sudo journalctl -b -u greetd
  ```

  The first command contains Hyprland and Quickshell output; the second
  contains greetd's session decisions.
- On the physical desktop, use Ctrl+Alt+F3 (or another free VT) if graphical
  login fails.
- Select an older NixOS generation from the boot menu after a broken rebuild.
- Press Escape while Plymouth is running to reveal boot details or a text
  prompt; press Escape again to return to the graphical splash.
- If the VM shows only a text disk prompt, confirm that its display is
  `virtio-ramfb-gl` and inspect the current boot:

  ```sh
  cat /proc/cmdline
  sudo journalctl -b --grep='plymouth|cryptsetup'
  ```

  The command line should include `console=tty0`,
  `plymouth.ignore-serial-consoles`, `quiet`, and `splash`.
  BGRT retains a firmware logo only when the firmware supplies one. A graphical
  spinner and password prompt without a vendor logo still mean that Plymouth
  is working.
- If UTM opens the `Shell>` UEFI prompt, the firmware did not find an installed
  bootloader. Enter `fs0:` and then `ls EFI\BOOT`. A completed ARM installation
  contains `BOOTAA64.EFI`, which can be started with
  `EFI\BOOT\BOOTAA64.EFI`. If that file is absent, reattach the installer ISO
  and rerun the installer; the previous installation did not complete.
- Boot the architecture-matching NixOS installer, unlock and mount the target,
  then rebuild from `/mnt/home/igor/dotfiles` if no installed generation
  works.
- Keep the LUKS recovery passphrase and a backup of Secure Boot keys outside
  the encrypted disk.

Do not wipe or replace a TPM slot until the recovery passphrase has been tested
with `cryptsetup open --test-passphrase`.

## Known limitations

- Each committed hardware module is a generic, architecture-correct
  placeholder until that host's first installation commits the real scan.
- The custom Quickshell greeter and lock screen need real-hardware testing.
- The greeter currently targets one interactive surface; multi-monitor
  presentation has not been completed.
- QML authentication assumes the default password-only PAM conversation.
- Audio, a graphical polkit agent, notifications, and complete portal
  integration are follow-up workstation work.

Native x86_64 and ARM64 CI can build both system closures and lint the
shared QML, but it cannot validate firmware enrollment, TPM behavior, GPU
initialization, snapshots, or physical recovery paths.
