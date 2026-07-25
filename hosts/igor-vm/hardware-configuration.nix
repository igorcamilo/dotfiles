{
  lib,
  modulesPath,
  ...
}:

{
  # Bootstrap placeholder. install.sh replaces this with the UTM guest scan.
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_blk"
    "virtio_scsi"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
