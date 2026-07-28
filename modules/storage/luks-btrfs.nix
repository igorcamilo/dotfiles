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
          # Lanzaboote keeps a full signed UKI per generation, times
          # configurationLimit in modules/boot/secure-boot.nix. 1G is too
          # little.
          size = "2G";
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
