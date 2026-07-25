{ lib, ... }:

{
  imports = [ ../../modules/storage/luks-btrfs.nix ];

  dotfiles.storage.installDisk = lib.removeSuffix "\n" (
    builtins.readFile ./disk-device
  );
}
