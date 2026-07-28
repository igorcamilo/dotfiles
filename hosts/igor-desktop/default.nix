_:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/storage/luks-btrfs.nix
  ];

  networking.hostName = "igor-desktop";

  # Installing erases this disk. By-id names one physical device for good;
  # /dev/nvme0n1 can point at a different one after a reboot.
  nixos-config.storage.installDisk = "/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_S7HENL0L304721P_1";
}
