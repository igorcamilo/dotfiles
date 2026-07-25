# Bootstrap-only hardware module.
#
# install.sh replaces this tracked file with the output of
# `nixos-generate-config --no-filesystems` before installing. Commit that
# generated result from igor-desktop after the first successful boot.
{ lib, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
