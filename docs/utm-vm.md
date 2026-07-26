# UTM VM on the M1 Pro MacBook Pro

Use the current stable UTM application with its **QEMU** backend. The VM is a
normal file-backed guest; it does not require Nix on macOS and does not modify
the Mac's partition table.

## Create the VM

Download the official NixOS ARM64 minimal ISO, then create a new
**Virtualize → Other** QEMU VM with:

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

Give the virtual disk a fixed, non-empty serial. After starting the ISO,
confirm that udev created a stable whole-disk symlink:

```sh
lsblk -o NAME,PATH,MODEL,SERIAL,SIZE,TYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/
```

The installer deliberately rejects `/dev/vda` and other topology-dependent
names.

## Prepare custom Secure Boot

Before the first installation boot, open the stopped VM's
**QEMU → Maintenance** settings:

1. select **Reset UEFI Variables**;
2. leave **Preload Secure Boot Keys** disabled; and
3. start the VM once so UTM applies the change.

This gives the VM UEFI and TPM support while leaving firmware in Setup Mode
for the repository's own sbctl keys. Do not preload UTM's Platform Key.

## Install and checkpoint

Inside the ARM64 live environment, follow [install.md](install.md):

```sh
sudo ./install.sh --host igor-vm
```

After the installed system boots and generates its signing keys, shut it down
and take a UTM snapshot. Take another snapshot before Secure Boot key
enrollment and another before TPM enrollment. Snapshots supplement, but do not
replace, the LUKS recovery passphrase.

## Graphics fallback

VirGL acceleration is experimental. If Hyprland freezes or the display stays
blank:

1. stop the VM;
2. replace `virtio-gpu-gl-pci` with `virtio-ramfb`;
3. disable accelerated rendering; and
4. boot the same `igor-vm` configuration.

This changes only virtual graphics performance; the host remains
`aarch64-linux`. The guest enables QEMU and SPICE agents for shutdown, time
synchronization, clipboard integration, and display resize support.
