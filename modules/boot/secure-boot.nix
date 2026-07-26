{ lib, pkgs, ... }:

{
  boot = {
    initrd.systemd.enable = true;
    loader = {
      efi.canTouchEfiVariables = true;

      # Lanzaboote installs systemd-boot itself, so NixOS's separate
      # systemd-boot installer must stay disabled.
      systemd-boot.enable = lib.mkForce false;
    };
    lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";

      # On a fresh installation, keys do not exist yet. Lanzaboote permits
      # unsigned artifacts for that first boot and creates the keys afterward.
      # Firmware enrollment stays manual so it is always a deliberate action.
      autoGenerateKeys.enable = true;
      autoEnrollKeys.enable = false;

      configurationLimit = 8;
      measuredBoot = {
        enable = true;
        pcrs = [
          4
          7
        ];
      };
    };
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
