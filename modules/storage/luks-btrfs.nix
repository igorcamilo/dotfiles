{ config, lib, ... }:

let
  cfg = config.nixos-config.storage;
in
{
  # The one fact this layout cannot know by itself: which disk it belongs to.
  # Every host that imports this file supplies its own.
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
          # Lanzaboote keeps a full signed UKI (kernel + initrd, amdgpu firmware
          # included) per generation, times configurationLimit generations kept
          # in modules/boot/secure-boot.nix; 1G leaves too little headroom.
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
