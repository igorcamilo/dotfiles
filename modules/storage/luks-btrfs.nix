{ config, lib, ... }:

let
  cfg = config.nixos-config.storage;
in
{
  options.nixos-config.storage.installDisk = lib.mkOption {
    type = lib.types.str;
    example = "/dev/disk/by-id/nvme-example";
    description = "Stable whole-disk path used by Disko during installation.";
  };

  config.disko.devices.disk.main = {
    type = "disk";
    device = cfg.installDisk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          size = "2G"; # A full signed UKI per generation; 1G is too little.
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptroot";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/root" = {
                  mountpoint = "/";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/home" = {
                  mountpoint = "/home";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
                "/nix" = {
                  mountpoint = "/nix";
                  mountOptions = [
                    "compress=zstd"
                    "noatime"
                  ];
                };
              };
            };
          };
        };
      };
    };
  };
}
