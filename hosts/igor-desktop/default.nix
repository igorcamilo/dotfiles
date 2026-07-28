_:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/storage/luks-btrfs.nix
  ];

  networking.hostName = "igor-desktop";

  # Installing erases this disk. A by-id path names one physical device for
  # good; /dev/nvme0n1 and /dev/sda can point at a different one after a
  # reboot or a cable swap.
  nixos-config.storage.installDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7HENL0L304721P_1";
}
