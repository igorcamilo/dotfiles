# Recovery and known limitations

## Recovery paths

- In UTM, use
  [the built-in recovery terminal](utm-vm.md#open-the-recovery-terminal) if
  greetd, Hyprland, or Quickshell fails. It is a separate UTM window connected
  to `ttyAMA0`, the VM's first emulated ARM serial port. Press Return, then log
  in as `igor` with the password chosen during installation.
- On the physical desktop, use Ctrl+Alt+F3 (or another free VT) if graphical
  login fails.
- Select an older NixOS generation from the boot menu after a broken rebuild.
- Press Escape while Plymouth is running to reveal boot details or a text
  prompt; press Escape again to return to the graphical splash.
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
