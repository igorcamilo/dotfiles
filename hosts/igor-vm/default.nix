{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/storage/luks-btrfs.nix
    ../../modules/virtualisation/utm.nix
  ];

  networking.hostName = "igor-vm";
  dotfiles.storage.installDisk = lib.removeSuffix "\n" (builtins.readFile ./disk-device);
}
