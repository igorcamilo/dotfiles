# Create the UTM virtual machine

This guide ends when `igor-vm` is ready to boot the NixOS installer.
Everything here happens in Finder or UTM on macOS. Disk selection,
installation, first boot, and installation troubleshooting are in
[install.md](install.md), where every Nix command runs inside NixOS.

The repository includes a ready-to-import template for UTM 4.7.5 on Apple
Silicon. The template uses UTM's **QEMU** backend; it does not require Nix on
macOS and does not modify the Mac's partition table.

## Import the template

1. Open **UTM → About UTM** and confirm that version 4.7.5 is installed. This
   is the version tested by this repository.
2. Download the
   [official NixOS ARM64 minimal ISO](https://nixos.org/download/).
3. In Finder, locate
   [`templates/igor-vm.utm`](../templates/igor-vm.utm), but **do not open this
   repository copy**.
4. Copy the complete `igor-vm.utm` package to a working location outside the
   repository, such as a `Virtual Machines` folder in your home directory.
5. Open the copied package. UTM registers and modifies that working copy in
   place.
6. Leave the VM stopped. Select its empty removable CD/DVD drive, choose
   **Browse…**, and attach the downloaded NixOS ISO.

Opening the repository package directly does not make another copy. Booting
it changes its virtual disk, UEFI variables, TPM state, and removable-media
bookmark, which dirties the repository and can destroy the pristine template.

If the repository copy is already registered in UTM, stop the VM, open its
action menu, choose **Move…**, and move it outside the repository. Then restore
the pristine repository package:

```sh
git restore templates/igor-vm.utm
```

UTM documents moving a registered VM in its
[action menu](https://docs.getutm.app/basics/actions/).

The ISO remains an external removable disk image. It is deliberately not
stored in the template or this repository. UTM documents this distinction in
its [drive settings](https://docs.getutm.app/settings-qemu/drive/drive/).

## What the template defines

The template contains:

- ARM64/AArch64 QEMU `virt` machine;
- `default` CPU, hardware virtualization, 6 processors, and 16 GiB memory;
- empty 150 GiB sparse QCOW2 system disk using the VirtIO interface;
- empty removable USB CD/DVD drive for the installer ISO;
- `virtio-net-pci` shared/NAT networking;
- `virtio-gpu-gl-pci` display with automatic resolution;
- a built-in serial terminal connected to the automatic ARM serial port;
- clipboard sharing, with directory sharing disabled;
- UEFI, RNG, balloon, and TPM 2.0 devices; and
- UTC hardware clock rather than RTC local-time mode.

It contains no operating system, ISO, password, Secure Boot key, or TPM state.
The large virtual capacity does not consume 150 GiB immediately: QCOW2 grows
as data is written. The complete empty template occupies less than 1 MiB in
the checkout.

You can inspect these values in UTM's settings or read the template's
[`config.plist`](../templates/igor-vm.utm/config.plist). UTM documents the
corresponding controls under
[System](https://docs.getutm.app/settings-qemu/system/) and
[QEMU](https://docs.getutm.app/settings-qemu/qemu/).

## Open the recovery terminal

`ttyAMA0` is Linux's name for the first serial port on this emulated ARM
machine. It is not a username, command, or second VM. The graphical display
and this serial port are two views into the same running VM:

- the graphical display shows the boot menu, disk-unlock prompt, and desktop;
- UTM's built-in terminal connects to `ttyAMA0` and provides a text login when
  the graphical login is unavailable.

The template already contains the required serial device. When the VM starts,
UTM normally opens a separate window for each graphical display and built-in
terminal. To reach the terminal:

1. look for the additional black terminal window that opens with the VM;
2. if it was closed or hidden, click the **display** button—the overlapping
   rectangles at the right of the running VM's toolbar—and select the terminal
   output;
3. press Return if no prompt is visible; and
4. at `igor-vm login:`, enter `igor` and the password chosen during
   installation.

An existing VM copied before the template gained this device will not update
automatically. With that VM fully stopped, open its settings, add a **Serial**
device, set **Mode** to **Built-in Terminal** and **Target** to **Automatic**,
then save and start it again.

UTM documents both the
[built-in terminal connection](https://docs.getutm.app/settings-qemu/devices/serial/)
and reopening a closed terminal with the
[toolbar's display button](https://docs.getutm.app/advanced/multiple-displays/).

## Keep the system disk identity

UTM 4.7.2 and newer assign a fixed serial automatically to each VirtIO block
device. The template already contains the system disk, so there is no serial
field or custom QEMU argument to add.

Do not delete and recreate that disk after installation. A replacement is a
different virtual block device and can receive a different
`/dev/disk/by-id/...` identity. The automatic fixed serial is documented in
the [UTM 4.7.2 release
notes](https://github.com/utmapp/UTM/releases/tag/v4.7.2).

## Prepare custom Secure Boot

The template has never been booted and contains fresh UEFI variables without
preloaded vendor keys. Explicitly request the intended state before the first
boot:

1. open the stopped VM's **QEMU → Maintenance** settings;
2. select **Reset UEFI Variables**;
3. leave **Preload Secure Boot Keys** disabled; and
4. save the VM.

These maintenance choices apply on the next start. Resetting without
preloading keys leaves the firmware in Setup Mode for this repository's own
sbctl keys. Do not preload UTM's Platform Key.

## Continue with installation

Start `igor-vm` from the attached ARM64 ISO and follow
[Install NixOS](install.md). That guide contains every remaining installation
step for both the VM and the physical desktop.
