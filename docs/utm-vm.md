# Create the UTM virtual machine

This guide ends when `igor-vm` is ready to boot the NixOS installer. All
commands run inside NixOS, disk selection, installation, first boot, and
installation troubleshooting are in [install.md](install.md).

Use UTM 4.7.2 or newer with its **QEMU** backend. The VM is a normal
file-backed guest; creating it does not require Nix on macOS and does not
modify the Mac's partition table.

## Create the basic VM

Open **UTM → About UTM** and confirm the version is 4.7.2 or newer. Update UTM
before continuing if it is older.

Download the
[official NixOS ARM64 minimal ISO](https://nixos.org/download/), then create a
new **Virtualize → Other** QEMU VM with:

- name: `igor-vm`
- architecture: ARM64/AArch64
- CPU: `default`, hardware hypervisor enabled
- processors: 6
- memory: 16 GiB
- disk: 150 GiB, QCOW2/sparse, VirtIO, non-removable
- network: `virtio-net-pci`, shared/NAT
- display: `virtio-gpu-gl-pci`, auto-resolution enabled
- clipboard sharing: enabled
- UEFI, RNG, balloon, and TPM 2.0: enabled
- RTC local-time mode: disabled

Save the VM, leave it stopped, and open its settings once more to verify the
values above. UTM documents the QEMU controls under
[System](https://docs.getutm.app/settings-qemu/system/) and
[QEMU](https://docs.getutm.app/settings-qemu/qemu/).

## Create the disk with a stable identity

UTM 4.7.2 added a fixed serial automatically for VirtIO block devices. There
is no serial text field to fill in and no custom QEMU argument to add.

With the VM stopped:

1. Open the VM's settings.
2. Under **Drives**, select the 150 GiB system disk. If it does not exist,
   choose **New…** under **Drives** and create it.
3. Set **Image Type** to **Disk Image**.
4. Set **Interface** to **VirtIO**.
5. Leave **Removable** disabled and **Raw Image** disabled. This keeps the
   disk inside the `.utm` bundle as a sparse QCOW2 image.
6. Save the VM. Do not delete and recreate this drive after installation,
   because a new virtual block device may receive a new identity.

UTM's drive editor and storage behavior are described in its
[drive documentation](https://docs.getutm.app/settings-qemu/drive/drive/).
The automatic fixed serial is documented in the
[UTM 4.7.2 release notes](https://github.com/utmapp/UTM/releases/tag/v4.7.2).

## Prepare custom Secure Boot

Before the first boot, open the stopped VM's **QEMU → Maintenance** settings:

1. select **Reset UEFI Variables**;
2. leave **Preload Secure Boot Keys** disabled; and
3. save the VM.

These maintenance choices apply on the next VM start. Resetting without
preloading keys leaves the firmware in Setup Mode for this repository's own
sbctl keys. Do not preload UTM's Platform Key.

## Continue with installation

The VM is now ready. Start it from the ARM64 ISO and follow
[Install NixOS](install.md). That guide contains every remaining step for both
the VM and the physical desktop.
