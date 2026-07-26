{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/storage/luks-btrfs.nix
  ];

  networking.hostName = "igor-desktop";
  dotfiles.storage.installDisk = lib.removeSuffix "\n" (builtins.readFile ./disk-device);
}
